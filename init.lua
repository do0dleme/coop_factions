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

local gen_def = dofile(minetest.get_modpath("coop_factions") .. "/utils/base.lua")
local actions = dofile(minetest.get_modpath("coop_factions") .. "/utils/actions.lua")

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
    params = "<faction>",
    privs = {
        faction_add = true,
        interact = true,
    },
    description = "Allow admins/moderators to add factions.",
    func = function(username, params)
        if minetest.deserialize(storage:get_string("factions")) then
            local facs = minetest.deserialize(storage:get_string("factions"))
            facs[#facs+1] = params
            print_all_of(facs)

            print(minetest.serialize(facs))

            storage:set_string("factions", minetest.serialize(facs))

            local x = minetest.deserialize(storage:get_string("faction_color"))
            if not x then
                x = {}
            end

            x[params] = {
                r = 255,
                b = 255,
                g = 255
            }

            storage:set_string("faction_color", minetest.serialize(x))
        else
            storage:set_string("factions", minetest.serialize({params}))

            local x = minetest.deserialize(storage:get_string("faction_color"))
            if not x then
                x = {}
            end

            x[params] = {
                r = 255,
                b = 255,
                g = 255
            }
            storage:set_string("faction_color", minetest.serialize(x))
        end
    end
})

minetest.register_chatcommand("start_faction", {
    params = "<faction>",
    privs = {start_faction = true},
    description = "Start a faction.",
    func = function(playerName, factionName)
        local factionNames = minetest.deserialize(storage:get_string("factions"))
        if not factionNames then
            factionNames = {}
        end
        factionNames[#factionNames+1] = factionName
        storage:set_string("factions", minetest.serialize(factionNames))
        minetest.chat_send_player(playerName, factionName .. " faction created.")

        local factionColors = minetest.deserialize(storage:get_string("faction_color"))
        if not factionColors then
            factionColors = {}
        end
        local factionColor = {r = 255, g = 255, b = 0}   -- Default the new faction's color to white.
        factionColors[factionName] = factionColor
        storage:set_string("faction_color", minetest.serialize(factionColors))
        local player = minetest.get_player_by_name(playerName)
        player:set_nametag_attributes({text = "(" .. factionName .. ") " .. playerName, color = factionColor})
        minetest.chat_send_player(playerName, factionName .. " faction's color (and yours) set to the default--white (255, 255, 255).")

        player:set_attribute("faction", factionName)
        factions.set_player_faction(playerName, factionName)
        minetest.chat_send_player(playerName, "Your faction set to " .. factionName .. ".")

        local privs = minetest.get_player_privs(playerName)
        privs.faction_leader = true
        minetest.set_player_privs(playerName, privs)
        minetest.chat_send_player(playerName, "Made you the leader of the " .. factionName .. " faction.")
    end
})

minetest.register_chatcommand("invite_to_faction", {
    params = "<player>",
    privs = {
        interact = true,
        faction_leader = true
    },
    description = "Invite a player into your faction.",
    func = function(playerInvitingName, playerInvitedName)
        local playerInviting = minetest.get_player_by_name(playerInvitingName)
        local playerInvited = minetest.get_player_by_name(playerInvitedName)

        if not playerInvited then
            return false, "Player, " .. playerInvitedName .. ", is not on-line."
        end

        local serializedInvitedToFactions = playerInvited:get_attribute("factions")
        local invitedToFactions
        if serializedInvitedToFactions then
            invitedToFactions = minetest.deserialize(serializedInvitedToFactions)
        else
            invitedToFactions = {}
        end
        local playerInvitingFaction = playerInviting:get_attribute("faction")
        invitedToFactions[#invitedToFactions+1] = playerInvitingFaction   -- Add faction of playerInviting who is inviting them to the list of factions to which this player is invited.

        playerInvited:set_attribute("factions", minetest.serialize(invitedToFactions))

        minetest.chat_send_player(playerInvitedName, "Player, " .. playerInvitingName .. ", invited you to their faction (" .. playerInvitingFaction .. ").")
        return true, "Player, " .. playerInvitedName .. ", invited to your faction (" .. playerInvitingFaction .. ")."
    end
})

minetest.register_chatcommand("join_faction", {
    params = "<faction>",
    privs = {
        interact = true,
        faction_leader = false
    },
    description = "Join a faction to which you've been invited.",
    func = function(playerJoiningName, factionName)
        local playerJoining = minetest.get_player_by_name(playerJoiningName)

        local serializedInvitedToFactions = playerJoining:get_attribute("factions")
        local invitedToFactions = minetest.deserialize(serializedInvitedToFactions)
        if not invitedToFactions then
            invitedToFactions = {}
        end

        if not has_value(invitedToFactions, factionName) then
            return false, "You haven't been invited to the " .. factionName .. " faction."
        end

        playerJoining:set_attribute("faction", factionName)
        factions.set_player_faction(playerJoiningName, factionName)

        local successMessage = "You've successfully joined the " .. factionName .. " faction."
        local serializedFactionColors = storage:get_string("faction_color")
        if not serializedFactionColors then
            return true, successMessage
        end

        local factionColors = minetest.deserialize(serializedFactionColors)
        if not factionColors then
            return true, successMessage
        end

        local factionColor = factionColors[factionName]
        if not factionColor then
            factionColor = {r = 255, g = 255, b = 255}
        end

        playerJoining:set_nametag_attributes({text = "(" .. factionName .. ") " .. playerJoiningName, color = factionColor})

        return true, successMessage
    end
})

minetest.register_chatcommand("faction_color", {
    params = "<r (0-255)> <g (0-255)> <b (0-255)>",
    privs = {
        interact = true,
        faction_leader = true
    },
    description = "Set your faction's color.",
    func = function(playerName, colorComponents)
        local player = minetest.get_player_by_name(playerName)
        colorComponents = string.split(colorComponents, " ")
        local r = colorComponents[1]
        local g = colorComponents[2]
        local b = colorComponents[3]

        if r == nil or g == nil or b == nil then
            return false, "<r (0-255)> <g (0-255)> <b (0-255)>"
        end

        local factionColors = minetest.deserialize(storage:get_string("faction_color"))

        local factionName = player:get_attribute("faction")
        local newColor = {r = tonumber(r), g = tonumber(g), b = tonumber(b)}
        factionColors[factionName] = newColor
        storage:set_string("faction_color", minetest.serialize(factionColors))

        for _, eachPlayer in ipairs(minetest.get_connected_players()) do
            local eachFactionName = eachPlayer:get_attribute("faction")
            if eachFactionName == factionName then
                local eachPlayerName = eachPlayer:get_player_name()
                eachPlayer:set_nametag_attributes({text = "(" .. factionName .. ") " .. eachPlayerName, color = newColor})
                minetest.chat_send_player(
                    eachPlayerName,
                    "The color of your faction (" .. factionName .. ") was just changed by " .. playerName .. "."
                )
            end
        end
    end
})

minetest.register_chatcommand("set_faction", {
    params = "<player> <faction>",

    description = "Set a player's faction.",
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

        local x = minetest.deserialize(storage:get_string("faction_color"))

        if not x then
            x = {}

            x[player:get_attribute("faction")] = {
                r = 255,
                g = 255,
                b = 255,
            }

            storage:set_string("faction_color", minetest.serialize(x))
        end

        local colors = x[player:get_attribute("faction")]

        if nick then
            player:set_nametag_attributes({text = "(" .. nick .. ")" .. " " .. player:get_player_name(), color = colors })
        end
    end
})

minetest.register_chatcommand("faction", {
    params = "",
    description = "Print your faction.",
    func = function(username, param)
        local user = minetest.get_player_by_name(username)
        if not user:get_attribute("faction") then
            return true, ""
        else
            return true, user:get_attribute("faction")
        end
    end
})

minetest.register_chatcommand("faction_msg", {
    params = "<message>",
    description = "Message everyone in faction.",
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
    description = "Add a faction.",
    give_to_singleplayer = false
})

minetest.register_privilege("faction_leader", {
    description = "Lead a faction.",
    give_to_singleplayer = false
})

minetest.register_privilege("set_faction", {
    description = "Set a player's faction.",
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

    -- Backward compatibility:
    if type(minetest.deserialize(player:get_attribute("faction"))) == "table" then
       player:set_attribute("faction", "neutral")
    end

    local playerFaction = player:get_attribute("faction")

    local playerName = player:get_player_name()
    if not factions.player_factions[playerName] then
        factions.player_factions[playerName] = playerFaction
        storage:set_string("player_factions", minetest.serialize(factions.player_factions))
    end

    local x = minetest.deserialize(storage:get_string("faction_color"))

    if not x then
        x = {}

        x[playerFaction] = {
            r = 255,
            b = 255,
            g = 255
        }

        storage:set_string("faction_color", minetest.serialize(x))
    end

    if minetest.settings:get_bool("allow_starting_faction") then
        local colors = x[playerFaction]
        local privs = minetest.get_player_privs(playerName)
        privs.start_faction = true
        minetest.set_player_privs(playerName, privs)
    end

    if playerFaction then
        player:set_nametag_attributes({text = "(" .. playerFaction .. ")" .. " " .. playerName, color = colors})
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
minetest.register_node("coop_factions:chest", chest)

minetest.register_craft({ -- Like the normal craft but logs instead of planks
    output = "coop_factions:chest", -- And there's a mese crystal in the middle
    recipe = {
        {"group:tree", "group:tree",           "group:tree"},
        {"group:tree", "default:mese_crystal", "group:tree"},
        {"group:tree", "group:tree",           "group:tree"},
    },
})

minetest.register_craft({ -- Or you can combine 4 normal chests
    output = "coop_factions:chest", -- around a mese crystal
    recipe = {
        {"",              "default:chest",        ""},
        {"default:chest", "default:mese_crystal", "default:chest"},
        {"",              "default:chest",        ""},
    },
})

minetest.register_craft({ -- Factions chests can be used as fuel in a furnace
    type = "fuel", -- with the same burn time as a normal default:chest
    recipe = "factions:chest",
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

minetest.register_tool("coop_factions:chest_remover", {
	  description = "Chest Remover (breaks non-empty chests)",
	  range = 100,
	  inventory_image = "factions_chest_remover.png",
	  groups = {not_in_creative_inventory = 1},
	  tool_capabilities = chest_remover_toolcaps,
})

minetest.register_on_punchnode(function(pos, node, puncher)
	  if puncher:get_wielded_item():get_name() == "coop_factions:chest_remover"
	  and minetest.get_node(pos).name ~= "air" then
		    -- The node is removed directly, which means it even works
		    -- on non-empty containers and group-less nodes
		    minetest.remove_node(pos)
		    -- Run node update actions like falling nodes
		    minetest.check_for_falling(pos)
	  end
end)
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

minetest.register_on_chat_message(function(name, message)
    if (minetest.settings:get_bool("no_chat_intercept")) then
        return false
    end
    if (minetest.get_player_by_name(name)) then
        local x = minetest.deserialize(storage:get_string("faction_color"))
        local player = minetest.get_player_by_name(name)
        if not x then
            x = {}

            x[player:get_attribute("faction")] = {
                r = 255,
                b = 255,
                g = 255
            }

            storage:set_string("faction_color", minetest.serialize(x))
        end

        local colors = x[player:get_attribute("faction")]
        minetest.chat_send_all(minetest.get_color_escape_sequence(rgb_to_hex(colors)) .. " [" .. minetest.get_player_by_name(name):get_attribute("faction") .. "]  <".. name .. "> " ..message)
        return true
    else
        return false
    end
end)
