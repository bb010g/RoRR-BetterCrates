-- Better Crates
-- Klehrik

mods["RoRRModdingToolkit-RoRR_Modding_Toolkit"].auto()

local item
local saved = {}



-- ========== Main ==========

Initialize(function()
    -- Add Cancel item
    item = Item.new("betterCrates", "cancel", true)
    item:set_sprite(Resources.sprite_load("betterCrates", "cancel", _ENV["!plugins_mod_folder_path"].."/sCancel.png", 1, 16, 16))
    item:set_tier(Item.TIER.notier)
    item:toggle_loot(false)
end)


-- Post-initialization

Initialize(function()
    -- Add callback to all crate-type interactables
    local count = gm.array_length(gm.variable_global_get("custom_object"))
    for id = 0, count - 1 do
        local obj = Object.wrap(id + Object.CUSTOM_START)
        if obj.base == gm.constants.oCustomObject_pInteractableCrate then

            obj:onStep(function(inst)
                local instData = inst:get_data()

                -- Insert Cancel item
                if inst.active == 0 then instData.selection = nil
                elseif inst.active == 1 then
                    if not inst.contents:contains(item.object_id) then
                        inst.contents:insert(0, item.object_id)
                    end

                    -- Load saved selection if it exists
                    if  not instData.selection
                    and saved[inst.__object_index] then
                        instData.selection = true
                        inst.selection = saved[inst.__object_index]
                    end

                -- Cancel crate selection if Cancel is selected
                elseif inst.active >= 3 then
                    -- Save selection
                    saved[inst.__object_index] = inst.selection

                    if inst.contents:get(inst.selection) == item.object_id then
                        inst.active = 0

                        -- Hide item UI
                        inst.last_move_was_mouse = true
                        inst.owner = -4
                        inst.did_alarm = false
                        inst.fade_alpha = 0.0

                        -- Free actor activity
                        local actor = inst.activator
                        actor.activity = 0.0
                        actor.activity_free = true
                        actor.activity_move_factor = 1.0
                        actor.activity_type = 0.0
                    end

                end
            end)

        end
    end
end, true)


gm.pre_script_hook(gm.constants.run_create, function()
    saved = {}
end)