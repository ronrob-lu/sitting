-- Sit on Beds Mod
-- Author: ronrob-lu
-- License: MIT
-- Allows players to sit on beds during daytime

local players_sitting = {}

-- Check if it's daytime (sun visibility and time of day)
local function is_daytime()
    local time = minetest.get_time()
    if not time then
        return true
    end
    -- Time is between 0.2 (dawn) and 0.708 (dusk) approximately
    return time >= 0.2 and time < 0.708
end

-- Make a player sit on a bed
local function sit_on_bed(player, pos, yaw)
    local pname = player:get_player_name()
    
    -- Store player state
    players_sitting[pname] = {
        pos = vector.round(pos),
        yaw = yaw,
        original_velocity = player:get_velocity()
    }
    
    -- Set player as attached to the bed position
    player:set_attach(pos, "", {x = 0, y = 0.5, z = 0}, {x = 0, y = 0, z = 0})
    
    -- Set the player's rotation to match the bed
    player:set_look_horizontal(yaw)
    
    -- Override the player's movement to prevent walking
    player:set_physics_override({
        speed = 0,
        jump = 0,
        gravity = 0,
        sneak = false,
        sneak_glitch = false,
        new_move = false
    })
    
    minetest.chat_send_player(pname, "You are now sitting. Press sneak to stand up.")
end

-- Make a player stand up from a bed
local function stand_up(player)
    local pname = player:get_player_name()
    
    if not players_sitting[pname] then
        return false
    end
    
    local sit_data = players_sitting[pname]
    
    -- Detach player from the bed
    player:set_detach()
    
    -- Restore physics
    player:set_physics_override({
        speed = 1,
        jump = 1,
        gravity = 1,
        sneak = true,
        sneak_glitch = true,
        new_move = true
    })
    
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
            if player:get_control().sneak then
                stand_up(player)
            else
                -- Keep player positioned correctly while allowing look rotation
                local current_pos = player:get_pos()
                local expected_pos = vector.add(sit_data.pos, {x = 0, y = 0.5, z = 0})
                
                -- Only update position if significantly different (to avoid jitter)
                if vector.distance(current_pos, expected_pos) > 0.1 then
                    player:set_pos(expected_pos)
                end
            end
        else
            -- Player disconnected, clean up
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
    return function(pos, node, clicker)
        if not clicker or not clicker:is_player() then
            if original_callback then
                return original_callback(pos, node, clicker)
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
            sit_on_bed(clicker, pos, yaw)
            return
        end
        
        -- If nighttime, use original behavior (sleep)
        if original_callback then
            return original_callback(pos, node, clicker)
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
