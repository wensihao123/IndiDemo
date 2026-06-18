---
artifact: PLAN
feature: 04-loot-equipment
role: Planner
status: draft
updated: 2026-06-18
inputs: [FEATURE-DESIGN.md, CONTEXT-FINDINGS.md, IDEA.md, project-context.md, 03-combat-formula-ext/CHANGES.md]
next: Implementer
---

# PLAN — 暗黑式掉落与装备 (Loot & Equipment)

> 承 FEATURE-DESIGN(B-4 PoE 式 ilvl+分阶池为准)+ CONTEXT-FINDINGS(真实签名/坑)+ HANDOFF 决策记录 D-1/D-2/D-3。
> 本文 = **追认 4 条已拍板决策 + 拍剩余开放项(§5#6 current_hp 跟随)+ 排有序可验证实现步骤 + F4 回归清单**。
> 只排计划,不写代码。数值全占位(F1 数值专章统一精调),本功能只交付"机制 + 数据结构 + 配置位"。

## 1. 目标 / Goal
让 02 的击杀掉落事件落地成**真实装备实例**(部位 + ilvl + 招牌基底 + 词缀[] + 稀有度),并自动消化:
**空槽自动填空 → 否则白装自动分解出材料 → 蓝/金进只读掉落包**;穿戴汇总进 `PartyMember` 8 维喂 03 战斗。
04 切片可独立验收"掉→填空/分解/进包→只读查阅"一条线(FEATURE-DESIGN §5),**不含手动换装/对比/打造(归 05)**。

## 2. 取法与关键决策 / Approach & key decisions
> 每条:**做什么 + 为什么 + 否决了什么**。前 4 条是追认 HANDOFF 决策记录,后续是 Planner 新拍。

- **K1 · 属性分层落在 `PartyMember`(追认 D-1)。** 构造时把传入的 8 维**快照进 `_base`**(裸职业基础值);新增 `equipment: Dictionary`(slot→EquipmentItem)与 `recompute_stats()`:每维生效值 = `_base[维] + Σ 各装备该维贡献`,用 `set(field, total)` 写回。
  *为什么:* D-1 明确 `@export warrior_*` = 裸基础,装备叠加;生效值必须可由"基础+穿戴"重算,才能支持脱下/换上不残留。*否决:* 只存生效值(无法还原基础、脱装会漂);单独 EquipmentManager 持槽(穿戴态天然属成员,4 人各自 3 槽,挂成员最直接)。
- **K2 · 开局白装在运行时由 Inventory 穿上,不烤进 `PartyMember` 构造 / `init_default_party`(追认 D-1 推论)。** `init_default_party` 仍只用 `@export warrior_*` 建裸成员;开局武器+护甲(白,ilvl=1)由 Inventory 在初始化时生成并 `equip` 上去。
  *为什么:* `formula_test`/`combat_director_test` 直接 `PartyMember.new(...)` 灌数值做夹具,若把白装烤进构造会双重计数或改动这些夹具值(破 03 收口)。*否决:* 在 `init_default_party` 里塞白装(污染单元测试基线 + 与 D-1 裸基础语义冲突)。
- **K3 · 扩 `loot_dropped` 签名带 ilvl(追认 D-2,用户已选 B 案,接受 F4 churn)。** 改为 `loot_dropped(kind, rarity, item_level: int)`;ilvl 源 = `EnemyDef` 新增 `@export var item_level: int = 1`;发射处 `combat_director.gd:421` 在 `_roll_loot(def)` 内,`def` 在手 → `loot_dropped.emit(kind, rarity, def.item_level)`。
  *为什么:* 用户在 Explorer session 明确选"直接扩签名"而非新增信号;`_roll_loot(def)` 作用域里 def/cur_stage 都在,代价小。*否决:* 不改签名、04 自取(用户已否);新增并行信号(两套掉落事件易漂,且用户已拍板扩签名)。
- **K4 · 新建 `Inventory` autoload,采用"场景型 autoload"(`.tscn`+脚本)以便 `@export` 挂 `LootTables` 资源(追认 D-3 + 守 hard-NO)。** 背包 + 材料库存 + 物品生成/词缀-阶 roll + 填空/分解消费逻辑全在此;装备槽挂各 `PartyMember`;重算写回成员。**04 仅内存态**,数据设计可序列化,save/load 留后续。
  *为什么:* D-3 指定新建 autoload;LootTables 配置资源路径**不能硬编码**(hard-NO),场景型 autoload 才能在 Inspector 里 `@export` 指派 `.tres`。*否决:* 纯脚本 autoload + `load("res://...")` 硬编码路径(破 hard-NO);把背包挂 PartyMember(背包是跨成员的共享库存)。
- **K5 · 物品/词缀用类型化数据类 + 配置资源,不用裸 Dictionary。** `EquipmentItem`(RefCounted:slot/item_level/rarity/base/affixes)、`Affix`(RefCounted:stat/tier/value);配置 `AffixTierBand`(tier/value_min/value_max/ilvl_req)、`AffixTierDef`(stat/bands[])、`LootTables`(各部位词缀池 + 基底轴配置 + 稀有度→词缀条数 + 分解门槛 + 部位 roll 权重 + 每件分解产材料数)。
  *为什么:* Tier 表是 B-4 核心、要可配置可序列化;类型化便于 gdUnit4 测边界。*否决:* 全靠 Dictionary 魔法键(无类型、Tier 表难配难测)。
- **K6 · `max_hp` 运行时变更时 `current_hp` 跟随 = "存活则加差额,死亡不复活,统一夹到 [0,new_max]"(拍 §5#6 开放项)。** `recompute_stats` 改 `max_hp` 后:若 `current_hp > 0` 则 `current_hp = clamp(current_hp + (new_max-old_max), 0, new_max)`;若已倒(≤0)则只 `clamp(current_hp,0,new_max)`(不靠加血复活)。
  *为什么:* 04 自动填空只增不替,饰品基底可能=生命,装上即"结实一点"(差额立即到账,兑现 §1 fantasy);夹钳避免与 `_revive_party`(过场景/团灭回满)打架——回满仍由 revive 负责,本规则只管增量。*否决:* 按比例缩放(装备瞬间按比例反而可能掉血,反直觉);无条件回满(等于偷偷全队治疗,破战斗状态)。占位规则,playtest 可调(F1)。
- **K7 · `loot_dropped` 的 `kind=gold/material` 直掉在 04 内维持现状(不进新管线)。** Inventory 只消费 `kind=equipment`;gold/material 直掉沿用既有(LootStub 打印),材料库存只由"装备分解"喂(FEATURE-DESIGN §3.7 边界)。
  *为什么:* §3.7 材料来自分解;直掉 material/gold 的经济归属未定,04 不顺手并入(守 hard-NO 范围)。*否决:* 让直掉 material 也进库存(无部位归属、与分解口径混淆)。**列为 flag F-D 交后续。**

## 3. 有序实现步骤 / Ordered steps
> 每步:动作 / 涉及文件 / 验证。逻辑能测的用 gdUnit4(**不带 `-d`**),UI 手动 Play。Godot:`G:\Godot\Godot_v4.6.3\godot.exe`。

**Step 1 — 扩掉落签名 + ilvl 源(K3)。**
- 动作:`combat_director.gd:11` 信号改 `loot_dropped(kind: StringName, rarity: StringName, item_level: int)`;`:421` emit 带 `def.item_level`;`EnemyDef` 加 `@export var item_level: int = 1`。同步改订阅者签名:`loot_stub.gd:13`、`combat_view.gd:215`(加 `_item_level` 参,FX 暂不用)。同步改测试 lambda:`loot_test.gd:26/35/47/63/76`(2 参→3 参)。
- 文件:`src/combat/combat_director.gd`、`src/combat/enemy_def.gd`、`src/combat/loot_stub.gd`、`src/combat/combat_view.gd`、`test/combat/loot_test.gd`。
- 验证:`--headless --check-only --quit` 退出 0;**全套 gdUnit4 绿**(F4 第一道闸:签名改动不破回归)。

**Step 2 — `PartyMember` 分层(K1/K2/K6)。**
- 动作:构造末尾快照 `_base`;加 `equipment: Dictionary` + `equip(item)/unequip(slot)` + `recompute_stats()`(base+Σ装备,`set` 写回,含 K6 的 current_hp 跟随)。`init_default_party` 不动数值(K2)。
- 文件:`src/combat/party_member.gd`。
- 验证:新增 `test/combat/party_equip_test.gd`——穿上加成生效、脱下还原 `_base`、max_hp 增时 current_hp 加差额且不超 max、已倒不被复活。check-only + 该 suite 绿;**回跑 formula_test/combat_director_test 确认裸基础未变。**

**Step 3 — 装备数据类(K5)。**
- 动作:`EquipmentItem`、`Affix`(RefCounted,`class_name`)。
- 文件:`src/loot/equipment_item.gd`、`src/loot/affix.gd`(新目录 `src/loot/`)。
- 验证:check-only 退出 0(暂无行为)。

**Step 4 — 配置资源类 + 占位 LootTables 资源(K5)。**
- 动作:`AffixTierBand`/`AffixTierDef`/`LootTables`(`extends Resource`,`class_name`)。按 FEATURE-DESIGN §3.4 填**生命、暴击率两张占位表**,其余词缀**结构就位、数值占位**;含各部位词缀池(§3.3)、稀有度→条数(白0/蓝1-2/金3+)、分解门槛(默认白)、部位 roll 权重、每件分解产材料数(占位=1)。作 `assets/data/loot/loot_tables.tres`。
- 文件:`src/loot/affix_tier_band.gd`、`src/loot/affix_tier_def.gd`、`src/loot/loot_tables.gd`、`assets/data/loot/loot_tables.tres`。
- 验证:check-only;写一个临时加载断言或并入 Step 5 测试确认 `.tres` 能 load 出预期阶数/区间。

**Step 5 — 物品生成 / 词缀-阶 roll(B-4 核心逻辑)。**
- 动作:在 Inventory(或其调用的 `LootRoller` 纯函数模块)实现:据 `kind=equipment` + rarity + ilvl 生成 `EquipmentItem`——roll 部位 → 据部位定基底招牌轴(饰品三选一)→ 据 ilvl 算基底值(隐式 T 阶)→ 据稀有度定词缀条数 N → 从部位池**不重复**抽 N 个词缀类型 → 各取"ilvl 门槛≤item ilvl 的合格阶"→ 合格阶内均匀挑阶 → 区间内 roll 值。
- 文件:`src/loot/loot_roller.gd`(纯逻辑,便于测)。
- 验证:`test/loot/loot_roll_test.gd`——边界:ilvl 卡门槛(低 ilvl 不出高阶)、同件词缀不重复、部位池约束(武器不出防御词缀)、稀有度→条数(白0/蓝1-2/金3+)、空池/越界兜底。check-only + suite 绿。

**Step 6 — Inventory autoload 消费逻辑(K4/K7) + 开局白装(K2)。**
- 动作:场景型 autoload(`scenes/autoload/inventory.tscn` + `src/loot/inventory.gd`),`@export var loot_tables: LootTables`。连 `Combat.loot_dropped`;`kind==equipment` 时:生成实例 → **填空优先(§3.8)**:对应槽空→`member.equip` + `recompute_stats` + 发 `item_auto_equipped`;否则按门槛:白→分解(材料库存 +N + 发 `material_gained(slot,rarity,amount)`)、蓝/金→进背包列表 + 发 `item_stored`。gold/material 直掉 no-op(K7)。初始化时给战士穿白武器+白护甲(ilvl=1),项链留空。
- 文件:`src/loot/inventory.gd`、`scenes/autoload/inventory.tscn`。
- 验证:`test/loot/inventory_test.gd`——填空优先于分解(空槽白件→穿上;已穿戴白件→分解)、材料累加 + 事件、蓝/金进包、开局只填武器/护甲留空项链。**注:** autoload 注册要等 Step 8;测试用直接 new + 注入 loot_tables 的方式跑纯逻辑(不依赖 `/root/Inventory`)。

**Step 7 — 只读掉落包 UI 面板。**
- 动作:在 CombatView 附近(同读 autoload)挂一个可点开的只读面板,列每件 部位/ilvl/基底/词缀(分稀有度色),**不可换/不可手动分解**。轻反馈:填空"叮"+一行日志、材料 +1 角标(§4,克制,不弹 OS 通知)。
- 文件:`scenes/...`(UI)+ 对应脚本;接 Inventory 信号。
- 验证:**手动 Play**(F7 风格):点开面板看到包内信息、确实只读;后台跑一段白装持续分解、包里只攒蓝/金、零必做操作(§5#5/#6)。

**Step 8 — 接线 + 全回归(交 Engine Integrator + Implementer 收尾)。**
- 动作:`project.godot` 注册 `Inventory` autoload(场景型);Inspector 把 `loot_tables.tres` 指给 `@export`;给现有 stage 的 Boss EnemyDef 设更高 `item_level`(走 `.tres` 编辑,普通怪用默认)。产 INTEGRATION-STEPS 给 Engine Integrator。
- 验证:**F4 全回归**(见 §5 清单)+ 手动 Play 端到端。

## 4. 不做 / Out of scope
- FEATURE-DESIGN §6"先不做"全条:手动换装、对比面板(绿↑红↓)、打造/强化消耗材料、自定义分解门槛 UI、套装、宝石、词缀重铸、按词缀的自动优选/替换、满包兜底、跨主题词缀池 → **归 05/更后**。
- save/load 持久化(全项目尚无存档系统,C-E):04 仅内存态,数据设计成可序列化即可。
- 全部数值精调(各词缀完整 Tier 表/权重/基底成长曲线/分解产量公式/汇总封顶)→ **F1 数值专章**,与 03 F1 合并。
- `kind=gold/material` 直掉的经济归属(K7)→ 后续。

## 5. 风险与 Flags / Risks & Flags
- **F4 回归清单(必跑,接 03 F4):** 改 `loot_dropped` 签名 + 动 `PartyMember`/`EnemyDef` 后,重跑全套 gdUnit4——`loot_test`/`combat_director_test`/`formula_test`/`progression_test`/`retreat_test`/`button_countdown_test`/`tick_driver_test` + 新增 `party_equip_test`/`loot_roll_test`/`inventory_test` + `--headless --check-only`。守住 02 掉落/解锁/回退/后台模拟、03 的 6 维解算与裸基础值不破。**已枚举的 2 参 lambda 同步点:loot_test.gd 26/35/47/63/76。**
- **F-A 已解(K3):** ilvl 源 = `EnemyDef.item_level`(@export 默认 1,Boss 在 `.tres` 调高)。**现有 stage_01/stage_02 的 EnemyDef 子资源会取默认值**,Boss 需在 Step 8 手动调高 → 列入 INTEGRATION-STEPS。
- **autoload 注册 = 唯一引擎侧人工点(Step 8):** 场景型 autoload + `@export` 资源指派要在编辑器做,Implementer 改不动 `project.godot` autoload 的 Inspector 绑定部分 → 必经 Engine Integrator 人机回报闭环。
- **F-D(K7):** `kind=gold/material` 直掉 04 内 no-op,交后续定经济归属。
- **多成员范围:** 设计支持 4 人各 3 槽,但 04 开局只给战士(slot 0)白装;其余成员/队伍扩充不在本切片(`init_default_party` 现也只填 slot 0)。
- **数值全占位(F1):** 仅生命/暴击率两表占位填全,其余结构就位数值占位;别把占位当定稿。守 §8 F5——B-4 已是偏重的 PoE 式 Tier,别外溢做套装/重铸。
