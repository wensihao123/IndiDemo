# Project Context (shared by all roles)

> 这是所有 role 的"共享内存"。每个 session 都应先读这一份。
> 保持它简短、事实化、可信——它一错,所有 role 跟着错。
>
> 状态:逐步完善中(2026-06-17 起草)。带 **[TODO]** 的小节尚未定稿。
>
> 协作模式:**纯 vibe coding**——所有代码由 role(主要 Implementer)产出,作者尽量不手写
> 代码,只定方向与验收。故 artifact / HANDOFF 的清晰度、可读性尤为重要。

## 0. 游戏一句话 + 支柱
- 这是个什么游戏,给谁玩:
  常驻 PC 屏幕下方的**悬浮窗挂机打宝游戏**。玩家组一支 4 人小队(职业分坦克 / 法师 /
  战士 / 射手 / 牧师等),装备走暗黑式掉落+词条+构筑,画风类 MapleStory(手绘 2D 横版)。
  两大板块:**城镇**(招募角色、打造装备、升级技能 = 养成)+ **探索**(小队自动打怪刷
  资源 = 产出)。给:喜欢暗黑式刷装/构筑、但更想要长期、低负担"陪伴感"的玩家。**[待你确认受众措辞]**
- 设计支柱(所有 feature 都要服务它们):
  - **支柱 1 —— 它首先是个"伙伴",不是个"任务"(权重最高 = 5/10)。**
    安静挂在屏幕下方,余光扫一眼就能看懂,绝不逼玩家盯屏或搓实时操作。战斗全自动。
    任何功能若要求"必须连续操作 X 分钟",即违反本条。
  - **支柱 2 —— 变强,是为了够到下一个够不着的怪(权重 = 3/10)。**
    出稀有装备/材料 → 回城调整队伍与构筑 → 挑战更难内容。这个"刷→调→再挑战"闭环是
    玩家主动参与的核心时刻;城镇所有系统都服务于它。
  - **支柱 3 —— 偶尔的一下惊喜,而不是赌场(权重 = 2/10)。**
    暗黑式掉落带来"哦?橙的!"的小确幸,是调味不是主菜;不靠强随机/逼氪制造焦虑。
- 节奏曲线(贯穿支柱 1↔2 的设计原则):
  **前期快迭代**(低等级、频繁回城调队)→ **后期稳态**(高等级、约 1–2 小时回城一次,
  趋近纯陪伴)。游玩重心随进度从"主动构筑"滑向"被动陪伴"。
- v1 的完成定义(2026-06-19 Producer 拍板,已拆进 BACKLOG):
  一个能跑通完整闭环的**垂直切片**——挂机探索 → 掉装/材料 → 回城变强 → 打过更硬的怪。
  权威清单见 `BACKLOG.md`;以下为口径基线。
  - 悬浮窗外壳:底部全宽常驻、800×250 主区、能最小化/恢复。**(已落地)**
  - 探索:1 区域、自动打多种怪、自动掉落、Boss 解锁/团灭回退。**(地基已落地,见下)**
  - 装备:2-3 槽位、白/蓝/金、攻击/生命词条;掉落 → 穿/分解/进包分流。**(后端已落地;04 收窄为表层+数值定稿)**
  - 城镇:换装 + 1 个最简打造/强化(材料 +1 武器)。**(05-town,待做)**
  - 闭环:变强后能打过一个更硬的怪 / Boss。
  - 存档:最简 save/load。**(已落地 —— 07-save-load 并入 00,通关→关程序→重开续战 round-trip 经手验)**
  - **团战 / 多敌同屏(2026-06-19 自 Later 提升进 v1):** 战斗引擎已是 lane 多实体,
     v1 收尾要把"多敌同屏"点亮到可玩(08-team-combat)。
  - **核心系统:**
    1. **4 人队伍按"4 格 slot"设计,v1 只填 1 个战士**——数据结构已支持 N 人(roster/slot 已就位)。
    2. **后台持续推进**——固定步长 tick 已落地,窗口在后台时推进照常。"完全关程序后的离线结算"仍推后。
  - **2026-06-19 地基现状:** REFACTOR-01 把四层架构 + 掉落后端 + 存档 + lane 多实体引擎全部落地
     (117/117 测试绿、手动 Play + 存档 round-trip 经手验)。v1 余下 = 表层点亮(04 表层 / 08 团战)+ 城镇(05)+ 难度(06)。
  - 明确推后到 v1 之后:招募 / 其它职业 / 技能树 / 多区域 / 离线结算 / 套装宝石 / 复杂词条池。

