---
artifact: REVIEW
feature: 02-auto-combat-loop
role: Reviewer
status: accepted   # 第 3 轮(F1 美术接线增量)复审:verdict = APPROVE,0 must-fix
updated: 2026-06-18
inputs: [PLAN.md, CHANGES.md, project-context.md, src/combat/enemy_def.gd, src/combat/combat_view.gd, INTEGRATION-STEPS.md, ASSET-SPEC.md, test/combat/{progression,retreat}_test.gd]
next: 功能收口;接线已 accepted、人工 Play 已验收
---

# REVIEW — 自动战斗循环 (Auto Combat Loop)

## 0b. 复审记录(2026-06-18,第 3 轮 · F1 敌人/FX 正式素材接线增量)
**verdict = APPROVE,0 must-fix。** 本轮只审 F1 增量(CHANGES §1「增量」/ §4 偏差 5-6 / §5 Wiring Contract E),
逻辑核心未动、上轮结论不变。逐行读了改动的两个文件:
- **`enemy_def.gd:10-13`** — 纯加 `@export_group("外观") + @export var sprite: Texture2D`,无逻辑/数值改动,
  现有 `.tres` 照常加载;贴图走 Resource、不硬编码路径 ✓(守 hard-NO + ASSET-SPEC §6)。
- **`combat_view.gd`** — 敌人主显改 `_enemy_sprite: TextureRect`,`EnemyDef.sprite` 为空时回退 `_enemy_panel: ColorRect`
  (`_update_enemy:96-102`,graceful degradation,不崩 ✓);`_layout_enemy_sprite:116-123` 按原生比例缩放、
  夹 70–125px、脚底落 `ENEMY_GROUND_Y`、水平居中,除零有 guard ✓,且仅在贴图变化时重排(`:101` 守每帧不重算)✓;
  `_spawn_pillar:222-237` 改用 `FX_LIGHT_PILLAR` + `modulate` 染稀有度 + `_spawn_sparkle`,tween 结束 `queue_free` 无 orphan ✓;
  `_gold_flash` 保持 ColorRect(ASSET-SPEC §1B)✓;FX 由 `preload` 固定路径(EI 契约 F1 P2-d 明示属代码侧)。
- **测试偏差 6**(`progression_test.gd:96` / `retreat_test.gd:102` `:=`→显式 `: CombatDirector`)— 仅类型标注、
  消除 Variant 推断警告致 CLI parse 失败,无行为改动 ✓;现 CLI 与编辑器一致 32 绿、`--import` 0(本 session 已复跑确认 exit 0)。
**剩余 nits(非阻塞):** N4 敌人名签可能压到高个 Boss 贴图上沿、N5 FX 路径硬编码(契约内、可接受)——见 §4。
本轮无新增 should-fix;S2 仍归 Game Designer。下方 §0–§5 为前两轮原文,保留存轨迹。

## 0. 复审记录(2026-06-18,第 2 轮)
**verdict 由 APPROVE WITH NITS → APPROVE。** Implementer 已闭合 S1:CHANGES §1 补回三处回血
(`combat_director.gd:223` 通关 / `:238` 过场景 / `:209-216` 卡关满轮)+ 小队状态栏(`combat_view.gd`
`_update_party`/`_build_party_bars`),§4 新增"偏差 4(用户授权)"并就 S2 知会 Game Designer,
测试计数 30→32(progression 6 / retreat 6)全档刷齐,Wiring Contract §5 未动(仍准确)。
逐条核对 CHANGES 与代码一致。**剩余非阻塞项:** S2 待 Game Designer 在 FEATURE-DESIGN F1 确认
回血粒度是预期;N1–N3 nits 可不动;step 7/8/9 仍待人工 Play 验(本就只能肉眼验)。
> 下方第 1–5 节为第 1 轮原文,保留以存轨迹;S1 现已解决,见本节。

## 1. Verdict
**APPROVE**(第 1 轮为 APPROVE WITH NITS;S1 已闭合,见 §0)

逻辑核心(解算 / 进度游标 / Boss 永久解锁 / 团灭回退四 case / 推进-修整入队 / 掉落事件流 /
固定步长 tick)读下来与 PLAN D1–D10 一致,无阻塞性正确性或安全问题;32 用例覆盖到位,
我抽查的两个回血测试断言逻辑成立。**没有 must-fix。** 第 1 轮唯一够分量的 should-fix(CHANGES 对不上代码)
已由 Implementer 修复并经复审核实。其余 nits + S2(归 Game Designer)不阻塞。

