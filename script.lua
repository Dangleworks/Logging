-- SETTINGS --
log_settings = {
    player_customcommand = true,
    player_chat = true,
    player_join = true,
    player_leave = true,
    player_sit = false,
    player_respawn = true,
    player_die = true,
    player_button_press = false,
    vehicle_spawn = true,
    vehicle_despawn = true,
    vehicle_damage = false,
    fire_extinguished = false,
    forest_fire_lit = false,
    forest_fire_extinguished = false,
    addon_component_spawn = false,
    statistics = true
}
log_port = 8000
log_requests = {
    player_customcommand = "/log/player/command?steam_id=%d&peer_id=%d&name=%s&is_admin=%s&is_auth=%s&command=%s",
    player_chat = "/log/player/chat?peer_id=%d&name=%s&message=%s",
    player_join = "/log/player/join?steam_id=%d&name=%s&peer_id=%d&is_admin=%s&is_auth=%s",
    player_leave = "/log/player/leave?steam_id=%d&name=%s&peer_id=%d&is_admin=%s&is_auth=%s",
    player_sit = "/log/player/sit?steam_id=%d&peer_id=%d&vehicle_id=%d&seat_name=%s",
    player_respawn = "/log/player/respawn?steam_id=%d&name=%s&peer_id=%s",
    player_die = "/log/player/die?steam_id=%d&name=%s&peer_id=%d&is_admin=%s&is_auth=%s",
    vehicle_spawn = "/log/vehicle/spawn?vehicle_id=%d&peer_id=%d&steam_id=%d&x=%0.3f&y=%0.3f&z=%0.3f&cost=%f&name=%s&mass=%f&voxels=%d",
    vehicle_despawn = "/log/vehicle/despawn?vehicle_id=%d&peer_id=%d&x=%0.3f&y=%0.3f&z=%0.3f",
    vehicle_teleport = "/log/vehicle/teleport?vehicle_id=%d&peer_id=%d&x=%0.3f&y=%0.3f&z=%0.3f",
    button_press = "/log/player/buttonpress?vehicle_id=%d&peer_id=%d&button_name=%s",
    server_stats = "/stats?data=%s"
}

stat_report_interval = 1000

--- RUNTIME VARIABLES ---
debugging = false
stat_last_report = 0
tps = 0
ticks_time = 0
ticks = 0
tps_buff = {}

-- CALLBACKS --
function onTick(game_ticks)
    if not log_settings.statistics then return end
    calculateTPS()
    local ctime = server.getTimeMillisec()
    if ctime - stat_last_report >= stat_report_interval then
        stat_last_report = ctime
        local stats = {
            players = server.getPlayers(),
            tps = {instant = tps, average = Mean(tps_buff.values)}
        }
        local stat_string = json.stringify(stats)
        if stat_string == nil or stat_string == "" then
            logError("Logging Tick - Stat string was nil or empty!")
            return
        end
        logDebug(stat_string)

        local req =
            string.format(log_requests.server_stats, encode(stat_string))

        server.httpGet(log_port, req)
    end
end

function onCreate(is_world_create) tps_buff = NewBuffer(10) end

function onCustomCommand(full_message, peer_id, is_admin, is_auth, command, ...)
    if command == "?debug" and is_admin then
        debugging = not debugging
        server.announce("[LOGGING]", "Logging: " .. tostring(debugging), peer_id)
    end

    if not log_settings.player_customcommand then return end
    local req = string.format(log_requests.player_customcommand,
                              getSteamID(peer_id), peer_id,
                              encode(getUserName(peer_id)), is_admin, is_auth,
                              encode(full_message))
    server.httpGet(log_port, req)
end

function onChatMessage(peer_id, sender_name, message)

    if not log_settings.player_chat then return end

    local req = string.format(log_requests.player_chat, peer_id,
                              encode(sender_name), encode(message))
    server.httpGet(log_port, req)
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
    if not log_settings.player_join then return end
    local req = string.format(log_requests.player_join, steam_id, encode(name),
                              peer_id, is_admin, is_auth)
    server.httpGet(log_port, req)
