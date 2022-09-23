----------------------------------------------
----------------------------------------------
------ 'FACTIONS' MOD FOR MINETEST GAME ------
----------------------------------------------
----------------------------------------------
---- see LICENSE.txt for more information ----
----------------------------------------------
----------------------------------------------

--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--

-------------------------
---- Misc init stuff ----
-------------------------

local modName = "coop_factions"
local utilsPath = minetest.get_modpath(modName).."/utils/"
local gen_def = dofile(utilsPath.."base.lua")
local actions = dofile(utilsPath.."actions.lua")

nametag_mgr.register_mod(modName, " (", " faction)")

factions = {}

local storage = minetest.get_mod_storage()
if minetest.deserialize(storage:get_string("player_factions")) then
    factions.player_factions = minetest.deserialize(storage:get_string("player_factions"))
else
    factions.player_factions = {}
    storage:set_string("player_factions", minetest.serialize({}))
end

function factions.get_player_faction(username)
    return factions.player_factions[username]
end

function factions.set_player_faction(username, faction)
   factions.player_factions[username] = faction
   storage:set_string("player_factions", minetest.serialize(factions.player_factions))
end

local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local function print_all_of(tab)
    for index, value in ipairs(tab) do
        print(value)
    end
end

-----------------------
---- Chat commands ----
-----------------------

