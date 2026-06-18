---
artifact: REVIEW
feature: 00-foundation-redesign
role: Reviewer
status: draft
updated: 2026-06-19
inputs: [PLAN.md, CHANGES.md, project-context.md, src/core/**, test/core/**, data/config/*.json]
next: Planner
---

# REVIEW — 底层地基重构 · 第一批(层 1-4)

> 审查范围:REFACTOR-01 第一批层 1-4 纯逻辑地基(数据层 / 属性引擎 / 持久层 / 掉落流水线)。
> 读了全部 14 个 `src/core/*.gd`、6 个 `test/core/*.gd`、3 份 `data/config/*.json` 的**磁盘实体**,
> 并**独立重跑**全套验证(非仅信 CHANGES)。

## 1. Verdict

**APPROVE WITH NITS** — 0 must-fix。

代码正确、忠于 PLAN、测试扎实(独立重跑 82/82 全绿)、无安全面、无超纲抽象。三处偏差已在 CHANGES §4 诚实记录且合理。下列 should-fix / nits 均**非阻塞**,可在本批收口或顺延到第二批/数值专章。

## 2. Must-fix (blocking)

无。

## 3. Should-fix (non-blocking)

- **`src/core/meta/character.gd:18` `build_stats()` 当前零测试、零调用方。**
  它是 Wiring Contract §5#4 给第二批层 5(战斗实体读 base→StatsComponent)留的接缝,保留合理;但本批无任何断言锁住它,存在静默腐烂到层 5 才暴露的风险。建议补一条最廉价单测(`base_stats={attack:5}` → `build_stats().get_final(attack)==5`),把这条接缝钉死。成本 3 行。

- **`src/core/systems/data_registry.gd` 校验未断言"三稀有度齐全"。**
  `_ingest_loot_table` 只校验**出现**的稀有度,不检查 white/blue/gold 是否都配了。若掉落表漏配 `gold`,`affix_count_range(gold)` 静默返回 `[0,0]`(金装 0 词缀)而**不报错**,与"策划数据闸"(ARCHITECTURE §4#6 / Wiring Contract §5#3)的意图不符。实发配置三档齐全、测试因此全绿,故非阻塞;建议在 03+04 数值专章或第二批接线时补一条完整性校验(缺档 → `get_load_errors()` 记一条)。

## 4. Nits (optional)

- **`src/core/data/loot_table_def.gd:24` `should_decompose(未知稀有度)` 返回 `true`**(`rarity_rank` 返回 -1,`-1 <= 0`)。未知稀有度在 `DataRegistry` 校验已被上游拦下、流水线里 `instance.rarity` 恒为合法值,故实际不可达;但加一道 `rank < 0 → return false` 防御更整洁。
- **`src/core/items/equipment_component.gd:18` `equip(slot, instance)` 未断言 `slot == instance.base_id`。** 现所有调用方(`LootIntake`、测试)都传匹配 slot;若误传不匹配 slot,modifier 仍按 instance 正确算、但会挂在错误槽键下。可加一句 `assert(slot == instance.base_id)` 防呆,非必须。
- **`data/config/` 目录 vs project-context §2 的 `assets/data/` 约定。** PLAN D4 明确选了 `res://data/config`,故忠于计划、非偏差;仅提示:03 战斗 `.tres` 在 `assets/data/combat/`,两套数据根目录分立,日后宜在 project-context §2 补一行统一说明,免后人困惑。
- **`loot_table_def.gd:18` `affix_count_range` 信任 `r` 有 2 元素**(`r[0]/r[1]`)—— 安全,因 `DataRegistry._ingest_loot_table` 存入前已校验 `pair.size()==2`;只是访问器与校验器之间存在隐式耦合,留意别绕过校验直接 `new` 喂残缺数据。

## 5. What I checked but found fine

- **独立重跑全量验证**:`-a res://test` → **82 cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | 14/14 suites | exit 0**。其中 **45 个 `test/combat/*` 回归锚仍全绿**(D1 守住)+ 37 新 `test/core/*` 全绿。CHANGES §3 的"82/82"属实。
- **文件清单**:恰好 14 个 `src/core` + 6 个 `test/core` + 3 份 JSON,**无任何 stray 文件**;`src/combat/*`、`project.godot` 零改动(全套 45 战斗用例数与 03 一致 = 未被动)。
- **终值公式**(`stats_component.gd:69`):`(base+Σflat)×(1+Σpercent)`,顺序/分组正确;脏缓存惰性重算;**无损卸下由"全量重算"结构性保证**(非增量回退,无浮点残留)—— 不变量 #2 成立。
- **LootGenerator**(`loot_generator.gd`):`count = min(count, candidates.size())` 杜绝 `% 0` 除零(候选空时循环不入);`remove_at` 保证选中 stat 不重复;`qualified_tiers(ilvl)` 守 ilvl 门槛;PICK_ONE 仅出一轴、ALL 出全轴。权重均匀挑阶 = R4/F2 占位,忠于 PLAN。
- **LootIntake**(`loot_intake.gd`):填空优先→白分解→蓝金进包路由正确,返回去向 StringName 可断言。
- **序列化**(`item_instance.gd`/`character.gd`/`player_state.gd`):存 `base_id` 非对象引用(D6/R5);`signature_axes` 已持久化(PICK_ONE 选中轴不丢);内存 round-trip 经 `to_dict→from_dict→to_dict` 等值已测。
- **DataRegistry 校验闸**:未知 stat/slot/rarity/sig_mode、`min>max`、`ilvl_req<1`、结构畸形均收 `_errors` 且 `ingest` 返 false,不静默吞(5 个畸形测覆盖)。
- **hard-NOs**:无新插件;无战斗顺手重构(零碰 `src/combat`);平衡数值与路径不硬编码进逻辑(配置目录可注入 + 数值在 JSON);地基抽象 = 用户 Producer 级 scope override,非超纲。
- **安全**:纯逻辑,仅读 `res://` 受信任配置,无外部输入 / 注入 / 密钥面。
- **偏差**(CHANGES §4):`GameKeys` 共享词表、`ItemInstance.signature_axes`、`handle_drop` 去 `character` 入参 —— 三者均必要且记录在案,认可。

---

**交接**:0 must-fix → 代码侧可收口。两条 should-fix 建议在本批顺手清(尤其 `build_stats` 补测,3 行)或并入第二批;若用户接受带 nits 放行,本功能第一批 done,下一步开**第二批 PLAN**(`/role-planner 00-foundation-redesign`,REFACTOR-01 层 5-8)。
