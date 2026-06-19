---
artifact: BALANCE
role: Num Smith
updated: 2026-06-20
---

# BALANCE — 数值事实源 (test-2 挂机打宝)

> ⚠ **本文 v1 逆推自现有代码 / 配置,反映现状、不是理想形态**(2026-06-19,首建)。
> 数字一律对齐真实文件:`data/config/*.json`、`assets/data/combat/stage_0*.tres`、
> `src/core/combat/{skill_component,combat_tuning,progression_controller}.gd`、
> `src/combat/enemy_def.gd`、`src/core/meta/starting_roster`(`data/config/starting_roster.json`)。
> 现阶段数值**几乎全是占位**,逆推中看到的失衡集中记在 §6,待模式 B 精调(首单 = 04 F-NUM)。
> 守 project-context 三支柱:① 伙伴优先(战斗全自动、不逼操作)② 变强够到下一个怪 ③ 偶尔惊喜非赌场。

## 1. 数值一句话 / Overview
**难度曲线 = 前期宽松陪伴、后期靠掉落变强够到更硬的怪**;掉落是 PoE 式「ilvl 闸门 + 分阶池」,
稀有度只决定**词缀条数**(白 0 / 蓝 1-2 / 金 3-4),不决定词缀强度——强度由 **ilvl 解锁的 Tier** 决定。
经济目前**单一**:材料来自「白装自动分解」,v1 无消耗口(消耗 = 05 城镇打造);金币种类已定义但**未接线**(死值)。
整体调性偏「稳态友好」:伤害/减伤都线性、无超线性放大,避免赌场式方差(支柱 3)。

## 2. 核心属性与单位 / Core attributes & units
8 维属性(`GameKeys.STATS`),全部走 `StatsComponent`,装备以 `StatModifier` 叠加:
| 维度 | 单位 / 量纲 | 含义 | 战士裸基础值 |
|------|------------|------|------|
| `attack` | 点/次 | 单次出手原始伤害 | 6 |
| `max_hp` | 点 | 生命上限 | 120 |
| `attack_speed` | 次/秒 | 出手频率(进度累加器满 1 出手) | 1 |
| `armor` | 点 | 经 `armor/(armor+K)` 转减伤% | 0 |
| `dodge_chance` | 概率 0..1 | 完全闪避(伤害=0) | 0 |
| `crit_chance` | 概率 0..1 | 暴击触发率 | 0 |
| `crit_mult` | 倍率 ×N | 暴击伤害倍数 | 2 |
| `hp_regen` | 点/秒 | 每秒回血 | 0 |
- **属性合成不变量:** `Final = (base + ΣFlat) × (1 + ΣPercent)`(`StatsComponent`)。当前**所有词缀 kind=flat**,percent 通道暂未使用。
- **稀有度 = 词缀条数,不是强度**:`white[0,0] / blue[1,2] / gold[3,4]`(`loot_tables.json`)。白装纯基底、无词缀。
- **ilvl(物品等级)= Tier 闸门**:词缀每个 Tier 有 `ilvl_req`,物品 ilvl ≥ 门槛才可取该阶(`affix_pool.json`)。

## 3. 公式与曲线 / Formulas & curves
**(a) 单次命中伤害(`SkillComponent.resolve_hit`):**
```
raw   = attack × damage_mult
若暴击(rng < crit_chance): raw ×= crit_mult
若闪避(rng < target.dodge_chance): 伤害 = 0
减伤: amount = raw × (1 − target.armor / (target.armor + K))   # K = armor_k = 50
```
- 护甲是**软递减**:armor == K(=50)时恰减 50%;线性输入、渐近 1 的减伤(不会负伤,denom≤0 时跳过防 NaN)。
- **稳态 DPS 近似**:`DPS ≈ attack × attack_speed × (1 + crit_chance×(crit_mult−1)) × (1 − tgt_armor/(tgt_armor+50)) × (1 − tgt_dodge)`。

**(b) 出手节奏(`SkillComponent`)**:`attack_progress += attack_speed × dt`,每满 1.0 出一手(离散、可一 tick 多手)。tick = 0.1s 固定步长(帧率无关,不变量)。

**(c) 基底成长曲线(`item_bases.json`,线性):** 装备某招牌轴生效值 = `base + per_ilvl × ilvl`。
| 部位 | 招牌轴 | base | per_ilvl |
|------|--------|------|----------|
| weapon | attack | 3.0 | 0.5 |
| weapon | attack_speed | 1.0 | 0.01 |
| armor | armor | 5.0 | 1.0 |
| accessory(三选一) | max_hp | 10.0 | 2.0 |
| accessory | dodge_chance | 0.01 | 0.001 |
| accessory | hp_regen | 0.5 | 0.1 |

