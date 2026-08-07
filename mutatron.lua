-- Fixed-position Gendustry Mutatron driver.
-- The configured machine must already be powered and supplied with Mutagen.
local component = require("component")
local os = require("os")
local robot = require("robot")

local bot = require("bot")

local config = require("config").mutatron or {}
local inventory_controller = component.inventory_controller

local M = {}

local position = config.position or {x = 0, y = 1, z = -1}
local machineY = position.y or 1
local robotY = config.robotY or (machineY + 1)
local machineSide = config.machineSide or 0
local slots = config.slots or {princess = 1, drone = 2, output = 3, labware = 4}
local machine = config.machine or {name = "gendustry:Mutatron", damage = 0}
local labware = config.labware or {name = "gendustry:Labware", damage = 0}

local function sameItem(left, right)
    return left and right and left.name == right.name and left.damage == right.damage
end

local function goAboveMachine()
    bot.moveYTo(robotY)
    bot.moveXZTo(position.x, position.z)
end

local function machineInventoryName()
    local ok, name = pcall(inventory_controller.getInventoryName, machineSide)
    return ok and name or nil
end

local function getMachineStack(slot)
    local ok, stack = pcall(inventory_controller.getStackInSlot, machineSide, slot)
    return ok and stack or nil
end

local function ensureMachine()
    goAboveMachine()
    local name = machineInventoryName()
    local expected = machine.inventoryName
    local isMutatron = type(name) == "string"
        and ((expected and name == expected) or name:lower():find("mutatron", 1, true) ~= nil)
    if not isMutatron then
        error(string.format(
            "诱变机坐标 (%d,%d,%d) 下方没有可访问的 Gendustry Mutatron",
            position.x, machineY, position.z
        ))
    end
    local ok, size = pcall(inventory_controller.getInventorySize, machineSide)
    if not ok or size == nil or size < slots.labware then
        error("诱变机物品栏不可访问，或槽位数不是预期的 4 格")
    end
end

local function requireEmpty(slot, description)
    local stack = getMachineStack(slot)
    if stack then
        error(string.format("诱变机%s槽仍有物品：%s", description, tostring(stack.label or stack.name)))
    end
end

local function insertOne(sourceSlot, targetSlot, description)
    if not bot.inventory[sourceSlot] or robot.count(sourceSlot) < 1 then
        error("诱变机缺少" .. description)
    end
    robot.select(sourceSlot)
    if not inventory_controller.dropIntoSlot(machineSide, targetSlot, 1) then
        error(string.format("无法将%s放入诱变机槽 %d", description, targetSlot))
    end
    bot.updateInventory(nil, sourceSlot)
end

local function ensureLabware()
    local existing = getMachineStack(slots.labware)
    if existing then
        if not sameItem(existing, labware) then
            error("诱变机 Labware 槽中有错误物品：" .. tostring(existing.label or existing.name))
        end
        return
    end
    local sourceSlot = bot.checkItem(labware, 1)
    if not sourceSlot then
        error("ME 中缺少 gendustry:Labware")
    end
    insertOne(sourceSlot, slots.labware, "Labware")
end

local function selectEmptySlot()
    for slot = 1, robot.inventorySize() do
        if not bot.inventory[slot] and robot.count(slot) == 0 then
            robot.select(slot)
            return slot
        end
    end
    error("机器人背包没有空槽，无法取回诱变机输出")
end

local function collectOutput()
    local targetSlot = selectEmptySlot()
    if not inventory_controller.suckFromSlot(machineSide, slots.output, 1) then
        error("无法从诱变机输出槽取回物品")
    end
    bot.updateInventory(nil, targetSlot)
    if not bot.inventory[targetSlot] then
        error("诱变机输出已取出，但机器人背包没有收到物品")
    end
    return targetSlot
end

local function waitForOutput()
    local timeout = tonumber(config.timeout) or 180
    for _ = 1, timeout do
        local output = getMachineStack(slots.output)
        if output then
            return output
        end
        os.sleep(1)
    end
    error("诱变机等待超时；请检查电力、Mutagen、Labware 和父代配对。输入已保留在机器中，请先处理后再重试")
end

function M.uses(mutation)
    if type(mutation) ~= "table" or config.enabled ~= true or mutation.disabledMutatron then
        return false
    end
    if mutation.requiredMutatron then
        return true
    end
    return config.mode == "all" or mutation.dimension ~= nil
end

function M.nextGeneration(princessSlot, droneSlot, mutation, targetSpecies)
    if not M.uses(mutation) then
        error("mutatron.nextGeneration() 收到了不应由诱变机处理的突变")
    end
    if not bot.inventory[princessSlot] or bot.inventory[princessSlot].type ~= "beePrincess" then
        error("诱变机只能输入公主蜂；请先让现有蜂后完成一个生命周期")
    end
    if not bot.inventory[droneSlot] or bot.inventory[droneSlot].type ~= "beeDrone" then
        error("诱变机只能输入雄蜂")
    end

    ensureMachine()
    requireEmpty(slots.princess, "公主蜂")
    requireEmpty(slots.drone, "雄蜂")
    requireEmpty(slots.output, "输出")
    ensureLabware()

    insertOne(princessSlot, slots.princess, "公主蜂")
    insertOne(droneSlot, slots.drone, "雄蜂")
    local output = waitForOutput()
    local outputSlot = collectOutput()
    local outputBee = bot.inventory[outputSlot]
    local outputName = tostring(output.name or ""):lower()

    if outputName == "gendustry:waste" then
        error("诱变机输出 Waste：输入公主蜂和雄蜂已损失。始祖公主蜂有概率变为卑贱，卑贱公主蜂有概率变为 Waste")
    end
    if not outputBee or outputBee.type ~= "beeQueen" then
        error("诱变机输出不是蜂后：" .. tostring(output.name))
    end
    if targetSpecies and (not outputBee.species or outputBee.species[1] ~= targetSpecies or outputBee.species[2] ~= targetSpecies) then
        error(string.format(
            "诱变机选择了非目标突变（得到 %s/%s，期望 %s）。基础诱变机遇到多条可用配方会随机选择；请改用高级诱变机或唯一的亲本配对",
            tostring(outputBee.species[1]), tostring(outputBee.species[2]), targetSpecies
        ))
    end
    if outputBee.isNatural == false then
        print("警告：诱变机将始祖公主蜂变为卑贱蜂后；后续请留意遗传衰减，必要时使用 Hibeescus 恢复")
    end
    return outputSlot
end

function M.destruct()
    -- The Mutatron is a permanent station. The caller returns the robot home.
end

return M
