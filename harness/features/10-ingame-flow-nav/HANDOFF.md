# HANDOFF · 10-ingame-flow-nav

> 每个功能的单一事实来源(管线状态 + 下一步)。每个 role 干完更新它。

## 一句话
把**游戏内**各板块(探索 / 城镇 / 背包)从各自为政的隐式可见性切换,统一纳入 09 立起的顶层 `GameFlow`:
定**新游戏落点**、把三板块做成 GameFlow 统一的"屏/板块"、把**板块之间切换的逻辑**显式化,清掉
STATE-MACHINES §6 残留的 EXPLORE↔TOWN 隐式状态债。是 V2「整套交互流程重构」的第二块(承 09)。

## 范围(Producer 2026-06-20 拍板)
**IN —— 整个游戏内流程结构:**
- ① **新游戏落点** —— 新游戏 / 继续后,玩家进哪个板块(待 UX/SMM 与用户敲定细则)。
- ② **探索 / 城镇 / 背包纳入 GameFlow 统一导航** —— 不再靠 `town_root.visible`、临时只读面板各自为政。
- ③ **板块之间切换逻辑显式化** —— 谁能到谁、切换时挂机暂停与否(守支柱 1:仅 Town 暂停)、回主菜单/暂停的接入点;清 §6 隐式状态债。
- 占位内容即可;UI 皮/juice 不在本块。

**OUT(守一次一件,留后续块 / Later):**
- 设置·暂停**屏内容实装**(09 只搭壳);存档管理 / 多档;招募 / 多职业 / 技能树 / 离线;UI·juice 上皮。

**⚠ 细则继续讨论**:新游戏落点、各板块切换规则属**设计层**,Producer 不代为设计 —— 交 UX-design / SMM 与用户敲定。

