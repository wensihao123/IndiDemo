---
artifact: REFACTOR
feature: 00-foundation-redesign
role: Arch Guard
status: draft
updated: 2026-06-19
inputs: [ARCHITECTURE.md, REFACTOR-01-foundation-redesign.md, project-context.md, BACKLOG.md, 00-foundation-redesign/INTEGRATION-STEPS.md, 00-foundation-redesign/HANDOFF.md, 00-foundation-redesign/CHANGES-batch3-s1.md, src/core/game_controller.gd, src/core/meta/player_state.gd, src/core/systems/save_system.gd]
next: Planner
---

# REFACTOR-02 — PlayerState 座位决策(持久元状态根 = autoload)

> REFACTOR-01 步 5(层 8 autoload 注册)的一处**座位级架构决策**,由 Engine Integrator 的
> 〔F-Arch-seat〕旗标触发。策略级,不写代码 / 不写文件级步骤——那是 Planner 的 §0 PLAN。
>
> ⚠ **实现修正(2026-06-19 落地后):** 本文多处写的运行时路径 `/root/PlayerState` 与实际不符——
> autoload **节点名取 `Player`**(`PlayerState` 会撞 `class_name` 致注册失败),真实路径 = `/root/Player`
> (`get_node("/root/Player") as PlayerState`)。决策本身(升 autoload + reset-on-boot + 唯一实例)不变,仅命名落地有别。详见 ARCHITECTURE.md §3.2。

## 1. 触发 / Trigger

REFACTOR-01 步 5 要把 `project.godot` 的 autoload 从单 `Combat`(旧 director)换成新系统集。
用户为 〔F-PS-autoload〕拍了**方案 C**:注册 `PlayerState` autoload + 改 `GameController._boot`
复用 `/root/PlayerState`(不再 `PlayerState.new()`/`add_child`)。Engine Integrator 把它升级为
架构分叉上报(〔F-Arch-seat〕):**`Game` 单座(GC 自持 PlayerState,唯一门 `Game.player_state`)
vs 拆座(`PlayerState` 升独立 autoload + per-run 编排座)**,并担心 C 引入"第二条访问路径
(`/root/PlayerState` ‖ `Game.player_state`)+ 全局可达坏味道",请 Arch Guard 定方向 + 写进事实源。

## 2. 现状诊断 / Diagnosis

**这不是新架构,是代码偏离了事实源、现在要不要收回来的问题。**

- **事实源早已是拆座**:`ARCHITECTURE.md §1` 把 `PlayerState(autoload)` 画成「持久元状态层」、
  与「单局战斗层」分立;`§3.2` 明列 `PlayerState | autoload | 持久 roster+背包+材料 = 存档目标`。
  整个 REFACTOR-01 的**根因诊断(§2)就是「项目没有『持久元状态』与『单局战斗模拟』的分层」**——
  PlayerState 正是那个被分出来的持久层根。
- **实现期临时偏离**:batch-3 的 `game_controller.gd:36-37` 落成 `player_state = PlayerState.new();
  add_child(player_state)`——GC **自持** PlayerState(单座)。这是 PLAN D2 把 autoload 注册推迟到
  步 5 + 规避单测 orphan 的**实现期权宜**,不是架构改向(CHANGES-batch3 §4.1 自己标了"建议步 5 再定")。
- **EI 的"坏味道"框定需纠正**:REFACTOR-01 要杀的味道(§2)是 `CombatDirector` **God object**——它把
  ①持久队伍数据 ②单敌运行时 ③进度 FSM ④数值解算 ⑤掉落 ⑥tick 驱动**揉成一坨**。一个**单一职责、
  只装"玩家存档态"**的全局 `PlayerState` autoload **不是这个味道**:它不碰战斗、不驱 tick,是应用级状态根。
  "全局可达"对一个**本就全局唯一**的存档态对象是**正当的**,不是 God object。EI 真正命中的是
  **"双访问路径"约定空缺**——那是约定问题,不是架构问题,钉一条规则即可消解(见 §3)。

**根因(一句):** PlayerState 该不该是 autoload,事实源已答"是";代码因实现期权宜暂时自持。步 5
是把它收回事实源目标的最干净时机(无存档历史、改面最小),拖到 05-town 再收会更贵(见 §6)。