minetest.register_chatcommand("add_faction", {
    params = "<faction name>",
    privs = {
        faction_add = true,
        interact = true,
    },
    description = "Allows admins/moderators to add factions",
    func = function(username, params)
        if minetest.deserialize(storage:get_string("factions")) then
            local facs = minetest.deserialize(storage:get_string("factions"))
            facs[#facs+1] = params
            print_all_of(facs)

            print(minetest.serialize(facs))

            storage:set_string("factions", minetest.serialize(facs))
        else
            storage:set_string("factions", minetest.serialize({params}))
        end
    end
})

local function rgb_to_hex(rgb)
    local hexadecimal = '#'
    for key, fval in ipairs({'r', 'g', 'b'}) do
        local value = tonumber(rgb[fval])
        local hex = ''
        while(value > 0) do
            local index = math.fmod(value, 16) + 1
            value = math.floor(value / 16)
            hex = string.sub('0123456789ABCDEF', index, index) .. hex            
        end

        if(string.len(hex) == 0)then
            hex = '00'

        elseif(string.len(hex) == 1)then
            hex = '0' .. hex
        end

        hexadecimal = hexadecimal .. hex
    end
    return hexadecimal
end

minetest.register_chatcommand("start_faction", {
    params = "<faction name>",
    privs = {
        start_faction = true
    },
    description = "Allows users to start factions",
    func = function(username, params)
        local user = minetest.get_player_by_name(username)
        if minetest.deserialize(storage:get_string("factions")) then
            local facs = minetest.deserialize(storage:get_string("factions"))
            facs[#facs+1] = params
            print_all_of(facs)

            print(minetest.serialize(facs))

            storage:set_string("factions", minetest.serialize(facs))
        else
            storage:set_string("factions", minetest.serialize({params}))
        end
        user:set_attribute("faction", params)
        local nick = user:get_attribute("faction")
        factions.set_player_faction(username, nick)

        local privs = minetest.get_player_privs(username)
        privs.faction_leader = true
        minetest.set_player_privs(username, privs)

        nametag_mgr.register_mod_group(modName, params)
        nametag_mgr.set_player_mod_group(username, modName, params)
        
        minetest.chat_send_player(username, "Created the "..params.." faction, with you as leader.")
    end
})

minetest.register_chatcommand("invite_to_faction", {
    params = "<faction name>",
    privs = {
        interact = true,
        faction_leader = true
    },
    description = "Invite a player into a faction",
    func = function(username, param)
        local user = minetest.get_player_by_name(username)
        local player = minetest.get_player_by_name(param)

        if not player then
            return false, "That player does not exist or is not online."
        end

        local userFaction = user:get_attribute("faction")
        if player:get_attribute("factions") then
            local facs = minetest.deserialize(player:get_attribute("factions"))
            facs[#facs+1] = userFaction
            print_all_of(facs)

            player:set_attribute("factions", minetest.serialize(facs))
        else
            player:set_attribute("factions", minetest.serialize({userFaction}))
        end

        minetest.chat_send_player(param, username.." invited you to their (the "..userFaction..") faction.")
        return true, "Invited "..param.." to your (the "..userFaction..") faction."
    end
})

minetest.register_chatcommand("join_faction", {
    params = "<faction name>",
    privs = {
        interact = true,
        faction_leader = false
    },
    description = "Join a faction to which you've been invited.",
    func = function(username, param)
        local user = minetest.get_player_by_name(username)

        if not minetest.deserialize(user:get_attribute("factions")) then
            user:set_attribute("factions", minetest.serialize({"neutral"}))
        end

        if has_value(minetest.deserialize(user:get_attribute("factions")), param) then
            user:set_attribute("faction", param)
        else
            return false, "You haven't been invited to the "..param.." faction."
        end

        local nick = user:get_attribute("faction")
        factions.set_player_faction(username, nick)
        
        nametag_mgr.set_player_mod_group(username, modName, param)
        
        return true, "You've joined the "..param.." faction."
    end
})

minetest.register_chatcommand("set_faction_color", {
    params = "<red> <green> <blue>",
    privs = {
        interact = true,
        faction_leader = true
    },
    description = "Set the color of a faction",
    func = function(username, param)
        local user = minetest.get_player_by_name(username)
        local params = string.split(param, " ")
        local red = params[1]
        local green = params[2]
        local blue = params[3]

        if red == nil or green == nil or blue == nil then
            return false, "<red> <green> <blue>"
        end

        local factionName = user:get_attribute("faction")
        local rgb = {
            r = tonumber(red),
            g = tonumber(green),
            b = tonumber(blue),
        }

        local hexColor = rgb_to_hex(rgb)
        nametag_mgr.register_mod_group(modName, factionName, hexColor)
        
        return true, "Updated the color of your faction ("..factionName..") to "..hexColor.."."
    end
})

minetest.register_chatcommand("set_faction", {
    params = "<player> <faction name>",

    description = "Set the faction of a player",
    func = function(username, param)
        local user = minetest.get_player_by_name(username)

        local i = 0
        local to = ""
        local tab = {}

        for word in string.gmatch(param, "([^%s]+)") do
            if i == 0 then
                to = word
            else
                table.insert(tab, word)
            end

            i = i + 1
        end

        local faction = table.concat(tab, " ")

        if to == nil or faction == nil then
            print(to)
            print(faction)
            return false, "Usage: /set_faction <user> <faction>"
        end

        local player = minetest.get_player_by_name(to)

        if has_value(minetest.deserialize(storage:get_string("factions")), faction) then
            if player then
                player:set_attribute("faction", faction)
            else
                return false, "That player does not exist or is not online"
            end
        else
            return false, "That faction does not exist."
        end

        local nick = player:get_attribute("faction")
        factions.set_player_faction(to, nick)
    end
})

minetest.register_chatcommand("faction", {
    params = "",
    description = "Print your faction",
    func = function(username, param)
        local user = minetest.get_player_by_name(username)
        local factionName = user:get_attribute("faction")
        if not factionName then
            return false, "You're not in a faction."
        end
        return true, "You're in the "..factionName.." faction."
    end
})

minetest.register_chatcommand("faction_msg", {
    params = "<message>",
    description = "Message everyone in faction",
    func = function(username, param)
        local text = username .. " said to your faction: " .. param
        local sender_faction = minetest.get_player_by_name(username):get_attribute("faction")

        for _, player in ipairs(minetest.get_connected_players()) do
            if player:get_attribute("faction") == sender_faction then
                minetest.chat_send_player(player:get_player_name(), text)
            end
        end 
    end
})

minetest.register_privilege("faction_add", {
    description = "Add faction",
    give_to_singleplayer = false
})

minetest.register_privilege("faction_leader", {
    description = "Lead a faction",
    give_to_singleplayer = false
})

minetest.register_privilege("set_faction", {
    description = "Set a player's faction",
    give_to_singleplayer = false
})

minetest.register_privilege("start_faction", {
    description = "Start a faction.",
    give_to_singleplayer = false
})

--------------------------------------------------------
---- Assign players to 'neutral' faction by default ----
--------------------------------------------------------

minetest.register_on_joinplayer(function(player)
    if not player:get_attribute("faction") then
        player:set_attribute("faction", "neutral")
    end

    if type(minetest.deserialize(player:get_attribute("faction"))) == "table" then
       player:set_attribute("faction", "neutral")
    end

    local nick = player:get_attribute("faction")

    if not factions.player_factions[player:get_player_name()] then
        factions.player_factions[player:get_player_name()] = nick
        storage:set_string("player_factions", minetest.serialize(factions.player_factions))
    end

    if minetest.settings:get_bool("allow_starting_faction") then
        local privs = minetest.get_player_privs(player:get_player_name())
        privs.start_faction = true
        minetest.set_player_privs(player:get_player_name(), privs)
    end
end) 

------------------------------------------
---- Faction chest functionality code ----
------------------------------------------

function has_locked_chest_privilege(meta, player)
    if player:get_player_name() ~= meta:get_string("faction_owner") then
        return false
    end

    return true
end

local chest = gen_def({
    description = "Factions chest",
    type = "chest",
    size = "small",
    tiles = {
        top = "factions_chest_top.png",
        side = "factions_chest_right.png",
        front ="factions_chest_front.png"
    },
    pipeworks_enabled = false,
    allow_metadata_inventory_move = false,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
        local meta = minetest.get_meta(pos)

        if actions.has_locked_chest_privilege(meta, player) then
            return stack:get_count()
        end

        local target = meta:get_inventory():get_list(listname)[index]
        local target_name = target:get_name()
        local stack_count = stack:get_count()

        if target_name == stack:get_name()
        and target:get_count() < stack_count then
            return stack_count
        end

        if target_name ~= "" then
            return 0
        end

        return stack_count
    end,
    allow_metadata_inventory_take = actions.get_allow_metadata_inventory_take({
        "dropbox", check_privs = actions.has_locked_chest_privilege
    }),
})

---------------------------
---- Registering nodes ----
---------------------------

-- Factions Chest
local chestName = modName..":chest"
minetest.register_node(chestName, chest)

minetest.register_craft({ -- Like the normal craft but logs instead of planks
    output = chestName, -- And there's a mese crystal in the middle
    recipe = {
        {"group:tree", "group:tree",           "group:tree"},
        {"group:tree", "default:mese_crystal", "group:tree"},
        {"group:tree", "group:tree",           "group:tree"},
    },
})

minetest.register_craft({ -- Or you can combine 4 normal chests
    output = chestName, -- around a mese crystal
    recipe = {
        {"",              "default:chest",        ""},
        {"default:chest", "default:mese_crystal", "default:chest"},
        {"",              "default:chest",        ""},
    },
})

minetest.register_craft({ -- Factions chests can be used as fuel in a furnace
    type = "fuel", -- with the same burn time as a normal default:chest
    recipe = chestName,
    burntime = 30,
})

--------------------------------------------------------------
---- Chest remover tool (instamine pickaxe, removes nodes ----
---- by calling minetest.remove_node(), so it can even    ----
---- remove non-empty chests which you can't do normally) ----
--------------------------------------------------------------

local chest_remover_toolcaps = { -- Everything takes 0 seconds to mine
    full_punch_interval = 0.1,
    max_drop_level = 3,
    groupcaps = {
	      unbreakable = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
	      fleshy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
	      choppy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
	      bendy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
	      cracky = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
	      crumbly = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
	      snappy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0, maxlevel = 3},
    },
    damage_groups = {fleshy = 1000}, -- 1000 damage - also a very powerful weapon
}

local chestRemoverName = modName..":chest_remover"
minetest.register_tool(chestRemoverName, {
	  description = "Chest Remover (breaks non-empty chests)",
	  range = 100,
	  inventory_image = "factions_chest_remover.png",
	  groups = {not_in_creative_inventory = 1},
	  tool_capabilities = chest_remover_toolcaps,
})

minetest.register_on_punchnode(function(pos, node, puncher)
	  if puncher:get_wielded_item():get_name() == chestRemoverName
	  and minetest.get_node(pos).name ~= "air" then
		    -- The node is removed directly, which means it even works
		    -- on non-empty containers and group-less nodes
		    minetest.remove_node(pos)
		    -- Run node update actions like falling nodes
		    minetest.check_for_falling(pos)
	  end
end)
