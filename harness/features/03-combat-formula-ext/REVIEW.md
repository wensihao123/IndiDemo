---
artifact: REVIEW
feature: 03-combat-formula-ext
role: Reviewer
status: draft
updated: 2026-06-18
inputs: [PLAN.md, CHANGES.md, project-context.md, src/combat/combat_director.gd, src/combat/party_member.gd, src/combat/enemy_def.gd, src/combat/combat_view.gd, assets/data/combat/stage_01.tres, stage_02.tres, test/combat/*.gd]
next: Implementer
---

# REVIEW — 扩 02 战斗公式以承载装备维度

## 1. Verdict

**APPROVE WITH NITS**

机制实现忠实 PLAN §3 七步与 D1–D7 决策:cadence 离散命中、暴击/闪避/护甲减伤/每秒回血/软狂暴均正确;02 收口成果(掉落/Boss 解锁/团灭回退/后台 tick/4 格队伍/过场景回满)未被破坏;数值全走 `@export`/Resource,无硬编码,无新插件,无顺手重构。独立重跑:`--check-only` 干净 + gdUnit4 **45/45 全绿**(8 suites)。
两个非阻塞项值得在交付前顺手处理(见 §3),其一是相对 02 的一处轻微行为回归,故未直接 APPROVE。

## 2. Must-fix(blocking)

无。

## 3. Should-fix(non-blocking)

- **`src/combat/combat_view.gd:196-203` — 伤害/MISS 飘字回调不判 `visible`,收起态(后台 tick)仍在建节点,违背本视图自述的"收起时隐藏、模拟照跑"不变量,且是相对 02 的回归。**
  改前:伤害飘字在 `_update_enemy()` 里推,被 `_process` 开头的 `if _combat == null or not visible: return`(:80)挡住——收起时不产生任何飘字节点。
  改后:`_on_hit_dealt` / `_on_player_dodged` 由信号直接驱动 `_spawn_*`,**不再判可见性**。后果:① 窗口收起(挂机主态)时每次命中仍 `Label.new()` + `create_tween()` 再 `queue_free`,纯浪费;② 长时间后台挂起后首帧,`CombatDirector._process` 的累加器会一次补跑多达 ~1000 步(:121),可在单帧内连发大量 `hit_dealt` → 同帧爆建上百个不可见 Label+Tween(一次性突刺)。
  为何要紧:后台持续推进是 MVP 核心系统(project-context §0),游戏绝大多数时间处于收起态;支柱 1"安静的伙伴"也要求收起时零演出开销。
  建议方向:在 `_on_hit_dealt` / `_on_player_dodged` 开头加 `if not visible: return`(与 `_process` 同一道闸);狂暴横幅已由 `_update_progress_and_buttons` 在 `_process` 内驱动、天然受 `visible` 保护,无需改;`_on_enemy_enraged` 只 append 日志字符串(廉价且利于复开时回看),可不动。注:`_on_loot_dropped` 的光柱/金闪同样无条件,但那是 02 既有行为、不在本次改动范围,留给后续单独决定。

- **`src/combat/combat_director.gd:218` — `target.armor / (target.armor + armor_k)` 在 `armor_k == 0 且 armor == 0` 时为 `0/0 = NaN`,会把成员血量算成 NaN。**
  `armor_k` 是 `@export` 默认 50.0,正常不触发;但它是个可在 Inspector 改的配置面 footgun(F1 调参时若有人清零 K)。
  建议方向:取 `var denom := target.armor + armor_k; var reduced := raw if denom <= 0.0 else raw * (1.0 - target.armor / denom)`(或在 `armor_k` 上加注释/约束下限)。低优先,值班式加一道防呆即可。

## 4. Nits(optional)

- `combat_director.gd:227-230` `_enrage_mult()` 为无上限线性增长(占位)。当前靠"狂暴→很快分出胜负"自限,可接受;精确曲线/封顶留 F1,符合 PLAN。仅记录,不需改。
- `combat_view.gd:410-415` 软狂暴同时给了常驻横幅 `_enrage_label` + 触发瞬间一条日志行(CHANGES §4 已声明为有意增强可读性)。与 PLAN"横幅/日志行"表述一致,F7 可读性达标,无异议。
- `combat_view.gd:240` `_spawn_miss_float` 用 `42.0 + member_index*24.0` 复算行 Y,与 `_build_party_bars`(:328)同一魔数两处独立写死。v1 只有 1 格、风险低;若日后填满 4 格可抽成共享常量。不阻塞。

## 5. What I checked but found fine(覆盖说明)

- **Cadence 累加器**:成员/敌人均 `progress += attack_speed*tick_seconds`、`while >= 1.0` 带 `guard < 1000` 上限并 `-= 1.0`,与 02 `_process` 既有防卡死同构;首杀 `break`(:193-196)正确。
- **暴击**:`is_crit = crit_chance > 0 and rng.randf() < crit_chance`,`dmg *= crit_mult`,`hit_dealt.emit(dmg, is_crit)` 语义正确(crit_chance=0 永不暴击)。
- **闪避**:命中后 `continue` 已消耗该次出手(progress 先减),`player_dodged.emit(party.find(target))` 索引正确;dodge_chance=0 走正常减伤。
- **护甲**:`armor==armor_k` 恰减 50%、`armor=0` 全伤,与 D4/单测一致(除 §3 的 0/0 边角)。
- **回血**:`minf(max_hp, current_hp + hp_regen*tick_seconds)` 封顶满血、default 0 为 no-op,先回血后结算与 D4 伪码顺序一致。
- **软狂暴**:`_enemy_fight_time` 累加、过阈 `enraged=true` 且 `enemy_enraged.emit()` 每场仅一次;`start_battle`(:140-145)复位 `_enemy_attack_progress/_enemy_fight_time/enraged` 及全员 `attack_progress` —— D2"运行时态不写回共享 Resource"严格遵守(EnemyDef 只加配置字段 attack_speed)。
- **外层胜负/下游事件不变**:敌死路径仍 `enemy_defeated`→`_roll_loot`→`_advance_after_kill`;团灭仍 `party_wiped`→`_retreat_after_wipe`;progression/countdown/grind 状态机、`_revive_party` 过场景回满全未改(§3.8 回归边界守住)。
- **删除 `_party_total_attack`**:全仓无引用,删除安全;`_front_living_member` 保留并仍被敌方循环使用。
- **构造兼容**:`PartyMember._init` 尾部可选参,三参旧调用(测试 + 任意旧代码)全部有效;`init_default_party` 传全 9 参。
- **约定**:新信号 `hit_dealt`/`player_dodged`/`enemy_enraged` 均过去式,合 project-context §3;文件 snake_case;早返回风格一致。
- **hard-NO**:无新插件;无计划外重构/加功能;全部数值(warrior_*、armor_k、enrage_*、tick_seconds、.tres 怪 attack_speed)走 `@export`/Resource;未对没影系统提前抽象(D5 软狂暴只全局,未给 EnemyDef 加覆盖)。
- **`.tres`**:stage_01/stage_02 共 8 个 EnemyDef 均补 `attack_speed=1.0`,怪血保持(D6);`stage_config_test` 5/5 绿。
- **测试真实性**:未轻信 CHANGES,独立重跑全套 = 45/45、0 fail/0 flaky;`formula_test` 13 例覆盖六维 + 狂暴触发/复位;旧 6 suite 用 `tick_seconds=1.0`(配 default attack_speed=1.0 → 1.0×1.0 无漂移)重绿,守住 Flag-C"禁逐 tick 精确算术"。
- **未覆盖(非代码层,留用户)**:手动 Play(F7)与 Flag-E(stage 1 须在阈值内可通、stage 2 Boss 狂暴墙)属 UI/体感验收,gdUnit4 测不到 —— 这是 CHANGES 已列明的待用户验收项,本审查不替代。
