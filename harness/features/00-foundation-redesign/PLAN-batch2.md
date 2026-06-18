---
artifact: PLAN
feature: 00-foundation-redesign
role: Planner
status: draft
updated: 2026-06-19
inputs: [project-context.md, ARCHITECTURE.md, arch/REFACTOR-01-foundation-redesign.md, PLAN.md, CHANGES.md, REVIEW.md, src/combat/combat_director.gd, src/combat/party_member.gd, src/combat/enemy_def.gd, test/combat/formula_test.gd, test/combat/progression_test.gd, test/combat/retreat_test.gd, test/combat/button_countdown_test.gd, test/combat/loot_test.gd, test/combat/tick_driver_test.gd]
next: Implementer
---

# PLAN — 底层地基重构 · 第二批(层 5:战斗层重构 / 替换 CombatDirector)

> 本 PLAN **只覆盖 REFACTOR-01 §4 的层 5**(战斗层重构)。用户 2026-06-19 拍:层 5 是整套重构里最大、
> 最高风险、且**纯逻辑可自交付**的核心,单独成批;层 6-8(表现层 / 存档 / autoload 接线 + 退役旧码)
> = **第三批,本批全绿后单开**(含 Engine Integrator 人机回报闭环)。
> 设计源:`harness/ARCHITECTURE.md` §3(组件边界)+ `arch/REFACTOR-01` §4#5;6 维公式源 = 现 `combat_director.gd:166-232` + `test/combat/formula_test.gd`。
> 第一批(层 1-4)产物 = 本批地基:`StatsComponent`/`EquipmentComponent`/`Character`/`PlayerState`/`LootGenerator`/`LootIntake`/`DataRegistry` 已就位、84/84 绿。

## 1. Goal

把 440 行 God object `CombatDirector` 重构成 ARCHITECTURE §3 的组件化战斗层(`Entity` 空壳 + `SkillComponent` 承 6 维公式 + `AICombatComponent` 目标选择 + `CombatArena` 编排 + `ProgressionController` FSM),从 `Character`/`EnemyDef` 快照生成战斗实体,**全部以 gdUnit4 收口**。**6 维公式断言值逐一保持不变**(回归锚)。**本批与旧 `src/combat/*` 并存:零改旧战斗码、零改现有 45 个测试、零动 `project.godot`** —— 旧 director 仍作运行中的对照锚,退役与 autoload 切换留第三批层 8。

## 2. Approach & key decisions

> 每条:决策 + 为什么 + 否掉的备选。

- **D1 · 并存,不删旧、不接线。** 新战斗核心全落 `src/core/combat/`,旧 `combat_director.gd`/`party_member.gd`/`loot_stub.gd` 原样不动、`project.godot` 不碰、现有 45 个 `test/combat/*` 一字不改。新核心由**自带的新测试套**(`test/core/combat/`)证明正确,公式断言值**与 `formula_test.gd` 逐条等值**。
  **Why:** 沿用第一批 D1/D2 成功范式——旧测试 100% 不变 = "未破坏"最硬证据;层 5 不引入 Engine Integrator / 人机点,Implementer 可纯 gdUnit4 自交付;新套绿 = 第三批切 autoload + 删旧码 + 退役旧测试的安全网。`project.godot` 的 `Combat` autoload 仍指向旧 director,删旧码会让 autoload 悬空 → 故删除/切换必须与 autoload 重注册同批做(层 8)。
  **否掉:** "层 5 就把 director 删了、tests 改造成读 Arena" —— 会同时改回归锚 + 让 autoload 悬空 + 拖进 Engine Integrator,风险前移,违背"逐层落定、每批全绿再下一批"。

- **D2 · `CombatArena`(战斗编排 + tick)与 `ProgressionController`(进度 FSM)拆成两个类,不像 director 揉成一锅。** Arena 跑一局战斗 + 发 `enemy_defeated`;Progression 监听 → 推游标 / 回退 / 倒计时 → 令 Arena 开下一场。
  **Why:** ARCHITECTURE §3.2 明确分列二者,职责正交(一局解算 vs 跨局/跨场推进)。**否掉:** 保留 director 式单类——正是被诊断的 God object 根因(REFACTOR-01 §2)。

