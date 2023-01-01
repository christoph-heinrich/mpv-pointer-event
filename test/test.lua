local mock = require('test/mock-mpv')
mock.config_path('test/pointer-event.conf')

require('pointer-event')

local events = {}
io.input('test/log.txt')
for line in io.lines() do
	if line:find('%[pointer_event%]') then print(line) end
	local time, level, message = line:match('%[(%s*[0-9.]+)%]%[([tdvie])%]%[pointer_event%] (.*)')
	if message ~= nil then
		if level == 't' then
			time = tonumber(time)
			if message:find('mouse-pos', 1, true) then
				local x, y, hover = message:match('(%d+) (%d+) (%w+)')
				x, y, hover = tonumber(x), tonumber(y), hover == 'true'
				events[#events+1] = {
					time = time,
					type = 'prop',
					prop_name = 'mouse-pos',
					prop_value = x and {x = x, y = y, hover = hover} or nil,
				}
			elseif message:find('osd-dimensions', 1, true) then
				local width, height = message:match('(%d+) (%d+)')
				width, height = tonumber(width), tonumber(height)
				events[#events+1] = {
					time = time,
					type = 'prop',
					prop_name = 'osd-dimensions',
					prop_value = width and {w = width, h = height} or nil,
				}
			elseif message:find('display-hidpi-scale', 1, true) then
				local scale = message:match('(%d+)')
				scale = tonumber(scale)
				events[#events+1] = {
					time = time,
					type = 'prop',
					prop_name = 'display-hidpi-scale',
					prop_value = scale,
				}
			elseif message:find('input-doubleclick-time', 1, true) then
				local dc_time = message:match('(%d+)')
				dc_time = tonumber(dc_time)
				events[#events+1] = {
					time = time,
					type = 'prop',
					prop_name = 'input-doubleclick-time',
					prop_value = dc_time,
				}
			else
				local key, x, y, hover, dir = message:match('([%w_]+) (%d+) (%d+) (%w+) (%w+)')
				x, y, hover = tonumber(x), tonumber(y), hover == 'true'
				events[#events+1] = {
					time = time,
					type = 'key',
					key = key,
					dir = dir,
					mouse_pos = x and {x = x, y = y, hover = hover} or nil,
				}
			end
		end
	end
end

for _, event in ipairs(events) do
	mock.time(event.time)
	if event.type == 'prop' then
		mock.set_property(event.prop_name, event.prop_value)
		mock.run_property_observers()
	else
		mock.set_property('mouse-pos', event.mouse_pos)
		if event.dir == 'down' then
			mock.key_down(event.key)
		else
			mock.key_up(event.key)
		end
	end
end