**为何"现在拆"而非"以后再说":** `BACKLOG` 的 **05-town-gear-upgrade 排在 Next**(非 v2),做
手动换装 + 打造强化——这些在**战斗之外**读写 `roster`/`bag`/`materials`。城镇不是 per-run。
若 PlayerState 仍被 per-run 战斗座(`Game`)自持,城镇就只能 `Game.player_state` 反向穿过战斗
编排座去拿持久态——这正是该避免的层次倒置。`player_state.gd:4` 注释本就写明"用 Node 是为日后
进树发跨系统 signal"(已有 `material_gained` 信号),其设计意图就是个可全局监听的 autoload 根。

## 3. 目标形态 / Target shape(delta vs ARCHITECTURE.md)

**采纳方案 C = 拆座**,并钉死两条原先空缺的约定:

| 维度 | 现状(代码) | 目标 |
|------|------------|------|
| `PlayerState` 形态 | GC `new()`+`add_child` 自持(单座) | **autoload**(持久元状态根),与事实源 §1/§3.2 一致 |
| `Game`(GameController)职责 | 既是 per-run 编排座、又"拥有"持久 PlayerState | **per-run 编排 + boot 入口**;**读**全局 `PlayerState`,不"拥有"它 |
| 访问路径约定 | 空缺(EI 担心双路径) | **唯一实例**:`/root/PlayerState` autoload。`Game.player_state` = 指向同一实例的缓存引用(战斗座自用);**非 per-run 消费者(城镇/存档/UI)一律读全局 `PlayerState`,绝不穿过 `Game`** |
| 测试隔离 | GC 自持 → 每个 GC 一份新 PlayerState,天然隔离 | autoload 在测试进程内**持久** → 须 **reset-on-boot**:`_boot` 开头 `player_state.reset()` 清 roster/bag/materials,再 load/默认 roster |

**新增不变量(写入 §4):** 持久元状态的根(`PlayerState`)是 autoload,**任何系统都经全局单例直达,
不经 `Game`**;`Game` 是单局编排座,持有 per-run(arena/progression),**不"拥有"持久态**。

**顺带纠正事实源一处旧错(D4,EI 另一条 F-Arch):** `DataRegistry` 在 `§1/§3.2` 被画成 autoload,
但代码(`game_controller.gd:32`)是 GC 持有的 `RefCounted`(PLAN D4 故意为之:Node-autoload 会让数据层
大量 `DataRegistry.new()` 单测留 orphan)。**本次把事实源改回"`Game` 持有(RefCounted),经 `Game.registry`
可达"**,使文档与代码一致。PlayerState 与 DataRegistry **刻意不对称**——见 §6 的原则与 05 复审点。

## 4. 调整策略 / Strategy(依赖序,= 步 5 §0 的架构骨架,交 Planner 落 PLAN)

> 这是 INTEGRATION-STEPS §0 那处"先决代码改"的架构依据。Planner 据此拆有序可验证步骤;
> 我只定结构动作与序,不写代码。

1. **PlayerState 加 `reset()`**(清 roster/bag/materials)——纯持久层内部方法,先于一切接线;
   独立可测(reset 后三者空)。这步不碰 autoload,不破现有 155 绿。
2. **`_boot` 改读全局 + reset-on-boot**:`player_state = get_node("/root/PlayerState")`(不再 new/add_child)
   → 紧接 `player_state.reset()` → 再 load 存档 / 默认 roster。**注:此步在编辑器注册 autoload 前,
   `/root/PlayerState` 不存在会取空**——故第 1、2 步的代码改与第 3 步的 autoload 注册**必须同批落、
   一次原子**(否则中间态 `_boot` 崩);这正是 INTEGRATION-STEPS 把它列为步 5 不可逆原子步的原因。
3. **测试隔离收口**:依赖 PlayerState 共享单例的用例(`game_controller_test` 写 `gc.player_state.roster`、
   `test_reboot_restores_from_save` 造双 GC)改为靠 **reset-on-boot** 保证每次 `_boot` 从干净态起;
   "重启"语义用 `reset()`+load 表达(比"new 第二个 GC"**更忠实**:证明的是存档文件而非内存残留驱动恢复)。
   全套须回到 **全绿、0 orphans**(155/155 当前基线)才算 §0 达成。
