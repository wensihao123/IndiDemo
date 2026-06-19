---
feature: 08-team-combat
status: done
updated: 2026-06-20
---
# HANDOFF — 08 团战:一波多敌(近战门控 + 远程隔位)

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。

## 一句话
把战斗从「单怪车轮」升成「**一波杂兵团**」——同屏 2–4 只敌人,**前排近战 + 后排远程**。
近战**门控**(只有够得着战士的才打、其余排队补位 = 车轮战);远程**隔位**(从后排即可输出战士)。
战士侧**零改动、单体集火**,**AoE 明确推后**给未来技能/法师。地基已预留座位(`enemies: Array[Entity]`、
`in_range` 占位恒真、`select_target` 集火最前),08 = 点亮这些座位 + 加「近/远站位」薄战术层。

## 依赖(前置)
- **战斗结算层已就位**:`CombatArena`(`enemies` 已是数组、`select_target` 集火、`enemy_defeated`/掉落/清场计数)、
  `AICombatComponent.in_range`(现占位恒真,08 要点亮为真门控)、`EnemyDef` / `SceneConfig`(现单敌 + kill_count)。
- **04 / 05 已 done**:掉落/装备 + 城镇构筑闭环在,团战的"更硬一波"才有"变强够到"的对象(支柱 2)。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | **draft(2026-06-19)** — 用户拍板两条:① 战士**单体、AoE 留技能**(v1 不做群伤)② 一波敌人用**近战门控 + 远程隔位**(前排近战够得着才打、排队补位=车轮;后排远程隔位漏血)。守 #7(站位=抽象前/后排×序,无真 2D 走位)、支柱 1(瞥一眼全自动)、i4(不超线性)。开 5 flag(F-ARCH 建议先审 / F-NUM / F-AOE 推后 / 支柱1相容 / Producer 知会) |
| 架构 | Arch Guard | arch/REFACTOR-04-team-combat.md | **draft(2026-06-19)— 判定:装得下,但比"加字段"重。** 根因不止数据:`Arena↔Progression` 刷怪/推进契约 = "每杀一只即重刷整盘单敌",团战要拆成**每清一波才推进**(新不变量 #12,`_spawn_current` 绝不在波未清空时换 `arena.enemies`)。三决策:① `EnemyDef += position_class{MELEE/RANGED}`(默认 MELEE,.tres 向后兼容)+ `SceneConfig += enemy_group: Array[EnemyDef]`(序=排位,旧 `enemy` 留 fallback)② 刷怪/推进粒度 per-enemy→per-wave(敌死仍 per-enemy 掉落/计数,推进只在 `not _has_living(enemies)`)③ **近战门控判定归 `CombatArena` 编排**(非 AI 组件,因门控是阵型级)、前 G 名近战可出手+远程恒真、`in_range` 退役,G=`CombatTuning.melee_gate_capacity`(值交 num-smith)。**波 size=1 退化等价旧行为 = 回归基线。** ARCHITECTURE 已回写 §2.1/§4(+#12)/§5/§6 |
| 数值 | Num Smith | balance/BALANCE-CHANGE-03-team-combat.md | **draft(2026-06-19)** — 团战威胁定值。锚清现状:战士 DPS≈19 / EHP≈134,关1 敌 atk1–5。① **唯一新运行时常量 `CombatTuning.melee_gate_capacity = 2`(G)**——同时最多 2 名最前近战出手、余排队补位;远程不受门控。② 一波规模 2–4 随场景深度递增、**Boss 维持 1**;近/远配比远程少数派(`远程数≈floor(WAVE_SIZE/3)`,v1 上限 1);远程权重 `attack/hp ≈ 0.6×同档近战`(漏血非主伤)——均 per-feature authoring 指南落 08 .tres。③ **新增不变量 i8 团战威胁纯加性**(严禁数量乘性放大;近战超 G 转时间压力非爆发,守 i4)。威胁校验:关1 Scene3 最硬一波峰值并发 DPS≈7.1、单波承伤≈15% EHP=可生还有压。BALANCE.md 已回写 §5(常量+i8)/§6(债-5 团战首检)|
| 计划 | Planner | PLAN.md | **draft(2026-06-19)** — 落 file-level PLAN,照 REFACTOR-04 §4 五步依赖序 + BALANCE-CHANGE-03 值。步 1 数据模型加性(`EnemyDef.position_class` 默认 MELEE / `SceneConfig.enemy_group`+取波 helper,旧 .tres 零迁移)→ 步 2 建整波(`current_wave_defs`/`_spawn_current` 多敌、Entity 烙站位+排位)→ **步 3 拆刷怪/推进契约(核心 #12,单独成步,size=1 退化等价=回归基线)**→ 步 4 门控归 Arena(前 G 近战+远程恒真,`in_range` 退役)→ 步 5 值落地(`melee_gate_capacity=2` + 关1 .tres 铺波/远程 EnemyDef)。每步 headless+gdUnit4 守、步 5 手动 Play 验。**关2 .tres 复算列入「不做」**(回 num-smith) |
| 实现 | Implementer | CHANGES.md | **draft(2026-06-19)** — 五步全落,144/144 test/core 绿。步1 `EnemyDef.position_class`/`SceneConfig.enemy_group`+`wave_defs()` 加性扩展 → 步2 `current_wave_defs`/`_spawn_current` 建整波、Entity 烙站位+排位 → **步3 拆契约**:`advance_after_kill` → `register_kill`(per-enemy)+`advance_after_wave`(per-wave,Arena 在波清空才调),`_spawn_current` 绝不在波未清空换 `arena.enemies`(#12);新增多敌逐清回归测 → 步4 `_front_melee_attackers` 门控(前 G 近战出手+远程恒出手)、`in_range` 删;新增 4 门控测 → 步5 `CombatTuning.melee_gate_capacity=2`(plain var,RefCounted 非 Resource)+ 关1 .tres 铺波(Scene1=2近战/Scene2=2近+1远/Scene3=3近+1远/Boss=1)+ 2 远程 EnemyDef(0.6×近战)。size=1 退化等价=回归基线保持。**关2 .tres 未动**(回 num-smith)。**+ 补最小占位多敌渲染**(playtest 反馈「每轮 1v1」→ 用户拍板补:View 加 4 槽池逐只横排画整波,前排靠左/死敌染灰/远程染蓝;纯表现层、144/144 不受影响)**+ should-fix ②③清尾(2026-06-20,纯注释)**|
| 审查 | Reviewer | REVIEW.md | **APPROVE WITH NITS(2026-06-20)** — 重跑 144/144 实测(非仅信 CHANGES)。步3契约拆分逐位等价证实(`_battle_restarted` 守双重推进、size=1=旧触发点、#12 测正确)、门控前G+远程豁免正确、值全走配置。**无 must-fix**。3 should-fix 全非阻断:① ARCHITECTURE-GUIDE §推进链路仍写旧 `advance_after_kill`(回 arch-guard 同步)② `current_enemy_def()` 现生产死代码、Wiring Contract §3「View 调它」已失准(renderer 改读 Entity.source_enemy_def)③ `MAX_WAVE_SLOTS=4` 与 WAVE_SIZE 隐式耦合(关2 复算时若 >4 会静默漏画敌人)。**手感/视觉/平衡仍须人工 playtest 验**(headless 不验) |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | — (推迟到 v1 功能全做完后统一 UI/juice 轮) |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | — |

> 状态取值:`—`(未开始) / `draft` / `accepted` / `blocked` / `superseded`

## 下一步
**✅ 2026-06-19 — Implementer 落 CHANGES(五步全实现,144/144 test/core 绿)。** 纯加性数据扩展 + 一处契约拆分
(刷怪/推进 per-enemy→per-wave,#12),改动锁在单局战斗层;波 size=1 退化逐位等价 = 回归基线保持。
关1 .tres 已铺波(Scene1=2近 / Scene2=2近+1远 / Scene3=3近+1远 / Boss=1);`in_range` 退役、门控归 Arena。
**✅ 2026-06-19 补 — 最小占位多敌渲染**:playtest 反馈「每轮 1v1」(解算多敌、View 只画波首一只)→ 用户拍板补占位渲染。
`combat_view.gd` 加 4 槽对象池逐只横排画整波(N==1 维持单敌大图=回归;N>1 缩小铺开、前排靠左、死敌染灰、远程染蓝)。纯表现层、144/144 不受影响。**仍待 Play 验视觉**(窄条密度/色辨识)。

**✅ 2026-06-20 — Reviewer 落 REVIEW(APPROVE WITH NITS,重跑 144/144 实测)。** 步3契约拆分逐位等价证实、
门控正确、值全走配置;**无 must-fix**。三 should-fix 全非阻断(见 REVIEW §3)。

**下一棒:🟡 人工 playtest(关1,人做 —— 解算层已绿,唯手感/视觉/平衡靠肉眼)** —— 在 Godot Play 关1,
对照 BALANCE-CHANGE-03 §7 清单①–⑤(单波承伤 ≲20–25% EHP / G=2 车轮感 / 单远程"烦"非"无解" / enrage 未意外触发)
+ 窄条视觉(800×250 里 4 只挤不挤、近红/远蓝辨识、死敌灰显「排队补位」读不读得懂)。playtest 通过即 08 收口。

**✅ 2026-06-20 — Implementer 清掉 should-fix ②③(纯注释,144/144 不受影响,见 CHANGES 补遗 2)**:
② `current_enemy_def()` 标注为生产死代码、保留作 boss 测锚 + 更正 Wiring Contract §3 失准句;③ `MAX_WAVE_SLOTS` 加 WAVE_SIZE 耦合防呆注释。

**✅ 2026-06-20 — Arch Guard 清掉 should-fix ①(纯文档,事实源同步)**:`ARCHITECTURE-GUIDE.md §5③` 敌死三件事第 3 条
`advance_after_kill` → `register_kill`(per-enemy 只计数)+ 补一段「08 拆分:推进改逐波清空触发(`advance_after_wave`,守 #12),
size-1 波逐位等价」;`§5⑤` Boss 分支 `advance_after_kill` → `advance_after_wave`。ARCHITECTURE.md(#12 / §扩展点)REFACTOR-04 时已回写、无需再动;
其余 `advance_after_kill` 残留均在 REFACTOR-04 自身或 00/02/03 冻结历史文档,不改。**三 should-fix 全清。**

**✅ 2026-06-20 — 人工 playtest 关1 通过(用户:「试玩后流程没有问题」)。08 正式收口 → `status: done`。**
解算层 144/144 绿 + 五步实现 + REVIEW APPROVE + 三 should-fix 全清 + 占位多敌渲染 playtest 验过。

**剩余清尾(非阻断,后续功能/统一轮处理,不挂 08 名下)**:
- **✅ 2026-06-20 — Num Smith 复算关2 铺波(BALANCE-CHANGE-05)。** 复算结论:关2 三普通场景 WAVE_SIZE
  统一 = **3**(Scene1 纯 3 近 / Scene2 2 近+1 远 / Scene3 2 近+1 远),`kill_count` 7→6;**WAVE_SIZE≤4
  无需抬 `MAX_WAVE_SLOTS`**。承伤主导项 = 波间不回血(整场 = 2 满波累积),P1-基线整场 < 100% 不团灭、
  墙单点仍在 Boss。**最重要偏离:Scene3 落 3 不照预览的 4**(4 会过载团灭,见 BALANCE-CHANGE-05 §6)。
- **✅ 2026-06-20 — Implementer 落 BALANCE-CHANGE-05(关2 `stage_02.tres` 铺波,CHANGES 补遗 3)。**
  纯数据:建 2 远程 sub_resource(投石暗影手 hp40/atk4、投石食人魔 hp50/atk4,`position_class=1`)→ 三场景改
  `enemy_group`(Scene1 纯 3 近 / Scene2-3 各 2 近+1 远,保留 `enemy` fallback)→ `kill_count` 7→6 → Boss 不动 →
  Scene3 照 BALANCE-CHANGE-05 §6 落 3 敌(非预览 4,4 会团灭 P1-基线)。新增锁值测 `test_stage_02_scenes_are_team_waves`。
  `--check-only` EXIT=0、全量 gdUnit4 **153/153 绿**(report_39)、`MAX_WAVE_SLOTS=4` 无需抬(WAVE_SIZE≤4)。
- **✅ 2026-06-20 — 人工 playtest 关2 通过(用户:「试玩没问题」)。** 关2 团战手感/承伤(Scene3 最深档紧度、
  远程漏血感)+ 占位多敌渲染在关2 视觉经手验通过。关2 团战铺波清尾正式闭合 → **08 全部清尾完结**
  (关1 + 关2 团战均 playtest 验过、153/153 解算绿、REVIEW APPROVE、四 should-fix 全清)。
  剩余仅「关1 手感微调(可后续)」属可选,不挂阻断。
- **🟡 人工 playtest(关1)** —— 手感/视觉/平衡(用户已表示可之后再调)。

## 决策记录
- **2026-06-19 — [用户拍板] 战士单体、AoE 留技能** —— v1 战士每次出手只打一个(集火最前),群伤明确推后给未来技能/法师。来源:用户。
- **2026-06-19 — [用户拍板] 近战门控 + 远程隔位** —— 一波多敌:前排近战只有"够得着"战士才打、其余排队补位(车轮战);
  后排远程不受门控、从后排即可输出战士(隔位漏血),引入近/远站位动态。来源:用户。
- **2026-06-19 — [GD 守] 站位 = 抽象前/后排×序(守 #7)** —— 用 `in_range` 门控 + 数组序实现,**绝不做真 2D 走位/碰撞/抛射物**。
- **2026-06-20 — [用户拍板] 关2 铺波守 ≤4、靠敌单值加压不靠人海** —— Num Smith 复算落 WAVE_SIZE 统一 3、
  `kill_count` 6;Scene3 因波间不回血实算偏离预览 4→3(4 会团灭)。来源:用户 + BALANCE-CHANGE-05。
- **2026-06-19 — [GD 留白] 远程"够不到"= AoE 的未来用武之地** —— v1 接受战士够不到后排远程(= 远程持续压力来源);
  这层"前排墙 + 后排远程"结构天然是未来 AoE 的挂点,但 v1 不预埋接口(守"不为没影的系统提前抽象")。

## 未决 flags
- **✅ F-ARCH(已解除 2026-06-19)** — Arch Guard 定案(REFACTOR-04):装得下,加性数据扩展 + 一处契约拆分(刷怪/推进 per-enemy→per-wave,#12)。`EnemyDef.position_class`(默认 MELEE).tres 向后兼容;`SceneConfig.enemy_group`(旧 `enemy` 留 fallback);门控归 `CombatArena`、`in_range` 退役。波 size=1 退化等价 = 回归基线。下游 num-smith→planner。
- **✅ F-NUM(已解除 2026-06-19)** — Num Smith 定稿(BALANCE-CHANGE-03):门控 `G=2`、一波 2–4 随深度递增 / Boss=1、远程少数派 `attack/hp≈0.6×近战`、新增 i8 团战威胁纯加性(守 i4)。关1 威胁校验过(单波≈15% EHP 可生还)。**关2 .tres 落地前需回 num-smith 复算 WAVE_SIZE**(敌值更高)。值走配置(`CombatTuning`/`.tres`)勿硬编码。**✅ 关2 复算已出(2026-06-20,BALANCE-CHANGE-05):WAVE_SIZE 3 / `kill_count` 6 / 2 新远程,交 Implementer。**
- **🟢 F-AOE(明确推后)** — 战士/玩家 AoE 留给未来技能/法师,v1 不做、不预埋接口。团战站位结构是其未来用武之地。
- **🟢 支柱 1 相容(已判定相容,待 playtest)** — 团战只加画面密度与压力、不加操作(仍全自动)。风险:800×250 窄条里"一群"挤不挤得下/看得清 → 留统一 UI 轮 + playtest。
- **🟢 UI/juice 推迟** — 本功能阶段用占位程序美术验功能;界面皮/动效/音随全局 UI/juice 统一轮做(用户拍板 2026-06-19)。
- **🟢 Producer 知会** — 08 scope 锁"敌方一波多敌 + 近/远站位门控";多波编排/boss 团/玩家 AoE 属新功能,另开条目。
