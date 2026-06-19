---
artifact: BALANCE-CHANGE
feature: 08-team-combat
role: Num Smith
status: draft
updated: 2026-06-19
inputs: [BALANCE.md, harness/features/08-team-combat/FEATURE-DESIGN.md, harness/arch/REFACTOR-04-team-combat.md, BACKLOG.md, project-context.md, src/core/combat/combat_tuning.gd, src/core/combat/combat_arena.gd, src/core/combat/skill_component.gd, src/combat/enemy_def.gd, assets/data/combat/stage_01.tres, assets/data/combat/stage_02.tres, data/config/starting_roster.json, data/config/item_bases.json]
next: Planner
---

# BALANCE-CHANGE-03 — 08 团战:一波多敌的威胁数值

## 1. 触发 / Trigger
08-team-combat 引入新数值:一场战斗从单怪变「**一波多敌**(前排近战 + 后排远程)」。Arch(REFACTOR-04)已定结构
(`EnemyDef.position_class`、`SceneConfig.enemy_group`、刷怪/推进 per-wave、门控归 Arena)。num-smith 这一棒定**值**:
**一波规模、近/远配比、门控容量 G、远程伤害权重**,并校验整波威胁守 **i4 不超线性**。

## 2. 现状诊断 / Diagnosis(锚点 = 真实数值)
团战不是"调某个失衡",而是**给一个新的威胁结构定值**,得先把现状战力锚清楚(全部对齐真实文件):
- **战士开局**(`starting_roster.json` + `item_bases.json`,白武白甲 ilvl1):
  `attack ≈ 6 + (3.0+0.5) = 9.5`,`attack_speed ≈ 1 + (1.0+0.01) = 2.01`,`armor ≈ 0 + (5+1) = 6`,`max_hp = 120`。
  → **输出 DPS ≈ 9.5 × 2.01 ≈ 19/s**;**EHP ≈ 120 / (1 − 6/56) ≈ 134**(护甲 6 仅减伤 ~10.7%)。
- **关1 敌人**(`stage_01.tres`):哥布林 hp12/atk1、野狼 hp18/atk2、兽人 hp28/atk3、Boss 哥布林王 hp90/atk5(均 as=1)。
  → 单敌对战士的**到手 DPS ≈ atk × 0.893**:哥布林 ~0.9/s、野狼 ~1.8/s、兽人 ~2.7/s。战士秒杀小怪(hp12 → <1s)。
- **当前单怪结算**(`combat_arena.tick_combat`):敌攻击循环**无门控**(`in_range` 占位恒真但根本没被调),
  当前同屏恒 1 敌,所以"多敌同时输出"这件事**今天不存在** → 团战是**全新的并发威胁源**,无旧值可调,只能新定。

**根因点(为什么必须现在定值、且能守 i4):** 一波的总威胁 = **各敌个体 DPS 之和**(近战那部分受门控 G 截断同时活跃数)。
这是**对敌数纯加性/线性**的——只要**禁止任何"敌越多每个越强"的乘性放大**,团战天然不碰 i4。i4 的真正风险不在"人多",
而在"会不会有人顺手给团战加个'人越多越狂暴'的乘性 buff"。本方案明令禁止之(见 §5 新增 i8)。

## 3. 目标数值 / Target numbers(delta vs BALANCE.md)

### 3a. 唯一新增运行时常量(走配置,守 hard-NO)
- **`CombatTuning.melee_gate_capacity = 2`**(`G`)—— 同一时刻最多 **2** 名最前存活近战可出手,其余近战**排队**(前排死则补位)。
  远程**不受门控**(隔位恒可出手)。选 2 的理由:G=1 太"礼貌"(纯一对一、几乎无群压)、G≥近战数则门控形同虚设(回到一拥而上);
  **G=2 = "一条两人宽的前线"**,既有车轮补位感、又给真实并发压力。**这是团战唯一的真运行时旋钮**,改它牵动全部近战威胁。

