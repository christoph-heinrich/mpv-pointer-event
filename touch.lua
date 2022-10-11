local drag_total = 0
local ds_w = nil
local ds_h = nil
local ds_time = nil
local ds_dur = nil
local ds_vol = nil
local ds_vol_max = nil

local time = nil
local function seek(fast)
	if not time then return end
	mp.commandv('no-osd', 'seek', time, fast and 'absolute+keyframes' or 'absolute+exact')
end
seek_timer = mp.add_timeout(0.05, seek)
seek_timer:kill()
local function drag_horizontal(dx)
	if not ds_dur then return end
	drag_total = drag_total + dx
	time = math.max(drag_total / ds_w * ds_dur + ds_time, 0)
	if ds_w / ds_dur < 10 then
		-- Perform a fast seek while moving around and an exact seek afterwards
		seek(true)
		seek_timer:kill()
		seek_timer:resume()
	else
		seek()
	end
	mp.commandv('script-binding', 'uosc/flash-timeline')
end

local function drag_vertical(dy)
	drag_total = drag_total + dy
	local vol = math.max(math.min(math.floor(-drag_total / ds_h * 100 + ds_vol + 0.5), ds_vol_max), 0)
	mp.commandv('no-osd', 'set', 'volume', vol)
	mp.commandv('script-binding', 'uosc/flash-volume')
end

local drag_initialized = false
local function drag_init(vertical)
	if vertical then
		ds_vol = mp.get_property_number('volume')
		ds_vol_max = mp.get_property_number('volume-max')
	else
		ds_time = mp.get_property_number('playback-time')
		ds_dur = mp.get_property_number('duration')
	end
	ds_w, ds_h, _ = mp.get_osd_size()
	drag_initialized = true
end

local vertical = true
local function drag(dx, dy)
	if not drag_initialized then
		vertical = dx * dx < dy * dy
		drag_init(vertical)
	end
	if vertical then drag_vertical(dy)
	else drag_horizontal(dx) end
end

local function drag_start()
	drag_total = 0
	drag_initialized = false
end

local function drag_end()
	drag_total = 0
	ds_vol = nil
	ds_vol_max = nil
	ds_time = nil
	ds_dur = nil
end

mp.register_script_message('drag', drag)
mp.register_script_message('drag_start', drag_start)
mp.register_script_message('drag_end', drag_end)