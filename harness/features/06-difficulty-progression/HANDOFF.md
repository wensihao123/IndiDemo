---
feature: 06-difficulty-progression
status: done
updated: 2026-06-20 (frontmatter 状态校正:06 已收口,见 BACKLOG Done/Decision log 2026-06-20)
---
# HANDOFF — 06 难度推进:撞墙 → 变强 → 冲过(v1 闭环收口)

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。

## 一句话
v1 垂直切片的**收口件**:把"刷(02/04)→ 调(05)→ 再挑战"闭合。**不造新系统**,而是把地基现有进度骨架
(团灭回退 / 卡关 GRINDING / 推进 / Boss 永久解锁)点亮成一堵**玩家能感受到的墙**:撞墙自动软退安全刷(不慌)、
回城变强、点推进冲过 = 高光兑现。体感取向已与用户拍板:**混合·软底+主动冲**。

## 依赖(前置)
- **进度骨架已在地基**:`ProgressionController`(`PROGRESSING/GRINDING/STAGE_CLEAR_COUNTDOWN/RESTING` 四态、
  `retreat_after_wipe` 团灭软退、`request_push` 主动再战、Boss 永久解锁不回退)+ 关1/关2 两关 .tres 已存在。
- **04 / 05 / 08 已全部 done**:看得见变强(04)+ 回城换装·强化(05)+ 团战多敌(08)—— 闭环的"刷"与"调"齐了,06 造"再挑战值不值"。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | **draft(2026-06-20)** — 体感 = 混合·软底+主动冲(用户拍板)。复用现有进度骨架,不造新系统。幻想 = "撞墙不慌→变强→冲过的踏实兑现"。最小版 = 一堵真墙(关2 入口/Boss)+ 卡关可读 + 突破高光,全用现有关1/关2 + GRINDING/推进。**命门 flag:墙的具体数值押 num-smith**(关1顶配 AFK 过不去、回城变强能过)。守 LESS(难度曲线机器/动态难度/新区域/新 Boss 机制 → v2) |
| 数值 | Num Smith | balance/BALANCE-CHANGE-04-difficulty-progression.md | **draft(2026-06-20)** — 墙定在**关2 Boss 兽人酋长**:`max_hp 220→480`、`attack 9→24`。诊断 = 墙在数值上不存在(关2 整条功率带坐在关1-通关玩家之下)。校验:P1-baseline 硬过不去、P1-topped 约差 17%、P2(回城吃关2 掉落+强化)能过留安全垫 → 兑现 i6 不变量。纯值微调(2 个 .tres 字段),Implementer 可直接落;但 06 整体需 Planner 编排(墙后 v1 终点呈现 + 卡关可读/突破庆祝)。|
| 计划 | Planner | PLAN.md | **draft(2026-06-20)** — 三步依赖序:① 立墙(改 `stage_02.tres` BossOrcChieftain `max_hp 220→480`/`attack 9→24`,纯数据)② 收口末关边界(`ProgressionController.advance_after_wave` Boss 分流 + `begin_run` 越界夹防呆 —— 修打通末关掉空场/越界续战的既存 bug,复用 FSM 不加新态;`max_unlocked` 记账不动守现有测试)③ 三处占位呈现(`combat_view` 卡关可读/回城邀请/末关里程碑庆祝,纯只读表现)。步1-2 纯逻辑 gdUnit4、步3 手动 Play。4 key decisions + 5 flags |
| 实现 | Implementer | CHANGES.md | **draft(2026-06-20)** — PLAN 三步全落:① 立墙(`stage_02.tres` Boss `max_hp 220→480`/`attack 9→24` + 锁值用例)② 收口末关边界(`progression_controller.gd` 末关分流 + `begin_run` 越界夹 + 2 条新用例)③ 三处占位呈现(`combat_view.gd` 卡关可读/回城邀请/末关庆祝)。**全量 gdUnit4 152/152 绿、`--check-only` EXIT=0**。Wiring Contract = 无新接线(改动落已接线脚本内部)。剩:🔴 手动 Play 表现层验收(清单见 CHANGES §6)。|
| 审查 | Reviewer | REVIEW.md | **APPROVE WITH NITS(2026-06-20)** — 决策 B/C 对不变量 #9 末关边界的补全经手追全:末关 Boss 循环正确、`max_unlocked` 记账零改动;逐字核 `reports/report_38/results.xml`「152/0」属实。无 must-fix。2 条 should-fix(均非阻塞、不挡合入):① `combat_view.gd:547` 回城邀请行布局压住小队栏 → 削弱"卡关可读",归手动 Play + UI·juice 轮调坐标;② 末关续战全链路(`_boot` #9→`begin_run` 夹)缺 GameController 级集成测试(单测已覆盖夹值)。 |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | — (卡关可读/突破庆祝/回城邀请并入全局 UI·juice 统一轮) |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | **无接线(2026-06-20)** — Wiring Contract 已确认无新接线;**手动 Play 表现层验收经手通过**(CHANGES §6 四项:撞墙软退 / 卡关可读 + 回城邀请 / 回城变强冲过 / 末关庆祝 + 终点循环不空场,均 OK)。REVIEW should-fix① 布局担忧在实际游玩不成立 → 关闭。 |

