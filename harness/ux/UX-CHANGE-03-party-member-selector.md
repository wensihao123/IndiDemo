---
artifact: UX-CHANGE
feature: 10-ingame-flow-nav
role: UX Design
status: draft
updated: 2026-06-20
inputs: [UX-MAP.md, BACKLOG.md, project-context.md, harness/features/10-ingame-flow-nav/INTEGRATION-STEPS.md, harness/features/10-ingame-flow-nav/CHANGES.md, src/combat/town_view.gd, src/core/meta/character.gd, src/core/meta/player_state.gd]
next: Producer(full 选择器 gated 招募功能)/ Implementer(interim 标签,已由 EI-F1 spec 在途)
---

# UX-CHANGE-03 · 城镇小队/工匠子板块的「成员轴」(member selector)

## 1. 触发 / Trigger
10-ingame-flow-nav 表现层 Play 手验,EI 记录 **EI-F1**:打开**小队换装**(及同构的**工匠强化**)overlay
直接铺装备槽 + 背包,**看不出在编辑哪个队员**。代码层 `town_view.gd:94 _hero()` 写死取 roster 首个非空
成员,小队/工匠两板块均绑它,**无成员选择器**。v1 单战士不出错;招募(多成员)落地后会静默永远编辑
0 号成员且玩家无从知道/无从切换。

## 2. 现状诊断 / Diagnosis(根因)
小队 / 工匠两个城镇子板块的**交互模型缺一个"成员轴"**。当前导航层级:
`城镇枢纽 → 子板块(overlay) → [槽位 × 装备/强化/对比]`。
但 `project-context.md` 核心系统 #1 = **「4 人队伍按 4 格 slot 设计」**,roster 终态是 1–4 个成员;
换装/强化本质是**每成员一份**的操作。现有交互把"成员"这一维**隐式塌缩成 `_hero()`(永远第 0 个)**。

**根因**:小队/工匠 overlay 设计时**假设了单成员,没把"先选哪个队员、再调他的装备"这层导航建进去**。
这不是 10-ingame-flow-nav 引入的缺陷(它复用既有单成员换装逻辑),而是**换装/强化交互从立项起就缺成员轴**,
被 v1「只填 1 人」掩盖。UX-MAP §3 城镇 Town 已隐约记了「v1 操作首个非空战士的三槽」,但从未把成员选择
当成一个交互维度设计过。

> **⚙ 几何细化(UX-CHANGE-04 §3.1,2026-06-20)**:full 形态的成员选择器**由"顶部 tab-row"改定为
> "左列成员栏"**(更宽裕、合用户参考图)。本文以下"tab-row"读作"左列成员栏";interim 标签与
> deferred-到-招募-v2 的结论均不变,仅几何位置细化。

## 3. 目标形态 / Target flow(delta vs UX-MAP §3 城镇 Town)
在**小队**与**工匠** overlay 顶部新增一条**成员选择器(member tab-row)**:
- 一行最多 **4 个成员条目**(职业图标/头像 + 名字,占位即可),对应 roster 4 格;**空位**显占位、灰、不可点。
- 点某成员 = 设「当前编辑成员」,**下方 [槽位 × 装备/强化/对比] 全部 rebind 到该成员**;选中态高亮。
- 进 overlay 默认选中**首个非空成员**(沿用现 `_hero()` 落点 → 零改面、与现状一致)。
- **小队与工匠共用一个 town 级「当前编辑成员」**:玩家在小队选了 A,切到工匠仍是 A(跨子板块保持,符合
  "我在打理 A 这个人"的心智)。出征/酒馆 overlay 是**关卡轴/占位**,不受成员轴影响。

**新增/变更交互态(小队 & 工匠)**:
- `成员选择器·单成员`(roster 仅 1 非空)→ **退化为一个不可切的「当前编辑:<名>」标签/单 tab**
  —— **这正是 EI-F1 裁决的"当前成员标签",是选择器在 1 成员时的退化态,前向兼容、非废弃过渡。**
- `成员选择器·多成员`(2–4 非空)→ tab-row 可点切换,选中高亮。
- `空位`(roster 该格为空)→ 灰、不可点的占位条目。