end

function onPlayerSit(peer_id, vehicle_id, seat_name)
    if not log_settings.player_sit then return end
    local req = string.format(log_requests.player_sit, getSteamID(peer_id),
                              peer_id, vehicle_id, encode(seat_name))
    server.httpGet(log_port, req)
end

function onPlayerRespawn(peer_id)
    if not log_settings.player_respawn then return end
    local req = string.format(log_requests.player_respawn, getSteamID(peer_id),
                              getUserName(peer_id), peer_id)
    server.httpGet(log_port, req)
end

function onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
    if not log_settings.player_leave then return end
    local req = string.format(log_requests.player_leave, steam_id, encode(name),
                              peer_id, is_admin, is_auth)
    server.httpGet(log_port, req)
end

function onPlayerDie(steam_id, name, peer_id, is_admin, is_auth)
    if not log_settings.player_die then return end
    local req = string.format(log_requests.player_die, steam_id, encode(name),
                              peer_id, is_admin, is_auth)
    server.httpGet(log_port, req)
end

vehicle_spawn_details = {}

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
    if not log_settings.vehicle_spawn then return end
    if peer_id == -1 then return end
    vehicle_spawn_details[vehicle_id] = {
        peer_id = peer_id,
        x = x,
        y = y,
        z = z,
        cost = cost
    }
end

function onVehicleLoad(vehicle_id)
    if not log_settings.vehicle_spawn then return end
    local vehicle_data, ok = server.getVehicleData(vehicle_id)
    if not ok then 
        logError("Logging onVehicleLoad - failed to get vehicle data")
        vehicle_spawn_details[vehicle_id] = nil
        return
    end
    logDebug(tostring(getSteamID(vehicle_spawn_details[vehicle_id].peer_id)))

    local req = string.format(log_requests.vehicle_spawn,
                              vehicle_id,
                              vehicle_spawn_details[vehicle_id].peer_id,
                              getSteamID(vehicle_spawn_details[vehicle_id].peer_id),
                              vehicle_spawn_details[vehicle_id].x,
                              vehicle_spawn_details[vehicle_id].y,
                              vehicle_spawn_details[vehicle_id].z,
                              vehicle_spawn_details[vehicle_id].cost,
                              encode(vehicle_data.filename),
                              vehicle_data.mass,
                              vehicle_data.voxels)
    logDebug(req)
    server.httpGet(log_port, req)
    vehicle_spawn_details[vehicle_id] = nil
end

function onVehicleDespawn(vehicle_id, peer_id)
    local vd, ok = server.getVehicleData(vehicle_id)
    local vehicle_data = {x=0,y=0,z=0}
    if ok then
        local x,y,z = matrix.position(vd.trasnform)
        vehicle_data = {
            x=x,
            y=y,
            z=z
        }
    end

    -- make sure to check the case of a vehicle being spawned, but not loaded
    if vehicle_spawn_details[vehicle_id] ~= nil then
        logDebug("Vehicle was despawned before it was loaded")
        vehicle_data = vehicle_spawn_details[vehicle_id]
        vehicle_spawn_details[vehicle_id] = nil
    end

    local req = string.format(log_requests.vehicle_despawn, vehicle_id, peer_id,
                              vehicle_data.x, vehicle_data.y, vehicle_data.z)

    if not log_settings.vehicle_despawn then return end

    server.httpGet(log_port, req)
end

function onVehicleTeleport(vehicle_id, peer_id, x, y, z)
    if not log_settings.vehicle_teleport then return end
    local req = string.format(log_requests.vehicle_teleport, vehicle_id,
                              peer_id, x, y, z)

    server.httpGet(log_port, req)
end

