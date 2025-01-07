-- Better Crates
-- Klehrik

mods["MGReturns-ENVY"].auto()
mods["RoRRModdingToolkit-RoRR_Modding_Toolkit"].auto(true)

-- preserve module data across reloads
M = M or {}
local M = M

M.pre_initialized = false
M.post_initialized = false
function M.is_fully_initialized()
    return M.pre_initialized and M.post_initialized
end



-- ========== Main ==========

function M.pre_initialize()
    -- Add Cancel item
    local cancel_item = Item.new("betterCrates", "cancel", true)
    M.cancel_item = cancel_item
    cancel_item:set_sprite(Resources.sprite_load("betterCrates", "cancel", _PLUGIN["plugins_mod_folder_path"].."/sCancel.png", 1, 16, 16))
    cancel_item:toggle_loot(false)


    -- Packet
    local packet_selection = M.packet_selection
    if packet_selection == nil then
        packet_selection = Packet.new()
        M.packet_selection = packet_selection
    end
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


    local function obj_on_step_callback(inst)
        local instData = inst:get_data()
        local actor = inst.activator

        if inst.active == 0 then
            instData.loaded_selection = nil
            instData.prev_selection = -1

        -- Cancel crate selection if Cancel is selected
        elseif inst.active >= 3 then
            -- Save selection
            if Player.get_client():same(actor) then
                M.saved_selections[inst.__object_index] = inst.selection
            end

            if inst.contents:get(inst.selection) == cancel_item.object_id then
                log.info("Cancelling!")
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
    end
    local function add_obj_callbacks(obj)
        obj:onStep(obj_on_step_callback)
    end


    -- Add callback to vanilla crates
    local count = gm.array_length(gm.variable_global_get("custom_object"))
    for id = 0, count - 1 do
        local obj = Object.wrap(id + Object.CUSTOM_START)
        if obj.base == gm.constants.oCustomObject_pInteractableCrate then
            add_obj_callbacks(obj)
        end
    end


    -- Add callback to future crate-type interactables
    -- as the first onStep callback
    gm.post_script_hook(gm.constants.object_add_w, function(self, other, result, args)
        if args[3].value == gm.constants.pInteractableCrate then
            local obj = Object.wrap(result.value)
            add_obj_callbacks(obj)
        end
    end)
end

if not Initialize(M.pre_initialize) then
    M.pre_initialize()
end

-- Post-initialize

function M.post_initialize()
    local function obj_on_step_callback(inst)
        local instData = inst:get_data()
        local actor = inst.activator

        if inst.active == 1 then
            if not inst.contents then return end

            -- Insert Cancel item
            local contents = inst.contents
            if not contents:contains(cancel_item.object_id) then

                -- Delete existing copies of Cancel
                local size = #contents
                for i = size - 1, 0, -1 do
                    if contents:get(i) == cancel_item.object_id then
                        contents:delete(i)
                    end
                end

                contents:insert(0, cancel_item.object_id)
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
                and M.saved_selections[inst.__object_index] then
                    instData.loaded_selection = true
                    inst.selection = math.min(M.saved_selections[inst.__object_index], #contents - 1)
                end
            end

        end
    end
    local function add_obj_callbacks(obj)
        obj:onStep(obj_on_step_callback)
    end


    -- Add callback to all crate-type interactables
    -- as the last onStep callback
    local count = gm.array_length(gm.variable_global_get("custom_object"))
    for id = 0, count - 1 do
        local obj = Object.wrap(id + Object.CUSTOM_START)
        if obj.base == gm.constants.oCustomObject_pInteractableCrate then
            add_obj_callbacks(obj)
        end
    end
end

if not Initialize(M.post_initialize, true) then
    M.post_initialize()
end

gm.post_script_hook(gm.constants.run_create, function(self, other, result, args)
    M.saved_selections = {}
    if M.hud_draw_alarm ~= nil then
        M.hud_draw_alarm:destroy()
    end

    M.hud_draw_alarm = Alarm.create(function()
        local hud = Instance.find(gm.constants.oHUD)
        if hud:exists() then hud.command_draw_id:push(-4) end
    end, 6)
end)

gm.post_script_hook(gm.constants.run_destroy, function(self, other, result, args)
    M.saved_selections = {}
    if M.hud_draw_alarm ~= nil then
        M.hud_draw_alarm:destroy()
        M.hud_draw_alarm = nil
    end
end)