**(d) 词缀 Tier 阶梯(`affix_pool.json`,分阶池)** — 每阶 `{min..max, ilvl_req}`,`weight` 字段全 1.0:
- `max_hp`:10 阶,T10(1-5, ilvl1)→ T1(115-140, ilvl90),阶梯最密、跨度最大。
- `crit_chance`:5 阶,T5(0.5-2%, ilvl1)→ T1(8.5-10%, ilvl80)。
- `attack/attack_speed/crit_mult/armor/dodge_chance/hp_regen`:各 2 阶(T2 ilvl1 / T1 ilvl30)。
- **阶选择(`LootGenerator._roll_affixes`):** 取 `ilvl_req ≤ ilvl` 的合格阶,**均匀随机**挑一阶(`randi()%size`,**忽略 weight**),再区间内 roll 值。→ ilvl 只抬「可取上限」,不偏向高阶(见 §6 债-3)。
- **部位词缀池(slot_pool):** weapon={crit_chance,attack,attack_speed,crit_mult}(4);armor={max_hp,armor,dodge_chance,hp_regen}(4);accessory={max_hp,crit_chance,attack,attack_speed,crit_mult,armor,hp_regen}(7,最富)。

**(e) 掉落概率与稀有度(`enemy_def.gd` + 各 .tres)**:每次击杀按 `drop_chance` 决定有无掉落;稀有度按 `rarity_weight_{white,blue,gold}` 归一化加权;kind 按 `weight_{gold,material,equipment}` 归一化加权(**当前未接线**,见 §6 债-4)。

**(g) 装备强化(`enhance_level`,05 城镇,planned in BALANCE-CHANGE-02)** — 确定性 +1、无失败、纯增益(GD 红线):
```
强化主轴 := weapon→attack / armor→armor / accessory→其 pick_one 轴   (weapon 不强化 attack_speed,守 i4)
bonus(主轴) = base_value(主轴, ilvl) × ENHANCE_PER_LEVEL × enhance_level   → 一条 StatModifier(主轴,FLAT,source=self)
```
- **FLAT、仅作用本件主轴、线性**(否决 PERCENT:会放大全身该属性 + weapon 双轴踩 i4)。满级 +10 = 主轴基底翻倍。
- 加成随本件 ilvl 缩放(高 ilvl 件强化增量更大);**不解锁 Tier**(强化是 i6 闸门之上的加性增益)。
- 强化经 `ItemInstance.to_modifiers` 的 source=self 通道注入 → 脱下精确回收(i1)、并入 ΣFlat(i2)。具体逐级表见 BALANCE-CHANGE-02。

**(f) 敌人数值(逆推自 .tres,非公式、属 per-feature 表,仅列锚点):** 关1 哥布林 hp12 → 兽人 hp28 → Boss 哥布林王 hp90;关2 精英兽人 hp50 → 食人魔 hp85 → **Boss 兽人酋长 hp480/atk24(= 06 的墙,planned in BALANCE-CHANGE-04;原 hp220/atk9 压不住关1 通关玩家、墙不存在)**。HP 大致几何递增(×1.5~2/档),关2 Boss 是唯一被刻意抬成"墙"的单点(关2 普通场景与关1 不动)。**所有敌人 `item_level` = .tres 显式覆盖(关1 1→10、关2 14→30,planned in BALANCE-CHANGE-01)**。**关2 远程(团战铺波,planned in BALANCE-CHANGE-05):投石暗影手 hp40/atk4/ilvl18(配 Scene2)、投石食人魔 hp50/atk4/ilvl24(配 Scene3),均 0.6×同档近战、`position_class=RANGED`。**

## 4. 经济收支 / Economy
- **材料(material)** — 唯一活跃货币。**来源**:白装自动分解,每件 +`material_per_decompose`(=1),按 `slot|white` 计(只有白材料实际产出)。产出速率 ≈ 掉落率 × 白装占比(当前掉落恒装备、稀有度白占比 ~72-88%);槽满后稳态每 `slot|white` 桶 ≈ 0.15-0.2/击杀。**消耗**:**05 强化 = v1 首个沉淀口**(planned in BALANCE-CHANGE-02)——强化某槽件花 `slot|white` 材料,单步 `1+L`、满件累计 55。**经济校验**:产出仍 > 消耗(材料整体净累积,**无材料荒**、反偏富余),但满件需长期投入 → 健康养成节奏。
- **金币(gold)** — `weight_gold` 在配置里是最大头(普通怪 55-80%),但 **kind 未接线**(`_drop_loot` 恒产装备),金币**从不实际掉落、也无消耗口** → v1 **死值**。归属待 F-KIND(Producer)。
- **装备(equipment)** — 非货币而是 build 产出:空槽自动穿(挂机变强唯一来源)、蓝/金进包、白超分解门槛→材料。

