---
artifact: BALANCE-CHANGE
feature: 04-loot-equipment
role: Num Smith
status: draft
updated: 2026-06-19
inputs: [BALANCE.md, features/04-loot-equipment/FEATURE-DESIGN.md, features/04-loot-equipment/PLAN.md, data/config/affix_pool.json, data/config/item_bases.json, data/config/loot_tables.json, data/config/starting_roster.json, assets/data/combat/stage_01.tres, assets/data/combat/stage_02.tres, src/combat/enemy_def.gd, src/core/systems/loot_generator.gd, src/core/combat/skill_component.gd]
next: Implementer
---

# BALANCE-CHANGE-01 — 04 掉落装备数值定稿(item_level 阶梯 + 现状确认)

## 1. 触发 / Trigger
04-loot-equipment 收窄为「表层 + 数值定稿」,F-NUM 要把占位数值精调成可玩基线。逆推建 `BALANCE.md v1` 时发现头号失衡:**所有怪 `item_level` 取默认 1,整条词缀 Tier 上阶梯死锁**(债-1)。本案据用户拍板的两条手感决策(温和 ilvl 阶梯 / 接受攻速双计)给出目标数字。

## 2. 现状诊断 / Diagnosis
- **债-1(根因,本案主修):** `EnemyDef.item_level` 默认 1,`stage_01.tres`/`stage_02.tres` 八个怪子资源**无一覆盖** → `LootGenerator._roll_affixes` 的 `qualified_tiers(ilvl)` 恒只返回 `ilvl_req==1` 的最低阶。结果:`max_hp` 永远只出 T10(1-5)、`crit_chance` 只出 T5(0.5-2%)、所有 2 阶词缀只出 T2,**整条强阶(直到 ilvl_req 90/80/30)永不解锁**。这不是某个值错,而是**驱动整条 Tier 闸门的输入变量没被赋值** → 架空不变量 i6 与支柱 2「变强够到下一个怪」。
- **债-2(已定夺=接受,不改):** 战士裸 `attack_speed=1.0` + 白武招牌轴 base 1.0 → 穿上 ≈2.0 次/秒。用户确认**有意**(武器 = 主攻速源)。保留现值,仅在 BALANCE.md 标注语义、撤销「疑似双计」债。
- **债-3(保持均匀,不改):** 阶选择 `randi()%合格阶数` 忽略 `weight`、不偏 ilvl 深度。GD 已表态 v1 接受均匀(守可读)。本案**不动阶选择逻辑**;但注意:一旦 ilvl 阶梯拉开,均匀挑阶会让高 ilvl 物品的词缀值方差变大(同件可能 T7 也可能 T10)——属可接受的「惊喜」方差(支柱 3),记为后续可选曲线化项。

## 3. 目标数值 / Target numbers
> Delta vs BALANCE.md。**仅改 8 个 EnemyDef 子资源的 `item_level` 一个字段**;公式 / base 曲线 / Tier 表 / 稀有度权重 / 分解 **全部维持现值**(逆推已确认其结构合理,只是被债-1 锁死)。

**(a) item_level 阶梯(温和,本案唯一数值改动)** — 改 `assets/data/combat/stage_0*.tres` 各怪 `item_level`:

| 关 | 场景/怪 | 现 item_level | 目标 item_level |
|----|---------|--------------|----------------|
| 1 | 哥布林(Scene1) | 1(默认) | **1** |
| 1 | 野狼(Scene2) | 1 | **3** |
| 1 | 兽人(Scene3) | 1 | **6** |
| 1 | Boss 哥布林王 | 1 | **10** |
| 2 | 精英兽人(Scene1) | 1 | **14** |
| 2 | 暗影狼(Scene2) | 1 | **18** |
| 2 | 食人魔(Scene3) | 1 | **24** |
| 2 | Boss 兽人酋长 | 1 | **30** |

**(b) 该阶梯解锁的 Tier(派生自现有 `affix_pool.json` 的 `ilvl_req`,验证用):**
- **关1(ilvl 1→10):** `max_hp` 解到 T9(ilvl_req 8;T8 需 16,锁)、`crit_chance` 仅 T5、所有 2 阶词缀仅 T2(T1 需 30,锁)。→ 关1 = 入门低阶,稳。
- **关2(ilvl 14→30):** 到 boss ilvl30 时,`max_hp` 解到 T7(ilvl_req 25;T6 需 34,锁)、`crit_chance` 解到 T4(ilvl_req 20;T3 需 40,锁)、**全部 2 阶词缀的 T1(ilvl_req 30)首次解锁**。→ 关2 = 看得见的中阶跃迁,对上推荐项「max_hp 到 T7 / crit 到 T4 / 2 阶词缀高阶解锁」。
- v1 共暴露 Tier 阶梯的**底部约三分之一**(ilvl 上限 30 / 满阶 90);上阶梯(max_hp T6-T1、crit T3-T1)留给 v1 之后的更深内容 —— 守「温和、长期成长」。

