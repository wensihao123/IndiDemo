---
artifact: CHANGES
feature: 03-combat-formula-ext
role: Implementer
status: draft
updated: 2026-06-18
inputs: [PLAN.md, FEATURE-DESIGN.md, CONTEXT-FINDINGS.md, project-context.md]
next: Reviewer
---

# CHANGES — 扩 02 战斗公式以承载装备维度

> 按 PLAN §3 七步有序实现。Flag-A 取 PLAN 推荐值(诚实默认 `attack_speed=1.0`/秒 + 改写旧测试),
> 用户已授权"按 PLAN 推荐走"。代码改 `src/`;本文件是 harness 内唯一产物。

## 1. What changed(改了什么)

**`src/combat/party_member.gd`**(Step 1)
- 新增 6 个战斗维度字段:`attack_speed`、`armor`、`dodge_chance`、`crit_chance`、`crit_mult`、`hp_regen`。
- 新增单场运行时累加器 `attack_progress`(初值 0,不进构造参数)。
- `_init` 扩为尾部可选参数:`_init(p_name="战士", p_max_hp=100.0, p_attack=4.0, p_attack_speed=1.0, p_armor=0.0, p_dodge_chance=0.0, p_crit_chance=0.0, p_crit_mult=2.0, p_hp_regen=0.0)`。原三参调用全部仍有效(吃默认)。
- `is_alive()` / `take_damage()` 不变。

**`src/combat/enemy_def.gd`**(Step 1)
- 在 `attack` 后新增 `@export var attack_speed: float = 1.0`(纯配置字段;运行时状态不上 Resource,见 D2)。

**`src/combat/combat_director.gd`**(Step 1 + Step 2)
- 新增 3 个 additive 信号:`hit_dealt(amount: float, is_crit: bool)`、`player_dodged(member_index: int)`、`enemy_enraged`。既有 5 信号不动。
- `@export_group("v1 战士")` 新增 `warrior_attack_speed:=1.0` / `warrior_armor:=0.0` / `warrior_dodge_chance`(0–1)`:=0.0` / `warrior_crit_chance`(0–1)`:=0.0` / `warrior_crit_mult:=2.0` / `warrior_hp_regen:=0.0`。
- 新增 `@export_group("公式")` → `armor_k:=50.0`;新增 `@export_group("软狂暴")` → `enrage_threshold_sec:=25.0` / `enrage_ramp_per_sec:=0.5`。
- 新增运行时 var:`_enemy_attack_progress:=0.0`、`_enemy_fight_time:=0.0`、公开 `enraged:=false`。
- `init_default_party` 把 9 个 warrior_* 全传进 `PartyMember.new`。
- `start_battle` 复位 `_enemy_attack_progress` / `_enemy_fight_time` / `enraged` + 所有成员 `attack_progress`。
- **重写 `tick_combat`**(Step 2,按 D4 伪码):缠斗计时 + 过阈值触发狂暴 → 每 tick 回血(封顶满血)→ 队伍按 cadence 逐成员离散命中(暴击翻倍、首杀 break)→ 敌死沿用 02 的 `enemy_defeated`/`_roll_loot`/`_advance_after_kill` 后 return → 否则敌人按 cadence 出手打前排(闪避 → 护甲减伤,伤害乘 `_enrage_mult()`)→ 团灭沿用 `party_wiped`/`_retreat_after_wipe`。
- 新增私有 `_enrage_mult()`(线性占位:`1.0 + ramp*(fight_time - threshold)`)。
- 删除 `_party_total_attack()`(被 cadence 循环取代,无测试引用)。`_front_living_member()` 保留。

**`assets/data/combat/stage_01.tres` / `stage_02.tres`**(Step 5)
- 每个 `EnemyDef` 子资源补 `attack_speed = 1.0`(stage_01:Boss/哥布林/野狼/兽人 共 4 个;stage_02:Boss/精英兽人/暗影狼/食人魔 共 4 个)。怪血保持现值(D6:精确重调留 F1)。