## 设计拍板(用户 2026-06-20)
- **拓扑 = B 城镇为家**:城镇 = 家/基地,探索 = "派出去挂机"。
- **落点 = 方式 3**:**新游戏 + 继续都落城镇,且城镇保持暂停**;点「出击」才开打。**有意接受支柱 1"启动即陪伴"让位**(UX 已挑明,见 UX-CHANGE-02 §3.2)。
- **背包拆解**:探索内 →**掉落预览**(只读·掉落装备+材料·不暂停);城镇内 → 并入**小队换装 + 工匠(打造/升级)**(同屏显装备+材料)。
- **顶层游戏内板块** = 城镇 ↔ 探索两块;EXPLORE↔TOWN 收进 GameFlow;Esc 推广到游戏内板块。
- **(2026-06-20 refine·用户 Game-flow-ideas.md + 截图)城镇升枢纽 + 四覆盖式子板块**:工匠(分解/强化/制作)/ 小队(队员·换装)/ 酒馆(占位)/ 出征(关卡选择→出击)。**新增「待回城」标记**:战斗中点回城不打断,本关结算后再返城(同向不变量 #12 + 支柱 1)。**状态三层多数已由四层地基承载,不重造**(真 delta = 掉落暂存 + 待回城标记)。

## 管线状态
- [x] **Producer**(2026-06-20)— 切出本 feature、定范围(IN/OUT 见上)、写进 `BACKLOG.md`(Now 第二块 + 决策日志)。
- [x] **UX Design**(2026-06-20,后 refine)— 产 `harness/ux/UX-CHANGE-02-ingame-flow-nav.md`(draft);**已按用户 `Game-flow-ideas.md` + 截图重做**:城镇升枢纽 + 四子板块、出征选关、待回城标记;UX-MAP.md / INDEX.md 同步更新。
- [x] **State Machine Master**(2026-06-20)— 产 `harness/state/STATE-CHANGE-02-ingame-flow-nav.md`(draft):把 EXPLORE↔TOWN 进出城收进 GameFlow(关 §6.4 残留 / ARCH §6 双发起点债)、落点改 TOWN 枢纽(暂停)、加「出征(选关)→出击 `on_depart`」与「待回城 `_return_pending` + `wave_boundary_settled` 结算返城」转移。**结论:不新增 Flow 态**(delta = 2 边迁入 + 落点翻转 + `_return_pending` 寄存器 + M1 新信号 `wave_boundary_settled`);四子板块 = 视图内 overlay,非 M2 态。掉落暂存 = 数据结构 + 写时机,**scope OUT 转 arch-guard**(待回城不依赖它)。STATE-MACHINES.md 已同步标 `[SC-02 计划]` 目标态。
- [ ] **Arch Guard**(条件触发,SMM 已点名)— SC-02 明确两处可能要结构:① **掉落暂存**(探索内只读掉落预览所需的暂存数据结构 + `LootIntake` 即时写 PlayerState 的写时机改造)= 数据层事,SMM scope OUT 交此;② 若四子板块/屏数膨胀要 ScreenManager 或子板块容器,定归宿(`ARCHITECTURE.md` §6 双发起点债将随 SC-02 落码关闭,承 REFACTOR-05 协调器边界)。**①若本期要掉落预览则先转;否则 Planner 可不阻塞先落导航主体。**
- [ ] **Game Designer**(flag)— ① 工匠·分解/制作是否超出现有强化(打造=造新装?)② **出征"选关"是否改变挂机推关心智** ③ 城镇暂停态挂机进度可见性(支柱 1 缓解)④ 待回城结算粒度(波 vs 关)。
- [ ] **Producer**(flag)— ① 酒馆招募 = 已 scoped Later,本案只接壳不实装;② 城镇四子板块 + 出征选关是否需再切片。
- [x] **Planner**(2026-06-20)— 产 `PLAN.md`(draft):落成 STATE-CHANGE-02 目标态。**8 步有序落地** + 7 项关键决策(D1 `wave_boundary_settled` 用「包裹法」=抽 `_advance/_retreat_impl()` + 公开法 emit,CombatArena 调用名不变;D2 GameFlow 主「何时」、TownView 收为纯视图 `show_town()/show_combat()` 主「如何」,关 §6.4 / ARCH §6 双发起点债、**不引 ScreenManager**;D3 落点反转 = 新 `_enter_town_hub()`〔pause_run + show_town + `_flow=TOWN`〕;D4 `on_depart(stage,scene)` 守 `stage<=max_unlocked_stage`;D5 `_return_pending:bool` + `call_deferred` 避免 tick 内重入〔受 ≤1 tick overrun,R5〕;D6 城镇枢纽 = 入口钮 + 四 `.visible` overlay〔小队/工匠复用、出征新增、酒馆占位〕,无子板块 Flow 态;D7 测试分层 = M1 信号 gdUnit4 / GameFlow·TownView 手测)。**结论:本期不需先转 arch-guard**(GameFlow 指挥 TownView/CombatView 可见性 = 延续 REFACTOR-05 协调器模式调公开 API,无新结构;掉落暂存仍 scope OUT)。
- [x] **Implementer**(2026-06-20)— 产 `CHANGES.md`(draft)。落地 PLAN 八步:M1 `wave_boundary_settled`(包裹法,新增 `wave_boundary_settled_test.gd` 2 用例)→ TownView 纯视图枢纽(`show_town`/`show_combat` + 四 overlay,删 `pause_run`/`resume_run`/`reset_to_combat`)→ GameFlow `_enter_town_hub()` 落点反转 + 信号监听 `_return_pending` 延迟返城 + `on_depart`(守 `max_unlocked_stage`)+ TOWN-Esc 分支(Esc 权威集中 GameFlow / R4 退路);CombatView 加「回城」钮 + 已请求态。删死码 `_enter_game`/`_reconcile_views_to_combat`。**自动验证全绿**:headless import 0 Parse Error、gdUnit4 **158 cases · 0 fail · 0 orphan**。3 处偏差(TownView 合一次重写 / Esc 取 R4 退路 / 回城文案)同范围,见 CHANGES §4。表现层手验清单见 CHANGES §6。
- [x] **Reviewer**(2026-06-20)— 产 `REVIEW.md`(draft):**Verdict = Approve**。逐文件读真码核对四轴 + 七决策,**无 Must-fix**。确认单一发起点(§6.4/ARCH §6 双发起点债已闭)、待回城守支柱 1/不变量 #12、`on_depart` 越权双层防御、信号连接时机成立、包裹法单发。2 项 Should-fix(S1 `on_depart` 的 prog==null 绕过守卫=理论缺口不可达;S2 出征 `stages` 双源隐式耦合=记债)+ 3 Nits(N1 菜单开着那波待回城延迟一波/N2 begin_run 后即 pause 冗余 spawn/N3 占位坐标)均非阻断。转 EI。
- [~] **Engine Integrator**(2026-06-20)— 产 `INTEGRATION-STEPS.md`(draft)。**核对 Wiring Contract 对真场景 `floating_shell.tscn` + 真码:全部成立、无任何编辑器接线工作**(GameFlow 为根末子节点、`stages` @export 已拖、CombatView/TownView 在 MainArea 互为兄弟;group `game_flow`/`town_view` + `wave_boundary_settled` 连接全代码内自完成)。本块无 .tscn/.tres/导入改动 → style-basic-2d §4/§7 不触发。产出 §A headless 复校(已绿) + **§B 表现层 Play 手验 6 段(B1 落城镇暂停 / B2 四子板块 / B3 Esc 分层 / B4 出征出击越权 / B5 改动随出击生效 / B6 待回城本波结算返城)**,逐项带 Verify + REVIEW flag(N1/S1/S2)留意点。**作者 Play 手验进行中**;已回报 **EI-F1 = 小队换装无「当前成员」标识**(`_hero()` 写死取 roster 首个成员、无成员选择器;v1 单成员不出错、非本块引入/非回归,多成员切换属 scope 外)→ 作者裁决「现在加当前成员标签」,精确规格已记 INTEGRATION-STEPS,转小 Implementer pass。
- [~] **UX Design**(2026-06-20,EI-F1 触发)— 产 `harness/ux/UX-CHANGE-03-party-member-selector.md`(draft):诊断小队/工匠 overlay **缺成员轴**(`_hero()` 写死取首个非空成员,多成员落地后静默永编辑 0 号且无从切换)。分两期:**interim=当前成员标签**(选择器单成员退化态 = EI-F1 已交 Implementer 的标签,前向兼容、本块在途)/ **full=成员选择器 tab-row,deferred 到招募/多成员 v2**(town 级共用「当前编辑成员」寄存器 + 下方控件 rebind)。**不新增屏、不动 Flow FSM、STATE-MACHINES 不变**(成员轴在 Flow 态之下)。UX-MAP.md §3 城镇 Town + §6 债 #9 / INDEX.md 已同步。
- [~] **UX Design**(2026-06-20,用户参考图触发)— 加产 `harness/ux/UX-CHANGE-04-town-boards-layout.md`(draft):据用户 6 张参考图(城镇/小队/打造/出征/酒馆/背包)把**枢纽 + 五子板块**从抽象占位细化为**每板块 IA(分区+导航+态)**,逐区标注"✅映射现有 / ⚠仅参考·略"。结论:**A 层(映射现有系统)= 全局 UI·juice 轮的布局蓝图,主交付 Art Spec**;少量新信息位(出征敌人/掉落预览、战力派生)交 Planner;**B 层无系统支撑项(货币/收益秒/每日任务·活动·成就/制作/技能/成功率/自动战斗开关)= 预留区位不建**(硬 NO:不造没影系统)。窗口几何(城镇放大窗?)flag SMM+用户。UX-MAP.md §3 / INDEX.md 已同步;UX-CHANGE-03 成员轴 full 几何细化为"左列成员栏"。
- [~] **Art Spec**(2026-06-20)— 产 `ASSET-SPEC.md`(draft):据 UX-CHANGE-04 把城镇枢纽 + 五板块布局蓝图落成**约 25 类素材**:**A 共用九宫格框架件**(板框/内嵌/标题牌/按钮×2/页签/槽框/列表行/头像框,一次出五板块复用)· **B 图标集 32×32**(类型 3 / 8 维属性 / 导航·操作,标核心/次要)· **C 城镇枢纽场景**(`bg_town` + 4 建筑入口 forge/tavern/party/depart)· **D 板块专属**(战士半身像 / 锁定剪影 / 星级 / 升级箭头 / 2 关卡预览 / 酒馆场景 / 招募锁位)。逐件定尺寸/锚点/九宫格切边/命名/palette + prompt brief + 客观验收。**只做 A 层(映射现有系统)**;B 层无系统项(货币/收益秒/每日任务·活动·成就/制作/技能/成功率/自动战斗开关)**不出素材**(硬 NO)。**强化预览不放成功率**(确定性 +1)。**画风决策已锁**:框架件由 flat StyleBox 升级为暖木金花边九宫格(STYLE-BIBLE §8.6),**用户已确认花边**(先按花边出图,效果好再回头细调 bible)。物品图标用按槽类型 3 枚(够 v1,逐基底图另立 spec)。**下一棒 = `/image-prompt 10-ingame-flow-nav`** 编译成品 prompt → 出图 → 回报 Art Spec 验收(产 ACCEPTANCE.md)。
- [x] **Image Prompt**(2026-06-20)— 产 `IMAGE-PROMPTS.md`(draft):把 ASSET-SPEC 25 件 brief 编译成**可直接粘给 image2(gpt-image)的英文成品 prompt**,每条 = 锁定四段前缀 ①②③(逐字取自 `IMAGE-PROMPT-PREFIX.md`:MapleStory 锚点 + 方案 A 暖木 palette)+ ④ 排除项 + 具体要求。画布映射:框架件/图标/立绘/星 = 1024×1024;宽幅(`bg_town`/`arrow_upgrade`/`stage_preview_*`/`bg_tavern`)= 1536×1024 后裁中段;竖幅(`recruit_lock`)= 1024×1536。逐件给透明开关 + Post-gen(平滑**非像素**下采样到精确 px、九宫格 patch_margin 交 EI、抠实底/无文字红线)。附批次建议(①框架+核心图标 ②城镇 ③板块专属)+ 复用既有(敌人 `enemy_*`/`hero_warrior`/掉落用 3 槽类型图标)。**下一棒 = 拿 IMAGE-PROMPTS.md 去 image2 出图 → `/role-engine-integrator-godot` 导入(或 `/role-art-spec` 验收)**。

## 下一步
**先开 `/role-implementer 10-ingame-flow-nav`** 落地一个小改(作者 Play 手验发现 EI-F1,已裁决):小队/工匠板块加「当前成员标签」。精确规格见 `INTEGRATION-STEPS.md`「手验发现 EI-F1」:在 `town_view.gd:156 _rebuild_slot_selector(col)` 顶部(null 守卫后、slot 循环前)插一行 `_label("当前编辑:%s" % nm, ...)`,`nm = c.display_name or "队员"`;该函数小队/工匠共用 → 一处改两板块生效。只标注现有单成员、不做切换(多成员切换 = v1 scope 外,招募功能再做)。无新结构/依赖。
**该小改落码后,作者继续照 `INTEGRATION-STEPS.md` §B 走 Play 手验并回报**(EI 闭环):打开
`res://scenes/shell/floating_shell.tscn` 按 F6,逐段验 B1 落城镇暂停 → B2 四子板块 → B3 Esc 分层/[☰] →
B4 出征出击+越权置灰 → B5 城镇改动随出击生效 → B6 回城本波结算返城/撤销。任一步偏离 Verify 即记现象回报。
**本块无编辑器接线**(已核 Wiring Contract 对真场景全成立),§A headless 复校可选(CHANGES §3/REVIEW 已绿)。
回报后:全绿 → EI 标 `[x]`、本 feature 可收;若 N1/S1/S2 实机暴露或发现新问题 → 据严重度退 Implementer 或滚后续块。
**评审结论**:Reviewer **Approve · 无 Must-fix**(REVIEW.md);S1/S2 两 Should-fix + 3 Nits 均非阻断,可后顺手修。
**表现层手验后续(scope OUT,非本块)**:掉落暂存(arch-guard)、掉落预览收窄;STATE-MACHINES.md 的 `[SC-02 计划]` / UX-MAP 待后续 role 把"计划"转"现状"。
**全局 UI·juice 轮(并行/独立于本块 EI 闭环)**:**Art Spec 已产 `ASSET-SPEC.md` → Image Prompt 已产 `IMAGE-PROMPTS.md`(25 件成品 image2 prompt)** → **下一棒 = 拿 `IMAGE-PROMPTS.md` 去 image2 出图**(逐件粘贴,按 Post-gen 缩到精确 px)→ 回报 Art Spec 验收(`/role-art-spec` 产 ACCEPTANCE.md)→ 落地换皮/接线(Theme.tres/NinePatch/导入预设)交 `/role-engine-integrator-godot`;**框架件 = 暖木金花边九宫格,用户已确认**(STYLE-BIBLE §8.6)。出征敌人/掉落预览 + 战力派生**数据接入**交 `/role-planner`。B 层无系统项不出图。
**自动验证已绿**:headless import 0 Parse Error、gdUnit4 158 cases / 0 fail / 0 orphan。
**条件先转 `/arch-guard`**(本期未触发):若后续做探索内「掉落预览」需掉落暂存数据结构,或四子板块/屏数膨胀真需 ScreenManager → 那时先转 arch-guard(SMM 已 scope OUT,本块未做)。
**flag(Planner 已滚汇,留待落地/后续块裁决)**:
- **scope → `/role-producer`**:四子板块是否本块一次做完?Planner 建议一块打包(出征新增 + 小队/工匠复用 + 酒馆占位),退路 = 把第 7 步城镇枢纽切成 `10b`;酒馆接壳不实装。
- **design → `/role-game-designer`**:① 待回城结算粒度(波 vs 关,R1)② 出征选关是否改挂机推关心智 ③ 城镇暂停态挂机进度可见性(支柱 1 缓解)④ 撤销「待回城」是否要(R3)⑤ 工匠分解/制作 scope。
- **后续(scope OUT,非本块)**:掉落暂存区(arch-guard)、掉落预览收窄 + UI·juice 上皮(全局 UI 轮)。
- **UX-CHANGE-03 成员轴 → 分两期**:**interim 当前成员标签 = 即上面 EI-F1 小 Implementer pass**(选择器单成员退化态,无需 Planner 另起);**full 成员选择器(左列成员栏,几何已由 UX-CHANGE-04 细化)→ flag `/role-producer`**,归入**招募/多成员功能(v2)**(BACKLOG Later),该功能开工时 `UX-CHANGE-03`+`UX-CHANGE-04 §3.1` = 成员轴蓝图,届时 `/role-planner <招募slug>` + `/role-art-spec`。**本块不立即建。State Machine Master 无需动作**(成员轴在 Flow 态之下)。
- **UX-CHANGE-04 城镇五板块布局重设计 → 三向**:① **主交付 → `/role-art-spec`(全局 UI·juice 轮)**:本文 = 枢纽 + 五板块布局蓝图,那一轮据 §3 各板块 IA 出视觉;② **`/role-planner` 少量新信息位**(可与上皮并行):出征**敌人/掉落预览**接数据(enemy_def + 掉落表)、**战力派生**(8 维→汇总值);③ **`/role-producer` flag**:B 层无系统支撑项(货币经济/制作/每日任务·活动·成就/自动战斗开关)= 本文只预留区位不立项,要不要提上日程由 Producer 定。**强化保持确定性 +1、不引成功率** → flag `/role-game-designer` 确认。
- **窗口几何 → 【已闭环·2026-06-20·State Machine Master】**:裁定 = **Option A 城镇复用 M3.EXPANDED 贴底全宽窗(800×250),不新增几何态、不动 MainArea 结构**(现状 M2.TOWN 已渲染于 EXPANDED;参考图为 ~3.2:1 正是贴底窗画幅)。无状态机 delta → **未产 STATE-CHANGE 文档**,结论落 `STATE-MACHINES.md §6 #8`。**A 层布局一律按 800×250 排版。** 条件触发未来债:若 UI·juice 轮实证 250px 装不下最满板且要城镇专属更大窗 → 才先 `/arch-guard`(MainArea 尺寸随 flow 变)再回 SMM 给 M3 加第 4 态 TOWN。本期不做。
