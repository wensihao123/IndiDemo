---
artifact: CHANGES
feature: 08-team-combat
role: Implementer
status: draft
updated: 2026-06-20
inputs: [PLAN.md, harness/arch/REFACTOR-04-team-combat.md, harness/balance/BALANCE-CHANGE-03-team-combat.md, harness/balance/BALANCE-CHANGE-05-stage2-team-combat.md, src/combat/enemy_def.gd, src/combat/scene_config.gd, src/core/combat/entity.gd, src/core/combat/progression_controller.gd, src/core/combat/combat_arena.gd, src/core/combat/combat_tuning.gd, src/core/combat/ai_combat_component.gd, src/combat/combat_view.gd, assets/data/combat/stage_01.tres, assets/data/combat/stage_02.tres, test/combat/stage_config_test.gd]
next: Reviewer
---

# CHANGES — 08 团战:一波多敌(近战门控 + 远程隔位)

## 1. 概要 / Summary
把战斗从「单怪车轮」升成「**一波多敌**」:同屏 2–4 敌(前排近战门控 + 后排远程隔位),战士侧零改动、单体集火。
全盘照 PLAN 五步依赖序实现——**纯加性数据扩展 + 一处契约拆分**(刷怪/推进 per-enemy→per-wave,新不变量 #12),
改动全锁在单局战斗层(Arena / Progression / 组件 / 调参 / 关1 .tres),**不碰持久/数据/表现层逻辑**。
**波 size=1 退化逐位等价旧行为** = 回归基线,144/144 test/core 全绿。

## 2. 分步改动 / Changes by step

### 步 1 — 数据模型加性扩展
- `src/combat/enemy_def.gd`:加 `enum PositionClass { MELEE, RANGED }` + `@export var position_class := MELEE`(默认近战 → 旧 .tres 缺键即近战,向后兼容)。
- `src/combat/scene_config.gd`:加 `@export var enemy_group: Array[EnemyDef]`(序=排位前→后)+ `wave_defs()` 取波 helper(`enemy_group` 非空用之,否则回退单敌 `[enemy]`,都空 `[]`)。旧 `enemy`/`kill_count` 原样保留。

### 步 2 — 建整波
- `src/core/combat/entity.gd`:加 `var position_class`(镜像)+ `lane`(波内排位序);`from_enemy_def(def, rank := 0)` 把 `def.position_class` + 排位 `rank` 烙到 Entity。**不引入坐标**(守 #7)。
- `src/core/combat/progression_controller.gd`:加 `current_wave_defs() -> Array[EnemyDef]`(读当前 `SceneConfig.wave_defs()`,Boss 场景=`[boss]`);`current_enemy_def()` 改为返回 `current_wave_defs()[0]`(波首,View/旧测兼容);`_spawn_current()` 改为对整波每只 `Entity.from_enemy_def(d, i)` 建数组后 `arena.start_battle(es)`。

### 步 3 — 拆刷怪/推进契约(核心,新不变量 #12)
- `src/core/combat/progression_controller.gd`:`advance_after_kill()` 拆成两条——
  `register_kill()`(per-enemy:仅累加 `_kills_this_scene`,GRINDING 有入队动作时不计)+
  `advance_after_wave()`(per-wave:沿用旧 GRINDING/Boss 解锁倒计时/普通场景推进逻辑,末尾 `_spawn_current()`)。
- `src/core/combat/combat_arena.gd`:`_handle_enemy_defeated()` 摘掉重刷副作用——只 `emit + _drop_loot + register_kill`;
  在 `tick_combat` 玩家攻击循环后检测 `not _has_living(enemies)` → 仅此时(且未被信号处理器重开战)调 `progression.advance_after_wave()`。
  **`_spawn_current` 绝不在波未清空时替换 `arena.enemies`**(#12)。size=1 波:那一只死=波清空=今日触发点,逐位等价。

### 步 4 — 近战门控 + 远程隔位
- `src/core/combat/combat_arena.gd`:加 `_front_melee_attackers()`(按排位序取前 `tuning.melee_gate_capacity` 名**存活近战**);
  敌攻击循环加判定:**远程恒可出手**(隔位),**近战仅当属于前 G 集合才出手**,否则跳过(不蓄力 → 排队补位车轮)。
- `src/core/combat/ai_combat_component.gd`:`in_range` 占位**退役**(门控是阵型级判定,已上移 Arena);组件只留 `select_target`(集火最前)。

### 步 5 — 配置值落地
- `src/core/combat/combat_tuning.gd`:加 `var melee_gate_capacity := 2`(G,BALANCE-CHANGE-03 §3a;测试可覆值)。
  **注**:`CombatTuning extends RefCounted`(非 Resource),沿用其既有 plain-`var` 注入风格(`@export` 在 RefCounted 上无效,故用 `var`)。
- `assets/data/combat/stage_01.tres`:各普通场景填 `enemy_group` 铺波(§3b/§3c)+ 新建 2 个远程 `EnemyDef`(`position_class=1`,`attack/hp≈0.6×同档近战`):
  - Scene1 = 2 哥布林(纯近战入门)
  - Scene2 = 2 野狼 + 1 投石哥布林(atk1/hp11)
  - Scene3 = 3 兽人 + 1 投石兽人(atk2/hp16)
  - Boss = 哥布林王 size-1(单挑不变)
  关2(`stage_02.tres`)**未动**(敌值更高,落地前须回 num-smith 复算 WAVE_SIZE,见「不做」)→ 仍 size-1 单近战波,行为与今日等价。

### 补遗 — 最小占位多敌渲染(用户拍板 2026-06-19,见 §3)
- playtest 反馈「每轮还是 1v1」:解算是多敌、但 View 只画波首一只 → 功能不可见。用户拍板「补最小占位渲染」。
- `src/combat/combat_view.gd`:加 4 槽对象池 + `_render_slot`/`_hide_slot`,逐只横排渲染整波(前排靠左、死敌染灰、远程染蓝)。**纯表现层、不碰解算**,144/144 不受影响。详见 §3。

### 补遗 2 — Reviewer should-fix 清尾(2026-06-20,REVIEW §3 之 ②③;纯注释,无逻辑改动)
- **②** `progression_controller.gd:current_enemy_def()` 更新 doc 注释:点明 08 后生产侧已无调用方(View 改直读 `Entity.source_enemy_def`),仅留作 progression 测的 boss-scene 锚 —— **保留不删**(守回归点)。同步更正 Wiring Contract §3「View 调 current_enemy_def」失准句。
- **③** `combat_view.gd:MAX_WAVE_SLOTS` 加防呆注释:本值=同屏可渲染敌数上限,与 BALANCE WAVE_SIZE 上限耦合;关2 复算若 WAVE_SIZE>4 须同步抬,否则尾部敌人静默漏画。
- REVIEW §3 之 **①**(ARCHITECTURE-GUIDE 仍写旧 `advance_after_kill`)= Arch Guard 拥有的事实源,**不在 Implementer 职责内**,回 `/arch-guard` 同步。
- 验证:两文件 `--check-only` 过 + `test/core` **144/144 / exit 0**(纯注释,行为零变)。

### 补遗 3 — 关2 `stage_02.tres` 铺波(2026-06-20,落 BALANCE-CHANGE-05;纯数据,无代码改动)
承「不做」里的关2 复算 flag——num-smith 复算已出(`balance/BALANCE-CHANGE-05-stage2-team-combat.md`),本期照其 §3+§4 落 `stage_02.tres`:
- **新建 2 个远程 `EnemyDef` sub_resource**(`position_class=1`,`attack/hp≈0.6×同档近战`):
  - `RangedSlingerS2`(投石暗影手)hp40/atk4/ilvl18(配 Scene2,基准暗影狼)。
  - `RangedSlingerS3`(投石食人魔)hp50/atk4/ilvl24(配 Scene3,基准食人魔)。
  - sprite 本期沿用同场景近战占位贴图(专属远程美术留 UI/juice 轮)。
- **三普通场景改 `enemy_group`**(WAVE_SIZE 统一 3,序=排位前→后;**保留旧 `enemy` 单敌 fallback** 不删):
  - Scene1 = `[精英兽人 ×3]`(纯近战,团战入门)。
  - Scene2 = `[暗影狼, 暗影狼, RangedSlingerS2]`(2 近+1 远)。
  - Scene3 = `[食人魔, 食人魔, RangedSlingerS3]`(2 近+1 远)。
- **`kill_count` 7→6**(三普通场景;与「波间不回血」约束配套 = 每场 2 满波累积,BALANCE-CHANGE-05 §2 约束 B)。
- **Boss(`BossOrcChieftain` hp480/atk24)一字不动**(墙,BALANCE-CHANGE-04)。
- **关2 普通近战(精英兽人/暗影狼/食人魔)数值全不动**——只把单敌包成波。
- **偏离记录**:BALANCE-CHANGE-05 §6 把 Scene3 从其触发预览的 4 敌收到 3 敌(波间累积承伤实算 4 会团灭 P1-基线);我照 BALANCE-CHANGE-05 落值 = Scene3 三敌,**非预览的四敌**。WAVE_SIZE≤4 → `MAX_WAVE_SLOTS=4` 无需抬(补遗 2 之③防呆点未触发)。
- **新增锁值测** `test/combat/stage_config_test.gd::test_stage_02_scenes_are_team_waves`:关2 三场景 `wave_defs().size()==3` 且 `kill_count==6`,Scene1 末位 MELEE / Scene2-3 末位 RANGED(防静默回退单敌或漏远程)。
- 验证:`--check-only` EXIT=0;`stage_config_test` 7/7 绿(含新测);全量 gdUnit4 **153/153 / 0 fail / exit 0**(report_39)。
- **接线无变化**:`stage_02.tres` 已在 `CombatView.stages`,改的是其内部 sub_resource;走 §3 既有取波/渲染/门控链路,无新接线。

## 3. Wiring Contract(接线契约)

### 新增/变更的公开接口
- `EnemyDef.position_class: PositionClass`(enum MELEE=0 / RANGED=1,默认 MELEE)。**.tres 配置位**。
- `SceneConfig.enemy_group: Array[EnemyDef]` + `SceneConfig.wave_defs() -> Array[EnemyDef]`。**.tres 配置位 + 取波入口**。
- `Entity.position_class` / `Entity.lane`(波内排位序);`Entity.from_enemy_def(def, rank := 0)`(新增 `rank` 形参,默认 0 → 旧调用零改)。
- `ProgressionController.current_wave_defs() -> Array[EnemyDef]`(新);`current_enemy_def()`(语义不变=波首;**08 后生产侧已无调用方** —— View 改直读 `arena.enemies`/`Entity.source_enemy_def`,本函数仅留作 progression 测的 boss-scene 锚,保留不删以守回归点)。
- `ProgressionController.register_kill()` + `advance_after_wave()`(**替换** `advance_after_kill()`)。
  → **唯一调用方 = `CombatArena`**(`_handle_enemy_defeated` 调 `register_kill`;`tick_combat` 波清空调 `advance_after_wave`)。无表现层直接调旧 `advance_after_kill`,**无外部接线需改**。
- `CombatTuning.melee_gate_capacity: int = 2`(注入旋钮)。
- `CombatArena._front_melee_attackers()`(内部 helper,门控判定)。

### 退役
- `AICombatComponent.in_range()` **已删**。grep 全仓:唯一调用方是其自身占位测试(已删该测)。无生产代码引用。

### 表现层(combat_view.gd)—— 已补最小占位多敌渲染(用户拍板 2026-06-19)
- 原状:View 只画波首一只(`_living_enemy()` + `current_enemy_def()`)→ 玩家看到「每轮 1v1」,功能不可见。
- **本期已补占位渲染**:`combat_view.gd` 加 4 槽对象池(`_slot_sprite/_slot_panel/_slot_hp_bg/_slot_hp_bar`,`MAX_WAVE_SLOTS=4`),
  `_update_enemy()` 改为遍历 `_arena.enemies` 逐槽渲染 + `_render_slot(i, ent, n)` / `_hide_slot(i)`:
  - **N==1** 维持单敌大图居中(Boss/单挑观感不变 = 回归基线)。
  - **N>1** 横排缩小铺开,按 `lane` 序前排(近战)靠左、后排靠右;每只独立血条。
  - 死敌不立即消失、染灰保留到波重刷(让玩家看见「门控排队补位 = 车轮」);远程占位染蓝(`SLOT_RANGED_COLOR`)一眼区分近/远。
  - 无贴图时回退 ColorRect 色块(近战红 / 远程蓝 / 死灰)。
- **纯表现层加性改动**,不碰战斗解算(headless 全测覆盖、144/144 不受影响);所有布局常量集中在文件头,无硬编码散落。
  **接线无破坏**:View 现**直读 `_arena.enemies` + `Entity.source_enemy_def`**(逐只取名/贴图/血量),不再调 `current_enemy_def()`;所读字段签名均未变。
- **仍待人工 Play 验视觉**:headless 不验手感/可读性 → 800×250 窄条里 4 只挤不挤得下、近/远色辨识度需在 Godot Play 关1 确认。

### 注入点(运行时,既有不变)
- `CombatArena.progression`(begin_run 时回写)、`CombatArena.tuning`(持 `melee_gate_capacity`)、
  `registry/player_state/loot_equipment`(掉落接线,本期未动)。

## 4. 测试 / Tests(全 headless,gdUnit4)
- **新增** `test/core/combat/progression_test.gd::test_multi_enemy_wave_clears_one_by_one_without_respawn`:2 敌波杀前排一只 → 后排仍活、`arena.enemies` 未被整波重刷冲掉、未推进;两只都清才重刷(证 #12)。
- **新增** `test/core/combat/combat_arena_test.gd` 4 例:门控容量截断(G=2 仅前 2 近战出伤)、前排死后第 3 名补位出手、远程不受门控恒出手、`melee_gate_capacity` 覆值(G=3 三近战全出手)。
- **删除** `test/core/combat/ai_combat_test.gd::test_in_range_is_placeholder_true`(`in_range` 退役)。
- **回归**:`test/core` **144 cases / 0 fail / exit 0**;combat 子集 62/62。size=1 波逐位等价旧行为(140 基线全保持)。
- 验证命令:`godot --headless --import` → `--check-only --script <f>` → `-s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a test/core`。
- `stage_01.tres` load-check:Scene0 size2(2近战)/ Scene1 size3(2近战+1远程)/ Scene2 size4(3近战+1远程)/ Boss size1,值与 §3b/§3c 表一致。

## 5. 不做 / Out of scope(承 PLAN §4)
- 战士/玩家 AoE(F-AOE 推后)；场景内多子波编排；真 2D 走位/坐标/碰撞/抛射物(守 #7)；UI/juice/表现层多敌渲染(统一轮)。
- **关2 `stage_02.tres` 铺波**——敌值更高,落地前须回 `/num-smith 08-team-combat` 复算 WAVE_SIZE;本期 `stage_02` 保持 size-1 单近战波(等价旧行为)。
- enrage(债-5)调值——团战拉长波是其首次实战检验机会,仅作 playtest 观察点,未动常量。

## 6. 风险与 flags / Risks & Flags
- **🟡 待人工 playtest(关1)**:headless 无法验"手感/可读性"。需人在 Godot 编辑器 Play 关1,对照 BALANCE-CHANGE-03 §7 清单
  ①单波承伤 ≲20–25% EHP(可生还有压)②G=2 车轮补位感成立 ③单远程是"烦"非"无解"④enrage 未在拖长波里意外触发(债-5 首检)。
- **🟢 呈现缺口(已补最小占位渲染,见 §3)**:多敌波现逐只横排渲染(前排靠左/死敌染灰/远程染蓝),功能可见。**仍待 Play 验视觉**(窄条密度/色辨识);精修皮/动效随 UI/juice 统一轮。
- **🟡 Flag 关2 复算**:关2 .tres 铺波前回 num-smith(见「不做」)。
- **🟢 已解除**:F-ARCH(REFACTOR-04)、F-NUM(BALANCE-CHANGE-03 G=2/i8)。**🟢 推后**:F-AOE、UI/juice。