4. **(承 INTEGRATION-STEPS §A)** 编辑器注册 `PlayerState`(在 `Game` 之上,先初始化)+ `Game`;
   `DataRegistry` **不注册**(维持 GC 持有)。此步及其后 §B–§F 在 §0 全绿后由 Engine Integrator/人执行。

## 5. 影响面与迁移 / Blast radius & migration

- **改面极小**:`src/core/meta/player_state.gd`(+`reset()`)、`src/core/game_controller.gd`(`_boot`
  两行 + 配套)、`test/core/game_controller_test.gd`(隔离方式)、`project.godot`(autoload 表)。
- **不动**:战斗层(arena/progression/entity/组件)、掉落、SaveSystem 序列化格式、S1 收口
  (`_sync_party_equipment` 仍按 `party_characters↔arena.players` 同序,roster 来源不变,无影响)、
  45 旧战斗锚、`floating_shell`。
- **存档迁移**:无。`SaveSystem` 落盘的是 `PlayerState.to_dict()`,座位变化不改盘上格式;无存档历史。
- **向后兼容**:`Game.player_state` 字段**保留**(同实例缓存引用),战斗座既有读法不破;新约束只加在
  "非 per-run 消费者走全局"这条**未来**规则上,不回溯改现有战斗码。

## 6. 风险与被否选项 / Risks & rejected alternatives

**风险**
- **reset-on-boot 漏清字段** → 缓解:`reset()` 单测断言 roster/bag/materials 三者全空;`_boot` 后置 load
  覆盖。
- **autoload 初始化序**:`Game._ready/_boot` 读 `/root/PlayerState`,故 **PlayerState 必须排在 Game 之上**
  (INTEGRATION-STEPS §A 已写)。属一次性接线点,EI 清单已覆盖。
- **"双路径"认知负担** → 缓解:钉死"**唯一实例;`Game.player_state` 只是同一对象的缓存;非战斗系统走全局**"
  一条规则(§4 不变量),消除"哪个才是真的"困惑——它们就是同一个对象。

**被否 / 暂缓选项**
- **方案 B(保持 GC 自持 PlayerState,单座)** → **否(本次)**。它现在更省(零代码改、测试天然隔离),
  但 05-town(Next)一来,城镇必经 `Game.player_state` 反穿战斗座取持久态 = 层次倒置,**届时仍要迁 autoload
  + 改全部访问点**。趁步 5 无存档、改面最小时一次收口,比"B 现在 + C 两功能后"更省——与 REFACTOR-01
  "时机最干净"同理。B 的唯一净胜项(测试隔离)被 reset-on-boot 以一处小改抵消。
- **把 `DataRegistry` 也升 autoload(与 PlayerState 对称)** → **暂缓**。原则:**autoload 留给真正全局、
  多消费者、可变/持久或发跨系统信号的根(PlayerState 全占);只读、当前仅战斗座消费的依赖(DataRegistry)
  保持 owned-RefCounted**,经 `Game.registry` 可达,免 Node-orphan 测试摩擦(D4)。
  **复审点(记 §6 张力):** 05-town 打造需在战斗之外读模板(ItemBaseDef/AffixDef)时,DataRegistry 变多
  消费者 → 那时再定"升 autoload(测试自 free)还是注入",**别现在为还没影的 05 提前抽象**(守 hard-NO)。

## 7. 交接 Planner / Handoff

- 把 §4 四步落成 INTEGRATION-STEPS **§0** 的有序可验证 PLAN(`reset()` → `_boot` 改读+reset-on-boot →
  测试隔离收口 → 全套 155 绿 0 orphans),作为编辑器侧 §A–§F 的**前置**。第 2、3 步与编辑器 §A 的 autoload
  注册**同批原子**,PLAN 须显式标注"中途不可 Play / 一次落"。
- **事实源已由本决策更新**:ARCHITECTURE.md §1 数据层标注 / §3.2 DataRegistry 行 + 新增 Game 行 / §4 新增
  不变量 8 / §6 新增 DataRegistry 复审张力。Planner/Implementer 以更新后的事实源为准。
- 不变量交付:**持久根经全局直达、不穿 `Game`;`Game` 不拥有持久态**——05-town 起的所有功能须遵此对照。
