---
updated: 2026-06-19
---

# 架构设计说明书 — test-2(2D 横版挂机 ARPG)

> 📖 **这是一份给人读的导读**,用大白话 + "跟着一次游玩走一遍"的方式讲清这个游戏的代码是怎么搭的、
> 为什么这么搭。它**不是**事实源——精确、致密、给各 role 对照的权威定义在
> [`ARCHITECTURE.md`](ARCHITECTURE.md);两者冲突时以那份为准。本文负责"看得懂",那份负责"说得准"。

---

## 0. 一句话:这是个什么游戏、代码想解决什么

一个挂在悬浮窗里、**自动打怪 + 一关关车轮推进 + 掉装变强**的放置型 ARPG。你不操作走位,
角色按属性自动出手;核心乐趣在**攒装备 / 词缀 / build**,而不是手操。

正因为"自动、可挂机、要能离线/后台算",代码的头号约束是:

> **战斗必须能在没有画面的情况下精确算出结果(headless 可演算),且和帧率无关。**

这一条决定了整套架构的形状——**逻辑和表现彻底分开**,画面只是"把算好的状态画出来",
关掉画面、改变帧率,战斗结果一模一样。

---

## 1. 全局俯瞰:四层 + 一个装配座

代码分成**四个层**,依赖**只能自上而下**,严禁反向(下层永远不知道上层存在):

```
┌─────────────────────────────────────────────────────────────┐
│ [表现层]   CombatView / AnimationComponent                    │  只读状态、监听信号,不碰任何数值
│            ▲ 监听 signal(过去式:hit_dealt / enemy_defeated…) │
│ [单局战斗层] CombatArena / ProgressionController               │  per-run(打完即弃),固定步长 tick
│            ▲ 读快照                                            │
│ [持久层]   PlayerState(autoload) / SaveSystem                 │  跨局存在 = 存档目标:roster+背包+材料
│            ▲ 读模板                                            │
│ [数据层]   DataRegistry + 静态模板(.tres + JSON)             │  只读蓝图,启动时加载并校验
└─────────────────────────────────────────────────────────────┘
```

横在这四层之上、负责"把它们装配起来开一局"的,是一个**装配座 `GameController`**(autoload 名 `Game`)。

**用一个比喻理解这五块:**

| 角色 | 比喻 | 干什么 |
|------|------|--------|
| 数据层 `DataRegistry` | **图纸库** | 怪长什么样、装备基底、词缀池——只读蓝图,开局一次性加载+校验 |
| 持久层 `PlayerState` | **你的存档/家当** | 你的队伍、背包、材料;唯一会被写进存档文件的东西 |
| 单局战斗层 `CombatArena`+`Progression` | **一局比赛的场地+裁判** | 按图纸和家当跑这一局,打完就拆,可弃 |
| 表现层 `CombatView` | **转播画面** | 把场上发生的事画出来 + 飘字 + 血条;拔掉它比赛照常进行 |
| 装配座 `GameController` | **总导演** | 开机时把上面四块拼起来、驱动每一拍、负责自动存档 |

**为什么要这么分?** 因为"家当(持久)"和"一局战斗(临时)"生命周期完全不同:你重开游戏,
家当要还在、上一局的临时实体该全没。把它们揉在一起,就会出"脱了装备属性没回退""重开还残留上局状态"
这类经典 bug。分层 + 下面几条铁律,就是从结构上根除这类问题。

---

## 2. 五条"看得懂"的铁律(不变量)

这些是代码里**永远成立**的约定,理解它们就理解了一大半设计意图(完整 9 条见 `ARCHITECTURE.md §4`):

1. **图纸只读,绝不写回。** 怪的模板、装备基底这些静态 def,运行时只读不改;血量/出手进度这类
   会变的量,只存在于"这一局的临时实体"上。→ *根除"配置被战斗悄悄改坏"。*

2. **属性永远是算出来的,绝不直接存最终值。** 任何生效属性 = `(基础 + Σ加法) × (1 + Σ百分比)`,
   每次穿脱装备/上 buff 都是增减一条 modifier,然后重算。→ *根除"脱了装备属性没退干净"。*

3. **没有画面也能算,且和帧率无关。** 战斗用**固定步长 tick**(把不定长的帧 delta 切成等长逻辑步),
   收起来 15fps、展开 60fps、切后台,结算完全一致。→ *这是放置/挂机/离线结算的地基。*

4. **跨局只留持久层。** 队伍/背包/材料/进度可序列化、能跨局;战斗临时实体每局从快照重建、用完即弃。

