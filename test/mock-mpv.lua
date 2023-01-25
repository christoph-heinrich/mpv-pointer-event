local conf_path = nil
local script_name = nil
local time_s = 0
local key_bindings = {key_name = {}, name_cb = {}}
local key_bindings_forced = {key_name = {}, name_cb = {}}
local properties = {}
local property_callbacks = {}
local timers = {}
local log_buffer = {}

mp = {}
function mp.add_key_binding(key, name, callback, _flags)
	if name == nil then error('nameless key bindings aren\'t supported') end
	key_bindings.key_name[key] = name
	key_bindings.name_cb[name] = callback
end
function mp.add_forced_key_binding(key, name, callback, _flags)
	if name == nil then error('nameless key bindings aren\'t supported') end
	key_bindings_forced.key_name[key] = name
	key_bindings_forced.name_cb[name] = callback
end
function mp.get_property() end
function mp.register_event(_name, _callback) end
function mp.register_script_message(_name, _callback) end
function mp.get_script_name() return script_name end
function mp.command(_cmd) end
function mp.observe_property(name, _type, callback)
	property_callbacks[name] = callback
end
function mp.create_osd_overlay() end
function mp.get_property_native(name) return properties[name] end
function mp.add_timeout(seconds, callback)
	local timer = {
		timeout = seconds,
		oneshot = true,
		deadline = time_s + seconds,
		callback = callback,
		stop = function(timer)
			timer.deadline = timer.deadline - time_s
			timers[timer] = nil
		end,
		kill = function(timer)
			timer.deadline = nil
			timers[timer] = nil
		end,
		resume = function(timer)
			if not timers[timer] then
				timer.deadline = time_s + (timer.deadline or timer.timeout)
				timers[timer] = true
			end
		end,
		is_enabled = function(timer) return timers[timer] end,
	}
	timers[timer] = true
	return timer
end
function mp.get_property_number(_name, default) return default end
function mp.get_time() return time_s end
package.loaded["mp"] = mp

local mp_utils = {}
package.loaded["mp.utils"] = mp_utils

local mp_msg = {}
function mp_msg.log(level, ...)
	if level == 'no' or level == 'status' then return
	elseif level == 'fatal' then level = 'f'
	elseif level == 'error' then level = 'e'
	elseif level == 'warn' then level = 'w'
	elseif level == 'info' then level = 'i'
	elseif level == 'v' then level = 'v'
	elseif level == 'debug' then level = 'd'
	elseif level == 'trace' then level = 't'
	end
	args = {...}
	for i, v in ipairs(args) do args[i] = tostring(v) end
	log_buffer[#log_buffer + 1] = string.format('[%8.3f][%s][%s] %s ', time_s, level, script_name, table.concat(args, ' '))
	print(log_buffer[#log_buffer])
end
function mp_msg.fatal(...) mp_msg.log('fatal', ...) end
function mp_msg.error(...) mp_msg.log('error', ...) end
function mp_msg.warn(...) mp_msg.log('warn', ...) end
function mp_msg.info(...) mp_msg.log('info', ...) end
function mp_msg.verbose(...) mp_msg.log('v', ...) end
function mp_msg.debug(...) mp_msg.log('debug', ...) end
function mp_msg.trace(...) mp_msg.log('trace', ...) end

package.loaded["mp.msg"] = mp_msg

local mp_assdraw = {}
function mp_assdraw.ass_new() return {} end
package.loaded["mp.assdraw"] = mp_assdraw

local mp_options = {}
function mp_options.read_options(opts, _name, _callback)
	if conf_path == nil then return end

	io.input(conf_path)
	for line in io.lines() do
		if line:sub(1,1) ~= '#' then
			local name, value = line:match('^(.-)=(.*)$')
			opts[name] = value
		end
	end
end
package.loaded["mp.options"] = mp_options

local mock = {}
function mock.config_path(path) conf_path = path end
function mock.script_name(name) script_name = name:gsub('-', '_') end
local function next_timer()
	local first = next(timers)
	for timer,_ in pairs(timers) do
		if timer.deadline < first.deadline then
			first = timer
		end
	end
	return first
end
function mock.time(seconds)
	local timer = next_timer()
	while timer and timer.deadline < seconds do
		time_s = timer.deadline
		timer.callback()
		if timer.oneshot then
			timer:kill()
		else
			timer.deadline = timer.deadline + timer.timeout
		end
		timer = next_timer()
	end
	time_s = seconds
end
local function call_key_cb(table, key, arg)
	local cb = table.name_cb[table.key_name[key]]
	if cb then
		cb(arg)
		return true
	else
		return false
	end
end
function mock.key_down(key)
	if not call_key_cb(key_bindings_forced, key, {event = 'down'}) then
		call_key_cb(key_bindings, key, {event = 'down'})
	end
end
function mock.key_up(key)
	if not call_key_cb(key_bindings_forced, key, {event = 'up'}) then
		call_key_cb(key_bindings, key, {event = 'up'})
	end
end
function mock.set_property(name, value, run_observer)
	properties[name] = value
	if run_observer then property_callbacks[name](name, value) end
end
function mock.get_log_buffer()
	return log_buffer
end

return mock
