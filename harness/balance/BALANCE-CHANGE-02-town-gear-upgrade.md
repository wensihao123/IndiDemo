---
artifact: BALANCE-CHANGE
feature: 05-town-gear-upgrade
role: Num Smith
status: draft
updated: 2026-06-19
inputs: [BALANCE.md, ARCHITECTURE.md, project-context.md, features/05-town-gear-upgrade/FEATURE-DESIGN.md, harness/arch/REFACTOR-03-town-meta-ops.md, data/config/item_bases.json, data/config/loot_tables.json, assets/data/combat/stage_01.tres, src/core/items/item_instance.gd, src/core/meta/player_state.gd, src/core/systems/loot_intake.gd]
next: Planner
---

# BALANCE-CHANGE-02 — 05 城镇装备强化数值定稿

## 1. 触发 / Trigger
05-town 引入 v1 第一个**材料消耗口**:装备强化(`ItemInstance.enhance_level +1` → 数值提升)。F-NUM 要把
GD 红线(**确定性 / 无失败 / 纯增益**)翻成具体数字:① 每级加成幅度 ② 材料成本曲线 ③ 是否设上限 ④ 三槽是否同公式;
并做**材料经济校验**(白装自动分解 = 唯一来源,强化 = 新沉淀口,产出 vs 消耗是否平衡)。架构缝由 REFACTOR-03
已定:强化贡献**必经 `to_modifiers` 产出的 `StatModifier(source=self)` 注入**(不变量 #10)。

## 2. 现状诊断 / Diagnosis
不是失衡待修,而是**新数值待定 + 既有经济缺沉淀口待补**:
- **加成接入处(根因约束):** `ItemInstance.to_modifiers`(`item_instance.gd:20-28`)现把每条招牌轴按
  `base.base_value(axis, ilvl)` 摊成一条 `StatModifier(axis, FLAT, …, self)`。强化加成**最自然、最守不变量的形态 =
  在此再追加一条 `FLAT`**(同 source=self),值由 `enhance_level` 算。走 PERCENT 会放大**全身**该属性(与其它装备纠缠、
  且对 weapon 的 attack×attack_speed 易踩 i4 超线性)→ **否决 PERCENT,用 FLAT**(守 i2 合成式 + i4 线性)。
- **weapon 双招牌轴的陷阱:** weapon 招牌轴 = `[attack, attack_speed]`(`item_bases.json`)。若强化同时放大两轴,
  DPS ≈ attack×attack_speed **双增 → 准平方放大,违 i4**。→ 强化**只作用每槽的「主轴」**(weapon→attack,
  armor→armor,accessory→其 pick_one 轴),attack_speed 不被强化。这样 DPS 对强化等级保持线性。
- **材料经济(BALANCE §4 现状):** 材料按 `slot|rarity` 计(`player_state._mat_key`),但 `decompose_threshold=white`
  → **只有 `slot|white` 三个桶实际产出**;来源恒为白装分解(`loot_intake`,kind 未接线,债-4)。v1 至今材料
  **单向累积、零沉淀口**(BALANCE §4 已标「沉淀属 05」)。强化 = 补上这个沉淀口。

## 3. 目标数值 / Target numbers
> Delta vs BALANCE.md。新增 §3(g) 强化公式 + §4 沉淀口 + §5 三个强化锚点 + 不变量。具体逐级表属本功能,留本文 §3。

**(a) 加成公式(三槽同一公式,FLAT,线性):**
```
强化主轴 := weapon→attack / armor→armor / accessory→其 pick_one 招牌轴
bonus(主轴) = base_value(主轴, ilvl) × ENHANCE_PER_LEVEL × enhance_level
           → 作为一条 StatModifier(主轴, FLAT, bonus, source=self) 追加进 to_modifiers
ENHANCE_PER_LEVEL = 0.10      # 每级 = 该件「主轴基底值」的 +10%(线性叠加,不复利)
ENHANCE_CAP = 10              # 强化上限 +10 → 满级 = 主轴基底翻倍(+100%)
```
- **幅度按本件 ilvl 缩放**:高 ilvl 件 base 大 → 同级强化绝对增量更大 → **奖励养高 ilvl 的好装**(对上 fantasy
  「把心爱的装备养起来」),且不解锁任何 Tier(不碰 i6 闸门,强化是闸门**之上**的加性增益)。
- **满级即翻倍**是给玩家的可读心智模型:「+10 = 招牌轴 ×2」。

**(b) 材料成本曲线(线性递增,三角累计):**
```
cost(L → L+1) = ENH_COST_BASE + ENH_COST_STEP × L      # L = 当前等级(0 起)
ENH_COST_BASE = 1, ENH_COST_STEP = 1   →   cost = 1 + L
消耗材料种类 = 该件所在槽的白材料 slot|white(无论该件自身稀有度;因只有 white 材料实际产出)
```
| L→L+1 | 0→1 | 1→2 | 2→3 | 3→4 | 4→5 | 5→6 | 6→7 | 7→8 | 8→9 | 9→10 |
|-------|----|----|----|----|----|----|----|----|----|------|
| 单步成本 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
| 累计到该级 | 1 | 3 | 6 | 10 | 15 | 21 | 28 | 36 | 45 | **55** |

- **+1 仅 1 材料**:首次强化即时可及(前期快迭代、即时满足)。**+10 累计 55 材料**:满级是长期投入(温和成长)。

**(c) 答 GD 四问:**
- **幅度** = +10%/级(本件主轴基底的线性百分比,FLAT 落地)。
- **成本** = `1+L` 线性递增(满级累计 55,同槽白材料)。
- **上限** = **设,+10**(满级 = 主轴翻倍;界面显「已满级」、强化禁用)。理由:守温和长期曲线、封顶材料经济、
  且让**更高 ilvl 的新掉落仍有竞争力**(强化不吞掉换装乐趣,支柱 2)。
- **三槽** = **同一公式 / 同成本 / 同上限**;唯一差异 = 各槽「主轴」不同。不做按槽分化(GD 未要求,守可读 + 最小)。

**(d) 回城是否回血(答 REFACTOR-03 风险 A):** v1 **不回血**——强化/换装是「安静工作台」,非补给站;沿用架构默认
(出城 re-snapshot 时 `current_hp` 夹 `[0,new_max]`,守 i5 不免费回血)。若 playtest 觉得「回城惩罚感」,再交 GD 显式
加「回城回 X%」设计旋钮(走配置),本案不做。

## 4. 调整策略 / Strategy(锚先行,派生跟随)
1. **先定加成锚 `ENHANCE_PER_LEVEL=0.10` + `ENHANCE_CAP=10`**(核心,牵动战力曲线)。它决定满级 = 主轴翻倍。
2. **再定成本锚 `cost=1+L`**(派生于「材料产速」校验,见 §5 经济):匹配白材料产出、让满级是长期投入。
3. **公式形态固定为 FLAT-追加于主轴**(由 #10 + i4 推出,非自由选)：`to_modifiers` 多摊一条
   `StatModifier(主轴, FLAT, base_value(主轴,ilvl)×0.10×level, self)`。**weapon 只摊 attack 不摊 attack_speed。**
4. **校验不变量**:i1(强化件脱下,该 FLAT 随 source=self 一并精确回收)、i2(并入 ΣFlat)、i4(对强化等级线性、
   weapon 不双轴放大)、i6(不解锁 Tier)。全部天然成立——这正是选 FLAT/单主轴的原因。
> 连带:`ENHANCE_PER_LEVEL` 改大 → 战力曲线整体上抬 + 换装相对贬值;`ENH_COST_STEP` 改大 → 满级更慢 + 吃更多材料。
> 两锚独立可分别 playtest 微调,不互相 whiplash。

## 5. 影响面与迁移 / Blast radius & migration
- **触及(数值侧)**:三个新常量 `ENHANCE_PER_LEVEL / ENHANCE_CAP / ENH_COST_BASE / ENH_COST_STEP` 应**走配置**
  (hard-NO:数值不硬编码进逻辑)——建议新增 `data/config/enhance.json`(或并入既有 config),由 Planner/Implementer 定落点。
  加成计算落在 `item_instance.gd` 的 `to_modifiers`;成本/扣材料落在持久层元操作(REFACTOR-03 §4 步 3)。
- **存档迁移**:`enhance_level` 由 REFACTOR-03 加进 `ItemInstance` 序列化(缺省 0,旧档无缝)。本案不加新存档字段。
- **材料经济校验(关键):**
  - **产出**(现状,不改):材料/击杀 ≈ `drop_chance × P(white)`,且仅当对应槽已占(否则掉落去补空槽)。
    实测锚:关1 普通怪 `drop_chance 0.5–0.55`、`rarity_white 82–88%`;Boss `1.0 / white 50%`。槽满后稳态
    ≈ **0.4–0.7 材料/击杀**,按掉落槽位大致均分 → **每个 `slot|white` 桶 ≈ 0.15–0.2/击杀**。
  - **消耗**(本案新增):把**单件**某槽强化满 = **55** 该槽白材料 ≈ **275–365 次击杀**的该槽材料产出。
  - **结论 = 健康沉淀、无材料荒**:产出仍 > 消耗(材料整体仍净累积),但强化首次给了**真实去处**;满一件需长期投入,
    符合「养成」节奏。**不存在材料荒风险**(开放 flag「材料来源是否够」→ 校验答:v1 反而偏**富余**,不需扩来源)。
- **向后兼容**:挂机自动填空(i3 只增不替)路径不动;强化是持久层另一条主动路径,二者并存。

## 6. 风险与被否选项 / Risks & rejected alternatives
- **被否 PERCENT 加成**:放大全身该属性、与他件纠缠、weapon 双轴踩 i4。→ 用 FLAT、隔离于本件、只作用主轴。
- **被否「强化 weapon 双招牌轴」**:attack×attack_speed 双增 = 准平方 DPS,违 i4。→ 只强化 attack。
- **被否「按槽分化公式/成本」**:GD 未要求,增复杂度损可读。→ 三槽同公式,仅主轴不同。
- **被否「不设上限」**:线性无封顶会让后期战力/材料失控、且吞掉换装乐趣。→ 封 +10(翻倍)。
- **风险 · 材料偏富余(债延伸)**:白材料产速高,满件后期可能材料过剩、强化成本显得轻。若 playtest 刺眼,
  **优先调 `ENH_COST_STEP`↑**(陡化成本)而非降产出。**需 playtest 校准**。
- **风险 · 强化 vs 换装权衡**:+10 翻倍 vs 更高 ilvl 新掉落,谁更优需对比面板可读地呈现。+10 满件 ≈ 约 +ilvl×N 的
  裸新件,二者应当**互有胜负**(养满的旧件 ≈ 跳档的新裸件)→ 健康张力。**需 playtest 确认**玩家会在「养」与「换」间取舍。
- **i3 澄清(应 🟢 flag)**:**手动换装可替换**(玩家主动,城镇)与**自动填空只增不替**(i3,挂机)是两条独立路径,
  强化不改变 i3;强化加成随 `ItemInstance` 走,换下放包再穿回**保留等级**(随持久态)。

## 7. 交接 / Handoff
**next: Planner**(结构性——动 `to_modifiers` + 新配置 + 持久层元操作 + 扣材料,非纯常量微调)。
- 把 §3 公式/成本/上限喂进 REFACTOR-03 §4 的步 2(`to_modifiers` 接强化:FLAT、仅主轴、`×0.10×level`)和步 3
  (持久层强化元操作:校验材料 ≥ `1+L`、扣 `slot|white`、`enhance_level+1`、封顶 10)。
- 四常量走配置(`data/config/enhance.json` 建议),**不硬编码**(hard-NO)。
- **可 gdUnit4 测**:强化件 `to_modifiers` 多出正确 FLAT、脱下精确回收(i1)、满级禁止再升、材料不足拒绝且不扣半截、
  成本曲线 `1+L`。表现层对比面板/强化按钮手动 Play 验。
- **playtest 校准项**:`ENHANCE_PER_LEVEL=0.10` 手感(满级翻倍是否「爽而不破」)、`1+L` 成本配白材料产速(是否过松)、
  「养 vs 换」取舍是否成立、回城不回血是否有惩罚感。