- **D3 · 6 维公式搬入 `SkillComponent.resolve_*`,值不变;`current_hp` 落 `Entity`、`attack_progress` 落 `SkillComponent`,回血 + 出手节奏由 `CombatArena` 每 tick 驱动(读 `StatsComponent` 最终值)。**
  映射(逐条对照 `combat_director.gd`):暴击(:188-190 `crit_chance`/`crit_mult`)、闪避(:215 目标 `dodge_chance`)、护甲(:219-220 `raw×(1-armor/(armor+K))`,denom≤0 跳过防 NaN)、回血(:177 `+hp_regen×dt` 封顶 max_hp)、攻速 cadence(:182-194 `attack_progress += attack_speed×dt`,离散多次/tick,首杀 break)、软狂暴(:170-173 计时触发 + :229-232 `1+ramp×(t-threshold)` 倍率)。
  **Why:** ARCHITECTURE §3.1 指定 SkillComponent 做"伤害结算(6 维公式搬入此处)";`StatsComponent.get_final` 取 attack/attack_speed/crit_*/armor/dodge/hp_regen,根除扁平字段。**否掉:** 公式留 Arena —— Arena 会重蹈 director 解算 + 编排纠缠。

- **D4 · 战斗调参常量(`armor_k`/`enrage_threshold_sec`/`enrage_ramp_per_sec`/`stage_clear_countdown_sec`/`tick_seconds`)收进可注入的 `CombatTuning`(`RefCounted`),由 `CombatArena` 持有、传 `SkillComponent` 解算用。**
  **Why:** 守 hard-NO"数值不硬编码";测试像旧 `d.armor_k=50`/`d.enrage_threshold_sec=0.5` 那样注入 tuning。**否掉:** 写死进公式 —— 撞 hard-NO、不可测边界。（精调曲线仍占位,留数值专章。）

