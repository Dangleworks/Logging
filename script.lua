-- SETTINGS --
log_settings = {
    player_customcommand=true,
    player_chat=true,
    player_join=true,
    player_leave=true,
    player_sit=true,
    player_respawn=true,
    player_die=true,
    player_button_press=true,
    vehicle_spawn=true,
    vehicle_despawn=true,
    vehicle_damage=true,
    fire_extinguished=true,
    forest_fire_lit=true,
    forest_fire_extinguished=true,
    addon_component_spawn=true
}
log_port = 8000

log_requests = {
    player_customcommand="/log/player/command?steam_id=%s&peer_id=%s&name=%&is_admin=%s&is_auth=%s&command=%s",
    player_chat="/log/player/chat?peer_id=%s&name=%s&message=%s",
    player_join="/log/player/join?steam_id=%s&name=%s&peer_id=%s&is_admin=%s&is_auth=%s",
    player_leave="/log/player/leave?steam_id=%s&name=%s&peer_id=%s&is_admin=%s&is_auth=%s",
    player_sit="/log/player/sit?steam_id=%s&peer_id=%s&vehicle_id=%s&seat_name=%s",
    player_respawn="/log/player/respawn?steam_id=%s&name=%s&peer_id=%s",
    player_die="/log/player/die?steam_id=%s&name=%s&peer_id=%s&is_admin=%s&is_auth=%s",
    vehicle_spawn="/log/vehicle/spawn?vehicle_id=%d&peer_id=%d&x=%d&y=%d&z=%d&cost=%d&name=%s&mass=%d&voxels=%d",
    vehicle_despawn="/log/vehicle/despawn?vehicle_id=%d&peer_id=%d&x=%d&y=%d&z=%d",
    vehicle_teleport="/log/vehicle/teleport?vehicle_id=%d&peer_id=%d&x=%d&y=%d&z=%d",
    button_press="/log/player/buttonpress?vehicle_id=%d&peer_id=%d&button_name=%s"
}

-- CALLBACKS --
function onCreate(is_world_create)
end

function onCustomCommand(full_message, peer_id, is_admin, is_auth, command, ...)
    local req = string.format(log_requests.player_customcommand, 
        getSteamID(peer_id),
        peer_id,
        encode(getUserName(peer_id)),
        is_admin,
        is_auth,
        encode(full_message)
    )
    server.httpGet(log_port, req)
end

function onChatMessage(peer_id, sender_name, message)
    local req = string.format(log_requests.player_chat, 
        --getSteamID(user_peer_id),
        peer_id,
        encode(sender_name),
        encode(message)
    )
    server.httpGet(log_port, req)
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
    local req = string.format(log_requests.player_join, 
        steam_id,
        name,
        peer_id,
        is_admin,
        is_auth
    )
    server.httpGet(log_port, req)
end

function onPlayerSit(peer_id, vehicle_id, seat_name)
    local req = string.format(log_requests.player_sit, 
        getSteamID(peer_id),
        peer_id,
        vehicle_id,
        seat_name
    )
    server.httpGet(log_port, req)
end

function onPlayerRespawn(peer_id)
    local req = string.format(log_requests.player_respawn, 
        getSteamID(peer_id),
        getUserName(peer_id),
        peer_id
    )
    server.httpGet(log_port, req)
end

function onPlayerLeave(steam_id, name, peer_id, is_admin, is_auth)
    local req = string.format(log_requests.player_leave, 
        steam_id,
        name,
        peer_id,
        is_admin,
        is_auth
    )
    server.httpGet(log_port, req)
end

function onPlayerDie(steam_id, name, peer_id, is_admin, is_auth)
    local req = string.format(log_requests.player_die, 
        steam_id,
        name,
        peer_id,
        is_admin,
        is_auth
    )
    server.httpGet(log_port, req)
end

vehicle_spawn_details = {}

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
    vehicle_spawn_details[vehicle_id] = {
        peer_id=peer_id,
        x=x,
        y=y,
        z=z,
        cost=cost
    }
end

function onVehicleLoad(vehicle_id)
    local vehicle_details, ok = server.getVehicleDetails(vehicle_id)
    local req = string.format(log_requests.vehicle_spawn, 
        vehicle_id,
        vehicle_spawn_details[vehicle_id].peer_id,
        vehicle_spawn_details[vehicle_id].x,
        vehicle_spawn_details[vehicle_id].y,
        vehicle_spawn_details[vehicle_id].z,
        vehicle_spawn_details[vehicle_id].cost,
        encode(vehicle_details.filename),
        vehicle_details.mass,
        vehicle_details.voxels
    )
    server.httpGet(log_port, req)
    vehicle_spawn_details[vehicle_id] = nil
end

function onVehicleDespawn(vehicle_id, peer_id)
    local vehicle_details, ok = server.getVehicleDetails(vehicle_id)
    if not ok then
        vehicle_details = {
            x=0,
            y=0,
            z=0
        }
    end

    -- make sure to check the case of a vehicle being spawned, but not loaded
    if vehicle_spawn_details[vehicle_id] ~= nil then
        vehicle_details = vehicle_spawn_details[vehicle_id]
    end

    local req = string.format(log_requests.vehicle_despawn, 
        vehicle_id,
        peer_id,
        vehicle_details.x,
        vehicle_details.y,
        vehicle_details.z
    )

    server.httpGet(log_port, req)
    vehicle_spawn_details[vehicle_id] = nil
end

function onVehicleTeleport(vehicle_id, peer_id, x, y, z)
    local req = string.format(log_requests.vehicle_teleport, 
        vehicle_id,
        peer_id,
        x,
        y,
        z
    )

    server.httpGet(log_port, req)
end

function onButtonPress(vehicle_id, peer_id, button_name)
    local req = string.format(log_requests.button_press, 
        vehicle_id,
        peer_id,
        encode(button_name)
    )

    server.httpGet(log_port, req)
end

function onVehicleDamaged(vehicle_id, damage_amount, voxel_x, voxel_y, voxel_z)
end

function onFireExtinguished(fire_x, fire_y, fire_z)
end

function onForestFireSpawned(fire_objective_id, fire_x, fire_y, fire_z)
end

function onForestFireExtinguished(fire_objective_id, fire_x, fire_y, fire_z)
end

-- object_id/vehicle_id, component_name, TYPE_STRING, addon_index
function onSpawnAddonComponent(component_id, component_name, TYPE_STRING, addon_index)
end


-- UTIL --
function encode(str)
    local function cth(c)
        return string.format("%%%02X", string.byte(c))
    end
	if str == nil then
		return ""
	end
	str = string.gsub(str, "([^%w _ %- . ~])", cth)
	str = str:gsub(" ", "%%20")
	return str
end

function getSteamID(peer_id)
    for _, p in pairs(server.getPlayers()) do
		if tostring(p.id) == peer_id then
			return p.steam_id
		end
	end
end

function getUserName(peer_id)
    if peer_id == -1 then
        return "Server"
    end

    local name, ok = server.getPlayerName(peer_id)
    if not ok then
        return "Unknown"
    end

    return name
end