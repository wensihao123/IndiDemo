---
artifact: PLAN
feature: 00-foundation-redesign
role: Planner
status: draft
updated: 2026-06-19
inputs: [project-context.md, ARCHITECTURE.md, arch/REFACTOR-01-foundation-redesign.md, 04-loot-equipment/FEATURE-DESIGN.md, src/combat/combat_director.gd, src/combat/party_member.gd, src/combat/enemy_def.gd, test/combat/formula_test.gd]
next: Implementer
---

# PLAN — 底层地基重构 · 第一批(层 1-4 纯逻辑地基)

> 本 PLAN **只覆盖 REFACTOR-01 §4 的层 1-4**(数据层 → 属性引擎 → 持久层 → 掉落流水线)。
> 层 5-8(战斗层重构 / 表现层 / 存档 / 接线全回归)= **第二批,本批全绿后单开一份 PLAN**。
> 设计源:`harness/arch/REFACTOR-01-foundation-redesign.md` + `harness/ARCHITECTURE.md`;装备数值设计源:`04-loot-equipment/FEATURE-DESIGN.md`。

## 1. Goal

搭起"持久元状态 + 模板-实例 + modifier 属性 + PoE 掉落流水线"四层**纯逻辑地基**,**全部以 gdUnit4 收口、完全不碰 `src/combat/*` 与现有 45 个测试、不动 `project.godot`** —— 为第二批替换 `CombatDirector` 备好可被战斗层快照消费的实地基。

## 2. Approach & key decisions

> 每条:决策 + 为什么 + 否掉的备选。

- **D1 · 新地基与旧战斗"并存",本批零改 `src/combat/*` 与现有测试。**
  新代码全落 `src/core/` 与 `data/config/`,旧 `combat_director.gd`/`party_member.gd` 原样不动。
  **Why:** 现有 45 测试是 02/03 公式的回归锚(`formula_test.gd` 直接构造 `PartyMember`、驱动 `tick_combat()` 断言 6 维公式值);本批不接战斗,旧锚保持 100% 不变即"未破坏"最硬证据。替换 director 与迁移测试是第二批层 5 的事。
  **否掉:** "边建边把 director 改成读 StatsComponent" —— 会在地基未落定时就动回归锚,风险前移,违背"逐层落定再上一层"。

- **D2 · 本批不注册任何 autoload,`DataRegistry`/`PlayerState` 以普通 `class_name` 落地、测试直接 `new()` 注入。**
  ARCHITECTURE 把二者标为 autoload,但 autoload 注册 = 改 `project.godot` = 引擎侧人工点(Engine Integrator)。
  **Why:** 本批要"Implementer 自交付 + 纯 gdUnit4 收口",不引入人机回报闭环。类本身即可被战斗层消费;autoload 注册并入第二批层 8 与 `Combat`→新系统集一起做。
  **否掉:** 本批就注册 autoload —— 会过早触发引擎侧人工点、且此时无人消费,纯负担。

- **D3 · 配置目录/路径走"可注入参数",默认值是结构常量而非平衡数值。**
  `DataRegistry.load_all(config_dir := "res://data/config")`;测试喂 fixture 目录。
  **Why:** 守 hard-NO"路径不硬编码进逻辑"+ 让校验/解析可用畸形 fixture 测。**否掉:** 写死 `res://data/config` 进函数体 —— 不可测、撞 hard-NO。

- **D4 · 装备/词缀/掉落表三份模板存 JSON;怪/关卡保持 `.tres`(沿用现有)。**
  `data/config/{item_bases,affix_pool,loot_tables}.json`。`EnemyDef`/`StageConfig` 本批**不碰**。
  **Why:** ARCHITECTURE §2 的混合存储分工(海量、要 Claude 批量生成的走 JSON;少而调手感的走 .tres)。`LootTableDef` 虽小,仍归 JSON 与另两份共享一条 `DataRegistry` 校验路径(单一闸)。
  **否掉:** `LootTableDef` 单独做 .tres —— 多一条加载/校验路径,收益不抵。