## 2. Must-fix (blocking)
无。

## 3. Should-fix (non-blocking)

- **S1 〔✅ 已解决,2026-06-18 复审核实〕· CHANGES.md 与代码不同步(artifact 失真)。**
  `combat_director.gd` 在 CHANGES 写完后又加了三处**改变玩法的行为**,CHANGES §1/§4 完全没提:
  - `_advance_after_kill` 普通场景清场后 `_revive_party()`(`combat_director.gd:238`)——过场景回满;
  - Boss 通关后 `_revive_party()`(`combat_director.gd:223`)——通关回满;
  - GRINDING 分支按 `kill_count` 计一轮、满轮 `_revive_party()`(`combat_director.gd:209-216`)——卡关刷怪回血。
  另外 `combat_view.gd` 新增了**小队状态栏**(`_update_party()` / `_build_party_bars()`,
  `combat_view.gd:95-112, 243-278`),CHANGES §1 视图小节也没列。
  **Why it matters:** project-context 明确本项目是纯 vibe coding、"artifact / HANDOFF 的清晰度尤为重要"。
  下游 Engine Integrator / Art Spec 读 CHANGES 接线、Game Designer 复盘玩法,都会被旧版误导
  (尤其"小队状态栏"是个新 UI 元素,Art Spec 需要知道它存在)。
  **方向:** Implementer 把这三处回血 + 状态栏补进 CHANGES §1,并在 §4 Deviations 标一条
  "playtest 后用户拍板新增回血/状态栏,偏离原 PLAN(已授权)";顺手把 `updated:` 刷新。
  Wiring Contract(§5)本身仍准确(autoload 名 / 信号 / stages 注入都没变),不必动。

- **S2 · 回血策略改了核心难度模型,建议 Game Designer 复核(非 bug)。**
  "每清完一个普通场景就全队回满"(`combat_director.gd:238`)意味着**跨场景的血量损耗被完全消除**,
  卡关只可能发生在"单场景内 kill_count 次击杀的损耗"或"Boss"两处。
  **Why it matters:** 支柱 2 的"够到下一个够不着的怪"靠的就是难度门槛;把 attrition(消耗战)拿掉后,
  难度调节几乎全压在单场景 / Boss 数值上。这是用户 playtest 当场拍板的修复(解决"血越刷越低回退"),
  方向没问题,但它把难度曲线的着力点搬家了,值得 Designer 知会一句、确认是预期。
  **方向:** 非阻塞;在 FEATURE-DESIGN F1(数值曲线留 playtest)下记一笔"回血粒度 = 过场景/满轮",
  让后续平衡时心里有数。代码不必改。

## 4. Nits (optional)

- **N1 · "本轮"一词被重载。** PLAN D6 定义"本轮 = 当前敌人死亡那刻"(用于推进/修整入队执行,
  `combat_director.gd:201-208` 仍是单敌死亡执行 ✓);但回血用的"一轮 = 刷满 kill_count"
  (`combat_director.gd:209-216`)。两个"轮"含义不同,代码注释已分别说明,行为也符合用户意图,
  只是术语易混。可在注释里把后者叫"一刷满轮"以免日后误读。

- **N2 · `_revive_party()` 会"复活"已倒下的成员。** 它对所有非 null 成员置 `current_hp = max_hp`
  (`combat_director.gd:325-328`),含 `current_hp==0` 的死亡成员。v1 单战士不会暴露(战士一死即团灭),
  但等 N 人组队落地后"过场景顺带满血复活阵亡队友"是否符合设计需 Designer 拍。现在无需改,
  留个心眼即可(挂到 BACKLOG 多职业项更合适)。

- **N3 · RESTING 是单向 stub,无 resume API。** 点修整后 `_enter_rest()` 进 RESTING 永久挂起,
  v1 无返回战斗的入口(`combat_director.gd:279-282`)。这是 PLAN D6/F2 授权的占位(真城镇=04),
  符合预期;仅提醒人工 Play 验时别误以为是 bug——点了修整战斗就停住直到重开。

