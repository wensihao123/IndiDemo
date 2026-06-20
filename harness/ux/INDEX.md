# UX 跨功能交互调整索引(UX Design)

> UX-MAP.md(harness 根)= 交互事实源。本目录放跨功能的 UX-CHANGE 调整方案。

- [UX-CHANGE-01 · Title/主菜单/设置](UX-CHANGE-01-title-main-menu.md) — 补前门+系统枢纽:启动居中菜单窗→收缩成条、`[☰]`可随时回。**accepted**(已与 STATE-CHANGE-01 / REFACTOR-05 对齐)→ Planner(挂 09-title-main-menu)。
- [UX-CHANGE-02 · 游戏内板块导航(城镇为家·枢纽+四子板块)](UX-CHANGE-02-ingame-flow-nav.md) — 城镇(家·枢纽)↔探索(派出挂机)、新游戏/继续都落城镇枢纽(暂停)、城镇升枢纽+四覆盖式子板块(工匠/小队/酒馆〔占位〕/出征〔关卡选择〕)、背包拆解(探索掉落预览/城镇小队换装+工匠)、新增「待回城」标记、EXPLORE↔TOWN 收进 GameFlow。**draft**(2026-06-20 按用户 Game-flow-ideas 重做)→ State Machine Master(挂 10-ingame-flow-nav)。
- [UX-CHANGE-03 · 城镇小队/工匠的「成员轴」(member selector)](UX-CHANGE-03-party-member-selector.md) — 小队/工匠 overlay 缺成员选择器(`_hero()` 写死取首个非空成员,多成员落地后静默永编辑 0 号)。分两期:**interim=当前成员标签**(单成员退化态,EI-F1 spec 已交 Implementer,本块在途)/ **full=成员选择器,deferred 到招募/多成员 v2**(几何 = 左列成员栏,已由 UX-CHANGE-04 §3.1 细化)。触发=10-ingame-flow-nav Play手验 EI-F1。**draft**(2026-06-20)→ interim 交 Implementer(无需 Planner);full flag Producer(gated 招募)。
- [UX-CHANGE-04 · 城镇枢纽 + 五子板块布局重设计(按参考图)](UX-CHANGE-04-town-boards-layout.md) — 据用户 6 张参考图(城镇/小队/打造/出征/酒馆/背包)把枢纽 + 五板块从抽象占位细化为每板块 IA(分区+导航+态),逐区标注"映射现有/仅参考·略"(货币·收益秒·每日任务·制作·技能·成功率·自动战斗开关均无系统→预留不建)。**= 全局 UI·juice 轮布局蓝图**。**draft**(2026-06-20)→ 主交付 Art Spec;少量新信息位(出征敌人/掉落预览·战力派生)交 Planner;窗口几何 flag SMM+用户。
