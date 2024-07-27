-- Better Crates v1.0.0
-- Klehrik

log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

local sCancel = gm.sprite_add(_ENV["!plugins_mod_folder_path"].."/sCancel.png", 1, false, false, 16, 16)

local item_id = -4
local item_array = -4
local tier_selection = {0, 0, 0, 0, 0}



-- ========== Functions ==========

local function get_crate(x, y)
    -- Look for crate at the given position
    local crates = Helper.find_active_instance_all(gm.constants.oCustomObject_pInteractableCrate)
    for _, c in ipairs(crates) do
        -- Doesn't spawn exactly on position for some reason
        if math.abs(c.x - x) <= 3 and math.abs(c.y - y) <= 3 then return c end
    end
    return nil
end



-- ========== Main ==========

gm.pre_script_hook(gm.constants.__input_system_tick, function()
    -- Add Cancel item
    local class_item = gm.variable_global_get("class_item")

    item_id = gm.item_find("betterCrates-cancel")
    if not item_id then
        item_id = gm.item_create("betterCrates", "cancel")
        item_array = class_item[item_id + 1]
        gm.array_set(item_array, 2, "Cancel")
        gm.array_set(item_array, 3, "Description")
        gm.array_set(item_array, 6, 0)
        gm.array_set(item_array, 7, sCancel)

        -- Add custom object for item
        -- Adapted from BreathingUnderwater (Groove_Salad)
        local obj = gm.object_add_w("betterCrates", "cancel", gm.constants.pPickupItem)
        gm.object_set_sprite_w(obj, sCancel)
        gm.array_set(item_array, 8, obj)

    else item_array = class_item[item_id + 1]
    end


    -- Append Cancel item to the beginning of all crates
    local crates = Helper.find_active_instance_all(gm.constants.oCustomObject_pInteractableCrate)
    for _, c in ipairs(crates) do
        if c.contents and c.contents[1] ~= item_array[9] then
            gm.array_insert(c.contents, 0, item_array[9])

            -- Scrapper mod support
            if c.is_scrapper then
                gm.array_insert(c.contents_ids, 0, item_id)
                gm.array_insert(c.contents_count, 0, 0)
            end
        end
    end


    -- [All]  Receive crate selection value
    while Helper.net_has("BetterCrates.selection") do
        local data = Helper.net_listen("BetterCrates.selection").data
        local crate = get_crate(data[1], data[2])
        if crate then crate.selection = data[3] end
    end


    -- [All]  Receive reset signal (Scrapper mod support)
    while Helper.net_has("BetterCrates.reset") do
        local data = Helper.net_listen("BetterCrates.reset").data
        local crate = get_crate(data[1], data[2])
        if crate then crate.force_scrapper_reset = 3 end
    end
end)


gm.pre_code_execute(function(self, other, code, result, flags)
    if code.name:match("oCustomObject_pInteractableCrate_Draw_0") then
        local activator = Helper.get_client_player() == self.activator

        if not self.is_scrapper then
            -- Move cursor to saved selection
            if activator and self.active == 1.0 then
                if not self.set_selection then
                    self.set_selection = true
                    self.selection = tier_selection[self.tier + 1]
                end

                -- [Net]  Send selection value to other players
                if not Helper.is_singleplayer() then Helper.net_send("BetterCrates.selection", {self.x, self.y, self.selection}) end
            else self.set_selection = nil
            end
        end


        if self.active > 1.0 then
            -- Save current selection
            if activator and not self.is_scrapper then
                tier_selection[self.tier + 1] = self.selection
            end


            -- Cancel is selected (selection 0)
            if self.selection == 0.0 then
                self.active = 0.0

                -- Give back player control
                if activator then
                    self.activator.activity = 0.0
                    self.activator.activity_free = true
                    self.activator.activity_move_factor = 1.0
                    self.activator.activity_type = 0.0
                    self.last_move_was_mouse = true

                    -- [Net]  Send reset signal to other players
                    if self.is_scrapper and not Helper.is_singleplayer() then Helper.net_send("BetterCrates.reset", {self.x, self.y}) end
                end
            end
        end

    end
end)


gm.pre_script_hook(gm.constants.run_create, function()
    tier_selection = {0, 0, 0, 0, 0}
end)