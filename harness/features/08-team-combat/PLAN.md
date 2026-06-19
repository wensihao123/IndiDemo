---
artifact: PLAN
feature: 08-team-combat
role: Planner
status: draft
updated: 2026-06-19
inputs: [FEATURE-DESIGN.md, harness/arch/REFACTOR-04-team-combat.md, harness/balance/BALANCE-CHANGE-03-team-combat.md, ARCHITECTURE.md, BALANCE.md, project-context.md, src/combat/enemy_def.gd, src/combat/scene_config.gd, src/core/combat/progression_controller.gd, src/core/combat/combat_arena.gd, src/core/combat/entity.gd, src/core/combat/combat_tuning.gd, src/core/combat/ai_combat_component.gd]
next: Implementer
---

# PLAN — 08 团战:一波多敌(近战门控 + 远程隔位)

## 1. 目标 / Goal
把战斗从「单怪车轮」升成「**一波多敌**」——同屏 2–4 只敌(前排近战门控 + 后排远程隔位),
战士侧零改动、单体集火;**波 size=1 = 今日行为逐位等价**(回归基线)。

## 2. 思路与关键决策 / Approach & key decisions
全盘照 REFACTOR-04 §4 的五步依赖序 + BALANCE-CHANGE-03 的值,**纯加性扩展 + 一处契约拆分**,
不碰持久/数据/表现层,改动全锁在单局战斗层(Arena/Progression/组件)。

- **决策 A — 数据模型加性扩展,旧 .tres 零迁移。**
  `EnemyDef += position_class`(enum,默认 MELEE)、`SceneConfig += enemy_group: Array[EnemyDef]`(序=排位前→后),
  旧 `enemy` 字段保留作 fallback。
  *为何*:新 `@export` 带默认 + fallback shim → 现有 `stage_01/stage_02.tres` 不改即跑(= size-1 波),守不变量 1(模板只读)、零存档迁移。
  *否掉的替代*:强删旧 `enemy` 字段、迁移所有 .tres(REFACTOR-04 被否 D)—— 是 drive-by 重构,违 hard-NO「不顺手重构」。

