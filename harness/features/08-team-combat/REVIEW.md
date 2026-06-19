---
artifact: REVIEW
feature: 08-team-combat
role: Reviewer
status: draft
updated: 2026-06-20
inputs: [PLAN.md, CHANGES.md, harness/arch/REFACTOR-04-team-combat.md, harness/balance/BALANCE-CHANGE-03-team-combat.md, project-context.md, src/core/combat/combat_arena.gd, src/core/combat/progression_controller.gd, src/core/combat/entity.gd, src/combat/enemy_def.gd, src/combat/scene_config.gd, src/core/combat/combat_tuning.gd, src/core/combat/ai_combat_component.gd, src/combat/combat_view.gd, test/core/combat/combat_arena_test.gd, test/core/combat/progression_test.gd, assets/data/combat/stage_01.tres]
next: Engine Integrator / Human（人工 playtest）
---

# REVIEW — 08 团战:一波多敌(近战门控 + 远程隔位)

## 1. Verdict
**APPROVE WITH NITS.**

五步实现忠实于 PLAN + REFACTOR-04 + BALANCE-CHANGE-03,核心契约拆分(#12)正确、门控判定正确、
值全走配置无硬编码。我重跑 `test/core` 实测 **144/144 / 0 fail / exit 0**(非仅信 CHANGES)。
无 must-fix 阻断项。剩余项全为非阻断:**手感/可读性必须人工 playtest 验**(headless 验不了)、
几处文档漂移与无害死代码。功能解算层可以放行;视觉与平衡待人验后定稿。

## 2. Must-fix (blocking)
无。

## 3. Should-fix (non-blocking)

- **`harness/ARCHITECTURE-GUIDE.md:154,163` 文档漂移** — 人类导读仍把敌死推进写成
  `progression.advance_after_kill()`,但该方法已拆成 `register_kill()` + `advance_after_wave()`
  且重刷副作用已从 `_handle_enemy_defeated` 摘出。*为何要紧*:GUIDE 是人类理解战斗推进的入口,
  纯 vibe coding 下导读失真会误导后续 role/作者。*方向*:这是 Arch Guard 拥有的事实源,
  不在 Implementer 职责内改 —— 建议下一棒回 `/arch-guard` 把 §推进链路同步到 register_kill /
  advance_after_wave + #12(REFACTOR-04 已记此变更,只是 GUIDE 未回写)。

- **`src/core/combat/progression_controller.gd:72 current_enemy_def()` 现为生产死代码** —
  renderer 重写后 `combat_view.gd` 改读 `_living_enemy().source_enemy_def`,全仓 `src/` 已无任何
  生产调用方(grep 确认),仅其自身测试 `test_current_enemy_def_returns_boss_at_boss_scene` 调它。
  *为何要紧*:CHANGES.md Wiring Contract §3 仍称「View 调 `current_enemy_def()`」,与现状不符
  (renderer 已不调它)——Wiring Contract 失准。*方向*:二选一 —— ① 保留作 boss-scene 语义的
  测试锚 + 把 Wiring Contract §3 那句「View 调 current_enemy_def」更正为「View 直读 arena.enemies /
  Entity.source_enemy_def」;或 ② 连同其测试一并删。倾向 ①(留一个被测的薄查询无害,删反而丢回归点)。

- **`src/combat/combat_view.gd:29 MAX_WAVE_SLOTS=4` 与 WAVE_SIZE 上限隐式耦合** — renderer 只画前 4 槽,
  `_update_enemy` 的 `for i in MAX_WAVE_SLOTS` 会**静默截断**波内第 5 只起的敌人(不渲染、但解算照打)。
  关1 max 波=4 恰好不触发;但关2 铺波前回 num-smith 复算 WAVE_SIZE 时若 >4,View 会漏画。
  *为何要紧*:漏画的敌人仍在打战士 → 玩家「被看不见的敌人扣血」。*方向*:非本期阻断(关2 明确 out-of-scope),
  但请在「关2 复算」flag 旁加一句「同步抬 MAX_WAVE_SLOTS 或确认 WAVE_SIZE≤4」,避免日后踩。

## 4. Nits (optional)
- `combat_arena.gd:148 _front_melee_attackers()` 依赖 `enemies` **数组序**等于排位序(`_spawn_current`
  按 `from_enemy_def(defs[i], i)` 建波,故数组序==rank,二者天然一致),但门控实际没读 `Entity.lane`。
  当前正确;若将来有谁重排 `enemies` 数组而不重排 lane,门控会和「视觉排位」脱钩。一句注释点明
  「门控按数组序、数组序即排位」可防未来误改。非必须。
- `combat_view.gd:123` 多敌时敌名仍固定渲染在旧单敌位 `(596,64)`(只画 front 一只的名),
  多敌横排时名字不一定压在 front 头顶 —— 纯呈现层、属 UI/juice 统一轮,占位可接受。

## 5. What I checked but found fine

- **步 3 契约拆分(最高风险)逐位等价**:追踪了 size-1 波与多敌波两条 tick 路径 ——
  敌死 → `_handle_enemy_defeated` 只 `register_kill`(per-enemy 计数)、**不再重刷**;玩家攻击循环后
  `not _has_living(enemies)` 才调 `advance_after_wave`,且 `not _battle_restarted` 守门防止
  「信号处理器已重开战」与「Arena 自驱推进」**双重推进**。size-1 波:那一只死=波清空=旧触发点,
  逐位等价;`_respawning_arena` 那条 aspd15「每 tick 恰一杀」的旧累加器断言靠 `_battle_restarted`
  仍成立(144 基线全保持)。`progression_test::test_multi_enemy_wave_clears_one_by_one_without_respawn`
  正确证明 #12(杀前排→后排仍活、数组未被整波冲掉、未推进;两只都清才重刷)。
- **门控正确性**:`_front_melee_attackers` 按数组序取前 G 存活近战、远程跳过不占名额;攻击循环里
  远程恒出手、近战仅前 G 出手(余者 `continue` 前置于 `accumulate` → 真排队不蓄力 = 车轮,守 i8)。
  4 例门控测覆盖:容量截断(G=2 三近战仅前 2 出伤)、前排死补位、远程豁免、`melee_gate_capacity` 覆值(G=3)。
  实测断言数值(980/980/970/970)与逻辑一致。
- **数值全走配置、守 hard-NO**:唯一新运行时常量 `melee_gate_capacity=2` 在 `CombatTuning`(plain
  `var`,因 `extends RefCounted` 下 `@export` 无效 —— 这点 CHANGES 已注明,正确);波规模/近远配比/远程权重
  全在 `stage_01.tres`。核对 .tres 值对 BALANCE-CHANGE-03 §3b/§3c:Scene1=2 近(atk1/hp12)、
  Scene2=2 野狼(atk2/hp18)+1 投石哥布林(atk1/hp11≈0.55–0.61×)、Scene3=3 兽人(atk3/hp28)+1 投石兽人
  (atk2/hp16≈0.57–0.67×)、Boss size-1 —— 远程≈0.6×同档近战,达标。逻辑层无散落硬编码平衡数。
- **加性数据扩展向后兼容**:`EnemyDef.position_class` 默认 MELEE、`SceneConfig.enemy_group` 空时
  `wave_defs()` 回退 `[enemy]` → 旧 .tres(关2)不改即 size-1 单近战波,零迁移。
- **退役无残留**:`AICombatComponent.in_range()` 已删,grep 全 `src/` 仅注释提及旧名,**无生产调用**;
  其占位测试已删。
- **renderer 不碰解算**:combat_view 改动纯读 `_arena.enemies` + Entity 字段渲染(N==1 大图居中=Boss/
  单挑回归观感、N>1 横排缩小、死敌灰显、远程染蓝、无贴图回退色块、各自血条),无写回战斗态;
  语法 `--check-only` 过,144/144 不受影响。空波/ front==null 守 null 安全。**注**:表现层项目约定
  本就手动验(project-context §1),故 renderer 正确性靠 playtest,不由 gdUnit4 覆盖 —— 见下。
- **范围忠实**:renderer 是本期超出原 PLAN(PLAN 把 View 推迟到 UI 轮)的新增,但属 **2026-06-19
  用户拍板「补最小占位渲染」**的授权决策(playtest 反馈「每轮 1v1」触发),非计划外顺手加功能,faithful。
  AoE / 多子波 / 真 2D 走位 / 关2 铺波均按 PLAN「不做」守住。

### 待人工验(非我能验,务必做)
- **手感/可读性 playtest(关1)**:headless 验不了。在 Godot Play 关1,对照 BALANCE-CHANGE-03 §7 清单
  ①单波承伤 ≲20–25% EHP ②G=2 车轮补位感成立 ③单远程「烦」非「无解」④enrage 未在拖长波里误触(债-5 首检)。
- **窄条视觉**:800×250 里 4 只挤不挤得下、近(红)/远(蓝)色辨识、死敌灰显是否读得懂「排队补位」。
- **关2 复算**:关2 .tres 铺波前回 `/num-smith 08-team-combat` 复算 WAVE_SIZE(并见 §3 第三条 MAX_WAVE_SLOTS)。
