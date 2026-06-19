---
artifact: REFACTOR
feature: 08-team-combat
role: Arch Guard
status: draft
updated: 2026-06-19
inputs: [ARCHITECTURE.md, harness/features/08-team-combat/FEATURE-DESIGN.md, BACKLOG.md, project-context.md, src/core/combat/combat_arena.gd, src/core/combat/progression_controller.gd, src/core/combat/ai_combat_component.gd, src/core/combat/entity.gd, src/core/combat/combat_tuning.gd, src/combat/enemy_def.gd, src/combat/scene_config.gd, src/combat/stage_config.gd]
next: Planner
---

# REFACTOR-04 — 08 团战:一波多敌 + 近/远站位门控

> **判定:装得下,但需要一处契约调整(spawn/advance 粒度由「每杀一只」改「每清一波」)+ 两处加性数据模型扩展 + 点亮一个占位座位。**
> 不是大重构(扩展点 §5「多敌团战」早已声明),但**比"加个字段"重** —— 核心是 Arena↔Progression 的刷怪/推进契约。
> 关键安全性质:**一波 size=1 退化成今日行为完全一致**,故现有平衡/推进/存档不被动到,只有"波>1"才走新路径。

## 1. 触发 / Trigger
08-team-combat(FEATURE-DESIGN draft,用户拍板):战斗从「单怪车轮」升「一波杂兵团」——同屏 2–4 只敌、
**前排近战门控(够得着才打、排队补位=车轮)+ 后排远程隔位(从后排即输出战士)**。战士侧零改动、单体集火,AoE 推后。

## 2. 现状诊断 / Diagnosis(根因,非症状)

GD 与上一棒 HANDOFF 把 08 概括为"加 `EnemyDef` 站位字段 + `SceneConfig` 多敌 + 点亮 `in_range`"。
通读真实代码后,**真正的不兼容比这深一层**,根因有三处、且第①处是结构性的:

**① 〔根因·结构〕Arena↔Progression 的刷怪/推进契约 = "一次只活一只敌,每杀一只立即重刷下一只"。**
- `ProgressionController._spawn_current()`(`progression_controller.gd:68-76`)**硬建单敌**:
  `var es: Array[Entity] = [Entity.from_enemy_def(def)]`;`current_enemy_def()` 只返回**一个** `EnemyDef`。
- 更要命的是耦合:`CombatArena._handle_enemy_defeated()`(`combat_arena.gd:147-153`)在**每一只敌死**时调
  `progression.advance_after_kill()`;而 `advance_after_kill()` 普通路径末尾必调 `_spawn_current()` →
  `start_battle(es)` → **整盘替换 `arena.enemies` 数组**并置 `_battle_restarted=true`(tick 里据此 `return`)。
- ⇒ 当前模型下"杀一只 = 立刻把敌方整盘换成新刷的一只"。**一波多敌里杀掉前排一个,会触发整波重刷**,
  后排远程/未清近战被冲掉 —— 团战"逐个清空一波"的核心语义**无处落脚**。这是根因,光加字段解决不了。

**② 〔加性·数据模型〕`EnemyDef` 无站位、`SceneConfig` 只能表达单敌。**
- `enemy_def.gd` 实际**没有**「站位类别(近/远)」字段(ARCHITECTURE §2.1 早把它写进事实源,但**代码未落** —— 文档/代码漂移)。
- `scene_config.gd` 只有 `enemy: EnemyDef` + `kill_count`,**无法表达"一波由哪些敌、谁前谁后"组成**。

**③ 〔加性·座位未接线〕`AICombatComponent.in_range()` 占位恒真,且 tick 里从未被调用。**
- `ai_combat_component.gd:15` 的 `in_range` 恒返 `true`,但 `combat_arena.tick_combat` 的敌攻击循环
  (`combat_arena.gd:127-139`)**根本没调它** —— 近战门控的判定座位定义了却没接进结算。

> 一句话根因:**当前战斗把"一只敌"和"一场推进单元"画了等号**;团战要把这二者拆开 —— 敌可多只成"波",
> "推进"以**波清空**为粒度,近战能否出手再受**阵型门控**约束。①是契约拆分,②③是在拆开后的加性填充。

