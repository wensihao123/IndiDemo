---
feature: 00-foundation-redesign
status: done
updated: 2026-06-19
---
# HANDOFF — 底层地基重构执行 (Foundation Redesign · Execution Home)

> ✅ **DONE(2026-06-19):REFACTOR-01 底层地基重构端到端完成。** 全套 **117/117、0 orphans**;
> 引擎侧切换(Combat→Game autoload + 删旧 director + 退役旧测)经 EI §A–§F 验收通过;§F 手动 Play
> 存档 round-trip 经人确认(通关 Boss→关→重开续到下一关、不重打 Boss,F-SaveBoss 修复实游戏生效)。
> 表现层读 `Game.arena/progression`、`GameController` 装配驱动、`SaveSystem` 落盘 `PlayerState`+进度,旧 director 退场。
> 事实源(ARCHITECTURE.md)+ 人类导读(ARCHITECTURE-GUIDE.md)均已对齐落地代码。
> **下一棒(非本功能):** Producer 回写 scope(BACKLOG + project-context §2 目录约定 / v1 完成定义)→ 05-town。
>
> ──────── 以下为历史执行日志 ────────
>
> **(2026-06-19):第三批步 1-4 已由 Implementer 落地交付(CHANGES-batch3.md)。** 全套
> **153/153、0 errors/0 failures/0 orphans**(140 + 13 新)。旧 director/`project.godot`/45 旧测一字未动(并存式守住)。
> CombatView 已原地改读 `/root/Game`,编译过;游戏暂中间态不可 Play(autoload 仍 Combat),Play 验收并入步 5。
> **新提 〔F-PS-autoload〕**:PLAN 步 5.1 列注册 PlayerState autoload,但本批 GC 自持 player_state → 直接注册会二重;
> 建议步 5 不注册 PlayerState autoload(全经 `Game.player_state`),详见 CHANGES-batch3 §4.1/§6。
> **Reviewer 已审(2026-06-19,REVIEW-batch3.md):APPROVE WITH NITS,0 must-fix。** 独立重跑 153/153 0 orphans、
> CombatView 单独编译过 + 空守卫确认、并行造桥(旧 director/project.godot/45 旧测)守住。**留 1 条 should-fix S1
> 〔自动穿装不回写 Character、重载即丢,loot_intake.gd:14-16〕——须在步 5 手测前当面拍板**(本缝步 5 一并补,
> 还是明确接受 v1 手测先不验掉装持久化);+ 3 nits 放行。
> **S1 已修(2026-06-19,Implementer,CHANGES-batch3-s1.md):** 用户拍方案 B(存档收口)—— `GameController._autosave()`
> 落盘前调 `_sync_party_equipment()`,把活体 Entity 的 `EquipmentComponent` 快照回 `Character.equipped`(含卸下边界 erase)。
> 全套 **155/155 0 orphans**(+2 新测:穿装重 boot 仍在 / 局内脱下收口清槽)。自动穿装持久化缝已闭。
> **S1 已审(2026-06-19,REVIEW-batch3-s1.md):APPROVE WITH NITS,0 must-fix / 0 should-fix。** 独立重跑 155/155 0 orphans、
> 方案 B 忠实度 / 写穿持久层 / 卸下边界 / 测试可证伪性逐条核过;仅 2 条信息性 nit(ItemInstance 别名共享当前无害、
> arena==null 防御冗余),均无需动作。
> **步 5 已出 INTEGRATION-STEPS(2026-06-19,Engine Integrator):** 编辑器侧切换清单(切 autoload / 删 3 src /
> 退役 7 旧测 / 全回归 / 手动 Play + 存档 round-trip)已就绪。**但用户拍 F-PS-autoload = 方案 C(注 PlayerState
> autoload + 改 `_boot` 复用 `/root/PlayerState`)→ 引入一处先决代码改(超 EI 职责)。**
> **Arch Guard 已拍 F-Arch-seat(2026-06-19,arch/REFACTOR-02-playerstate-seat.md):拆座 = PlayerState 升 autoload
> 正确**;钉死访问约定 + reset-on-boot 测试隔离;顺带纠 `DataRegistry` 事实源回 "Game 持有·RefCounted"。
> **Planner 已落 §0 PLAN(2026-06-19,PLAN-batch3-s0.md):** 4 步——`PlayerState.reset()` → 附加注册 `Player` autoload
> → `_boot` 改读 `/root/Player`+reset-on-boot → 测试隔离收口,全套回 155/0 orphans。
> **⚠ Planner 实证捕到 INTEGRATION-STEPS §A 一处会编译失败的缺陷:autoload 名不能填 `PlayerState`**(撞 `class_name
> PlayerState`,Godot 4.6.3 `--import` 报 `hides an autoload singleton`)→ **节点名改 `Player`(类型仍 PlayerState),
> 同 `Game`/`GameController` 先例**(F1,需回写事实源 + §A 措辞)。另 §0 把**附加可逆**的 `Player` 注册前移给 Implementer,
> 不可逆的 `Combat`→`Game` 切换 + 删档仍归 EI(F2,重切 §A)。
> **用户已拍(2026-06-19):F1 采纳 `Player`;F2 采纳拆法。** Planner 据此在 PLAN-batch3-s0.md 新增 **§6「给 Engine
> Integrator 的明确交接」**——列 autoload 表三态演进(现状 `Combat` → §0 后 `Combat`+`Player`(Implementer 已注)→
> §A 后 `Player`↑`Game`↓),**点明 EI 不要再加 `Player`**,§A 仅 ①删 `Combat` ②加 `Game`(排 `Player` 之下)③校验顺序。
> **§0 已由 Implementer 落地交付(2026-06-19,CHANGES-batch3-s0.md):** 4 步全绿——`PlayerState.reset()` / `project.godot`
> 附加 `Player` autoload / `_boot` 改 `get_node("/root/Player") as PlayerState`+reset-on-boot / 隔离收口。全套 **156/156、
> 0 orphans**(155 基线 + 1 新 reset 测),连跑两次稳定,`--import` 干净无 `hides an autoload singleton`。**F3 首验关口达成**:
> `/root/Player` 在 gdUnit CmdTool headless 下确有实例,`test_reboot_restores_from_save` 走共享单例+reset 仍绿(更忠实:证存档文件驱动恢复)。
> **§0 不切 `Combat`、未加 `Game`、未删任何 src、未退役任何测**——那些不可逆部分仍归 EI。
> **§0 已审(2026-06-19,REVIEW-batch3-s0.md):APPROVE WITH NITS,0 must-fix / 0 should-fix。** 读真实代码 + project.godot +
> 两套测试,独立重跑 **156/156、0 orphans、exit 0**;reset 实现 / `_boot` 改写顺序 / 默认分支重填 / `add_child` 移除影响面
> (arena/save/loot 全按引用消费,无破坏) / autoload 名合法性 / 不可逆部分未越界 逐条核过。仅 2 信息性 nit(N1 `test_reboot_restores_from_save`
> 对 reset 回归不可证伪但对 save/load 仍可证伪、且 reset 有专测兜底;N2 `get_node("/root/Player")` 硬失败是 F3 刻意契约、已在 Wiring Contract 注明),**均无需动作**。
> **→ 下一步:§0 全绿且审过 → 开 `/role-engine-integrator 00-foundation-redesign` 执行 INTEGRATION-STEPS §A–§F(不可逆,人机回报闭环)。
> §A 按 PLAN §6 / CHANGES §5:`Player` 已注册、勿重加,只删 `Combat` + 加 `Game`(排 `Player` 之下)+ 校验顺序。** F1 文档措辞回写(`PlayerState`→`Player` 节点名)待 Arch Guard/EI 顺手清。

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
>
> **本目录是 REFACTOR-01 整体地基重构的执行家**(放 PLAN/CHANGES/REVIEW/INTEGRATION-STEPS)。
> 它没有自己的 FEATURE-DESIGN —— **设计源 = `harness/arch/REFACTOR-01-foundation-redesign.md`(策略)+
> `harness/ARCHITECTURE.md`(目标地基事实源)**。编号取 00 表示"先于一切功能的地基",不挪占 03/04 的历史号。

