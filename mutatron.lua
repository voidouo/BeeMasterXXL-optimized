-- Fixed-position Gendustry Mutatron driver.
-- The robot starts on top of the OC charger. Coordinates in config.lua are
-- relative to that charger, using the same coordinate system as apiary.lua.
local component = require("component")
local robot = require("robot")
local os = require("os")

local bot = require("bot")
local tools = require("tools")

local config = require("config").mutatron or {}
local inventory_controller = component.inventory_controller

local M = {}

local position = config.position or {x = 6, y = 1, z = 0}
local machineY = position.y or ((config.robotY or 2) - 1)
local robotY = config.robotY or (machineY + 1)
if robotY ~= machineY + 1 then
    error("config.mutatron.position.y 必须比 config.mutatron.robotY 小 1")
end
local machineSide = config.machineSide or 0
local slots = config.slots or {princess = 1, drone = 2, output = 3, labware = 4}
local machine = config.machine or {name = "gendustry:Mutatron", damage = 0}
local labware = config.labware or {name = "gendustry:Labware", damage = 0}

local currentFoundation = config.initialFoundation
local foundationKnown = currentFoundation ~= nil
local active = false
local autoPlace = config.autoPlace ~= false

local function sameItem(left, right)
    if not left or not right then return left == right end
    return left.name == right.name and left.damage == right.damage
end

local function getMachineName()
    local ok, result = pcall(inventory_controller.getInventoryName, machineSide)
    if ok then return result end
    return nil
end

local function getMachineStack(slot)
    local ok, result = pcall(inventory_controller.getStackInSlot, machineSide, slot)
    if ok then return result end
    return nil
end

local function hasMachine()
    local name = getMachineName()
    if type(name) ~= "string" then return false end
    local expected = machine.inventoryName
    if expected and name == expected then return true end
    return name:lower():find("mutatron", 1, true) ~= nil
end

local placeMachine

local function ensureMachine()
    if not hasMachine() then
        if autoPlace then
            placeMachine()
        end
    end
    if not hasMachine() then
        error(string.format(
            "诱变机坐标 (%d,%d,%d) 没有可访问的 Gendustry Mutatron；请确认机器在机器人正下方",
            position.x, machineY, position.z
        ))
    end
    local ok, size = pcall(inventory_controller.getInventorySize, machineSide)
    if not ok or not size or size < slots.labware then
        error("诱变机的 OC 物品栏不可用，或槽位少于 4 格")
    end
end

local function goAboveMachine()
    bot.moveYTo(robotY)
    bot.moveXZTo(position.x, position.z)
end

local function refreshSlot(slot)
    if slot and slot > 0 then
        bot.updateInventory(nil, slot)
    end
end

local function refreshInventory()
    for slot = 1, robot.inventorySize() do
        bot.updateInventory(nil, slot)
    end
end

local function selectEmptySlot()
    local slot = bot.selectEmptySlot()
    if not slot then
        error("机器人背包没有空槽，无法取回诱变机输出")
    end
    return slot
end

local function collectOutput()
    local targetSlot = selectEmptySlot()
    if not inventory_controller.suckFromSlot(machineSide, slots.output, 1) then
        error("无法从诱变机输出槽取回蜜蜂")
    end
    refreshSlot(targetSlot)
    if not bot.inventory[targetSlot] or robot.count(targetSlot) < 1 then
        error("诱变机输出槽取出成功但机器人没有收到物品，请检查库存同步")
    end
    return targetSlot
end

local function collectMachineSlot(slot)
    if not getMachineStack(slot) then return nil end
    local targetSlot = selectEmptySlot()
    if not inventory_controller.suckFromSlot(machineSide, slot, 64) then
        return nil
    end
    refreshSlot(targetSlot)
    return targetSlot
end

local function removeFoundation(tool)
    if robot.detectDown() then
        tools.swingDown(tool)
    end
end

placeMachine = function()
    local slot = bot.checkItem(machine, 1)
    if not slot then
        error("缺少 gendustry:Mutatron，无法重新放回诱变机")
    end
    robot.select(slot)
    if not robot.placeDown() then
        error("无法在固定坐标重新放置诱变机")
    end
    refreshSlot(slot)
