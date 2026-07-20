# BeeMasterXXL optimized build

这个目录是针对 GTNH 2.9.0-beta-1、Java 17 和 OpenComputers 1.12.44 的兼容修正版。

## 主要修复

- 使用 `inventory_controller.storeInternal()` + `database.get()` 读取机器人背包中蜜蜂的完整 NBT。
- 对 ME 查询返回 `nil`、查询异常和空结果进行统一处理。
- ME 网络描述符缺少 `individual` 时，尝试通过数据库补全。
- 避免 `individual`、`droneList`、`targetGenes` 为空时直接索引导致崩溃。
- `checkItemByTag()` 使用数据库中实际匹配的槽位请求物品。
- 下载器增加重试，并先写临时文件，网络中断不会删除旧脚本。
- 保留可配置的蜂箱框架投放功能，配置在 `config.lua`。

## 安装

将本目录中的 Lua 文件复制到 OC 硬盘根目录，`lib` 目录也要保留。推荐先备份旧目录和 `data.txt`。

如果使用 `installer.lua`，需要机器人安装因特网卡并确保能访问 GitHub Raw。连接失败时将 `usingPrefix` 改为 `true`，也可以直接从 Windows 复制文件。

## 组件要求

机器人至少需要：物品栏控制器、ME/AE 网络升级、数据库、蜜蜂分析相关升级，以及原项目要求的其它组件。机器人初始位置必须在 OC 充电器上方。

## 框架配置

```lua
frames = {
    enabled = true,
    item = {name = "MagicBees:frameFurious", damage = 0},
    count = 1,
    slots = {3, 4, 5}
}
```

如果当前整合包的狂热框架注册名不同，只修改 `item.name`。不需要框架时将 `enabled` 设为 `false`。

## 失败诊断

程序现在会区分“ME 查询为空”和“数据库无法读取完整 NBT”。如果仍有错误，请先确认目标亲本蜂已经存入同一个 ME 网络，并且网络区块保持加载。