5. **信号用过去式、跨系统用信号、同实体内直接调。** 战斗层发 `enemy_defeated` 这种"已发生"的事件,
   表现层监听着画出来——表现层永远是被动旁观者,从不反向驱动逻辑。

---

## 3. 数据模型:两层切分(图纸 vs 实物)

整个数据模型的核心切分是:**静态模板(只读图纸)** vs **运行时实例(可序列化的实物)**。

### 3.1 静态模板(图纸,只读)

| 模板 | 存哪 | 是什么 |
|------|------|--------|
| `EnemyDef` | `.tres` | 一种怪:8 维属性 + 掉落权重 + `item_level` + 远/近站位 + 立绘 |
| `StageConfig` / `SceneConfig` | `.tres` | 关卡 / 一波怪 / 站位布局 |
| `ItemBaseDef` | JSON | 装备基底:部位、招牌属性、基底值随 ilvl 的曲线 |
| `AffixDef` | JSON | 词缀池:属性、加法/百分比、各 Tier 区间与门槛与权重、能出现在哪些部位 |
| `LootTableDef` | `.tres`/JSON | 部位 roll 权重、稀有度→词缀条数、分解门槛 |

> **为什么有的存 `.tres` 有的存 JSON?**(2026-06-19 定的分工)
> - **少而需要在 Godot 编辑器里手调手感**的(怪、关卡)→ `.tres`,Inspector 里拖。
> - **海量、要 Claude 批量生成 + 肉眼 review 的**(词缀库、装备基底)→ JSON,文本好批改。
> - **进了内存都是同一套带类型的对象**,JSON 只是磁盘上的"作者格式"。

### 3.2 运行时实例(实物,可序列化)

- **`ItemInstance`** — 一件具体掉落:`{ 基底, ilvl, 稀有度, 词缀列表 }`。掉落那一刻由 `LootGenerator` roll 出来,是唯一会进存档的物品形态。
- **`Character`(持久)** — 一个角色:`{ id, 职业, 8 维裸属性, 已穿装备 }`。**这是存档的基本单元。**
- **战斗 `Entity`(per-run)** — 一局里的临时空壳(`RefCounted`),挂上面那一套组件;每局从 `Character`(或 `EnemyDef`)快照生成,打完即弃。表现层另挂一个可视 Node 引用它,但不混进逻辑。
- **`StatModifier` / `AffixRoll`** — 往属性组件里注入的一条条增减项。

**一句话记忆:`Character` 是你存档里的人,`Entity` 是他这一局的"战斗替身";替身死了存档里的人不掉血。**

---

## 4. 组件:战斗实体是怎么"拼"出来的

战斗 `Entity` 本身是个空壳,能力全靠挂组件(玩家和怪**共用同一套**):

| 组件 | 职责 | 边界(它**不**做什么) |
|------|------|----------------------|
| `StatsComponent` | 持基础值 + modifier 列表,按公式算最终值,脏标记缓存 | 不知道装备/技能存在,只认 modifier |
| `EquipmentComponent` | 管槽位,穿/脱装备 → 向 Stats 注入/回收 modifier(**无损卸载**) | 只翻译"装备→modifier",不算最终值 |
| `SkillComponent` | 出手节奏(攻速累计)+ 6 维伤害结算(暴击/闪避/护甲) | 不碰动画、不碰位置 |
| `AICombatComponent` | 轻量选敌:打"最前的存活目标" | 不算伤害(交给 Skill) |
| `AnimationComponent` | 监听事件播序列帧,**纯表现** | **绝不参与数值**,缺席不影响结算 |

**想加新能力(技能/被动/buff)= 往 Entity 挂个组件、经 `StatModifier` 接进 Stats**,解算公式一行不用改。
这就是"组件化"换来的扩展性。

---

## 5. 主线:跟着一次完整游玩走一遍数据流 ★

这一节是全文最值得读的部分——把上面的零件串成一次真实游玩。

### ① 开机装配(`GameController._boot`)
1. Godot 按 autoload 顺序加载:先 `Player`(持久根 `PlayerState`)、再 `Game`(`GameController`)。
   > 节点名为什么是 `Player` 不是 `PlayerState`?因为叫 `PlayerState` 会撞类名 `class_name PlayerState`,
   > 导致注册失败——所以节点名取 `Player`,类型仍是 `PlayerState`,代码里 `get_node("/root/Player")` 取它。
2. `Game._boot` 依次:建 `DataRegistry` 并**加载+校验**所有图纸 → **`PlayerState.reset()`**(先清干净,
   防 autoload 在测试/重开里残留)→ 建本局 `CombatArena` + `ProgressionController`。
