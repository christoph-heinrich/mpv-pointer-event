local msg = require("mp.msg")

local function analyze_mouse(mbtn)

	local long_click_time = 0.5
	local double_click_time = mp.get_property_number("input-doubleclick-time") / 1000
	local drag_distance = 30 * mp.get_property_number("display-hidpi-scale")
	local double_click_distance = 20 * mp.get_property_number("display-hidpi-scale")

	local function single_click()
		msg.verbose('single_click')
		-- mp.commandv('cycle', 'pause')
	end
	local function double_click()
		msg.verbose('double_click')
	end
	local function long_click()
		msg.verbose('long_click')
		-- mp.command('script-binding uosc/menu-blurred')
	end
	-- local drag_total = 0
	-- local ds_vol = nil
	-- local ds_vol_max = nil
	-- local ds_time = nil
	-- local ds_dur = nil
	-- local ds_w = nil
	-- local ds_h = nil
	local function drag_start(is_horizontal)
		msg.verbose('drag_start')
		-- drag_total = 0
		-- ds_w, ds_h, _ = mp.get_osd_size()
		-- if is_horizontal then
		-- 	ds_time = mp.get_property_number('playback-time')
		-- 	ds_dur = mp.get_property_number('duration')
		-- else
		-- 	ds_vol = mp.get_property_number('volume')
		-- 	ds_vol_max = mp.get_property_number('volume-max')
		-- end
	end
	local function drag_end()
		msg.verbose('drag_end')
		-- drag_total = 0
		-- ds_vol = nil
		-- ds_vol_max = nil
		-- ds_time = nil
		-- ds_dur = nil
	end
	local function drag(dx, dy)
		msg.verbose('drag', dx, dy)
	end
	local function drag_horizontal(dx)
		msg.debug('drag_horizontal', dx)
		-- if not ds_dur then return end
		-- drag_total = drag_total + dx
		-- local flags = (ds_w / ds_dur < 10) and 'absolute+keyframes' or 'absolute+exact'
		-- local dur = math.min(drag_total / ds_w * ds_dur + ds_time, 0)
		-- mp.commandv('osd-msg', 'seek', dur, flags)
	end
	local function drag_vertical(dy)
		msg.debug('drag_vertical', dy)
		-- drag_total = drag_total + dy
		-- local vol = math.max(math.min(math.floor(-drag_total / ds_h * 100 + ds_vol + 0.5), ds_vol_max), 0)
		-- mp.commandv('osd-msg', 'set', 'volume', vol)
	end

	local drag_distance_sq = drag_distance * drag_distance
	local double_click_distance_sq = double_click_distance * double_click_distance

	local last_drag_x = nil
	local last_drag_y = nil
	local dragging = false
	local dragging_horizontal = true
	local drag_possible = true

	local last_down = 0
	local last_down_x = 0
	local last_down_y = 0
	local down_start = nil

	local long_click_timeout = mp.add_timeout(long_click_time, function()
		long_click()
		drag_possible = false
	end)
	long_click_timeout:kill()

	local double_click_timeout = mp.add_timeout(double_click_time, function()
		if down_start then return end
		single_click()
	end)
	double_click_timeout:kill()

	local function btn_down(x, y)
		msg.debug('btn_down', x, y)
		local now = mp.get_time()
		drag_possible = true
		local dx, dy = x - last_down_x, y - last_down_y
		local sq_dist = dx * dx + dy * dy
		if now - last_down <= double_click_time and sq_dist <= double_click_distance_sq then
			double_click_timeout:kill()
			long_click_timeout:kill()
			double_click()
			drag_possible = false
			last_down = 0
		else
			double_click_timeout:resume()
			long_click_timeout:resume()
			last_down = now
		end

		last_drag_x, last_drag_y = x, y
		last_down_x, last_down_y = x, y
		down_start = now
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
			if dragging_horizontal then	drag_horizontal(dx)
			else drag_vertical(dy) end
		else
			local dx, dy = x - last_down_x, y - last_down_y
			local dx_sq, dy_sq = dx * dx, dy * dy
			local sq_dist = dx_sq + dy_sq
			if drag_possible and sq_dist >= drag_distance_sq then
				double_click_timeout:kill()
				long_click_timeout:kill()
				dragging_horizontal = dx_sq > dy_sq
				drag_start(dragging_horizontal)
				drag(dx, dy)
				dragging = true
				if dragging_horizontal then drag_horizontal(dx)
				else drag_vertical(dy) end
			end
		end
		last_drag_x, last_drag_y = x, y
	end

	local mouse_x, mouse_y = 0, 0
	mp.add_forced_key_binding(mbtn, 'pe_' .. mbtn, function(tab)
		local mouse = mp.get_property_native('mouse-pos')
		mouse_x, mouse_y = mouse.x, mouse.y
		msg.trace(mbtn, tab.event, mouse.x, mouse.y)
		if tab.event == 'up' then
			-- because of window dragging the up event can come shortly after down
			if down_start then
				if mp.get_time() - down_start > 0.02 then
					btn_up()
				else
					double_click_timeout:kill()
					long_click_timeout:kill()
					window_drag = true
				end
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
end

analyze_mouse('mbtn_left')