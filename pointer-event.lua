local msg = require('mp.msg')
local options = require('mp.options')

local opts = {
	long_click_time = 500,
	double_click_time = mp.get_property_number('input-doubleclick-time'),
	drag_distance = 30,
	left_single = '',
	left_double = '',
	left_long = '',
	left_drag_start = '',
	left_drag_end = '',
	left_drag = '',
	right_single = '',
	right_double = '',
	right_long = '',
	right_drag_start = '',
	right_drag_end = '',
	right_drag = '',
	mid_single = '',
	mid_double = '',
	mid_long = '',
	mid_drag_start = '',
	mid_drag_end = '',
	mid_drag = '',
}
options.read_options(opts, 'pointer-event')

opts.long_click_time = opts.long_click_time / 1000
opts.double_click_time = opts.double_click_time / 1000

for k, v in pairs(opts) do
	if v == '' then opts[k] = nil end
end

local scale_sq = 1

local function analyze_mouse(mbtn)

	local key = mbtn
	mbtn = mbtn:match('_(.+)$')
	local cmd_single = opts[mbtn .. '_single']
	local cmd_double = opts[mbtn .. '_double']
	local cmd_long = opts[mbtn .. '_long']
	local cmd_drag_start = opts[mbtn .. '_drag_start']
	local cmd_drag_end = opts[mbtn .. '_drag_end']
	local cmd_drag = opts[mbtn .. '_drag']

	if not cmd_single and
		not cmd_double and
		not cmd_long and
		not cmd_drag_start and
		not cmd_drag_end and
		not cmd_drag then
		return
	end

	local nop = function() end
	local single_click = cmd_single and function()
		msg.verbose('single_click')
		mp.command(cmd_single)
	end or nop
	local double_click = cmd_double and function()
		msg.verbose('double_click')
		mp.command(cmd_double)
	end or nop
	local long_click = cmd_long and function()
		msg.verbose('long_click')
		mp.command(cmd_long)
	end or nop
	local drag_start = cmd_drag_start and function()
		msg.verbose('drag_start')
		mp.command(cmd_drag_start)
	end or nop
	local drag_end = cmd_drag_end and function()
		msg.verbose('drag_end')
		mp.command(cmd_drag_end)
	end or nop
	local drag = cmd_drag and function(dx, dy)
		msg.verbose('drag', dx, dy)
		mp.command(cmd_drag .. ' ' .. dx .. ' ' .. dy)
	end or nop

	local drag_distance_sq = opts.drag_distance * opts.drag_distance

	local last_drag_x = nil
	local last_drag_y = nil
	local dragging = false
	local drag_possible = true

	local last_down_x = 0
	local last_down_y = 0
	local down_start = nil

	local long_click_timeout = mp.add_timeout(opts.long_click_time, function()
		long_click()
		drag_possible = false
	end)
	long_click_timeout:kill()

	local double_click_timeout = mp.add_timeout(opts.double_click_time, function()
		if down_start then return end
		single_click()
	end)
	double_click_timeout:kill()

	local function btn_down(x, y)
		msg.debug('btn_down', x, y)
		if double_click_timeout:is_enabled() then
			double_click_timeout:kill()
			long_click_timeout:kill()
			double_click()
			drag_possible = false
		else
			double_click_timeout:resume()
			long_click_timeout:resume()
			drag_possible = true
		end

		last_drag_x, last_drag_y = x, y
		last_down_x, last_down_y = x, y
		down_start = mp.get_time()
	end
	local window_drag = false
	local function btn_up()
		msg.debug('btn_up')
		if not double_click_timeout:is_enabled() and long_click_timeout:is_enabled() and
			not dragging and drag_possible and not window_drag then
			single_click()
		end
		long_click_timeout:kill()
		if dragging then drag_end() end
		dragging = false
		down_start = nil
	end
	local function drag_to(x, y)
		msg.debug('drag_to', x, y)
		if dragging then
			local dx, dy = x - last_drag_x, y - last_drag_y
			drag(dx, dy)
		else
			local dx, dy = x - last_down_x, y - last_down_y
			local sq_dist = dx * dx + dy * dy
			if drag_possible and sq_dist >= drag_distance_sq * scale_sq then
				double_click_timeout:kill()
				long_click_timeout:kill()
				drag_start()
				drag(dx, dy)
				dragging = true
			end
		end
		last_drag_x, last_drag_y = x, y
	end

	local mouse_x, mouse_y = 0, 0
	mp.add_forced_key_binding(key, 'pe_' .. mbtn, function(tab)
		local mouse = mp.get_property_native('mouse-pos')
		mouse_x, mouse_y = mouse.x, mouse.y
		msg.trace(key, tab.event, mouse.x, mouse.y)
		if tab.event == 'up' then
			-- because of window dragging the up event can come shortly after down
			if mp.get_time() - down_start > 0.02 then
				btn_up()
			else
				double_click_timeout:kill()
				long_click_timeout:kill()
				window_drag = true
			end
		else
			btn_down(mouse_x, mouse_y)
			window_drag = false
		end
	end, {complex = true})
	mp.observe_property('mouse-pos', 'native', function(_, mouse)
		msg.trace('mouse-pos', mouse.hover, mouse.x, mouse.y)
		if mouse.hover and down_start then
			if window_drag then btn_up()
			else drag_to(mouse.x, mouse.y) end
		end
		mouse_x, mouse_y = mouse.x, mouse.y
	end)
	if cmd_double then
		mp.add_forced_key_binding(key .. '_dbl', 'pe_' .. mbtn .. '_dbl', function()
			-- to prevent warning about double click not being assigned
		end)
	end
end

analyze_mouse('mbtn_left')
analyze_mouse('mbtn_right')
analyze_mouse('mbtn_mid')

mp.observe_property('display-hidpi-scale', 'number', function(_, val)
	if val then scale_sq = val * val
	else scale_sq = 1 end
end)