---
artifact: REVIEW
feature: 00-foundation-redesign
role: Reviewer
status: draft
updated: 2026-06-19
inputs: [PLAN-batch2.md, CHANGES-batch2.md, src/core/combat/*, test/core/combat/*, test/combat/*（迁移源基线）, project-context.md]
next: Planner（开第三批 PLAN）
---
# REVIEW — REFACTOR-01 第二批 / 层 5 战斗层重构（Combat Core）

> 审查对象:把 438 行 `CombatDirector` 重构成 `src/core/combat/` 6 组件类 + 56 新 `test/core/combat/*`。
> 审查基调:对抗性新眼;**读真实代码优先于 CHANGES**;独立重跑测试;逐条核对迁移等值。

## 1. 结论 / Verdict

**APPROVE WITH NITS** — 0 must-fix。

层 5 的并存式重构干净达标:6 个组件类 1:1 落在 ARCHITECTURE §3 既定边界,无越界抽象;6 维战斗公式 /
4 条团灭回退 / 倒计时-修整 / 游标推进的断言值逐条照搬迁移源、独立重跑全绿;D1 锚(45 旧测一字未改)守住。
两处预授权偏差(F5 `Entity`→`RefCounted`、`_battle_restarted` 单敌语义)经核**合理且必要**。
留 1 should-fix(4 槽位空位容错有代码、迁移后却无新测覆盖)+ 3 nits,**全不阻塞**第三批。

## 2. 必修 / Must-fix（阻塞合入)

**无。**

## 3. 应修 / Should-fix(建议改,不阻塞)

**S1 — 4 槽位空位容错:代码支持但迁移后零测试覆盖。**
`project-context.md §0` 把"4 人队 = 4 格 slot,v1 只填 1 战士"列为 MVP 结构要求。新 Arena 全程做了空位容错:
`start_battle` 的 `if p != null`(combat_arena.gd:48-53)、`_has_living`(:56-60)、回血循环(:97-101)、
我方进攻循环 `if p == null or not p.is_alive(): continue`(:104-106)。**代码是对的**。但旧 `test/combat/*` 里
进度/回退用例原本以 `[member, null, null, null]` 四元组驱动,迁移到 `test/core/combat/*` 后统一收成单元素
`party: Array[Entity] = [hero]`(见 progression_test.gd:_arena / retreat_test.gd:_arena / button_countdown_test.gd:_arena)。
于是这条 MVP 不变量(4 格里 3 个空位仍能正确跑战斗/回血/团灭)在新套件里**无任何断言守护** —— 将来层 6-8
删旧 director、退役旧 `test/combat/*` 后,这条容错就彻底失去回归网。
建议:在 `combat_arena_test.gd` 或 progression 套补 1 个用例,用 `players = [hero, null, null, null]` 跑一次
击杀推进 + 一次受击团灭,断言空位不致 crash、计数/回退与单元素等价。约 15 行,补网即可。

## 4. 吹毛求疵 / Nits(可选)

- **N1** `ai_combat_component.gd` 的 `in_range(...) -> true` 恒真占位:严格说是"为还没影的走位/距离系统提前留缝",
  踩到 project-context §4 hard-NO 的边。但它是 ARCHITECTURE §3 明列的命名扩展点(AI 选靶/判距分离),且零额外状态、
  零分支,作为 lane 几何到位前的显式 seam 可接受。留记号,层后做 lane 时记得回填真实判距。
- **N2** `combat_arena.gd` 同时持 `_battle_restarted` 布尔与 `if not _has_living(enemies): return` 两道"本 tick 收尾"
  判断,语义有轻微重叠(单敌走前者、留尸走后者)。当前为忠实复刻 director 双路径,**别现在动**;层 6 信号平迁后
  可考虑统一成一处。仅备忘。
- **N3** `_drop_loot` 的 slot/rarity 用 `rng.randi() % size()` 等概率占位(:163-164),注释已标"留数值专章"。
  与 03/04 的 F1 数值占位同源,合并进总数值专章即可,本批不必动。

## 5. 我查过但认为没问题 / Checked & fine

- **独立重跑(全套)**:`140/140` 通过,`22/22` suites,**0 errors / 0 failures / 0 orphans**,exit 0。
  CHANGES-batch2 的 140/140、0 orphans 声明属实。
- **D1 回归锚**:独立重跑 `test/combat/*` = `45/45`、`8/8` suites 全绿 —— 旧战斗码 + 45 旧测确未被触碰,
  `project.godot` 未动,并存式约束守住。
- **6 维公式逐条等值**:对照迁移源 `test/combat/formula_test.gd`,新 `combat_arena_test.gd` 断言值一字不差 ——
  暴击 raw×crit_mult=20.0;护甲 armor==K → `raw×(1-K/2K)`=950.0(denom≤0 跳过防 NaN);回血 +regen×dt=50.5、
  封顶满血=100.0;攻速档期离散命中 8-12 / 17-23 容差区间;软狂暴每场仅触发一次 + `1+ramp×(t-threshold)` 放大;
  `start_battle` 复位 `enraged`。解算顺序 crit→dodge→armor 与 `skill_component.gd:resolve_hit` 一致。
- **4 条团灭回退等值**:对照 `retreat_test.gd` 迁移,核过 ① 场景中段团灭退一场景、② 非首关首场景退到上关末普通
  场景(跳其 Boss)、③ 首关首场景原地刷、④ Boss 团灭退末普通场景且 `advance_target=BOSS_SCENE`;退后 GRINDING
  不推游标;卡关刷一轮满 kill_count → 全队回满(100→90→90→80→100 序列逐 tick 核对)。
- **倒计时 / 修整 / 游标推进等值**:对照 `button_countdown_test.gd` + `progression_test.gd` —— 通关倒计时半程不推进、
  越点自动推进;修整取消自动推进;GRINDING 中 push/rest 入队、本轮结束才执行;游标 0→1→2→BOSS;Boss 击杀永久
  解锁 `max_unlocked_stage` 且绝不回打已清 Boss;过场景/通关满血。
- **F5 偏差(`Entity` 由 PLAN 的 `Node2D` 退为 `RefCounted`)**:合理。headless 测中内部 `Entity.new()` 作 Node2D
  会留 orphan;退 RefCounted 后 0 orphans 实测成立,且 Entity 是纯数据壳(stats/skill/ai 组合),不需场景树。
  PLAN-batch2 D5/F5 已预授权,比建议的 Node 更彻底,**追认通过**。
- **F7 偏差(`_battle_restarted`)**:合理且必要。复刻 director"单敌被杀→触发推进/补刷后即结束本 tick、新生敌不
  反击"语义。核过:补刷置位 `_battle_restarted=true` → 玩家循环内 `return`(combat_arena.gd:119-120);倒计时/修整
  路径留死敌不补刷 → 落到 `if not _has_living(enemies): return`(:123-124),敌不反击。两路径覆盖 director 行为。
- **掉落接线顺序**:`_handle_enemy_defeated`(:147-152)= `enemy_defeated.emit` → `_drop_loot` → `progression.advance_after_kill`,
  与 director 同一次敌死先掉落后推进的顺序一致(F7 等值)。`arena_loot_test.gd` 3 用例守此顺序。
- **接线安全闸**:`_drop_loot` 在 `registry/player_state/loot_equipment` 任一为空时早退(:159-160),保证 5d 纯解算
  可脱离 5e 接线独立测 —— 与 56 新套大多不注掉落依赖的事实自洽。
- **组件边界 / 无越界**:6 类(CombatTuning 调参 / Entity 壳 / SkillComponent 解算 / AICombatComponent 选靶 /
  CombatArena 编排 / ProgressionController 跨场 FSM)正交映射 ARCHITECTURE §3,无 God object 回潮,无计划外重构。
- **信号命名**:`hit_dealt / player_dodged / enemy_defeated / party_wiped / enemy_enraged / item_dropped` 全过去式,
  与既有约定一致,供层 6 View 平迁。
- **安全**:纯逻辑战斗模拟,无 I/O / 网络 / 外部输入;唯一新增 `EnemyDef.item_level` int export 走 Resource 配置,
  未硬编码数值进逻辑(符合 §4 hard-NO)。无注入面。
- **数值不硬编码**:调参集中在 `CombatTuning`(armor_k / enrage_* / countdown / tick_seconds 皆 export),
  战斗逻辑读 tuning 而非字面量,符合 §4。

---
**交接**:第二批层 5 = APPROVE WITH NITS,0 must-fix,可进第三批。S1(4 槽位空位补测)建议在第三批删旧
director **之前**补上,否则该 MVP 不变量在旧 `test/combat/*` 退役后失去回归网。N1(`in_range` 占位)、N3(掉落
占位概率)并入总数值/lane 专章。Planner 开第三批(层 6-8:`CombatView` 改读新信号 / `SaveSystem` 落盘 /
autoload 重注册 + 删旧 director + 退役旧符号掉落测试,经 Engine Integrator);本批 56 新套 = 删 director 的安全网(F6)。