- **D5 · 纯算组件(`StatsComponent`/`EquipmentComponent`/`StatModifier`/`ItemInstance`/`Character`/`LootGenerator`)= `RefCounted`;`PlayerState` = `Node`(为日后 autoload + 发 signal)。**
  **Why:** ARCHITECTURE §6 软决策——纯算组件无需进树;`PlayerState` 要发 `material_gained` 等跨系统 signal 且将成 autoload,用 Node。
  **否掉:** 全 Node —— 纯算组件进树是无谓开销(撞 §6 倾向)。

- **D6 · `Character`/`ItemInstance`/`PlayerState` 本批即写 `to_dict()`/`from_dict()` 并做内存 round-trip 测,但不落盘。**
  **Why:** ARCHITECTURE §2 不变量"数据设计成可序列化";内存 round-trip 能极廉价地证明字段确实可序列化,真正的文件 `SaveSystem` 留层 7。
  **否掉:** 序列化全推到层 7 —— 到时才发现某字段(如 `ItemInstance.base` 指向模板)不可直接序列化,要返工持久层。提前用 round-trip 钉死"实例存 base 的 id、读取时回查 DataRegistry"。

- **D7 · 掉落"填空优先于分解"的 intake 编排放层 4(流水线尾),而非层 3。**
  `LootGenerator` 产出 `ItemInstance` 后,`LootIntake.handle_drop(...)` 路由:空槽→穿;否则白→分解出材料;蓝/金→进包(04 §3.8)。
  **Why:** intake 是"生成→消费"的桥,自然属流水线尾;它调用层 3 的 `EquipmentComponent`/`PlayerState` API,放层 4 不破依赖方向。
  **否掉:** 放层 3 —— 此时 `LootGenerator` 尚不存在,intake 无 `ItemInstance` 可路由。

- **D8 · `ilvl` 在本批是 `LootGenerator.generate(...)` 的入参,不在本批确定来源。**
  04 §8 F-A 的"ilvl 来源 = `EnemyDef.item_level` / 进度"是**战斗侧产掉落时**才需要的接线,属第二批层 5。
  **Why:** 本批 LootGenerator 是纯函数,ilvl 由调用方给;在此定 EnemyDef 字段=提前碰战斗。**否掉:** 本批就给 EnemyDef 加 `item_level` —— 越界碰 .tres/战斗,违 D1。

## 3. Ordered steps

> 目录(D1/D5,Implementer 可微调命名,确认无 `class_name` 撞车后落定):
> ```
> src/core/data/      item_base_def.gd  affix_def.gd  loot_table_def.gd
> src/core/stats/      stat_modifier.gd  stats_component.gd
> src/core/items/      item_instance.gd  affix_roll.gd  equipment_component.gd
> src/core/meta/       character.gd  player_state.gd
> src/core/systems/    data_registry.gd  loot_generator.gd  loot_intake.gd
> data/config/         item_bases.json  affix_pool.json  loot_tables.json
> test/core/           各 *_test.gd
> ```
> **所有数值是占位**(守 04 §8 F1 / 03 F1,结构才是交付物)。每步独立 gdUnit4 收口;每步末跑 `godot --headless --check-only` 必须 0 错。

### 层 1 — 数据层 (DataRegistry + 模板 def)

