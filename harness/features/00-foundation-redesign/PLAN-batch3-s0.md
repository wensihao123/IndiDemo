---
artifact: PLAN
feature: 00-foundation-redesign
role: Planner
status: draft
updated: 2026-06-19
inputs: [arch/REFACTOR-02-playerstate-seat.md, ARCHITECTURE.md, project-context.md, INTEGRATION-STEPS.md, src/core/game_controller.gd, src/core/meta/player_state.gd, src/core/systems/save_system.gd, test/core/game_controller_test.gd, project.godot, (empirical) godot 4.6.3 autoload/class_name 冲突探针]
next: Implementer
---

# PLAN — 步 5 §0:PlayerState 升 autoload(reset-on-boot)前置代码改

> 把 `arch/REFACTOR-02-playerstate-seat.md §4` 落成有序可验证步骤。**这是 INTEGRATION-STEPS §0 的实体 PLAN**:
> Implementer 自交付(代码 + 全套绿),**§0 全绿后**才轮到 Engine Integrator/人做 §A–§F 的不可逆编辑器切换。

## 1. Goal

把 `GameController` 自持的 `PlayerState` 改为复用全局 autoload 单例(reset-on-boot 保测试隔离),让持久根可被非战斗系统全局直达,且全套回到 155/155、0 orphans——作为步 5 编辑器切换的先决。

## 2. Approach & key decisions

- **D-A〔关键·已实证〕autoload 节点名 = `Player`(类型仍 `PlayerState`),不是 `PlayerState`。**
  - What:注册的 autoload **Node Name 用 `Player`**,Path 指 `res://src/core/meta/player_state.gd`;脚本保留 `class_name PlayerState` 作类型。
  - Why:`player_state.gd` 有 `class_name PlayerState`,而 Godot 4.6.3 **禁止 autoload 名与全局类名同名**。我在隔离临时工程实证:autoload 名填 `PlayerState` → `--import` 直接报 `Parse Error: Class "PlayerState" hides an autoload singleton. Failed to create an autoload`。本项目既有 `Game`(类型 `GameController`)即同款"节点名 ≠ 类名"先例,沿用之。
  - 否决:① 改 autoload 名为 `PlayerState` —— 实证编译失败。② 删 `class_name PlayerState` 改 autoload 名 `PlayerState` —— 会令 `var player_state: PlayerState`/`SaveSystem` 三处签名/`arena.player_state`/测试的类型注解全失效,改面过大,否。
- **D-B reset-on-boot:`PlayerState` 加 `reset()`,`_boot` 取单例后**先 `reset()` 再 load/默认 roster。**
  - What:`reset()` 清 `roster`/`bag`/`materials` 三者;`_boot` 在 save/默认分支**之前**调用。
  - Why:autoload 在测试进程内**持久**,跨用例会串状态;`test_reboot_restores_from_save` 造 gc+gc2 现共用同一 `/root/Player`,无 reset 则 gc2 会带着 gc 的内存态、"读档恢复"退化成假绿。reset-on-boot 让每次 boot 从干净态起;重启语义 = reset+load(证**存档文件**而非内存残留驱动恢复,比"new 第二个 GC"更忠实)。注:`SaveSystem.apply→from_dict` 虽已 clear 三者(load 分支),但**默认分支**只 `roster = get_starting_roster()`、不清 bag/材料 → 必须显式 reset 兜全。
  - 否决:每个测试 `before_test` 手动清 `/root/Player` 而 `_boot` 不 reset —— 把隔离责任散到测试、运行期 boot 仍可能带脏态,不如收口在 `_boot`。(可留 `before_test` 清理作**附加**防御,见步 4。)
- **D-C §0 内只做"加 `Player` autoload"这一**附加、可逆**的 project.godot 改;`Combat`→`Game` 切换 + 删档 + 退役测试仍归 EI(§A–§C 不可逆)。**
  - What:Implementer 在 `project.godot [autoload]` **新增** `Player="*res://src/core/meta/player_state.gd"`,**不删 `Combat`、不加 `Game`、不删任何文件**。
  - Why:`_boot` 读 `/root/Player` 必须有该 autoload 在场才能测绿;附加一行 autoload 是可逆文本改(删行即还原),由 Implementer 经 `--headless --import` + 全套绿自验,属自交付范畴。真正不可逆的部分(摘 `Combat`、加 `Game`、删 director/party_member/loot_stub、退役 7 旧测)保留给 EI 的 §A–§C。这样 §0 有独立绿检查点,且不抢 EI 的不可逆领地。**这会重切 INTEGRATION-STEPS §A,见 Flag F2。**
  - 否决:§0 完全不碰 project.godot、把代码改 + autoload 注册 + 删档揉成一次 EI 原子切换 —— §0 无法独立测绿,丢掉"先验证 §0 再动不可逆"的安全网,否。
