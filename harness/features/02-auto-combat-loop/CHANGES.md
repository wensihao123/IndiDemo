---
artifact: CHANGES
feature: 02-auto-combat-loop
role: Implementer
status: draft
updated: 2026-06-18
inputs: [PLAN.md, FEATURE-DESIGN.md, project-context.md, HANDOFF.md, INTEGRATION-STEPS.md(F1), ASSET-SPEC.md, ACCEPTANCE.md]
next: Engine Integrator (INTEGRATION-STEPS Part 2) / Reviewer
---

# CHANGES — 自动战斗循环 (Auto Combat Loop)

> 实现 PLAN 9 步的符号/轻演出版自动战斗循环 + playtest 后回血/状态栏微调(§4 偏差 4)。逻辑步全配
> gdUnit4 headless 单测(32 用例全绿、0 orphan);UI/演出/后台 tick 三处只能手动 Play 验,已在 §3、§6 标出待人工验收。
>
> **增量(2026-06-18 · F1 敌人/FX 正式素材接线):** 应 Engine Integrator INTEGRATION-STEPS 的 F1 flag——
> 占位换正式美术需先补两处代码(`EnemyDef.sprite` 字段 + `combat_view` 把敌人/光柱占位换成贴图)。
> 见下 §1「增量」小节、§4 偏差 5、§5 Wiring Contract C 补充。逻辑/数值未动,32 用例仍全绿。

## 1. What changed / 改了什么

### 新增 — 数据模型(Resource,PLAN step 1 / D3)
- `src/combat/enemy_def.gd` — `class_name EnemyDef`。`@export`:`display_name`、`max_hp`、
  `attack`、`drop_chance`,以及统一掉落表权重 `weight_gold/weight_material/weight_equipment`
  与稀有度权重 `rarity_weight_white/blue/gold`。纯数值,无逻辑。
- `src/combat/scene_config.gd` — `class_name SceneConfig`。`@export`:`enemy: EnemyDef`、
  `kill_count: int`(清场 = 杀够数,D3 取 kill-count)。
- `src/combat/stage_config.gd` — `class_name StageConfig`。`@export`:`stage_name`、
  `scenes: Array[SceneConfig]`、`boss: EnemyDef`。
- `src/combat/party_member.gd` — `RefCounted`,非 Resource。`display_name/max_hp/attack/current_hp`,
  `is_alive()`、`take_damage(amount)`。队伍成员的运行时载体。
- `assets/data/combat/stage_01.tres`、`stage_02.tres` — 作者手填的两关数据。stage_01 三场景
  (哥布林/狼/兽人,hp 12/18/28,drop 0.5/0.55/0.6)+ Boss 哥布林王(hp 90,drop 1.0,equip 权重 35);
  stage_02 调得稍硬(精英兽人/暗影狼/食人魔,hp 50/65/85)+ Boss 兽人酋长(hp 220)。

### 新增 — 模拟核心(Autoload,PLAN step 2-7 / D1-D8)
- `src/combat/combat_director.gd` — `class_name CombatDirector`。战斗/进度状态机 + 固定步长 tick。
  - 信号:`enemy_defeated(enemy)`、`party_wiped`、`loot_dropped(kind, rarity)`、
    `boss_cleared(stage)`、`rest_requested`。
  - 解算(D2):`tick_combat()` 每 tick 队伍打当前敌人、敌人打最前存活成员;敌死 → 事件 +
    掉落 roll + 推进;全灭 → 团灭 + 回退。
  - 进度(D4):游标 `cur_stage/cur_scene`(0/1/2 普通,3=`BOSS_SCENE`)+ `max_unlocked_stage`;
    Boss 击杀永久解锁、永不再战。
  - 回退(D5):团灭四 case(i≥1 退一场景 / i==0 非首关退上关末场景 / i==0 首关原地 / Boss 退场景2)。
  - 按钮模型(D6):`Mode { PROGRESSING, GRINDING, STAGE_CLEAR_COUNTDOWN, RESTING }`;Boss 后
    5s 倒计时自动推进、`request_rest()` 取消;GRINDING 下推进/修整入队、当前敌人死亡(本轮结束)执行。
  - 掉落(D7):`_roll_loot()` 单 roll → kind(金/材料/装备)→ 非金再 roll 稀有度;`loot_dropped` 发事件。
  - tick(D8):`_process(delta)` 累加器按 `tick_seconds`(默认 0.1,`@export`)步进,帧率无关。
  - **回血(playtest 后新增,用户拍板 2026-06-18,见 §4 偏差 4):** `_revive_party()` 把全部存在成员
    回满,在三处调用——① 普通场景清场后(`_advance_after_kill`,过场景回满);② Boss 通关后
    (下一关满状态开局);③ GRINDING 卡关刷怪满一轮(刷满该场景 `kill_count` = 一轮完成)后回满,
    使血不会越刷越低导致连环回退。原有团灭回退处的回满保留不变。GRINDING 入队的推进/修整仍在
    单敌死亡即执行(PLAN D6 不变)。