1. **建三个模板 def 类型(`RefCounted`,字段即 schema)。**
   - `ItemBaseDef`:`slot: StringName`(weapon/armor/accessory)、`signature_axes: Array[StringName]`、`signature_mode`(ALL=武器双轴全给 / PICK_ONE=饰品三选一)、基底值随 ilvl 的占位曲线参数(每轴 `{base, per_ilvl}`,value=base+per_ilvl×ilvl)。
   - `AffixDef`:`stat: StringName`(8 维之一)、`kind`(FLAT|PERCENT)、`slot_pool: Array[StringName]`、`tiers: Array`(每阶 `{tier:int, min:float, max:float, ilvl_req:int, weight:float}`)。
   - `LootTableDef`:`rarity_affix_count: {white:[0,0], blue:[1,2], gold:[3,4]}`(占位)、`decompose_threshold: StringName`(默认 white)、`material_per_decompose:int`(占位 1)。
   - 文件:`src/core/data/{item_base_def,affix_def,loot_table_def}.gd`。
   - **Verify:** `--check-only` 0 错;`new()` 可建、字段可读(随层 1 测一起)。

2. **写占位 JSON 配置三份。**
   - `item_bases.json`:weapon(攻击+攻速 ALL)、armor(护甲 ALL)、accessory(生命/闪避/秒回 PICK_ONE)。
   - `affix_pool.json`:按 04 §3.3 部位池(武器=攻击/攻速/暴击率/暴击伤害;护甲=护甲/闪避/生命/秒回;饰品=混合 7 轴);**生命、暴击率两条按 04 §3.4 占位表填全 Tier,其余条目结构就位、Tier 数值占位**。
   - `loot_tables.json`:稀有度→条数 + 分解门槛。
   - 文件:`data/config/*.json`。
   - **Verify:** JSON 合法(`JSON.parse_string` 不报错),随步 3 被 DataRegistry 解析。