- **D-D `DataRegistry` 维持 `Game` 持有(RefCounted),本步不动。** 承 REFACTOR-02:autoload 只给真正全局/多消费/可变持久的根(PlayerState);只读单消费依赖保持 owned,免 Node-orphan 测试摩擦。05-town 需战斗外读模板时再复审。

## 3. Ordered steps

> 每步落地后全套须保持绿;2、3 步逻辑耦合(步 3 读 `/root/Player` 须步 2 已注册),但按下序每步均可独立验证。

1. **给 `PlayerState` 加 `reset()`。**
   - Files:`src/core/meta/player_state.gd`(新增方法:`roster.clear()` / `bag.clear()` / `materials.clear()`)。
   - Verify:`test/core/meta/player_state_test.gd`(无则新建)加一例——填入 roster/bag/材料各 ≥1 项后调 `reset()`,断言三者均空;跑该套件绿。`_boot` 暂未调用它,全套仍 155/155、0 orphans。

2. **在 `project.godot` 附加注册 `Player` autoload(不动 `Combat`/不加 `Game`)。**
   - Files:`project.godot` `[autoload]` 增 `Player="*res://src/core/meta/player_state.gd"`。
   - 前置确认:`grep class_name Player`(全 `src/`)**无命中**——确保节点名 `Player` 不与任何全局类名冲突(`Character`/`Entity` 等都不叫 `Player`)。
   - Verify:`"G:/Godot/Godot_v4.6.3/godot.exe" --headless --import` **无** `hides an autoload singleton` 报错(证 `Player` 节点名合法);全套绿、0 orphans(此时 `_boot` 仍 `PlayerState.new()`,`/root/Player` 空转无害、引擎托管不计 orphan)。

3. **改 `_boot` 复用单例 + reset-on-boot。**
   - Files:`src/core/game_controller.gd`。把第 36-37 行 `player_state = PlayerState.new()` / `add_child(player_state)` 换成 `player_state = get_node("/root/Player") as PlayerState`(用 `as` 转型避免 narrowing 警告→warning-as-error),紧接 `player_state.reset()`;**删掉 `add_child`**。位置须在 save/默认分支(原 49-55 行)**之前**。
   - Verify:全套 155/155、0 orphans;`game_controller_test` 6/6,尤其 `test_reboot_restores_from_save`(现走共享 `/root/Player`+reset)与两条 S1 用例仍绿。**首验关口:确认 gdUnit CmdTool headless 跑时 `/root/Player` 确有实例**(若为 null → 测试立即报错 → 按 Flag F3 上报,**不要**擅自加 `get_node_or_null`+`new` 回退,那会破坏共享单例语义)。

4. **测试隔离收口 + 全回归。**
   - Files:`test/core/game_controller_test.gd`(及任何 boot 后留脏 `/root/Player` 的套件)。
   - Action:主隔离靠步 3 的 reset-on-boot;若实测有跨用例串状态,加 `before_test` 调 `get_node("/root/Player").reset()` 作附加防御(非必需则不加,守"勿过度")。确认 `test_reboot_restores_from_save` 仍**可证伪**(它断言 reset 清内存后 roster 由存档文件读回)。
   - Verify:全套 **155/155、0 orphans**;连跑两次稳定(无顺序依赖);`--headless --import` 干净。**此即 §0 达成**——回报用户/EI 进 INTEGRATION-STEPS §A。

## 4. Out of scope

- **步 5 不可逆切换本身**:摘 `Combat` autoload、加 `Game` autoload、删 `combat_director.gd`/`party_member.gd`/`loot_stub.gd`、退役 7 个旧 `test/combat/*`、手动 Play(§F)——全留 Engine Integrator/人,§0 全绿后做。
- **`DataRegistry` 升 autoload**(维持 owned,05-town 再议)。
- **存档格式 / 战斗逻辑 / 掉落 / S1 收口**任何改动(`_sync_party_equipment` 不动:其 roster 来源不变)。
- `Game.player_state` 字段不删(保留为同实例缓存引用)。