**(c) 维持不变(确认现值即定稿,非占位待调):** 稀有度权重(白重、Boss 偏蓝金,守支柱3,如关2酋长 35/45/20)、kind 权重(死值,待 F-KIND)、`drop_chance`(0.5-1.0 阶梯)、`material_per_decompose=1`、`decompose_threshold=white`、稀有度条数 white0/blue1-2/gold3-4、全部 base 曲线、armor_k=50、战士裸基础与开局白装。

## 4. 调整策略 / Strategy
1. **锚先行:** 设 8 个怪的 `item_level`(上表)。这是唯一输入变动。
2. **派生自动跟随:** Tier 解锁面(b)由 `qualified_tiers(ilvl)` 现成逻辑自动得出,**无需改任何公式/表**。
3. **校验不变量:** 跑一遍确认 i6 恢复(更深怪 → 更高 ilvl → 更高 Tier 上限)、i4 仍成立(没动公式,无超线性)。
4. **连带效应(需知会、非阻塞):** 04 自动填空**只填空槽、不替换**(i3),战士开局仅**饰品空槽**会被填一次;白武/白甲(ilvl1)不会被换。故**ilvl 阶梯在 04 内的可见兑现 = ①包里蓝/金件随关卡推进肉眼变强(表层面板可查)+ ②那一次饰品填空**;高 ilvl 装备的「穿上变强」完整兑现要等 **05 手动换装**。这正确——04 的 fantasy 是「看见刷到啥 + 看见包在变强」,符合 FEATURE-DESIGN。

## 5. 影响面与迁移 / Blast radius & migration
- **触及文件:** `assets/data/combat/stage_01.tres`(4 处:野狼/兽人/哥布林王 + 哥布林保持 1)、`assets/data/combat/stage_02.tres`(4 处)。**纯 `.tres` 子资源字段值编辑,零代码、零公式、零配置 JSON 改动。**
- **存档迁移:** 无破坏。`item_level` 不进存档关键路径;已存档的背包物品各自带生成时的 ilvl(旧档里是 1),新档掉落按新阶梯——不需迁移、向后兼容。
- **与 04 实现关系:** 与 04 PLAN 的「稀有度接线 + 表层面板」**正交、可并入同一 Implementer pass**(都不冲突);也可单独作为一次 `.tres` 数据编辑先落。

## 6. 风险与被否选项 / Risks & rejected alternatives
- **被否「陡峭展示满阶梯」(stage2 推 ilvl 40-50):** 会把成长压进 2 关、上阶梯很快贬值,长期曲线变陡,违「温和长期陪伴」。用户已选温和。
- **被否「极简低 ilvl(全程 1-5)」:** 掉落手感平、词缀强度不拉开,削支柱 2。用户已否。
- **被否「攻速改语义/降裸值」(债-2):** 用户确认接受双计为有意,改之牵动已调好的早期手感,无收益。
- **风险 · 均匀挑阶 + 高 ilvl 方差(债-3):** 关2 后期同部位词缀值波动变大(T7~T10 等概率)。属可接受惊喜方差;**需 playtest 确认**不会让玩家觉得「金件还不如蓝件」。若刺眼,后续可改 weight/ilvl 偏置(非本案)。
- **风险 · 04 内变强不明显:** 因只填饰品空槽(见 §4.4),开面板时右栏属性跳变可能只有一次。**需 playtest 确认**「包在变强」是否足够兑现 fantasy;若不足,真正的发力点是 05 换装,不是再调 ilvl。
- **需 playtest 校准项:** ilvl 阶梯陡缓手感、关2 蓝/金件读起来是否「明显更强」、材料累积速率(无沉淀口,纯观察是否过快堆积)。

## 7. 交接 / Handoff
**next: Implementer**(纯 `.tres` 值编辑,非结构性)。
- 按 §3(a) 表把 `stage_01.tres` / `stage_02.tres` 八个 `EnemyDef` 子资源的 `item_level` 改成目标值(哥布林保持 1,其余新增/改写该字段)。
- 验证:`--headless --check-only` 退出 0;开 Godot 编辑器确认 .tres 加载无误、Inspector 里 item_level 显示新值;手动 Play 一段,开表层面板观察「关卡推进 → 包里蓝/金件 ilvl 上升、词缀阶变高」。
- 可与 04 PLAN 的稀有度接线 + 表层面板同 pass 落地。
- **后续(非本案):** 债-3 阶选择曲线化、债-4 kind/金币(F-KIND)、债-5 狂暴/回血校准、债-6 词缀池扩充 —— 均留 v1 之后或对应 flag。