## 1. 引擎与技术栈
- 引擎 + 版本:**Godot 4.6**(渲染 Forward Plus,Windows 用 d3d12 驱动)
  - 注:空项目按 3D 默认配置(Forward Plus + Jolt 3D 物理),但本作是 2D。搭场景时
    考虑切渲染到 Mobile/Compatibility,3D 物理基本用不上。见第 6 节。
- 脚本语言:**GDScript**
- 目标平台:**先做 Windows 版**(桌面悬浮窗,后续平台暂不在范围内)
- 美术风格基线:类 MapleStory 手绘 2D。**全屏宽、底部悬浮条**;主游戏区固定 **800×250**
  居中,两侧用**占位背景图**填充以适配不同显示器宽度/分辨率。
- 测试:**gdUnit4**,只测纯逻辑(掉落计算 / 词条 roll / 4 人队伍数值结算等);UI、悬浮窗、
  战斗演出靠手动验证。
- 其它工具:暂无额外 lint/format;依赖 Godot 编辑器报错与 `--check-only` 把关。

## 2. 目录约定
> **2026-06-19 更新:REFACTOR-01 地基重构已落地,目录已成形(不再为空)。**
> 四层架构详见事实源 `harness/ARCHITECTURE.md` + 人类导读 `harness/ARCHITECTURE-GUIDE.md`。
> autoload 两枚:`Player`(=`PlayerState`,持久根)→ `Game`(=`GameController`,装配座),顺序不可换。
```
test-2/                   [Godot 项目根,= res://]
  project.godot           [autoload: Player(上) → Game(下)]
  src/
    core/
      data/               [纯数据定义:item_base_def / affix_def / loot_table_def]
      stats/              [属性层:stats_component / stat_modifier]
      items/              [物品实例层:item_instance / affix_roll / equipment_component]
      systems/            [系统:loot_generator / loot_intake / data_registry / save_system]
      combat/             [单局战斗层:combat_arena / progression_controller / entity /
                           ai_combat_component / skill_component / combat_tuning]
      meta/               [持久元状态层:player_state(autoload Player)/ character]
      game_controller.gd  [装配座 autoload Game] · game_keys.gd
    combat/               [表现层 + 配置:combat_view / enemy_def / stage_config / scene_config]
    shell/                [floating_shell.gd 悬浮窗外壳]
  data/config/            [数值配置 JSON:item_bases / affix_pool / loot_tables / starting_roster]
  scenes/shell/           [floating_shell.tscn 主场景]
  assets/
    sprites/              [bg / ui / hero / fx / enemies 占位图]
    data/combat/          [stage_01.tres / stage_02.tres]
    audio/                (空)
  harness/                [role 的 artifact,纳入版本控制]
    project-context.md    [本文件]
    ARCHITECTURE.md       [Arch Guard — 架构事实源] · ARCHITECTURE-GUIDE.md [人类导读]
    BACKLOG.md            [Producer]
    STYLE-BIBLE.md        [Art Spec]
    arch/                 [REFACTOR-NN-*.md 跨功能重构案]
    features/<NN-slug>/   [每个功能一目录:FEATURE-DESIGN / PLAN / CHANGES / ... / HANDOFF.md]
```

## 3. 代码约定
- 命名:文件 snake_case,节点 PascalCase,signal 用过去式(died / item_dropped)
- 风格:优先 composition over inheritance;早返回
- 信号 vs 直调:跨系统用 signal,父子节点内部可直调
- 注释:只在"为什么"不显然时注释

## 4. 禁止事项(hard NOs)
- 不引入新插件 / AddOn,除非计划明确批准。
- 不做计划外的"顺手重构 / 顺手加功能"(独游易失控,严格按计划)。
- 数值平衡参数与路径不硬编码进逻辑(掉落率、怪物属性等走配置 / Resource)。
- 不为还没影的后期系统提前抽象(先 3 行重复,别过度设计)。

## 5. 验证一次改动是否 OK 的标准流程
按顺序,全绿才算通过:
```
godot --headless --check-only      # 语法 / 编译过关
跑 gdUnit4 测试                     # 纯逻辑回归
手动打开相关场景按 Play,观察预期表现   # UI / 演出靠肉眼
```

## 6. 当前已知的坑 / 临时约束
- 空项目按 3D 默认配置(Forward Plus 渲染 + Jolt 3D 物理),与 2D 目标不符;搭首个场景时
  需决定渲染模式与是否禁用 3D 物理。
- ~~几乎所有系统尚未存在(src/scenes/assets 全空)~~ **已过时(2026-06-19):** 四层地基 +
  autoload(Player/Game)+ 存档系统已落地,见 §2 与 ARCHITECTURE.md。新功能对照 ARCHITECTURE.md 接入。