function onButtonPress(vehicle_id, peer_id, button_name)
    if not log_settings.player_button_press then return end
    local req = string.format(log_requests.button_press, vehicle_id, peer_id,
                              encode(button_name))

    server.httpGet(log_port, req)
end

function onVehicleDamaged(vehicle_id, damage_amount, voxel_x, voxel_y, voxel_z) end

function onFireExtinguished(fire_x, fire_y, fire_z) end

function onForestFireSpawned(fire_objective_id, fire_x, fire_y, fire_z) end

function onForestFireExtinguished(fire_objective_id, fire_x, fire_y, fire_z) end

function onSpawnAddonComponent(component_id, component_name, TYPE_STRING,
                               addon_index) end

-- UTIL --
function calculateTPS()
    ticks = ticks + 1
    local ctime = server.getTimeMillisec()
    if  ctime - ticks_time >= 500 then
        tps = ticks * 2
        ticks = 0
        ticks_time = ctime
        tps_buff.Push(tps)
    end
end

function NewBuffer(maxlen)
    local buffer = {}
    buffer.maxlen = maxlen
    buffer.values = {}

    function buffer.Push(item)
        table.insert(buffer.values, 1, item)
        buffer.values[buffer.maxlen + 1] = nil
    end

    function buffer.PrintAll()
        data = ""
        for i, v in pairs(buffer.values) do
            data = data .. v
            if i < #buffer.values then data = data .. "," end
        end

        print(data)
    end
    return buffer
end

function Mean(T)
    local sum = 0
    local count = 0
    if T == nil then return 0 end
    for k, v in pairs(T) do
        if type(v) == 'number' then
            sum = sum + v
            count = count + 1
        end
    end
    return (sum / count)
end

function encode(str)
    function cth(c) return string.format("%%%02X", string.byte(c)) end
    if str == nil then return "" end
    str = string.gsub(str, "([^%w _ %- . ~])", cth)
    str = str:gsub(" ", "%%20")
    return str
end

function getSteamID(peer_id)
    for _, p in pairs(server.getPlayers()) do
        if tostring(p.id) == tostring(peer_id) then return p.steam_id end
    end
    return 0
end

function getUserName(peer_id)
    if peer_id == -1 then return "Server" end

    local name, ok = server.getPlayerName(peer_id)
    if not ok then return "Unknown" end

    return name
end

function logDebug(message)
    if not debugging then return end
    for _, p in ipairs(server.getPlayers()) do
        if p.admin then server.announce("[Logging-Debug]", message, p.id) end
    end
end

function logError(message)
    for idx, p in pairs(server.getPlayers()) do
        if p.admin == true then server.announce("[Error]", message, p.id) end
    end
    debug.log(message)
end

-- Source: https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
json = {}

-- Internal functions.
local function kind_of(obj)
    if type(obj) ~= 'table' then return type(obj) end
    local i = 1
    for _ in pairs(obj) do
        if obj[i] ~= nil then
            i = i + 1
        else
            return 'table'
        end
    end
    if i == 1 then
        return 'table'
    else
        return 'array'
    end
end

local function escape_str(s)
    local in_char = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
    local out_char = {'\\', '"', '/', 'b', 'f', 'n', 'r', 't'}
    for i, c in ipairs(in_char) do s = s:gsub(c, '\\' .. out_char[i]) end
    return s
end

-- Returns pos, did_find; there are two cases:
-- 1. Delimiter found: pos = pos after leading space + delim; did_find = true.
-- 2. Delimiter not found: pos = pos after leading space;     did_find = false.
-- This throws an error if err_if_missing is true and the delim is not found.
local function skip_delim(str, pos, delim, err_if_missing)
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) ~= delim then
        if err_if_missing then
            error('Expected ' .. delim .. ' near position ' .. pos)
        end
        return pos, false
    end
    return pos + 1, true
end

