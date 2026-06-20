---
artifact: UX-CHANGE
feature: 10-ingame-flow-nav
role: UX Design
status: draft
updated: 2026-06-20
inputs: [UX-MAP.md, STATE-MACHINES.md, ARCHITECTURE.md, BACKLOG.md, project-context.md, harness/feedbacks/Game-flow-ideas.md, harness/feedbacks/game-flow.png, src/combat/town_view.gd, src/combat/combat_view.gd, src/shell/game_flow.gd, harness/features/10-ingame-flow-nav/HANDOFF.md]
next: State Machine Master
---

# UX-CHANGE-02 · 游戏内板块导航统一化(城镇为家 · 枢纽 + 子板块)

> 承 09(前门 + 系统枢纽)。09 立了"系统级"枢纽(`[☰]`→主菜单),本案定**"游戏级"板块导航**:
> 把 探索/城镇/背包 从各自为政的隐式可见性切换,收成 **城镇(家·枢纽)↔ 探索(派出挂机)** 两块顶层板块,
> 由 GameFlow 单一发起点统管。
>
> **本版(2026-06-20 refine)依据用户 `Game-flow-ideas.md` + `game-flow.png` 重做**:城镇升为**枢纽**,
> 下挂 **工匠 / 酒馆 / 小队 / 出征** 四个**覆盖式子板块**;出征 = 关卡选择 → 派出挂机;新增**「待回城」标记**
> (战斗中点回城不打断,本关结算后再返城)。用户既往拍板(B 城镇为家 / 落点方式 3 都落城镇且暂停 / 背包拆解)全部保留。

## 1. 触发 / Trigger
Producer 切出 `10-ingame-flow-nav`,范围 = **整个游戏内流程结构**:新游戏落点 + 探索/城镇/背包纳入 GameFlow 统一导航 +
各板块切换逻辑显式化。用户随后用 `Game-flow-ideas.md`(+ 截图)把"城镇该长什么样"具体化为**枢纽 + 四子板块**模型,
并补了战斗中回城的"待回城"标记诉求。09 只统一了系统级导航,**游戏级板块切换仍散在各 view 里**
(STATE-MACHINES §6.4 残留 / ARCHITECTURE §6 "屏可见性双发起点"债)。

## 2. 现状诊断 / Diagnosis
- **探索(Explore)是隐式的"家"**:GameFlow `_enter_game`(继续/新游戏后)直接落 EXPLORE 自动战斗。
- **城镇是单层、非枢纽**:`town_view.gd` 把"换装 + 强化 +1"**平铺在一屏**,没有"枢纽 → 子板块"的层级;
  也没有 出征(关卡选择)/ 小队 / 酒馆 的位置。整段进出城由 `TownView` 自管(`Game.pause_run()` + 隐 `CombatView` +
  显 `town_root`),**GameFlow 不知情**——EXPLORE↔TOWN 这对游戏态切换从未进入 09 建立的 GameFlow 流程 FSM。