**`src/combat/combat_view.gd`**(Step 6)
- 订阅 `hit_dealt` → 逐命中飘伤害字,暴击放大字号(22)+ 染暴击色 + "暴击" 前缀。
- 订阅 `player_dodged` → 在对应成员血条行飘 "MISS"。
- 订阅 `enemy_enraged` → 日志行 "🔥 敌人狂暴!";另加常驻横幅 `_enrage_label`,每帧读 `_combat.enraged && has_living_enemy()` 控制显隐(`start_battle` 复位 enraged → 自动消失)。
- 移除原"逐帧比较 `_last_enemy_hp` 差值"推伤害飘字的逻辑(及该 var),改由 `hit_dealt` 驱动(Flag-F:单 tick 多命中/暴击/闪避 0 伤害都能正确表达)。

**测试(Step 3 新增 + Step 4 回贴)**
- 新增 `test/combat/formula_test.gd`(13 个确定性单测:暴击翻倍/无暴击、闪避抵消+`player_dodged`、护甲==K 减半/零护甲全伤、回血+0.5/tick、回血封顶、cadence 容差、攻速翻倍、狂暴过阈仅触发一次、狂暴放大伤害、`start_battle` 复位狂暴)。
- 回贴 6 个旧 suite:`combat_director_test` / `progression_test` / `retreat_test` / `button_countdown_test` / `loot_test` 统一设 `tick_seconds = 1.0`(配合默认 `attack_speed=1.0` → `1.0×1.0=1.0` 无浮点漂移 → 每 `tick_combat()` 每 actor 恰一击,还原 02 "每 tick 一击" 语义);`tick_driver_test` 保 `tick_seconds=0.1`(测累加器)但改设 `warrior.attack_speed=15.0`(`15×0.1≥1.0` → 每 tick 必出手)。`stage_config_test` 未动(无战斗,免疫)。

## 2. Why(对应 PLAN 步骤/决策)

| 改动 | PLAN 依据 |
|------|-----------|
| 6 维字段 + `attack_progress` + 可选构造参 | Step 1 / D3(尾部可选参,零破坏三参调用点) |
| 运行时状态进 Director 而非 EnemyDef | D2(EnemyDef 是共享 Resource,写运行时态会串味) |
| `tick_combat` 离散命中重写 | Step 2 / D1(cadence)+ D4(保留外层胜负事件结构) |
| 软狂暴只全局 `@export` | D5(无每怪需求,不提前抽象,守 hard-NO) |
| `.tres` 仅补 `attack_speed=1.0`、不重调怪血 | Step 5 / D6(精确数值归 F1 专章) |
| 3 个 additive 信号 + View 改信号驱动飘字 | D7 / Step 6 / Flag-F(逐帧差值无法表达多命中/暴击/0伤闪避) |
| 旧测试统一 `tick_seconds=1.0` 重绿 | Step 4 / Flag-C(禁脆弱逐 tick 精确算术;1.0×1.0 无漂移) |
| Flag-A 取诚实默认 + 改测试 | PLAN §5 Flag-A 推荐(默认值须语义自洽,04 会大量构造成员) |

## 3. How verified(怎么验的)

- **每步验证门**(project-context §5):
  - Step 1:`--headless --check-only --quit` 退出 0 + 全套旧测试仍绿(加法未破坏 02)。
  - Step 2:check-only 0(编译过);部分旧测试受控转红(时序变了,Step 4 收口)。
  - Step 3:check-only 0 + 13 新单测全绿。
  - Step 4:check-only 0 + 全套(旧+新)45 全绿。
  - Step 5:check-only 0 + `stage_config_test` 5/5 绿。
  - Step 6:check-only 0 + 全套 45 全绿。
- **最终回归(Step 7)**:`--headless --check-only --quit` → `EXIT=0`;`GdUnitCmdTool.gd -a test`(不带 `-d`,WINDOWED)→ **45 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED**,8/8 suites。
- gdUnit4 调用:`godot.exe --path . -s --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a test`(headless 会被 gdUnit4 拒;`tcp://...:0` 的 "remote port" 报错为良性,测试照跑照过)。
- **手动 Play(F7)= 尚未执行,需用户**:UI 不进 gdUnit4(project-context §5)。见下方"待用户验收"。