3. 读存档:有档就 `apply`(还原 roster/背包/进度),没档就发默认 roster(一个战士)。
4. **算续战游标**:从存档读出"打到哪关哪场"。这里有个关键修复(见 §6)。

### ② 表现层开一局(`CombatView` → `GameController.begin_run`)
- 悬浮窗 `floating_shell` 里的 `CombatView` 读 `/root/Game` 的 `arena` + `progression` 两个对象,
  调 `begin_run(stages)`(**不传具体关卡 → 用续战游标**)。
- `begin_run` 把 roster 补齐成 **4 格队伍**(空位填 null 容错),每个角色 `Entity.from_character` 快照成战斗替身,
  并把"掉落自动穿装的目标"指到第一个存活成员的装备组件上。

### ③ 战斗 tick(`CombatArena.tick_combat`,固定步长)
每一拍依次:**缠斗计时/狂暴判定 → 我方回血 → 我方按攻速出手**(`AICombat` 选最前存活敌,`Skill` 按 6 维公式
结算伤害,发 `hit_dealt`)→ **敌死结算** → 敌方按攻速反击(闪避→护甲→狂暴加成)→ 团灭判定。

敌人一死,`_handle_enemy_defeated` 干三件事(顺序很重要,和旧版逐条等价):
1. 发 `enemy_defeated` 信号(表现层据此演出);
2. **掉落**:过 `drop_chance` → `LootGenerator` roll 出 `ItemInstance` → `LootIntake` 分流(见 ④)→ 发 `item_dropped`;
3. `progression.advance_after_kill()` 推进进度游标。

### ④ 掉落分流(`LootIntake.handle_drop`)——v1 核心循环的一环
一件掉落进来,按"填空优先于分解"的规则去向三处之一:
- **空槽** → 直接穿上(`EQUIPPED`)——这就是"自动变强";
- 否则**白装且达分解门槛** → 拆成材料进 `PlayerState`(`DECOMPOSED`);
- **蓝/金装** → 进背包(`BAGGED`)。

### ⑤ 通关 Boss → 自动存档(`boss_cleared` → `_autosave`)
打掉关底 Boss 时,`advance_after_kill` 的 Boss 分支:`max_unlocked_stage` +1(永久解锁下一关)→ 发 `boss_cleared`
→ `Game._on_boss_cleared` → `_autosave`。
存档前先 **`_sync_party_equipment`**:把战斗中自动穿到替身上的装备**写回 `Character`**(否则只 buff 了替身、
存档里的人没穿,重开就丢)→ 然后 `SaveSystem.save` 落盘。
> ⚠ **此刻有个微妙时序**:发 `boss_cleared` 那一瞬,场景游标 `cur_scene` **还停在 Boss 格**(`BOSS_SCENE`)——
> 游标要等通关倒计时后才推进。所以**存进档里的游标 = "Boss 那一格"**。这正是 §6 那个 bug 的根源。

### ⑥ 关掉游戏 → 也自动存档
`GameController` 监听窗口关闭(`NOTIFICATION_WM_CLOSE_REQUEST`)→ 同样 `_autosave`。

### ⑦ 重开 → 续战(回到 ①,但这次有存档)
`_boot` 读档 `apply` 后算续战游标——见下一节那条修复。

---

## 6. 一个真实修过的 bug:F-SaveBoss(读懂它就读懂了续战契约)

**现象(你手动 Play 抓到的):** 打通 Boss → 自动存档 → 关游戏 → 重开,**又从那个 Boss 重打了一遍**。

**根因:** §5⑤ 说过,Boss 清算触发自动存档那一刻,游标还停在 `(关 N, BOSS)`。于是存档里写的是
"在 N 关 Boss 格",重开自然从 Boss 开打。可 `max_unlocked_stage` 其实已经 +1 了——存档里**藏着"已经通了"的证据**,
只是续战时读错了字段。

**修法(最小改,不动存档格式、不动战斗状态机):** 只在 `GameController._boot` 续战读取处加一句判别——

> 若存档里 `cur_scene == BOSS_SCENE` **且** `max_unlocked_stage > cur_stage`(= 这关 Boss 已被清),
> 就把续战落点改到 **`(max_unlocked_stage, 0)`**(下一关开头);否则(打一半就关、`max` 还没 +1)续回原 Boss 接着打。