## 这是什么 / 为什么

feature-by-feature 推进反复撞旧结构,根因 = **无「持久元状态 vs 单局战斗模拟」分层**(`CombatDirector` God object、
每局 `@export` 重建队伍)。用户 2026-06-19 拍 **Producer 级 scope call**:一次性重铺底层(组件化实体 / 模板-实例两层 /
modifier 属性 / PoE 装备流水线 / lane 团战),知情地推翻 v1 符号式 + 最小 retrofit 基调。**时机最干净:04 尚未实现、无存档历史 → 零数据迁移负担。**

三项地基拍板:**GDScript 保留** / **数据混合**(.tres 怪·关卡 + JSON 海量词缀·基底)/ **战斗扩成槽位-分路抽象多敌团战**(非真实 2D 物理)。
02/03 的 6 维战斗公式**保留搬入** `SkillComponent`,不丢。

## 设计源(读这两份,不在本目录重写)
- **`harness/ARCHITECTURE.md`** — 目标地基事实源(4 层架构 / 模板-实例数据模型 / 组件边界 / 7 条不变量 / 扩展点)。
- **`harness/arch/REFACTOR-01-foundation-redesign.md`** — 重构策略(根因诊断 + 目标 delta + §4 八层有序迁移 + 影响面 + 风险/被否选项 + Planner 交接)。
- **承接档(有效保留,移植进重构层)**:`04-loot-equipment/FEATURE-DESIGN.md`(B-4 PoE ilvl+分阶池 / LootTables / Tier 表 → REFACTOR-01 §4 第 3-4 层);`03-combat-formula-ext`(6 维公式 → 第 5 层 SkillComponent)。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 架构 | Arch Guard | (ARCHITECTURE.md + arch/REFACTOR-01/02) | draft(2026-06-19 产出目标地基 + 八层迁移策略;**已回写事实源至与落地代码一致**:banner 改"已落地"、F1 autoload 名 `Player`、§4 新增不变量 9=F-SaveBoss 续战契约、§6【已落地】+残留注释债;F1/F-Arch/F-SaveBoss 三回写 flag 清账) |
| 计划 | Planner | PLAN.md(一)/ PLAN-batch2.md(二)/ PLAN-batch3.md(三)/ PLAN-batch3-s0.md(步5 §0) | draft(**步5 §0 PLAN 已出 PLAN-batch3-s0.md**:4 步把 REFACTOR-02 §4 落地——`PlayerState.reset()` → 附加注册 `Player` autoload(**实证 autoload 名不可填 `PlayerState`,撞 class_name → 用 `Player`**)→ `_boot` 读 `/root/Player`+reset-on-boot → 测试隔离收口,全套回 155/0 orphans;§0 绿后才动 EI §A–§F。)（以下为前三批:**第一批 = 层 1-4** 全绿。**第二批 = 仅层 5** 战斗核心,7 步并存式 + D1-D8 + F1-F7。**第三批 = 层 6-8**(PLAN-batch3.md):5 步——starting_roster.json+Character名+DataRegistry校验 → SaveSystem(round-trip)→ GameController autoload 装配+驱动 → CombatView 原地重写读 Arena+Progression 双对象 → **步5 Engine Integrator 不可逆切换**(切 autoload `Combat`→`PlayerState`/`Game`+删 director/party_member/loot_stub+退役7旧测+全回归+手动 Play)。用户拍四决策:GameController autoload 装配座 / 存 PlayerState+进度游标 / 本批含切换删除 / starting_roster.json) |
| 实现 | Implementer | CHANGES.md / batch2 / batch3 / batch3-s1 / batch3-s0(步5 §0)/ **batch3-s2(F-SaveBoss 修复)** | draft(**F-SaveBoss 已交付 CHANGES-batch3-s2.md**:§F 抓到的"打通 boss 重开重打 boss" bug 已修——`GameController._boot` 续战游标据 `max_unlocked_stage > cur_stage` 判别 boss 已通 → 续 `(max_unlocked_stage,0)`,不动存档格式/FSM;补可证伪集成回归测;全套 **117/117、0 orphans**。)（**步5 §0 已交付 CHANGES-batch3-s0.md**:`PlayerState.reset()` + `project.godot` 附加 `Player` autoload + `_boot` 读 `/root/Player`+reset-on-boot + reset 单测;全套 **156/156、0 orphans**,连跑两次稳、`--import` 干净;不切 Combat/不加 Game/不删 src,留 EI。)（前批:**第一批层 1-4 全绿,审后两条 should-fix 已清**:84/84。**第二批层 5 全绿**:140/140、0 orphans。**第三批步 1-4 全绿**:CHANGES-batch3.md —— starting_roster.json + `Character.display_name` + DataRegistry 校验 / `SaveSystem` round-trip / `GameController` 装配驱动 + 自动存档 / `CombatView` 原地重写读 `/root/Game` 双对象;13 新 `test/core/*`,全套 **153/153、0 orphans**;含 Wiring Contract（步 5 EI 必读）。**S1 修复全绿**:CHANGES-batch3-s1.md —— 方案 B 存档收口(`Entity.write_equipment_into` + `GameController._sync_party_equipment`),+2 测,全套 **155/155、0 orphans**。步 5 不可逆切换留 Engine Integrator) |
| 审查 | Reviewer | REVIEW.md / batch2 / batch3 / batch3-s1 / batch3-s0(步5 §0)/ **batch3-s2(F-SaveBoss)** | draft(**F-SaveBoss APPROVE WITH NITS,0 must/should-fix**:REVIEW-batch3-s2.md —— 读真实代码 + 独立重跑 **117/117 0 orphans** + GC 单套 7/7;对抗推演判别式 `cur_scene==BOSS && max_unlocked>cur_stage` 唯一对应"boss 已清"(查 retreat 绝不把游标设回旧关 BOSS)、确认 `combat_view.gd:79` 无参 begin_run 走续战游标 in-game 真生效、回归测可证伪、不动存档格式/FSM。2 信息性 nit(WM_CLOSE 等价 / 末关空 Arena 正确终态)无需动作。）（**步5 §0 APPROVE WITH NITS,0 must/should-fix**:REVIEW-batch3-s0.md —— 独立重跑 156/156 0 orphans、reset 实现/`_boot` 顺序/`add_child` 移除影响面/autoload 名合法性/不可逆部分未越界 逐条核过,仅 2 信息性 nit(N1 reboot 测对 reset 不可证伪但 reset 有专测兜底 / N2 `/root/Player` 硬失败是 F3 契约)。前批:**第一批 APPROVE WITH NITS,0 must-fix**:独立重跑 82/82、公式/无损/PoE/序列化/校验闸均核过;2 should-fix 已清 + 4 nits 放行。**第二批 APPROVE WITH NITS,0 must-fix**:REVIEW-batch2.md —— 独立重跑 140/140 0 orphans、45 旧锚 45/45 全绿、6 维公式/4 条团灭回退/倒计时-修整/游标推进逐条等值、F5/F7 偏差追认;留 1 should-fix + 3 nits,全不阻塞。**第三批步 1-4 APPROVE WITH NITS,0 must-fix**:REVIEW-batch3.md —— 独立重跑 153/153 0 orphans、CombatView 单独 `--check-only` 过 + 缺 `/root/Game` 空守卫确认、并行造桥(旧 director/project.godot/45 旧测)守住、存档 round-trip / GC boot-resume / DataRegistry 错误累积顺序 / View 双对象读法逐条核过、F-PS-autoload 与 Dev-1/2/3 追认;留 1 should-fix〔S1 自动穿装不回写、重载即丢,须步 5 手测前拍板〕+ 3 nits。**S1 修复后复核 APPROVE WITH NITS,0 must/should-fix**:REVIEW-batch3-s1.md —— 独立重跑 155/155 0 orphans、方案 B 忠实度/写穿持久层/卸下边界/测试可证伪性核过,仅 2 信息性 nit) |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | —(表现层序列帧待 Art Spec;符号/占位先行,不阻塞数值地基) |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | **accepted(✅ §A–§F 全部验收通过,2026-06-19)**:§A–§E 切换全绿(116/116、0 orphans,EI 复跑)+ **§F 手动 Play 经人确认通过**——基础战斗表现正常 + 存档 round-trip 通过(通关 Boss → 关程序 → 重开**续到下一关、不重打 Boss**,F-SaveBoss 修复实游戏生效;roster/装备持久化未丢)。**REFACTOR-01 引擎侧切换闭环完成。**（历史:§A 切 autoload 完成(`project.godot` 现 `Player`↑ + `Game`↓ UID 引用,无 `Combat`)/ §B 删 3 director / §C 退役 7 旧测(留 stage_config_test)/ §D 重导入干净(无 `hides an autoload singleton`)/ §E 全回归 **116/116、0 errors/0 failures/0 orphans、18/18 套、exit 0**(156 基线 − 退役 7 测的 40 用例 = 116)。**§D 排障:用户首跑报 "no main scene defined" = 运行目录非工程根所致,加 `--path "G:/Games/test-2"` 即过,非工程缺陷**。Flags:F-PS-autoload-code ✅ 已解决、F1 文档回写非阻塞、F-Cutover 回退=改回 `Combat`+删 `Game`(留 `Player`)。**待人在编辑器执行 §F(F5 Play + 存档 round-trip)并回报截图验收**) |