## 4. Deviations(与 PLAN 的偏差)

- 无算法/结构性偏差。`tick_combat` 外层胜负事件流、progression/retreat/countdown/loot 状态机、后台 tick、4 格队伍、过场景回满全部未动(符合 §3.8 / 回归边界自查)。
- 细节澄清(非偏差):Step 6 的"软狂暴横幅"实现为常驻 `_enrage_label`(每帧读 `enraged`)+ 触发瞬间一条日志行,二者并存——PLAN 写的是"横幅/日志行"二选一表述,这里两者都给以增强可读性(守 F7),克制不弹 OS 通知/不抢焦点。

## 5. Wiring Contract(给 Engine Integrator / 接线)

**改动均为脚本内字段/信号扩展,无新增场景节点、无新 .tscn、无新插件、无新资源文件。** 但有以下接线面变化,Engine Integrator 在 Godot 编辑器里需知:

1. **`EnemyDef` 资源新增导出字段 `attack_speed: float = 1.0`。**
   - stage_01.tres / stage_02.tres 的 8 个 EnemyDef 子资源已在文本里写入 `attack_speed = 1.0`。
   - 若日后在 Inspector 新建 EnemyDef,该字段默认 1.0,无需手填(占位;精确值待 F1)。
2. **`CombatDirector` 新增导出参数**(均有默认,场景里无需改即可跑):
   - `@export_group("v1 战士")`:`warrior_attack_speed`(1.0)、`warrior_armor`(0.0)、`warrior_dodge_chance`(0.0)、`warrior_crit_chance`(0.0)、`warrior_crit_mult`(2.0)、`warrior_hp_regen`(0.0)。
   - `@export_group("公式")`:`armor_k`(50.0)。
   - `@export_group("软狂暴")`:`enrage_threshold_sec`(25.0)、`enrage_ramp_per_sec`(0.5)。
   - **手动验收时**可在 Inspector 临时调 `warrior_crit_chance`→0.3 看暴击飘字、`warrior_dodge_chance`→0.3 看 MISS,验完还原。
3. **`CombatDirector` 新增 3 个信号**:`hit_dealt(amount: float, is_crit: bool)`、`player_dodged(member_index: int)`、`enemy_enraged`。
   - `CombatView`(MainArea 内)已在代码里自动 connect 这三个(`_ready`),无需在编辑器连线。
   - 既有 5 信号(`enemy_defeated`/`party_wiped`/`boss_cleared`/`loot_dropped`/`rest_requested`)接线不变。
4. **`CombatDirector` 新增公开 var `enraged: bool`**:View 每帧读以显示狂暴横幅。无需接线。
5. **无破坏性改动**:`PartyMember.new(name, hp, atk)` 三参调用仍有效;Combat autoload、begin_run 入口、stages 注入方式均不变。

## 6. Flags(实现期回执)

- **Flag-A〔已按推荐落地〕** 默认 `attack_speed=1.0`/秒 + 旧测试用 `tick_seconds=1.0` 重绿。用户授权"按 PLAN 推荐走"。
- **Flag-C〔已守〕** 无任何逐 tick 精确算术断言;cadence 单测用 `is_between` 容差,旧测试用 `1.0×1.0` 无漂移 + 首杀 break。
- **Flag-D〔回血读出〕** 本轮**未**做回血飘字(尽力而为项,非硬要求)。血条会随 `current_hp` 回升柔和反映;如需显式 "+N" 回血飘字可后补,不阻塞验收。
- **Flag-F〔已复验待 Play〕** View 飘字已改 `hit_dealt` 驱动;代码层与单测已绿,**但飘字/暴击放大是 UI 表现,须在手动 Play 复看**。
- **Flag-E〔需用户在 Play 时确认〕** D6 下 stage 2 Boss(220HP)预期会过 25s 阈值触发狂暴推平裸装战士 = 故意的卡关墙(支柱 2),非 bug。算术 sanity:stage 1 Boss 90÷6≈15 命中≈15s < 25s → 第一关应能在阈值内清掉。**请在 Play 中确认 stage 1 全程可通,stage 2 Boss 狂暴墙触发且可读。**