## 3. 目标形态 / Target shape(delta vs ARCHITECTURE.md)

### 3a. 数据模型(§2.1 落实漂移 + 扩 SceneConfig)
- **`EnemyDef += 站位类别`**:`@export var position_class: PositionClass`(enum `{MELEE 近战, RANGED 远程}`,
  **默认 MELEE**)。新 `@export` 带默认 → 现有 `.tres` 缺该键时取默认,**向后兼容、无需迁移**(守不变量 1 模板只读)。
  落实 ARCHITECTURE §2.1 早写的"站位类别(近/远)"。
- **`SceneConfig` 单敌 → 一波多敌**:加 `@export var enemy_group: Array[EnemyDef]`(**数组顺序 = 排位序,前→后**;
  每只的近/远由其 `EnemyDef.position_class` 决定)。`kill_count` 语义保留(见 §3c)。
  **向后兼容**:保留旧 `enemy` 字段作 fallback —— 取波时"`enemy_group` 非空则用之,否则包成 `[enemy]`"。
  → 现有 `stage_01/stage_02` 的 `.tres` 不改也照跑(= size-1 波),Planner 决定是否顺手迁移到 `enemy_group`。
- **`Entity` 已有 `lane:int`**:建敌时由 `from_enemy_def` 把 `position_class` + 该敌在波内的**排位 index** 烙到
  Entity 上(`lane` 复用为排位序,或加 `position_class` 镜像字段)。供门控判定读,**不引入坐标**(守 #7)。

### 3b. Arena↔Progression 契约:刷怪/推进粒度 "每杀一只" → "每清一波"(**核心**)
拆开"敌死结算(per-enemy)"与"推进/刷下一波(per-wave-cleared)"两件事:
- **per-enemy(不变频率,只去掉重刷副作用)**:敌死仍 `enemy_defeated.emit` + 掉落 + **计一次击杀计数**。
  但**不再**在每只敌死时触发 `_spawn_current()` 重刷。
- **per-wave-cleared(新粒度)**:`CombatArena` 在一次 tick 内清掉敌人后,以 **`not _has_living(enemies)`** 为
  "波已清空"信号,**此时才**回调 Progression 的"波清空"钩子 → 由它做"推进/刷下一波"(沿用 advance/countdown/团灭那套)。
- `ProgressionController._spawn_current()` 改为**建整波**(把 `current_wave_defs() -> Array[EnemyDef]` 各 `from_enemy_def`),
  且**只在波清空(或团灭回退/推进)时**调用 —— **绝不在波未清空时替换 `arena.enemies`**。
- **新增不变量 #12**(见 §3d)。**退化保证**:波 size=1 时,"清空" = 那一只死 = 今日触发点,行为逐位等价。

### 3c. 近战门控 + 远程隔位:点亮 `in_range`,门控判定归 Arena
- 门控只作用于**敌方攻击循环**(战士单体集火最前敌,玩家侧不需门控)。
- 判定逻辑:遍历敌攻击循环时,某敌**远程 → 恒可出手**(隔位);某敌**近战 → 仅当它在"前 G 名存活近战"内才可出手**,
  其余近战**排队等位**(前排死则下一名补进 = 车轮)。`G` = `CombatTuning.melee_gate_capacity`(**值交 num-smith**)。
- **归属决策(arch 定)**:门控判定**归 `CombatArena` 编排**,不归 `AICombatComponent`。理由:门控是**阵型级**问题
  (需要"谁是前 G 名近战"= 整个 `enemies` 数组 + 排位),而 `enemies` 数组的事实源在 Arena;让组件去判反而要把整盘
  阵型注进单个组件,破坏 §3.1"组件不持全局阵型"的边界。`AICombatComponent` 继续只管**目标选择**(集火最前)。
  → `AICombatComponent.in_range` 占位**退役**(或收窄为纯 helper),门控在 Arena tick 内计算。
- 守 #7:门控 = 数组序 + 近/远标签算出,**无坐标、无移动、无碰撞**。"接近时长/真 lane 几何"仍按 §6 留作未来,不在 08。

### 3d. 不变量增删(§4)
- **新增 #12 — 战斗推进以"波清空"为粒度,刷怪不打断未清空的波**:`enemy_defeated`/掉落/击杀计数仍 per-enemy;
  但"刷下一波 / 推进场景 / 倒计时"只在 `not _has_living(enemies)`(或团灭回退/玩家推进)时触发;
  `_spawn_current` **绝不**在波未清空时替换 `arena.enemies`。守住"一波多敌可逐个被清而非杀一只就整波重刷"。
  (波 size=1 即退化为旧 director 行为,向后等价。)
- **#7 细化(不新增,补一句实现约定)**:团战站位的具体实现 = "前 G 名近战可出手、其余排队 + 远程不受门控",
  纯由数组序 + 近/远标签算得,**仍无真 2D**。
- §2.1 表格 `EnemyDef`/`SceneConfig` 行更新为已落实的具体形态(`position_class` enum / `enemy_group` 数组)。
- §5 扩展点"多敌团战"行标注:**08 落实**,刷怪/推进契约已由 per-enemy 拆为 per-wave(REFACTOR-04)。

## 4. 调整策略 / Strategy(依赖序,strategy-level,无逐行代码)
1. **数据模型先行(加性,可独立测)**:`EnemyDef += position_class`(enum+默认 MELEE);`SceneConfig += enemy_group`
   + 取波 helper(`enemy_group` 非空用之、否则 `[enemy]`)。此步不动战斗逻辑,现有测试应全绿。
2. **建波**:`ProgressionController.current_enemy_def()` → `current_wave_defs() -> Array[EnemyDef]`;
   `_spawn_current()` 建**整波**实体(各 `from_enemy_def`,烙 `position_class` + 排位 index)。
   此步先让"一波多敌能同屏并存",但推进仍按旧粒度(下一步才拆)。
3. **拆刷怪/推进契约(核心,#12)**:把 `_handle_enemy_defeated` 的"重刷"副作用摘掉(只留 emit+掉落+计数);
   在 Arena tick 检测 `not _has_living(enemies)` → 调 Progression 新"波清空"钩子做推进/刷下一波。
   `advance_after_kill` 拆成"计一只击杀(per-enemy)" + "波清空推进(per-wave)"两条路径。
   **回归重点**:确保 size=1 波逐位等价旧行为,现有 progression/arena 测试据此迁移。
4. **点亮门控(§3c)**:Arena 敌攻击循环加门控判定(前 G 近战 + 远程恒真),`G` 取 `CombatTuning.melee_gate_capacity`;
   `AICombatComponent.in_range` 退役/收窄。
5. **配置值与校验**:`CombatTuning += melee_gate_capacity`(默认占位,**真值 num-smith 定**);
   一波规模/近远配比/远程伤害权重等**全走配置**(守 hard-NO 不硬编码),由 num-smith 在 BALANCE-CHANGE 给定。

> 顺序理由:1 纯加性打底 → 2 让多敌存在但不改推进 → 3 才动契约(风险最高、单独一步好回归) → 4 加门控 → 5 填值。
> 每步可独立 gdUnit4 验,契约拆分(步 3)单独成步以便定位回归。

## 5. 影响面与迁移 / Blast radius & migration
**触及文件(逻辑层,真实代码):**
- `src/combat/enemy_def.gd`(+`position_class`)、`src/combat/scene_config.gd`(+`enemy_group`+取波 helper)。
- `src/core/combat/progression_controller.gd`(`current_wave_defs`、`_spawn_current` 建整波、`advance_after_kill` 拆粒度)。**改动最大处。**
- `src/core/combat/combat_arena.gd`(`_handle_enemy_defeated` 去重刷副作用、tick 加波清空检测 + 敌攻击循环门控判定)。
- `src/core/combat/entity.gd`(`from_enemy_def` 烙 `position_class`+排位)、`src/core/combat/combat_tuning.gd`(+`melee_gate_capacity`)。
- `src/core/combat/ai_combat_component.gd`(`in_range` 退役/收窄)。
- **数据资源**:`stage_01/stage_02` 等 `.tres` —— 靠 `enemy` fallback **可不改**;Planner 可选迁移到 `enemy_group` 顺带配近/远。

**测试迁移(主要成本)**:`combat_arena_test` / `progression_controller_test` / `ai_combat_component_test` 中
**断言"每杀一只即 `_spawn_current` 重刷"** 的用例需改为"波清空才推进"。**缓释**:size=1 波 = 旧行为,故多数用例
按"单敌波"语义即等价通过,只有显式断言重刷时机/`in_range` 恒真的少数用例要重写;并**新增**多敌波(逐个清、门控、远程隔位)用例。

**向后兼容**:
- 现有 `.tres`(无 `position_class`/无 `enemy_group`)→ 取默认 MELEE + `[enemy]` 单敌波 → **行为不变**。
- 不碰存档:`EnemyDef`/`SceneConfig` 是只读模板(`.tres`),非 `PlayerState` 存档单元 → **无存档迁移**。
- 不碰持久层/数据层/表现层契约 —— 改动全锁在**单局战斗层**(Arena/Progression/组件)内,守 §3.3 依赖方向。

## 6. 风险与被否选项 / Risks & rejected alternatives
- **风险·契约拆分回归**:步 3 动的是战斗最核心的刷怪/推进耦合,易引入"波清空判定时机"细 bug(如击杀触发 tick `return`
  与波清空检测的先后)。**缓释**:单独成步 + size=1 退化等价 + 全程 gdUnit4 守;Reviewer 重点盯此步。
- **风险·门控容量 G vs 平衡(i4)**:G ≥ 波内近战数时门控形同虚设(全部能打)= 退化单怪手感;G 过小则车轮太慢。
  归 num-smith 定,且整波 DPS/承伤须守 i4 不超线性。**arch 只给座位(`CombatTuning.melee_gate_capacity`),值不定。**
- **被否 A:光加字段、不拆契约**(HANDOFF 初判路线)。否 —— 每杀一只即重刷整波的耦合会让多敌无法逐个清,根因未解。
- **被否 B:门控判定放 `AICombatComponent`(把 enemies 数组注进组件)**。否 —— 破坏 §3.1"组件不持全局阵型"边界;
  阵型事实源在 Arena,门控天然是编排级判定。组件继续只管目标选择。
- **被否 C:一个场景内多"子波"编排(scene 持 `Array[wave]`,逐波刷)**。否(v1)—— 超出 GD 最小切片(一波即一场足矣),
  徒增 progression 状态复杂度;多波编排留作未来(若 Producer 要 boss 团再开)。
- **被否 D:迁移所有 `.tres` 删掉旧 `enemy` 字段**。否(本期)—— fallback shim 成本极低且零破坏;强删迁移是 drive-by,
  与"不顺手重构"相左。留旧字段为 deprecated,未来真要清再单开。

## 7. 交接 Planner / Handoff
让 Planner 据本 REFACTOR 的 §4 五步依赖序,落成 file-level PLAN(注意步 3 契约拆分单独成步、size=1 退化等价是回归基线):
1. `EnemyDef.position_class` + `SceneConfig.enemy_group`/取波 helper(加性,现有测试全绿)。
2. `ProgressionController` 建整波(`current_wave_defs` + `_spawn_current` 多敌)。
3. **拆刷怪/推进契约**:`_handle_enemy_defeated` 去重刷、Arena 波清空检测 → Progression 波清空钩子、`advance_after_kill` 拆 per-enemy/per-wave(守新不变量 #12)。
4. Arena 敌攻击循环门控(前 G 近战 + 远程恒真)、`in_range` 退役;`Entity.from_enemy_def` 烙站位+排位。
5. `CombatTuning.melee_gate_capacity` 座位 + 全部团战值走配置。

**先于 Planner**:`/num-smith 08-team-combat` —— 定一波规模(2–4 上限/是否随场景深度递增)、近/远配比、**门控容量 G**、
远程伤害权重,守 i4。num-smith 出 BALANCE-CHANGE 后,值喂进步 5 的配置;Planner 可与 num-smith 并行起草、落值时合流。

**ARCHITECTURE.md 已回写**:§2.1(EnemyDef/SceneConfig 具体形态)、§4(新增 #12 + #7 细化)、§5(多敌团战标注 08 落实)、§6(门控/lane 债更新)。
