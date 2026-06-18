---
artifact: CHANGES
feature: 00-foundation-redesign
role: Implementer
status: draft
updated: 2026-06-19
inputs: [PLAN-batch2.md, ARCHITECTURE.md, arch/REFACTOR-01-foundation-redesign.md, CHANGES.md, src/combat/combat_director.gd, src/combat/enemy_def.gd, test/combat/formula_test.gd, test/combat/combat_director_test.gd, test/combat/tick_driver_test.gd, test/combat/progression_test.gd, test/combat/retreat_test.gd, test/combat/button_countdown_test.gd]
next: Reviewer
---

# CHANGES — 底层地基重构 · 第二批(层 5:战斗层重构 / 替换 CombatDirector)

> 按 PLAN-batch2 §3 七步(5a–5g)有序实现。本批**只做 REFACTOR-01 §4 的层 5**:把 438 行 God object
> `CombatDirector` 重构成 ARCHITECTURE §3 的组件化战斗层。**与旧 `src/combat/*` 并存**:零改旧战斗码
> (除 `enemy_def.gd` 加 `item_level` 一字段,D6 预授权)、零改现有 45 个 `test/combat/*`、零动 `project.godot`(D1)。
> 真实代码落 `src/core/combat/` + `test/core/combat/`;本文件是 harness 内唯一产物。
> 工具链:`G:\Godot\Godot_v4.6.3\godot.exe`,每步自跑 gdUnit4 验绿(warnings-as-errors,`auto_free()` 须显式标类型)。

## 1. What changed(改了什么)

**新战斗核心(`src/core/combat/`,全新增)**

- **`combat_tuning.gd`(`CombatTuning`,`RefCounted`)** — 可注入调参常量(承 director @export):`armor_k=50.0`、`enrage_threshold_sec=25.0`、`enrage_ramp_per_sec=0.5`、`stage_clear_countdown_sec=5.0`、`tick_seconds=0.1`;`enrage_mult(fight_time, enraged)`(承 director `_enrage_mult` :229-232)。
- **`entity.gd`(`Entity`,`RefCounted`)** — 战斗实体空壳:持 `stats/equipment/skill/ai` 组件 + 单场运行时 `current_hp` + `team:enum{PLAYER,ENEMY}` + `lane`(占位)+ `source_enemy_def`。`max_hp()`、`is_alive()`、`take_damage`(floor 0)、`heal`(cap max_hp)、`reset_swing()`。工厂 `from_character(c, registry)`(base_stats→StatsComponent + 装备经 EquipmentComponent 注入,血满)/ `from_enemy_def(def)`(8 维进 base,血满)。
- **`skill_component.gd`(`SkillComponent`,`RefCounted`)** — 6 维公式落点:`attack_progress` + `accumulate(aspd, dt)` + `pending_swings()`(离散出手,guard<1000);`resolve_hit(attacker, target, tuning, rng, damage_mult:=1.0) -> {amount, is_crit, dodged}`(暴击→闪避→护甲减伤,denom≤0 跳过防 NaN)。读值全经 `attacker.stats.get_final(...)`。
- **`ai_combat_component.gd`(`AICombatComponent`,`RefCounted`)** — `select_target(self, enemies)`(首个存活,无则 null,承 `_front_living_member`);`in_range(...)→true`(v1 占位,F4)。
- **`combat_arena.gd`(`CombatArena`,`Node`)** — 单局编排 + 固定步长 tick(承 director :115-226 逐条等值):`start_battle` / `tick_combat`(缠斗计时+软狂暴 → 回血 → 我方攻 → 敌死结算 → 敌攻含 enrage_mult → 团灭)/ `_process` 累加器。信号同名同义供层 6 平迁:`hit_dealt`/`player_dodged`/`enemy_defeated`/`party_wiped`/`enemy_enraged` + 新 `item_dropped(instance, destination)`。掉落钩子 `_drop_loot`(5e)。
- **`progression_controller.gd`(`ProgressionController`,`RefCounted`)** — 跨场推进 FSM(承 director :242-396 逐条等值):`Mode{PROGRESSING,GRINDING,STAGE_CLEAR_COUNTDOWN,RESTING}`、`QueuedAction{NONE,PUSH,REST}`、`BOSS_SCENE=3`、游标 `cur_stage/cur_scene/max_unlocked_stage`。`begin_run`(回写 `arena.progression=self`)/ `current_enemy_def` / `advance_after_kill` / `retreat_after_wipe`(四条回退)/ `request_push|rest` / `process_countdown` / 私有 `_spawn_current/_execute_push/_enter_rest/_revive_party`。内部 `new` 敌实体 = RefCounted,headless 无 orphan。

**唯一的 `src/combat/*` 改动(D6 预授权)**
- `src/combat/enemy_def.gd` — `@export var item_level: int = 1`(additive,旧 `weight_*`/`rarity_weight_*` 不删;见第一批 CHANGES 已记)。**本批未再动**(第一批 5e 已加),此处仅复述其归属。

