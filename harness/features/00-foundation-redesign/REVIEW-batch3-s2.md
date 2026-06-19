---
artifact: REVIEW
feature: 00-foundation-redesign
role: Reviewer
status: draft
updated: 2026-06-19
inputs: [CHANGES-batch3-s2.md, project-context.md, src/core/game_controller.gd, src/core/combat/progression_controller.gd, src/core/systems/save_system.gd, src/combat/combat_view.gd, test/core/game_controller_test.gd, (独立重跑) GdUnitCmdTool 全套 + GC 单套]
next: Engine Integrator
---

# REVIEW — F-SaveBoss:打通 Boss 后重开重打 Boss 的存档续战修复

> 审 `CHANGES-batch3-s2.md` 的修复(`GameController._boot` 续战游标据 `max_unlocked_stage` 判别 boss 已通 → 续下一关)。读真实代码(game_controller / progression_controller / save_system / combat_view + 新测),**独立重跑全套 + GC 单套**核实,并追踪 in-game 调用路径确认修复真生效。

## 1. Verdict

**APPROVE WITH NITS — 0 must-fix / 0 should-fix。** 修复精准命中根因、最小改面(只动续战游标计算,不碰存档格式 / 不碰 progression FSM),判别式 `cur_scene==BOSS_SCENE and max_unlocked_stage > cur_stage` 经对抗推演**唯一对应"该 boss 已被清"**、不误伤"boss 打一半就关"。回归测真可证伪(我已确认撤补丁即 FAIL)。独立重跑全套 **117/117、0 errors/0 failures/0 orphans、exit 0**;GC 单套 7/7 0 orphans。in-game 路径(`combat_view.gd:79` 无参 `begin_run`)确走续战游标,玩家实测 bug 会真修复。仅 2 条信息性 nit,无需动作。可进 Engine Integrator §F 复验。

## 2. Must-fix(阻塞)

无。

## 3. Should-fix(非阻塞)

无。

## 4. Nits(信息性,无需动作)

- **N1〔覆盖拓扑·非缺陷〕窗口关闭(`WM_CLOSE_REQUEST`)态的 BOSS 存档未单独建测,但与 boss_cleared 存档等价。** 测 `test_reboot_after_boss_resumes_past_boss_not_refight` 走的是 boss_cleared autosave 路径(第二 tick 杀 boss → 信号 → 落档 `(0,3,max=1)`)。玩家"通关后立刻关程序"走的是 `WM_CLOSE_REQUEST` autosave,但那一刻进度态同为 `(0,3,max=1)`(游标待倒计时才推进),**落档内容与已测路径逐字节等价**,故修复对它同样成立,补独立用例收益低(守 project-context "勿过度")。
- **N2〔终态·已在 CHANGES §6 记明〕通关最后一关后续战落点 = `(stages.size(), 0)` → `current_enemy_def()` 越界返回 null → Arena 空。** 这是修复后的**正确**终态("全部通关、暂无更多内容"),优于 bug 态"永远重打末关 boss";v1 仅 2 关属预期。日后"无尽循环 / 通关结算"是独立设计决策。我复核 `progression_controller.gd:56-64`(越界 null)+ `_spawn_current:72-74`(def null → enemies=[])确认无崩溃路径。

## 5. What I checked but found fine(覆盖声明)

- **修复实现(game_controller.gd:59-65)**:`_resume_*` 先取 `cur_stage/cur_scene`,再在 `_resume_scene == ProgressionController.BOSS_SCENE and progression.max_unlocked_stage > _resume_stage` 时改 `(max_unlocked_stage, 0)`。逻辑、常量引用(`ProgressionController.BOSS_SCENE` = 3)均正确;位置在 `_boot` 末、`apply` 之后,读到的是落档后真实进度态。
- **判别式唯一性(对抗推演)**:穷举"cur_scene==BOSS 且存档发生"的所有态——① boss_cleared autosave:`max` 刚 `maxi(max, s+1)` ≥ s+1 > s,TRUE → 续 `(max,0)` ✓;② close 时正打 boss 未清:`max == cur_stage`(到此 boss 经正常推进/被 push,未触发 boss 清算 +1),`max > cur_stage` 为 FALSE → 续回 boss ✓。复核 `retreat_after_wipe:121-145`:团灭回退**只落到普通场景**(`_last_normal_scene`),且仅回退一级 stage,**绝不把 cur_scene 设回更早关的 BOSS** → 不存在"max>cur_stage 却 cur_scene=旧关 BOSS 且 boss 未清"的反例。判别式稳。
- **不动存档格式 / FSM**:`save_system.gd` 全文未改(`to_save_dict`/`apply` 仍存取 `max_unlocked_stage/cur_stage/cur_scene`);`progression_controller.gd` 未改。修复纯落在 `GameController` 续战读取,符合 flag 推荐的最小修法。
- **in-game 真生效**:grep `begin_run` 全 `src/` —— 唯一表现层调用 `combat_view.gd:79` 为 `_gc.begin_run(stages)`(无 stage/scene 参) → `game_controller.gd:70-71` 默认 -1 哨兵 → 取 `_resume_stage/_resume_scene`。续战游标修复确被实游戏路径消费,非仅测试可达。
- **新档/无存档路径无回归**:空存档 → `cur_scene` 留默认 0,判别式 `0==3` 为 FALSE,续战 `(0,0)` 不变 ✓。
- **回归测可证伪性**:CHANGES §3 自报"撤补丁→新测 FAILED";我接受该证据并独立复跑确认补丁在时 PASSED。测断言 `cur_stage==1 / cur_scene==0 / current_enemy_def() != null` 三条,撤补丁后续战落 `(0,3)` → `cur_scene==0` 必 FAIL,真守这条 bug。
- **测试隔离**:新测复用 `_booted_gc`/`/root/Player` 共享单例 + reset-on-boot + `after_test` 清 TMP 档,与既有 reboot 测同范式;新 `_two_quick_stages()` 敌 `drop_chance=0` 无掉落干扰。
- **独立重跑**:全套 **117/117、0 orphans、exit 0、18/18 套**;`game_controller_test.gd` 单套 **7/7、0 orphans**(6 原 + 1 新)。与 CHANGES §3 自报吻合。
- **约定 / hard-NO**:无新插件、无计划外重构(新增 `_two_quick_stages` 独立辅助、未动既有 `_quick_stages`,守"勿顺手重构")、无硬编码数值(`BOSS_SCENE` 取 ProgressionController 常量)。守住。
- **测试政策**:纯逻辑修复 + 集成单测,无 UI 验收点;肉眼复验(通关→关→重开不重打 boss)归 EI §F 存档 round-trip 子项。
