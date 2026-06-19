---
artifact: PLAN
feature: 04-loot-equipment
role: Planner
status: draft
updated: 2026-06-19
inputs: [FEATURE-DESIGN.md, project-context.md, ARCHITECTURE.md, src/core/combat/combat_arena.gd, src/combat/combat_view.gd, src/combat/enemy_def.gd, src/core/combat/entity.gd, src/core/stats/stats_component.gd, src/core/items/equipment_component.gd, src/core/items/item_instance.gd, src/core/game_keys.gd, src/core/systems/loot_generator.gd]
next: Implementer
---

# PLAN — 暗黑式掉落与装备:表层查阅面板 + 稀有度权重接线 (收窄版)

> ⚠ **本文是 2026-06-19 收窄重写,替换原 8 步后端 retrofit PLAN(已 superseded)。**
> 后端(掉落流水线 / ilvl 分阶池 / EquipmentComponent→StatsComponent modifier / 空槽穿·白分解·蓝金进包)
> 已被 REFACTOR-01 整体落地、117/117 测过。**本 PLAN 不重做后端**,只交付两件:
> ① 只读查阅面板(掉落包 + 当前装备双栏,8 维属性,自动填空显形);② 把稀有度从均匀随机改成读 `EnemyDef` 权重。
> 只排计划,不写代码。数值精调归 num-smith(F-NUM,并行),本 PLAN 不动配置数字。

## 1. 目标 / Goal
在 `CombatView` 里加一个可点开的**只读查阅面板**——左栏列掉落包(`PlayerState.bag`)、右栏列当前装备 3 槽 + 8 维生效属性(读活体 `Entity`),自动填空时属性行**跳变显形**兑现"挂机变强";同时修掉 `combat_arena.gd:_drop_loot` 稀有度均匀随机的 gap,改读 `EnemyDef.rarity_weight_*`(守支柱 3:金/白不该等概率)。两件均不改架构(F-ARCH-OK)。

## 2. 取法与关键决策 / Approach & key decisions
> 每条:**做什么 + 为什么 + 否决了什么**。

- **D1 · 稀有度权重用纯静态函数 `LootGenerator.pick_weighted(weights: Array, rng: RandomNumberGenerator) -> int` 选择,掉落点构造 `[def.rarity_weight_white, def.rarity_weight_blue, def.rarity_weight_gold]` → 返回 idx → `GameKeys.RARITIES[idx]`。**
  *为什么:* `EnemyDef` 已有这三个 `@export`(普通怪 80/18/2、Boss 50/38/12)就位,只是 `_drop_loot` 没读;纯静态加权挑选可被 gdUnit4 确定性测(注入种子)。*否决:* 把 roll 逻辑塞进 `EnemyDef`(数据类不该持随机逻辑);新建 RNG 服务(过度设计,arena 已持 `rng`);同时改 slot/kind 权重(超范围——slot 现也均匀,但守 FEATURE-DESIGN 范围只动 rarity;kind 是 F-KIND 待 Producer)。
- **D2 · 面板在 `CombatView` 内用代码构建(`Panel`/`VBoxContainer`/`Label` + `add_child`),一个 `Button` 切换显隐,零 `.tscn`/`floating_shell.tscn` 改动。**
  *为什么:* `CombatView` 现有全部 UI 都是 `_build_ui()` 代码生成(无 .tscn widget),面板跟从同一模式最省接线、不碰场景文件(F-ARCH-OK、不需 Engine Integrator)。*否决:* 单独 `.tscn` 面板(引入场景绑定 + Inspector 接线,违背"纯读不改架构");改 `floating_shell.tscn`(超范围)。
- **D3 · 右栏(当前装备 + 8 维属性)读活体 `Entity`,不读 `Character`。** 取 `_gc.arena.players[0]`(第一个非空队员的 Entity),装备槽读 `entity.equipment.get_equipped(slot)`,属性读 `entity.stats.get_final(stat)`。
  *为什么:* 自动填空写的是活体 `EquipmentComponent`→`StatsComponent`(见 entity.gd `from_character` + arena 的 `loot_equipment`),只有读活体才能让"刚穿上的白装"立即显形;读 `Character` 会显示静态初始态、错过变强瞬间。*否决:* 读 `Character.equipment`(静态、不反映运行时自动填空)。