end

-- Foundation blocks are placed below the machine. Rebuilding is only done
-- when the required block changes, so a fixed machine is left in place.
local function rebuildMachine(targetFoundation, removeBlock)
    goAboveMachine()
    ensureMachine()
    for slot = 1, slots.labware do
        if getMachineStack(slot) then
            error("更换诱变机基石前必须先清空诱变机槽 " .. slot)
        end
    end

    local previousLabel = bot.inventoryLabel
    bot.inventoryLabel = "mutatron.machine"
    tools.swingDown()
    bot.inventoryLabel = previousLabel
    refreshInventory()
    if hasMachine() then
        error("无法拆下固定位置的诱变机；请确认机器人装备了可精准采集的 Vajra")
    end

    local ok, reason = pcall(function()
        bot.moveYTo(machineY)
        if removeBlock then
            removeFoundation(currentFoundation and currentFoundation.tool)
            if robot.detectDown() then
                error("无法拆下诱变机下方的旧基石；请检查工具或手动清空该方块")
            end
        end
        if targetFoundation then
            tools.placeDown(targetFoundation)
        end
        bot.moveYTo(robotY)
        placeMachine()
    end)
    if not ok then
        -- Do not leave an empty machine location when a foundation operation
        -- fails. If the block was already removed, restore the machine on the
        -- current floor when the dropped item is still available.
        local restored = pcall(function()
            bot.moveYTo(robotY)
            if not hasMachine() then placeMachine() end
        end)
        if restored then
            error("诱变机基石更换失败，机器已尝试恢复原位：" .. tostring(reason))
        end
        error("诱变机基石更换失败且机器未能恢复，请手动放回 Mutatron：" .. tostring(reason))
    end
    refreshInventory()
    ensureMachine()
end

local function prepareFoundation(targetFoundation)
    if not foundationKnown then
        if targetFoundation then
            if not config.rebuildOnFirstFoundation then
                error("首次使用需要更换诱变机下方基石，请将 config.mutatron.rebuildOnFirstFoundation 设为 true")
            end
            -- The existing block is unknown on the first run, so remove it
            -- before placing the requested foundation.
            rebuildMachine(targetFoundation, true)
        else
            goAboveMachine()
            ensureMachine()
        end
        currentFoundation = targetFoundation
        foundationKnown = true
        return
    end

    if not sameItem(currentFoundation, targetFoundation) then
        rebuildMachine(targetFoundation, true)
        currentFoundation = targetFoundation
    else
        goAboveMachine()
        ensureMachine()
    end
end

local function requireEmptyMachineSlot(slot, description)
    local stack = getMachineStack(slot)
    if stack then
        error(string.format("诱变机%s槽仍有物品：%s；请先清空机器", description, tostring(stack.label or stack.name)))
    end
end

local function insertOne(sourceSlot, targetSlot, description)
    if not bot.inventory[sourceSlot] or robot.count(sourceSlot) < 1 then
        error("诱变机缺少" .. description)
    end
    robot.select(sourceSlot)
    if not inventory_controller.dropIntoSlot(machineSide, targetSlot, 1) then
        error("无法将" .. description .. "放入诱变机槽 " .. targetSlot)
    end
    refreshSlot(sourceSlot)
end

local function insertLabware()
    local existing = getMachineStack(slots.labware)
    if existing then
        if not sameItem(existing, labware) then
            error("诱变机基因药皿槽中有错误物品：" .. tostring(existing.label or existing.name))
        end
        return
    end
    local sourceSlot = bot.checkItem(labware, 1)
    if not sourceSlot then
        error("诱变机缺少基因药皿 gendustry:Labware；每次诱变都会消耗耗材")
    end
    insertOne(sourceSlot, slots.labware, "基因药皿")
end

local function waitForOutput()
    local timeout = tonumber(config.timeout) or 180
    for _ = 1, timeout do
        local output = getMachineStack(slots.output)
        if output then return output end
        os.sleep(1)
    end
    error("诱变机等待超时；请检查电力、Mutagen 诱变剂、基因药皿和父代配对。若程序中断，请先清空机器槽 1/2/3/4")