- `src/combat/loot_stub.gd` — `loot_dropped` 的占位监听(打印事件),PLAN step 3 的 stub。

### 新增 — 视图(MainArea 读出,PLAN step 8 / D9)
- `src/combat/combat_view.gd` — `class_name CombatView`,`extends Control`。订阅 `Combat` 单例信号、
  `_process` 读当前态渲染:敌人占位 ColorRect + 名字 + 血条、伤害飘字(从敌 HP 帧间差推出,不需新信号)、
  战斗日志(4 行)、进度读出、推进/修整按钮 + 倒计时;掉落分级 FX(白默默 / 蓝光柱 / 金光柱+窗口内一闪)。
  UI 子节点全部代码内建(`_build_ui`),减少 .tscn 改动。`@export var stages: Array[StageConfig]` 注数据(不硬编码路径)。
  - **小队状态栏(playtest 后新增,用户拍板 2026-06-18,见 §4 偏差 4):** 左上每格一行 名字 + 血条 + `当前/最大` HP
    文本(`_build_party_bars` / `_update_party`);存活绿、阵亡灰,空 slot 隐藏。结构按 `PARTY_SLOTS` 建满 4 格,
    v1 只第 0 格显示。让玩家余光能读到小队 HP(原本无任何小队状态显示)。

### 增量 — F1 敌人/FX 正式素材接线(2026-06-18,应 EI INTEGRATION-STEPS F1)
- `src/combat/enemy_def.gd` — 加 `@export_group("外观")` + `@export var sprite: Texture2D`。贴图随
  Resource 走、不硬编码路径(ASSET-SPEC §6 / project-context §4);留空 = 视图回退占位色块。**纯加字段,
  不改任何已有数值/逻辑**,故 stage_01/02.tres 现有数据照常加载(测试仍 32 绿)。
- `src/combat/combat_view.gd` — 敌人占位 `_enemy_panel: ColorRect` → 新增 `_enemy_sprite: TextureRect`
  主显、`_enemy_panel` 降级为「`EnemyDef.sprite` 为空时」的回退占位(graceful degradation,接好 .tres 后不再出现)。
  - `_update_enemy()`:有贴图 → 显示 `_enemy_sprite`、`_layout_enemy_sprite()` 按原生比例缩放到显示高
    (`native_h × 0.71` 夹到 70–125px,ASSET-SPEC §1)、脚底落地平线 `ENEMY_GROUND_Y=180`、水平居中
    `ENEMY_CENTER_X=635`;无贴图 → 显示回退色块。敌人朝左(ACCEPTANCE 已核),**无 flip_h**。
  - `_spawn_pillar()`:ColorRect → `fx_light_pillar` 贴图(`preload`)+ `modulate` 染稀有度色(蓝 `#6699ff`/
    金 `#ffd24a` 来自既有 `RARITY_COLOR`,白不出 FX),脚底升起后淡出;附 `_spawn_sparkle()` 把
    `fx_loot_sparkle` 叠在光柱根部(F1 P2-d 可选项)。
  - `_gold_flash()` **保持 ColorRect 不动**(ASSET-SPEC §1B 明确金装全屏一闪不出素材)。
  - `_spawn_damage_float()` 锚点从 `_enemy_panel.position` 改为常量 `ENEMY_CENTER_X/GROUND_Y`(贴图尺寸可变,
    锚点不再依赖具体节点)。
  - FX 贴图按 EI 契约由代码 `preload` 固定路径(INTEGRATION-STEPS F1 P2-d:FX 属代码侧、非数据);
    敌人贴图仍走 Resource(`EnemyDef.sprite`),不硬编码。
- `test/combat/progression_test.gd:96`、`test/combat/retreat_test.gd:102` — 把 `var d := auto_free(...)`
  改为 `var d: CombatDirector = auto_free(...)`(见 §4 偏差 6:CLI toolchain 把 Variant 推断警告作错处理)。

