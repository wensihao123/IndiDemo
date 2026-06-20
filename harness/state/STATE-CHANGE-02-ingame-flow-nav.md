---
artifact: STATE-CHANGE
feature: 10-ingame-flow-nav
role: State Machine Master
status: draft
updated: 2026-06-20
inputs: [STATE-MACHINES.md, ARCHITECTURE.md, UX-MAP.md, harness/ux/UX-CHANGE-02-ingame-flow-nav.md, BACKLOG.md, project-context.md, src/shell/game_flow.gd, src/combat/town_view.gd, src/combat/combat_view.gd, src/core/combat/progression_controller.gd, src/core/combat/combat_arena.gd, src/core/game_controller.gd, src/core/systems/loot_intake.gd, harness/features/10-ingame-flow-nav/HANDOFF.md]
next: Planner
---

# STATE-CHANGE-02 · 游戏内板块流程收编(EXPLORE↔TOWN 进 GameFlow · 落点城镇 · 待回城标记)

> 承 UX-CHANGE-02(城镇为家·枢纽 + 四子板块)。把 UX 画的"城镇(家)↔ 探索(派出挂机)"落成 **M2 `GameFlow.Flow`**
> 的转移:收编进出城、反转落点、加「待回城」延迟返城。**核心结论:不新增 Flow 状态**——五态
> `{BOOT,TITLE,EXPLORE,TOWN,MENU_OVERLAY}` 不变,只**搬两条边进 owner + 翻落点 + 加一个延迟寄存器 + 一个波界结算信号**。

## 1. 触发 / Trigger
UX-CHANGE-02 要把 探索/城镇 的切换从 `TownView` 自管收进 GameFlow 单一发起点、落点由"探索 running"改为"城镇暂停"、
出征板块按选关 `begin_run` 派出、战斗中点回城**不打断**而是设标记到本波结算才返城。这些都是 **M2 流程机的动态行为**(转移/守卫/寄存器),属本角色。

## 2. 现状诊断 / Diagnosis
- **EXPLORE↔TOWN 未在 M2 内**(STATE-MACHINES §6.4 残留 / ARCH §6 双发起点债):`town_view.gd:41-59` `_enter_town`/`_leave_town`
  自己调 `Game.pause_run()`/`resume_run()` + 翻自身 `_town_root.visible` + 反查兄弟 `CombatView.visible`。GameFlow 的 `_flow` **从不经过这对切换**——
  `Flow.TOWN` 这个枚举值存在,却**没有任何 GameFlow 转移会进入/离开它**(只有 `_resume_to_source` 在 MENU_OVERLAY 回来时据 `_menu_return_to` 写 `_flow=TOWN`,但那是"回到 TownView 已自管出来的态",非 GameFlow 发起进出城)。