> 状态取值:`—`(未开始) / `draft` / `accepted` / `blocked` / `superseded`

## 下一步
**Implementer 第一批已交付(CHANGES.md,层 1-4 全绿):** 14 个 `class_name` 脚本(`src/core/`)+ 3 份占位 JSON(`data/config/`)+ 37 个新 `test/core/*` 单测。
**全套 82/82 通过**(14/14 suites,0 errors/0 failures/0 orphans):内含**现有 45 个 `test/combat/*` 一字未改仍 45/45 绿**(D1 回归锚已守)。本批纯逻辑,无 UI 手动验收点。
偏差均记 CHANGES §4 + Wiring Contract(§5):新增 `GameKeys` 共享词表、`ItemInstance.signature_axes` 持久化字段、`LootIntake.handle_drop` 去 `character` 入参。R3(`class_name` 撞车)已清。

**Reviewer 已审(REVIEW.md):APPROVE WITH NITS,0 must-fix。** 独立重跑 82/82、文件清单干净、终值公式 / 无损卸下 / PoE roll / 填空优先 / 校验闸 / 序列化 round-trip 均核过。留 2 条 should-fix(`Character.build_stats()` 补 3 行测 / `DataRegistry` 补"三稀有度齐全"校验)+ 4 nits,**全非阻塞**。

