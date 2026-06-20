---
artifact: REVIEW
feature: 10-ingame-flow-nav
role: Reviewer
status: draft
updated: 2026-06-20
inputs: [CHANGES.md, PLAN.md, harness/state/STATE-CHANGE-02-ingame-flow-nav.md, src/shell/game_flow.gd, src/combat/town_view.gd, src/combat/combat_view.gd, src/core/combat/progression_controller.gd, src/core/combat/combat_arena.gd, src/core/game_controller.gd, test/core/combat/wave_boundary_settled_test.gd]
next: Engine Integrator
---

# REVIEW · 10-ingame-flow-nav(游戏内板块流程收编 + 城镇枢纽落点 + 待回城)

评审对象 = CHANGES.md 落地的 PLAN 八步(实现 STATE-CHANGE-02 / UX-CHANGE-02)。逐文件读真码核对,
不重写代码,只判对错 + 指出须改项。**自动验证已绿**(headless import 0 Parse、gdUnit4 158 cases/0 fail),
表现层属手验范畴,留 EI 跑 CHANGES §6。

## 1. Verdict(结论)
**Approve(通过,可转 Engine Integrator)。** 实现忠实落地 PLAN 八步与七项决策(D1–D7),
四轴(正确性 / 忠实度 / 过度设计 / 约定)均无阻断问题。三处偏差(CHANGES §4)我逐一核过,
**都在范围内且合理**——其中「Esc 集中 GameFlow」走的是 PLAN R4 明示退路,论证(树末节点最先收 Esc、
免抢吃)成立,我认为优于原主路,接受。**无 Must-fix。** 下列 Should-fix / Nits 均非阻断,
EI 手验或后续块处理即可。

核验过的关键不变量(均成立):
- **单一发起点**(§6.4 / ARCH §6 双发起点债):进出城决策全收进 GameFlow,TownView 退为纯视图
  (`show_town`/`show_combat` 不碰 `running`,town_view.gd:55-67),`pause_run`/`resume_run` 调用上移
  GameFlow `_enter_town_hub`(game_flow.gd:57-68)。死码 `_enter_game`/`_reconcile_views_to_combat`/
  `reset_to_combat`/`_enter_town`/`_leave_town` 全删,全 src/test 无悬挂调用(grep 0 命中)。债已闭。
- **待回城守支柱 1 / 不变量 #12**:`on_request_return` 仅切标记不碰 running(game_flow.gd:176-179);
  实际返城在波界信号后 `call_deferred`(:187-194),战斗不被打断。
- **越权防护**:`on_depart` 守 `stage > max_unlocked_stage → return`(:159-160),且 TownView 关卡钮
  `disabled = not unlocked` 并仅 unlocked 才接 `pressed`(town_view.gd:273-276)——防御纵深双层。
- **信号连接时机**:`Game`(autoload)`_ready → _boot` 先建 `progression`(game_controller.gd:29/35/51),
  早于场景节点 GameFlow `_ready`(:35-37 连接),且 `progression` 仅 _boot 建一次、begin_run 复用 →
  连接持久有效。Wiring Contract 此项属实。
- **包裹法只发一次**:`advance_after_wave`/`retreat_after_wipe` 各 = impl + emit(progression_controller.gd
  :121-123/171-173);CombatArena 是唯一调用方,advance 调完即 `return`(combat_arena.gd:142-144),
  wipe 在 tick 末(:166-167)→ 单 tick 至多发一次,无双发。

## 2. Must-fix(阻断,必须改后才能继续)
**无。**

## 3. Should-fix(建议改,非阻断;可本块收尾或滚下游)
- **S1 · `on_depart` 的 prog==null 分支绕过越权守卫(game_flow.gd:156-164)。** 守卫写作
  `if prog != null and stage > prog.max_unlocked_stage: return`——当 `prog == null` 时,守卫被整体短路,
  仍会落到 `begin_run(stages, stage, scene)` 用**任意** stage 开局,越权检查失效。当前 `progression`
  post-boot 永不为 null(已核),故是**理论缺口非现实 bug**;但既然上面 `if _gc == null: return` 已挡 _gc,
  这里把 prog 缺失也视作"不可出征"更稳:建议改为 `if prog == null: return` 在前,或 `stage >= 0 and
  (prog == null or stage > prog.max_unlocked_stage)`。一行,EI 前可顺手;不改也不阻断(不可达)。

- **S2 · 出征关卡列表的 `stages` 双源耦合(town_view.gd:257 `prog.stages` vs game_flow.gd:164
  `begin_run(stages,…)` 用 GameFlow `@export stages`)。** TownView 用 `prog.stages` 建钮与算 unlocked,
  GameFlow 出击用自己的 `stages`。二者当前是**同一 Array**(begin_run 时 GameFlow 把自己的 stages 存入
  prog),故索引对齐、无 bug。但这是隐式不变量:若将来某路径让两者发散,关卡钮 index 会错位到别的关。
  建议要么在 `on_depart` 内也按 `prog.stages` 取关、要么留一行注释钉死"GameFlow.stages 即 prog.stages"
  这条不变量。非阻断,记为债。