- **落点写死在 `_enter_game`**(`game_flow.gd:51-58`):continue/new_game → `_flow=EXPLORE` + `enter_game_geometry`,**直接落自动战斗**。无"落城镇暂停"路径。
- **无玩家选关**:`begin_run(stages, stage=-1, scene=-1)`(`game_controller.gd:74`)**已支持显式 stage/scene 参数**(默认 <0 取续战游标),但 GameFlow 只用默认值续战,**没有"出征选关"把具体关序喂进去**的转移。
- **回城是硬切、即时**:`_enter_town` 立刻 `pause_run` 冻结当前波——与"波清空才推进"(ARCH 不变量 #12 / STATE §5#2)粒度不一致,中途冻结半场。无"待回城标记 → 本波结算再返城"的延迟机制。
- **无波界结算信号**:M1 `advance_after_wave`(波清空)/`retreat_after_wipe`(团灭)是**直接方法调用**(`combat_arena.gd:143/167`),**不发信号**。GameFlow(表现层,只能监听 signal)**无钩子可挂**"一波刚结算"这个时刻 → 待回城无处触发。
- **根因**:`Flow.TOWN` 是个**有名无路的孤儿态**——枚举有它,但进出它的转移散在 TownView,GameFlow 不发起;且 M1 的"波界结算时刻"从未对外暴露成可监听事件,导致任何"等本波打完再做某事"的流程意图都无处挂。

## 3. 目标形态 / Target machines(delta vs STATE-MACHINES.md §3)

### 3.1 M2 `GameFlow.Flow` — 不加态,改转移 + 加寄存器
**状态集不变**:`enum Flow { BOOT, TITLE, EXPLORE, TOWN, MENU_OVERLAY }`(`Flow.TOWN` 由孤儿态转为有进有出的正式态)。
**新增寄存器**:`_return_pending: bool`(「待回城」标记;仅 EXPLORE 内有意义)——沿用 M1 `_queued:QueuedAction` 的"延迟到结算执行"范式,但归 M2(板块切换是 M2 职责)。单一 setter(回城请求)+ 单一 clearer(结算返城),不入布尔汤。

**转移表 delta**(粗体 = 本案新增/改写;其余沿 STATE-CHANGE-01):

| from | 事件 | 守卫 | to | 动作 |
|------|------|------|----|------|
| TITLE | `on_continue` | `has_save` | **TOWN** | `Game.begin_run(stages)`(续战游标装配,running=true)→ **`Game.pause_run()`** → 显城镇枢纽 + 隐 CombatView;几何 `enter_game_geometry`。**落点由 EXPLORE 改 TOWN(暂停)** |
| TITLE | `on_new_game`(无档/覆盖确认后) | — | **TOWN** | `Game.new_game(stages)`(0-0 装配,running=true)→ **`Game.pause_run()`** → 显城镇枢纽。同上落点反转 |
| **TOWN** | **`on_depart(stage,scene)`(出征→出击)** | **选中关已解锁(`≤max_unlocked_stage`)** | **EXPLORE** | 选同游标 → `Game.resume_run()`;选他关 → `Game.begin_run(stages, stage, scene)`(显式参,重装该关);隐城镇/显 CombatView |
| **EXPLORE** | **`on_request_return`(战斗中点回城)** | **`not _return_pending`** | **EXPLORE(原地)** | **置 `_return_pending=true`**;回城按钮转「已请求回城,本关结束后返回」。**不动 `arena.running`(不打断,守支柱 1)** |
| **EXPLORE** | **`on_request_return`(再点 = 撤销)** | **`_return_pending`** | **EXPLORE(原地)** | `_return_pending=false`;按钮复原(撤销待回城,可选,见 §6 R3) |
| **EXPLORE** | **`wave_boundary_settled`(M1 波界结算)** | **`_return_pending`** | **TOWN** | `_return_pending=false` → **`Game.pause_run()`** → 隐 CombatView/显城镇枢纽 |
| **EXPLORE** | **`wave_boundary_settled`** | **`not _return_pending`** | **EXPLORE** | 无操作(常态:继续挂机) |
| EXPLORE/TOWN | `open_menu(src)` [☰] | — | MENU_OVERLAY | (不变)记来源、enter_menu_geometry、不动 running |
| MENU_OVERLAY | `on_continue`/Esc | — | EXPLORE/TOWN | (不变)`_resume_to_source` 回来源态 |

**删除**:TownView 自管的 `_enter_town`/`_leave_town` 进出城逻辑(pause/resume + 视图显隐)**上移进上表的 GameFlow 转移**;TownView 的「进城」「出城」按钮发起点改为调 GameFlow(进城已无独立入口——落点即城镇;出城 = 出征/出击)。

### 3.2 M1 `ProgressionController` — 加一个中性"波界结算"信号(不加态)
**状态/转移全不变**。仅在**已有的两个波界落点**尾部**各发一次**中性过去式信号:
- `advance_after_wave()` 尾(波清空:推进/补刷/通关倒计时进入后)→ `emit wave_boundary_settled`
- `retreat_after_wipe()` 尾(团灭回退后)→ `emit wave_boundary_settled`

```
signal wave_boundary_settled   # 一个波界刚结算(清空或团灭回退);M1 不知道"待回城",纯报时刻,M2 监听决定做什么
```
M1 **不感知城镇/待回城**(守职责正交:M1 管推进,M2 管板块)。这样"等本波打完再返城"= M2 监听该信号 + 查自己的 `_return_pending`。
> 粒度取 **波界(wave boundary)** 而非"整关":波清空 / 团灭回退都触发,故即便卡关 GRINDING(无尽刷或反复团灭)也能在下一个波界及时返城,不会因卡关永远回不去。**"波 vs 场景 vs 关"的最终粒度是 Game Designer 旋钮**(见 §6 / UX-CHANGE-02 §5),本案默认波界、留 guard 可收紧。

### 3.3 M4 `CombatArena.running` — 不改机制,改耦合时刻
`running` 仍是 tick 唯一闸(不变量 #6)。delta 仅"何时翻":
- 落点:begin_run/new_game 后**立即 `pause_run()`**(running→false),落城镇。
- 出击:`resume_run()`/`begin_run(选关)`(running→true)。
- 待回城:回城请求**不翻 running**(战斗续跑);到 `wave_boundary_settled` 才 `pause_run()`。

### 3.4 城镇四子板块(工匠/小队/酒馆/出征)= 视图内覆盖层,**不是 M2 态**
玩家在四子板块间切换时,M2 `_flow` **恒为 TOWN**(玩家"位置"始终在城镇,子板块是叠加 overlay)。子板块的打开/关闭/Esc 退一级 = **视图层 show/hide**(类比现 `town_view.gd` 的 `_town_root.visible`),**不进 M2 转移表**。故本案不为四子板块新增 Flow 态。
> ⚠ 若四子板块 + 出征关卡列表的数量/层级让"视图内 show/hide"撑不住、需要屏容器/ScreenManager(承 STATE §6.1 / ARCH §6 "ScreenManager 范式仍欠"债),**先转 arch-guard 定结构**,再回来看是否要把子板块升为一台**城镇内 sub-FSM**。本案判定:v1 四子板块(三功能 + 一占位)用视图内 overlay 可承,**暂不升 FSM**。

## 4. 调整策略 / Strategy(依赖序,strategy-level,无代码)
1. **M1 暴露波界结算信号**(前置·最小):`ProgressionController` 加 `wave_boundary_settled`,在 `advance_after_wave`/`retreat_after_wipe` 尾各发一次。纯加信号,不动 M1 状态/转移 → 现有 153 测不受影响(信号无监听者即 no-op)。
2. **GameFlow 收编进出城**:把 `_enter_town`/`_leave_town` 的 pause/resume + 视图显隐逻辑上移为 GameFlow 转移(`on_depart`/落点+待回城返城);TownView 进出城按钮改调 GameFlow。**先验证 GameFlow 横向命令 CombatView/TownView 显隐的归宿**(承 REFACTOR-05 协调器边界)→ 若需新结构先转 arch-guard(§5)。
3. **翻落点**:`_enter_game` 拆成"落城镇暂停"路径:continue/new_game → begin_run/new_game → `pause_run` → 显城镇。`Flow.TOWN` 成为 continue/new_game 的落点。
4. **出征选关转移**:GameFlow 加 `on_depart(stage,scene)`(出征子板块「出击」调),守卫"已解锁",据是否换关走 `resume_run` 或 `begin_run(选关)`。
5. **待回城寄存器 + 返城转移**:GameFlow 加 `_return_pending`,连 `wave_boundary_settled` → 查标记 → `pause_run` 返城。回城按钮态机:`default` ↔ `已请求回城`。
6. **子板块 overlay + Esc 层级**(视图层,交 Planner):TOWN 视图重构为枢纽 + 四 overlay 子板块;Esc 退一级 = 子板块→枢纽(视图内),探索→城镇(= `on_request_return`),城镇枢纽(根)→ `open_menu`。**此步不动 M2 状态集**,但 Esc 路由需与 GameFlow `_unhandled_input` 协调(谁先吃 Esc)。

## 5. 影响面与迁移 / Blast radius & migration
- **是否先动 arch-guard?**
  - **核心流程改(1–5)= 不需要新结构**:全在 GameFlow 现有协调器职责内(REFACTOR-05 已立)+ M1 加一个信号 + 一个 bool 寄存器。不新增模块/数据结构。**SMM 可直接交 Planner。**
  - **条件触发 arch-guard(三项,任一成立则先转)**:① **GameFlow 横向接管 CombatView/TownView 显隐** 若被判定为需统一屏容器/ScreenManager(承 ARCH §6 / STATE §6.1 范式债)而非沿用现 `.visible` 横向调用;② **城镇四子板块** 若超出视图内 overlay 需屏挂载结构;③ **掉落暂存区**(下条)。
  - **掉落暂存区 = arch-guard 专属,且本案 scope OUT**:现 `loot_intake.gd:12-21` + `combat_arena.gd:183-194` 在**敌死瞬间**即写 `PlayerState`(equip/add_material/add_to_bag)。UX-CHANGE-02 §3.4 提的"掉落暂存→结算合并"是**新数据结构(暂存缓冲)+ 写入时机不变量改写**(ARCH 不变量 #4/#11"唯一写入口"),**属 arch-guard,非状态机**;且**待回城/本案不依赖它**(待回城只延迟板块切换,掉落照旧即时入库也能跑)。**故本案不做掉落暂存**,作为独立增强 flag 给 arch-guard,prevent scope 蔓延。
- **STATE-MACHINES.md**:M2 转移表改写(收编 + 落点 + 待回城 + 出征)、加 `_return_pending` 寄存器、M1 加 `wave_boundary_settled` 信号;§6.4 残留**闭合**(EXPLORE↔TOWN 进 GameFlow);§5 不变量 #6 注脚补"待回城延迟 pause 时刻";债 #6(两套停语义)复核但不解。本文 §2/§3 已同步更新为目标态。
- **src 影响**:`src/shell/game_flow.gd`(落点+收编+出征+待回城,主改面)、`src/combat/town_view.gd`(进出城上移、枢纽+四子板块视图重构、按钮改调 GameFlow)、`src/combat/combat_view.gd`(背包→掉落预览、回城按钮 + 已请求回城态)、`src/core/combat/progression_controller.gd`(加 `wave_boundary_settled` 两处 emit)。
- **向后兼容**:M1 加信号无监听者时 no-op,153 测不动;`Flow` 状态集不变,STATE-CHANGE-01 的 Title/设置/覆盖/退出/MENU_OVERLAY/Esc 全保留;`begin_run` 显式参签名已存在(只是新被 GameFlow 用上)。**测试迁移**:进出城原由 TownView 测覆盖,收编后需补 GameFlow 级"落点=TOWN paused""出击=resume/begin_run""回城→待回城→波界结算返城"用例。

## 6. 风险与被否选项 / Risks & rejected alternatives
- **被否·给四子板块各开一个 Flow 态(TOWN_SMITHY/TOWN_PARTY/…)**:会让 M2 从 5 态炸成 9+ 态,且子板块是叠加 overlay 不是流程节点。**判过度建模**——子板块属视图层 show/hide,M2 只认"在不在城镇"。若将来子板块带复杂内部流程,再引**城镇内 sub-FSM**(届时先转 arch-guard),不污染顶层 M2。
- **被否·待回城用即时硬切(保持现状)**:即时 `pause_run` 会中途冻结半波,违 ARCH 不变量 #12 波粒度 + 支柱 1 不打断。故取"标记 + 波界结算返城"。
- **风险 R1(待回城粒度)**:取"波界"=波清空/团灭都触发,卡关也能及时返城;但若团队**连波都清不掉**(每波必团灭前… 实则 `retreat_after_wipe` 本身是团灭后调,也是波界)则下次团灭即返城,无死锁。"波 vs 场景 vs 关"的玩家心智(回城要等多久)= **Game Designer 旋钮**,本案默认波界、留 guard 可收紧。
- **风险 R2(收编爆炸半径)**:把 EXPLORE↔TOWN 显隐收进 GameFlow 会动 REFACTOR-05 刚立的协调器边界(横向命令两视图)。沿用 09 "协调器横向调公开 API"模式可控;**若被判定要统一屏容器/ScreenManager 则先转 arch-guard**(§5),勿在 Planner 层硬塞。
- **风险 R3(待回城可撤销?)**:§3.1 给了"再点撤销"转移(可选)。若 Game Designer 认为"出征即承诺、不可撤"则删该行——纯 UX/设计旋钮,SMM 两种都支持。
- **风险 R4(Esc 双吃)**:子板块 overlay 的 Esc(退枢纽,视图层)与 GameFlow `_unhandled_input` 的 Esc(MENU_OVERLAY=继续)可能争抢。需定优先级:**子板块开着时 Esc 先关子板块**(视图先吃、`set_input_as_handled`),无子板块时 Esc 才到 GameFlow。交 Planner 落协调,SMM 标明此约束。

## 7. 交接 / Handoff
- **下一棒 = Planner**:开 `/role-planner 10-ingame-flow-nav`,喂本 `STATE-CHANGE-02` + `UX-CHANGE-02`,把以下排成有序可验证步骤:
  ① M1 加 `wave_boundary_settled`(两处 emit);② GameFlow 收编进出城 + 翻落点(continue/new_game→TOWN paused);
  ③ `on_depart(stage,scene)` 出征选关转移;④ `_return_pending` + 待回城返城转移 + 回城按钮态;⑤ TownView 枢纽+四子板块视图重构 + Esc 层级协调;⑥ 补 GameFlow 级测试。
- **条件转 Arch Guard(Planner 投入前判定)**:若 ②(GameFlow 接管两视图显隐)需统一屏容器/ScreenManager、或 ⑤ 四子板块超出视图内 overlay → **先 `/arch-guard 10-ingame-flow-nav`** 定结构(承 REFACTOR-05 协调器边界 / ARCH §6 范式债),再回 Planner。
- **独立 flag Arch Guard(不阻塞本案)**:**掉落暂存区 + 结算唯一写入口**(新缓冲结构 + 写入时机不变量 #4/#11)——UX-CHANGE-02 §3.4 提的状态分层增强,**本案 scope OUT**,若要做单独走 arch。
- **flag Game Designer**:① 待回城粒度(波/场景/关 + 是否可撤销 R3);② 出征"选关"是否改挂机推关心智;③ 城镇暂停态挂机进度可见性(支柱 1 缓解)。
- **flag Producer**:酒馆招募仅接壳(Later);城镇四子板块 + 出征是否需再切片。
- **回写**:STATE-MACHINES.md 已更新目标态(M2 转移 + `_return_pending` + M1 `wave_boundary_settled` + §6.4 闭合);UX-MAP.md 与 UX-CHANGE-02 由 ux-design 维护、本案与其一致。