## 4. 调整策略 / Strategy(分两期,按 scope 切)
1. **interim(本块即时,已在途)= 当前成员标签**:小队/工匠 overlay 顶部显「当前编辑:<成员名>」。
   = 选择器的单成员退化态。**EI 已把精确落码 spec 交 Implementer(见 10-ingame-flow-nav INTEGRATION-STEPS
   「EI-F1」:插在 `_rebuild_slot_selector` 顶部,小队/工匠共用该函数 → 一处生效两板块)。** 本期到此为止。
2. **full(成员选择器·多成员)= deferred 到招募/多成员功能(v2)**:把第 1 步那行标签**原地升级**为可点
   tab-row + town 级「当前编辑成员」寄存器 + 下方控件 rebind。**不在 v1/本块范围,不交 Planner 立即建。**
   招募功能开工时,本文 = 成员轴交互蓝图。

> **升级连续性(关键)**:只要 interim 标签放 overlay 顶部同一处、以 `_hero()` 为默认成员,招募时把标签
> 换成 tab-row 即可,**无返工**。EI-F1 spec 已与此对齐。

## 5. 影响面与迁移 / Blast radius
- **屏/overlay**:仅城镇 **小队 + 工匠** 两 overlay 顶部各加一行;**不新增屏、不改 §2 顶层导航图、不动
  Flow FSM**。成员选择是 overlay 内**比四子板块更细一层**的控件态,远在 GameFlow `{TOWN}` 之下 →
  **STATE-MACHINES.md 无需变**(成员轴不是 Flow 态,与四子板块=overlay 同理,只是更细)。
- **共享状态**:full 期需一个 town 级「当前编辑成员」寄存器(TownView 持有,跨小队/工匠共享)。属
  **实现细节非新结构**;interim 标签(单成员)**不需要**寄存器。若招募期要把"当前成员"提升为更广概念
  → 那时由 **arch-guard** 看,**本期不触发**。
- **Art Spec**:成员 tab-row 视觉(职业图标/头像、选中高亮、空位样式)= 招募轮 + 全局 UI·juice 轮;
  **interim 标签是纯文字占位,本期无视觉需求**。
- **数据**:roster 是 `Array[Character]`(`player_state.roster`),`Character.display_name` 即成员名;
  tab-row 直接遍历 roster 即可,无数据迁移。

## 6. 风险与被否选项 / Risks & rejected
- **被否①·每个槽位都标成员名,不加顶部选择器**:啰嗦,且仍**无法切换**成员——治标不治本。
- **被否②·每个成员开独立 overlay/屏**:过度;4 人换装本质是同一界面换数据源,tab-row 足矣,且违反
  "窗口小、低负担、余光可读"(支柱 1)。
- **被否③·现在就做完整选择器**:违反 scope(招募 = v2/Later,BACKLOG line 105/126)+ hard NO
  「不为没影的后期系统提前抽象」。故**只做 interim 标签、把 full 设计存档备用**。
- **风险·升级返工**:已用"标签 = 选择器单成员退化态 + 同位置 + 同默认成员"消解(见 §4 连续性)。
- **风险·小队/工匠"当前成员"是否真该共用**:倾向共用(心智 = 打理同一个人);若 playtest（招募后）
  发现各自独立更顺,改寄存器作用域即可——留待招募期 GD/playtest 定,不锁死。

## 7. 交接 / Handoff
- **interim 标签** → **已由 EI-F1 spec 交 Implementer**(本块 `/role-implementer 10-ingame-flow-nav`),
  **无需 Planner 另起**。落码后作者 Play 验小队/工匠顶部均显成员名即收。
- **full 成员选择器** → **flag Producer**:归入**招募/多成员功能(v2)**;该功能开工时本 UX-CHANGE-03 =
  成员轴交互蓝图,届时 `/role-planner <招募slug>` 落地、`/role-art-spec` 出 tab-row 视觉。
- **State Machine Master**:无需动作(成员选择在 Flow 态之下,STATE-MACHINES 不变)。
- UX-MAP.md 已据本文更新:§3 城镇 Town 记成员轴 + 两期交互态;§6 新增债 #9(planned in UX-CHANGE-03)。
