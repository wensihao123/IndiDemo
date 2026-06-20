---
updated: 2026-06-20 (**V2 进行中:整套交互流程重构。第一块 09-title-main-menu 已收口 → 第二块 10-ingame-flow-nav committed**)
---


# BACKLOG (Producer)

> 范围的单一事实来源。每个想法只落进一个桶,并附理由,避免下周重新吵。
> 默认偏向 LESS:中途冒出的新想法,默认答案是 "Later"。
>
> ⚠ **2026-06-19 大事:`00-foundation-redesign` 整体地基重构落地**(REFACTOR-01)。它由"04 装不进旧
> director 结构"触发,重铺成四层组件化架构,并把**掉落/装备后端、存档、lane 多敌引擎**一并提前进地基
> (推翻原"v1-minimal"基调)。下方 Done/Now/Next 已据此重新归桶。

## v1 scope line(可上架/可验收的 v1 = 这一句)
一个能跑通**完整闭环**的垂直切片:挂机探索自动打怪(**含团战 / 多敌同屏**)、掉装备/材料 → 回城**手动换装 +
最简强化**变强 → 打过更硬的怪。含悬浮窗外壳、4 格队伍(v1 只填 1 战士)、**后台持续推进**、最简存档。
地基(组件化实体 / 持久层 / 掉落流水线 / lane 多敌引擎)已由 `00-foundation-redesign` 铺就。

## 状态:V1 里程碑收口 → 进入 V2(2026-06-20 scope call)
- **V1 里程碑收口** —— 上面那句垂直切片闭环已端到端验(占位程序美术)。功能/内容达标,作为里程碑算完成。
- **无上线时间线压力(用户拍板 2026-06-20)** —— **不赶 V1 上架**,做到完善再推,版本号到 V 几无所谓。
  故先前"流程重构进 v1.5 还是推 v2"的纠结**取消**:它就是 **V2 的第一件正式工作**,按部就班做好即可。
- **V2 纪律(无 deadline 时 Producer 的真正风险 = 蔓延 / 永不收尾,而非赶不上)**:仍守"一次一件"、
  流程重构**严格限定在流程/屏/状态结构本身**,不顺手把 Later 的招募/多职业/技能树/离线等大件捆进来。
  每块做完再开下一块;"做到完善"= 逐块收尾,不是无限打磨同一块。

## Done(已完成 —— v1 切片累积)
- ✅ **01-floating-window-shell**(2026-06-18)— 底部全宽常驻悬浮窗、800×250 居中主区、收起/恢复、
  待机微动占位角色、F1 收起 / F2 置顶、per-pixel 透明收起 handle。设计→实现→接线→审查→清理 全链路走通。
- ✅ **02-auto-combat-loop**(2026-06-18)— 1 战士自动打 2 关 ×(3 普通场景 + Boss)、固定步长 tick(后台持续推进)、
  4 格队伍数据地基、掉落事件流(白/蓝/金 FX)、Boss 永久解锁 + 团灭回退 + 推进/修整。
  *(注:其内部实现已于 `00` 重铺为组件化,**行为保留**;6 维公式搬入 `SkillComponent`。)*
- ✅ **03-combat-formula-ext**(2026-06-18)— 战斗公式扩出 **6 维**:攻速→出手频率、护甲→减伤、闪避、暴击(率+倍率)、
  每秒回血、软狂暴。数值全走 Resource/@export。审查 APPROVE WITH NITS + 2 should-fix 已清 + 用户手动 Play(F7)通过。
  *(注:成果被 `00` **承接(非废弃)**——6 维公式搬入 `SkillComponent`,**断言值不变 = 重构回归锚**;承载结构由单敌 director 改为
  lane 多实体 + 组件,数值/语义不丢。目录留作设计/历史档,不再单独推进。)*