- **D5 · `Entity` = `Node2D` 空壳(持组件 + 运行时 `current_hp`/队伍/排位;工厂 `from_character(c, registry)` / `from_enemy_def(def)`);战斗逻辑组件(`SkillComponent`/`AICombatComponent`)= `RefCounted`,由 `CombatArena` **直接方法调用**驱动(不靠 `_process`)。**
  **Why:** ARCHITECTURE §6 软决策——表现/在树才需 Node;Arena 显式 tick 保 headless 确定 + 帧率无关(不变量 #3),gdUnit4 易测。`Entity` 用 Node2D 以备层 6 挂 `AnimationComponent`/排位可视。**否掉:** 组件全靠 `_process` 自驱 —— 破固定步长确定性、难测。**(若 Implementer 验出 Node2D 在纯逻辑测里有摩擦,可临时退 `Node`,回写本决策。)**

- **D6 · 新掉落流水线接进 `CombatArena`:敌死 → `LootGenerator.generate(slot, EnemyDef.item_level, rarity, registry, rng)` → `LootIntake.handle_drop(...)` 入 `PlayerState`;Arena 发一个掉落信号供层 6 View。给 `EnemyDef` **新增** `item_level`(纯加字段,不删旧权重字段)。**
  **Why:** D8(第一批)定 ilvl 来源 = 战斗侧,正落本层;复用层 4 已测的 PoE 流水线。`EnemyDef.item_level` 加字段是 additive,旧 director 的 `_roll_loot`/`loot_dropped`/`weight_*` 与 `loot_test.gd`(旧符号式掉落)**不碰、随旧 director 一起留到层 8 退役**(见 F2)。
  **否掉:** 本层也 roll 旧符号式 kind/rarity —— 与层 4 PoE 流水线重复、且那套已被取代。

- **D7 · `AICombatComponent` 目标选择 = 选敌对阵营**最前存活**(集火);lane 射程/接近 = v1 占位"恒在射程"。**
  **Why:** 守 director `_front_living_member` 行为 = 现有进攻/受击测试可等值迁移;多敌 lane 几何 / 集火-AoE / 接近时长 = ARCHITECTURE §6 占位、留 playtest 数值专章。**否掉:** 本层就实装 lane 几何 —— 数值未定、超纲(违 hard-NO 不提前抽象未定系统)。

- **D8 · 软狂暴计时 = `CombatArena` 上的**每场战斗**计时器(承 director `_enemy_fight_time`),开新战斗复位。**
  **Why:** 单敌语义直迁、保 `test_soft_enrage_*` 等值;多敌下"每敌计时"是数值/设计细化,占位先行。**否掉:** 本层就做 per-enemy 狂暴 —— 越界进未定数值。

## 3. Ordered steps

> 目录建议(Implementer 确认无 `class_name` 撞车后落定;新名勿撞 `CombatDirector`/`PartyMember`/`CombatView` 等现有):
> ```
> src/core/combat/   combat_tuning.gd  entity.gd  skill_component.gd
>                    ai_combat_component.gd  combat_arena.gd  progression_controller.gd
> test/core/combat/  各 *_test.gd
> ```
> **所有数值占位**(守 04 §8 F1 / 03 F1)。新测试的公式断言值**逐条照抄 `formula_test.gd`**。每步独立 gdUnit4 收口;每步末 `godot --headless --check-only` 必 0 错。**全程不碰 `src/combat/*`、不碰 `test/combat/*`、不碰 `project.godot`。**

### 5a — 实体 + 调参地基

1. **`CombatTuning`(`RefCounted`)+ `Entity`(`Node2D`)骨架与工厂。**
   - `CombatTuning`:`armor_k=50.0`、`enrage_threshold_sec`、`enrage_ramp_per_sec`、`stage_clear_countdown_sec`、`tick_seconds=0.1`(占位,可注入)。
   - `Entity`:`team:enum{PLAYER,ENEMY}`、`stats:StatsComponent`、`equipment:EquipmentComponent`、`skill:SkillComponent`、`ai:AICombatComponent`、运行时 `current_hp`、排位占位;`is_alive()`、`max_hp()→stats.get_final(MAX_HP)`、`take_damage(amount)`、`heal(amount)`(封顶 max_hp)。
   - 工厂:`from_character(c:Character, registry:DataRegistry)`(base_stats→StatsComponent + 装备经 EquipmentComponent 注入,`current_hp=max_hp`);`from_enemy_def(def:EnemyDef)`(8 维→StatsComponent base,`current_hp=max_hp`)。
   - 文件:`src/core/combat/{combat_tuning,entity}.gd`。
   - **Verify:** `test/core/combat/entity_test.gd` —— 由 `Character{base_stats:{attack:5,max_hp:100}}` + 一件武器建实体 → `max_hp()`/各 `get_final` 等于 StatsComponent 注入后值;由 `EnemyDef` 建 → 读敌 8 维;`take_damage`/`heal` 边界(封顶、不负)。`--check-only` 0 错。

### 5b — 技能/伤害解算(6 维公式落点)

2. **`SkillComponent`(`RefCounted`):出手节奏 + 6 维伤害解算。**
   - 持 `attack_progress`;`accumulate(dt)`(`+= attack_speed_final × dt`)、`pending_swings()→int`(取整出手次数、扣减 progress、guard<1000)。
   - `resolve_hit(target:Entity, tuning, rng) -> {amount:float, is_crit:bool, dodged:bool}`:暴击(自 `crit_chance`/`crit_mult`)→ 闪避(target `dodge_chance`)→ 护甲减伤(`raw×(1-armor/(armor+K))`,denom≤0 跳过)。读各值经 `stats.get_final`。
   - 文件:`src/core/combat/skill_component.gd`。
   - **Verify:** `test/core/combat/skill_component_test.gd`(注入 `rng.seed`)—— 暴击 chance=1 → `amount=atk×crit_mult`、`is_crit`;chance=0 → 原值不暴;dodge=1 → `dodged`、amount 不施加;armor==K → 减伤恰 50%(atk×0.5);armor=0 → 全额。**值逐条对齐 `formula_test.gd:26-101`。**

### 5c — AI 目标选择

3. **`AICombatComponent`(`RefCounted`):选敌对阵营最前存活 + 占位射程。**
   - `select_target(self_entity, enemies:Array[Entity]) -> Entity`(首个 `is_alive()`,无则 null);`in_range(self, target)→true`(v1 占位)。
   - 文件:`src/core/combat/ai_combat_component.gd`。
   - **Verify:** `test/core/combat/ai_combat_test.gd` —— 跳过已死、返回最前存活;全死返 null。

### 5d — 战斗编排(替换 director 的解算 + tick)

4. **`CombatArena`(`Node`,per-run):固定步长累加器 + 一局编排 + 信号。**
   - 持 `players:Array[Entity]`、`enemies:Array[Entity]`、`tuning`、`rng`、每场计时 `battle_time`、`enraged`。
   - `start_battle(enemy_entities)`:置敌、复位 `battle_time`/`enraged`/各 `attack_progress`。
   - `tick_combat()`:① `battle_time += dt`、过阈值首次 → `enraged=true` + `enemy_enraged.emit()`;② 回血(各存活 entity `heal(hp_regen×dt)`);③ 我方进攻:每 player `skill.accumulate(dt)` → 逐次 `select_target` + `resolve_hit` → `target.take_damage` + `hit_dealt.emit(amount,is_crit)` / `player_dodged.emit(idx)`,敌死即 break + `enemy_defeated.emit(def)`;④ 敌进攻:敌 `skill.accumulate(dt)`,伤害 ×`enrage_mult(battle_time,tuning)`,打我方最前存活(闪避→护甲);⑤ 全员倒 → `party_wiped.emit()`。
   - `_process(delta)`:`_accum += delta; while _accum>=tick_seconds and guard<1000: _accum-=tick_seconds; process_countdown(...); tick_combat()`(承 director:115-125;但 countdown 委托 Progression,见步 6)。
   - 信号:`hit_dealt(amount,is_crit)`、`player_dodged(idx)`、`enemy_defeated(def)`、`party_wiped`、`enemy_enraged`(同名同义,供层 6 View 平迁)。
   - 文件:`src/core/combat/combat_arena.gd`。
   - **Verify:** `test/core/combat/combat_arena_test.gd` —— **迁 `formula_test`(11)+ `combat_director_test`(5,敌亡/成员倒/团灭/默认队伍由 roster 快照建)+ `tick_driver_test`(2,大帧=10 小帧、余数跨帧)的断言值**,改为驱动 Arena;回血封顶、攻速 cadence 容差(8-12 / 17-23)、软狂暴触发一次 + 放大、`start_battle` 复位狂暴 —— **数值逐条等值**。

### 5e — 掉落接线(新流水线)

5. **敌死掉落:Arena 接 `LootGenerator`+`LootIntake`;`EnemyDef` 加 `item_level`。**
   - `EnemyDef` 新增 `@export var item_level := 1`(additive,旧权重字段不删)。
   - Arena 在 `enemy_defeated` 路径:`LootGenerator.generate(slot, def.item_level, rarity, registry, rng)` → `LootIntake.handle_drop(inst, equipment, player_state, loot_table)`;发 `item_dropped(instance, destination)` 信号(供层 6)。slot/rarity 来源 = 占位规则(留数值专章;本层只验"敌死→产 ItemInstance 并入 PlayerState")。
   - 文件:`src/combat/enemy_def.gd`(仅加一字段)、`src/core/combat/combat_arena.gd`。
   - **Verify:** `test/core/combat/arena_loot_test.gd` —— 注入 registry + seed:敌死 → 产出合法 `ItemInstance`(ilvl=def.item_level)且按 intake 路由进 `PlayerState`(空槽穿 / 白出材料 / 蓝金进包),`item_dropped` 触发。**注:此为加字段,跑一次 `--import` 后旧 `stage_config_test`/旧 director 仍须 45/45 绿(item_level 有默认值)。**

### 5f — 进度状态机

6. **`ProgressionController`(`RefCounted`,per-run;不靠 `_process`,Arena 驱动)。**
   - 承 director FSM:`Mode{PROGRESSING,GRINDING,STAGE_CLEAR_COUNTDOWN,RESTING}`、`QueuedAction{NONE,PUSH,REST}`、游标 `cur_stage/cur_scene(BOSS=3)/max_unlocked_stage`、`begin_run(stages,stage,scene)`、`current_enemy_def()`、`advance_after_kill()`(Boss 永久解锁 + 倒计时 / 普通场景 kill_count 达标进下一 / GRINDING 入队 push|rest 本轮结束执行 / 过场景·通关回满队伍)、`retreat_after_wipe()`(:368-396 四条回退)、`request_push/request_rest`、`process_countdown(dt)`、`revive_party()`。
   - 接线:Arena `enemy_defeated` → `progression.advance_after_kill()` → 取 `current_enemy_def()` 建敌 Entity → `arena.start_battle(...)`;`party_wiped` → `retreat_after_wipe()` → 重建队伍/敌。倒计时由 Arena tick 调 `process_countdown`。`boss_cleared`/`rest_requested` 信号保留。
   - 文件:`src/core/combat/progression_controller.gd`。
   - **Verify:** `test/core/combat/progression_test.gd` + `retreat_test.gd` + `button_countdown_test.gd` —— **迁现有 progression(6)/retreat(6)/button_countdown(5)的断言值**:场景游标 0→1→2→Boss、kill_count 闸、Boss 永久解锁不回退、过场景/通关回满、四条团灭回退落点、GRINDING 阻进、倒计时自动推进、修整取消自动推进、push/rest 本轮结束执行。**逐条等值。**

### 5g — 收口闸

7. **全量回归闸(本批收口)。**
   - **旧锚:** 现有 45 个 `test/combat/*` **仍 45/45 绿且一字未改**(D1;`EnemyDef.item_level` 加字段不破旧测试)。
   - **新套:** `test/core/combat/*` 全绿(entity/skill/ai/arena/arena_loot/progression/retreat/button_countdown)+ 第一批 84 个 `test/core/*` 仍全绿。
   - `godot --headless --check-only` 0 错;`--import` 后 0 orphans。
   - **Verify:** 三条全绿 = 层 5 done;HANDOFF 回写,交第三批 Planner(层 6-8)。

## 4. Out of scope(本批明确不做)

- **层 6**:`AnimationComponent`、`CombatView` 改读新信号(表现层,手动验收)。
- **层 7**:`SaveSystem` 落盘序列化 `PlayerState`(纯逻辑但归第三批)。
- **层 8(Engine Integrator)**:`project.godot` autoload 由 `Combat`→新系统集、**删除 `combat_director.gd`/`party_member.gd`/`loot_stub.gd`、退役旧 45 测试中被取代者(尤其 `loot_test.gd` 旧符号式)、迁/扩 `.tres`**。
- **改 `src/combat/*`(除 `enemy_def.gd` 加 `item_level` 一字段)、改 45 个旧测试、改 `project.godot`**(D1)。
- **真 lane 几何 / 集火-AoE / 接近时长 / 多敌狂暴细化 / 招牌轴-稀有度掉落规则精调**(占位,数值专章)。
- **招募 / 多职业 / 技能树 / Boss 行为扩展**(v2)。

## 5. Risks & Flags / Open questions

- **【Flag·已决,建议追认】F1 新旧战斗并存一批。** 层 5 结束时 `src/combat/`(旧 director,autoload 在跑)与 `src/core/combat/`(新核心,仅测试消费)并存;退役旧码 + 切 autoload = 层 8。若你想层 5 就切 autoload 手动 Play 新战斗 → 需提前引入 Engine Integrator + 删旧码,**不建议**(破纯逻辑自交付 + 让 `Combat` autoload 悬空)。
- **【Flag·待你拍】F2 旧符号式掉落不 1:1 迁移。** `loot_test.gd`(6 例)+ `EnemyDef.weight_*`/`rarity_weight_*` + director `_roll_loot`/`loot_dropped` 测的是**已被层 4 PoE 流水线取代**的旧符号模型。本批**不迁移、不删**(随旧 director 留到层 8 退役)。故"45 全保留"的精确含义 = **本批 45 旧测试原样全绿**;层 8 删 director 时这 6 例随旧码退役(新掉落由 `loot_generator_test`/`loot_intake_test`/`arena_loot_test` 覆盖)。**默认按此推进;若你要保留旧符号掉落语义需明示。**
- **【Flag·占位】F3 软狂暴 = 每场计时(D8)、F4 lane 恒在射程(D7)。** 均守单敌语义、保现有断言;多敌细化留数值专章。
- **【软决策】F5 `Entity` Node2D vs RefCounted(D5)。** 选 Node2D 空壳 + RefCounted 逻辑组件;Implementer 若验出纯逻辑测摩擦可退 Node 并回写。`ProgressionController` 取 `RefCounted`(无 `_process`,Arena 驱动)——若你倾向 Node 请示。
- **【依赖】F6 第三批回归锚转移。** 层 8 删旧 director 后,旧 45 锚随之退役;**新 `test/core/combat/*`(等值迁移)成为唯一安全网** —— 故本批新套必须把公式/进度断言值**逐条照抄不缩水**(REFACTOR-01 §5 公式断言不变)。
- **【风险】F7 大类拆分语义漂移。** director 把"敌死→掉落→推进"挤在 `_advance_after_kill` 一条路径;拆成 Arena(发 `enemy_defeated`)+ Progression(advance)+ 掉落接线三处后,**触发顺序须等价**(掉落与推进都由同一次敌死触发)。新 arena 测试须含一条"敌死同时产掉落 + 推游标"的顺序断言。