这条判别**唯一对应"Boss 已清"**:团灭回退只会落到普通场景、绝不会把游标设回更早关的 Boss,所以不存在反例。
它现在是**续战契约的第 9 条不变量**(`ARCHITECTURE.md §4`),并有一条**可证伪的回归测**守着
(撤掉补丁该测立刻 FAIL)。

> **为什么讲这个 bug?** 因为它是"持久/per-run 分层 + 时序"最典型的坑,理解它就理解了为什么这套架构
> 要把"什么时候存、存的是哪一刻的状态"当头等大事。

---

## 7. 想加东西怎么加(扩展点)

地基就是为"加配置/加组件就上、不动承重墙"设计的:

| 想做什么 | 怎么加 | 要不要改代码 |
|----------|--------|--------------|
| 新词缀 / 新装备基底 | 往 JSON 池加一条 | **不用**(校验过即生效) |
| 新怪 / 新职业 | 新 def + 组件组合 | 不改解算 |
| 新技能 / 被动 / buff | 往 Entity 挂组件,经 StatModifier 接入 | 只加组件 |
| 等级 / 经验(v2) | `Character` 加 level + 成长曲线写进 base_stats | 存档地基已就位 |
| 多敌团战 | lane 多实体地基已在,加波次配置 | 加配置为主 |
| 真存档 / 多档 / 离线结算 | 扩 `SaveSystem` | 持久层已是序列化目标 |

---

## 8. 现状:地基铺好了,但很多能力"还没点亮"

**REFACTOR-01 地基重构已落地**(四层 = 真实代码、旧单敌 director 已删、表现层切 `Game` autoload、
测试 117/117 全绿)。但你会发现**玩起来和重构前几乎一样**(自动打怪、车轮推进,只多了存档)——
**这是正常的**:行为保持不变正是"重构成功"的标志,这次换的是承重结构,不是手感。

真正的价值是地基里埋了一堆**还没被内容点亮的能力**:

| 地基已就位 | 为什么还没体感 |
|------------|----------------|
| 模板/实例两层 + PoE 式词缀 Tier 掉落 | 掉装在跑,但"掉装→变强"还没在 UI 上铺开;词缀表全占位 |
| lane 多实体团战引擎 | 关卡配置仍是单敌占位,没配多波次 |
| 组件化实体(可挂新技能/职业) | 还没有新内容去挂 |
| 持久层(roster/背包/材料) | 城镇/招募/打造(05-town)还没做 |

**新手感会在"内容开始吃这套地基"时出现**(真正的 build 循环、团战、城镇打造)。

**已知小债(非阻塞):** 两处代码注释还写着"逻辑在 CombatDirector"(`enemy_def.gd` / `stage_config.gd`),
是陈旧出处注释,逻辑其实已搬走,留之后顺手清;数值(lane 几何、词缀 Tier 表、成长曲线)全是占位,待 playtest;
`DataRegistry` 的座位(现为 `Game` 持有的只读对象)等 05-town 需要在战斗外读图纸时再复审。

---

## 9. 文件地图(想看代码从哪进)

| 你想看… | 去这里 |
|---------|--------|
| 开机怎么装配、自动存档、续战 | `src/core/game_controller.gd` |
| 一局战斗怎么跑(tick/出手/掉落) | `src/core/combat/combat_arena.gd` |
| 关卡推进/通关/团灭回退状态机 | `src/core/combat/progression_controller.gd` |
| 6 维伤害公式 | `src/core/combat/skill_component.gd` |
| 属性怎么算(base+modifier) | `src/core/stats/stats_component.gd` |
| 穿脱装备 → 属性增减 | `src/core/items/equipment_component.gd` |
| 掉落怎么 roll / 怎么分流 | `src/core/systems/loot_generator.gd` / `loot_intake.gd` |
| 存档存了什么 / 怎么还原 | `src/core/systems/save_system.gd` |
| 你的家当(队伍/背包/材料) | `src/core/meta/player_state.gd` |
| 图纸加载与校验 | `src/core/systems/data_registry.gd` |
| 画面/血条/飘字 | `src/combat/combat_view.gd` + `scenes/shell/floating_shell.tscn` |

---

### 名词速查

- **autoload** — Godot 的全局单例,开机就在、全程存在(本作:`Player` 持久根、`Game` 装配座)。
- **per-run** — 只活一局的东西,打完即弃(`CombatArena`、战斗 `Entity`)。
- **modifier** — 往属性上加的一条增减项(加法或百分比),装备/buff 都通过它生效。
- **续战游标** — 存档里记的"打到哪关哪场",重开据此接着打。
- **headless** — 没有画面、纯逻辑运行(跑测试、未来离线结算都靠它)。