- ✅ **00-foundation-redesign**(2026-06-19,**cross-cutting 整体地基重构**)— 触发 = 04 装不进旧 director(God object)。
  交付:**四层架构**(数据层 `DataRegistry` / 持久层 `PlayerState`+`SaveSystem` / 单局战斗层 `CombatArena`+`ProgressionController` /
  表现层 `CombatView`)+ **组件化 `Entity`**(Stats/Equipment/Skill/AICombat)+ **属性引擎**(`Final=(Base+ΣFlat)×(1+ΣPercent)`,
  无损卸装)+ **掉落/装备后端**(`ItemBaseDef`/`AffixDef` JSON 池 → `LootGenerator` PoE Tier roll → `ItemInstance`,自动填空槽 / 自动分解)+
  **lane 多敌引擎**(团战在地基内,差配置)+ **存档 round-trip**(`SaveSystem` 落 roster/背包/材料/进度)。
  全套 **117/117、0 orphans**;旧 `Combat` director 退场;§F 手动 Play(含存档重开续战、F-SaveBoss 修复)经人验收通过。
  事实源 `ARCHITECTURE.md` + 人类导读 `ARCHITECTURE-GUIDE.md` 已对齐落地代码。
- ✅ **07-save-load(最简版)实质已交付,并入 `00`** — 最简 save/load(队伍/背包/进度)由 foundation `SaveSystem` 落地,
  §F round-trip 人验通过(通关→关程序→重开续到下一关、不重打 Boss)。**故不再单列 07 新功能**;多档/云存档原本就在 v1 外。
- ✅ **04-loot-equipment(收窄为「表层 + 数值定稿」)**(2026-06-19)— 后端(掉落 roll / `ItemInstance` / 词缀分阶 / 自动填空 / 自动分解 / 装备组件)随 `00` 落地;04 交付剩余两件:
  ① 悬浮窗**只读双栏查阅面板**(背包/当前装备 + 8 维属性明细 + 自动填空绿闪 = 支柱 2 "变强看得见");
  ② **数值定稿**——`LootGenerator.pick_weighted` 读 `EnemyDef.rarity_weight_*`(金/白不再等概率,守支柱 3)+ 8 个 `EnemyDef.item_level` 阶梯(BALANCE-CHANGE-01)。
  gdUnit4 123/123 绿、Reviewer APPROVE WITH NITS(2 should-fix 已闭)、人验 6 条通过。旧设计/计划/勘探三件标 superseded(假设旧 director)。
