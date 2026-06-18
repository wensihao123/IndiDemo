---
artifact: PLAN
feature: 00-foundation-redesign
role: Planner
status: draft
updated: 2026-06-19
inputs: [ARCHITECTURE.md, arch/REFACTOR-01-foundation-redesign.md, project-context.md, CHANGES-batch2.md, REVIEW-batch2.md, src/combat/combat_view.gd, src/combat/combat_director.gd, src/core/combat/*, src/core/meta/player_state.gd, src/core/meta/character.gd, src/core/systems/data_registry.gd, project.godot, scenes/shell/floating_shell.tscn]
next: Implementer（步 1-4）→ Engine Integrator（步 5 不可逆切换）
---
# PLAN — 底层地基重构 · 第三批(层 6-8:表现层平迁 / 存档 / 接线收口)

> 承 REFACTOR-01 §4 的**层 6（表现层）+ 层 7（存档）+ 层 8（接线+全回归）**。第二批已把战斗核心
> 落 `src/core/combat/`(Arena+Progression 等 6 类,140/140 绿,REVIEW-batch2 APPROVE)。本批把**表现层
> 接上新核心 + 落盘存档 + 切 autoload 删旧 director**,让整个重构收口、游戏真正跑在新地基上。
>
> **关键范式(承第一、二批):** 步 1-4 = 纯逻辑/可编译的并存式新码,**旧 `Combat` director 仍是
> autoload、45 旧测仍全绿**;步 5 = 唯一不可逆的引擎侧切换(切 autoload + 删旧码 + 退役旧测 + 手动 Play),
> **经 Engine Integrator 人机回报闭环**。56 个 `test/core/combat/*` = 删 director 后的唯一安全网(F6)。

## 1. Goal(一句话)

把 `CombatView` 从读旧 director 改为读新 `CombatArena`+`ProgressionController`、新建 `GameController`
autoload 装配并驱动一局、用 `SaveSystem` 落盘 `PlayerState`+进度,最后切 autoload 删旧 director,
让重构在新地基上端到端跑通(战斗演出 + 存档 + 全回归绿 + 手动 Play 通过)。

## 2. Approach & key decisions(每条:做什么 + 为什么 + 否掉的选项)

- **D1 · 装配座 = 新 `GameController` autoload(用户拍板)。** `src/core/game_controller.gd`(`extends Node`)
  持有 per-run `CombatArena`+`ProgressionController`、`DataRegistry`、引用 `PlayerState`;`_ready` 装配 +
  从存档/默认 roster 建队 + 把 `arena` 作子节点挂进树(让其 `_process` 固定步长 tick 驱动战斗)。View 只读它。
  *为什么:* 逻辑层独立于表现层(ARCHITECTURE 不变量 #3,headless 可演算);autoload 切换变成一处干净替换。
  *否掉:* View 自己持有这局——把"跑一局"耦进表现层,headless 无法脱 View 驱动战斗。
- **D2 · 存档 = `PlayerState` + 进度游标(用户拍板)。** 顶层 dict `{version, player:{roster,bag,materials},
  progress:{max_unlocked_stage,cur_stage,cur_scene}}`。`PlayerState.to_dict/from_dict` 已就绪(第一批),
  进度块读写 `ProgressionController` 的公开游标。*为什么:* 重开能续到已解锁关 + 回原进度(不变量 #4)。
  *否掉:* 只存 PlayerState——解锁进度每次启动归零,违挂机陪伴体验。
- **D3 · 默认战士走 `data/config/starting_roster.json`(用户拍板),由 `DataRegistry` 加载校验。** 取代旧
  director 的 `@export warrior_*`。条目 = `{id, class_id, display_name, base_stats:{8 维}}`。*为什么:* 数值不
  硬编码进逻辑(hard-NO);与现有 JSON 批量数据 + DataRegistry 校验范式一致;顺带给 View 提供队伍显示名来源。
  *否掉:* `.tres` CharacterDef(新建模板类,数值少不需批量);旧 `@export`(撞 hard-NO)。
- **D4 · `DataRegistry` 仍 `RefCounted`、由 `GameController` 持有,不单独注册 autoload。** *为什么:* 它
  `extends RefCounted`,直接注册 autoload 需改 `extends Node`,会让第一批 `data_registry` 等单测里
  `DataRegistry.new()` 留 orphan(破 0-orphan)。只有 GameController 消费它,经 `Game.registry` 可达即够。
  *否掉:* 改 Node + 注册 autoload(动第一批已绿码 + 担 orphan 风险)。**→ 须回写 ARCHITECTURE §3.2(F-Arch)。**
- **D5 · 切换+删除 = 一个原子的 Engine-Integrator 步(用户拍板,步 5)。** 切 autoload、删
  `combat_director/party_member/loot_stub`、退役 7 个引用它们的旧 `test/combat/*`、场景验证、手动 Play
  必须同批完成(否则 autoload 悬空 / 旧测编译失败)。*为什么:* 删旧码与 autoload 重注册不可分,且是唯一
  需肉眼验收的引擎侧改动。*否掉:* 拆两棒(重构跨批悬而未决,徒增并存窗口)。
- **D6 · `CombatView` 原地重写(同 `src/combat/combat_view.gd` 路径)。** *为什么:* `floating_shell.tscn`
  的 CombatView 节点按脚本路径引用——原地改脚本则**场景零改动**(`@export stages` 的 stage_01/02.tres 指派
  保留),只动 `project.godot` autoload。*否掉:* 新建 View 文件(要改场景 ext_resource + 重指派 .tres)。
- **D7 · 给 `Character` 加 `display_name` 字段(含序列化)。** Entity 是纯战斗壳、无名字;View 队伍名从
  `GameController` 暴露的 `party_characters`(与 `arena.players` 同序)取,血量从 `arena.players[i]` 取。
  *为什么:* 名字属持久角色数据,不该塞进 per-run Entity。*否掉:* Entity 加 display_name(污染战斗壳)。
- **D8 · 保留 `src/combat/{enemy_def,stage_config,scene_config}.gd` 与 `test/combat/stage_config_test.gd`。**
  这三类是新战斗仍在用的 `.tres` 背书模板(`Entity.from_enemy_def`/`Progression` stages),其 .tres 不迁移、
  脚本原地保留(移动会断 .tres 的 ext_resource 脚本路径)。`stage_config_test` 不引用 director,继续绿。

## 3. Ordered steps(执行序;步 1-3 纯逻辑可单测,步 4 可编译,步 5 引擎侧不可逆)

### 步 1 — 默认 roster 配置 + Character 名字 + DataRegistry 加载校验
- **动作:**
  1. 新建 `data/config/starting_roster.json`:数组,首条战士 `{"id":"warrior","class_id":"warrior",
     "display_name":"战士","base_stats":{"attack":6,"max_hp":120,"attack_speed":1,"armor":0,
     "dodge_chance":0,"crit_chance":0,"crit_mult":2,"hp_regen":0}}`(数值平移旧 director `@export` 默认)。
  2. `src/core/meta/character.gd` 加 `var display_name: String`;`to_dict`/`from_dict` 含之。
  3. `src/core/systems/data_registry.gd` 加 `_starting_roster: Array[Character]` + `load_all` 多读
     `starting_roster.json` + `_ingest_starting_roster`(校验:id 非空、`base_stats` 键 ⊆ `GameKeys.STATS`、
     值可转 float;非法收进 `_errors` 不静默)+ 访问器 `get_starting_roster() -> Array[Character]`。
- **文件:** `data/config/starting_roster.json`(新)、`src/core/meta/character.gd`、`src/core/systems/data_registry.gd`。
- **验证:** 新 `test/core/starting_roster_test.gd`:① 合法数据 ingest → 得 1 个 `Character`,`display_name=="战士"`、
  `base_stats` 8 维齐、`build_stats().get_final(ATTACK)==6`;② 非法(stat 键拼错 / id 空)→ `is_valid()==false`
  且 `get_load_errors()` 含对应条目。`--import` 后全套仍绿(旧 director 未动)。

### 步 2 — SaveSystem(纯逻辑,round-trip 可单测)
- **动作:** 新建 `src/core/systems/save_system.gd`(`class_name SaveSystem`,`RefCounted`):
  - `to_save_dict(player_state, prog) -> Dictionary` → `{"version":1, "player": player_state.to_dict(),
    "progress": {"max_unlocked_stage":…, "cur_stage":…, "cur_scene":…}}`。
  - `save(player_state, prog, path:="user://savegame.json") -> bool` → `FileAccess` 写 `JSON.stringify`。
  - `load_file(path:="user://savegame.json") -> Dictionary` → 不存在/解析失败返回 `{}`(不抛)。
  - `apply(d, player_state, prog, registry:=null)` → `player_state.from_dict(d["player"], registry)` +
    把 `progress` 写回 `prog.max_unlocked_stage/cur_stage/cur_scene`(缺字段取默认)。
- **文件:** `src/core/systems/save_system.gd`(新)。
- **验证:** 新 `test/core/save_system_test.gd`:构造 `PlayerState`(塞 1 Character + 1 ItemInstance + 材料)+
  一个设了 `max_unlocked_stage=1,cur_stage=1,cur_scene=2` 的 `ProgressionController` → `save` 到临时
  `user://test_save.json` → 新建空 PlayerState/Prog → `load_file`+`apply` → 断言 roster/bag/材料/三游标逐一等值;
  另测 `load_file("user://不存在")=={}`。用后清理临时档。

### 步 3 — GameController 装配 + 驱动(headless 可单测)
- **动作:** 新建 `src/core/game_controller.gd`(`class_name GameController`,`extends Node`):
  - 字段:`registry: DataRegistry`、`player_state: PlayerState`、`arena: CombatArena`、
    `progression: ProgressionController`、`party_characters: Array[Character]`、`save_system: SaveSystem`、
    `const PARTY_SLOTS := 4`、`var save_path := "user://savegame.json"`。
  - `_ready()` → `_boot()`(可被测试以注入参数另调,故 `_boot` 与 `_ready` 分离)。
  - `_boot(config_dir:=DataRegistry.DEFAULT_CONFIG_DIR, load_save:=true)`:建 `registry`+`load_all(config_dir)`
    (失败 push_error 列 `get_load_errors()`,但不崩);取/建 `player_state`;**若存档存在且 load_save → `save_system.apply`
    恢复 roster+进度**,否则 `player_state.roster = registry.get_starting_roster()`;建 `arena`(`add_child`,注
    `tuning`/`registry`/`player_state`/`loot_equipment`=战士 `EquipmentComponent`)+ `progression`(`progression.arena=arena`)。
  - `begin_run(stages, stage:=cur_resume_stage, scene:=cur_resume_scene)`:`party_characters = _active_party()`、
    `arena.players = [Entity.from_character(c, registry) for c in party_characters]`(4 格 null 容错)、
    `progression.begin_run(stages, stage, scene)`、恢复存档时 `progression.max_unlocked_stage = 恢复值`。
  - 存档触发:`progression.boss_cleared` 连一个 `_autosave`;`_notification(NOTIFICATION_WM_CLOSE_REQUEST)` → `_autosave`。
    `_autosave()` = `save_system.save(player_state, progression, save_path)`。
- **文件:** `src/core/game_controller.gd`(新)。
- **验证:** 新 `test/core/game_controller_test.gd`(把 GameController 以 `auto_free` 加进树,`_boot(临时空目录或注入,
  load_save=false)`,roster 直接注 1 个测试 Character 绕开真 json):① `begin_run(测试 stages)` 后 `arena.players.size()>=1`、
  `progression.current_enemy_def()` 非空;② 反复 `arena.tick_combat()` → 敌被击杀、`progression.cur_scene` 推进
  (复用 batch-2 进度断言模式);③ `boss_cleared` 后 `save_system.load_file(临时档)` 非空、含 `progress.max_unlocked_stage>=1`;
  ④ 新 GameController `_boot(load_save=true)` 读同一临时档 → roster/进度恢复。`--import` 后全套绿。

### 步 4 — CombatView 原地重写(读新双对象;UI,仅可编译,运行验收并入步 5)
- **动作:** 重写 `src/combat/combat_view.gd`,把所有对 `/root/Combat`(director)的读改为读 `/root/Game`:
  - `_ready`:`var gc = get_node_or_null("/root/Game")`;连 `gc.arena.{hit_dealt,player_dodged,enemy_defeated,
    party_wiped,enemy_enraged,item_dropped}` + `gc.progression.{boss_cleared,rest_requested}`;按钮 →
    `gc.progression.request_push/request_rest`;`gc.begin_run(stages)`。
  - 敌人:`gc.arena.has_living_enemy()`、def 取 `gc.progression.current_enemy_def()`、当前血取首个存活
    `gc.arena.enemies` 的 `current_hp`(替换旧 `enemy_hp()`)。
  - 队伍:行 i 名字取 `gc.party_characters[i].display_name`(null 容错),血/存活取 `gc.arena.players[i]`
    的 `current_hp`/`max_hp()`/`is_alive()`;`PARTY_SLOTS` 用 `GameController.PARTY_SLOTS`。
  - 进度/按钮:`gc.progression.{mode,cur_stage,cur_scene,countdown_remaining}` + `gc.arena.enraged`;
    `Mode`/`BOSS_SCENE` 改引 `ProgressionController.Mode`/`ProgressionController.BOSS_SCENE`。
  - 掉落:删 `_on_loot_dropped(kind,rarity)`,改 `_on_item_dropped(inst: ItemInstance, dest: StringName)`:
    `rarity = inst.rarity` 决定光柱/金闪;日志读 `dest`(EQUIPPED/DECOMPOSED/BAGGED)。删 `_kind_text`/旧符号式分支。
- **文件:** `src/combat/combat_view.gd`(原地重写)。
- **验证:** `godot --headless --check-only`(脚本编译过;`/root/Game` 运行时存在性由步 5 保证)。**无自动化测试
  (UI,按 project-context §5 靠手动 Play)——运行验收并入步 5。** 此步落地后游戏处于"View 等 Game、autoload 仍 Combat"
  的中间态,不可 Play;这是预期,Play 验收在步 5 切换后。

### 步 5 —【Engine Integrator · 不可逆切换 + 全回归 + 手动 Play】
> 本步是引擎侧人工点,经 Engine Integrator 人机回报闭环。**切 autoload / 删码 / 退测 / Play 必须同批一次完成。**
- **动作:**
  1. `project.godot` autoload:删 `Combat="*res://src/combat/combat_director.gd"`;按序加
     `PlayerState="*res://src/core/meta/player_state.gd"`、`Game="*res://src/core/game_controller.gd"`
     (DataRegistry 不注册,由 Game 持有,D4)。
  2. 删 `src/combat/combat_director.gd`、`src/combat/party_member.gd`、`src/combat/loot_stub.gd`。
  3. 退役引用上述类的旧测试:`test/combat/` 下 `combat_director_test.gd`、`formula_test.gd`、`progression_test.gd`、
     `retreat_test.gd`、`button_countdown_test.gd`、`tick_driver_test.gd`、`loot_test.gd`(共 7 个;**保留
     `stage_config_test.gd`**——只测 StageConfig,不引用 director)。
  4. `godot --headless --import`(注册新 autoload/class)。
  5. **全回归:** 跑 `-a res://test` → 期望全绿:`test/core/*`(39 + 步 1-3 新增)+ `test/core/combat/*`(56)+
     `test/combat/stage_config_test.gd`,0 errors/0 failures/**0 orphans**。`--check-only` 对全项目 exit 0。
  6. **手动 Play(floating_shell.tscn):** 战斗自动跑、敌/队血条与名字正确、命中飘字+暴击、闪避 MISS、推进/修整
     按钮(GRINDING/倒计时态)、通关倒计时自动推进、掉落光柱/金闪按稀有度、Boss 通关横幅、团灭→回退刷怪;
     **存档:** Boss 通关后关程序→重开,进度续到已解锁关(`user://savegame.json` 存在、肉眼确认续档)。
- **文件:** `project.godot`;删 3 个 src + 7 个 test;无新增。
- **验证:** 上 5、6 两条全过(全绿 + 手动 Play 清单逐项 OK + 存档 round-trip 肉眼确认)。产出 INTEGRATION-STEPS.md
  记引擎侧操作与回报。

## 4. Out of scope(本批明确不做)

- **真·城镇 / 招募 / 多职业 / 技能树**:`rest_requested` 仍落 RESTING 占位(真城镇 = 后续 04/05)。
- **lane 几何 / 多敌团战实战**:`AICombatComponent` 选最前存活 + 恒在射程占位不变(数值专章)。
- **离线结算**(关程序后按时长补进度):只做"重开续档",不做离线时长结算。
- **存档版本迁移**:只留 `version:1` 字段占位,不写迁移逻辑。
- **词缀/数值精调、属性成长曲线**:并入总数值专章(承 03/04 F1)。
- **AnimationComponent 正式序列帧 / 音效 / hitstop**:符号/占位 FX 先行,正式表现待 Art Spec。
- **EnemyDef/StageConfig 的 .tres 重组或迁目录**:原地保留(D8)。

## 5. Risks & Flags / Open questions

- **〔F-Cutover〕步 5 不可逆、引擎侧、唯一手动验收点。** 缓解:步 1-4 全部并存式落绿(旧 director 仍跑),
  切换前 56 个 `test/core/combat/*` 已是公式/进度等值安全网(F6);切换在单步内原子完成,出错可回退 project.godot。
- **〔F-Arch〕D4 偏离 ARCHITECTURE §3.2「DataRegistry autoload」。** 实为 `GameController` 持有的 RefCounted。
  **建议 Arch Guard 回写 ARCHITECTURE §3.2**:DataRegistry 由 Game 持有、经 `Game.registry` 可达(改 Node-autoload
  会破第一批 0-orphan)。非阻塞,记此 flag 供 arch-guard 一并更新。
- **〔F-View-untested〕步 4 View 重写无自动化测试**(UI,project-context §5 手动 Play)。缓解:逻辑全在 Arena/Prog
  (已测),View 仅读出 + 演出;手动 Play 清单(步 5.6)逐项把关。
- **〔F-Save-trigger〕存档触发策略 = Boss 通关 + 关程序(`WM_CLOSE_REQUEST`)。** 不做定时自动存 / 离线结算(本批
  最简)。若 playtest 觉得丢档窗口大,后续加定时 autosave(留 Implementer/Producer 定,非本批)。
- **〔F-Stages-source〕关卡数据仍由 `CombatView` 的 `@export stages`(stage_01/02.tres)持有、`begin_run` 时传入
  GameController**,autoload 不持关卡数据(避免硬编码 .tres 路径,守 hard-NO)。代价:headless 测 GameController 需自
  造测试 stages(已在步 3 验证方案内)。若日后要纯后台无 View 跑全程,再引入 stage 清单配置(非本批)。
- **〔F-Producer 回写〕** 本批新增 `src/core/game_controller.gd`、`src/core/systems/save_system.gd`、
  `data/config/starting_roster.json`、新 autoload `PlayerState`/`Game` → 提示 Producer 更新 project-context §2 目录约定
  + v1 完成定义(存档/装配已就位)。非 Planner 落地项,记此待办。
- **〔Open〕`loot_equipment` 注入目标 = 战士 `EquipmentComponent`。** v1 单战士明确;多人时掉落填空目标策略(填谁的空槽)
  留后续,本批按"战士装备组件"接(承第二批 Wiring Contract §4)。
