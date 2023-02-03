-- pointer-event 1.2.1 - 2023-Feb-03
-- https://github.com/christoph-heinrich/mpv-pointer-event
--
-- Low latency detection of single-click, double-click, long-click and dragging.

-- workaround https://github.com/mpv-player/mpv/issues/11154
mp.add_key_binding('mouse_move', nil, function() end)

local msg = require('mp.msg')
local options = require('mp.options')

local opts = {
	long_click_time = 500,
	double_click_time = 0,
	drag_distance = 10,
	margin_left = 0,
	margin_right = 0,
	margin_top = 50,
	margin_bottom = 90,
	ignore_left_single_long_while_window_dragging = true,
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

for k, v in pairs(opts) do
	if v == '' then opts[k] = nil end
end

opts.long_click_time = opts.long_click_time / 1000

local window_dragging_enabled = mp.get_property_bool('window-dragging')
if window_dragging_enabled then
	msg.warn('window dragging is enabled and can interfere with gesture detection')
end

local fullscreen, maximized, windowed = false, false, true
local function update_windowed()
	windowed = not (fullscreen or maximized)
end

local prop_double_time = mp.get_property_number('input-doubleclick-time', 300)
local double_time
local function update_double_time()
	local time = opts.double_click_time <= 0 and prop_double_time or opts.double_click_time
	double_time = time / 1000
end
update_double_time()

local scale = 1
local scale_sq = 1

local width, height = 0, 0
local area_x0, area_x1, area_y0, area_y1
local function update_area()
	area_x0, area_y0 = opts.margin_left * scale, opts.margin_top * scale
	area_x1, area_y1 = width - opts.margin_right * scale, height - opts.margin_bottom * scale
end

local function analyze_mouse(key)

	local mbtn = key:match('_(.+)$')
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

	local function recognized_event(fun, dx, dy)
		if (fun == single_click or fun == long_click)
			and mbtn == 'left' and windowed and window_dragging_enabled
			and opts.ignore_left_single_long_while_window_dragging then
			return
		end
		if last_down_x >= area_x0 and last_down_x < area_x1 and
			last_down_y >= area_y0 and last_down_y < area_y1 then
			fun(dx, dy)
		end
	end

	local long_click_timeout = mp.add_timeout(opts.long_click_time, function()
		recognized_event(long_click)
		drag_possible = false
	end)
	long_click_timeout:kill()

	local double_click_timeout = mp.add_timeout(double_time, function()
		if down_start then return end
		recognized_event(single_click)
	end)
	double_click_timeout:kill()

	local function btn_down(x, y)
		msg.debug('btn_down', x, y)
		if double_click_timeout:is_enabled() then
			double_click_timeout:kill()
			long_click_timeout:kill()
			recognized_event(double_click)
			drag_possible = false
		else
			double_click_timeout.timeout = double_time
			double_click_timeout:resume()
			long_click_timeout:resume()
			drag_possible = true
		end

		last_drag_x, last_drag_y = x, y
		last_down_x, last_down_y = x, y
		down_start = mp.get_time()
	end
	local function btn_up()
		msg.debug('btn_up')
		if not double_click_timeout:is_enabled() and long_click_timeout:is_enabled() and
			not dragging and drag_possible then
			recognized_event(single_click)
		end
		long_click_timeout:kill()
		if dragging then recognized_event(drag_end) end
		dragging = false
		down_start = nil
	end
	local function drag_to(x, y)
		msg.debug('drag_to', x, y)
		if dragging then
			local dx, dy = x - last_drag_x, y - last_drag_y
			recognized_event(drag, dx, dy)
		else
			local dx, dy = x - last_down_x, y - last_down_y
			local sq_dist = dx * dx + dy * dy
			if drag_possible and sq_dist >= drag_distance_sq * scale_sq then
				double_click_timeout:kill()
				long_click_timeout:kill()
				recognized_event(drag_start)
				recognized_event(drag, dx, dy)
				dragging = true
			end
		end
		last_drag_x, last_drag_y = x, y
	end

	local mouse_x, mouse_y = 0, 0
	mp.add_forced_key_binding(key, 'pe_' .. mbtn, function(tab)
		local mouse = mp.get_property_native('mouse-pos')
		mouse_x, mouse_y = mouse.x, mouse.y
		msg.trace(key, mouse.x, mouse.y, mouse.hover, tab.event)
		if tab.event == 'up' then btn_up()
		else btn_down(mouse_x, mouse_y) end
	end, {complex = true})
	mp.observe_property('mouse-pos', 'native', function(name, mouse)
		if not mouse then return end
		msg.trace(name, mouse.x, mouse.y, mouse.hover)
		if down_start then drag_to(mouse.x, mouse.y) end
		mouse_x, mouse_y = mouse.x, mouse.y
	end)
	if cmd_double then
		mp.add_key_binding(key .. '_dbl', 'pe_' .. mbtn .. '_dbl', function()
			-- to prevent warning about double click not being assigned
		end)
	end
end

analyze_mouse('mbtn_left')
analyze_mouse('mbtn_right')
analyze_mouse('mbtn_mid')

mp.observe_property('display-hidpi-scale', 'number', function(name, val)
	msg.trace(name, val)
	if val then
		scale = val
		scale_sq = val * val
	else
		scale = 1
		scale_sq = 1
	end
	update_area()
end)

mp.observe_property('osd-dimensions', 'native', function(name, dim)
	msg.trace(name, dim and dim.w or nil, dim and dim.h or nil)
	if not dim then return end
	width, height = dim.w, dim.h
	update_area()
end)

mp.observe_property('input-doubleclick-time', 'number', function(name, val)
	msg.trace(name, val)
	if val then prop_double_time = val
	else prop_double_time = 300 end
	update_double_time()
end)

mp.observe_property('fullscreen', 'bool', function(name, val)
	msg.trace(name, val)
	if val == nil then return end
	fullscreen = val
	update_windowed()
end)

mp.observe_property('window-maximized', 'bool', function(name, val)
	msg.trace(name, val)
	if val == nil then return end
	maximized = val
	update_windowed()
end)