- **N4 〔第 3 轮 · F1〕· 敌人名签位置固定,可能压到高个贴图上沿。** `_enemy_name` 固定在 `(596,64)`
  (`combat_view.gd:359`),而 boss/食人魔贴图夹到 125px 高、脚底落 y=180 → 上沿到 y≈55,名签会叠在贴图顶部。
  纯视觉、不阻塞;人工 Play 时顺带看一眼 Boss 名签是否被贴图盖住,碍眼再把名签 y 上移或随贴图高动态放。
  (已在 INTEGRATION-STEPS §G 步24 的"敌人正式贴图"走查范围内,无需单独验。)

- **N5 〔第 3 轮 · F1〕· FX 两图路径硬编码 `preload`(契约内,可接受)。** `combat_view.gd:30-31` 直接
  `preload` 两张 FX。hard-NO 是"平衡参数/路径不硬编码进逻辑",FX 是固定视觉常量、非平衡数据,且 EI 接线契约
  (INTEGRATION-STEPS F1 P2-d)明确"FX 属代码侧";为 2 张定死的视觉资源加 `@export` 反属过度设计。判定可接受,
  仅记此判断轨迹。**敌人贴图(平衡相关、数据驱动的部分)正确走了 Resource**,边界划分合理。

## 5. What I checked but found fine (覆盖说明)

- **战斗解算(D2):** `tick_combat` 队伍总攻 → 当前敌人;敌死当 tick **不反击**(先判死再反击,
  `combat_director.gd:129-149`),回血测试的逐 tick 血量断言据此成立。`_party_total_attack` /
  `_front_living_member` 遍历存活成员,N 人地基正确。
- **进度游标 + Boss 永久解锁(D4):** `BOSS_SCENE=3`、`max_unlocked_stage = maxi(...)` 单调不回退、
  Boss 通关进 5s 倒计时而非立刻推进(`:218-229`)——符合"Boss 一次性门"。
- **团灭回退四 case(D5):** i==BOSS→退末普通场景且推进目标=Boss;i≥1→退 i-1 推进回 i;
  i==0 非首关→跳上关 Boss 退 (S-1,末) 推进 (S,0);i==0 首关→原地。逐条对上 PLAN,retreat_test 五用例覆盖。
- **推进/修整 + 倒计时(D6):** GRINDING 入队、本轮(单敌死)执行;倒计时无操作自动推进、
  修整即时取消推进(`:245-266`)——与 button_countdown_test 一致。
- **掉落事件流(D7):** `_roll_loot` 单次 0/1 发射、先种类后稀有度、金币恒 white、`_weighted_pick`
  权重和 ≤0 退化保护(`:333-362`)。kind/rarity 取值合法,03 接口边界干净。
- **固定步长 tick(D8):** 累加器 `while _accum >= tick_seconds`(`:87-97`)帧率无关,guard<1000 防卡死;
  RESTING/倒计时态空跑 tick 无副作用。
- **掉落契约 = 03 边界:** `loot_dropped(kind, rarity)` 只产事件,无物品实例,02 未越界进 03 ✓。
- **数值全走 Resource(hard-NO):** EnemyDef/SceneConfig/StageConfig + 两关 `.tres` 手填,
  逻辑里无硬编码平衡数;`CombatView.stages` 走 `@export` 注入而非硬路径 ✓。换关只改 .tres 列表。
- **接线:** `project.godot` autoload `Combat="*…combat_director.gd"`(避开 class_name 同名,§4 偏差1 处理正确);
  `floating_shell.tscn` CombatView 注 stage_01/02 ✓;视图 `get_node_or_null("/root/Combat")` 缺单例不崩。
- **约定:** 信号全过去式(enemy_defeated/party_wiped/loot_dropped/boss_cleared/rest_requested)✓;
  早返回、composition、注释只解释"为什么" ✓。
- **安全:** 无外部输入 / 网络 / 密钥 / 注入面;RNG 可注入种子供测试。无 over-engineering
  (4 格 slot / N 人是 project-context 钦定的 MVP 必须,非提前抽象)。
- **未跑测试:** 用户已在编辑器跑绿、我读过两处新增回血测试断言成立,故未重跑;step 7/8/9
  仍待人工 Play 验(后台 tick / 视图可读性 / 两关闭环),属本来就只能肉眼验的部分。