### 3b. 一波组成(authoring 指南 + per-feature 表,**不进 BALANCE.md 标准件**,落 08 的 .tres)
> 一波"由哪些敌、谁前谁后"是 per-feature 配置(`SceneConfig.enemy_group`),具体表归 08 功能目录;此处给**形状与上限**。
- **一波规模 `WAVE_SIZE`**:v1 普通场景 **2–4**,**随场景深度在一关内递增**;**Boss 场景维持 size=1**(守 Boss 单挑高光,= 旧行为退化基线,不做 Boss 团)。
  建议形状(关1 示例,Planner/Implementer 落 .tres 时可微调):

  | 场景 | WAVE_SIZE | 近战 | 远程 | 说明 |
  |------|-----------|------|------|------|
  | Scene1 | 2 | 2 | 0 | 纯近战入门,先让"一波两个"被看懂,无远程干扰 |
  | Scene2 | 3 | 2 | 1 | **引入第一个远程**(隔位漏血登场) |
  | Scene3 | 3–4 | 2–3 | 1 | 近战墙加厚,门控 G=2 → 多出的近战转为"排队 = 拉长清场 = 远程多漏几下" |
  | Boss | 1 | 1(Boss) | 0 | Boss 单挑不变 |

- **近/远配比**:远程是**少数派**(墙是近战、远程是后面的冷箭)。指南:`远程数 ≈ floor(WAVE_SIZE / 3)`,**v1 上限 1**(单远程),
  避免远程叠成"主伤害"。近战数 = `WAVE_SIZE − 远程数`。

### 3c. 远程伤害权重(authoring 指南,落 08 的远程 EnemyDef .tres)
远程**不受门控、全程在线**,有效在场时间 > 被门控的近战,故**单值必须压低**,否则远程喧宾夺主:
- **远程 `attack` ≈ 0.6 × 同档近战 attack**(`RANGED_ATK_FACTOR ≈ 0.6`,authoring 锚,非运行时常量)。
  例:关1 兽人档(近战 atk3)配一个远程"投石哥布林" atk≈2。
- **远程 `max_hp` ≈ 0.6 × 同档近战 hp**(`RANGED_HP_FACTOR ≈ 0.6`):远程**脆**——前排一清,战士集火它**很快倒**,
  保证"持续漏血"是有期限的压力、不是无解。例:配 hp≈16-18。
- 远程 `attack_speed` 维持 1(同其它敌),不靠攻速找补。

### 3d. 威胁校验(关1 Scene3 最硬一波,守 i4 + 可生还)
取 Scene3 = 2 近战(兽人 atk3,hp28)+ 1 远程(atk2,hp16),G=2:
- **峰值并发到手 DPS** = 2×(3×0.893) + 1×(2×0.893) ≈ **5.36 + 1.79 ≈ 7.1/s**(全员加性,**无乘性**,守 i4)。
- **战士清场耗时**:集火逐个,兽人 28/19≈1.5s ×2 + 远程 16/19≈0.85s ≈ **~3.9s**。
- **整波承伤** ≈ 7.1/s 摊销(近战随清场递减、远程全程)≈ **粗略 18–22 点 / 波**,占 EHP134 的 ~15%。
  → **单波可生还、有体感压力**;一个场景 `kill_count` 多波累积(按敌死计数,见 §5)制造"够不够强"的支柱 2 拉力。健康。
- **若多出的近战(Scene3 取 3 近战)**:G=2 → 第 3 个近战**排队不增峰值伤害**,只把清场拖到 ~5.4s → 远程多漏 ~3 点。
  **关键性质:近战超过 G 的部分 = 转为"时间压力(远程多漏)",不是"爆发压力"** —— 这正是 i4 要的"人多不超线性"。

## 4. 调整策略 / Strategy(依赖序,值层面)
1. **先定锚:`melee_gate_capacity = 2`**(`CombatTuning`)—— 它是团战所有近战威胁的总闸,先固定它,后面的波组成才有参照。
2. **再定每波近战数**(派生于 G):普通场景近战 2–3。≤G 的部分构成峰值并发,>G 的部分转时间压力。
3. **远程作为少数派叠加**(派生于"漏血而非主伤"):单远程、`RANGED_ATK_FACTOR 0.6` / `RANGED_HP_FACTOR 0.6`,压低到"漏血"量级。
4. **按场景深度铺 WAVE_SIZE 曲线**(Scene1 纯近战入门 → Scene2 引入远程 → Scene3 加厚),Boss 维持 1。
5. **校验**:每个场景最硬一波的"峰值并发 DPS × 清场耗时"占战士 EHP 的比例落在**可生还区(单波 ≲ 20–25% EHP)**;
   关2 同法按其更高敌值复算(关2 敌 hp50–220/atk 偏高 → WAVE_SIZE 可更克制,优先靠敌单值而非堆数量加压)。

> 牵动关系:**改 G** → 直接缩放所有近战峰值威胁(最大杠杆);**改远程 factor** → 缩放漏血压力;**改 WAVE_SIZE** → 改清场时长 + 间接改远程总漏血。三者中 **G 是主锚**,先锁 G 再铺其余。

