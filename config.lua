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
    ["mutatron"] = {
        -- 机器人初始充电器为原点；当前机器人朝西，机器在正前方一格的 y=1，机器人停在机器正上方的 y=2。
        position = {x = 0, y = 1, z = -1},
        robotY = 2,
        enabled = true,
        -- "dimension" 处理维度需求和 requiredMutatron；"all" 让所有非黑名单突变都走诱变机。
        mode = "dimension",
        -- 机器人从下方（OpenComputers sides.bottom = 0）访问机器物品栏。
        machineSide = 0,
        machine = {name = "gendustry:Mutatron", damage = 0, inventoryName = "tile.gendustry.mutatron"},
        labware = {name = "gendustry:Labware", damage = 0},
        -- Gendustry 槽位：公主蜂、雄蜂、输出、Labware。
        slots = {princess = 1, drone = 2, output = 3, labware = 4},
        timeout = 180
    }
}