> 状态取值:`—`(未开始) / `draft` / `accepted` / `blocked` / `superseded`

## 下一步
**✅ 2026-06-20 — Game Designer 落 FEATURE-DESIGN(draft)。** 体感取向经用户拍板 = 混合·软底+主动冲;
功能定位 = v1 闭环收口、复用进度骨架不造新系统;幻想/循环/规则/反馈/成功标准/最小版/flag 七节齐。

**✅ 2026-06-20 — Num Smith 落 BALANCE-CHANGE-04(draft)。** 墙定在**关2 Boss 兽人酋长**:`max_hp 220→480`、
`attack 9→24`(纯值微调,2 个 .tres 字段)。诊断 = 墙在数值上不存在(关2 功率带在关1-通关玩家之下);
校验 P1 过不去 / P2 回城变强能过,兑现 i6 单调闸门。BALANCE.md §3f/§6 已同步到目标形态。

**✅ 2026-06-20 — Planner 落 PLAN(draft)。** 三步依赖序定档:立墙(数据)→ 收口末关边界(逻辑)→ 三处占位呈现(表现)。
关键诊断:打通末关 Boss 现状会 `_execute_push` 把 `cur_stage` 推到 `stages.size()` 越界 → 空场,且不变量 #9 续战会
把游标设成 `max_unlocked=末关+1`(越界)—— 二者均为既存 bug,06 一并收口(复用 FSM 终点循环重刷末关 Boss,不加新态、
不动 `max_unlocked` 记账以守现有测试 `:76/:92/:98`)。

**✅ 2026-06-20 — Implementer 落 CHANGES(draft)。** PLAN 三步全落、代码已进 `src/` + 两关数据:
- 步1 数据:`stage_02.tres` Boss `max_hp 220→480` / `attack 9→24` + `stage_config_test.gd` 锁值用例。
- 步2 逻辑:`progression_controller.gd` 末关 Boss 分支 `has_next` 分流(末关→指回本关 Boss 循环)+ `begin_run` 越界游标夹回末关 Boss;新增 2 条边界用例。`max_unlocked` 记账语义不动。
- 步3 表现:`combat_view.gd` 卡关可读文案 + GRINDING 回城邀请行 + 末关里程碑占位庆祝(`_milestone_flash`)。
- **验证:全量 gdUnit4 152/152 绿(0 err/0 fail/0 orphan)、`--check-only` EXIT=0。** 手动 Play 待人验收。

**✅ 2026-06-20 — Reviewer 落 REVIEW(APPROVE WITH NITS)。** 决策 B/C 对不变量 #9 末关边界的补全经手追全:
末关 Boss 循环正确(`current_enemy_def()!=null` 不空场)、`max_unlocked` 记账语义零改动(现有 `:76/:92/:98` 全绿)。
逐字核 `reports/report_38/results.xml` =「152 tests / 0 failures」,确认 CHANGES「152/152」属实(本机未重跑:`runtest.cmd` 不在仓库根、godot 未在 PATH)。
**无 must-fix。** 2 条 should-fix(非阻塞):① `combat_view.gd:547` 回城邀请行与小队栏布局重叠 → 直接削弱本功能"卡关可读"成功标准,坐标级改动、归手动 Play 校准 + 全局 UI·juice 轮;② 末关续战全链路缺 GameController 级集成测试(夹值已单测覆盖,链路无端到端网)。

**✅ 2026-06-20 — 手动 Play 表现层验收通过(归人)。** CHANGES §6 四项全 OK:撞墙软退、卡关可读 + 回城邀请行(布局无冲突,REVIEW should-fix① 关闭)、回城变强冲过、末关庆祝 + 终点循环不空场。**06 功能验收完成。**

**功能状态:✅ DONE(代码已审、152/152 绿、手动 Play 验收通过)。** 06 = v1 垂直切片**收口件**,至此「刷(02/04)→ 调(05)→ 再挑战(06)」闭环闭合。

