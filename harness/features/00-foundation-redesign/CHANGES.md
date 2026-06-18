---
artifact: CHANGES
feature: 00-foundation-redesign
role: Implementer
status: draft
updated: 2026-06-19
inputs: [PLAN.md, arch/REFACTOR-01-foundation-redesign.md, ARCHITECTURE.md, 04-loot-equipment/FEATURE-DESIGN.md, src/combat/party_member.gd]
next: Reviewer
---

# CHANGES — 底层地基重构 · 第一批(层 1-4 纯逻辑地基)

> 按 PLAN §3 十一步有序实现。本批**只做层 1-4**(数据层→属性引擎→持久层→掉落流水线),
> 全部 gdUnit4 收口,**零改 `src/combat/*`、零改现有 45 测试、零改 `project.godot`**(D1/D2)。
> 真实代码改 `src/core/` + `data/config/` + `test/core/`;本文件是 harness 内唯一产物。
> 工具链:用户授权"Implementer 自交付",给 `G:\Godot\Godot_v4.6.3\godot.exe`,我每层自跑 gdUnit4 验绿。

## 1. What changed(改了什么)

**层 1 — 数据层(Step 1-3)**
- `src/core/game_keys.gd`(`class_name GameKeys`,**PLAN 外新增**,见 §4 偏差):全项目共享词表 —— 8 维 stat 常量 + `STATS`;3 槽 `SLOT_*` + `SLOTS`;`SIG_ALL/SIG_PICK_ONE` + `SIG_MODES`;`KIND_FLAT/KIND_PERCENT` + `KINDS`;`RARITY_WHITE/BLUE/GOLD` + `RARITIES`;`static rarity_rank()`。
- `src/core/data/item_base_def.gd`(`ItemBaseDef`):`slot/signature_mode/signature_axes/base_curves`;`base_value(axis, ilvl) = base + per_ilvl×ilvl`。
- `src/core/data/affix_def.gd`(`AffixDef`):`stat/kind/slot_pool/tiers`;`qualified_tiers(ilvl)` 返回 `ilvl_req ≤ ilvl` 的阶。
- `src/core/data/loot_table_def.gd`(`LootTableDef`):`rarity_affix_count/decompose_threshold/material_per_decompose`;`affix_count_range(rarity)`、`should_decompose(rarity)`。
- `data/config/{item_bases,affix_pool,loot_tables}.json`:3 槽基底 + 8 条词缀(生命 10 阶 / 暴击率 5 阶按 04 §3.4 填全,余 6 条结构就位、值占位)+ 掉落表。
- `src/core/systems/data_registry.gd`(`DataRegistry`,非 autoload):`load_all(config_dir := "res://data/config")` 读 3 JSON → `ingest()` 校验+建 def;访问器 `get_item_base/get_affixes_for_slot/get_loot_table/get_load_errors/is_valid`。校验闸(ARCHITECTURE §4#6):未知 stat/slot/rarity/sig_mode、`min>max`、`ilvl_req<1`、结构畸形 → 收 `_errors` 不静默吞。

**层 2 — 属性引擎(Step 4-5)**
- `src/core/stats/stat_modifier.gd`(`StatModifier`):`{stat, kind:enum{FLAT,PERCENT}, value, source}`;`static kind_from_name()`(JSON 串→枚举边界转换)。
- `src/core/stats/stats_component.gd`(`StatsComponent`):base 字典 + modifier 列表 + 脏标记缓存;`get_final = (base+Σflat)×(1+Σpercent)`;`remove_modifiers_by_source` 按来源**无损**回收(不变量 #2);任何写置脏、读时惰性重算。

**层 3 — 持久层(Step 6-8)**
- `src/core/items/affix_roll.gd`(`AffixRoll`):`{stat, kind, tier, value}` + `to_dict/from_dict`。
- `src/core/items/item_instance.gd`(`ItemInstance`):`{base_id, ilvl, rarity, signature_axes, affixes}`(存 `base_id` 不存对象,D6);`to_modifiers(registry)`(招牌轴按 ilvl 算 FLAT + 各 affix→modifier,source=本实例)+ `to_dict/from_dict`。
- `src/core/items/equipment_component.gd`(`EquipmentComponent`):管 3 槽,`equip/unequip/get_equipped/is_slot_empty/empty_slots`;穿装注入、脱装按 source 无损回收、换装先脱旧再穿新。
- `src/core/meta/character.gd`(`Character`):`{id, class_id, base_stats, equipped}` + `build_stats()` + `to_dict/from_dict`。
- `src/core/meta/player_state.gd`(`PlayerState`,**Node**,本批不注册 autoload):`roster/bag/materials` + `add_material()`(发 `material_gained`)+ `add_to_bag/get_material` + `to_dict/from_dict`。

**层 4 — 掉落流水线(Step 9-10)**
- `src/core/systems/loot_generator.gd`(`LootGenerator`,纯逻辑):`generate(slot, ilvl, rarity, registry, rng) -> ItemInstance` —— 条数随稀有度、从池选不重复 stat、在合格 Tier 区间 roll、招牌轴按 signature_mode 定;`rng` 注入可 seed。
- `src/core/systems/loot_intake.gd`(`LootIntake`):`static handle_drop(instance, equipment, player_state, loot_table)` 路由(04 §3.8 填空优先):空槽→穿(含白)/已穿白→出材料/已穿蓝金→进包;返回去向 StringName。

**测试(`test/core/`,全新增,不碰 `test/combat/`)**
- `data_registry_test.gd`(8)、`stats_component_test.gd`(10)、`equipment_component_test.gd`(5)、`player_state_test.gd`(4)、`loot_generator_test.gd`(7)、`loot_intake_test.gd`(3)= **37 新单测**。

## 2. Why(对应 PLAN 步骤/决策)

| 改动 | PLAN 依据 |
|------|-----------|
| 新代码全落 `src/core/`,零碰 `src/combat/*` 与 45 旧测试 | D1(旧测试=回归锚,本批不接战斗) |
| `DataRegistry/PlayerState` 普通 `class_name`、测试 `new()` 注入、不动 `project.godot` | D2(本批不引入引擎侧人工点) |
| `load_all(config_dir=...)` 目录可注入 + `ingest()` 可喂内存畸形数据 | D3(守 hard-NO 路径不硬编码 + 校验可测) |
| 三模板 JSON、`EnemyDef/StageConfig` 不碰 | D4(混合存储分工) |
| 纯算组件 `RefCounted`、`PlayerState` 用 `Node` | D5 |
| `Character/ItemInstance/PlayerState` 本批即写 `to_dict/from_dict` + 内存 round-trip 测 | D6(提前钉死可序列化、存 base_id 回查) |
| `LootIntake` 编排放层 4 流水线尾 | D7 |
| `ilvl` 作 `generate(...)` 入参、不定来源、不给 EnemyDef 加字段 | D8 |
| affix 仅生命/暴击率填全 Tier,余占位;测试只断结构/约束不断平衡值 | R4(占位不被误当定稿) |

## 3. How verified(怎么验的)

- **逐层 gdUnit4 收口**(每层:写码 → `--headless --import`(注册新 `class_name`)→ 跑该层 suite):
  - 层1:`data_registry_test` **8/8** 绿。
  - 层2:`stats_component_test` **10/10** 绿(含无损卸下 = 不变量 #2 核心断言)。
  - 层3:`equipment_component_test` + `player_state_test` **9/9** 绿(含 round-trip 等值 + `material_gained` signal via `monitor_signals`)。
  - 层4:`loot_generator_test` + `loot_intake_test` **10/10** 绿(含门槛守约 + 填空优先路由)。
- **全量回归闸(Step 11)**:全套 `-a res://test` → **82 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED**,14/14 suites,exit 0。
  - 内含 **45 个现有 `test/combat/*` 用例,仍 45/45 绿且一字未改**(D1 回归锚已守) + 37 新 `test/core/*` 全绿。
- gdUnit4 调用:`godot.exe --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/...`(gdUnit4 默认拒 headless,加 `--ignoreHeadlessMode`;`tcp://...:0` 的 remote port 报错为良性)。
- **关于 `--check-only`**:本批用 `--headless --import` 全量导入 + 跑全套测试(会编译所有脚本)作为"0 编译错"的等价证据 —— 82/82 + 0 orphans 即全脚本编译通过。无独立 UI/场景需手动 Play(本批纯逻辑,无表现层改动)。

## 4. Deviations(与 PLAN 的偏差)

- **〔新增〕`GameKeys` 共享词表** —— PLAN §3 目录未列。各 def/组件都要引用 stat/slot/rarity/kind 字面量,集中成单一常量源避免散落硬编码字符串(守 hard-NO 精神、便于校验)。建议追认。
- **〔字段补充〕`ItemInstance.signature_axes`** —— PLAN §3 步6 的字段表写 `{base_id, ilvl, rarity, affixes}`,未列招牌轴。但 PICK_ONE(饰品)选中的是哪一轴必须**随实例持久化**(否则 round-trip/重建丢失);ALL 则存全轴。故加此可序列化字段,`to_modifiers` 据它算招牌贡献。
- **〔签名微调〕`LootIntake.handle_drop` 去掉 `character` 入参** —— PLAN 步10 列了 `character`,但本批路由只用到 `equipment`/`player_state`/`loot_table`(equip 经 `EquipmentComponent` 绑定的 `StatsComponent`,无需 Character)。角色侧 `equipped` 同步是第二批接线点,届时再决定是否回传 Character。
- 无算法/结构性偏差;终值公式、PoE roll、填空优先路由均按 PLAN/04 实现。

## 5. Wiring Contract(给 Engine Integrator / 第二批 Planner / 接线)

**本批纯逻辑地基:零新场景节点、零 `.tscn`、零新插件、零 autoload 注册、零 `project.godot` 改动。**
新增的是一批 `class_name` 脚本 + `data/config/*.json` 配置。接线面如下,**第二批层 5-8 才会消费**:

1. **新增 `class_name`(已确认不与现有 `class_name` / Godot 4.6 内置撞车,R3 已清):**
   `GameKeys`、`ItemBaseDef`、`AffixDef`、`LootTableDef`、`DataRegistry`、`StatModifier`、`StatsComponent`、`AffixRoll`、`ItemInstance`、`EquipmentComponent`、`Character`、`PlayerState`、`LootGenerator`、`LootIntake`。
   - **加任何新 `class_name` 后,引擎需先跑一次 `--import`(或编辑器打开一次)** 才能让其它脚本/测试解析到它 —— 本批已踩坑确认,记此备忘。
2. **autoload 留给第二批层 8(Engine Integrator):** ARCHITECTURE 把 `DataRegistry`/`PlayerState` 标为 autoload,本批**未**注册(D2)。第二批接线时在 `project.godot` 注册,届时全局 `DataRegistry.load_all()` 应在启动期跑一次、`get_load_errors()` 非空要硬失败(策划数据闸)。
3. **配置目录 `res://data/config/`:** 三份 JSON 是结构占位(R4),平衡数值精调留 03+04 合并数值专章。新增/改词缀须过 `DataRegistry` 校验(未知 stat/slot/rarity、`min>max`、`ilvl_req<1` 会被 `get_load_errors()` 拦)。
4. **第二批战斗层接口(REFACTOR-01 层 5)预期消费点:**
   - 战斗实体读 `Character.build_stats()` + `EquipmentComponent` 注入装备 modifier,得 `StatsComponent.get_final(stat)` 作战斗快照 —— `formula_test.gd` 的 6 维公式断言值**迁移后不得变**(R6 回归锚)。
   - 掉落:战斗侧定 `ilvl`(D8 / 04 F-A:`EnemyDef.item_level` vs 进度)→ `LootGenerator.generate(...)` → `LootIntake.handle_drop(...)`。
   - `PlayerState.material_gained(slot, rarity, amount)` 信号可供 UI/成就接线。
5. **无破坏性改动:** 现有 `Combat` autoload、`CombatDirector`、`PartyMember`、`begin_run` 入口、stages 注入、45 测试全部原样未动。

## 6. Flags(实现期回执)

- **〔R1 已决〕autoload 推迟第二批(D2)。** 若你想本批就注册便于手动 Play 试 → 需提前引入 Engine Integrator,不建议。
- **〔R2 已决〕ilvl 来源不在本批(D8)。** `generate` 取 ilvl 入参;来源在第二批层 5 定。
- **〔R3 已清〕`class_name` 无撞车。** 14 个新名经核不与现有(`CombatDirector/CombatView/LootStub/EnemyDef/StageConfig/PartyMember/SceneConfig`)及 Godot 4.6 内置冲突;`Character` 安全(非内置)。
- **〔R4 已守〕数值全占位。** 测试只断结构与约束(条数/不重复/池/门槛/公式),不断具体平衡值。
- **〔R5 已缓解〕序列化 base 引用。** `ItemInstance` 存 `base_id`,round-trip 测是闸(已绿)。
- **〔R6 交棒〕第二批回归锚。** 本批结束 45+37 全绿 = 第二批替换 director 的安全网;迁 `formula_test` 时公式断言值不得变。

## 7. 交接

- **本批代码侧 done**(84/84 全绿,无 UI 手动验收点 —— 纯逻辑)。
- **下一步**:审后修订已收口(见 §8),开**第二批 PLAN**(REFACTOR-01 层 5-8:替换 `CombatDirector` / 表现层改读 / `SaveSystem` 落盘 / autoload 重注册全回归)。

## 8. 审后修订(2026-06-19,清 REVIEW.md 两条 should-fix)

Reviewer 给 **APPROVE WITH NITS,0 must-fix**;用户拍"两条 should-fix 都清"。两处均已改并重验:

- **should-fix #1 — `Character.build_stats()` 补单测**(REVIEW §3 第 1 条):该方法是给第二批层 5 留的接缝,原零测试零调用方,有静默腐烂风险。在 `test/core/player_state_test.gd` 加 `test_character_build_stats_seeds_base`:`base_stats={attack:5, max_hp:100}` → `build_stats().get_final(...)` 等值,把接缝钉死(3 行断言)。
- **should-fix #2 — `DataRegistry` 补"三稀有度齐全"校验**(REVIEW §3 第 2 条):`_ingest_loot_table` 原只校验**出现**的稀有度,漏配 `gold` 会让 `affix_count_range(gold)` 静默返 `[0,0]`(金装 0 词缀)而不报错,与策划数据闸(ARCHITECTURE §4#6)意图不符。在 `data_registry.gd:_ingest_loot_table` 存入 `typed` 后加完整性闸:遍历 `GameKeys.RARITIES`,缺档 → `_errors` 记一条。配套测 `test_incomplete_rarity_table_reports_error`(漏金档 → `ingest` 返 false 且错含 "gold")。
  - 连带修 `equipment_component_test.gd` 的 `_registry()` 占位表 → 补齐 blue/gold 三档,免新闸把它推入 error 态。
- **4 条 nits 按 REVIEW 建议放行**(should_decompose(未知)→true 实际不可达 / equip 无 slot==base_id 断言 / `data/config` 目录约定 / `affix_count_range` 信任 2 元素)—— 均非阻塞,留数值专章或第二批接线时酌情清。
- **重验**:`--import` 后全套 `-a res://test` → **84 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | 14/14 suites | exit 0**(原 82 + 2 新 = 84;45 旧战斗回归锚仍全绿)。