---

## 待用户验收(Step 6/7 手动 Play — F7 硬验收点,UI 不进 gdUnit4)

打开战斗场景按 Play,观察并回报:
1. **cadence**:战士逐次出手,敌人血条阶梯式下降、每命中一个伤害飘字。
2. **暴击**(Inspector 临时 `warrior_crit_chance`=0.3):看到放大+变色的"暴击 -N"飘字。验后还原。
3. **闪避**(Inspector 临时 `warrior_dodge_chance`=0.3):被敌人打时成员行冒 "MISS" 且不掉血。验后还原。
4. **软狂暴**:放任 stage 2 Boss 缠斗过 25s → 日志 "🔥 敌人狂暴!" + 右上常驻 "🔥 敌人狂暴" 横幅 → 战士被推平 → 团灭回退刷怪正常。
5. **02 回归**:击杀→掉落 FX(蓝/金光柱)/进度读出正常、通关 5s 倒计时正常、stage 1→2 流程顺。
6. **Flag-E**:确认 stage 1 全程可在阈值内通关(否则第一关卡死 = 真 bug,回报我)。

回报结果(截图/体感)后即可交 Reviewer(`/role-reviewer 03-combat-formula-ext` 喂本 CHANGES.md)。

---

## 7. 审后修订(2026-06-18,清 REVIEW.md 两个 should-fix)

REVIEW.md 判 **APPROVE WITH NITS**、0 must-fix;顺手清掉两个非阻塞 should-fix:

1. **`src/combat/combat_view.gd` 飘字回调加可见性闸** —— `_on_hit_dealt` / `_on_player_dodged` 开头各加 `if not visible: return`。
   修前:这两个回调由信号无条件驱动 `_spawn_*`,收起态(后台 tick 主态)仍 `Label.new()`+`create_tween()`,且长挂起后首帧累加器一次补跑多步会同帧爆建大量不可见 Label。
   修后:与 `_process` 开头(:80)同一道 `visible` 闸对齐——收起时零飘字开销,守住本视图"收起时隐藏、模拟照跑"不变量 + 支柱 1"安静的伙伴"。狂暴横幅本就在 `_process` 内受 `visible` 保护、`_on_enemy_enraged` 只 append 日志,均不动。
2. **`src/combat/combat_director.gd` 护甲减伤防 0/0** —— 减伤改为 `var denom := target.armor + armor_k; var reduced := raw if denom <= 0.0 else raw * (1.0 - target.armor / denom)`。
   修前:`armor_k==0 且 armor==0` 时 `0/(0+0)=NaN`,会把成员血量算成 NaN。`armor_k` 默认 50,仅 Inspector 调参清零时触发(配置 footgun)。
   修后:`denom<=0` 跳过减伤(取全伤),其余路径数值不变。

**验证**:`--headless --check-only --quit` → `EXIT=0`;gdUnit4 全套独立重跑 → **45 test cases | 0 failures | 0 flaky | 8/8 suites | PASSED**,exit 0(两处改动均不改既有断言路径:可见性闸只影响 UI 节点产生、护甲 denom>0 时算式等价)。
3 个 nit 按 REVIEW 判定不改(均记录在案,无行为影响)。

修订后状态:0 must-fix 已无、2 should-fix 已清 → **代码侧可收口**,仅余用户手动 Play(F7,上方清单)+ Flag-E 确认。

## 8. 验收(2026-06-18)

**用户手动 Play(F7)通过,未发现问题。** F7 硬验收点(cadence 飘字、暴击、闪避 MISS、stage 2 Boss 软狂暴墙、02 回归)+ Flag-E(stage 1 阈值内可通)+ Flag-F(UI 飘字表现)均实机确认。**本功能 done。**