3. **`DataRegistry`(`class_name`,非 autoload):`load_all(config_dir)` 解析三份 JSON → 类型化 def 对象 + 启动校验 + 访问器。**
   - 校验(强制闸,ARCHITECTURE §4#6):字段齐全、`stat ∈ 8 维集`、`slot ∈ {weapon,armor,accessory}`、`affix.slot_pool ⊆ 合法 slot`、`tier.min ≤ max`、`ilvl_req ≥ 1`;失败 → 收集错误列表(`get_load_errors()`),不静默吞。
   - 访问器:`get_item_base(slot)`、`get_affixes_for_slot(slot)`、`get_loot_table()`。
   - 文件:`src/core/systems/data_registry.gd`。
   - **Verify:** `test/core/data_registry_test.gd` —— ① 喂合法 fixture 目录 → 三类 def 数量/字段正确解析;② 喂畸形 fixture(未知 stat / `ilvl_req=0` / min>max / 缺字段)→ `get_load_errors()` 各报对应错且不崩。`--check-only` 0 错。

### 层 2 — 属性引擎 (StatsComponent + StatModifier)

4. **`StatModifier`(`RefCounted`):`{stat:StringName, kind:enum{FLAT,PERCENT}, value:float, source}`。**
   - 文件:`src/core/stats/stat_modifier.gd`。**Verify:** 随步 5 测。

5. **`StatsComponent`(`RefCounted`):持 8 维 base(`Dictionary{stat→float}`)+ modifier 列表 + 脏标记缓存。**
   - `set_base(stat,v)` / `add_modifier(mod)` / `remove_modifiers_by_source(source)` / `clear_modifiers()`;`get_final(stat) -> (base+ΣFlat)×(1+ΣPercent)`;任何写操作置脏,`get_final` 惰性重算并缓存。对外**只读**最终值(ARCHITECTURE §3.1 / 不变量 #2)。
   - 文件:`src/core/stats/stats_component.gd`。
   - **Verify:** `test/core/stats_component_test.gd` —— base-only=base;+FLAT;+PERCENT;FLAT+PERCENT 组合按公式;**`add` 后 `remove_by_source` 精确回到 base(无损卸载,根除脱装残留 = 不变量 #2 的核心断言)**;脏缓存(连续读不变、加 mod 后变)。`--check-only` 0 错。

### 层 3 — 持久层 (Character + PlayerState + EquipmentComponent)

6. **`ItemInstance` + `AffixRoll`(`RefCounted`)+ `to_modifiers()`。**
   - `AffixRoll: {stat, kind, tier:int, value:float}`;`ItemInstance: {base_id:StringName, ilvl:int, rarity:StringName, affixes:Array[AffixRoll]}`(**存 base 的 id 不存对象引用,D6 可序列化**;取 def 时回查 DataRegistry)。
   - `to_modifiers(registry) -> Array[StatModifier]`:基底招牌轴(按 ilvl 算值)+ 每条 affix → modifier,`source = 本实例`。
   - 文件:`src/core/items/{item_instance,affix_roll}.gd`。**Verify:** 随步 7/8 测 + D6 round-trip。

7. **`EquipmentComponent`(`RefCounted`):管 3 槽,穿/脱 `ItemInstance` ↔ 向 `StatsComponent` 注入/回收 modifier。**
   - `equip(slot, instance)`:若该槽已穿先 `unequip`;注入 `instance.to_modifiers()`(source=instance)。`unequip(slot)`:`stats.remove_modifiers_by_source(instance)` + 清槽。`empty_slots()` / `is_slot_empty(slot)`。
   - 文件:`src/core/items/equipment_component.gd`。
   - **Verify:** `test/core/equipment_component_test.gd` —— 穿一件 → 对应 `stats.get_final` 上升符合该件 modifier 之和;脱下 → 精确回 base(无损);换装(已穿再 equip)→ 旧 modifier 不残留。

8. **`Character`(`RefCounted`,持久单元)+ `PlayerState`(`Node`,本批不注册 autoload)。**
   - `Character: {id, class_id, base_stats:Dict 8维, equipped:{slot→ItemInstance}}` + `to_dict()/from_dict(registry)`;可由其 base 建 `StatsComponent`。
   - `PlayerState`:`roster:Array[Character]`、`bag:Array[ItemInstance]`、`materials:Dict{ "slot|rarity" → int }`;`add_material(slot,rarity,n)`(发 `material_gained(slot,rarity,n)`)、`add_to_bag(inst)`;`to_dict()/from_dict(registry)`。
   - 文件:`src/core/meta/{character,player_state}.gd`。
   - **Verify:** `test/core/player_state_test.gd` —— 材料累加正确 + `material_gained` 触发(用 gdUnit4 `monitor_signals`);**`Character`/`PlayerState` `to_dict→from_dict` round-trip 等值(D6,含 equipped 装备经 base_id 回查重建)**。

### 层 4 — 掉落流水线 (LootGenerator + LootIntake)

9. **`LootGenerator`(`RefCounted`,纯逻辑):`generate(slot, ilvl, rarity, registry, rng) -> ItemInstance`(承 04 B-4 PoE roll)。**
   - 条数 = `loot_table.rarity_affix_count[rarity]` 内随机(白 0 / 蓝 1-2 / 金 3+);
   - 取该 slot 词缀池 → 选 `count` 条**不重复 stat**(04 §3.4);每条:在 `ilvl_req ≤ ilvl` 的**合格 Tier**里挑一阶(占位均匀,权重留 F2)→ 区间内 roll 值;
   - 基底招牌轴按 `signature_mode`(武器双轴 / 饰品 PICK_ONE)定,值按 ilvl 占位曲线。
   - 文件:`src/core/systems/loot_generator.gd`。
   - **Verify:** `test/core/loot_generator_test.gd`(注入 `rng.seed`)—— 白→0 条 / 蓝→1-2 / 金→3+;affix 的 stat 互不重复;全部 stat ∈ 该 slot 池;**无任何 affix 的 `ilvl_req > 物品 ilvl`(门槛守约)**;低 ilvl 取不到高 Tier;基底招牌轴存在且 PICK_ONE 只一轴。

10. **`LootIntake`(`RefCounted` 或 `PlayerState` 上方法):`handle_drop(instance, character, equipment, player_state, loot_table)` 路由(04 §3.8 填空优先)。**
    - 空槽(`equipment.is_slot_empty(instance.slot)`)→ `equip`(填空,**含白装**);
    - 否则 `rarity ≤ decompose_threshold`(白)→ `player_state.add_material(slot, rarity, material_per_decompose)`;
    - 否则(蓝/金)→ `player_state.add_to_bag(instance)`。
    - 文件:`src/core/systems/loot_intake.gd`。
    - **Verify:** `test/core/loot_intake_test.gd` —— ① 空槽掉对应部位(白也)→ 穿上、槽不再空;② 已穿戴时掉白 → 材料 +1、不进包、不换;③ 掉蓝/金(槽已满)→ 进包、材料不变。

11. **全量回归闸(本批收口)。**
    - 跑**现有 45 个 gdUnit4 用例**(`test/combat/*`)—— **必须仍 45/45 绿且一字未改**(D1 回归锚);新增 `test/core/*` 全绿;`godot --headless --check-only` 0 错。
    - **Verify:** 上述三条全绿 = 第一批 done;HANDOFF 回写,交第二批 Planner pass。

## 4. Out of scope（本批明确不做)

- **层 5-8**:战斗层重构 / 替换 `CombatDirector` / `Entity`+`SkillComponent`(搬 6 维公式)/ `AICombatComponent` lane 站位 / `CombatArena` / `ProgressionController` / `AnimationComponent`·`CombatView` 改读 / `SaveSystem` 落盘 / autoload 重注册全回归。**全留第二批。**
- **改 `src/combat/*` 任何文件、改现有 45 个测试、改 `project.godot`**(D1/D2)。
- **注册 autoload**(D2,留层 8 + Engine Integrator)。
- **定 ilvl 来源 / 给 `EnemyDef` 加 `item_level`**(D8,留层 5 / 04 F-A)。
- **数值精调**:全用占位,完整 Tier 表 / 成长曲线 / 合格阶权重 / 分解产量公式 = 03+04 合并的总数值专章(04 F1/F2)。
- **05 城镇侧**:手动换装 / 对比面板 / 打造强化消耗材料 / 自定义分解门槛 / 满包兜底(04 §6)。

## 5. Risks & Flags / Open questions

- **【Flag·已决,建议追认】R1 autoload 推迟到第二批(D2)。** 我已按"本批纯逻辑自交付"定。若你想本批就把 `DataRegistry`/`PlayerState` 注册进 `project.godot`(便于手动 Play 试),需提前引入 Engine Integrator —— 不建议。
- **【Flag·已决】R2 ilvl 来源不在本批(D8)。** `LootGenerator` 取 ilvl 入参;F-A(EnemyDef.item_level vs 进度全局值)留第二批层 5 接线时定。本批可用任意 ilvl 测门槛逻辑。
- **【Flag·待 Implementer 核】R3 `class_name` 撞车。** 新增 `Character`/`PlayerState`/`DataRegistry` 等需确认不与 Godot 4.6 内置或现有 `class_name` 冲突(`Character` 尤其留意;冲突则改名 `Hero`/`PartyCharacter` 并回写本 PLAN)。
- **【Flag·F1 占位】R4 数值全占位。** affix 仅生命/暴击率两表填全,余者结构就位、值占位 —— 校验测断言**结构与约束**(门槛/不重复/池/条数),不断言具体平衡值,避免占位被误当定稿。
- **【风险】R5 序列化 base 引用(已缓解,D6)。** `ItemInstance` 存 `base_id` 而非对象;`from_dict` 经 `DataRegistry` 回查重建 —— round-trip 测是该缓解的闸。
- **【依赖】R6 第二批的回归锚。** 本批结束时 45+新测全绿是第二批替换 director 的安全网;第二批层 5 把 `formula_test.gd` 等迁成读 `StatsComponent`/`Arena` 时,**公式断言值不得变**(REFACTOR-01 §5 回归锚)。