## 5. 影响面与迁移 / Blast radius & migration
- **新增常量**:`CombatTuning.melee_gate_capacity`(默认 2)。BALANCE.md §5 收录。
- **新增 BALANCE 不变量 i8**(团战威胁纯加性,见下),BALANCE.md §5 收录。
- **per-feature 数据**:08 的 `SceneConfig.enemy_group` 各波组成 + 远程 `EnemyDef` 新 .tres(按 §3b/§3c 指南),落 08 功能目录;**不进 BALANCE.md**。
- **现有 .tres 向后兼容**:`stage_01/stage_02` 不改 = size-1 单近战波(`position_class` 默认 MELEE + `enemy` fallback)→ **数值行为与今日逐位等价**(REFACTOR-04 退化基线)。要不要把现有场景改造成多敌波,是 Implementer 落 §3b 表时的内容,不是迁移负担。
- **无存档迁移**:`EnemyDef`/`SceneConfig`/`CombatTuning` 全是只读模板/调参,非 `PlayerState` 存档单元。
- **联动 enrage(债-5)**:团战清场更慢,`battle_time` 每波重置但单波可达 4–6s,仍 < `enrage_threshold 25s` → enrage 基本仍不触发;但团战让"耐久战"更可能,**债-5 的狂暴常量首次有机会被实战检验**,记为 playtest 观察点,本棒不动其值。

## 6. 风险与被否选项 / Risks & rejected alternatives
- **风险·G 与可读性**:G=2 在 800×250 窄条里,"谁是活跃的 2 个近战 / 谁在排队"要表现层能传达(否则玩家看不懂为何有人不动手)。
  纯数值上 G=2 站得住;**呈现交统一 UI/juice 轮 + playtest**。若实测窄条挤不下 3–4 敌,**优先降 WAVE_SIZE 上限到 3,不动 G**。
- **风险·远程无解感**:远程隔位 + 战士够不到(设计内,F-AOE),若 `RANGED_ATK_FACTOR` 偏高或远程数 >1,会从"漏血"变"磨死"。
  缓释:v1 锁**单远程 + factor 0.6 + 脆血(0.6 HP)**。playtest 若仍刺眼 → **先降远程 attack,再降远程数**,**不要给战士加 AoE**(守 GD 的 F-AOE 推后)。
- **风险·关2 复算**:关2 敌值更高(食人魔 hp85、酋长 atk9),若照搬关1 的 WAVE_SIZE+配比会过载。**关2 优先靠敌单值加压、WAVE_SIZE 更克制**;Implementer 落关2 .tres 前回 num-smith 复算一次。
- **被否 A:G=1**(纯一对一车轮)。否 —— 群压太弱,和单怪手感几乎无差,辜负"被一群围攻"的 fantasy。
- **被否 B:无门控、全近战同时打**(G=∞)。否 —— 4 个近战齐砍 = 峰值 DPS 翻 4 倍,瞬间击穿 EHP,且对敌数超线性式体感(违 i4 精神)、不可读。
- **被否 C:远程也设独立"后排容量"门控**。否(v1)—— 远程本就少数派(单远程),再加一层门控是过度设计;单远程恒在线足够表达隔位。
- **被否 D:用乘性"团队士气/数量狂暴"放大每敌伤害**。**硬否** —— 直接违 i4/i8;团战威胁必须纯加性。

## 7. 交接 / Handoff
**结构性数值改动(新常量 + 新不变量 + 与 REFACTOR-04 结构耦合)→ next: Planner**(已与 arch 同指向 `/role-planner 08-team-combat`)。
- Planner 把本文的值并入 REFACTOR-04 §4 的步骤:**步 5** 落 `CombatTuning.melee_gate_capacity=2`;**步 1/2** 的 .tres 按 §3b/§3c 表铺波(近/远 EnemyDef + enemy_group)。
- **走配置勿硬编码**:`melee_gate_capacity` 经 `CombatTuning` 注入(测试可覆值);波组成/远程值全走 `.tres`。
- **playtest 验证清单**:① 关1 Scene3 单波承伤是否 ≲ 20–25% EHP(可生还有压);② G=2 车轮感是否成立(不是一对一也不是被秒);
  ③ 单远程漏血是"烦"不是"无解";④ 关2 按更高敌值复算后是否仍可生还;⑤ enrage 在拖长的波里是否意外触发(债-5 首检)。
- **BALANCE.md 已回写**:§5 新增常量 `MELEE_GATE_CAPACITY` + 不变量 i8;§6 债-5 标注"团战首次给狂暴常量实战检验机会"。