- **背包**:探索内 `combat_view.gd::_build_panel` 一个只读全区遮罩(掉落包 + 当前装备 + 8 维属性),`_panel_btn` 切显隐,再点关闭,不暂停。
- **回城是硬切**:今天没有"进城"动作里的"待回城"概念——`_enter_town` 立刻 `pause_run`。战斗中想回城 = 立即冻结当前波,
  与"波清空才推进"(ARCHITECTURE 不变量 #12)粒度不一致,也与支柱 1"不打断"略有张力。
- **关卡推进是全自动、无玩家选择**:`ProgressionController` 自动推关(`max_unlocked_stage` 解锁),玩家**无处选"去打哪一关"**。
- **根因**:**游戏内板块切换没有统一发起点,且城镇缺"枢纽"这一层**。09 收拢了系统级导航,但探索/城镇/背包之间仍靠
  `.visible`+`pause_run` 隐式硬撑;城镇内部也没有可扩展的"枢纽 → 子板块"骨架,导致加 出征/小队/酒馆 无处落。

## 3. 目标形态 / Target flow(delta vs UX-MAP.md §2/§3,🔜 planned)

### 3.1 顶层游戏内板块:城镇(家·枢纽)↔ 探索(派出挂机)
顶层仍只两块;**城镇内部升为"枢纽 + 四覆盖式子板块"**(子板块 = overlay,玩家"位置"始终在城镇,只叠面板,返回成本低):

```
[启动] ─> 主菜单 Title ─[继续/新游戏]─> 城镇 Town(家·枢纽·暂停)
                                       〔继续=续战游标;新游戏=有档先覆盖确认;**两者均落城镇暂停态**〕

城镇 Town(枢纽) ─[工匠]──> 工匠子板块 overlay(左仓库 / 右打造:分解·强化·制作)   ─Esc/返回─> 城镇枢纽
城镇 Town(枢纽) ─[小队]──> 小队子板块 overlay(左仓库按部位分页 / 右人物详情:装备栏+属性)─Esc/返回─> 城镇枢纽
城镇 Town(枢纽) ─[酒馆]──> 酒馆子板块 overlay(占位"敬请期待")                    ─Esc/返回─> 城镇枢纽
城镇 Town(枢纽) ─[出征]──> 出征子板块 overlay(关卡选择)─[选关·出击]─> 探索 Explore(resume_run,派出挂机)

探索 Explore ─[回城](战斗中)─> 设「待回城」标记(不打断,本关结算后返城)→ 结算 → 城镇 Town(pause_run)
探索 Explore ─(本关自然结算/通关)─> 〔正常出口〕→ 城镇 Town(pause_run)
探索 Explore ─[掉落预览]─> 掉落预览 overlay(只读·已掉落装备+材料·**不暂停**) ─再点/Esc─> 探索

探索 / 城镇 ─[☰]─> 主菜单(MENU_OVERLAY) ─继续/Esc─> 回来源(探索续战 / 城镇仍暂停)
城镇(家·游戏内根) ─Esc─> 主菜单(MENU_OVERLAY)   〔家无更上层板块,Esc 给键盘一条通往系统枢纽的出口〕
```

**关键 delta(对比现状):**
- **落点反转**:BOOT/继续/新游戏 由"落探索(running)"改为 **"落城镇枢纽(暂停)"**。点 出征→出击 才开打。
- **城镇升为枢纽 + 四子板块**:工匠 / 小队 / 酒馆 / 出征,均为**覆盖式 overlay**(非整屏跳转),玩家始终"在城镇"。
- **切换发起点统一**:EXPLORE↔TOWN 由 `TownView` 自管**上移进 GameFlow**(收 §6.4 残留 / ARCH §6 债)。
- **出征 = 关卡选择**:把现"全自动推关"补上"玩家选去打哪一关"的入口;选关后**仍是挂机自动战斗**(idle 不变,只是给了落点选择)。⚠ 见 §3.4 风险:这层"选关"心智属 Game Designer scope。
- **「待回城」标记(新)**:战斗中点「回城」**不立即冻结**,设 `待回城` 标记、按钮转「已请求回城,本关结束后返回」,
  等当前波/关结算这一刻再 `pause_run` 返城。与 ARCHITECTURE 不变量 #12(波清空粒度)、支柱 1(不打断)同向。
- **背包拆解**(用户既往拍板,保留):
  - **探索内** = **掉落预览**:`_build_panel` 收窄为"已掉落的装备 + 材料"只读速查(去掉当前装备/8 维明细——移到城镇·小队语境);仍**不暂停**(守支柱 1)。
  - **城镇内** = **并入小队(换装)+ 工匠**:小队子板块显示装备(现 05-town 三槽 + 对比已具雏形);工匠子板块显示**装备 + 材料**(现 05-town 强化 +1 是其起点)。

### 3.2 落点权衡(已记,免再议)
**支柱冲突已挑明并由用户拍板**:城镇(家)暂停挂机,故"新游戏/继续都落城镇"= **启动后默认是静止暂停的城镇枢纽,而非自动战斗的小队**——
与支柱 1(权重 5/10:"悬浮窗安静贴底自动战斗、余光扫一眼就懂")有张力。用户选**方式 3(都落城镇且暂停)**,
**有意接受**此权衡(基地心智 > 启动即陪伴)。记录于此,Art Spec/Game Designer/Planner 勿误判为漏做。
缓解项(交下游):出征/出击按钮应显著、易达;城镇态可考虑让"挂机收益/进度"仍可见以保留一点陪伴感(机制属 Game Designer)。

### 3.3 每屏/子板块职责与交互态(delta vs §3)
- **城镇 Town(升为家·枢纽·游戏内根)**:枢纽本身 = 四入口(工匠/小队/酒馆/出征)+ 进度/货币速览。交互态:`default` / 各子板块"已打开"。Esc=开主菜单(游戏内根的键盘出口)。
- **工匠子板块 overlay**:左仓库 / 右打造,按标签(分解 / 强化 / 制作)显示可执行操作 + **消耗与结果预览**(消耗哪些材料、强化成功率、产出什么),确认后即时更新仓库。交互态沿用 05-town(default/空槽/满级/材料不足)+ 标签切换。⚠ 分解/制作超出现有"强化 +1" = 新玩法,本案只定 IA 壳,机制 flag Game Designer。
- **小队子板块 overlay**:左仓库按部位分标签页 / 右人物详情(装备栏 + 8 维属性)。选队员→看装备栏→点/拖装备到对应部位;穿脱即时重算并**高亮属性变化**(攻击 +12)。与工匠共用同一份仓库(过滤展示不同)。交互态:`default` / `空槽` / `(无可换 X)` / 属性变化高亮。
- **酒馆子板块 overlay**:**占位**(标题 + "敬请期待"),但导航入口 + 返回逻辑先接通。交互态:`default`(仅返回)。⚠ 招募内容 = Producer scoped Later,本案只接壳。
- **出征子板块 overlay**:关卡选择(列已解锁关卡)→「出击」派出挂机。交互态:`default` / 关卡`已解锁可选` / `未解锁锁定` / 选中。
- **探索 Explore(降为"出击在外"板块)**:新增「回城」出口(走「待回城」标记);原「背包/装备」按钮 → **「掉落预览」**(只读掉落+材料)。其余战斗态(grinding/推进/倒计时/狂暴/里程碑)不变。「回城」按钮新增态:`default` / `已请求回城(本关结束后返回)`。
- **掉落预览 overlay**:由现只读双栏面板收窄——只列**已掉落装备 + 材料**,不含当前装备/属性明细;`再点/Esc` 关闭;不暂停。

### 3.4 状态分层:多数已由四层地基承载(SMM/arch 复核 delta,非新建)
用户 `Game-flow-ideas.md` §三的"持久 / 派生 / 临时"三层,**绝大部分已是当前四层地基的现状**,本案**不重造**,仅指出 delta 供 SMM/arch 复核:
- **持久层**(玩家档案 / 仓库单一数据源 / 小队存引用不存计算属性)= 现 **持久元状态层 `PlayerState`(autoload)+ `Character.equipped:{slot→ItemInstance}` + `PlayerState.bag`/材料**;"仓库是唯一真相、队员只存引用、不复制装备"= 已有不变量 #2/#11(属性永远重算、战斗外元操作只写持久层)。
- **派生层**(最终属性实时计算/缓存)= 现 **`StatsComponent` 脏标记重算**(不变量 #2),已不存最终值。
- **临时层**(战斗进度/血量/掉落暂存/回城标记)= 现 **per-run 战斗层(`CombatArena`/`Entity`/`ProgressionController`,可弃)**。
- **真 delta(需 SMM/arch 看)**:① **掉落暂存区 + 结算唯一写入口**——需核 `item_dropped` 当前是否即时写 `PlayerState.bag`,若是则要改为"暂存→关卡结算合并";② **「待回城」标记**——M1/M2 新增"结算时若标记则 pause+返城"转移。这两项才是本案引出的新状态行为。

## 4. 调整策略 / Strategy(依赖序,strategy-level,无代码)
1. **GameFlow 收编 EXPLORE↔TOWN**(前置·SMM/arch):把进城/出城从 `TownView` 自管上移为 GameFlow 发起的板块切换,纳入 M2 流程 FSM。
2. **改落点**:GameFlow 继续/新游戏后的 `_enter_game` 由落 EXPLORE 改为落 **TOWN 枢纽(暂停态)**;出征→「出击」= GameFlow 切 EXPLORE + resume(带所选关卡)。
3. **城镇枢纽骨架**:把现单层 town 改为"枢纽 + 四 overlay 子板块"(工匠/小队/酒馆/出征);子板块统一 overlay 显隐 + 返回。换装/强化归入 小队/工匠 子板块。
4. **背包拆解**:探索面板收窄为掉落预览(掉落装备+材料);城镇换装→小队子板块、强化→工匠子板块(整合材料显示)。
5. **「待回城」标记 + 出征选关**(行为·SMM):回城在战斗中设标记、结算时返城;出征 overlay 选已解锁关 → begin_run(stage)。
6. **Esc 推广**(闭债 #3):子板块 overlay→城镇枢纽;掉落预览→探索;探索→城镇(回城);城镇枢纽(根)→开主菜单。`[☰]` 全局入口不变。

## 5. 影响面与迁移 / Blast radius
- **STATE-MACHINES.md(SMM,核心)**:M2 `GameFlow.Flow` 加 EXPLORE↔TOWN 转移(收 §6.4 残留)、改 BOOT/continue 落点为 TOWN 枢纽、
  「出击/回城」= GameFlow 命令的 resume/pause;**新增「待回城」标记**(M1 结算钩子 + M2 返城,关联不变量 #12 与债 #6"两套停语义");
  出征选关 = `begin_run(chosen_stage)`。债 §6.4 残留 + §6.3 RESTING + #6 需复核。→ `STATE-CHANGE-02`。
- **ARCHITECTURE.md(Arch Guard,条件触发)**:① §6 "屏可见性双发起点"债的结构归宿——GameFlow 如何横向命令 TownView/CombatView 显隐,
  **以及城镇"枢纽 + 四子板块 overlay"是否需要屏挂载/容器结构**(沿 09 协调器横向调用?还是引入 ScreenManager/子面板容器?)。若需新结构,先转 arch-guard。
  ② **掉落暂存区**:若现 `item_dropped` 即时写 bag,需引入暂存 + 结算合并(碰持久层写入时机,= 不变量 #11 的"唯一写入口"细化)。③ "工匠·分解/制作"若成新机制 → 数据/模块层亦需 arch。
- **Art Spec(并入 UI·juice 轮)**:城镇枢纽四入口布局、出征关卡列表、工匠/小队 overlay 左仓右详情排布、掉落预览、出击/回城按钮、「已请求回城」态、城镇"家"的视觉权重。
- **Game Designer(scope flag)**:① 工匠·分解/制作 是否超出现有强化(打造=造新装?);② **出征"选关"是否改变挂机推关心智**(idle-within-stage vs 主动推关);③ 城镇暂停态下是否给"挂机进度可见"以补支柱 1;④ 「待回城」结算粒度(波 vs 关)。
- **Producer(scope flag)**:① **酒馆招募 = 已 scoped Later/OUT**——本案只接 nav 入口 + 占位屏,招募内容不实装;② 城镇"枢纽 + 四子板块"+ 出征选关 是否仍在本块预算内,或需再切片(如出征/小队各成子块)。
- **src 影响**:`src/shell/game_flow.gd`(落点+板块切换+待回城)、`src/combat/town_view.gd`(进出城上移、枢纽+四子板块重构)、`src/combat/combat_view.gd`(背包→掉落预览、回城按钮态)、`ProgressionController`/`CombatArena`(待回城标记+结算返城、掉落暂存)。
- **保持一致**:窗口几何态(M3:MENU↔strip)与收起/置顶不变;`[☰]`→主菜单流程(09)不变;暂停机制(`pause_run`/`resume_run`)本身不变,仅发起方/落点/触发时机(待回城)变;**三层状态多数已由四层地基承载,不重造**(§3.4)。

## 6. 风险与被否选项 / Risks & rejected alternatives
- **被否·拓扑 A(探索为家)/ C(平权切换条)**:用户选 **B 城镇为家**(基地心智);C 的常驻切换条判过重、过度设计。
- **被否·落点方式 1(拆分落点:继续→探索/新游戏→城镇)/ 方式 2(都落城镇但不暂停)**:用户选**方式 3(都落城镇且暂停)**。
- **风险 R1(支柱 1)**:城镇为家+暂停 → 启动落静止城镇,削弱"启动即陪伴自动战斗"。**已挑明、用户有意接受**(§3.2);缓解交下游(出击显著 + 城镇可见挂机进度)。
- **风险 R2(scope 蔓延 · 本版加剧)**:`Game-flow-ideas.md` 把城镇扩成**四子板块**,其中 **酒馆招募** = Producer 已划 Later、**工匠分解/制作** + **出征选关** = 新机制/新心智,易从"导航结构重构"滑成"实装一堆新玩法"。**本案只定 IA 壳 + 占位**:酒馆接壳不实装;分解/制作/选关心智 flag 给 Game Designer/Producer,**勿在本期实装机制**。若四子板块工作量超本块预算,Producer 应再切片。
- **风险 R3(收编爆炸半径)**:把 EXPLORE↔TOWN + 城镇枢纽收进 GameFlow 会动 09 刚立的协调器边界。沿用 09 的"协调器横向调公开 API"模式可控;**若四子板块 overlay 诱发屏挂载/ScreenManager 机制则先转 arch-guard**,勿在 Planner 层硬塞。
- **风险 R4(状态分层误读为新建)**:`Game-flow-ideas.md` 的三层状态**多数已是现状四层地基**(§3.4),勿当新需求重造;真 delta 仅"掉落暂存区 + 待回城标记",交 SMM/arch 精确判定。

## 7. 交接 / Handoff
- **下一棒 = State Machine Master**:开 `/state-machine-master 10-ingame-flow-nav`,喂本 `UX-CHANGE-02`,产 `STATE-CHANGE-02`——
  把 EXPLORE↔TOWN 收进 M2 `GameFlow.Flow`、改 BOOT/continue 落点为 TOWN 枢纽(暂停)、定「出击(选关)/回城(待回城标记+结算返城)」转移、复核掉落暂存。
- **flag Arch Guard**:若收编需新结构(屏挂载/ScreenManager / 城镇四子板块容器 / 掉落暂存写入时机),SMM 先转 `/arch-guard` 定归宿(承 REFACTOR-05 协调器边界)。
- **flag Game Designer**:工匠·分解/制作 scope + 出征"选关"心智 + 城镇暂停态挂机可见性 + 待回城结算粒度。
- **flag Producer**:酒馆招募仅接壳(内容 Later);四子板块 + 出征是否需再切片。
- **flag Art Spec**:城镇枢纽四入口 / 出征关卡列表 / 工匠·小队 overlay / 掉落预览 / 出击·回城·已请求回城 视觉,并入全局 UI·juice 轮。
- **再下游 Planner**:SMM(+arch)定稿后,`/role-planner 10-ingame-flow-nav` 落成 PLAN。
