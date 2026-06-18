---
artifact: CONTEXT-FINDINGS
feature: 04-loot-equipment
role: Explorer
status: draft
updated: 2026-06-18
inputs: [project-context.md, FEATURE-DESIGN.md, 03-combat-formula-ext/CHANGES.md]
next: Planner
---

# CONTEXT-FINDINGS — 暗黑式掉落与装备 (Loot & Equipment)

> 勘探目标(FEATURE-DESIGN §8):**F-A** ilvl 来源 = 02 `loot_dropped` 发射点 + 现有"怪等级/进度"概念;
> **F4** 03 战斗如何读 `PartyMember`、04 穿戴汇总往哪写。只报"现状是什么",不提方案(交 Planner)。

## 1. 相关文件 & 各自职责
- `src/combat/combat_director.gd`(class `CombatDirector`,**注册为 autoload `Combat`**,见 `project.godot:20`)——战斗解算核心 + 掉落 roll + 进度状态机。**掉落事件、ilvl 候选来源、战斗读 PartyMember 全在这里。**
- `src/combat/party_member.gd`(class `PartyMember`,`extends RefCounted`)——运行时队员可变状态;**持有战斗用的 8 项数值字段**(装备汇总最终要落到这里)。
- `src/combat/enemy_def.gd`(class `EnemyDef`,`extends Resource`)——怪的数值 + 掉落权重配置。**当前无任何"等级"字段。**
- `src/combat/loot_stub.gd`(class `LootStub`)——临时掉落监听,只 `print`;文件自注:"真正的物品生成 / 入库 = step 03"(即本 04)。**04 要把它替换/升级成真物品生成。**
- `src/combat/combat_view.gd`(class `CombatView`)——战斗视图,订阅 `Combat` 信号渲染;`_on_loot_dropped` 出蓝/金光柱 FX。掉落包面板大概率挂这附近(同读 `/root/Combat`)。
- `src/combat/stage_config.gd` / `scene_config.gd`——关卡/场景配置(`StageConfig.scenes[]` + `boss`,`SceneConfig.enemy` + `kill_count`)。
- `assets/data/combat/stage_01.tres` / `stage_02.tres`——实际关卡数据(怪的 EnemyDef 子资源全在里头)。
- `src/shell/floating_shell.gd`——纯悬浮窗外壳,**不碰战斗/队伍/装备**;`main_scene = scenes/shell/floating_shell.tscn`。CombatView 是另挂的节点(读 autoload)。
- 测试:`test/combat/loot_test.gd`(掉落 roll)、`combat_director_test.gd`、`formula_test.gd`、`progression_test.gd`、`retreat_test.gd`、`button_countdown_test.gd`、`tick_driver_test.gd`——**改信号签名/PartyMember 字段会牵动它们(F4)**。

## 2. 关键数据形状 / 接口(原文签名)

**掉落事件(02→04 边界,F-A 核心):**
```gdscript
# combat_director.gd:11
signal loot_dropped(kind: StringName, rarity: StringName)
# 常量 :35-40
const KIND_GOLD := &"gold"; KIND_MATERIAL := &"material"; KIND_EQUIPMENT := &"equipment"
const RARITY_WHITE := &"white"; RARITY_BLUE := &"blue"; RARITY_GOLD := &"gold"
```
发射点(唯一一处):
```gdscript
# combat_director.gd:408  —— 击杀后被 tick_combat:201 调用,def = 刚被击杀的 EnemyDef
func _roll_loot(def: EnemyDef) -> void:
    ...
    loot_dropped.emit(kind, rarity)   # :421
```
→ **发射处 `def`(EnemyDef)在手,且 `cur_stage`/`cur_scene` 在 `self` 上可读** —— 给掉落带 ilvl 的两个候选源都在同一作用域,接线代价小。

**PartyMember 的 8 项战斗数值(F4,装备汇总落点):**
```gdscript
# party_member.gd:7-18
var display_name: String
var max_hp: float
var attack: float
var current_hp: float
var attack_speed: float
var armor: float
var dodge_chance: float
var crit_chance: float
var crit_mult: float
var hp_regen: float
var attack_progress := 0.0   # 单场运行时累加器,非属性
```
构造默认值由 `CombatDirector.init_default_party()`(:129)从 `@export var warrior_*`(:44-53)塞入;`current_hp = max_hp`(party_member.gd:27)。

**EnemyDef(无等级字段):**
```gdscript
# enemy_def.gd —— 字段全集:display_name, max_hp, attack, attack_speed, sprite,
#   drop_chance, weight_gold/material/equipment, rarity_weight_white/blue/gold
# 没有 level / item_level / tier 之类
```

## 3. 当前相关流程(端到端)

**掉落流:** `_process`(:115,固定步长)→ `tick_combat`(:166)→ 我方离散命中把 `_enemy_hp` 打到 ≤0 →`enemy_defeated.emit(defeated)` + `_roll_loot(defeated)`(:201)→ `_roll_loot` 先 roll 是否掉(`def.drop_chance`)、再 roll kind、非金币再 roll rarity → `loot_dropped.emit(kind, rarity)`(:421)。**订阅者 3 个**:`LootStub._on_loot_dropped`(print)、`CombatView._on_loot_dropped`(FX,:215)、各测试里的 lambda。**事件之后没有任何"生成物品实例/入库"逻辑——这正是 04 要接的空位。**

