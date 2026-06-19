---
artifact: CHANGES
feature: 00-foundation-redesign
role: Implementer
status: draft
updated: 2026-06-19
inputs: [HANDOFF.md(F-SaveBoss flag), src/core/game_controller.gd, src/core/combat/progression_controller.gd, src/core/systems/save_system.gd, test/core/game_controller_test.gd, project-context.md]
next: Reviewer
---

# CHANGES — F-SaveBoss:打通 Boss 后重开重打 Boss 的存档续战修复

> §F 手动 Play 抓到的真 bug:打通 Boss → 自动存档 → 关游戏 → 重开**又从 Boss 那格重打**。
> 修 `GameController._boot` 续战游标读取(据 `max_unlocked_stage` 判别 "Boss 已通" → 续到下一关开头)。
> 全套 **117/117、0 orphans**(116 基线 + 1 新集成回归测),已验证回归测可证伪(撤补丁即 FAIL)。

## 1. What changed(每文件一行)

- `src/core/game_controller.gd` — `_boot` 末尾续战游标修正:若读档的 `_resume_scene == ProgressionController.BOSS_SCENE` 且 `progression.max_unlocked_stage > _resume_stage`(= Boss 已清判别)→ 续战落点改 `(max_unlocked_stage, 0)`(+ 两行 why 注释)。
- `test/core/game_controller_test.gd` — 新增 `_two_quick_stages()` 辅助 + `test_reboot_after_boss_resumes_past_boss_not_refight`:打通第一关 Boss → 重 boot → 断言续到第二关开头(`cur_stage==1`/`cur_scene==0`/有怪),非 Boss 格。

## 2. Why(映射 F-SaveBoss flag)

- **根因(HANDOFF F-SaveBoss)**:`progression_controller.gd:100-109` Boss 分支里 `boss_cleared.emit`(触发 `GameController._on_boss_cleared`→`_autosave`)发信号那一刻,`cur_scene` 仍 = `BOSS_SCENE`(3)——游标要等通关倒计时后 `_execute_push()`(:176-181)才推进。`save_system.gd:15-19` 存的就是当下 `(cur_stage, 3)`,重开 `begin_run` 据此从 Boss 开局。`max_unlocked_stage` 已正确 +1,只是续战读 `cur_stage/cur_scene` 而非它。
- **修法(flag 推荐的最小改,不动存档格式 / 不动 FSM)**:只在 `GameController._boot` 续战读取处加判别。`max_unlocked_stage > cur_stage` 天然区分两态——Boss 已通(max 已 +1)续下一关;Boss 打一半就关(max 未 +1,== cur_stage)续回 Boss 续打。
- **回归测**:flag 要求补 "Boss 清→存→重开→不在 Boss 格" 集成测,堵 116 测漏的"自动存档时机 × 进度游标"集成缝(原 round-trip 测用普通游标、progression FSM 测不跨"存→重开")。

## 3. How I verified it(命令 + 结果)

1. `--headless --check-only --script src/core/game_controller.gd` → **EXIT=0**(无 error/warning,守 warning-as-error)。
2. 全套 `GdUnitCmdTool -a res://test` → **117/117、0 errors/0 failures/0 orphans、exit 0、18/18 套**(116 基线 + 1 新测)。
3. **可证伪自检**:临时撤掉补丁(续战游标不修正)单跑 `game_controller_test.gd` → 新测 `test_reboot_after_boss_resumes_past_boss_not_refight` **FAILED**(续战落在 `(0, BOSS)`,`cur_scene` 断言不等于 0);恢复补丁后全套重绿 **117/117**。证明该测真守这条 bug,非假绿。

## 4. Deviations from the plan(偏差)

- **无。** 严格按 F-SaveBoss flag 推荐的最小修法(改续战读取、不动存档格式 / 不动 progression FSM)。未扩范围、无 drive-by。
- 一点实现取舍记录:回归测用**独立新增** `_two_quick_stages()`(没去重构现有单关 `_quick_stages()`),守 hard-NO "不顺手重构" + project-context "先 3 行重复别过度设计"。

## 5. Wiring Contract — 给 Engine Integrator 的桥

- **本次无任何新接线点。** 纯逻辑行为修正,改动全在 `GameController._boot` 内部续战游标计算。
- **无**新 `class_name`、**无**新 `@export`/Inspector 字段、**无**新信号、**无**新 autoload / input-map / group / collision 依赖。
- 现有 autoload 表(`Player`↑ + `Game`↓)、场景接线、`floating_shell.tscn` 的 `CombatView`/`stages` 指派**均无需改动**。
- **EI/人验收方式**:重跑 §F 手动 Play 的存档 round-trip 子项即可——打通 Boss → 关程序 → 重开,确认**续到已解锁的下一关、不再从 Boss 开打**(roster/装备持久化等其余 §F 子项不受本次影响)。

## 6. Flags / Open questions

- **〔边界·已覆盖非缺陷〕通关最后一关 Boss 后续战落点 = `(stages.size(), 0)`** → `current_enemy_def()` 越界返回 null → Arena 无敌人(= "全部通关、暂无更多内容")。这是修复后的正确表现(优于 bug 态的"永远重打末关 Boss");v1 仅 2 关属预期,日后若要"无尽循环 / 通关结算"是**独立设计决策**,非本修复范围。
- **〔非阻塞·留 Arch Guard〕** 续战语义("Boss 已通据 `max_unlocked_stage` 判别")是 `GameController` 续战契约的一个隐含不变量,ARCHITECTURE.md 未显式记。可在回写 §3.2/不变量时顺手补一句,非本批落地项。
- **无 blocking flag。** 修复达成、可证伪、全套绿,交 Reviewer。