-- Expects the given pos to be the first character after the opening quote.
-- Returns val, pos; the returned pos is after the closing quote character.
local function parse_str_val(str, pos, val)
    val = val or ''
    local early_end_error = 'End of input found while parsing string.'
    if pos > #str then error(early_end_error) end
    local c = str:sub(pos, pos)
    if c == '"' then return val, pos + 1 end
    if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
    -- We must have a \ character.
    local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
    local nextc = str:sub(pos + 1, pos + 1)
    if not nextc then error(early_end_error) end
    return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

-- Returns val, pos; the returned pos is after the number's final character.
local function parse_num_val(str, pos)
    local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
    local val = tonumber(num_str)
    if not val then error('Error parsing number at position ' .. pos .. '.') end
    return val, pos + #num_str
end

-- Public values and functions.

function json.stringify(obj, as_key)
    local s = {} -- We'll build the string as an array of strings to be concatenated.
    local kind = kind_of(obj) -- This is 'array' if it's an array or type(obj) otherwise.
    if kind == 'array' then
        if as_key then error('Can\'t encode array as key.') end
        s[#s + 1] = '['
        for i, val in ipairs(obj) do
            if i > 1 then s[#s + 1] = ',' end
            s[#s + 1] = json.stringify(val)
        end
        s[#s + 1] = ']'
    elseif kind == 'table' then
        if as_key then error('Can\'t encode table as key.') end
        s[#s + 1] = '{'
        for k, v in pairs(obj) do
            if #s > 1 then s[#s + 1] = ',' end
            s[#s + 1] = json.stringify(k, true)
            s[#s + 1] = ':'
            s[#s + 1] = json.stringify(v)
        end
        s[#s + 1] = '}'
    elseif kind == 'string' then
        return '"' .. escape_str(obj) .. '"'
    elseif kind == 'number' then
        if as_key then return '"' .. tostring(obj) .. '"' end
        return tostring(obj)
    elseif kind == 'boolean' then
        return tostring(obj)
    elseif kind == 'nil' then
        return 'null'
    else
        error('Unjsonifiable type: ' .. kind .. '.')
    end
    return table.concat(s)
end

json.null = {} -- This is a one-off table to represent the null value.

function json.parse(str, pos, end_delim)
    pos = pos or 1
    if pos > #str then return nil end
    local pos = pos + #str:match('^%s*', pos) -- Skip whitespace.
    local first = str:sub(pos, pos)
    if first == '{' then -- Parse an object.
        local obj, key, delim_found = {}, true, true
        pos = pos + 1
        while true do
            key, pos = json.parse(str, pos, '}')
            if key == nil then return obj, pos end
            if not delim_found then return nil end
            pos = skip_delim(str, pos, ':', true) -- true -> error if missing.
            obj[key], pos = json.parse(str, pos)
            pos, delim_found = skip_delim(str, pos, ',')
        end
    elseif first == '[' then -- Parse an array.
        local arr, val, delim_found = {}, true, true
        pos = pos + 1
        while true do
            val, pos = json.parse(str, pos, ']')
            if val == nil then return arr, pos end
            if not delim_found then return nil end
            arr[#arr + 1] = val
            pos, delim_found = skip_delim(str, pos, ',')
        end
    elseif first == '"' then -- Parse a string.
        return parse_str_val(str, pos + 1)
    elseif first == '-' or first:match('%d') then -- Parse a number.
        return parse_num_val(str, pos)
    elseif first == end_delim then -- End of an object or array.
        return nil, pos + 1
    else -- Parse true, false, or null.
        local literals = {
            ['true'] = true,
            ['false'] = false,
            ['null'] = json.null
        }
        for lit_str, lit_val in pairs(literals) do
            local lit_end = pos + #lit_str - 1
            if str:sub(pos, lit_end) == lit_str then
                return lit_val, lit_end + 1
            end
        end
        local pos_info_str = 'position ' .. pos .. ': ' ..
                                 str:sub(pos, pos + 10)
        return nil
    end
end