## 5. 关键调参常量与平衡不变量 / Key constants & invariants
**调参锚点(命名常量,改这些牵动全局):**
- `CombatTuning.armor_k = 50.0` — 护甲半减点(armor=50 → 减伤 50%)。
- `CombatTuning.tick_seconds = 0.1` — 固定逻辑步长。
- `CombatTuning.enrage_threshold_sec = 25.0` / `enrage_ramp_per_sec = 0.5` — 软狂暴起点与线性陡增(占位,基本未被触发,见 §6 债-5)。
- `CombatTuning.stage_clear_countdown_sec = 5.0` — 通关后自动推进倒计时。
- 战士裸基础:`attack6 / max_hp120 / attack_speed1 / crit_mult2`,余 0(`starting_roster.json`)。开局白武+白甲(ilvl1),空饰品。
- 掉落:`material_per_decompose=1`、`decompose_threshold="white"`、稀有度条数 `white0/blue1-2/gold3-4`。
- **强化(05,planned in BALANCE-CHANGE-02,走配置勿硬编码):** `ENHANCE_PER_LEVEL=0.10`(每级 +10% 主轴基底,FLAT 线性)、`ENHANCE_CAP=10`(满级 = 主轴翻倍)、成本 `cost(L→L+1)=ENH_COST_BASE(1)+ENH_COST_STEP(1)×L`(满件累计 55,花 `slot|white`)。三槽同公式,仅主轴不同。
- **团战门控(08,planned in BALANCE-CHANGE-03,走配置勿硬编码):** `CombatTuning.melee_gate_capacity = 2`(`G`)——同一时刻最多 2 名最前存活近战可出手,其余近战排队补位(车轮);**远程不受门控**(隔位恒可出手)。团战唯一运行时旋钮,缩放全部近战峰值威胁。一波规模(普通场景 2–4 随深度递增、Boss 维持 1)、近/远配比(远程少数派,`远程数≈floor(WAVE_SIZE/3)`、v1 上限 1)、远程权重(`attack≈0.6×同档近战`、`hp≈0.6×同档近战` → 漏血而非主伤)= per-feature authoring 指南,落 08 的 .tres,不在此硬定。**关2 波规模已落定(planned in BALANCE-CHANGE-05):三普通场景 WAVE_SIZE 统一 = 3(Scene1 纯 3 近 / Scene2-3 各 2 近+1 远)、`kill_count` 7→6——比关1 更克制,靠敌单值加压不靠人海。** ⚠ **铺波承伤主导项 = 场景内波间不回血**(`_revive_party()` 仅清场调用):整场承伤 = `ceil(kill_count/WAVE_SIZE)` 波**累积**,`kill_count` 与 `WAVE_SIZE` 必须一起定(BALANCE-CHANGE-05 §2 约束 B)。

**平衡不变量(必须恒成立):**
- **i1 装备无损还原**:脱下装备 `StatsComponent` 完全回到裸基础(modifier by-source 移除)——逆推/换装不漂。
- **i2 属性合成式**:任何维度生效值 = `(base+ΣFlat)×(1+ΣPercent)`,不得旁路硬写。
- **i3 自动填空只增不替**:空槽自动穿对应掉落,**绝不替换已穿戴**(挂机变强单调、不回退)。
- **i4 无超线性放大**:伤害对单一属性线性、护甲软递减渐近 1,避免方差爆炸(守支柱 3 非赌场)。
- **i5 `max_hp` 变动时 `current_hp` 夹 [0,new_max]**:存活加差额、死亡不复活(`progression._revive_party` 负责回满,装备增量不偷偷治疗)。
- **i6 ilvl 单调闸门**:更深内容给更高 ilvl → 解锁更高 Tier 上限(变强够到下一个怪 = 支柱 2 的数值载体)。**由 BALANCE-CHANGE-01 设 item_level 阶梯恢复**(关1 ilvl 1→10、关2 14→30)。
- **i7 强化确定性纯增益**(05,planned in BALANCE-CHANGE-02):强化 = **确定 +1、无失败、无掉级、无碎裂**(GD 红线,守支柱 3 非赌场);加成 **FLAT、仅作用本件主轴、对等级线性**(weapon 不强化 attack_speed → DPS 不双轴放大,守 i4);经 source=self 通道注入 → 守 i1/i2;**不解锁 Tier**(i6 闸门之上的加性增益);封顶 +10。
- **i8 团战威胁纯加性**(08,planned in BALANCE-CHANGE-03):一波多敌的总威胁 = **各敌个体 DPS 之和**(近战那部分受门控 `G` 截断同时活跃数),**严禁任何"敌数越多每个越强"的乘性放大**(无数量狂暴/团队士气类乘子)。门控只**减少**同时活跃近战数、**绝不增伤**;近战超过 `G` 的部分转为**时间压力**(拖长清场 → 远程多漏几下),**不是爆发压力**。守 i4 不超线性 + 支柱 1 可读(瞥一眼看懂"在打一群")。