### 修改
- `project.godot` — 新增 `[autoload]`:`Combat="*res://src/combat/combat_director.gd"`(见 §4 偏差)。
- `scenes/shell/floating_shell.tscn` — MainArea 下加 `CombatView` 节点(铺满主区),
  `stages` 注 stage_01 + stage_02 两个 `.tres`(ext_resource 引入)。

### 新增 — 测试(PLAN step 2-7、D10)
- `test/combat/` 下 7 个套件、32 用例:`combat_director_test`(4 解算/团灭)、`loot_test`(5 掉落)、
  `progression_test`(6 游标/解锁 + **过场景回血**)、`retreat_test`(6 回退四 case + grinding 不动游标 +
  **卡关满轮回血**)、`button_countdown_test`(4 倒计时/入队)、`stage_config_test`(5 .tres 加载/字段)、
  `tick_driver_test`(2 帧率无关 + 累加器余数)。其中两条回血用例守偏差 4(见 §4)。

## 2. Why — 映射到 PLAN 步骤
| PLAN step | 产出 | 验证 |
|-----------|------|------|
| 1 数据 Resource + 2 关 | enemy_def/scene_config/stage_config.gd + stage_01/02.tres | stage_config_test(5) + import 0 |
| 2 战斗解算核心 | combat_director tick_combat / 信号 | combat_director_test(4) |
| 3 掉落事件流 + 稀有度 roll | _roll_loot + loot_stub | loot_test(5) |
| 4 进度状态机 + Boss 永久解锁 | 游标 / max_unlocked_stage / boss_cleared | progression_test(6) |
| 5 团灭回退(D5 四 case) | _retreat_after_wipe | retreat_test(6) |
| 6 推进/修整 + 倒计时 + 本轮结束执行 | Mode 状态机 / 队列 / countdown | button_countdown_test(4) |
| 7 固定步长 tick + Autoload + 后台持续 | _process 累加器 + project.godot autoload | tick_driver_test(2) + 手动 Play(待) |
| 8 MainArea 当前态读出 + 掉落 FX + 按钮 | combat_view.gd + 接入 .tscn | import 0 + 手动 Play(待) |
| 9 2 关闭环走查 | — | 手动 Play(待,见 §6) |
| **F1 增量** 敌人/FX 正式素材接线 | enemy_def.sprite + combat_view 贴图/光柱 | import 0 + 32 用例全绿 + 手动 Play(待 EI Part 2 拖图后) |

## 3. How verified / 怎么验的
- **解析/导入:** `godot.exe --headless --import` 退出码 0,无 parse error,scene 加载无误(F1 增量后复跑:仍 0,
  `CombatView` / `EnemyDef` 全局类正常注册)。
- **逻辑单测:** `godot.exe --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a test/combat`
  → **32 用例 0 errors / 0 failures / 0 orphans 全绿**(F1 增量后复跑确认;815ms)。每次跑后清掉生成的 `reports/`。
  - **注:** 去掉了原命令的 `-d`。`-d`(调试模式)会在 Variant 推断警告处断进调试器挂起;偏差 6 修掉两处
    推断写法后,即使带 `-d` 也不再断,但常规回归用不带 `-d` 的命令更干净。**实际 Godot 可执行 = `G:\Godot\Godot_v4.6.3\godot.exe`**。
- **未由我验(只能手动 Play,已交人工):**
  - step 7 后台 tick:收起(缩到 handle)等数秒再展开,进度应已前进;15fps 收起态与 60fps 展开态推进一致。
  - step 8 视图:余光可读"第几关第几场景 / 推进还是卡关刷";收起再展开直接显示当前态不补演;金装窗口内一闪不弹 OS 通知。
  - step 9 2 关闭环:关1 打到 Boss → 解锁 → 推进关2;关2 调到打不过 → 团灭回退无尽刷 → 推进重试 / 修整(落 stub)。