## 5. Risks & Flags / Open questions

- **F1〔已决·2026-06-19 用户采纳 `Player`〕autoload 节点名 = `Player`(类型 `PlayerState`),非 `PlayerState`。** 实证:`PlayerState` 名注册即编译失败(见 D-A)。**用户已拍:采纳 `Player`**(与 `Game`/`GameController` 同构)。**影响事实源措辞(待回写)**:`ARCHITECTURE.md §1/§3.2/§4-不变量8`、`REFACTOR-02`、`INTEGRATION-STEPS §A`("Node Name 填 `PlayerState`")均写的是"PlayerState autoload",须改成"autoload 节点 `Player`,类型 `PlayerState`"——由 Arch Guard 顺手回写或 EI 据本 PLAN 改 §A 措辞。备选名 `Meta`/`PlayerStateRoot` 已弃。
- **F2〔已决·2026-06-19 用户采纳拆法〕§0 含一处 Implementer 做的附加 autoload 注册;EI 不可重复添加。** 用户已拍:**就按拆法**——**附加、可逆**的 `Player` 注册由 Implementer 在 §0 前移(经 `--import` 自验),**不可逆**的 `Combat`→`Game` 切换 + 删档留 EI。**详见下方 §6「给 Engine Integrator 的明确交接」——EI 务必先读,避免二重注册 `Player`。**
- **F3〔风险·步 3 首验关口〕`_boot` 读 `/root/Player` 依赖 autoload 在 gdUnit CmdTool headless 下在场。** 本 session 既往确认"headless 测试跑会注册 autoload";步 3 verify 直接验。若实测 `/root/Player` 为 null → **上报**,不擅自加 `new` 回退(破坏共享单例 + reboot 测试语义)。
- **F4〔接线顺序·EI〕** `Game._boot` 在 autoload 初始化期读 `/root/Player` → `Game` 必须排在 `Player` **之下**(INTEGRATION-STEPS §A 已注,重申)。`Player` 与 `Game` 顺序:`Player`(上)→ `Game`(下)。

## 6. 给 Engine Integrator 的明确交接(避免二重注册 `Player`)

> 用户 2026-06-19 拍板"就按拆法"。**EI 进 INTEGRATION-STEPS §A 前务必先读本节**:`Player` autoload **已由 Implementer 在 §0 注册**,**EI 不要再加 `Player`**,只做不可逆的 `Combat`→`Game` 部分。

**autoload 表的三态演进(看清你接手时它已是什么样):**

| 阶段 | 执行者 | `[autoload]` 内容 | 备注 |
|------|--------|-------------------|------|
| §0 之前(现状) | — | `Combat="*…/combat_director.gd"` | batch-3 并存态,旧 director 仍在 |
| **§0 之后(EI 接手时)** | **Implementer** | `Combat=…` **+ `Player="*res://src/core/meta/player_state.gd"`** | `Player` **已在**,Implementer 经 `--import` + 全套 155/0 自验过;`Game` 尚未加 |
| §A 之后(目标态) | **EI** | `Player="*res://…/player_state.gd"`(上)→ `Game="*res://…/game_controller.gd"`(下) | EI 摘 `Combat`、加 `Game`、校验顺序 |

**EI 在 §A 实际要做的 = 仅以下三动作(`Player` 行原样保留,勿动勿重加):**
1. **删** `Combat="*…/combat_director.gd"` 这一行。
2. **加** `Game="*res://src/core/game_controller.gd"`,且排在 `Player` **之下**(F4:`Game._boot` 初始化期读 `/root/Player`,Player 须先初始化)。
3. **校验**最终 `[autoload]` = `Player`(上)+ `Game`(下)两行,无 `Combat`、无重复 `Player`;`--import` 无 `hides an autoload singleton` 报错。

**对 INTEGRATION-STEPS §A 文本的影响(EI 自行回写其 owned 文档):** 原 §A 写"删 `Combat`、加 `PlayerState`↑`Game`↓"——须改成"**`Player` 已由 §0 注册**;§A 只删 `Combat` + 在 `Player` 下加 `Game` + 校验顺序"。节点名 `PlayerState`→`Player`(F1)。§B(删 3 src)/§C(退役 7 旧测)/§D–§F 不受影响,照旧。