- **D4 · 左栏(掉落包)读 `_gc.player_state.bag`(`Array[ItemInstance]`),每件显示 部位/ilvl/稀有度(着色)/词缀行。** 用 `CombatView` 已有的 `RARITY_COLOR` 给稀有度上色。
  *为什么:* 蓝/金进包后落在 `PlayerState.bag`(player_state.gd 已确认),只读它即得包内容;复用既有颜色字典保持一致。*否决:* 自建颜色映射(重复)。
- **D5 · 面板刷新 = 打开时 + 可见时收到 `item_dropped` 时,不每帧刷。** `CombatView` 已订阅 `arena.item_dropped`(`_on_item_dropped`);在其尾部加 `if _panel_visible: _refresh_panel()`;`_process` 不参与面板刷新。
  *为什么:* 面板是低频查阅,每帧重建 Label 浪费且与 `_process` 的 `visible` 门控冲突;事件驱动刷新精确对上"掉落→填空→属性跳变"的显形时机(兑现 §1 fantasy)。*否决:* 每帧 `_refresh_panel()`(无谓开销);只在打开时刷(错过打开期间的实时掉落变强)。
- **D6 · 8 维属性显示按维度格式化:** `crit_chance`/`dodge_chance` 显示百分比(`×100` + `%`),`crit_mult` 显示 `×N.N`,`attack_speed` 显示 `N.N/s`,`hp_regen` 显示 `N.N/s`,`attack`/`max_hp`/`armor` 显示整数。维度顺序与名称取 `GameKeys.STATS`。
  *为什么:* FEATURE-DESIGN 拍板"8 维属性明细"作为变强反馈;裸浮点(如暴击 0.05)不可读,需按语义格式化。*否决:* 统一裸数字(暴击率/倍率/攻速辨识不清);引入战力合分(FEATURE-DESIGN 已明确不做战力分)。

## 3. 有序实现步骤 / Ordered steps
> 每步:动作 / 涉及文件 / 验证。逻辑用 gdUnit4,UI 手动 Play。
> gdUnit4:`"G:/Godot/Godot_v4.6.3/godot.exe" --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test`;语法:`--headless --check-only`。

**Step 1 — `LootGenerator.pick_weighted` 纯静态加权挑选(D1)。**
- 动作:在 `loot_generator.gd` 加 `static func pick_weighted(weights: Array, rng: RandomNumberGenerator) -> int`——求和 → `rng.randf() * total` → 累加定位 idx;`total <= 0` 兜底返回 0;全零数组返回 0。
- 文件:`src/core/systems/loot_generator.gd`。
- 验证:`test/core/loot_generator_test.gd` 加用例——注入固定种子确定性命中、分布 N 次后各桶占比 ≈ 权重(±3%)、`[0,0,0]→0`、`[0,1,0]→1`、单元素 `[5]→0`。check-only 退出 0 + suite 绿。

**Step 2 — 掉落点改读稀有度权重(D1)。**
- 动作:`combat_arena.gd:_drop_loot` 把 `var rarity := GameKeys.RARITIES[rng.randi() % GameKeys.RARITIES.size()]` 改为 `var rarity := GameKeys.RARITIES[LootGenerator.pick_weighted([def.rarity_weight_white, def.rarity_weight_blue, def.rarity_weight_gold], rng)]`。slot 保持均匀(范围外)。
- 文件:`src/core/combat/combat_arena.gd`。
- 验证:`test/core/combat/arena_loot_test.gd`——构造 `rarity_weight_white=100,blue=0,gold=0` 的 `EnemyDef` 跑多次掉落,断言全 white;再 `gold=100` 断言全 gold;确认读的是 `def` 字段而非均匀。check-only + suite 绿。

**Step 3 — 面板骨架 + 切换按钮(D2,空内容)。**
- 动作:`_build_ui()` 末尾加一个"背包/装备"`Button` 和一个默认隐藏的 `Panel`(`_panel`,内含左右两个 `VBoxContainer`:`_bag_col` / `_equip_col`);按钮 `pressed` 切 `_panel.visible` 并维护 `_panel_visible`,打开时调 `_refresh_panel()`(本步可空实现)。
- 文件:`src/combat/combat_view.gd`。
- 验证:**手动 Play** floating_shell —— 按钮出现、点击能开合一个空面板,不挡战斗演出、不报错。

**Step 4 — 左栏掉落包列表(D4)。**
- 动作:`_refresh_panel()` 重建 `_bag_col`:遍历 `_gc.player_state.bag`,每件一行 `部位 · ilvl · 稀有度(RARITY_COLOR 着色)`,下挂词缀行(读 `inst.affixes` 的 `stat/value`);空包显示占位行。
- 文件:`src/combat/combat_view.gd`。
- 验证:手动 Play —— 让战斗掉出蓝/金进包,开面板见条目与颜色正确;白装不出现在包里(被分解/穿戴)。