## 4. Deviations / 偏差(与 PLAN 不一致处,需 Reviewer 知会)
- **〔偏差 1 · 必读〕Autoload 单例名 = `Combat`,不是 `CombatDirector`。**
  PLAN D1 / step 7 写"注册 Autoload `CombatDirector`",但 `combat_director.gd` 带 `class_name CombatDirector`,
  Godot **禁止 Autoload 与全局 class_name 同名**(报 "Class 'CombatDirector' hides an autoload singleton",import 失败)。
  解法:**Autoload 注册名用 `Combat`,脚本保留 `class_name CombatDirector`**。
  → 游戏代码取单例用 `Combat`(或 `get_node("/root/Combat")`),**类型引用**(测试 / `current_enemy_def()` 等)仍用 `CombatDirector`。
  这是命名偏差,不影响行为。Wiring Contract(§5)已据此写。
- **〔偏差 2 · 微小〕清场→Boss 过渡更鲁棒。** PLAN 描述场景 0→1→2→3。实现里末普通场景清场后用
  `cur_scene = BOSS_SCENE if cur_scene + 1 >= scenes.size() else cur_scene + 1` 直接跳 Boss,
  使 1/2/3 场景关都能正确到 Boss(否则少于 3 场景的关会停在空场景永不到 Boss)。3 场景关行为不变。
- **〔偏差 3 · 授权内〕`rest_requested` 的 stub 落点 = `RESTING` 模式。** PLAN/FEATURE-DESIGN 授权 Implementer
  定最简占位(真城镇 = 04)。实现为:修整 → `_enter_rest()` 清当前敌人、置 `Mode.RESTING`、发 `rest_requested`;
  RESTING 态停止刷怪且倒计时不再自动推进。视图显示"修整中(占位 · 城镇 = 04)"。
- **〔偏差 4 · 用户授权,playtest 后新增〕过场景/通关/卡关满轮回血 + 小队状态栏。** PLAN 未含这两项。
  用户 playtest 后拍板(2026-06-18):① 报 bug"卡关刷怪血越刷越低导致连环回退" → 加"满一轮(刷满该场景
  `kill_count`)全队回满";② 顺势统一"每清完一个普通场景 + 通关 Boss 也全队回满"(原本只在团灭回退回满);
  ③ 缺小队 HP 显示 → 加左上小队状态栏。逻辑实现见 §1 模拟核心/视图小节,代码位:`combat_director.gd`
  `_revive_party()` 调用点(`:223` 通关 / `:238` 过场景 / `:209-216` 卡关满轮),`combat_view.gd`
  `_update_party()` / `_build_party_bars()`。新增两条 gdUnit4 用例守此行为:
  `progression_test.test_party_heals_full_after_clearing_a_scene`、
  `retreat_test.test_grind_round_heals_party_so_hp_does_not_erode`。
  **影响知会(REVIEW S2):** 此改把难度模型从"跨场景 attrition 消耗"搬成"单场景 / Boss 门槛",
  难度调节着力点转移——非 bug,留 Game Designer 在 FEATURE-DESIGN F1 确认预期。Wiring Contract(§5)不受影响。
- **〔偏差 5 · 增量,EI F1 触发〕敌人/FX 占位 → 正式贴图 + `EnemyDef.sprite` 字段。** 见 §1「增量」小节。
  这是 PLAN §5 / FEATURE-DESIGN 早已预告的"占位换正式素材"轨道(美术 Art Spec→EI 下游),非新设计;
  逻辑/数值/信号契约全未动。敌人贴图走 Resource、FX 贴图按 EI 契约走代码 `preload`。下一步 = 回 EI 做
  INTEGRATION-STEPS Part 2(给 stage_01/02.tres 内联 EnemyDef 子资源逐个拖贴图)。
- **〔偏差 6 · 测试维护,必读〕两处测试 `var d := auto_free(...)` → 显式类型。** `auto_free()` 返回 Variant,
  `:=` 推断成 Variant 触发警告;本机 Godot 4.6 CLI 把该警告**作错处理**,导致 `progression_test.gd:96` /
  `retreat_test.gd:102` 这两条偏差 4 新增用例**在扫描期 parse 失败、整套跑不起来**(其余 10 处早已用显式
  `var d: CombatDirector = auto_free(...)`,故只这两条受影响)。改为显式类型与其余一致即修复,32 用例恢复全绿。
  **知会:** CHANGES 原称"32 全绿"的复跑应是在编辑器内(警告等级与 CLI 不同);CLI(= EI/CI 校验路径)
  此前实为跑不起来。已修,现 CLI 与编辑器一致全绿。无逻辑改动。

## 5. Wiring Contract / 接线契约(Reviewer / Engine Integrator / 下游必读)
> 本期代码改 `project.godot` + `floating_shell.tscn` 已接好。下游若新建场景或换数据,按此接。

