local conf_path = nil
local time_s = 0
local key_bindings = {key_name = {}, name_cb = {}}
local key_bindings_forced = {key_name = {}, name_cb = {}}
local properties = {}
local property_callbacks = {}
local property_callback_pending = {}
local timers = {}

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
function mp.register_event() end
function mp.register_script_message() end
function mp.get_script_name() end
function mp.command(_cmd) end
function mp.observe_property(name, _type, callback)
	property_callbacks[name] = callback
	property_callback_pending[name] = true
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
function mp_msg.trace(...) print(string.format('[%8.3f]', time_s), '[t]', ...) end
function mp_msg.debug(...) print(string.format('[%8.3f]', time_s), '[d]', ...) end
function mp_msg.verbose(...) print(string.format('[%8.3f]', time_s), '[v]', ...) end
function mp_msg.info(...) print(string.format('[%8.3f]', time_s), '[i]', ...) end
function mp_msg.error(...) print(string.format('[%8.3f]', time_s), '[e]', ...) end
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
function mock.set_property(name, value)
	properties[name] = value
	property_callback_pending[name] = true
end
function mock.run_property_observers()
	for name, _ in pairs(property_callback_pending) do
		property_callbacks[name](name, properties[name])
	end
	property_callback_pending = {}
end

return mock
