---
artifact: CONTEXT-FINDINGS
feature: 03-combat-formula-ext
role: Explorer
status: draft
updated: 2026-06-18
inputs: [project-context.md, FEATURE-DESIGN.md, 02-auto-combat-loop/FEATURE-DESIGN.md, src/combat/*.gd, test/combat/*.gd]
next: Planner
---

# CONTEXT-FINDINGS — 扩 02 战斗公式(reopen 既有战斗代码勘探)

> 本文只报"现状是什么"(what IS),不给方案(怎么改 = Planner)。所有签名/数值均逐字摘自现码,行号为引用锚点。
> 目的:让 Planner 在 reopen 02 时对着真实代码与测试规划,尤其是 §4/§5 的回归雷区。

## 1. 相关文件与各自职责

战斗全部在 `src/combat/` 下,7 个文件;测试在 `test/combat/` 下,7 个 gdUnit4 suite。

| 文件 | 类型 | 职责 | 本 feature 是否会动 |
|------|------|------|---------------------|
| `src/combat/combat_director.gd` (363 行) | `extends Node`, `class_name CombatDirector` | 战斗解算核心 + 进度状态机 + 掉落 roll + 固定步长 tick 驱动。注册为 autoload `/root/Combat`。 | **核心改点**(tick_combat 伤害结算) |
| `src/combat/party_member.gd` (21 行) | `extends RefCounted`, `class_name PartyMember` | 运行时成员可变状态(血/攻)。 | **加字段**(攻速/护甲/闪避/暴击/回血) |
| `src/combat/enemy_def.gd` (26 行) | `extends Resource`, `class_name EnemyDef` | 一种怪的数值 + 外观 + 掉落配置(走 .tres)。 | **加字段**(攻速;软狂暴若每怪配置) |
| `src/combat/scene_config.gd` (9 行) | `extends Resource`, `class_name SceneConfig` | 一个普通场景 = 怪 + kill_count。 | 大概率不动 |
| `src/combat/stage_config.gd` (11 行) | `extends Resource`, `class_name StageConfig` | 一关 = 3 普通场景 + 1 Boss。 | 不动 |
| `src/combat/combat_view.gd` (401 行) | `extends Control`, `class_name CombatView` | 纯读出渲染:订阅信号 + 每帧读态画敌/队/进度/掉落 FX + 推进/修整按钮。 | **可能加读出**(见 §5,死因可读 F7) |
| `src/combat/loot_stub.gd` | (未读,名为 stub) | 掉落占位,推测与 04 装备衔接的占位。 | 待 Planner 确认 |
| `assets/data/combat/stage_01.tres` / `stage_02.tres` | Resource 数据 | 两关实际数值配置(走 Resource,不硬编码)。 | **需重调怪血**(DPS 重定后,见 §4) |

## 2. 关键数据结构与签名(逐字摘录)

### PartyMember(`party_member.gd`)— 新战斗维度的落点
```gdscript
var display_name: String
var max_hp: float
var attack: float
var current_hp: float

func _init(p_name := "战士", p_max_hp := 100.0, p_attack := 4.0) -> void:
func is_alive() -> bool:                  # current_hp > 0.0
func take_damage(amount: float) -> void:  # current_hp = maxf(0.0, current_hp - amount)
```
> 仅 3 个数值字段(名/血/攻)。FEATURE-DESIGN §3.8 要加的 attack_speed / armor / dodge_chance / crit_chance / crit_mult / hp_regen **都不存在**。
> ⚠ 构造器是**位置参数** `_init(name, max_hp, attack)`,全测试用 `PartyMember.new("战士", 100.0, 10.0)` 三参调用(见 §4)。

### EnemyDef(`enemy_def.gd`)— Resource,怪与 Boss 共用
```gdscript
@export var display_name: String = "怪物"
@export var max_hp: float = 10.0
@export var attack: float = 1.0
@export var sprite: Texture2D                    # 外观,缺省回退色块
@export_range(0.0,1.0) var drop_chance: float = 0.6
@export var weight_gold/weight_material/weight_equipment: float
@export var rarity_weight_white/blue/gold: float
```
> 同样**只有 attack 一个攻击维度**,无 attack_speed。EnemyDef 是 `Resource` → 加 `@export` 字段后**已有 .tres 会用字段默认值**(向后兼容,不会加载失败),但默认值必须能复现合理行为(见 §5)。

### CombatDirector(`combat_director.gd`)— 解算核心
信号(02 已收口的事件边界,**必须不破坏**):
```gdscript
signal enemy_defeated(enemy: EnemyDef)
signal party_wiped
signal loot_dropped(kind: StringName, rarity: StringName)   # kind∈{gold,material,equipment} rarity∈{white,blue,gold}
signal boss_cleared(stage: int)
signal rest_requested
```
关键 @export 数值(走配置,不硬编码):
```gdscript
@export var warrior_max_hp := 120.0
@export var warrior_attack := 6.0
@export var stage_clear_countdown_sec := 5.0
@export var tick_seconds := 0.1                  # 固定逻辑步长 = 10 tick/秒
```
状态机:`enum Mode { PROGRESSING, GRINDING, STAGE_CLEAR_COUNTDOWN, RESTING }`,`enum QueuedAction { NONE, PUSH, REST }`,`const BOSS_SCENE := 3`,`const PARTY_SLOTS := 4`。

## 3. 战斗当前如何端到端跑(现状)

**伤害结算核心 — `tick_combat()` (129–149 行),这是要扩的那一块:**
```gdscript
func tick_combat() -> void:
    if not has_living_enemy() or not has_living_member():
        return
    _enemy_hp = maxf(0.0, _enemy_hp - _party_total_attack())   # ① 全队总攻击,每 tick 全额打一次
    if _enemy_hp <= 0.0:
        ... enemy_defeated.emit(); _roll_loot(); _advance_after_kill(); return
    var target := _front_living_member()                        # ② 敌人反击最前存活成员
    if target != null:
        target.take_damage(_enemy_def.attack)                   # ③ 平砍 attack,无攻速/无减伤/无闪避
    if not has_living_member():
        party_wiped.emit(); _retreat_after_wipe()
```
```gdscript
func _party_total_attack() -> float:    # 累加所有存活成员的 m.attack
func _front_living_member() -> PartyMember:   # 数组里第一个存活成员
```

**当前数值模型的本质事实(Planner 必读):**
- **没有攻速** —— 每个存活成员**每 tick 都全额出手一次**。即:有效 DPS = `attack ÷ tick_seconds` = `attack × 10`(tick_seconds=0.1)。敌人同理,每 tick 平砍 `attack` 一次 = `attack × 10`/秒。
- **没有减伤/闪避/暴击/回血** —— 伤害是裸 `attack` 直接 `take_damage`。
- 队伍侧已是**数组聚合**(`_party_total_attack` / `_front_living_member`),敌方侧是**单实例**(`_enemy_def` + `_enemy_hp`,非数组)。

**固定步长驱动 — `_process(delta)` (87–98 行):**
```gdscript
_accum += delta
while _accum >= tick_seconds and guard < 1000:   # guard 防卡死,单帧最多 1000 步
    _accum -= tick_seconds
    process_countdown(tick_seconds)
    tick_combat()
```
帧率无关、后台照跑;tick_combat 与 process_countdown 同一节奏。

**回血模型(02 拍板,FEATURE-DESIGN §3.4 要在其之上加"战中每秒回血",不能破坏这个粒度):**
全队满血回复发生在 `_revive_party()` (325–329 行),调用点共 4 处:
- 过场景(清完一个普通场景,238 行)
- 通关 Boss(223 行)
- 团灭回退(`_retreat_after_wipe`,320 行)
- 卡关刷满一轮 kill_count(215 行)
即"场景间/轮间全队回满,场景内无跨场景损耗",战中**逐 tick 回血目前完全不存在**。

**进度状态机 + 团灭回退 + 倒计时**(`_advance_after_kill` / `_retreat_after_wipe` / `process_countdown` / `request_push` / `request_rest`)逻辑独立于伤害公式,**只认"敌人死亡/团灭"两个事件**,不关心伤害怎么算。理论上扩公式不该动它们——但它们的**触发时机依赖击杀/团灭发生在第几 tick**,而测试把时机写死了(见 §4)。

**View 层(`combat_view.gd`)纯读出:**
- 订阅 5 个信号 + 每帧 `_update_enemy/_update_party/_update_progress_and_buttons`。
- 伤害飘字靠**逐帧比较敌人血量差** `_last_enemy_hp - hp` 推出(108–110 行),**不需要新信号**——只要伤害仍体现在 `_enemy_hp` 下降上,飘字自动还能用。
- View **完全没有**攻速/暴击/闪避/减伤/回血的概念(无"Miss"、无暴击强调、无回血读出)。

## 4. 约束与雷区(reopen 02 的核心风险)

### ⚠ 雷区 A:几乎整套战斗测试把"每 tick 全额出手一次"的算术写死了
FEATURE-DESIGN §3.1 的离散命中 cadence(`progress += attack_speed × tick_seconds`,满 1.0 才出手)一旦落地,**默认每 tick 出手**的前提就变了,下列断言会成片失败。逐条点名(供 Planner 排"重跑 + 改断言"工作量):

**`combat_director_test.gd`(纯解算,时序最敏感):**
- `test_enemy_defeated_after_enough_ticks`:战士 atk10、怪 hp25,`for i in 10: tick` 后断言**恰被击败 1 次**。现模型 10 tick = 100 伤害必杀;cadence 下若攻速使出手变稀,10 tick 可能打不死 → **断言失败**。
- `test_member_down_but_party_continues_when_one_alive`:脆皮 hp5、敌 atk10,`for i in 3: tick` 后断言**脆皮已倒、坦克仍在**。依赖"敌人每 tick 平砍" → cadence 下 3 tick 内可能还没出手 → 失败。
- `test_party_wiped_when_all_down`:战士 hp12、敌 atk6,`for i in 10: tick` 断言**团灭恰 1 次、敌未被击败**。同样依赖每 tick 出手。
- `test_init_default_party_fills_only_slot_0`:**不涉时序**,安全。

**`tick_driver_test.gd`(帧率无关性,核心不变量必须守住):**
- `test_same_sim_time_yields_same_tick_count_...`:1 血怪、战士 atk100,断言 1.0s(=10 步)产 **10 次击杀**;`test_accumulator_carries_remainder_across_frames` 断言 0.1s 后**恰 1 杀**。这两条本意是验"固定步长帧率无关"(必须继续成立),但**击杀次数 10/1 依赖"每 tick 1 杀"**。cadence 下需要么调攻速使其仍每 tick 杀、么改断言数字。**注意:帧率无关这个不变量本身不能丢。**

**`progression_test.gd`(进度推进,多处假设"1 击/tick 必杀 1 血怪"):**
- `test_cursor_advances_through_scenes_to_boss` / `test_kill_count_gates_scene_advance` / `test_boss_kill_unlocks_next_stage_permanently` / `test_never_refights_cleared_boss`:都靠"`tick_combat()` 一下 = 杀一个 1 血怪推进一格"。cadence 下一 tick 可能不出手 → 游标不动 → 失败。
- `test_party_heals_full_after_clearing_a_scene`:**写死血量算术** `is_equal(90.0)` / `is_equal(100.0)`(战士 atk100 两 tick 杀 150 血怪、中间挨一击 100→90)。攻速 + 减伤 + 回血任一落地都会改这串数 → 失败。

**`retreat_test.gd`(团灭回退):**
- 多个用例用脆皮(atk1)对 1000 血怪,`d.tick_combat()` **一下就团灭**(敌 atk100 一击秒脆皮)。cadence 下敌人第一 tick 可能不出手 → 不团灭 → 回退分支不触发 → 全组失败。
- `test_grind_round_heals_party_so_hp_does_not_erode`:**逐 tick 写死血量** `90/90/80/100`(用户报过的 bug 的回归网)。攻速/减伤/回血落地必改 → 失败,且**这是个真 bug 的回归保护,改断言时要保住它验的语义(刷一轮回满、血不越刷越低)**。

**`button_countdown_test.gd`(倒计时/推进/修整):**
- 强战士"每 tick 杀 1 血怪"推进到倒计时;脆皮制造 GRINDING。同样依赖每 tick 出手 → 时序断言会偏。

**`loot_test.gd`(掉落,200~1000 次循环):**
- 全部用 `d.start_battle(_enemy(...)); d.tick_combat()` 当作**一次击杀**(1 血怪一 tick 必杀)。cadence 下"一 tick 未必杀" → 击杀次数 / 掉落次数全错,`is_between(420,580)` 等区间断言失败。

**`stage_config_test.gd`(.tres 加载结构):**
- 只验结构与相对大小(`scenes.size()==3`、`max_hp` 递增、`attack > 0`、掉落权重和 > 0)。**不涉时序,基本安全**;但若给 EnemyDef 加 `attack_speed @export` 且想验证它,需在此补断言。重调怪血(见雷区 B)只要保持相对大小关系(递增、关2 比关1 硬)就不破这些断言。

> **量级提示给 Planner:** 7 个 suite 里 6 个含时序敏感断言,**只有 stage_config_test 基本免疫**。这正是 FEATURE-DESIGN F4 说的"时序敏感断言需更新"——工作量不小,要单列。

### ⚠ 雷区 B:DPS 重定 → stage_01/02.tres 怪血要等比重调
现怪血是按"attack×10/秒"的旧 DPS 配平的。FEATURE-DESIGN §3.1 说 cadence 会 rebase DPS(§6 给的占位:战士 attack≈6、攻速≈1.0/s → 新 DPS≈6/秒,**比旧的 60/秒 低一个量级**)。`.tres` 怪血若不等比下调,击杀时间会暴涨、卡关时序全变。FEATURE-DESIGN §6 已点名"02 怪血需等比重定"。

### ⚠ 雷区 C:`take_damage` 是唯一的"受伤口子",但它不认减伤/闪避/暴击
现 `target.take_damage(_enemy_def.attack)` 与 `_enemy_hp -= _party_total_attack()` 是仅有的两个伤害施加点。新的减伤/闪避(受击侧)、暴击(出手侧)都得在这两处之前/之间插入计算。`take_damage(amount)` 自身只做 `current_hp -= amount`,不含任何减免——减免逻辑要放在调用方还是塞进 take_damage,是 Planner 的设计点。

### 约束(来自 project-context §4 hard-NO,勘探确认现码遵守)
- 数值全走 `@export` / Resource,**逻辑里不硬编码**(warrior_*/tick_seconds 均 @export;怪走 .tres)。新维度必须延续这一点。
- 不引插件;不顺手重构无关代码;不做超范围抽象。
- gdUnit4 运行**不带 `-d`**;校验链 = `godot --headless --check-only`(exit 0)→ gdUnit4 全绿 → 人工 Play(project-context §3)。