## 4. Nits(可选,纯改善)
- **N1 · 待回城可能被「菜单开着的那一波」跳过(game_flow.gd:188 `_flow == Flow.EXPLORE` 守卫)。**
  EXPLORE 中按 [☰] 进 MENU_OVERLAY 时 sim 不暂停(开菜单不停战,combat_view.gd:587 注),若恰在
  MENU_OVERLAY 态有一波结算,`_on_wave_boundary_settled` 因 flow≠EXPLORE 不触发,`_return_pending`
  保留,要等回到 EXPLORE 后**下一波**才返城。即"待回城最多被一波延迟"。守支柱 1 的取舍下这是
  可接受甚至更稳的行为,无须改,仅记录供 EI 手验时心里有数。
- **N2 · `_enter_town_hub` 前会先 `begin_run`/`new_game` 置 running=真,再立刻 `pause_run`
  (game_flow.gd:78-80 / 91-94 → 57-68)。** 同帧一开一停,净效果 = 不跑战斗(CombatView `_process`
  下帧才 tick,且彼时已 paused),正确但有一次冗余 spawn/start_battle。可读性 > 微优化,保留即可。
- **N3 · 回城钮坐标硬编码 `Vector2(660,44)`(combat_view.gd:595)、出征钮字号等占位排布。**
  符合本项目"UI/juice 推迟到功能做完后统一一轮"约定(占位即可),非本块问题;并入全局 UI 轮交 Art Spec。

## 5. What I checked but found fine(已查并确认无虞)
- **纯视图切换正确性**:`show_town` 显本视图 + 隐兄弟 CombatView(`get_parent().get_node_or_null
  ("CombatView")`,town_view.gd:48/57-58)+ `_show_board(HUB)` 复位 + `_refresh`;`show_combat` 反向。
  从战斗返城**总落 HUB**(不残留旧子板块 overlay)——`_show_board(HUB)` 把四 overlay 全置不可见
  (:72-78)。正确。
- **Esc 分层裁决**(game_flow.gd:199-224):子屏(设置/覆盖/退出)→ 退回主菜单;MENU_OVERLAY → 继续;
  TOWN → 子板块开则 `close_overlay_to_hub` 否则 `open_menu(TOWN)`。GameFlow 为 floating_shell 末子节点,
  `_unhandled_input` 逆树序最先收 Esc,集中裁决无抢吃。R4 退路落地正确。
- **回城钮文案切换**(combat_view.gd:237-255):`_process` 仅 `visible`(即 EXPLORE)时跑
  `_update_progress_and_buttons`,据 `gf.is_return_pending()` 切"回城 / 已请求回城·本波后返";
  返城后 CombatView 隐藏、下次出征 `_return_pending` 已被 `on_depart` 复位(:169)→ 无残留文案。正确。
- **`on_request_return` 撤销(R3/F-R3)**:`_return_pending = not _return_pending`(:179)实现"再点撤销";
  若 GD 定不可撤,删该切换即可(CHANGES §7 已挂 flag)。当前实现与 PLAN 一致。
- **D5 延迟返城重入安全**:信号在 Arena.tick 内同步发,handler 只 `call_deferred`,真正
  `_enter_town_hub`(pause+换视图)落到 idle 帧;期间无用户输入可改 flow,deferred 跑时 flow 仍 EXPLORE,
  且 `_enter_town_hub` 无条件强制 TOWN。R5"≤1 tick 过冲"已 PLAN 接受。
- **新增单测**(wave_boundary_settled_test.gd):2 用例(波清空推进 / 团灭回退)各断言信号发恰 1 次 +
  推进/回退语义未被包裹改变,构造合理(auto_free、最小 stage/arena)。旧 158 套零回退。
- **死码清理**:`_enter_game`/`_reconcile_views_to_combat`/`reset_to_combat`/`_enter_town`/`_leave_town`
  全 src 无定义无调用;test 仅剩 `gc.pause_run/resume_run`(GameController 仍保留,未删)——属正常。
- **无新依赖、无 .tscn/.tres/资源导入改动、无硬编码平衡参/路径**:符合 project-context §4 硬性 NO。
  跨层取 GameFlow 一律走 group `game_flow`(无写死路径),与既有 REFACTOR-05 协调器模式一致。
- **Wiring Contract**(CHANGES §5)与真码一致:节点/group 均既存,唯一运行时连接
  `progression.wave_boundary_settled → _on_wave_boundary_settled` 时机成立(见 §1)。

## 交接 / Handoff
转 **Engine Integrator**(本块无接线/资源改动,主跑表现层手验):重点按 CHANGES §6 在编辑器 Play 走全链路
——落城镇暂停 → 出征选关出击 → 探索挂机 → 回城待结算返城 → 换装/强化再出击 —— 并特别留意
**N1(菜单开着那一波的待回城延迟)**与 **S1/S2** 是否在实机暴露。S1/S2 建议本块或下游顺手修;均非阻断。