## 6. 已知失衡与债 / Known imbalances & debt
> 逆推中发现,按杠杆从高到低排;债-1/2/3 是 04 F-NUM 的核心标的。
- **✅ 债(墙已定,planned in BALANCE-CHANGE-04)· i6 闸门曾无"够不着"那一端。** ilvl 阶梯让掉落变强(债-1),却没有任何一档内容把玩家挡在外面 → 关2 整条功率带坐在关1-通关玩家之下、"墙"在数值上不存在,06 闭环空转。**已由 BALANCE-CHANGE-04 把关2 Boss 兽人酋长抬成墙**(hp220→480、atk9→24),兑现不变量"关1 顶配纯 AFK 过不去、回城用关2 级掉落/强化变强能过"。墙是单点(关2 普通场景/关1 不动),需 playtest 校准准度。
- **✅ 债-1(已定稿,planned in BALANCE-CHANGE-01)· ilvl 阶梯曾是死的。** 所有 `EnemyDef.item_level` 取默认 1 → 掉落恒 ilvl=1、整条上阶梯死锁。**已由 BALANCE-CHANGE-01 设温和 item_level 阶梯解决**(关1 1→10、关2 14→30,暴露 Tier 底部 ~1/3),交 Implementer 落 `.tres`。
- **✅ 债-2(已定夺=接受)· 武器 = 主攻速源。** 战士裸 `attack_speed=1.0` + 白武招牌轴 base 1.0 → 穿上 ≈2.0 次/秒,系**有意**(武器是攻速主要来源,2026-06-19 用户拍板)。保留现值,不改语义/裸值。
- **债-3 · 阶选择均匀、忽略 weight + 不偏 ilvl 深度。** `_roll_affixes` 用 `randi()%合格阶数` 等概率挑阶,`weight` 字段(全 1.0)完全没用上;高 ilvl 时 T10(如 max_hp 1-5)与 T1(115-140)**等概率**,值方差极大、无「越深越易出强阶」拉力。GD/用户表态 v1 **接受均匀**(守可读、当惊喜方差);ilvl 阶梯拉开后此方差会更明显,playtest 若刺眼再改 weight/ilvl 偏置(后续可选,非 v1)。
- **✅ 债(沉淀口已补,planned in BALANCE-CHANGE-02)· 材料曾零沉淀口。** v1 材料单向累积、无消耗。**05 强化补上首个 `slot|white` 沉淀口**(单步 `1+L`、满件 55)。经济校验:产出仍 > 消耗(净累积、无荒、偏富余);若 playtest 显材料过剩 → 优先陡化 `ENH_COST_STEP` 而非降产出。
- **债-4 · kind 权重死值。** `weight_{gold,material,equipment}` 从不参与 roll(掉落恒装备),金币货币未接线。待 F-KIND(Producer)定 v1 是否纳入;纳入则需补 kind roll + 金币沉淀口。
- **债-5 · 狂暴/回血数值未经实战检验。** 快速击杀下 `enrage_threshold=25s` 极少触发;`hp_regen` 词缀存在但无敌人能拖到回血显著。这些常量是纯占位,待有「耐久战」内容后再校准。**08 团战清场更慢(单波 4–6s,仍 < 25s),首次给狂暴常量实战检验机会**——记为团战 playtest 观察点(BALANCE-CHANGE-03 §5/§7),若拖长波意外触发再校准,本期不动其值。
- **✅ 债(已定铺波,planned in BALANCE-CHANGE-05)· 关2 普通场景曾退回单敌、团战机制空转。** 关1 已团战、关2 三普通场景却仍单敌(`enemy` fallback),08 门控/排位/远程在关2 没被行使。**已由 BALANCE-CHANGE-05 把关2 三场景改写成团战波**(WAVE_SIZE 统一 3、Scene2-3 各引入 1 远程、`kill_count` 7→6),承伤经"波间不回血"约束实算收到安全带(P1-基线整场累积 < 100% 不团灭、墙单点仍在 Boss),交 Implementer 落 `stage_02.tres`。准度待 playtest。
- **债-6 · 词缀池薄/金装撞满。** weapon 词缀候选恰好 4 个,金装 [3,4] 条会几乎抽空全池 → 金武缺乏 build 差异。v1 可接受(守 fantasy:先有掉落),池扩充属后续。
