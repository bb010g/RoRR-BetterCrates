-- Better Crates
-- Klehrik

mods["MGReturns-ENVY"].auto()
mods["RoRRModdingToolkit-RoRR_Modding_Toolkit"].auto(true)

local item
local packet_selection

local saved = {}



-- ========== Main ==========

Initialize(function()
    -- Add Cancel item
    item = Item.new("betterCrates", "cancel", true)
    item:set_sprite(Resources.sprite_load("betterCrates", "cancel", _PLUGIN["plugins_mod_folder_path"].."/sCancel.png", 1, 16, 16))
    item:toggle_loot(false)


    -- Packet
    packet_selection = Packet.new()
    packet_selection:onReceived(function(message, player)
        local crate = message:read_instance()
        local selection = message:read_ushort()

        crate.selection = selection

        -- [Host]  Send to all players
        if Net.is_host() then
            local message = packet_selection:message_begin()
            message:write_instance(crate)
            message:write_ushort(selection)
            message:send_exclude(player)
        end
    end)


    local function add_callback(obj)
        obj:onStep(function(inst)
            local instData = inst:get_data()
            local actor = inst.activator

            if inst.active == 0 then
                instData.loaded_selection = nil
                instData.prev_selection = -1

            -- Cancel crate selection if Cancel is selected
            elseif inst.active >= 3 then
                -- Save selection
                if Player.get_client():same(actor) then
                    saved[inst.__object_index] = inst.selection
                end

                if inst.contents:get(inst.selection) == item.object_id then
                    inst.active = 0

                    -- Hide item UI
                    inst.last_move_was_mouse = true
                    inst.owner = -4

                    -- Free actor activity
                    actor.activity = 0.0
                    actor.activity_free = true
                    actor.activity_move_factor = 1.0
                    actor.activity_type = 0.0
                end

            end
        end)
    end


    -- Add callback to vanilla crates
    local count = gm.array_length(gm.variable_global_get("custom_object"))
    for id = 0, count - 1 do
        local obj = Object.wrap(id + Object.CUSTOM_START)
        if obj.base == gm.constants.oCustomObject_pInteractableCrate then
            add_callback(obj)
        end
    end


    -- Add callback to future crate-type interactables
    -- as the first onStep callback
    gm.post_script_hook(gm.constants.object_add_w, function(self, other, result, args)
        if args[3].value == gm.constants.pInteractableCrate then
            local obj = Object.wrap(result.value)
            add_callback(obj)
        end
    end)
end)


-- Post-initialize

Initialize(function()
    local function add_callback(obj)
        obj:onStep(function(inst)
            local instData = inst:get_data()
            local actor = inst.activator

            if inst.active == 1 then
                if not inst.contents then return end

                -- Insert Cancel item
                local contents = inst.contents
                if not contents:contains(item.object_id) then

                    -- Delete existing copies of Cancel
                    local size = #contents
                    for i = size - 1, 0, -1 do
                        if contents:get(i) == item.object_id then
                            contents:delete(i)
                        end
                    end

                    contents:insert(0, item.object_id)
                end

                if Player.get_client():same(actor) then
                    -- Sync current crate contents
                    if not instData.synced then
                        instData.synced = true
                        Helper.sync_crate_contents(inst)
                    end

                    -- Sync selection
                    if inst.selection ~= instData.prev_selection then
                        instData.prev_selection = inst.selection

                        local message = packet_selection:message_begin()
                        message:write_instance(inst)
                        message:write_ushort(inst.selection)
                        if      Net.is_host()   then message:send_to_all()
                        elseif  Net.is_client() then message:send_to_host()
                        end
                    end

                    -- Load saved selection if it exists
                    -- This is intentionally after "Sync selection"
                    -- for a 1-frame delay; do not move
                    if  not instData.loaded_selection
                    and saved[inst.__object_index] then
                        instData.loaded_selection = true
                        inst.selection = math.min(saved[inst.__object_index], #contents - 1)
                    end
                end

            end
        end)
    end


    -- Add callback to all crate-type interactables
    -- as the last onStep callback
    local count = gm.array_length(gm.variable_global_get("custom_object"))
    for id = 0, count - 1 do
        local obj = Object.wrap(id + Object.CUSTOM_START)
        if obj.base == gm.constants.oCustomObject_pInteractableCrate then
            add_callback(obj)
        end
    end
end, true)


gm.post_script_hook(gm.constants.run_create, function(self, other, result, args)
    saved = {}

    Alarm.create(function()
        local hud = Instance.find(gm.constants.oHUD)
        if hud:exists() then hud.command_draw_id:push(-4) end
    end, 6)
end)