end

local function runMutation(princessSlot, droneSlot, mutation)
    active = true
    prepareFoundation(type(mutation) == "table" and mutation.foundation or nil)
    requireEmptyMachineSlot(slots.princess, "公主蜂")
    requireEmptyMachineSlot(slots.drone, "雄蜂")
    requireEmptyMachineSlot(slots.output, "输出")
    insertLabware()

    local previousLabel = bot.inventoryLabel
    bot.inventoryLabel = "mutatron.nextGeneration()"
    if bot.inventory[princessSlot] then
        bot.inventory[princessSlot].inventoryLabel = bot.inventoryLabel
    end
    if bot.inventory[droneSlot] then
        bot.inventory[droneSlot].inventoryLabel = bot.inventoryLabel
    end

    local outputReady = false
    local ok, result = pcall(function()
        -- Always transfer exactly one parent of each type.
        insertOne(princessSlot, slots.princess, "公主蜂")
        insertOne(droneSlot, slots.drone, "雄蜂")
        local output = waitForOutput()
        outputReady = true
        local outputName = tostring(output.name or ""):lower()
        if outputName == "gendustry:waste" then
            local wasteSlot = collectOutput()
            if bot.inventory[wasteSlot] then
                bot.inventory[wasteSlot].inventoryLabel = previousLabel
            end
            error("诱变机输出 Waste，公主蜂未成功突变；已将废物取回机器人槽 " .. wasteSlot)
        end
        if outputName ~= "forestry:beeprincessge" then
            local unexpectedSlot = collectOutput()
            if bot.inventory[unexpectedSlot] then
                bot.inventory[unexpectedSlot].inventoryLabel = previousLabel
            end
            error("诱变机输出不是可分析的公主蜂：" .. tostring(output.name) .. "；已取回槽 " .. unexpectedSlot)
        end
        return collectOutput()
    end)

    bot.inventoryLabel = previousLabel
    if bot.inventory[princessSlot] then
        bot.inventory[princessSlot].inventoryLabel = previousLabel
    end
    if bot.inventory[droneSlot] then
        bot.inventory[droneSlot].inventoryLabel = previousLabel
    end
    if not ok then
        -- Once an output exists, the machine has finished. Recover any
        -- residual input/labware so the next attempt is not permanently
        -- blocked by a stale slot. A timeout intentionally leaves inputs in
        -- place because the machine may still be processing them.
        if outputReady then
            for _, slot in ipairs({slots.princess, slots.drone, slots.labware}) do
                local recoveredOK, recovered = pcall(collectMachineSlot, slot)
                if recoveredOK and recovered and bot.inventory[recovered] then
                    bot.inventory[recovered].inventoryLabel = previousLabel
                end
            end
        end
        error(result)
    end

    local outputSlot = result
    if bot.inventory[outputSlot] then
        bot.inventory[outputSlot].inventoryLabel = previousLabel
    end
    return outputSlot
end

function M.uses(mutation)
    if type(mutation) ~= "table" or not config.enabled then return false end
    if mutation.disabledMutatron then return false end
    -- A Mutatron handles mutations that need a special foundation or
    -- dimension, independent of the dimension in which the robot is running.
    return mutation.requiredMutatron == true
        or mutation.dimension ~= nil
        or mutation.foundation ~= nil
        or config.mode == "all"
end

function M.nextGeneration(princessSlot, droneSlot, mutation)
    if not M.uses(mutation) then
        error("mutatron.nextGeneration() 收到了不应由诱变机处理的突变")
    end
    return runMutation(princessSlot, droneSlot, mutation)
end

function M.destruct()
    -- The Mutatron is intentionally fixed in place. Only return the robot to
    -- a known height/position; foundation and machine stay available next run.
    if not config.enabled or not active then return end
    pcall(function()
        bot.moveYTo(robotY)
        bot.moveXZTo(position.x, position.z)
    end)
end

return M