**两条 should-fix 已清(2026-06-19,用户拍"都清"):** Implementer 补 `build_stats` 单测 + `DataRegistry` 三稀有度完整性校验(配套测 + 修 equipment 测占位表),详见 CHANGES §8。重验 **84/84 全套绿**(原 82 + 2 新;45 旧战斗回归锚仍全绿)。4 nits 按 REVIEW 建议放行。

**第一批 done。第二批 PLAN 已产出(PLAN-batch2.md):** Planner 把第二批**收窄为仅层 5**(战斗层重构,用户 2026-06-19 拍——层 5 是整套最大/最高风险/纯逻辑可自交付的核心,单独成批;层 6-8 留第三批)。7 步并存式计划:`CombatTuning`+`Entity`(工厂 from Character/EnemyDef)→ `SkillComponent`(搬 6 维公式)→ `AICombatComponent`(目标选择)→ `CombatArena`(tick+编排+信号)→ 掉落接新流水线(`EnemyDef` 加 `item_level`)→ `ProgressionController`(FSM)→ 收口闸。

**关键约束(承第一批范式):本批与旧 `src/combat/*` 并存,零改旧战斗码、零改 45 旧测试、零动 `project.godot`。** 新核心落 `src/core/combat/`,由新 `test/core/combat/*` 证明正确,**公式断言值逐条照抄 `formula_test.gd`**。删旧 director + 切 autoload + 退役旧符号掉落测试(`loot_test.gd`)= 第三批层 8 经 Engine Integrator。

**第二批 done(层 5 已交付,CHANGES-batch2.md):** 用户拍 F2 按默认(旧符号式掉落不迁移、留层 8 退役),Implementer 落地层 5 —— 把 438 行 `CombatDirector` 重构成 `src/core/combat/` 6 个组件类:`CombatTuning`(可注入调参)/ `Entity`(RefCounted 空壳 + `from_character`/`from_enemy_def` 工厂)/ `SkillComponent`(搬 6 维公式)/ `AICombatComponent`(选最前存活)/ `CombatArena`(Node,tick+编排+信号+掉落接线)/ `ProgressionController`(RefCounted 进度 FSM)。`EnemyDef.item_level` 已于 5e 加(additive)。
**全套 140/140 通过**(22/22 suites,0 errors/0 failures/0 orphans):**45 旧 `test/combat/*` 一字未改仍全绿**(D1)+ 39 第一批 `test/core/*` + **56 新 `test/core/combat/*`**(公式/进度断言逐条等值)。纯逻辑,无 UI 手动验收点。
偏差(CHANGES-batch2 §4):**F5 兑现 → `Entity` 退 `RefCounted`**(Node2D 在 headless 测留 orphan,按 PLAN 预授权退;比建议的 Node 更彻底,待追认);Arena 加 `_battle_restarted` 复刻 director 单敌"击杀后即结束本 tick"语义(F7 等值保障);新增 `item_dropped` 信号。

**第二批已审(REVIEW-batch2.md):APPROVE WITH NITS,0 must-fix。** Reviewer 独立重跑 140/140(0 errors/0 failures/0 orphans、22/22 suites)+ 45 旧锚 45/45 全绿(D1 守住);6 维公式 / 4 条团灭回退 / 倒计时-修整 / 游标推进 / Boss 永久解锁断言值逐条照搬迁移源核过;F5(`Entity`→`RefCounted`,orphan 规避)、F7(`_battle_restarted` 单敌"击杀即收尾"语义 + 掉落-推进同序)两处预授权偏差经核合理,**追认通过**。留 1 should-fix + 3 nits,全不阻塞。
- **S1(should-fix)**:4 槽位空位容错(`project-context §0` MVP 不变量)代码全程支持(combat_arena.gd:48-53/56-60/97-105),但迁移把旧 `[member,null,null,null]` 四元组收成单元素 `[hero]` → 新 `test/core/combat/*` **无任何用例守这条不变量**。建议第三批删旧 director **之前**补 1 个 `players=[hero,null,null,null]` 用例(约 15 行),否则旧 `test/combat/*` 退役后该容错失去回归网。
- **N1** `in_range()->true` 恒真占位(lane 几何到位前的显式 seam,层后回填真实判距)/ **N2** `_battle_restarted` 与 `_has_living` 收尾判断轻微重叠(层 6 信号平迁后可统一,现勿动)/ **N3** 掉落 slot/rarity 等概率占位 → 并入总数值专章。

**第三批 PLAN 已产出(PLAN-batch3.md):层 6-8 五步并存式计划。** 用户 AskUserQuestion 拍四决策:① 装配座 = 新 `GameController` autoload(持 per-run Arena+Progression,逻辑层独立于 View)② 存档 = `PlayerState`+进度游标(`max_unlocked_stage`/`cur_stage`/`cur_scene`)③ 本批含层 8 不可逆切换+删除 ④ 默认战士走 `data/config/starting_roster.json`(DataRegistry 校验)。
- **步 1-3(Implementer 可单测全绿,旧 director 仍跑):** starting_roster.json + `Character.display_name` + DataRegistry 加载校验 → `SaveSystem`(save/load round-trip) → `GameController`(`_boot` 装配 registry/playerstate/arena/progression、`begin_run`、boss/退出 autosave;headless 可测)。
- **步 4(可编译,UI 验收并入步 5):** `CombatView` 原地重写 —— 读 `/root/Game` 的 `arena`(战斗态/6 信号)+ `progression`(mode/游标/倒计时/current_enemy_def)双对象;敌血取 `arena.enemies`、队名取 `gc.party_characters`、`Mode`/`BOSS_SCENE` 改引 `ProgressionController`;`loot_dropped`→`item_dropped(ItemInstance,dest)`。
- **步 5(Engine Integrator 不可逆原子步):** `project.godot` 切 autoload(删 `Combat`,加 `PlayerState`/`Game`)+ 删 `combat_director/party_member/loot_stub` + 退役 7 个引用它们的旧 `test/combat/*`(**保留 `stage_config_test`**)+ `--import` + 全回归(0 orphans)+ **手动 Play**(战斗/血条/飘字/按钮/倒计时/掉落 FX/Boss/团灭 + 存档 round-trip 肉眼确认)。56 新套 = 删 director 安全网(F6)。
- **F-Arch(非阻塞):** D4 让 `DataRegistry` 仍 `RefCounted` 由 GameController 持有(改 Node-autoload 会破第一批 0-orphan)→ **建议 Arch Guard 回写 ARCHITECTURE §3.2**(DataRegistry 经 `Game.registry` 可达)。

