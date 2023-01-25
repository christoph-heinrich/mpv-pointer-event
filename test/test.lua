local mock = require('test/mock-mpv')
mock.config_path('test/pointer-event.conf')
mock.script_name('pointer-event')

-- Experiment about overwriting built in functions to insert logging.
-- do
-- 	local function get_script_log_level()
-- 		local script_name = mp.get_script_name()
-- 		local log_level = nil
-- 		for module, value in mp.get_property('msg-level'):gmatch('([%w_/]+)=(%w+),?') do
-- 			if module == script_name or module == 'all' then
-- 				log_level = value
-- 			end
-- 		end
-- 		return log_level or 'status'
-- 	end

-- 	if get_script_log_level() == 'trace' then
-- 		local msg = require('mp.msg')
-- 		local utils = require('mp.utils')
-- 		do
-- 			local orig_fn = mp.observe_property
-- 			mp.observe_property = function(name, _type, callback)
-- 				orig_fn(name, _type, function(pname, val)
-- 					msg.trace("[logreplay][observe_property]", pname, type(val),
-- 						type(val) == 'table' and utils.format_json(val) or val)
-- 					callback(pname, val)
-- 				end)
-- 			end
-- 		end
-- 	end
-- end

require('pointer-event')

local events = {}
local log = {}
io.input('test/log.txt')
for line in io.lines() do
	-- if line:find('%[pointer_event%]') then print(line) end
	local time, level, message = line:match('%[(%s*[0-9.]+)%]%[([tdvie])%]%[pointer_event%] (.*)')
	if message ~= nil then
		log[#log+1] = line
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
			elseif message:find('fullscreen', 1, true) then
				local dc_time = message:match('(%d+)')
				dc_time = tonumber(dc_time)
				events[#events+1] = {
					time = time,
					type = 'prop',
					prop_name = 'fullscreen',
					prop_value = dc_time,
				}
			elseif message:find('maximized', 1, true) then
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
		else
			events[#events+1] = {}
		end
	end
end

for i, event in ipairs(events) do
	if event.type then
		mock.time(event.time)
		if event.type == 'prop' then
			mock.set_property(event.prop_name, event.prop_value, true)
		elseif event.type == 'key' then
			mock.set_property('mouse-pos', event.mouse_pos)
			if event.dir == 'down' then
				mock.key_down(event.key)
			else
				mock.key_up(event.key)
			end
		else
			error('unknown event type')
		end
	end
end

mock_log = mock.get_log_buffer()
if #log ~= #mock_log then
	print('ERROR: logs are not the same length', #log, #mock_log)
	-- return
end

for i, line in ipairs(log) do
	-- ignore time as it can be slightly off due to string -> double -> string conversion
	local pattern = '%[%s*%d+.%d+%](.*)'
	if line:match(pattern) ~= mock_log[i]:match(pattern) then
		print(i)
		print(line)
		print(mock_log[i])
		print('ERROR: log lines are not identical')
	end
end
