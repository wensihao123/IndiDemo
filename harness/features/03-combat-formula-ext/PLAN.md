---
artifact: PLAN
feature: 03-combat-formula-ext
role: Planner
status: draft
updated: 2026-06-18
inputs: [project-context.md, FEATURE-DESIGN.md, CONTEXT-FINDINGS.md, src/combat/*.gd, test/combat/*.gd, assets/data/combat/stage_01.tres, stage_02.tres]
next: Implementer
---

# PLAN — 扩 02 战斗公式以承载装备维度

## 1. Goal
受控扩展 02 的 `tick_combat`:把"每 tick 全队 attack 之和扣血"换成**按攻速的离散命中** + 暴击/闪避/护甲/每秒回血 + **软狂暴**,六个新维度作为字段挂在 `PartyMember`/`EnemyDef` 上被战斗消费;**绝不破坏** 02 已收口的掉落事件流/Boss 解锁/团灭回退/后台 tick/4 格队伍/过场景回满(FEATURE-DESIGN §3.8)。本功能不含装备物品(归 04),只保证"字段存在且被正确消费"。

## 2. Approach & key decisions

> 总原则:**先把机制做对并隔离验证(新维度单测),再回贴 02 旧测试,最后才接真实游戏数值**。让"扩展没破坏 02"成为一个可观察的绿色检查点。所有数值均为占位(FEATURE-DESIGN §6/F1),不精调、不设硬上限。

**D1 — cadence 用"每 actor 的出手进度累加器"(离散命中)。**
每 tick:`progress += attack_speed × tick_seconds`;`while progress >= 1.0`(带单 tick guard 上限,照抄 `_process` 现有 `guard < 1000` 模式)打出一次命中并 `progress -= 1.0`。attack_speed 语义 = **每秒出手次数**。
- *为何*:离散命中让"一次命中"成为暴击/(未来吸血)的结算单位(FEATURE-DESIGN §3.1),这是攻速能与它们协同的根因。
- *拒绝的替代*:把 attack_speed 当成"每 tick 伤害乘子"(连续模型)——那样暴击只能按 tick 结算、攻速与暴击无法解耦,丢掉设计要的"出手如雨 + 尖峰"质感。

**D2 — 运行时进度/计时状态绝不写进 `EnemyDef`(它是共享 Resource)。**
`EnemyDef` 是 `Resource`(被 .tres 共享、可能被多处引用),**只加配置字段**(`attack_speed`)。敌人的出手进度、缠斗计时、狂暴态是**单场运行时状态**,与现有 `_enemy_hp`(独立于 `_enemy_def`)一样放进 `CombatDirector` 的运行时 var:`_enemy_attack_progress` / `_enemy_fight_time` / `enraged`,在 `start_battle` 里复位。
- *为何*:往 Resource 写运行时可变状态会被多个引用/缓存共享、甚至污染 .tres,是隐蔽 bug 源。`PartyMember` 是 `RefCounted` 运行时实例,故它的 `attack_progress` 可以放成员上;敌人不行。
- *拒绝的替代*:给 `EnemyDef` 加 `attack_progress` 字段——错,会被共享实例串味。

**D3 — `PartyMember` 加字段用"可选构造参数 + 默认值",不改三参调用点的兼容性。**
`_init(name, max_hp, attack, attack_speed:=1.0, armor:=0.0, dodge_chance:=0.0, crit_chance:=0.0, crit_mult:=2.0, hp_regen:=0.0)`。运行时 `attack_progress` 不进构造参数(初始化为 0)。现有所有 `PartyMember.new(name, hp, atk)` 三参调用保持有效(吃默认值)。
- *为何*:CONTEXT-FINDINGS §5.2 指出 7 个测试 + `init_default_party` 都按位置三参调用;尾部可选参数是最小侵入的加字段方式。
- 默认值取**设计自然单位**(attack_speed=1.0/秒,其余防御/暴击维度 = 无效化的 0,crit_mult=2.0 备用):一个"未指定的成员"= 每秒挥一次、无任何加成。**不**把默认设成"每 tick 出手一次"那种只相对 tick_seconds 才有意义的值(见 §5 Flag-A 的取舍与替代)。

**D4 — `tick_combat` 重写:保留外层结构与胜负事件,只换两处伤害施加。**
外层(存活判定 → 队伍打敌 → 敌死则 emit/掉落/推进 return → 否则敌打前排 → 团灭则 emit/回退)**不变**,下游只认"敌血≤0 / 全员倒"两事件(§3.8)。算法(伪码,顺序是决策,非可选):
```
if not has_living_enemy() or not has_living_member(): return
_enemy_fight_time += tick_seconds
if not enraged and _enemy_fight_time >= enrage_threshold_sec:
    enraged = true; enemy_enraged.emit()
# 每 tick 回血(场内即时,封顶满血;default hp_regen=0 → 无操作)
for m in 存活成员: if m.hp_regen > 0: m.current_hp = min(max_hp, +hp_regen*tick_seconds)
# 队伍进攻:逐成员累计出手,打出离散命中(可多次/tick),首杀即 break
for m in 存活成员:
    m.attack_progress += m.attack_speed * tick_seconds
    while m.attack_progress >= 1.0 and guard:
        m.attack_progress -= 1.0
        var dmg = m.attack; var crit = rng.randf() < m.crit_chance
        if crit: dmg *= m.crit_mult
        _enemy_hp = maxf(0.0, _enemy_hp - dmg)
        hit_dealt.emit(dmg, crit)
        if _enemy_hp <= 0.0: break
    if _enemy_hp <= 0.0: break
if _enemy_hp <= 0.0: <击败:沿用 02 的 enemy_defeated/_roll_loot/_advance_after_kill> ; return
# 敌人进攻:累计出手,打最前存活成员(闪避→护甲)
_enemy_attack_progress += _enemy_def.attack_speed * tick_seconds
while _enemy_attack_progress >= 1.0 and guard:
    _enemy_attack_progress -= 1.0
    var target = _front_living_member(); if target == null: break
    var raw = _enemy_def.attack * _enrage_mult()
    if rng.randf() < target.dodge_chance: player_dodged.emit(party.find(target)); continue
    var reduced = raw * (1.0 - target.armor / (target.armor + armor_k))
    target.take_damage(reduced)
if not has_living_member(): party_wiped.emit(); _retreat_after_wipe()
```
- 队伍先手、敌死不还手 = 02 现行为(progression 回血测试依赖:敌人 tick2 被杀就不还手),保留。
- `_enrage_mult()` = `enraged ? 1.0 + enrage_ramp_per_sec*(_enemy_fight_time - enrage_threshold_sec) : 1.0`(线性占位,曲线形状留 F1)。
- `_party_total_attack()` 被 cadence 循环取代 → 删除(无测试直接引用它,CONTEXT-FINDINGS §3)。`_front_living_member` 保留。

**D5 — 软狂暴配置只用全局 `@export`,不做每怪覆盖。**
`enrage_threshold_sec` / `enrage_ramp_per_sec` 放 `CombatDirector` 的 `@export`(走配置,守 hard-NO);对普通怪/Boss/无尽刷一视同仁(farming 场景够弱、在阈值前清完,不会误触发——FEATURE-DESIGN §3.5 自洽性)。
- *为何*:全局即满足"走配置不硬编码";每怪覆盖是 FEATURE-DESIGN F5 倾向的增强,但当前**无具体需求**(没有"某 Boss 要特殊狂暴曲线"的实例),按 hard-NO"不为没影的系统提前抽象"先不做。
- *拒绝的替代*:现在就给 `EnemyDef` 加一套 enrage 覆盖字段 + sentinel——过度设计。留 §4 Out-of-scope + §5 Flag,有真需求再加。

**D6 — `.tres` 怪血本轮不做精确等比重调,只补 `attack_speed` 占位 + 验证墙位置。**
DPS 从"attack×10/秒"重定到"attack×1/秒"(战士 attack=6、attack_speed=1.0 → 6 DPS),怪血保持现值(stage_01: 12/18/28/Boss90;stage_02: 50/65/85/Boss220),只给每个 `EnemyDef` 补 `attack_speed=1.0`。战斗变长~10×(对挂机可接受),且自然形成卡关:Boss220 ÷ 6 ≈ 37 次命中 > enrage 阈值 → **stage 2 Boss 会狂暴 = 裸装战士的墙**(正是支柱 2"够不着→去 04 拿装备"的钩子)。
- *为何*:精确数值(怪血、阈值、曲线、各维度基准)是 FEATURE-DESIGN F1 数值专章的活;本功能只验机制。盲目 ÷10 怪血会让"几乎一击一杀"抹掉 cadence 质感,反而更糟。
- *拒绝的替代*:本轮就精调全套数值——越界(F1),且无装备维度可调,调了也是白调。
- Implementer 只需 sanity:**stage 1 全程可在阈值内清掉**(Boss90÷6≈15 命中≈15s < 25s ✓),stage 2 Boss 触发狂暴墙符合预期即可;若 stage 1 体感慢到荒谬可微调阈值/怪血**但须保持 stage_config_test 的大小序**(关内递增、stage2.scene0 > stage1.scene2)。

**D7 — 新增信号(全部 additive,不动既有 5 个信号)。**
`hit_dealt(amount: float, is_crit: bool)`、`player_dodged(member_index: int)`、`enemy_enraged`,外加公开 var `enraged: bool` 供 View 持续读狂暴态。既有订阅者不受影响(§3.8 只禁"改/删"事件流,加信号是扩展)。View 的敌人伤害飘字**改由 `hit_dealt` 驱动**(每次命中一个飘字、暴击放大染色),取代现在"逐帧比较 `_last_enemy_hp` 差值"的推法——因为后者无法表达单 tick 多次命中/暴击,且闪避(0 伤害)根本没有血量差(CONTEXT-FINDINGS §5.5)。

## 3. Ordered steps

**Step 1 — 加字段与运行时状态(纯加法,行为不变)。**
- 文件:`src/combat/party_member.gd`(加 6 个 stat 字段 + `attack_progress` 运行时,扩 `_init` 尾部可选参数);`src/combat/enemy_def.gd`(加 `@export var attack_speed: float = 1.0`);`src/combat/combat_director.gd`(在 `@export_group("v1 战士")` 加 `warrior_attack_speed:=1.0`/`warrior_armor:=0.0`/`warrior_dodge_chance:=0.0`/`warrior_crit_chance:=0.0`/`warrior_crit_mult:=2.0`/`warrior_hp_regen:=0.0`;新 `@export_group("公式")` 加 `armor_k:=50.0`;新 `@export_group("软狂暴")` 加 `enrage_threshold_sec:=25.0`/`enrage_ramp_per_sec:=0.5`;加运行时 var `_enemy_attack_progress:=0.0`/`_enemy_fight_time:=0.0`/`enraged:=false`;声明 3 个新 signal;`init_default_party` 把 6 个 warrior_* 传进 `PartyMember.new`;`start_battle` 复位 `_enemy_attack_progress`/`_enemy_fight_time`/`enraged` 及所有成员 `attack_progress`)。
- 验证:`godot --headless --check-only` 退出 0;**跑全套 gdUnit4 → 仍全绿**(`tick_combat` 未改、新字段未被消费、新信号未发)。这是"加法未破坏 02"的检查点。

**Step 2 — 重写 `tick_combat` 为 cadence + 暴击/闪避/护甲/回血/狂暴(按 D4 伪码)。**
- 文件:`src/combat/combat_director.gd`(重写 `tick_combat`;加私有 `_enrage_mult()`;删 `_party_total_attack`;按 D4 发 `hit_dealt`/`player_dodged`/`enemy_enraged`)。
- 验证:`--check-only` 退出 0(编译通过)。**预期此时部分 02 旧测试转红**(时序假设变了,CONTEXT-FINDINGS §4)——这是受控的红色间歇,由 Step 3/4 收口;本步只验编译 + 机制将在 Step 3 被单测覆盖。

**Step 3 — 为六维 + 狂暴写新 gdUnit4 单测(确定性边界值,验机制本身)。**
- 文件:新增 `test/combat/formula_test.gd`(及可选 `enrage_test.gd`)。
- 覆盖(用 0.0/1.0 极值或注入 `rng.seed` 去随机,避免 flaky):
  - **暴击**:`crit_chance=1.0,crit_mult=2.0` → 一次命中伤害 = `attack×2`;`crit_chance=0.0` → = `attack`。
  - **闪避**:`dodge_chance=1.0` → 敌人出手后目标 HP 不变 + 收到 `player_dodged`;`=0.0` → 正常掉血。
  - **护甲**:`armor = armor_k` → 减伤恰 50%(`armor/(armor+K)=0.5`),实伤 = `raw×0.5`;`armor=0` → 无减伤。
  - **回血**:`hp_regen=5.0,tick_seconds=0.1` → 先扣血再 tick,HP 回升 0.5(封顶 max_hp)。
  - **cadence**:`attack_speed=1.0,tick_seconds=0.1`,对超高血敌人 tick N 次 → 命中次数 ≈ N/10(用 `is_between` 容差断言,**勿**断言精确逐 tick 计数,见 Flag-C);`attack_speed=2.0` 命中频率约翻倍。
  - **软狂暴**:`enrage_threshold_sec` 设小(如 0.5),对不死敌人持续 tick → 过阈值后 `enraged==true`、`enemy_enraged` 恰发一次、敌人单次伤害较狂暴前增大;`start_battle` 新敌人后 `enraged` 复位、计时归零。
- 验证:`--check-only` 0;**新单测全绿**(证明 Step 2 的公式正确)。

**Step 4 — 回贴 02 旧测试:按 cadence 改写受影响断言,保结构意图。**
- 文件:`test/combat/combat_director_test.gd`、`tick_driver_test.gd`、`progression_test.gd`、`retreat_test.gd`、`button_countdown_test.gd`、`loot_test.gd`(`stage_config_test.gd` 基本免疫,见 Step 5)。
- 原则(交 Implementer 逐 suite 执行,**用不等式/语义断言,不用脆弱的逐 tick 精确算术**):
  - **结构类**(progression 游标推进、loot 每杀一次掉落、retreat 四条回退、countdown 推进/修整):这些只需"击杀/团灭确定性发生"。`tick_combat` 内**首杀即 break、一次调用最多杀一个**(D4),故让进攻方攻速足够高、单次伤害足够秒掉测试用 1 血/低血怪 → 每次 `tick_combat()` 仍恰一杀;让需要"敌人先杀脆皮"的用例(如 `test_member_down_but_party_continues`)反过来给**敌人**高攻速、给**队伍**低攻速,使敌人先开火、队伍来不及秒敌 → 用**不等式**保证(脆皮 hp5 挨一发 atk10 必死、坦克 hp200 必活、高血敌人 3 tick 内死不了),避免依赖"恰好每 tick 一次"。
  - **算术类**(progression `test_party_heals_full_after_clearing_a_scene` 的 90/100、retreat `test_grind_round_heals_party...` 的 90/90/80/100):保留其**语义**(过场景/满轮 → 全队回满、刷一轮血不越刷越低 = 用户报过的 bug 回归网),**重算或改为语义断言**(如清场后 `current_hp == max_hp`),不死盯中间那个具体数。
  - 参照 CONTEXT-FINDINGS §4 的逐用例点名清单逐条过。
- 验证:`--check-only` 0;**全套 gdUnit4(旧+新)全绿**。

**Step 5 — 接真实游戏数值 + `.tres` 补 `attack_speed` 占位(D6)。**
- 文件:`assets/data/combat/stage_01.tres`、`stage_02.tres`(每个 `EnemyDef` 子资源加 `attack_speed = 1.0`);`combat_director.gd` 的 warrior_* 占位保持(attack_speed=1.0、其余防御/暴击=0)。怪血保持现值。
- 验证:`stage_config_test.gd` 全绿(只验结构 + 大小序 + 正数,加字段与保持 HP 大小序不破坏它;如想验攻速可加一条 `attack_speed > 0` 断言);`--check-only` 0。

**Step 6 — View 死因可读(F7 硬验收点)。**
- 文件:`src/combat/combat_view.gd`(订阅 `hit_dealt`→敌人伤害飘字逐命中、暴击放大+暴击色;`player_dodged`→对应成员位冒 "MISS";`enemy_enraged` + 读 `enraged`→克制的"敌人狂暴!"横幅/日志行;移除 `_last_enemy_hp` 逐帧差值的伤害飘字推法,改由 `hit_dealt` 驱动)。回血飘字 = 尽力而为(可由成员 HP 非复活性回升推出),非硬要求(Flag-D)。
- 验证:**手动 Play**(UI 不进 gdUnit4,project-context §5)。打开战斗场景按 Play,观察:逐命中飘字;在 Inspector 临时把 `warrior_crit_chance` 调到 0.3 → 看见暴击飘字;`warrior_dodge_chance` 调到 0.3 → 看见 MISS;放任 stage 2 Boss 打到过阈值 → 看见"狂暴"提示 + 战士被推平团灭回退。验后把临时调的值还原。

**Step 7 — 全量回归收口。**
- 验证(project-context §5 全绿才算过):① `godot --headless --check-only` 退出 0;② 全套 gdUnit4 绿(**不带 `-d`**);③ 手动 Play 跑 stage 1→2:cadence 可见、击杀→掉落 FX/进度读出正常、团灭→回退刷怪正常、通关 5s 倒计时正常、stage 2 Boss 狂暴墙触发且可读。更新 HANDOFF。

## 4. Out of scope（本功能明确不做）
- 装备物品本身(背包/穿戴/基底/词缀 roll)= **04-loot-equipment**;本功能只让公式维度存在并被消费。
- 吸血(本轮未选,留 v2);敌人侧的暴击/闪避/护甲(留作日后调怪旋钮)。
- 软狂暴的**每怪覆盖**(D5:只做全局 @export,有真需求再加)。
- **精确数值调参**(攻速基准、护甲 K、暴击率/倍率、闪避率、回血速率、狂暴阈值/曲线、02 怪血等比重定)= FEATURE-DESIGN **F1 数值设计专章**;本功能用占位值。
- 等级/经验、团战(单场多敌)、套装/宝石/重铸、横版全套演出 —— 各自 BACKLOG/Later,**不顺手并入**(hard-NO)。
- 不引任何新插件/AddOn。

## 5. Risks & Flags / Open questions
- **Flag-A〔需你/Implementer 拍:加字段默认值取向〕** 本计划取"`PartyMember._init` / `EnemyDef` 默认 `attack_speed=1.0`(设计自然单位)+ Step 4 逐 suite 改写旧测试"。**替代**:把代码默认设成"每 tick 出手一次"的等价值(=1/tick_seconds),则旧测试几乎零改动即绿,但代价是一个"只相对 tick_seconds 才有意义"的隐藏耦合默认值(对 04 构造成员是 footgun)。**推荐前者**(诚实默认 + 显式改测试),因为 04 会大量构造/配置成员,默认值必须语义自洽;旧测试改写虽是实打实工作量,但用不等式/语义断言后稳定且仍验原意图。若你更看重最小 diff,可改用后者——告诉我或让 Implementer 定。
- **Flag-B〔已决:软狂暴配置位〕** 全局 `@export`,无每怪覆盖(D5)。Boss/无尽刷一视同仁;farming 场景够弱不触发。若 playtest 发现某 Boss 需要专属狂暴曲线,再加 `EnemyDef` 覆盖(届时新需求,不违 hard-NO)。
- **Flag-C〔cadence 单测勿断言精确逐 tick 计数〕** `attack_speed × tick_seconds`(如 1.0×0.1)在浮点下不精确,"恰好每 tick 一次"会偶发漂移(某 tick 0 次/某 tick 进位)。新单测的 cadence 用 `is_between` 容差;旧结构测试用"足够高攻速 + 首杀 break"或不等式,**别**让断言吊在精确逐 tick 算术上(这也是 Step 4 改写的核心手法)。
- **Flag-D〔回血 View 读出 = 尽力而为〕** F7 硬要求只点名"软狂暴 + 闪避"死因可读;暴击飘字强烈建议做(§1 幻想支点)。回血"血条柔和回升"若 View 侧不易干净推出,可留占位/后补,不阻塞验收。
- **Flag-E〔数值墙 = 预期非 bug〕** D6 下 stage 2 Boss 会狂暴推平裸装战士(≈37 命中 > 25s 阈值)。这是**故意的卡关墙**(支柱 2),不是回归 bug;但 Implementer 须确认 **stage 1 全程能在阈值内清掉**,否则第一关就卡死 = 真 bug。精确阈值/怪血平衡 = F1。
- **Flag-F〔View 伤害飘字改信号驱动〕** Step 6 用 `hit_dealt` 取代逐帧 HP 差值的飘字逻辑,改了一处既有(手动验收过的)表现。须在 Step 6/7 的 Play 里复验飘字仍正常(逐命中、暴击放大),别只看新维度。
- **回归边界自查(交 Implementer 全程守)**:`loot_dropped`/roll、`boss_cleared`/永久解锁、团灭回退/无尽刷状态机、5s 倒计时、后台 tick 驱动、4 格队伍、过场景/通关/满轮全队回满的回血粒度 —— 全部**不动**;胜负仍只由"敌血≤0 / 全员倒"两事件触发(FEATURE-DESIGN §3.8)。