## 5. 给 Planner 的 flags

1. **测试改写是本 feature 最大单项成本**,不是顺带。建议把"重跑 02 全套 + 逐条修时序断言"作为独立计划步骤,并明确**每个 cadence 默认值的选择会直接决定多少断言能不改**——例如若新攻速默认能让"每 tick 仍出手一次",大批 `progression/loot/tick_driver` 用例可少改;但这属设计取舍,Planner 定。(对照 §4 雷区 A 的点名清单。)

2. **EnemyDef/PartyMember 加字段的"默认值"要谨慎**:EnemyDef 是 Resource,已有 .tres 加载时吃字段默认值;PartyMember 构造器是位置参数 `_init(name, max_hp, attack)`,全测试三参调用——**新字段要么给默认值、要么改构造器签名**(改签名会波及所有 `PartyMember.new(...)` 调用点:7 个测试 + `init_default_party` 105 行)。Planner 定加字段方式。

3. **`.tres` 怪血重调要与 cadence 数值一起定**(雷区 B),否则击杀/卡关时序失真。FEATURE-DESIGN §6 把精确数值留给"数值设计专章(F1)",但要跑通测试至少得有一套占位值——Planner 需安排"占位数值 + 等比重调怪血"作为一个步骤。

4. **软狂暴(FEATURE-DESIGN §3.5)需要一个"每个敌人的战斗计时器"**,现码里没有任何 per-fight 计时状态(`start_battle` 只刷血,不记开战时刻)。这是个新增运行时状态,且 F5 未决:阈值/曲线放 EnemyDef(每怪)还是全局 @export(倾向全局默认 + 每怪可覆盖)——Planner 拍。它落点应在 `tick_combat` 出手伤害结算里(敌方输出随计时上调)。