**第三批步 1-4 done(Implementer 已交付,CHANGES-batch3.md):** 13 个新 `test/core/*` 用例 + 1 份 JSON +
2 个新 `class_name`(`SaveSystem`/`GameController`)+ `Character.display_name`/DataRegistry 校验扩展 + CombatView 原地重写。
**全套 153/153、0 orphans**(45 旧战斗锚仍全绿,`project.godot`/旧 director 未动)。三处偏差均记 CHANGES §5
(begin_run -1 哨兵 / loot_equipment 注入移到 begin_run / 加 auto_boot 测试钩),非语义改动。

**第三批步 1-4 已审(REVIEW-batch3.md):APPROVE WITH NITS,0 must-fix。** Reviewer 独立重跑 **153/153、0 orphans**、
`--check-only src/combat/combat_view.gd` exit 0、确认 CombatView 对缺失 `/root/Game` 有空守卫(切换前不崩工程)、
并行造桥(旧 `Combat` autoload / `project.godot` / 45 旧测)零改;存档 round-trip、GC 装配-驱动-存档闭环、DataRegistry
错误累积顺序、View 双对象读法逐条核过;F-PS-autoload 与 Dev-1/2/3 三处偏差追认合理。**留 1 条 should-fix + 3 nits,
全不阻塞本批。**
- **S1(should-fix,须步 5 手测前当面拍板)**:自动穿装走 `loot_intake.gd:14-16` EQUIPPED 路径只 buff 活体 Entity 的
  `EquipmentComponent`,**从不回写 `Character.equipped`** → 存档/重 boot 后该装备消失,直击 v1 核心循环(掉装→变强)。
  不是 must-fix:`loot_intake.gd:5` 注明"角色侧同步留第二批",PLAN-batch3 D2 范围本就只序列化 roster 当前所持。
  **用户已拍(2026-06-19):S1 交 Implementer 修,同步方案 = B(存档时收口)** —— autosave 前把活体
  `EquipmentComponent` 快照回 `Character.equipped`,改动局部在 GameController/SaveSystem 侧,须处理空位/卸下边界。

**→ 下一步:开 `/role-implementer 00-foundation-redesign` 落地 S1(方案 B,喂 REVIEW-batch3.md §3);** 完成后再由
Engine Integrator 收口步 5(切 autoload `Combat`→`PlayerState`/`Game` + 删 director/party_member/loot_stub + 退役 7 旧测 +
全回归 + 手动 Play)由 Engine Integrator 收口**(不可逆引擎侧,人机回报闭环)。**进步 5 前先清两件:① 解 〔F-PS-autoload〕
(建议不注册 PlayerState autoload)② 就 S1 掉装持久化拍板。** S1(4 槽位空位补测,承第二批)亦在删 director 前并入 ——
注:第三批 `game_controller_test` 已断言 `players[1]` null 容错,部分补上该网。

## 待办 / 旗标
- **[F-SaveBoss — ✅ 已修且审过(2026-06-19,Implementer CHANGES-batch3-s2 + Reviewer REVIEW-batch3-s2),APPROVE WITH NITS 0 must/should]** 打完 boss 重开重打 boss 的 bug 已修:`GameController._boot:63-65` 续战游标据 `_resume_scene == BOSS_SCENE` 且 `max_unlocked_stage > _resume_stage` 判别 boss 已通 → 续 `(max_unlocked_stage, 0)`;boss 打一半就关(max 未 +1)→ 续回 boss。不动存档格式/FSM。补可证伪集成回归测(撤补丁即 FAIL)。**Reviewer 独立重跑 117/117 0 orphans、对抗推演判别式唯一性(retreat 绝不把 cur_scene 设回旧关 BOSS)、确认 `combat_view.gd:79` 无参 `begin_run` 走续战游标 → in-game 真生效**;2 信息性 nit(N1 WM_CLOSE 态与 boss_cleared 落档等价无需单测 / N2 通关末关续到空 Arena 是正确终态)无需动作。**下一棒 = 人在 Godot 重验 §F 存档 round-trip(通关→关→重开应续到下一关、不重打 boss)。**
- **[F1/F2 — 已决(2026-06-19,用户拍),给 EI 的明确交接见 PLAN-batch3-s0.md §6]** ① **F1**:autoload 节点名 = **`Player`**(类型 `PlayerState`),非 `PlayerState`(撞 class_name 编译失败,实证)。② **F2**:**就按拆法**——`Player` autoload 由 **Implementer 在 §0 注册**(附加、可逆,经 `--import` 自验);**EI 不要再加 `Player`**。**EI 进 §A 时 autoload 表已是 `Combat`+`Player`,只需:①删 `Combat` ②加 `Game`(排 `Player` 之下,F4)③校验顺序**(`Player`↑`Game`↓,无 `Combat`/无重复 `Player`)。**待回写**:`ARCHITECTURE.md §1/§3.2/§4-不变量8`、`REFACTOR-02`、`INTEGRATION-STEPS §A` 里"PlayerState autoload / Node Name 填 PlayerState"措辞 → 改"autoload 节点 `Player`,类型 `PlayerState`"(Arch Guard 回写事实源 / EI 回写其 owned §A)。
- **[F-Arch-seat — 已决(2026-06-19,Arch Guard),见 `arch/REFACTOR-02-playerstate-seat.md`]** 拍板:**拆座
  = `PlayerState` 升 autoload(持久根),方案 C 正确**。理由:事实源 ARCHITECTURE.md §1/§3.2 本就把 PlayerState
  画成 autoload,代码自持只是 batch-3 实现期权宜;05-town(Next)会在战斗外读写 roster/bag,拆座现在做(无存档、
  改面最小)比拖到 05 再迁更省。**纠 EI"God-object 坏味道"框定**:单一职责的存档态全局根不是 director 那种 God object,
  EI 真正命中的是"双路径约定空缺"——已钉死:**唯一实例,`Game.player_state` = 同对象缓存引用,非战斗系统读全局
  `PlayerState` 不穿 `Game`**(ARCHITECTURE §4 不变量 8)。测试隔离 = **reset-on-boot**(`_boot` 先 `player_state.reset()`
  再 load)。**顺带纠正事实源:`DataRegistry` 改回"`Game` 持有·RefCounted"(D4,非 autoload),与代码一致;05-town
  需战斗外读模板时复审。** → 下一棒进 §0(下方 F-PS-autoload)。
