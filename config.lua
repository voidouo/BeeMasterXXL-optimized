return{
    ["apiary"] = {--生态之书页码
          [1] = 309,
        [2] = 5,
        [3] = 188,
        [4] = 178,
        [5] = 273,
        [6] = 93,
        [7] = 74,
        [8] = 59,
        [9] = 136,
        [10] = 58,
        [11] = 73,
        [12] = 248,
        [13] = 252,
        [14] = 218,
        [15] = 113,
        [16] = 216,
    },
    ["worldAccelerator_tier"] = 5,
    ["frames"] = {enabled = true, item = {name = "MagicBees:frameFurious", damage = 0}, count = 1, slots = {3, 4, 5}},
    ["initialDirection"] = {x = -1, z = 0},
    ["mutatron"] = {
        -- 诱变机坐标相对于机器人初始充电器位置；这是示例坐标，请按你的实际摆放修改。
        position = {x = 5, y = 3, z = -2},
        -- 机器人站在诱变机上方一格，机器本体位于 y=1。
        robotY = 4,
        enabled = true,
        -- "required"：有突变基石、特殊维度或 requiredMutatron=true 时使用。
        -- 改成 "all" 后，没有特殊条件的普通突变也会走诱变机。
        mode = "required",
        machine = {name = "gendustry:Mutatron", damage = 0, inventoryName = "tile.gendustry.mutatron"},
        labware = {name = "gendustry:Labware", damage = 0},
        slots = {princess = 1, drone = 2, output = 3, labware = 4},
        machineSide = 0,
        timeout = 180,
        -- 第一次遇到基石时会拆下机器，替换机器下方方块；之后只在基石变化时执行。
        rebuildOnFirstFoundation = true,
        -- 如果你已知机器下方当前基石，可填同样的 {name=..., damage=...}
        -- 来避免首次运行重复拆装机器；不知道时保持 nil。
        initialFoundation = nil
    }
}