**A. Autoload(已接,`project.godot`):**
```
[autoload]
Combat="*res://src/combat/combat_director.gd"
```
- 单例节点名 **`Combat`**(全局可访问 `/root/Combat`);类型名 **`CombatDirector`**。两者不同名是必须的(§4 偏差1)。

**B. 视图接入(已接,`floating_shell.tscn`):**
- `MainArea`(Control,800×250)下挂 `CombatView` 节点(铺满主区,script = `src/combat/combat_view.gd`)。
- `CombatView.stages: Array[StageConfig]` 已注 `assets/data/combat/stage_01.tres`、`stage_02.tres`(ext_resource)。
  → **换关卡只改这个 export 的 .tres 列表,不碰代码。** 视图 `_ready` 里 `stages` 非空时调 `Combat.begin_run(stages)`。
- 视图通过 `get_node_or_null("/root/Combat")` 取单例;单例缺失时只显示"(无 Combat 单例)"不崩。

**C. 信号契约(下游订阅点):**
- `Combat.loot_dropped(kind: StringName, rarity: StringName)` — **03 的接口边界**。kind ∈ {`gold`,`material`,`equipment`},
  rarity ∈ {`white`,`blue`,`gold`},金币恒 white。每次敌死恰 0/1 次。物品词条细节归 03,02 不产。
- `Combat.boss_cleared(stage: int)`、`Combat.enemy_defeated(enemy: EnemyDef)`、`Combat.party_wiped`、`Combat.rest_requested`。
- 按钮入口:`Combat.request_push()` / `Combat.request_rest()`(视图按钮已连)。

**D. 数据扩展:** 加敌人/场景/关 = 新建 `.tres`(EnemyDef/SceneConfig/StageConfig),挂进 StageConfig 或 CombatView.stages;无需改代码(D3)。

**E. 敌人贴图(F1 增量,EI Part 2 接线点):**
- `EnemyDef` 现有 `@export var sprite: Texture2D`(分组「外观」)。**EI 在 `stage_01/02.tres` 里展开 `boss`
  与各 `scenes[i].enemy` 内联子资源,给每个 `sprite` 字段拖入对应 PNG**(哥布林=`enemy_goblin.png` …,
  映射见 INTEGRATION-STEPS Part 2-a/b)。敌人一律朝左,**无需 flip**。
- 留空 = 视图回退到红色占位色块(不崩);贴图在位 = 自动按显示高缩放、脚底落地平线显示。
- **FX 贴图无需编辑器接线**:`combat_view.gd` 已 `preload("res://assets/sprites/fx/fx_light_pillar.png")`
  与 `fx_loot_sparkle.png`,运行时 `modulate` 染稀有度色;EI 只需 headless `--import` 确认两张被打包。

## 6. Flags / 待办与风险(滚动 PLAN §5)
- **〔需人工 Play 验,3 处〕** step 7 后台 tick(收起持续推进 + 15fps 一致)、step 8 视图可读性 + 金光不弹 OS 通知、
  step 9 两关闭环。我只能 headless,以上交用户在 Godot 里 Play 验收。
- **〔Art → ✅ F1 已落地〕** 敌人/光柱/星辉占位已换成正式贴图接线(§1 增量);**待 EI INTEGRATION-STEPS Part 2
  给 .tres 拖入各敌人 `sprite` 后**,敌人才显示正式图(未拖前回退占位色块);FX 已直接生效。"瞥一眼可读 /
  金光惊喜感"真手感待 EI Part 2 + 人工 Play 终判。
- **〔需人工 Play 验,F1 增量〕** EI 拖完 .tres 后:敌人正式贴图脚底落地平线、体型差可读(Boss/食人魔更大);
  蓝/金掉落出 `fx_light_pillar` 光柱(蓝染 `#6699ff`/金染 `#ffd24a`)+ 根部 sparkle;金装仍全屏一闪。
- **〔音效/hitstop 占位〕** D9 金装"音效 + 极短停顿"暂缺(无音频素材),v1 只做窗口内一闪;hitstop 留 playtest。
- **〔平衡留 playtest〕** kill-count、各场景/Boss 数值曲线、5s 倒计时、"本轮 = 单敌死亡"粒度,全走 Resource/`@export`,留调。
- **〔提醒〕** Godot exe 实际 `godot.exe`,校验命令照此(INTEGRATION 文档旧名本机不存在)。
