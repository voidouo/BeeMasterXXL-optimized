-- ME/database compatibility helpers.
-- AE/OC item lists are descriptors; the database is the reliable source for
-- complete NBT (including Forestry's individual table).
local component = require("component")

local M = {}
M.upgrade = component.upgrade_me
M.database = component.database

local function requireComponent(value, name)
    if not value then error("missing component: " .. name) end
    return value
end

function M.getItems(filter)
    requireComponent(M.upgrade, "upgrade_me")
    local ok, result = pcall(M.upgrade.getItemsInNetwork, filter)
    if not ok then
        error("ME query failed: " .. tostring(result))
    end
    return type(result) == "table" and result or {}
end

local function clearDatabase()
    requireComponent(M.database, "database")
    for slot = 1, 81 do
        pcall(M.database.clear, slot)
    end
end

-- Store matching network stacks in the database and return complete entries.
-- The returned entries have the database slot so callers can request them.
function M.storeNetwork(filter, limit)
    requireComponent(M.upgrade, "upgrade_me")
    requireComponent(M.database, "database")
    clearDatabase()
    limit = math.min(limit or 81, 81)
    local ok, result = pcall(M.upgrade.store, filter, M.database.address, 1, limit)
    if not ok then
        -- Older GTNH builds expose the three-argument form only.
        ok, result = pcall(M.upgrade.store, filter, M.database.address, 1)
    end
    if not ok then
        return nil, tostring(result)
    end
    local entries = {}
    for slot = 1, limit do
        local stack = M.database.get(slot)
        if stack then
            entries[#entries + 1] = {slot = slot, stack = stack}
        end
    end
    return entries
end

-- Fill missing descriptor fields using the complete stack stored in database.
function M.enrichItems(items, filter)
    if type(items) ~= "table" or #items == 0 then return items or {} end
    local needFullData = false
    for _, item in ipairs(items) do
        if item and item.tag and not item.individual then
            needFullData = true
            break
        end
    end
    if not needFullData then return items end
    local entries = M.storeNetwork(filter, #items)
    if not entries then return items end
    local byTag = {}
    for _, entry in ipairs(entries) do
        if entry.stack and entry.stack.tag then
            byTag[entry.stack.tag] = entry.stack
        end
    end
    for _, item in ipairs(items) do
        local complete = item and item.tag and byTag[item.tag]
        if complete then
            for key, value in pairs(complete) do
                if item[key] == nil then item[key] = value end
            end
        end
    end
    return items
end

-- Read a robot inventory slot with complete NBT when supported by the OC build.
function M.getInternalStack(slot)
    requireComponent(M.database, "database")
    local controller = component.inventory_controller
    local stack = controller.getStackInInternalSlot(slot)
    if not stack then return nil end
    local isBee = stack.name == "Forestry:beePrincessGE" or stack.name == "Forestry:beeDroneGE"
    if isBee and not stack.individual and controller.storeInternal then
        pcall(M.database.clear, 1)
        local ok, stored = pcall(controller.storeInternal, slot, M.database.address, 1)
        if ok and stored ~= false then
            local complete = M.database.get(1)
            if complete then stack = complete end
        end
    end
    return stack
end

return M