- ✅ **05-town-gear-upgrade(城镇:手动换装 + 对比面板 + 装备强化)**(2026-06-19)— 支柱 2 主动构筑高光落点。进城**暂停挂机** →
  1 战士 3 槽**手动换装** + **对比面板**(逐轴差值绿↑红↓)+ **确定性装备强化**(+1、三槽通吃、花 `slot|white` 材料、数值随级线性、上限 +10)→ 出城**不回血**且改动生效。
  六棒齐(设计→架构→数值→计划→实现→接线):新增 `enhance.json`/`EnhanceConfigDef` + `ItemInstance.enhance_level` + `PlayerState` 换装/强化元操作 +
  `Game.pause_run/resume_run` + `TownView`(REFACTOR-03 + BALANCE-CHANGE-02,守 i1/i4/i5/i7 + 不变量 #10/#11)。gdUnit4 **145/145 绿、0 orphan**;EI 接线人验通过。
  **界面为占位程序美术;UI/juice 经用户拍板推迟到 v1 功能全完成后统一处理(见决策日志 2026-06-19)。**
- ✅ **08-team-combat(多敌同屏 —— 自 Later 提升进 v1)**(2026-06-20)— 敌方**一波多敌同时打**(车轮战→团战)。
  REFACTOR-04 把刷怪/推进契约由 per-enemy 拆为 **per-wave(新不变量 #12)**;`EnemyDef.position_class`(近/远)+ `SceneConfig.enemy_group`(多敌波)加性扩展;
  **近战门控**(前 G=`CombatTuning.melee_gate_capacity=2` 名近战出手、余排队补位=车轮)+ **远程隔位漏血**(不受门控);`in_range` 退役。
  关1 .tres 铺波(Scene1=2近 / Scene2=2近+1远 / Scene3=3近+1远 / Boss=1);波 size=1 退化逐位等价 = 回归基线。
  gdUnit4 **144/144 绿**、Reviewer APPROVE WITH NITS(3 should-fix 全清)、占位多敌渲染 + 人工 playtest 关1 通过(用户:「试玩后流程没有问题」)。
  **UI/juice(窄条排布/色辨识打磨)并入全局统一一轮。**
  - ✅ **关2 .tres 团战铺波(2026-06-20 收尾完成,原 Next①)** — num-smith 复算(BALANCE-CHANGE-05)→ Implementer author `stage_02.tres`:
    三普通场景改 `enemy_group`(Scene1 纯 3 近 / Scene2-3 各 2 近+1 远)、`kill_count` 7→6、新建 2 远程 `EnemyDef`(0.6× 同档近战)、Boss 不动;
    WAVE_SIZE≤4 故 `MAX_WAVE_SLOTS` 无需抬。新增锁波结构用例,gdUnit4 **153/153 绿**、**人工 playtest 关2 通过(用户:「试玩没问题」)**。关1+关2 团战体验现一致。
- ✅ **06-difficulty-progression(v1 闭环收口 —— 最后一件功能)**(2026-06-20)— 把"刷→调→再挑战"闭环真正闭上。
  **立墙**:关2 Boss 兽人酋长 `max_hp 220→480`/`attack 9→24`(纯 .tres 微调,BALANCE-CHANGE-04,双门槛 DPS+EHP)→ 玩家撞墙团灭软退、回城变强才推得过。
  **收口末关边界**(本功能唯一逻辑改动):`ProgressionController.advance_after_wave` Boss 分支按"有无下一关"分流(末关→`advance_target` 指回本关 Boss 循环陪伴,非越界空场)+ `begin_run` 越界游标夹回末关 Boss —— 补全不变量 #9 既存越界 bug,复用 FSM 不加新态、`max_unlocked` 记账语义不动。
  **三处占位呈现**:卡关可读文案 + GRINDING 回城邀请行 + 末关里程碑庆祝(`combat_view.gd` 纯只读表现)。
  gdUnit4 **152/152 绿、0 fail**(决策 B/C 各 +1 边界用例、立墙锁值用例;经手核 `reports/report_38/results.xml`)、Reviewer **APPROVE WITH NITS**(无 must-fix,2 should-fix 见下)、**手动 Play 验收通过**(撞墙软退 / 卡关可读 + 回城邀请 / 回城变强冲过 / 末关庆祝 + 终点循环不空场,用户:「手动 play 没有问题」)。
  **遗留(非阻塞,已落桶):① 关2 .tres 团战铺波 → Next;② 末关存档往返集成测试补网 → Later 技术债;③ 墙准度 playtest 主观校准 → v1 终验观察项。**

### V2 流程重构(逐块累积)
- ✅ **09-title-main-menu(流程重构第一块)**(2026-06-20)— 给"启动即开打"的悬浮窗补**前门 + 系统枢纽**:启动落居中主菜单窗(继续/新游戏/设置/退出)→
  选完**收缩成贴底条**进游戏;游戏中右上 `[☰]` 随时回主菜单(**设置/退出只此一处**)。把隐式 M2 游戏流程升为显式 `GameFlow` 协调节点
  (表现层,Boot→Title→Game{Explore↔Town}+MENU_OVERLAY)+ `floating_shell` 加 **MENU 几何态**(560×400 居中 ↔ 800×250 贴底)。
  守支柱 1:**Menu/Collapse 不暂停 sim**,仅 Town 暂停;破坏性动作(覆盖单档/退出)二次确认;Esc 统一返回上一层。
  六棒齐(UX→SMM→Arch REFACTOR-05→Planner→Implementer→EI):gdUnit4 **156/156 绿、0 orphan**、Reviewer **APPROVE WITH NITS**(无 must/should-fix)、
  EI **人手动 Play(D1-D9)验收通过**、步 6 回写三事实源(STATE-MACHINES/UX-MAP/ARCHITECTURE)🔜→现状。占位视觉(MENU 窗/四屏排布/`[☰]` 图标/strip↔MENU 过渡)并入全局 UI·juice 一轮(非阻塞)。

## Now(committed,当前在做 —— 一次只做一件)
- **🔧 整套交互流程重构(V2 主线伞)。** 目标:**点开→主菜单(新游戏/继续)→挂机↔城镇↔背包↔暂停/设置→存档退出**,
  把流程从布尔隐式(`town_root.visible`+`arena.running`,STATE-MACHINES §6.4)**逐块**升为显式 GameFlow。无上线压力,逐块收尾、做到完善。
  分工与推进顺序见 `test-2/doc/flow-state-rebuild-collaboration.md`(gitignore,过程参考)。
  - **第一块 ✅ `09-title-main-menu`(已收口,见 Done)** = 前门 + 系统枢纽:启动主菜单 / `[☰]` hub / 设置壳 / 真屏切换 / M2 显式化。
  - **➡ 第二块(当前 committed)`10-ingame-flow-nav` — 游戏内板块导航统一化。** 触发:09 立了前门与顶层 GameFlow,但**游戏内**各板块仍各自为政 ——
    城镇靠 `town_root.visible`、背包是临时只读面板、EXPLORE↔TOWN 仍由 TownView 自管(STATE-MACHINES §6 残债)。
    **范围(用户定 2026-06-20)= 整个游戏内流程结构**:① **新游戏落点**(新游戏 → 进哪个板块);
    ② 把**探索 / 城镇 / 背包**纳入 GameFlow 统一的"屏/板块"导航;
    ③ **每个板块之间切换的逻辑**(谁能到谁、切换时挂机暂停与否、回主菜单/暂停的接入点)显式化,清掉 §6 隐式状态债。
    *占位内容即可;**细则(落点、切换规则)继续与用户讨论**,属设计层 → 交 UX/SMM 定,Producer 不代为设计。*
    - **不**含(守一次一件,留后续块/Later):设置·暂停**屏内容实装**、存档管理/多档、招募/多职业/技能树/离线、UI·juice 上皮。
    - **三方分工**:`/role-ux-design 10-ingame-flow-nav` 出屏图+导航(`UX-MAP.md`)→ state-machine-master 把板块切换实现进 GameFlow 流程 FSM(`STATE-MACHINES.md`)→
      撞新结构(ScreenManager / 屏挂载)转 arch-guard 定结构(`ARCHITECTURE.md`/REFACTOR-NN)→ Planner/Implementer 落地。
    - **下一步**:开 `/role-ux-design 10-ingame-flow-nav` 画屏图(先和用户敲定新游戏落点 + 板块切换细则)。
- (背景)V1 功能切片已全部 done(01/02/03/00/04/05/08/06):"挂机探索→掉装→回城变强→打过更硬的怪"闭环可端到端验。

## Next(排队中,按优先级)
1. **全局 UI / juice 统一一轮(V2 打磨 —— ⏸ 排在流程重构的屏/界面结构落地之后)。** 因「整套流程重构」会改屏/界面结构,
   提前上皮会返工 → **排在流程 FSM + 屏挂载结构落地之后**再做。内容不变:开 `/role-art-spec` 统一定
   `Theme`/`NinePatchRect`/图标 + 反馈 juice,覆盖 05 城镇 / 04 掉落面板 / 02 战斗演出 / 06 三处占位呈现 / 08 团战窄条排布·近远色辨识
   +(新增)主菜单/暂停/设置等流程屏。关2 铺波数值已定稿(BALANCE-CHANGE-05)。
   *诚实提示:无 deadline,故这步不是"上架前最后一段",而是 V2 完善的一环;守"统一一轮、非逐功能上皮",做完即收。*

## Later / v2(明确推后,已停车未杀)
- 招募系统 / 坦克·法师·射手·牧师等其它职业 / 4 人实际组队 build 深度
- **等级 / 经验系统** —— 击杀给经验、升级长 HP/攻击。源:02 playtest(2026-06-18)。地基已备:`Character` 加 level 字段 +
  成长曲线(走 Resource),存档持久层已就位(`00`)。需 Game Designer 定经验来源 / 升级曲线 / 升哪些属性。
- 技能树与技能升级
- 多探索区域 / 更多 Boss
- 离线结算(完全关闭程序后的收益)—— 现有最简存档是其前置,已就位。
- 套装、宝石、复杂词条池(超出已扩 6 维的)、词条重铸
- **全局 UI / juice 统一一轮(用户拍板 2026-06-19)** —— 各功能(城镇换装/对比/强化、战斗、掉落面板)现为**占位程序美术**(裸 Button/Label/ColorRect),
  能验收功能即可。界面皮(`NinePatchRect` + 统一 `Theme` + 图标排版)与反馈 juice(换装绿闪 / 强化特效 / 音 / 对比差值显形)**留到 v1 功能全做完后开 Art Spec 统一做一轮**,不逐功能上皮。
  Why: 垂直切片 + solo,逻辑对了再统一上皮避免返工、避免每功能停下打磨拖慢闭环。涵盖 05 城镇 UI(FEATURE-DESIGN §4)、04 掉落面板、下条 02 战斗演出。
- **02 横版战斗演出打磨** —— 怪精灵、攻击/受击动画、伤害飘字、掉落迸出等全套表现(`AnimationComponent` 挂点已在地基内,差正式素材)。
  符号/轻演出版验证乐趣后再上;属打磨而非核心验证,并入上条「全局 UI/juice 统一一轮」或正式美术阶段再做。
- 透明窗 / 点击穿透 / 多显示器精细适配
- **全局热键(失焦时也响应 F1/F2)** —— 需 OS 级注册或插件(撞 hard-NO);本期点 handle / 收起按钮已够用。
- Linux / Mac 平台
- **[技术债] 末关存档往返集成测试补网(06 REVIEW should-fix②)** — 不变量 #9 末关边界的"通末关 Boss→存档→重 boot→`begin_run` 夹回"全链路缺 GameController 级端到端用例(夹值已由 `progression_test` 单测覆盖,逻辑已对)。非阻塞;未来动 `_boot`/`begin_run` 任一端时这条路径会无回归网,届时随手补一条 `game_controller_test` 即可。源:06 REVIEW(2026-06-20)。

## Cut(决定不做,附理由)
- (暂无)—— 目前没有被否决的想法;新想法默认进 Later 而非直接 Cut。

## Decision log
- 2026-06-17 — v1 定为"单战士垂直切片",招募/多职业/组队深度推到 v2。
  Why: 完整愿景对独游过大;先用 1 个战士跑通完整闭环验证核心乐趣(支柱 1+2)。队伍数据按 4 格设计,日后加人不必重写地基。
- 2026-06-17 — Now 第一项 = 悬浮窗外壳(01),先于战斗循环。Why: 悬浮窗是项目最大技术未知数,也是支柱 1 的物理载体。
- 2026-06-17 — "后台持续推进"列 MVP 必须;"离线结算"推到 v2。Why: 后台推进是"挂机"本质;离线结算只是增强,可后补。
- 2026-06-18 — 01 验收完成移入 Done;Now 推进 02。
- 2026-06-18 — "全局热键(失焦也响应)" → Later/v2。Why: 不阻塞 v1;真全局热键需插件,撞 hard-NO。
- 2026-06-18 — **02 演出粒度 = 符号/轻演出版(simplify);横版全套演出 → Later。** Why: 02 核心验证是"循环像不像好伙伴"而非美术。
- 2026-06-18 — **02 playtest 两条新想法 → Later/v2:** ① 等级/经验、② 车轮战→团战。Why: 都非 02 核心验证必要件,默认偏 LESS。
- 2026-06-18 — 02 验收完成移入 Done;Now 推进 03(后顺延为 04 前置)。
- 2026-06-18 — **03 拆两块、扩战斗公式提前做(推翻同日初裁)。** Why: 词缀是装备核心一半,趁干净 refactor 更省事。
  落地:新建 `03-combat-formula-ext` 在前,原 03-loot 顺延为 `04-loot-equipment`。
- 2026-06-18 — 03 验收完成移入 Done;Now 推进 04。
- 2026-06-18 — **[B1] 04/05 边界右移:手动换装 + 对比面板从 04 挪到 05,04 只做只读掉落包。** Verdict: 简化+去重(批准)。
- 2026-06-19 — **`00-foundation-redesign` 整体地基重构完成,移入 Done(cross-cutting)。**
  Why: 04 装不进旧 director(God object,无持久/属性分层/单敌硬编码,REFACTOR-01 §2)→ 用户决定整体重铺。
  时机最干净(04 未实现、无存档历史、无玩家数据迁移)。交付四层架构 + 组件化 + 持久层 + 掉落后端 + lane 多敌引擎 +
  存档 round-trip,全套 117/117、§F 人验通过。**这是已付出的大投资;后续应推向"让可见循环上架",避免再起大重构。** 来源:REFACTOR-01 + EI §F 验收。
- 2026-06-19 — **04-loot-equipment 收窄为"表层 + 数值定稿"(用户拍板)。** Verdict: simplify(批准)。
  Why: 掉落/装备/词缀**后端已随 `00` 落地并持久化**,04 再从头实现会与已落地代码大量重复(撞 hard-NO「勿过度/勿重复」)。
  04 留两件未竟:① 掉装→变强在悬浮窗里**看得见**(只读掉落包/背包面板 + 变强反馈)② 词缀/掉落**数值定稿**(现占位)。
  旧 04 设计/计划/勘探 artifact 标 superseded(假设旧结构)。来源:用户(AskUserQuestion)。
- 2026-06-19 — **v1 完成定义纳入「团战 / 多敌同屏」(用户拍板),`车轮战→团战` 从 Later 提升进 v1(新功能 `08-team-combat`)。**
  Verdict: now(进 v1 Next)。Why: `00` 已把 lane 多敌引擎做进地基(`CombatArena.enemies` 数组化、`Entity` 通用),
  提前成本从"中等重构"降为"加设计 + 配置"。**诚实权衡(Producer 提示):** 仍非零成本——需 Game Designer 定目标选择规则
  (集火/分散/AoE)+ 配多敌关卡 + tuning,会推迟上架;玩家侧仍 4 格(v1 填 1 战士),团战 = 敌方一波多敌。
  排在 05 之后、06 之前。来源:用户(AskUserQuestion)。
- 2026-06-19 — **07-save-load(最简版)实质已交付、并入 `00`,不单列新功能。** Verdict: done-by-foundation。
  Why: foundation `SaveSystem` 已落 roster/背包/材料/进度 round-trip,§F 人验通过;多档/云存档原本就在 v1 外。
- 2026-06-19 — **03-combat-formula-ext 成果被 `00` 承接(非废弃),无需任何后续。** Verdict: carried-over(已 done,留痕)。
  Why: 03 本体 2026-06-18 已收口(done);REFACTOR-01 把 6 维公式搬入 `SkillComponent`、**公式断言值作为重构回归锚**(值不变),
  仅承载结构由单敌 director 改为 lane 多实体 + 组件。与 07 不同:07 是"未单独实现、后端被吸收";03 是"先独立做完、成果再被承接"。
  03 目录留作设计/历史档,不再单独推进。来源:`03-combat-formula-ext/HANDOFF.md` + REFACTOR-01 §4/§5。
- 2026-06-19 — **04-loot-equipment 收口移入 Done。** Verdict: done。Why: 表层只读双栏面板 + 数值定稿(rarity 加权 + item_level 阶梯)全落地,
  gdUnit4 123/123、Reviewer APPROVE(should-fix 已闭)、人验 6 条通过。BACKLOG "Now" 此前未及时刷新(滞留 04),本次校正。
- 2026-06-19 — **05-town-gear-upgrade 收口移入 Done。** Verdict: done。Why: 手动换装 + 对比面板 + 确定性强化全链路落地,六棒齐,
  gdUnit4 145/145 绿、EI 接线人验通过。后端持久层(roster/背包/材料)复用 `00`,新增强化经同一 `to_modifiers(source=self)` 缝(守不变量)。
- 2026-06-19 — **全局 UI/juice 推迟到 v1 功能全完成后统一做一轮(用户拍板)。** Verdict: Later(统一一轮,非逐功能)。
  Why: 各功能现用占位程序美术跑通功能即可;垂直切片 + solo,逻辑对了再统一上皮可避免返工、避免每功能停下打磨拖慢核心闭环验证。
  涵盖 05 城镇 UI、04 掉落面板、02 战斗演出;待功能闭环完成后开 Art Spec。来源:用户(05 EI 验收后拍板)。
- 2026-06-19 — **08-team-combat 升为当前 Now(04+05 done 后顺位)。** Verdict: now。Why: v1 余下功能仅 08(团战)+ 06(难度收口);
  08 排 06 之前(06 依赖团战到位才好验闭环)。下一步 `/role-game-designer 08-team-combat`。
- 2026-06-20 — **08-team-combat 收口移入 Done。** Verdict: done。Why: REFACTOR-04 落地(刷怪/推进 per-enemy→per-wave,#12)+
  近战门控/远程隔位 + 关1 .tres 铺波,gdUnit4 144/144、Reviewer APPROVE(3 should-fix 全清:GUIDE 同步 / 死代码标注 / MAX_WAVE_SLOTS 防呆)、
  占位多敌渲染 + 人工 playtest 关1 通过(用户:「试玩后流程没有问题」)。**关2 .tres 复算与团战视觉打磨分别并入 06 / 全局 UI 轮,不阻断 08 收口。**
- 2026-06-20 — **06-difficulty-progression 提进 Now(08 done 后,v1 最后一件功能)。** Verdict: now。Why: 前置(04 表层 + 05 换装 + 08 团战)
  全部 done,"刷→调→再挑战"闭环现可端到端验;06 是 v1 垂直切片的收口件(点亮支柱 2)。下一步 `/role-game-designer 06-difficulty-progression`。
  **诚实提示(Producer):** 06 done 后 v1 功能即齐 —— 届时余下只剩「全局 UI/juice 统一一轮」(Later,非功能),应避免在 06 里夹带难度曲线精调/多区域(守 LESS,留 v2)。
- 2026-06-20 — **06-difficulty-progression 收口移入 Done —— v1 功能切片全部完成。** Verdict: done。
  Why: 立墙(关2 Boss hp480/atk24,BALANCE-CHANGE-04 双门槛)+ 末关边界收口(决策 B/C 补不变量 #9 既存越界 bug,复用 FSM 不加新态、`max_unlocked` 记账不动)+ 三处占位呈现;gdUnit4 152/152 绿、Reviewer APPROVE WITH NITS(无 must-fix)、手动 Play 验收通过(用户:「手动 play 没有问题」)。"刷→调→再挑战"闭环至此端到端闭合,支柱 2 点亮。来源:06 HANDOFF + REVIEW + 用户手动 Play。
- 2026-06-20 — **关2 .tres 团战铺波 = 独立后续任务,进 Next(非进 06)。** Verdict: next(v1 收尾)。
  Why: 08 只 author 了关1 多敌波,关2 仍单敌;用户拍板 06 不扩范围、铺波单列。structure 已就绪,待办 = num-smith 定波数值 + author + 必要时抬 `MAX_WAVE_SLOTS`。**不阻塞 v1 可玩闭环(团战系统已在关1 验证),属内容补齐。** 来源:用户(2026-06-20)。
- 2026-06-20 — **全局 UI/juice 统一一轮前置已满足(v1 功能全完成),自 Later 提示为 Next 主线。** Verdict: next(收尾主线,待关2 铺波数值定稿后启动)。
  Why: 此前"留到功能全做完后统一做一轮"的条件现已达成 → 这是迈向可上架 v1 的主要剩余工作。仍守"统一一轮、非逐功能上皮";建议排在关2 铺波之后,免对未定稿内容上皮返工。来源:Producer(承 2026-06-19 用户拍板)。
- 2026-06-20 — **06 REVIEW should-fix②(末关存档往返集成测试)→ Later 技术债。** Verdict: later(不阻塞)。
  Why: 夹值逻辑已单测覆盖、手动 Play 验过;缺的是端到端回归网,属补网而非缺陷。停车不杀,动相关代码时随手补。来源:06 REVIEW。
- 2026-06-20 — **关2 .tres 团战铺波收尾完成,移出 Next → Done(归 08)。** Verdict: done。
  Why: num-smith 复算(BALANCE-CHANGE-05:WAVE_SIZE 统一 3、`kill_count` 6、2 远程 0.6× 同档近战、Scene3 实算从预览 4 收到 3 防 P1-基线团灭)
  → Implementer author `stage_02.tres` 纯数据(保留 `enemy` fallback)+ 新增锁波结构用例;gdUnit4 **153/153 绿**、`MAX_WAVE_SLOTS` 无需抬(WAVE_SIZE≤4)、
  **人工 playtest 关2 通过(用户:「试玩没问题」)**。至此关1+关2 团战体验一致 = **v1 功能与内容全部就绪**。来源:BALANCE-CHANGE-05 + 08 CHANGES 补遗 3 + 用户试玩。
- 2026-06-20 — **全局 UI/juice 统一一轮升为 Next 唯一主线(关2 铺波 done 后)。** Verdict: next(可上架 v1 的最后一段)。
  Why: v1 功能与内容均已就绪、数值已定稿,此前"待关2 铺波定稿后启动"的前置已清 → 可直接开 `/role-art-spec`。守"统一一轮、非逐功能上皮"。来源:Producer。
- 2026-06-20 — **新提案「整套交互流程重构」设为当前焦点(Now),scope 待 Producer 细化;原 UI/juice 一轮顺延到屏结构定下后。** Verdict: now(scope 研究中)。
  Why: 用户指出游戏**完全没有交互状态设计** —— 无主菜单/暂停/真屏切换,流程靠布尔隐式硬撑(STATE-MACHINES §6.4)。这是新功能体量、会动地基结构,
  超出"UI/juice 一轮"。state-machine-master 据 role 升级规则 flag 给 Producer 做 scope call;流程重构会改屏结构,故 UI/juice 应顺延其后免返工。
  ⚠ **本条目 + Now + UI/juice 顺延均由 state-machine-master 代为占位录入,scope/优先级细则由即将开启的 Producer session 拍板覆盖。**
  分工/推进顺序见 `doc/flow-state-rebuild-collaboration.md`(gitignore)。来源:用户(2026-06-20)。
- 2026-06-20 — **【Producer scope call】V1 里程碑收口 → 进入 V2;无上线时间线压力,做到完善再推。整套流程重构 = V2 第一件,committed now。** Verdict: now(V2)。
  Why: 用户拍板"没有时间线压力,V1 算收口也可以,重构算 V2 开始,到 V 几无所谓,完善了再推"。→ 先前"流程重构进 v1.5/上架前/v2"的纠结**取消**(无 deadline 则此问题不成立),
  直接定为 V2 第一件正式工作、可立即开 UX,无需再等。**Producer 纪律收紧点**:无 deadline 时真正风险 = 范围蔓延 / 永不收尾,故 ① 流程重构**严格限定流程/屏/状态结构**,
  不捆绑 Later 的招募/多职业/技能树/离线等大件;② 守"一次一件"、逐块收尾。UI/juice 一轮重定性为 V2 打磨、排在流程结构落地之后(免返工)。来源:用户(2026-06-20)。
- 2026-06-20 — **09-title-main-menu(流程重构第一块)收口移入 Done。** Verdict: done。
  Why: 前门 + 系统枢纽全链路落地(GameFlow 显式化 + MENU 几何态 + 四屏 show/hide + 二次确认 + Esc 统一),gdUnit4 156/156、Reviewer APPROVE WITH NITS
  (无 must/should-fix)、EI 人手动 Play(D1-D9)验收通过、步 6 三事实源回写完成。守支柱 1(Menu/Collapse 不暂停 sim)。占位视觉并入全局 UI·juice 轮(非阻塞)。
  来源:09 HANDOFF/REVIEW/INTEGRATION-STEPS + 用户手动 Play。
- 2026-06-20 — **【scope call】流程重构第二块 = `10-ingame-flow-nav`(游戏内板块导航统一化),committed now。** Verdict: now(V2)。
  Why: 用户拍板下一块推"城镇/背包纳入统一屏导航",范围 = **整个游戏内流程结构**(新游戏落点 + 探索/城镇/背包纳入 GameFlow 统一导航 + 各板块切换逻辑显式化,清 §6 隐式状态债)。
  **Producer 边界(守一次一件/V2 纪律)**:本块**只**做游戏内板块导航的流程/屏/状态结构,占位内容即可;**不**捆绑设置·暂停屏内容实装、存档管理/多档、招募/多职业/技能树/离线、UI·juice 上皮 —— 各自留后续块或 Later。
  落点与切换细则属设计层,交 UX-design/SMM 与用户继续敲定,Producer 不代为设计。下一步 `/role-ux-design 10-ingame-flow-nav`。来源:用户(AskUserQuestion,2026-06-20)。