**战斗读 PartyMember:** `tick_combat` 直接读字段——回血 `m.hp_regen`(:176)、出手 `m.attack_speed`(:182)、伤害 `m.attack`(:187)、暴击 `m.crit_chance`/`m.crit_mult`(:188-190);敌人反击读 `target.dodge_chance`(:215)、`target.armor`+`armor_k`(:219-220)。**没有"基础值 vs 装备加成"分层——`PartyMember` 字段即最终生效值,`@export warrior_*` 就是开局基础值直接灌进去。**

**队伍构建/血量:** `init_default_party`(:129)只填第 0 格;`_revive_party`(:400)把 `current_hp = max_hp`(过场景/团灭/通关调用)。**若装备运行时改 `max_hp`,与 `current_hp`、`_revive_party` 的交互需 Planner 定。**

**进度概念:** 只有整数游标 `cur_stage`/`cur_scene`/`max_unlocked_stage`(:90-93)。无"探索深度等级""怪等级"等连续量。

## 4. 约束 & 坑(勘探所得)

- **C-A · 没有等级概念可直接拿来当 ilvl。** `EnemyDef` 无 level 字段;唯一进度量是 `cur_stage`/`cur_scene` 整数游标。ilvl 要么**给 EnemyDef 加 `item_level`(走 Resource 配置,守 hard-NO)**,要么**从游标算**(如 `ilvl = f(cur_stage, cur_scene)`)。两者都在 `_roll_loot` 作用域内可取。**Planner 必须定,否则 Tier 门槛无意义(F-A)。**
- **C-B · 改 `loot_dropped` 签名会波及 3 类订阅者 + 多个测试。** `loot_test.gd` 里多处 `loot_dropped.connect(func(_k, _r): ...)`(2 参 lambda)、`LootStub._on_loot_dropped(kind, rarity)`、`CombatView._on_loot_dropped(kind, rarity)`。若给事件加 ilvl/物品实例参数,**全部要同步改**(F4 回归)。或者**不改签名、改由 04 自己在 autoload 内取 ilvl**——Planner 取舍。
- **C-C · PartyMember 无"基础 vs 装备"分层,且字段即生效值。** 现状 `@export warrior_*` → `PartyMember` 字段 = 最终值。装备汇总(基底+词缀加到 8 维)需要一个**"基础值 + 装备加成 → 重算生效值"**的机制;现在没有。**且开局 warrior 已有 attack=6/max_hp=120 等非零基础值**——与 FEATURE-DESIGN §3.5 "开局自带全白基础装"语义重叠:**"裸战士基础值"和"白装基底数值"谁是谁、怎么叠,Planner/GD 要厘清**(否则会双重计数)。
- **C-D · PartyMember 无装备槽、无背包、无材料库存——全是新结构。** 三槽穿戴、掉落包列表、`{部位×稀有度→数量}` 材料库存都要新建;挂哪(扩 PartyMember? 新建 Inventory/Equipment autoload? 挂 Combat?)由 Planner 定。
- **C-E · 无存档系统。** project-context §0 把 save/load 列为 MVP 但**目前不存在**;装备/背包/材料是典型需持久化的状态,落地后**无处持久化**——本功能可先做内存态,但需 flag 依赖。
- **C-F · `max_hp` 运行时变更的连锁。** `_revive_party`/构造把 `current_hp` 锚到 `max_hp`;第一件饰品自动填空若改 `max_hp`(饰品基底可能=生命),需定 `current_hp` 怎么跟随(按比例?补满?),别和过场景回满逻辑打架。
- **C-G · 自动填空"绝不替换已穿戴"目前无任何实现锚点。** 现在掉落后什么都不做(只 print/FX)。填空/分解优先级(FEATURE-DESIGN §3.8)是全新逻辑,需在"`loot_dropped` 之后"接一段消费逻辑(替代 LootStub)。

## 5. Flags / 给 Planner 的开放问题
> **2026-06-18:#1-#5 已由用户在 Explorer session 当场拍板**(见 HANDOFF 决策记录 D-1/D-2/D-3);#6 仍开放,#7 是常驻清单。

1. **(F-A 落地)ilvl 来源 → 已定:`EnemyDef` 加 `@export item_level`**(配置驱动、Boss 给更高;`_roll_loot(def)` 处 def 在手可取)。**Planner 确认即可。**
2. **(C-B)事件接口 → 已定:扩 `loot_dropped` 签名带上 ilvl(/物品载荷)**;接受 3 订阅者 + 掉落测试 2 参 lambda 的同步改动(纳入 #7 回归)。
3. **(C-C)基础值 vs 装备分层 → 已定(D-1):** `@export warrior_*` = 裸职业基础值;装备(含开局白装)叠加,total = 基础 + Σ装备,开局白装 ilvl=1 数值小、不双重计数、不打乱 03。**归 GD 文档,Planner 据此排实现。**
4. **(C-D)装备/背包/材料挂哪 → 已定(D-3):** 新建 `Inventory`/`LootSystem` autoload(背包+材料+消费/roll 逻辑);装备槽挂各 `PartyMember`;重算写回 PartyMember。
5. **(C-E)存档 → 已定:04 仅内存态**,数据设计成可序列化,save/load 留后续功能。
6. **(C-F,仍开放)`max_hp` 改变时 `current_hp` 的跟随规则**,与 `_revive_party`/过场景回满的兼容。**交 Planner。**
7. **(F4 回归清单)** 接入后必须重跑:`loot_test` / `combat_director_test` / `formula_test` / `progression_test` / `retreat_test` / `button_countdown_test` / `tick_driver_test` + `--headless --check-only`;**改 `loot_dropped` 签名后这些里的 `connect(func(_k,_r)...)` 全要同步加参**;守住 02 掉落/解锁/回退/后台模拟与 03 的 6 维解算不破。
