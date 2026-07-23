-- Sit on Beds Mod
-- Author: ronrob-lu
-- License: MIT
-- Allows players to sit on beds during daytime

local players_sitting = {}

-- Check if it's daytime (sun visibility and time of day)
local function is_daytime()
    local time = nil

    -- Try different time APIs depending on Minetest/Luanti version
    if minetest.get_day_time then
        time = minetest.get_day_time()
    elseif minetest.get_time then
        local t = minetest.get_time()
        if type(t) == "table" then
            time = t.day or 0
        elseif type(t) == "number" then
            time = t
        end
    end

    -- Fallback to midday if no time API available
    if time == nil then
        time = 0.5
    end

    -- Time is between 0.2 (dawn) and 0.708 (dusk) approximately
    return time >= 0.2 and time < 0.708
end

-- Register the seat entity (invisible object to attach players to)
minetest.register_entity("sit_on_beds:seat", {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        visual = "sprite",
        visual_size = {x = 0.01, y = 0.01},
        textures = {"blank.png"},
        pointable = false,
        static_save = false,
        hp_max = 999999,
        armor_groups = {immortal = 100},
    },
    on_step = function(self, dtime)
        -- Keep the entity stationary
        self.object:set_velocity({x = 0, y = 0, z = 0})
        self.object:set_acceleration({x = 0, y = 0, z = 0})
    end,
})

-- Make a player sit on a bed
local function sit_on_bed(player, pos, yaw)
    local pname = player:get_player_name()

    -- Create invisible seat entity at the sitting position
    local sit_pos = vector.add(pos, {x = 0.5, y = 0.5, z = 0.5})
    local seat = minetest.add_entity(sit_pos, "sit_on_beds:seat")
    
    if not seat then
        minetest.chat_send_player(pname, "Failed to create seat.")
        return false
    end

    -- Set the seat's rotation
    seat:set_yaw(yaw)

    -- Store player state
    players_sitting[pname] = {
        pos = vector.round(pos),
        yaw = yaw,
        seat = seat
    }

    -- Attach player to the seat entity
    player:set_attach(seat, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})

    -- Set the player's rotation to match the bed
    player:set_look_horizontal(yaw)

    minetest.chat_send_player(pname, "You are now sitting. Press sneak to stand up.")
    return true
end

-- Make a player stand up from a bed
local function stand_up(player)
    local pname = player:get_player_name()

    if not players_sitting[pname] then
        return false
    end

    local sit_data = players_sitting[pname]

    -- Detach player from the seat
    player:set_detach()

    -- Remove the seat entity
    if sit_data.seat and sit_data.seat:get_luaentity() then
        sit_data.seat:remove()
    end

    -- Position player next to the bed
    local new_pos = vector.add(sit_data.pos, {x = 0.5, y = 0, z = 0.5})
    player:set_pos(new_pos)

    -- Restore look direction
    player:set_look_horizontal(sit_data.yaw)

    -- Clear sitting data
    players_sitting[pname] = nil

    minetest.chat_send_player(pname, "You stood up.")

    return true
end

-- Check if a node is a bed
local function is_bed(node)
    local nodedef = minetest.registered_nodes[node.name]
    if not nodedef then
        return false
    end

    -- Check if node has bed group
    if nodedef.groups and nodedef.groups.bed then
        return true
    end

    -- Check for common bed node names
    if string.find(node.name, "bed") then
        return true
    end

    return false
end

-- Get the yaw/rotation for sitting based on node direction
local function get_sit_yaw(pos, node)
    local nodedef = minetest.registered_nodes[node.name]
    if nodedef and nodedef.paramtype2 == "facedir" then
        local facedir = minetest.get_node(pos).param2
        -- Convert facedir to yaw
        return facedir * math.pi / 32
    end
    return 0
end

-- Register globalstep to handle sitting players
minetest.register_globalstep(function(dtime)
    for pname, sit_data in pairs(players_sitting) do
        local player = minetest.get_player_by_name(pname)
        if player then
            -- Check if player wants to stand up (sneak key)
            local controls = player:get_player_control()
            if controls and controls.sneak then
                stand_up(player)
            end
            -- Player can look around freely while attached, no need to update position
        else
            -- Player disconnected, clean up
            if sit_data.seat and sit_data.seat:get_luaentity() then
                sit_data.seat:remove()
            end
            players_sitting[pname] = nil
        end
    end
end)

-- Register chat command to force stand up
minetest.register_chatcommand("stand", {
    params = "",
    description = "Stand up from sitting position",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            if stand_up(player) then
                return true, "You stood up."
            else
                return false, "You are not sitting."
            end
        end
        return false, "Player not found."
    end
})

-- Hook into bed interactions
-- We need to intercept the bed's on_rightclick
local function wrap_bed_on_rightclick(original_callback)
    return function(pos, node, clicker, itemstack, pointed_thing)
        if not clicker or not clicker:is_player() then
            if original_callback then
                return original_callback(pos, node, clicker, itemstack, pointed_thing)
            end
            return
        end

        local pname = clicker:get_player_name()

        -- Check if already sitting
        if players_sitting[pname] then
            stand_up(clicker)
            return
        end

        -- Check if it's daytime
        if is_daytime() then
            -- Get the yaw for sitting
            local yaw = get_sit_yaw(pos, node)

            -- Sit on the bed
            if sit_on_bed(clicker, pos, yaw) then
                return
            end
        end

        -- If nighttime, use original behavior (sleep)
        if original_callback then
            return original_callback(pos, node, clicker, itemstack, pointed_thing)
        end
    end
end

-- Override existing bed nodes
for nodename, nodedef in pairs(minetest.registered_nodes) do
    if is_bed({name = nodename}) then
        if nodedef.on_rightclick then
            -- Wrap the existing on_rightclick
            local original = nodedef.on_rightclick
            minetest.override_item(nodename, {
                on_rightclick = wrap_bed_on_rightclick(original)
            })
        else
            -- Add on_rightclick if it doesn't exist
            minetest.override_item(nodename, {
                on_rightclick = wrap_bed_on_rightclick(nil)
            })
        end
    end
end

-- Register callback for when new nodes are registered (for compatibility with mods loaded after this one)
local old_register_node = minetest.register_node
minetest.register_node = function(name, def)
    old_register_node(name, def)

    -- Check if this is a bed and wrap its on_rightclick
    if is_bed({name = name}) then
        if def.on_rightclick then
            local original = def.on_rightclick
            minetest.override_item(name, {
                on_rightclick = wrap_bed_on_rightclick(original)
            })
        else
            minetest.override_item(name, {
                on_rightclick = wrap_bed_on_rightclick(nil)
            })
        end
    end
end

minetest.log("action", "[sit_on_beds] Mod loaded. Players can now sit on beds during daytime.")