**测试(`test/core/combat/`,全新增,不碰 `test/combat/`)**
- `entity_test.gd`(4)、`skill_component_test.gd`(10)、`ai_combat_test.gd`(4)、`combat_arena_test.gd`(19)、`arena_loot_test.gd`(3)、`progression_test.gd`(6)、`retreat_test.gd`(6)、`button_countdown_test.gd`(4)= **56 新单测**,断言值逐条照抄旧 `formula/combat_director/tick_driver/progression/retreat/button_countdown` 测,改为驱动 Arena+Progression。

## 2. Why(对应 PLAN 步骤/决策)

| 改动 | PLAN-batch2 依据 |
|------|-----------|
| 新核心全落 `src/core/combat/`,零碰旧 director / 45 旧测试 / `project.godot` | D1(旧 director=运行中对照锚,退役留层 8) |
| `CombatArena`(单局)与 `ProgressionController`(跨场 FSM)拆两类 | D2(ARCHITECTURE §3.2 职责正交,破 God object 根因) |
| 6 维公式搬 `SkillComponent.resolve_hit`,`current_hp`→Entity、`attack_progress`→Skill,Arena 每 tick 驱动 | D3(公式不丢、读 `get_final` 根除扁平字段) |
| 调参收进可注入 `CombatTuning` | D4(数值不硬编码,测试注入) |
| 逻辑组件 `RefCounted`、Arena 显式方法调用驱动(不靠 `_process`) | D5(headless 确定 + 帧率无关,不变量 #3) |
| 敌死接新 PoE 流水线(`LootGenerator`→`LootIntake`),`EnemyDef` 加 `item_level` | D6(ilvl 来源=战斗侧,复用层 4 已测流水线) |
| AI 选最前存活、lane 恒在射程占位 | D7(等值迁 `_front_living_member`,lane 几何留数值专章) |
| 软狂暴=每场计时,开新战斗复位 | D8(单敌语义直迁,多敌细化留数值专章) |

## 3. How verified(怎么验的)

- **逐步 gdUnit4 收口**(每步:写码 → `--headless --import`(注册新 `class_name`)→ 跑该步 suite):5a `entity_test` 4/4、5b `skill_component_test` 10/10、5c `ai_combat_test` 4/4、5d `combat_arena_test` 19/19、5e `arena_loot_test` 3/3、5f `progression+retreat+button_countdown` 16/16。
- **全量回归闸(5g)**:全套 `-a res://test` → **140 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | 22/22 suites | exit 0**。
  - 拆分:**45 个现有 `test/combat/*` 一字未改仍 45/45 绿**(D1 回归锚已守)+ 39 第一批 `test/core/*` + **56 新 `test/core/combat/*`**。
  - `--import` 后 **0 orphans**(Entity/Progression 退 `RefCounted`,内部 new 敌实体不留游离 Node)。
  - `--check-only` 对新脚本 exit 0;全套测试编译通过 = 0 编译错的等价证据。
- gdUnit4 调用:`godot.exe --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/...`(`--ignoreHeadlessMode` 须在脚本路径**之后**作脚本参数)。
- **F7 顺序断言已落**:`arena_loot_test.test_defeat_and_drop_fire_from_same_kill_in_order` 断 `[defeated, dropped]` 由同一次敌死按序触发;`combat_arena_test` 含"敌死即结束本 tick、新生敌不反击"的语义。

## 4. Deviations(与 PLAN 的偏差)

- **〔软决策 F5 兑现 → Entity 退 `RefCounted`〕** PLAN-batch2 D5/步 5a 把 `Entity` 定为 `Node2D` 空壳,但带"若纯逻辑测有摩擦可退 `Node` 并回写"的预授权。实现中验出:`ProgressionController` 每场内部 `new` 敌 `Entity`(非 `auto_free`),`Node2D` 会在 headless 测留 **orphan**。故按 F5 预授权退为 **`RefCounted`**(比建议的 `Node` 更彻底,纯逻辑层无需在树)。表现层(层 6)另挂可视 `Node` 引用本实体,不混入战斗逻辑层;`lane` 仍作数据位保留。**建议追认。**
- **〔Arena 内部 `_battle_restarted` 标志,等价 director 行为〕** director 单敌:一次击杀后 `return`,新生敌当 tick 不反击(:197-204)。新 Arena 是多敌数组,故加 `_battle_restarted`(`start_battle` 置真、`tick_combat` 顶复位):击杀触发 progression 推进/补刷(经 `start_battle`)后即结束本 tick。**这是为复刻 director 单敌语义所必需**——直接关系 grind/retreat 的逐 tick 血量算术(retreat 的 90/90/80/100 序列)。非语义漂移,而是 F7 等值的保障。
- **〔`item_dropped` 信号为新增〕** director 无此信号(旧用 `loot_dropped(kind,rarity)` 符号式)。新 Arena 发 `item_dropped(ItemInstance, destination)` 供层 6 View;旧 `loot_dropped` 随旧 director 留到层 8 退役(F2)。
- **〔F2 按默认推进〕** 用户拍"F2 按默认":旧符号式掉落(`loot_test.gd` 6 例 + `EnemyDef.weight_*`/`rarity_weight_*` + director `_roll_loot`)**不迁移、不删**,随旧 director 留层 8 退役。本批新掉落由 `arena_loot_test` + 层 4 的 `loot_generator_test`/`loot_intake_test` 覆盖。
- 无算法/结构性偏差;6 维公式、进度 FSM、四条回退、倒计时/修整断言值均逐条等值。

## 5. Wiring Contract(给第三批 Planner / Engine Integrator / 接线)

**本批纯逻辑战斗核心:零新场景节点、零 `.tscn`、零新插件、零 autoload 注册、零 `project.godot` 改动。** 旧 `Combat` autoload 仍指向旧 `combat_director.gd`,运行时行为不变。接线面如下,**第三批层 6-8 消费**:

1. **新增 `class_name`(已确认不与现有 / Godot 4.6 内置撞车,F-R3 范式):**
   `CombatTuning`、`Entity`、`SkillComponent`、`AICombatComponent`、`CombatArena`、`ProgressionController`。
   - **加新 `class_name` 后引擎须先跑一次 `--import`** 才能让其它脚本解析到它。
2. **层 6(表现层)接线点 —— View 平迁信号:** `CombatArena` 发的 `hit_dealt(amount, is_crit)`、`player_dodged(member_index)`、`enemy_defeated(EnemyDef)`、`party_wiped`、`enemy_enraged` 与旧 director **同名同义**,层 6 `CombatView` 改 `connect` 到 Arena 实例即可。新增 `item_dropped(ItemInstance, destination)` 供掉落飘字 / 背包提示。`ProgressionController` 发 `boss_cleared(stage)`、`rest_requested`。
3. **层 8(Engine Integrator)autoload 切换:** 当前 `project.godot` 的 `Combat` autoload = 旧 director。层 8 重注册为新系统集(Arena+Progression+DataRegistry+PlayerState 的装配),并**删除 `combat_director.gd`/`party_member.gd`/`loot_stub.gd`、退役 `loot_test.gd` 等被取代的旧测试**(F2/F6)。删旧码与 autoload 重注册**必须同批**,否则 autoload 悬空。
4. **装配契约(新战斗一局怎么搭起来):**
   - 建 `CombatArena`(Node);注 `arena.tuning`(`CombatTuning`)、`arena.rng`(可 seed)。
   - 玩家:`arena.players = [Entity.from_character(c, registry), ...]`(`Array[Entity]`)。
   - 掉落接线(可选,空则纯解算):`arena.registry`/`arena.player_state`/`arena.loot_equipment`(掉落填空目标 = 战士 `EquipmentComponent`)。
   - 进度:`var prog := ProgressionController.new(); prog.arena = arena; prog.begin_run(stages, stage, scene)`(`begin_run` 自动回写 `arena.progression = prog` 并刷首敌)。
   - 驱动:`running` 期 Arena `_process` 自走固定步长(每步 `progression.process_countdown` + `tick_combat`);headless 测可直接调 `arena.tick_combat()` / `prog.process_countdown(dt)`。
5. **回归锚转移(F6):** 本批 56 新 `test/core/combat/*` = 层 8 删旧 director 后的**唯一安全网**(旧 45 锚随旧码退役)。公式/进度断言值已逐条照抄不缩水。

## 6. Flags(实现期回执)

- **〔F1 已守〕新旧并存一批。** 旧 director + autoload 在跑,新核心仅测试消费;切 autoload + 删旧码 = 层 8。
- **〔F2 已决(用户拍"按默认")〕旧符号式掉落不迁移、不删,随旧码留层 8 退役。** 45 旧测试本批原样全绿。
- **〔F3/F4 已守(占位)〕软狂暴每场计时、lane 恒在射程。** 单敌语义,保现有断言;多敌细化留数值专章。
- **〔F5 已兑现并加强〕`Entity` 退 `RefCounted`(非建议的 `Node`)。** 见 §4 偏差,建议追认。`ProgressionController` 亦 `RefCounted`(无 `_process`,Arena 驱动)。
- **〔F6 已交棒〕回归锚转移第三批。** 新套等值迁移、断言不缩水(已绿)。
- **〔F7 已落〕大类拆分顺序等价。** `_battle_restarted` 保单敌"击杀后即结束本 tick"语义;`arena_loot_test` 含敌死→掉落→推进同序断言。

## 7. 交接

- **本批代码侧 done**(140/140 全套绿,0 orphans;纯逻辑,无 UI 手动验收点)。
- **下一步**:Reviewer 审本批(独立重跑 + 核 6 维公式/四条回退/倒计时断言逐条等值 + F5/F7 偏差);审后开**第三批 PLAN**(REFACTOR-01 层 6-8:`CombatView` 改读新信号 / `SaveSystem` 落盘 `PlayerState` / autoload 重注册 + 删旧 director + 退役旧符号掉落测试,经 Engine Integrator 人机回报闭环)。
