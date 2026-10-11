# 智人TV之机炮仙人

在单人舰船按 **F11**，自动前往十字架一（GACRUX），寻找难度 10、终结族掠食变种、绿胖模板的升旗任务并进入空降舱。手动确认落点后，自动选择社区MO配装。

**前置模组：** [Bingus Shared Loader v19 / API 1](https://www.nexusmods.com/helldivers2/mods/16292)
**已验证环境：** Windows、Steam build **25480438** / EXE **1.8.46015.0**。选任务、入舱、穿戴、三件武器及四战备已在该环境实机确认；其他游戏版本未验证。使用前需已解锁下列装备。

**固定配装：**

- 战备：机炮 → 轨道空爆 → 轨道精准攻击 → 轨道加特林火力网。
- 主手：LAS-12 钗；副手：GP-20 最后通牒；投掷物：G-48 千兆级榴弹。
- 头盔：UF-16 督察员；护甲：CM-09 碎骨杀手；披风：民主之心捍卫者。

**安装：** 退出游戏，将加载器与 `FlagDrop-v0.9.zip` 导入 Arsenal 或 HD2MM，启用并部署。按加载器说明设置启动资源优先级；Arsenal 默认顺序下加载器放在底部。更新时替换旧版 FlagDrop。

**源码打包：** 源码包包含 `entry.lua`、`mission.lua`、`loadout.lua`、`pod.lua`、`build.py` 和本说明。在该目录用 Python 3 运行 `python build.py`，生成可安装的 `FlagDrop-v0.9.zip`。无需额外 Python 库；玩家安装成品包无需 Python。散装 Lua 文件不能直接作为本模组安装。

**日志：** `%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/FlagDrop.log`。

**参考实现与资料：** [MissionReroller](https://github.com/lombax5832/MissionReroller)、[DiverKit](https://www.nexusmods.com/helldivers2/mods/16493)、[ShipStationHotkeys](https://github.com/CowboyBingus/ShipStationHotkeys)、[OneClickArmorSet](https://github.com/Alomare/OneClickArmorSet)、[HD2-Transmog](https://github.com/tyrypyrking/HD2-Transmog)、[HD2Runtime](https://github.com/SkyeShade/HD2Runtime)、[FileDiver](https://github.com/xypwn/filediver)
