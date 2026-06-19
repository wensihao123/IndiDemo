---
updated: 2026-06-19
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

## Now(committed,当前在做 —— 一次只做一件)
1. **04-loot-equipment(已收窄为「表层 + 数值定稿」)** — 后端(掉落 roll / `ItemInstance` / 词缀分阶 / 自动填空槽 /
   自动分解 / 装备组件)已随 `00` 落地并持久化。04 收窄为两件:
   - **① 掉装→变强「看得见」**:悬浮窗里一个**只读掉落包 / 背包查阅面板**(查阅掉了什么、当前穿戴),
     + 让玩家感到"变强了"的反馈(属性/战力可见)。这是支柱 2 在 v1 的高光落点。
   - **② 数值定稿**:词缀数值 / 掉落概率 / 稀有度梯度 / slot·rarity 选择规则——现为占位(随机),需定稿。
   - **旧 `FEATURE-DESIGN.md` / `PLAN.md` / `CONTEXT-FINDINGS.md` 标 superseded**(它们假设旧 director 结构;后端已由 `00` 以新架构实现)。
   - 下一步:`/role-game-designer 04-loot-equipment` 重新收敛——只收"表层 UI + 数值定稿"的剩余线头,**不重做已落地后端**(守 hard-NO「勿过度/勿重复」)。

## Next(排队中,按优先级)
2. **05-town-gear-upgrade** — 城镇最简版:**手动换装 + 对比面板(逐项差值绿↑红↓)** + 1 个最简打造/强化(材料 +1 武器)。
   - 持久层 roster/背包/材料已由 `00` 就位;主动构筑的高光时刻集中在回城。
   - 不含:招募、技能升级、其它打造线。
   - **〔触发复审〕** 05 需在战斗外读写 roster/模板 → `DataRegistry` 由单消费者变多消费者,届时复审其座位(升 autoload vs 注入,见 ARCHITECTURE.md §6)。
3. **08-team-combat(多敌同屏 —— 自 Later 提升进 v1,用户 2026-06-19 拍板)** — 敌方**一波多敌同时打**(车轮战→团战)。
   - lane 多实体引擎已在地基内(`CombatArena.enemies` 已是数组、`Entity` 通用)→ 余下主要是**设计 + 配置**:
     Game Designer 定**目标选择规则**(集火 / 分散 / AoE;现 `AICombatComponent` 占位"打最前存活")+ 配多敌关卡(`SceneConfig` 多敌)+ tuning。
   - 玩家侧仍 4 格(v1 填 1 战士);"清场/一轮"按整波重定义。掉落/团灭回退/解锁/倒计时只认事件,基本不动。
   - 下一步:`/role-game-designer 08-team-combat` 定目标选择规则与波次。
4. **06-difficulty-progression** — 闭环收口:变强后能打过一个更硬的怪 / 更难一波。
   - 自然排末位(依赖 04 表层 + 05 换装 + 08 团战 到位才好验"刷→调→再挑战"闭环)。
   - 不含:难度曲线精调、多区域。

## Later / v2(明确推后,已停车未杀)
- 招募系统 / 坦克·法师·射手·牧师等其它职业 / 4 人实际组队 build 深度
- **等级 / 经验系统** —— 击杀给经验、升级长 HP/攻击。源:02 playtest(2026-06-18)。地基已备:`Character` 加 level 字段 +
  成长曲线(走 Resource),存档持久层已就位(`00`)。需 Game Designer 定经验来源 / 升级曲线 / 升哪些属性。
- 技能树与技能升级
- 多探索区域 / 更多 Boss
- 离线结算(完全关闭程序后的收益)—— 现有最简存档是其前置,已就位。
- 套装、宝石、复杂词条池(超出已扩 6 维的)、词条重铸
- **02 横版战斗演出打磨** —— 怪精灵、攻击/受击动画、伤害飘字、掉落迸出等全套表现(`AnimationComponent` 挂点已在地基内,差正式素材)。
  符号/轻演出版验证乐趣后再上;属打磨而非核心验证,正式美术阶段或单独立项再做。
- 透明窗 / 点击穿透 / 多显示器精细适配
- **全局热键(失焦时也响应 F1/F2)** —— 需 OS 级注册或插件(撞 hard-NO);本期点 handle / 收起按钮已够用。
- Linux / Mac 平台

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