- **决策 B — 刷怪/推进契约由「每杀一只」拆成「每清一波」(核心,新不变量 #12)。**
  敌死仍 per-enemy(emit + 掉落 + 计数),但**摘掉每只死即重刷整波的副作用**;
  改由 Arena 在 tick 内检测 `not _has_living(enemies)` 才回调 Progression 推进/刷下一波。
  *为何*:当前 `_handle_enemy_defeated → advance_after_kill → _spawn_current → start_battle` 会**整盘替换 `arena.enemies`**,
  杀掉前排一个就把整波(含未清近战/远程)冲掉,团战「逐个清空一波」语义无处落脚——这是根因,光加字段解决不了。
  *否掉的替代*:光加字段不拆契约(REFACTOR-04 被否 A)——根因未解,多敌无法逐个清。

- **决策 C — 近战门控判定归 `CombatArena` 编排,`AICombatComponent.in_range` 退役。**
  敌攻击循环里:远程恒可出手(隔位);近战仅当在「前 G 名存活近战」内才出手,其余排队补位(车轮)。`G = CombatTuning.melee_gate_capacity`。
  *为何*:门控是**阵型级**判定(需「谁是前 G 名近战」= 整个 enemies 数组 + 排位),事实源在 Arena;塞进单个组件会破坏 §3.1「组件不持全局阵型」边界。
  *否掉的替代*:门控放 `AICombatComponent`、把 enemies 数组注进组件(REFACTOR-04 被否 B)——破坏组件边界。

- **决策 D — 团战所有值走配置,唯一新运行时常量 `melee_gate_capacity = 2`(守 i8 纯加性)。**
  G=2(BALANCE-CHANGE-03 §3a)经 `CombatTuning` 注入(测试可覆值);一波规模/近远配比/远程权重全走 `.tres`(§3b/§3c 表)。
  *为何*:守 hard-NO「数值不硬编码」+ 新不变量 i8「团战威胁纯加性」(严禁任何「敌越多每个越强」的乘性放大)。
  *否掉的替代*:G=1(群压太弱,被否 A)/ G=∞(超线性击穿 EHP,违 i4,被否 B)/ 乘性数量狂暴(硬否 D)。

## 3. 有序步骤 / Ordered steps
> 顺序理由(REFACTOR-04 §4):1 纯加性打底 → 2 让多敌存在但不改推进 → 3 才动契约(风险最高、**单独成步**好回归)→ 4 加门控 → 5 填值。
> 每步 `godot --headless --check-only` + gdUnit4 跑绿再进下一步;改 `class_name`/enum 后先 `godot --headless --import` 刷全局类缓存。

### 步 1 — 数据模型加性扩展(不动战斗逻辑,现有测试应全绿)
- **改 `src/combat/enemy_def.gd`**:加 `enum PositionClass { MELEE, RANGED }` + `@export var position_class: PositionClass = PositionClass.MELEE`。
- **改 `src/combat/scene_config.gd`**:加 `@export var enemy_group: Array[EnemyDef] = []`;加取波 helper(如 `func wave_defs() -> Array[EnemyDef]`:`enemy_group` 非空返回它,否则返回 `[enemy]`;`enemy` 也空则 `[]`)。旧 `enemy` + `kill_count` 保留不动。
- **验证**:`godot --headless --import`(新 enum)→ `--check-only` → 现有 `combat_arena_test`/`progression_controller_test`/`scene_config` 相关 gdUnit4 全绿(纯加性,行为未变);新增小测:`wave_defs()` 在「只设 enemy」「只设 enemy_group」「都空」三态返回正确。

### 步 2 — 建整波(多敌可同屏并存,推进仍按旧粒度)
- **改 `src/core/combat/progression_controller.gd`**:`current_enemy_def() -> EnemyDef` 旁加/改 `current_wave_defs() -> Array[EnemyDef]`(读当前 `SceneConfig.wave_defs()`);`_spawn_current()`(现 `:68-76`)改为对 `current_wave_defs()` 每只 `Entity.from_enemy_def(d)` 建**整波**数组后 `arena.start_battle(es)`。
- **改 `src/core/combat/entity.gd`**:`from_enemy_def(def, rank := 0)` 把 `def.position_class` + 波内排位 `rank` 烙到 Entity(`lane` 复用为排位序 + 加 `position_class` 镜像字段);`_spawn_current` 建波时按数组 index 传 `rank`。**不引入坐标**(守 #7)。
- **验证**:`--check-only` + gdUnit4。新增测:给一个 2 敌 `enemy_group` 的 SceneConfig,`_spawn_current` 后 `arena.enemies.size()==2` 且各自 `position_class`/排位正确。**此步推进仍旧粒度**(下一步才拆),size-1 波行为不变。

### 步 3 — 拆刷怪/推进契约(核心,守新不变量 #12,**单独成步**)
- **改 `src/core/combat/combat_arena.gd`**:`_handle_enemy_defeated()`(现 `:147-153`)**摘掉重刷副作用**——只留 `enemy_defeated.emit(def)` + `_drop_loot(def)` + 击杀计数(per-enemy),**不再**调触发整波重刷的 `advance_after_kill` 重刷路径;在 `tick_combat` 内某只敌死后检测 `not _has_living(enemies)`(需要的话加 `_has_living` helper)→ 仅此时调 Progression 新「波清空」钩子。
- **改 `src/core/combat/progression_controller.gd`**:`advance_after_kill()` 拆两条——「计一只击杀(per-enemy)」+「波清空推进(per-wave)」;后者沿用现有 advance/countdown/团灭回退逻辑,末尾才 `_spawn_current()` 刷下一波。**`_spawn_current` 绝不在波未清空时替换 `arena.enemies`**(#12)。
- **验证**:`--check-only` + gdUnit4。**回归重点**:迁移现有断言「每杀一只即 `_spawn_current` 重刷」的用例为「波清空才推进」;size=1 波须逐位等价旧行为(那一只死=波清空=今日触发点)。新增多敌波测:2 敌波杀前排一个 → `arena.enemies` 仍含后排那只(未被重刷冲掉)、计数+1、未推进;两只都清 → 才推进/刷下一波。

### 步 4 — 点亮近战门控 + 远程隔位(§3c)
- **改 `src/core/combat/combat_arena.gd`**:敌攻击循环(现 `:127-139`)加门控判定——遍历前先算「前 G 名存活近战」集合(`G = tuning.melee_gate_capacity`,按排位序取存活近战前 G 名);循环内:远程恒可出手;近战仅当属于该前 G 集合才出手,否则跳过(排队)。
- **改 `src/core/combat/ai_combat_component.gd`**:`in_range`(`:15` 占位恒真)退役或收窄为纯 helper;组件继续只管目标选择(集火最前)。
- **验证**:`--check-only` + gdUnit4。新增测:3 近战波 + G=2 → 同一 tick 仅前 2 名近战造成伤害、第 3 名 0 伤;前排死后第 3 名补进可出手;远程波不受 G 限制恒出手。覆 `CombatTuning.melee_gate_capacity` 验不同 G。

### 步 5 — 配置值落地 + 校验(全走配置,守 hard-NO)
- **改 `src/core/combat/combat_tuning.gd`**:加 `@export var melee_gate_capacity: int = 2`(BALANCE-CHANGE-03 §3a 的 G)。
- **铺波 .tres(按 BALANCE-CHANGE-03 §3b/§3c 表,落 `assets/data/combat/`)**:
  - 关1 各 SceneConfig 填 `enemy_group`:Scene1 = 2 近战;Scene2 = 2 近战 + 1 远程;Scene3 = 2–3 近战 + 1 远程;Boss 维持 size=1。
  - 新建关1 远程敌 `EnemyDef` .tres(`position_class = RANGED`):`attack ≈ 0.6×同档近战`、`max_hp ≈ 0.6×同档近战`、`attack_speed = 1`(§3c)。如关1 兽人档配「投石哥布林」atk≈2 / hp≈16–18。
- **验证**:`godot --headless --import` →`--check-only`→ gdUnit4 全绿 → **手动 Play 关1**:肉眼确认一波多敌同屏、近战门控(排队补位车轮感)、远程隔位漏血、逐波 `kill_count` 累积推进、Boss 仍单挑。对照 BALANCE-CHANGE-03 §7 playtest 清单①–⑤。

## 4. 不做 / Out of scope
- **战士/玩家 AoE**(F-AOE 推后)——v1 战士单体集火最前,不预埋接口。
- **一个场景内多「子波」编排**(scene 持 `Array[wave]`,REFACTOR-04 被否 C)——v1 一波即一场;多波/boss 团另开功能。
- **真 2D 走位/坐标/碰撞/抛射物**(守 #7)——站位纯由数组序 + 近/远标签算得。
- **UI / juice / 表现层**(占位程序美术验功能即可)——「谁活跃/谁排队/远程隔位」的呈现留全局 UI/juice 统一轮。
- **关2 .tres 铺波**——关2 敌值更高(食人魔 hp85/酋长 atk9),**落地前须回 `/num-smith 08-team-combat` 复算 WAVE_SIZE**(BALANCE-CHANGE-03 §6),不在本期步 5。
- **enrage(债-5)调值**——团战拉长波是其首次实战检验机会,本期仅作 playtest 观察点,不动其常量。

## 5. 风险与 flags / Risks & Flags
- **风险·步 3 契约拆分回归(最高)**:刷怪/推进是战斗最核心耦合,易出「波清空判定时机」细 bug(击杀触发 tick `return` 与波清空检测的先后)。**缓释**:单独成步 + size=1 退化等价基线 + 全程 gdUnit4;Reviewer 重点盯此步。
- **风险·门控 G vs 平衡(i4/i8)**:G≥波内近战数 → 门控形同虚设(退化单怪手感);G 过小 → 车轮太慢。值由 num-smith 定 G=2,整波威胁须守 i4 不超线性 + i8 纯加性(严禁乘性数量放大)。
- **风险·窄条可读性(支柱 1 相容)**:800×250 里 3–4 敌挤不挤得下/「谁排队」看不看得懂,留 UI 轮 + playtest;**若实测挤 → 优先降 WAVE_SIZE 上限到 3,不动 G**(BALANCE-CHANGE-03 §6)。
- **风险·远程无解感**:远程隔位 + 战士够不到(设计内 F-AOE),若 factor 偏高/远程 >1 会从「漏血」变「磨死」。v1 锁单远程 + factor 0.6 + 脆血;playtest 若刺眼 → 先降远程 attack 再降数,**不给战士加 AoE**。
- **🟡 Flag 关2 复算**:关2 .tres 铺波前须回 num-smith(见「不做」)。
- **🟢 Flag 已解除**:F-ARCH(REFACTOR-04 定案)、F-NUM(BALANCE-CHANGE-03 定案 G=2/i8)。
- **🟢 Flag 推后**:F-AOE(玩家 AoE 留技能)、UI/juice 统一轮。
