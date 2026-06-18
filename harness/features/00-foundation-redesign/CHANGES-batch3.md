---
artifact: CHANGES
feature: 00-foundation-redesign
role: Implementer
status: draft
updated: 2026-06-19
inputs: [PLAN-batch3.md, ARCHITECTURE.md, arch/REFACTOR-01-foundation-redesign.md, CHANGES-batch2.md, REVIEW-batch2.md, src/core/meta/character.gd, src/core/meta/player_state.gd, src/core/systems/data_registry.gd, src/core/combat/combat_arena.gd, src/core/combat/progression_controller.gd, src/core/combat/entity.gd, src/combat/combat_view.gd, src/combat/combat_director.gd, data/config/*]
next: Reviewer
---

# CHANGES — 底层地基重构 · 第三批(层 6-8:表现层平迁 / 存档 / 装配收口)

> 实现 PLAN-batch3 §3 **步 1-4**(步 5 = 不可逆引擎切换,留 Engine Integrator,本批不做)。
> **关键范式延续:** 步 1-4 全是并存式新码 —— 旧 `Combat` director 仍是 autoload、`project.godot` 未动、
> 45 个旧 `test/combat/*` 全绿。本批新增 13 个测试用例(6+3+4),全套 **153/153、0 errors/0 failures/0 orphans**。
> CombatView 已原地改读 `/root/Game`,但**游戏暂处中间态不可 Play**(autoload 仍是 Combat),Play 验收并入步 5。

## 1. What changed(做了什么,按 PLAN 步骤)

### 步 1 — 默认 roster 配置 + Character 名字 + DataRegistry 加载校验
- **新增** `data/config/starting_roster.json`:数组,首条战士 `{id:warrior, class_id:warrior,
  display_name:战士, base_stats:{8 维}}`。数值平移旧 director `@export warrior_*` 默认(hp120/atk6/crit_mult2 等)。
- **改** `src/core/meta/character.gd`:加 `var display_name: String = ""`;`to_dict` 写 `"display_name"`、
  `from_dict` 读 `String(d.get("display_name",""))`。
- **改** `src/core/systems/data_registry.gd`:加 `_starting_roster: Array[Character]`;`load_all` 多读
  `starting_roster.json`(顶层须数组,否则报错);新 `_ingest_starting_roster`(校验 id 非空、`base_stats`
  键 ⊆ `GameKeys.STATS`、值为数字,违例收进 `_errors` 不静默);访问器 `get_starting_roster()`(深拷贝,
  每次 new Character 防跨局串);测试入口 `ingest_starting_roster(roster)`(并行 `ingest()`)。
- **新增测试** `test/core/starting_roster_test.gd`(6 例)。

### 步 2 — SaveSystem(纯逻辑,round-trip)
- **新增** `src/core/systems/save_system.gd`(`class_name SaveSystem`,`RefCounted`):
  `to_save_dict`(`{version:1, player:player_state.to_dict(), progress:{max_unlocked_stage,cur_stage,cur_scene}}`)、
  `save(...) -> bool`(FileAccess 写 JSON.stringify)、`load_file(path) -> Dictionary`(不存在/解析失败/顶层非对象
  → `{}` 不抛)、`apply(d, player_state, prog, registry)`(空 dict noop;否则 from_dict + 写回三游标,缺字段取默认)。
- **新增测试** `test/core/save_system_test.gd`(3 例)。

### 步 3 — GameController 装配 + 驱动(headless 可单测)
- **新增** `src/core/game_controller.gd`(`class_name GameController`,`extends Node`):
  - 字段 `registry/player_state/arena/progression/party_characters/save_system`、`const PARTY_SLOTS:=4`、
    `save_path`、`auto_boot`(测试可关)、`_resume_stage/_resume_scene`(续战游标)。
  - `_ready()` → `auto_boot` 时 `_boot()`。`_boot(config_dir, load_save)`:建 registry+`load_all`(失败 push_error 不崩)、
    `player_state`(add_child)、`arena`(add_child + 注 tuning/registry/player_state)、`progression`(`progression.arena=arena`
    + 连 `boss_cleared` → `_autosave`);**存档存在且 load_save → `apply` 恢复 roster+游标**,否则
    `roster = registry.get_starting_roster()`;记录续战游标。
  - `begin_run(stages, stage:=-1, scene:=-1)`(<0 取续战游标):建 4 格队伍(空位 null 容错)、注
    `arena.loot_equipment = 首个存活成员.equipment`、`progression.begin_run`。
  - 存档触发:`boss_cleared` + `NOTIFICATION_WM_CLOSE_REQUEST` → `_autosave`(=`save_system.save`)。
- **新增测试** `test/core/game_controller_test.gd`(4 例)。

### 步 4 — CombatView 原地重写(读新双对象;仅可编译,Play 验收并入步 5)
- **重写** `src/combat/combat_view.gd`(同路径,场景零改动):所有 `/root/Combat`(director)读出改 `/root/Game`:
  - `_ready`:`_gc = get_node_or_null("/root/Game")`;`_arena=_gc.arena`、`_prog=_gc.progression`;连
    `_arena.{hit_dealt,player_dodged,enemy_defeated,party_wiped,enemy_enraged,item_dropped}` +
    `_prog.{boss_cleared,rest_requested}`;按钮 → `_prog.request_push/request_rest`;`_gc.begin_run(stages)`。
  - 敌人:存活/血量改读 `_arena.enemies` 首个存活 Entity 的 `current_hp/max_hp()`(新 `_living_enemy()`),
    def 取 `_prog.current_enemy_def()`(名字/贴图仍走 def)。
  - 队伍:名字取 `_gc.party_characters[i].display_name`,血/存活取 `_arena.players[i]` 的 `current_hp/max_hp()/is_alive()`;
    `PARTY_SLOTS` 用 `GameController.PARTY_SLOTS`。
  - 进度/按钮:`_prog.{mode,cur_stage,cur_scene,countdown_remaining}` + `_arena.enraged`;`Mode`/`BOSS_SCENE`
    改引 `ProgressionController.Mode`/`ProgressionController.BOSS_SCENE`。
  - 掉落:删 `_on_loot_dropped(kind,rarity)` + `_kind_text`,改 `_on_item_dropped(inst: ItemInstance, dest: StringName)`
    (FX 按 `inst.rarity`,日志按 `dest` 走 `LootIntake.{EQUIPPED/DECOMPOSED/BAGGED}` → 新 `_dest_text`)。

## 2. Why(映射 PLAN 决策)

- 步1 ⟵ **D3**(默认战士走 JSON,数值不硬编码进逻辑,守 hard-NO)+ **D7**(`display_name` 属持久角色数据,
  不污染 per-run Entity)。校验沿用 DataRegistry「防策划数据错」范式(ARCHITECTURE §4#6)。
- 步2 ⟵ **D2**(存档 = PlayerState + 进度游标,重开能续到已解锁关 / 回原进度,不变量 #4)。
- 步3 ⟵ **D1**(GameController 作装配座,逻辑层独立于表现层、headless 可演算)+ **D4**(DataRegistry 仍
  RefCounted 由 GC 持有,不改 Node-autoload 避免破第一批 0-orphan)。
- 步4 ⟵ **D6**(原地重写 → 场景零改动,只待步 5 切 autoload)。读双对象(Arena 单局 + Progression 跨场)
  忠实映射 ARCHITECTURE 四层依赖方向(表现层只读逻辑层)。

## 3. How verified(怎么验的)

- **步 1:** `test/core/starting_roster_test.gd` 6/6 —— 实发 json 加载得战士(`display_name=="战士"`、8 维齐、
  `build_stats().get_final(ATTACK)==6`/`MAX_HP==120`);深拷贝隔离;非法(stat 拼错 `attck` / id 空 / 值非数字)
  各 `is_valid()==false` 且 `get_load_errors()` 含对应串。
- **步 2:** `test/core/save_system_test.gd` 3/3 —— PlayerState(1 Character+1 ItemInstance+材料)+ 三游标
  save→load_file→apply 后 `to_dict` 全量等值 + 三游标逐一等值;读不存在档 `{}`;空档 apply noop。临时档用后清理。
- **步 3:** `test/core/game_controller_test.gd` 4/4 —— begin_run 后 4 格队伍(`players[0]` 非空、`players[1]` null
  容错)+ 敌人就位;tick → 杀场景怪推进到 BOSS_SCENE;Boss 通关 → 自动落档(临时档 `max_unlocked_stage==1`);
  新 GC 读同档 → roster/`display_name`/进度恢复。
- **步 4:** `godot --headless --check-only --script .../combat_view.gd` exit 0(编译过);全文 grep 无残留
  `_combat`/`CombatDirector`/`loot_dropped`/`_kind_text`/`enemy_hp()`。**无自动化测试(UI),Play 验收并入步 5。**
- **全回归(独立重跑全套):** `153/153 | 0 errors | 0 failures | 0 orphans`,exit 0,25 suites。
  含旧 `test/combat/*` 45 例全绿 —— 旧 director、`project.godot`、45 旧测一字未动(并存式约束守住)。

## 4. Wiring Contract(接线契约 —— 步 5 Engine Integrator 必读)

> 本批落地「View 已读 Game、autoload 仍 Combat」的中间态。下列接线必须由步 5 一次原子完成,否则 autoload
> 悬空 / 旧测编译失败 / View 取不到 `/root/Game`。

### 4.1 autoload 改动(`project.godot`,步 5 执行)
- **删** `Combat="*res://src/combat/combat_director.gd"`。
- **按序加**(顺序要紧:PlayerState 先于 Game,但 Game 自建自己的 player_state,故二者无强依赖;仍建议此序):
  - `PlayerState="*res://src/core/meta/player_state.gd"`
  - `Game="*res://src/core/game_controller.gd"`
- **不注册** DataRegistry(D4:由 `Game.registry` 持有,经 `/root/Game` 可达;它 `extends RefCounted`,
  注 autoload 需改 Node 会破第一批 0-orphan)。

  ⚠️ **注意 PlayerState autoload 与 GameController 自建 player_state 的二重性:** 当前 `GameController._boot`
  内部 `PlayerState.new()` + `add_child`,**不**读 `/root/PlayerState`。若步 5 注册了 `PlayerState` autoload,
  会出现"两个 PlayerState"(一个空 autoload、一个 GC 持有的真身)。**建议步 5 二选一**:① 不注册 PlayerState
  autoload(View/存档都经 `Game.player_state` 取,最简、与本批测试一致);② 若 Producer 要 `/root/PlayerState`
  全局可达,则改 `_boot` 复用 `/root/PlayerState` 而非自建。**本批按 ①(GC 自持)实现并测过;PLAN 步 5.1
  列了注册 PlayerState —— 此处偏差需 Engine Integrator/Planner 拍板,记为 〔F-PS-autoload〕(见 §6)。**

### 4.2 删除的源文件(步 5)
- `src/combat/combat_director.gd`、`src/combat/party_member.gd`、`src/combat/loot_stub.gd`。

### 4.3 退役的旧测试(步 5,共 7 个;**保留 `stage_config_test.gd`**)
- `test/combat/` 下:`combat_director_test.gd`、`formula_test.gd`、`progression_test.gd`、`retreat_test.gd`、
  `button_countdown_test.gd`、`tick_driver_test.gd`、`loot_test.gd`。

### 4.4 View ↔ Game 运行时契约(已在本批 View 代码落定,步 5 切 autoload 后即生效)
- View 取 `/root/Game`(GameController);经 `gc.arena`(CombatArena)+ `gc.progression`(ProgressionController)
  + `gc.party_characters`(Array[Character],与 `arena.players` 同序)读全部表现数据。
- View 连接的信号:**arena** 发 `hit_dealt(amount,is_crit)` / `player_dodged(member_index)` /
  `enemy_defeated(enemy:EnemyDef)` / `party_wiped` / `enemy_enraged` / `item_dropped(instance:ItemInstance,
  destination:StringName)`;**progression** 发 `boss_cleared(stage)` / `rest_requested`。
- View 调的方法:`gc.begin_run(stages)`(stages 来自 View 的 `@export stages`,F-Stages-source);
  `gc.progression.request_push()` / `request_rest()`。
- 场景:`floating_shell.tscn` 的 CombatView 节点脚本路径不变(原地重写),`@export stages`(stage_01/02.tres)
  指派保留 —— **步 5 零场景改动**。

### 4.5 数据/存档契约
- 存档路径 `user://savegame.json`;格式 `{version:1, player:{roster,bag,materials}, progress:{max_unlocked_stage,
  cur_stage,cur_scene}}`。触发 = Boss 通关 + 关程序(`WM_CLOSE_REQUEST`)。
- 默认开局 roster ⟵ `data/config/starting_roster.json`(经 `DataRegistry.get_starting_roster()`)。
- 掉落填空目标 `arena.loot_equipment` = 首个存活成员(v1 战士)的 `EquipmentComponent`(承第二批契约 §4)。

## 5. Deviations(偏离 PLAN —— 全部记录)

- **〔Dev-1 · begin_run 默认参数用 -1 哨兵〕** PLAN 写 `begin_run(stages, stage:=cur_resume_stage,
  scene:=cur_resume_scene)`。GDScript 默认参数引用实例成员不可靠 → 改 `stage:=-1, scene:=-1`,<0 时取
  `_resume_stage/_resume_scene`。语义等价,更稳。
- **〔Dev-2 · loot_equipment 注入时机移到 begin_run〕** PLAN 步3 写"`_boot` 注 loot_equipment=战士
  EquipmentComponent"。但战士 Entity 在 `begin_run` 才建(其 `EquipmentComponent` 随之新建)。若 `_boot`
  注一个独立 EquipmentComponent,掉落 buff 不会落到正在战斗的 Entity 上(数据不一致)。故改在 `begin_run`
  把 `arena.loot_equipment` 指向**当局战士 Entity 的** equipment。更正确,守 §4.5 契约。
- **〔Dev-3 · 加 `auto_boot` 字段〕** PLAN 未列。为让 headless 测以注入 config_dir/load_save 调 `_boot`(避免
  `_ready` 自动 boot 撞真存档 / 重复 add_child),加 `var auto_boot := true`,测试置 false。不影响生产路径
  (默认 true,`_ready` 照常 boot)。

## 6. Flags / Open(待下游处置)

- **〔F-PS-autoload〕(本批新提,需拍板)** 见 §4.1:PLAN 步 5.1 列注册 `PlayerState` autoload,但本批
  GameController 自持 player_state(不读 `/root/PlayerState`)。直接注册会致二重 PlayerState。**建议步 5 采
  §4.1 方案①(不注册 PlayerState autoload,全经 `Game.player_state`)**,或由 Planner 改 `_boot` 复用全局。
  非阻塞步 1-4,但 Engine Integrator 切 autoload 前必须定。
- **〔F-Cutover〕** 步 5 不可逆、引擎侧、唯一手动验收点(承 PLAN §5)。本批 56 个 `test/core/combat/*` +
  13 新 `test/core/*` 是切换前的等值安全网。
- **〔F-Arch〕** D4 偏离 ARCHITECTURE §3.2「DataRegistry autoload」(实为 GC 持有的 RefCounted)。建议
  Arch Guard 回写 §3.2。承 PLAN-batch3 §5。
- **〔F-View-untested〕** 步4 View 重写无自动化测试(UI,project-context §5 手动 Play)。逻辑全在已测的
  Arena/Prog;Play 清单(PLAN 步 5.6)逐项把关。
- **〔F-Stages-source〕** 关卡数据仍由 View `@export stages` 持有、`begin_run` 传入 GC(autoload 不持关卡
  数据,守 hard-NO 不硬编码 .tres 路径)。承 PLAN §5。
- **〔F-Producer 回写〕** 本批新增 `game_controller.gd`、`save_system.gd`、`starting_roster.json` + 待加
  autoload `Game`(/PlayerState) → 提示 Producer 更新 project-context §2 目录约定 + v1 完成定义。承 PLAN §5。
- **〔Open · loot_equipment 多人策略〕** v1 单战士明确;多人时掉落填谁的空槽留后续。承第二批 + PLAN §5。