5. **死因可读(F7,验收点而非可选)**:View(`combat_view.gd`)目前无闪避"Miss"/暴击强调/减伤/回血的任何读出。闪避(全有全无)+ 软狂暴若没有视觉提示,玩家会看不懂"为什么突然打得动/打不动"。Planner 需把"View 增读出钩子"排进计划(可能联动 Art Spec)。注意 View 伤害飘字靠**逐帧血量差**推出、不靠信号——闪避(伤害=0)那一下不会触发飘字,需要另想读出方式(可能需要新信号或新读出字段,这是设计点)。

6. **敌方仍是单实例**(`_enemy_def`+`_enemy_hp`,非数组)。本 feature 只扩公式、**不引多敌同屏**(车轮战→团战是 Later 独立项,BACKLOG)。攻速/暴击等都施加在"全队 vs 单敌"上即可,**不要顺手把敌方改成数组**(守 FEATURE-DESIGN §3.8 侵入边界 + hard-NO)。

7. **autoload 接线**:CombatDirector 注册为 `/root/Combat`,View 在 `_ready` 里 `get_node_or_null("/root/Combat")` 并 `begin_run(stages)`。加 @export 字段后,若想在编辑器里调参,需经 Engine Integrator 在 autoload 场景/Inspector 上接线(FEATURE-DESIGN F4 提到的"若动 Resource 字段则需 EI")。