- **[F-PS-autoload — 已定方案 C(2026-06-19),先决 BLOCKING]** 用户拍:注册 `PlayerState` autoload + 改
  `GameController._boot` 复用 `/root/PlayerState`(不再 `PlayerState.new()`/`add_child`)。**这是 Implementer 代码改**:
  含修测试隔离(`game_controller_test` 等在 `_boot` 后写 `gc.player_state.roster`,共享单例会串状态;`test_reboot_restores_from_save`
  造双 GC 会共用同一 PlayerState)。**§0 全套重绿后**才执行 INTEGRATION-STEPS §A 起的编辑器切换。详见 INTEGRATION-STEPS §0。
- **[Producer 待回写,非 Planner 落地项]** 更新 BACKLOG scope line(团战/演出/存档提前进 v1 地基)+ project-context(§1 确认 GDScript、§2 目录约定、v1 完成定义)。第三批又新增 `game_controller.gd`/`save_system.gd`/`starting_roster.json` + 待加 autoload `Game` → 一并回写目录约定 + v1 完成定义(装配/存档已就位)。
- **[引擎侧人工点]** autoload 重注册 + JSON/`.tres` 资源指派 → 第 8 层经 Engine Integrator 人机回报闭环。
- **[数值全占位]** lane 几何、词缀完整 Tier 表、属性成长曲线 → 与 03/04 的 F1 合并成总数值专章。
- **组件 Node vs RefCounted** = 软决策(ARCHITECTURE §6),留 Planner/Implementer 定。

