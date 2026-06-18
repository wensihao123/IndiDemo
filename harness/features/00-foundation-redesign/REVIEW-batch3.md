---
artifact: REVIEW
feature: 00-foundation-redesign
role: Reviewer
status: done
updated: 2026-06-19
inputs: [PLAN-batch3.md, CHANGES-batch3.md, src/core/systems/data_registry.gd, src/core/systems/save_system.gd, src/core/game_controller.gd, src/combat/combat_view.gd, src/core/systems/loot_intake.gd, test/core/*, data/config/starting_roster.json, project.godot]
next: Engine Integrator(步5 切换)/ 人(就 must/should 项拍板)
---

# REVIEW — batch-3 步骤 1-4(REFACTOR-01 层 6-8)

## 1. 结论 / Verdict

**APPROVE WITH NITS.**

步 1-3(起始 roster 配置 + Character.display_name + DataRegistry 校验 + SaveSystem + GameController 装配/驱动/存档闭环)纯逻辑全部有单测护住,独立重跑全绿;步 4(CombatView 原地重写)编译通过且对缺失 `/root/Game` 有空守卫,不会在切换前崩工程。并行造桥约束守住:旧 `Combat` autoload、`project.godot`、45 个旧 `test/combat/*` 全未动。

**不阻塞本批交付**,但有一个必须在步 5 手测前当面说清的真问题(自动穿装不回写、重载即丢,见 Should-fix S1),以及一个 Implementer 已正确标注、留给步 5 拍板的装配冲突(F-PS-autoload)。

独立验证记录:
- 全量重跑:**153 / 153 | 0 error | 0 failure | 0 flaky | 0 skipped | 0 orphan | exit 0 | 25 suites**,与 CHANGES 声称一致。
- `--check-only src/combat/combat_view.gd` → exit 0(步 4 唯一不在测试套里的交付物,单独编译确认)。
- `project.godot` 仍 `Combat="*res://src/combat/combat_director.gd"`;`test/combat/*.gd` 8 个文件仍在。并行造桥成立。

## 2. 必须修 / Must-fix

无。本批 DoD(步 1-3 纯逻辑绿、步 4 编译)已满足,无阻塞缺陷。

## 3. 应该修 / Should-fix

**S1 —【需在步 5 手测前当面说清】自动穿装不回写 Character,重载即丢。**
`loot_intake.gd:14-16` 的 EQUIPPED 路径走 `equipment.equip(slot, instance)`,只给活体 Entity 的 `EquipmentComponent` 加 buff,**从不回写 `Character.equipped`**;而 `SaveSystem` 序列化的是 roster 里的 `Character.equipped`(经 `PlayerState.to_dict`)。后果:打怪自动穿上的装备在本局生效,但一旦存档→重 boot,这件装备凭空消失。这直接打在 v1 核心循环(掉装→变强→打更硬的怪)上。
- 为什么不是 must-fix:`loot_intake.gd:5` 注释白纸黑字写明"角色侧同步留第二批接线",PLAN-batch3 D2 的字面范围就是"忠实序列化 PlayerState/roster 当前所持",并未把"关掉 LootIntake↔Character 回写缝"列进本批任务。本批代码忠实实现了被交付的范围,没有引入新错。
- 但它是真缝、且影响核心循环:**步 5 进入手动 Play 之前必须当面确认**——要么本缝在步 5 一并补,要么明确接受"v1 手测先不验证掉装持久化"。别让它在手测时才被发现。建议路由给 Planner/人,作为步 5 范围决策的一部分。

## 4. 吹毛求疵 / Nits

- **N1** `SaveSystem.load_file` 只在"顶层非 Dictionary"时返回 `{}`,但 `JSON.parse_string` 对损坏文本返回 `null`,`null is Dictionary` 为 false 也会落到 `{}` 分支——行为正确,只是没像 `DataRegistry._read_json` 那样把"解析失败"单列成可诊断信息。读档容错本就要"静默回默认",此处可接受,记一笔即可。
- **N2** `GameController.begin_run` 的 `-1` 哨兵(Dev-1)是 GDScript 默认参不能引用实例成员的合理绕法;但 `stage`/`scene` 传负数(非 -1,如 -5)会与"取续战游标"语义混淆。当前仅内部调用、入参可控,不阻塞;若日后开放外部传参,建议显式 `>= 0` 之外的负值断言。
- **N3** `combat_view.gd` 仍保留 `@export var stages`(免改场景),与"数据走 Resource 不硬编码"一致;但步 5 切换后,关卡来源(场景导出 vs Game 注入)需在 F-Stages-source 里定稿,别让两处来源并存。属步 5 议题,非本批。

## 5. 查过但没问题 / What I checked but found fine

- **存档 round-trip**:`to_save_dict` 含 version/player/progress 三段;`apply` 对空 dict 早退、非空时 `from_dict` + 三游标 `int()` 回写;`save_system_test` 的 round-trip 用例做了 to_dict 全等 + 三游标比对,断言真实有效。读不存在档返回 `{}` 用例成立。
- **DataRegistry 错误累积顺序**:`ingest()` 开头清 `_errors`,故 `load_all` 里 roster 校验排在 `ingest()` 之后且用 `_ingest_*`(append 不 clear),`return _errors.is_empty()` 合并判定——顺序正确,不会被前者清掉。`starting_roster_test` 6 个用例(好数据/深拷贝隔离/未知属性/空 id/非数字值)断言到位。
- **get_starting_roster 深拷贝**:`from_dict(c.to_dict())` 每次新建 Character,`test_get_starting_roster_returns_fresh_copies` 验证跨局不串。
- **GameController boot/resume**:`_boot` 装配顺序(registry→player_state→arena→progression)依赖方向正确;有档走 `apply`、无档走 `get_starting_roster`;`_resume_stage/scene` 从 `progression` 读回。`game_controller_test` 4 用例(4 格建队 + 空位 null 容错、tick 推进到 BOSS_SCENE、Boss 通关自动落档、重 boot 读档恢复)真实覆盖装配-驱动-存档闭环。`tick_seconds=1.0` 是还原逐 tick 确定推进的正确测试约定。
- **CombatView 双对象读出**:`_ready` 取 `_gc.arena`/`_gc.progression`,对 `_gc==null` 有空守卫显示"(无 Game 单例)"并 return——切换前工程不会硬崩。订阅 arena 六信号 + prog 两信号、按钮接 `request_push/request_rest`、`begin_run(stages)` 与新契约一致。`_on_item_dropped(inst, dest)` 替换旧 `_on_loot_dropped` 符合 LootIntake 目的地枚举(EQUIPPED/DECOMPOSED/BAGGED)。
- **F-PS-autoload(装配冲突)**:GameController 在 `_boot` 里自持 `PlayerState.new()`,与 PLAN 步 5.1"注册 PlayerState autoload"会撞成双实例。Implementer 已正确标注并路由到步 5——判断无误,本批不需在此解决。
- **Dev-2 / Dev-3**:`loot_equipment` 注入时机移到 `begin_run`(取首个存活成员的 EquipmentComponent)、`auto_boot` 字段供测试关自动 boot——两处偏差均为合理工程取舍,不改变契约语义。
- **并行造桥**:旧 director / `project.godot` / 45 个旧测试零改动,步 5 之前的不可逆切换面被正确隔离。