**Step 5 — 右栏当前装备 3 槽 + 8 维属性(D3/D6)。**
- 动作:`_refresh_panel()` 重建 `_equip_col`:取 `_gc.arena.players[0]`(空守卫);3 槽各显示 `get_equipped(slot)`(空槽显"—");其下列 `GameKeys.STATS` 8 维 `entity.stats.get_final(stat)`,按 D6 格式化。
- 文件:`src/combat/combat_view.gd`。
- 验证:手动 Play —— 面板右栏显示战士当前武器/护甲/饰品 + 8 维数值;开局空饰品显"—";数值与战斗表现量级一致。

**Step 6 — 自动填空"变强显形"(D5)。**
- 动作:`_on_item_dropped(inst, dest)` 尾部加 `if _panel_visible: _refresh_panel()`;当 `dest == 装备(EQUIPPED)` 时,对应属性行/槽位做一次短促高亮(绿色闪一下,复用既有 FX 风格,纯表现)。
- 文件:`src/combat/combat_view.gd`。
- 验证:手动 Play —— 开着面板挂机,空槽被自动填上时右栏对应行实时跳变 + 高亮,兑现"看见自己变强";已穿戴槽不被替换(后端保证,面板只读不写)。

**Step 7 — 全回归 + 语法闸。**
- 动作:无新代码,跑校验。
- 文件:—。
- 验证:`--headless --check-only` 退出 0；**全套 gdUnit4 绿**(重点 `loot_generator_test` / `arena_loot_test` 不破,面板纯读不引入逻辑回归）；手动 Play 端到端走一遍 §3 各步观察点。

## 4. 不做 / Out of scope
- **手动换装 / 对比面板(绿↑红↓)/ 打造 / 强化 / 自定义分解门槛 UI** → 归 05 城镇。
- **kind roll(金币/材料种类)** → F-KIND,待 Producer 拍;本 PLAN 掉落仍恒为装备,`_drop_loot` 不动 kind。
- **slot 权重**(部位仍均匀随机)→ 范围外,未列入 FEATURE-DESIGN。
- **全部数值精调**(词缀 Tier 表 / base 曲线 / 合格阶权重 / 稀有度权重数值 / 各怪 item_level·drop_chance)→ **F-NUM,交 num-smith 并行**,本 PLAN 只接线读权重、不改权重数字。
- **满包兜底**(F-BAG)→ 推后。
- **`floating_shell.tscn` / 架构 / autoload / 后端管线**任何改动 → 不碰(F-ARCH-OK)。

## 5. 风险与 Flags / Risks & Flags
- **F-NUM(并行,num-smith):** 本 PLAN 接线读 `EnemyDef.rarity_weight_*` 但**不定这些数字**;Step 2 用 100/0/0 这类极端值做测试夹具,真实权重由 num-smith 精调(与 03 数值合表)。两条线无序依赖,可并行。
- **F-KIND(待 Producer):** 掉落恒为装备(kind 未接);若 Producer 决定 v1 纳入金币/材料 kind,需另开一步在 `_drop_loot` 接 `weight_gold/material/equipment` —— 不在本切片。
- **R1 · 800×250 布局紧:** 主区固定 800×250,双栏面板 + 战斗演出同屏,可能拥挤;Step 3 起手动 Play 确认面板不压住战斗关键信息(必要时面板覆盖式弹出、开时半遮战斗)。属手动验证项。
- **R2 · UI 仅手动验:** Step 3–6 全是 `CombatView` UI,按 §5 政策只能手动 Play 验,无法 gdUnit4 自动化;唯一可测逻辑是 Step 1–2 的加权挑选。报告完成时显式声明"UI 经手动 Play 验"。
- **R3 · 活体空守卫:** `_gc.arena.players` 在 `begin_run` 前为空/未装配,`_refresh_panel` 右栏须先判空(`players.is_empty()` 或首元素 null),否则开局未进战斗时点开面板会空引用。Step 5 必带守卫。
- **F-ARCH-OK(确认):** 面板纯读 `bag[]`/`EquipmentComponent`/`StatsComponent`,稀有度接线只在 `_drop_loot` 内读既有 `@export`,无架构改动、无需 /arch-guard、无 Engine Integrator 人工接线点。