## 决策记录
- 2026-06-19 — **[Engine Integrator/用户] §F 手动 Play 验收通过 → REFACTOR-01 引擎侧切换闭环完成**。人在 Godot 里跑完 §F 清单回报"没问题":基础战斗表现正常(战斗自动跑/血条/飘字/掉落 FX/日志)+ **存档 round-trip 通过**——通关第一关 Boss → 关程序(autosave)→ 重开**续到第二关开头、不再重打 Boss**,证 F-SaveBoss 修复在实游戏路径(`combat_view.gd:79` 无参 `begin_run` → 续战游标)真生效;roster/自动穿装持久化未丢(S1 亦验)。`INTEGRATION-STEPS.md` 标 **accepted**。**REFACTOR-01 端到端在新地基跑通**:表现层读 `Game.arena`/`Game.progression`、`GameController` 装配驱动、`SaveSystem` 落盘 `PlayerState`+进度,旧 `Combat` director 彻底退场。下一棒(非本功能):Producer 回写 scope(BACKLOG + project-context)→ 05-town。来源:用户回报 + INTEGRATION-STEPS §F。
- 2026-06-19 — **[Arch Guard] 事实源回写至与已落地代码一致(ARCHITECTURE.md + REFACTOR-02)**。bare `/arch-guard`,模式 = 事实源维护(非新重构)。读全文 ARCHITECTURE.md + glob `src/**/*.gd` + grep director 核对现状,改四处脱节:① **顶部 banner**"目标地基尚未落地 / src/combat/*=待迁移现状" → 改"REFACTOR-01 已落地"(四层 = 真实代码、旧 director 已删仅留出处注释、表现层切 `Game` autoload、117/117);② **F1 autoload 命名**:§1 座位约定 + §3.2 PlayerState 行补"**节点名 = `Player`**(`PlayerState` 撞 class_name,真实路径 `/root/Player`)";③ **§4 新增不变量 9 = F-SaveBoss 续战契约**(`saved cur_scene==BOSS_SCENE && max_unlocked_stage>cur_stage ⇒ 续 (max_unlocked_stage,0)`,判别唯一性靠团灭回退只落普通场景);④ **§6【迁移中】→【已落地】**,并记残留代码注释债(`enemy_def.gd:9`/`stage_config.gd:4` 仍写"逻辑在 CombatDirector",留 Implementer drive-by 修)。**F-Arch/D4(DataRegistry "Game 持有·RefCounted")核实早已写入 §3.2/§6,未重复**。REFACTOR-02 多处 `/root/PlayerState` 路径加"实现修正"banner 校正为 `/root/Player`。**F1 / F-Arch / F-SaveBoss 续战不变量三条回写 flag 全部清账**。来源:ARCHITECTURE.md / REFACTOR-02。
- 2026-06-19 — **[Reviewer] F-SaveBoss 修复 = APPROVE WITH NITS,0 must/should-fix(REVIEW-batch3-s2.md)**。读真实代码(game_controller/progression/save_system/combat_view + 新测),独立重跑全套 **117/117 0 orphans exit 0** + GC 单套 7/7。核:修复只动 `GameController._boot:63-65` 续战游标(不碰存档格式/FSM);**对抗推演判别式 `cur_scene==BOSS_SCENE && max_unlocked_stage>cur_stage` 唯一对应"该 boss 已清"**——查 `retreat_after_wipe` 团灭回退只落普通场景、绝不把 cur_scene 设回旧关 BOSS,故无"max>cur 却 cur_scene=旧 BOSS 且未清"反例;"boss 打一半就关"max 未 +1 → 续回 boss;**`combat_view.gd:79` 无参 `begin_run` 走续战游标 → in-game 真生效**;回归测撤补丁即 FAIL 证可证伪。2 信息性 nit(N1 WM_CLOSE 态落档与 boss_cleared 等价、N2 末关通关续到空 Arena 是正确终态)无需动作。下一棒 = 人重验 §F 存档 round-trip。来源:REVIEW-batch3-s2.md。
- 2026-06-19 — **[Implementer] F-SaveBoss 落地(CHANGES-batch3-s2.md),全套 117/117 0 orphans**。`GameController._boot` 续战游标据 `max_unlocked_stage > cur_stage` 判别 boss 已通 → 续 `(max_unlocked_stage,0)`,免重开重打 boss;不动存档格式/progression FSM。补集成回归测 `test_reboot_after_boss_resumes_past_boss_not_refight`(两关速通),撤补丁即 FAIL 证可证伪。根因:`boss_cleared.emit` 发信号触发 autosave 那一刻 cur_scene 仍 = BOSS_SCENE(游标待倒计时后 `_execute_push` 才推进)。来源:CHANGES-batch3-s2.md。
- 2026-06-19 — **[EI/用户] §F 手动 Play 抓到 F-SaveBoss bug + §A–§E 已验证全绿**。EI 复跑确认切换全绿(116/116 0 orphans);§F 手动 Play 发现"打通 boss 重开重打 boss",EI 定位根因(boss_cleared autosave 存的是 boss 那格游标)并记 flag 路由 Implementer。§D 用户首跑 "no main scene defined" = 运行目录非工程根,加 `--path` 即过。来源:用户 + EI 复跑。
- 2026-06-19 — **[Reviewer] 步 5 §0 = APPROVE WITH NITS,0 must/should-fix(REVIEW-batch3-s0.md)**。读真实代码 + project.godot + 两套测试,独立重跑 **156/156、0 orphans、exit 0**。逐条核:`reset()` 三者全清 / `_boot` 改 `get_node("/root/Player") as PlayerState`+reset 在 load 前 / 默认分支 reset 后重填 roster(bag/材料留空属新档应然)/ 删 `add_child` 无破坏(arena/save/loot 全按对象引用消费,无依赖 GC-parenting)/ `Player` 名不撞 class_name / 不可逆部分(Combat/Game/删 src/退役测)未越界。2 信息性 nit:N1 `test_reboot_restores_from_save` 对 `reset()` 回归不可证伪(共享单例掩盖)但对 save/load 仍可证伪、`reset()` 由专测兜底 → 合计覆盖完整;N2 `get_node("/root/Player")` 硬失败是 PLAN F3 刻意契约、已在 Wiring Contract 告警。均无需动作。下一棒 = `/role-engine-integrator`(§A–§F 不可逆)。来源:REVIEW-batch3-s0.md。
- 2026-06-19 — **[Implementer] 步 5 §0 落地(CHANGES-batch3-s0.md),全套 156/156 0 orphans**。4 步:① `PlayerState.reset()`(clear roster/bag/materials)+ reset 单测;② `project.godot` 附加 `Player="*res://src/core/meta/player_state.gd"`(`grep class_name Player` 无命中,`--import` 无 `hides an autoload singleton`);③ `_boot` 改 `get_node("/root/Player") as PlayerState`+`reset()`,删 `add_child`,顺带同步类头 docstring 两行;④ 隔离收口——reset-on-boot 已足,未加 `before_test`(守勿过度)。**F3 关口达成**:`/root/Player` 在 gdUnit headless 在场,`test_reboot_restores_from_save` 走共享单例+reset 仍绿。连跑两次稳定,`--import` 干净。**未触不可逆部分**(Combat/Game 切换、删 src、退役测留 EI)。来源:CHANGES-batch3-s0.md。
- 2026-06-19 — **[用户/Planner] F1/F2 拍板 + 给 EI 的明确交接(PLAN-batch3-s0.md §6)**。用户拍:**F1 采纳 `Player`**(autoload 节点名,类型仍 `PlayerState`);**F2 采纳拆法**(`Player` 注册前移 Implementer §0,`Combat`→`Game` 切换留 EI)。指令:"就按你的拆法,并详细写清让 EI 了解计划,以免重复添加"。Planner 据此在 PLAN 新增 **§6**:列 autoload 表三态(现状 `Combat` → §0 后 `Combat`+`Player`(Implementer 已注,经 `--import`+155/0 自验)→ §A 后 `Player`↑`Game`↓),**明确 EI 不要再加 `Player`**,§A 仅 ①删 `Combat` ②加 `Game`(排 `Player` 下)③校验顺序。F1 措辞回写(ARCHITECTURE/REFACTOR-02/§A)列待办。来源:用户 + PLAN-batch3-s0.md §6。
- 2026-06-19 — **[Planner] 步 5 §0 PLAN(PLAN-batch3-s0.md)+ 实证捕到 INTEGRATION-STEPS §A 缺陷**。把 REFACTOR-02 §4 落成 4 步(`reset()` → 附加注册 autoload → `_boot` 读单例+reset-on-boot → 隔离收口,全套 155/0 orphans)。**关键发现(隔离临时工程实证):autoload 名填 `PlayerState` 会撞 `class_name PlayerState`,Godot 4.6.3 `--import` 报 `Class "PlayerState" hides an autoload singleton` 编译失败** → 节点名改 **`Player`**(类型仍 PlayerState),同 `Game`/`GameController` 先例(F1,需回写 ARCHITECTURE/REFACTOR-02/§A 措辞)。决策:§0 把**附加可逆**的 `Player` 注册前移给 Implementer(经 `--import` 自验),**不可逆**的 `Combat`→`Game` 切换+删档仍归 EI(F2,重切 §A)。reset-on-boot 收口测试隔离(默认分支不清 bag/材料,必须显式 reset)。来源:PLAN-batch3-s0.md。
- 2026-06-19 — **[Arch Guard] F-Arch-seat 拍板:拆座 = `PlayerState` 升 autoload(方案 C 正确),产 `arch/REFACTOR-02-playerstate-seat.md`**。诊断:这不是新架构、是代码偏离事实源——ARCHITECTURE.md §1/§3.2 早把 PlayerState 画成 autoload,GC 自持只是 batch-3 权宜;05-town(Next)会在战斗外读写 roster→拆座现在做(无存档、改面最小)更省。纠 EI"God-object 坏味道"框定(单一职责存档根≠director God object);钉死两约定:① 唯一实例,`Game.player_state`=同对象缓存,非战斗系统读全局 PlayerState 不穿 Game(新增不变量 8)② reset-on-boot 测试隔离。顺带纠事实源:`DataRegistry` 改回"Game 持有·RefCounted"(D4,非 autoload),05-town 需战斗外读模板时复审。已更新 ARCHITECTURE.md §1/§3.2/§4/§6。下一棒 = `/role-planner`(落步 5 §0 PLAN)。来源:REFACTOR-02。
- 2026-06-19 — **[用户/Engine Integrator] F-PS-autoload 定为方案 C(注 PlayerState autoload + 改 `_boot` 复用 `/root/PlayerState`)**:比"只注 Game"更净(日后城镇/招募可读全局 PlayerState),代价 = 一处 `_boot` 代码改 + 测试隔离修(超 EI 职责,路由 Implementer)。EI 已出 INTEGRATION-STEPS,§0 列该先决为 BLOCKING。来源:用户(AskUserQuestion)+ INTEGRATION-STEPS §0。
- 2026-06-19 — **[Reviewer] S1 修复复核 = APPROVE WITH NITS,0 must-fix / 0 should-fix**:独立重跑 155/155 0 orphans,方案 B 忠实(`_autosave` 落盘前 `_sync_party_equipment` 收口)、`party_characters[i]`↔roster 同引用写穿持久层、卸下边界 erase 有测、两新测可证伪(修复前会 FAIL)逐条核过。仅 2 信息性 nit(ItemInstance 别名共享当前无害 / arena==null 防御冗余),无需动作。来源:REVIEW-batch3-s1.md。
- 2026-06-19 — **[Implementer] S1 落地(方案 B,CHANGES-batch3-s1.md)**:`Entity.write_equipment_into(c)` 把活体装备态快照回 `Character.equipped`(含卸下边界 erase),`GameController._autosave` 落盘前调 `_sync_party_equipment` 按 index 配对收口。+2 测(穿装重 boot 仍在 / 局内脱下清槽),全套 155/155 0 orphans。无新引擎接线点。来源:CHANGES-batch3-s1.md。
- 2026-06-19 — **[用户] S1(自动穿装回写持久化)路由 Implementer,同步方案定 B(存档时收口)**:不在 Reviewer session 越界改码;开 `/role-implementer 00-foundation-redesign` 落地。方案 B = autosave 前把活体 `EquipmentComponent` 当前装备快照回 `Character.equipped`(改动局部在 GameController/SaveSystem 侧),实现时须处理空位/卸下边界。来源:用户(AskUserQuestion)。
- 2026-06-19 — **[Reviewer] 第三批步 1-4 = APPROVE WITH NITS,0 must-fix**:独立重跑 153/153 0 orphans、CombatView 单独编译过 + 空守卫确认、并行造桥守住,存档/装配/校验顺序/View 双对象逐条核过,F-PS-autoload + Dev-1/2/3 追认。**新提 should-fix S1〔自动穿装不回写 Character、重载即丢,loot_intake.gd:14-16〕须步 5 手测前拍板**(非 must:已注明留第二批、PLAN D2 范围外)。来源:REVIEW-batch3.md。
- 2026-06-19 — **[Implementer] 第三批步 1-4 落地三处偏差(CHANGES-batch3 §5)**:① `begin_run` 默认参数改 -1 哨兵(GDScript 实例成员不能作默认值)② `loot_equipment` 注入从 `_boot` 移到 `begin_run`(战士 Entity 在 begin_run 才建,须指向当局 Entity 的 EquipmentComponent 才能让掉落 buff 落到战斗壳)③ 加 `auto_boot` 字段供 headless 测注入 `_boot`。均非语义改动。来源:CHANGES-batch3。
- 2026-06-19 — **[Implementer 新提,需步 5 拍板] F-PS-autoload**:GameController 自持 player_state 与 PLAN 步 5.1「注册 PlayerState autoload」冲突(会二重)。建议步 5 不注册 PlayerState autoload。来源:CHANGES-batch3 §4.1/§6。
- 2026-06-19 — **[用户/Planner] 第三批四决策(AskUserQuestion)**:① 装配座 = 新 `GameController` autoload ② 存档 = PlayerState+进度游标 ③ 本批含层 8 不可逆切换+删除 ④ 默认战士走 `starting_roster.json`(DataRegistry 校验)。据此产出 PLAN-batch3.md 五步。来源:用户(AskUserQuestion 四问全选推荐项)。
- 2026-06-19 — **[Planner] D4:`DataRegistry` 不注册 autoload,由 `GameController` 持有(仍 RefCounted)**。理由:改 Node-autoload 会让第一批单测 `DataRegistry.new()` 留 orphan,破 0-orphan;只 GameController 消费,`Game.registry` 可达即够。**待 Arch Guard 回写 ARCHITECTURE §3.2**。来源:PLAN-batch3 §2/§5。
- 2026-06-19 — **[Reviewer] 第二批层 5 = APPROVE WITH NITS,0 must-fix**:独立重跑 140/140(0 orphans)+ 45 旧锚全绿,6 维公式/4 团灭回退/倒计时-修整/游标推进逐条等值核过,F5/F7 偏差追认通过。留 S1(4 槽位空位补测,列第三批删 director 前置)+ N1/N2/N3。来源:REVIEW-batch2.md。
- 2026-06-19 — **[用户] F2 按默认**:旧符号式掉落不 1:1 迁移、随旧 director 留到层 8 退役;Implementer 据此落地第二批层 5。来源:用户("F2按照默认,开干")。
- 2026-06-19 — **[Implementer] F5 兑现**:`Entity` 由 PLAN 拟定的 `Node2D` 退为 `RefCounted`(headless 测中内部 new 敌实体作 Node2D 会留 orphan;PLAN-batch2 D5/F5 预授权)。待 Reviewer/用户追认。
- 2026-06-19 — **[Producer/用户] 启动整体底层地基重构(REFACTOR-01)**,推翻 v1-minimal retrofit。理由:打好基础以后添砖加瓦快。来源:用户。
- 2026-06-19 — 三项地基拍板:GDScript 保留 / 数据混合(.tres + JSON)/ 战斗槽位-分路抽象多敌团战。来源:用户(AskUserQuestion)。
- 2026-06-19 — **目录决策**:03/04 保留作设计/历史档(03 公式活在代码、04 FEATURE-DESIGN 是重构输入),**新建本 00 目录**放重构执行,不删不改号。来源:用户。