**遗留(均不阻塞,记 backlog 即可):**
- **🟡 should-fix②(可选,Implementer):** 补一条单关末关存档往返集成测试,给不变量 #9 末关边界拉端到端回归网。逻辑已对(夹值已单测覆盖),纯补网。
- **🟡 关2 团战铺波(用户 2026-06-20 拍板的独立后续任务):** structure 已在 08 就绪,待办 = author `stage_02.tres` 多敌波 + num-smith 定波数值。建议 `/role-producer` 记 backlog。
- **🟡 playtest 主观校准:** 墙准度依赖词缀 roll 方差(关1 顶配 AFK 是否确实卡死 / 回城变强是否"踏实"过)→ 旋钮见 BALANCE-CHANGE-04 §6,落值后交 playtest,不预先再调。

**建议下一棒:`/role-producer`** —— 把上述遗留记进 BACKLOG,并据 v1 完成定义核对闭环是否全绿、可否收 v1 垂直切片。

**并行/之后:🟡 手动 Play 表现层验收(归人 / Engine Integrator)** —— 清单见 `CHANGES.md §6`:撞墙软退 / 卡关可读 + 回城邀请 / 回城变强冲过 / 末关庆祝 + 终点循环不空场。表现层精修归全局 UI·juice 统一轮。

**再之后**:关2 团战铺波(用户 2026-06-20 拍板单列的独立后续任务)→ `/role-producer` 记 backlog,再走 num-smith 定波数值 + author `stage_02.tres` 多敌波。

**playtest 校准点(过墙后主观裁定)**:关1 顶配纯 AFK 是否确实卡死 / 回城变强后是否"踏实"过(非压线非空过)/
软退安全刷是否无惩罚感 / 突破庆祝是否够重(BALANCE-CHANGE-04 §6 风险:墙准度依赖词缀 roll 方差,太松抬 atk、太硬降 atk 再降 hp)。

## 决策记录
- **2026-06-20 — [用户拍板] 卡关体感 = 混合·软底+主动冲。** 默认软墙(团灭自动软退安全刷、进度不丢、装备照掉 = 支柱 1 陪伴不打断),
  把"再挑战"做成玩家明确的主动动作(点推进 = "我觉得我变强了,冲一次")= 支柱 2 能动性。复用现有 GRINDING + request_push 骨架。来源:用户(AskUserQuestion)。
- **2026-06-20 — [GD 守 LESS] 06 不造难度机器。** 用现有关1/关2 + 现有进度骨架点亮"一堵真墙",不做难度曲线精调/动态难度/多区域/新 Boss 机制(留 v2)。来源:Producer BACKLOG 守门 + GD self-cut。
- **2026-06-20 — [Planner 收口末关边界] 打通末关 = 终点关 Boss 循环陪伴,非推进出界。** `advance_after_wave` Boss 分支按"有无下一关"分流:末关 → `advance_target` 指回 `(末关, BOSS)` 循环重刷 + `begin_run` 加越界夹补不变量 #9 末关边界。复用 FSM 不加新态,`max_unlocked` 记账不动(守现有测试)。否决独立 `V1_CLEARED` 终态(动 FSM,留 v2)。来源:PLAN 决策 B/C(修既存越界 bug + FEATURE-DESIGN §3.3 边界态④)。
- **2026-06-20 — [num-smith 定墙] 墙落关2 Boss、非关2 入口。** 抬 `BossOrcChieftain` hp220→480 / atk9→24(纯值微调)。否关2 入口:入口即墙会把关2 中段练级带锁死(鸡生蛋,玩家没素材变强);墙落 Boss 则关2 普通场景成"够墙的练级带"。两维同抬 = DPS+EHP 双门槛,P2 全面变强才过。来源:BALANCE-CHANGE-04 §2/§3/§6。
- **2026-06-20 — [GD 留 num-smith] 墙的数字不在设计里硬定。** 设计只给"墙的不变量"(关1顶配 AFK 过不去、回城变强能过),具体落档/增量交 num-smith。来源:GD escalation(数值归 num-smith)。
- **2026-06-20 — [用户拍板] 06 先收口、关2 团战铺波单列下一棒。** 用户试玩发现关2 从入口起又是 1v1 车轮(08 只把多敌波 author 进了关1,关2 .tres 仍单敌波)。决策:06 不扩范围、按现 PLAN 最快闭环(墙+终点+呈现);关2 团战铺波作为 06 之后的**独立后续任务**(structure 已在 08 就绪,待办 = author `stage_02.tres` 多敌波 + num-smith 定波数值),06 闭环后 `/role-producer` 记 backlog。来源:用户(AskUserQuestion)。PLAN §4 已标。
