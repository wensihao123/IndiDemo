---
artifact: CHANGES
feature: 00-foundation-redesign
role: Implementer
status: draft
updated: 2026-06-19
inputs: [PLAN-batch3-s0.md, ARCHITECTURE.md, arch/REFACTOR-02-playerstate-seat.md, project-context.md, src/core/meta/player_state.gd, src/core/game_controller.gd, test/core/game_controller_test.gd, test/core/player_state_test.gd, project.godot]
next: Engine Integrator
---

# CHANGES — 步 5 §0:PlayerState 升 autoload(reset-on-boot)前置代码改

> 落地 `PLAN-batch3-s0.md` 的 4 步:`PlayerState.reset()` → 附加注册 `Player` autoload →
> `_boot` 复用 `/root/Player`+reset-on-boot → 测试隔离收口。全套 **156/156、0 orphans**(155 基线 + 1 新 reset 测)。
> **不可逆的 `Combat`→`Game` 切换 + 删档 + 退役旧测仍归 Engine Integrator**(§0 Out of scope,见 PLAN §4/§6)。

## 1. What changed(每文件一行)

- `src/core/meta/player_state.gd` — 新增 `reset()`:`roster.clear()` / `bag.clear()` / `materials.clear()`(+ 一行 why 注释)。
- `project.godot` — `[autoload]` **附加** `Player="*res://src/core/meta/player_state.gd"`(`Combat` 行原样保留,**未加 `Game`**)。
- `src/core/game_controller.gd` — `_boot`:`player_state = PlayerState.new()` / `add_child(player_state)` 改为
  `player_state = get_node("/root/Player") as PlayerState` + `player_state.reset()`(删 `add_child`,位置仍在 save/默认分支前);
  顺带更新类头 docstring 两行使其与新座位一致(不自持、Combat→Game 切换留步 5)。
- `test/core/player_state_test.gd` — 新增 `test_reset_clears_all_persistent_state`:填 roster/bag/材料各 1 项 → `reset()` → 断言三者 size==0。

## 2. Why(映射 PLAN 步号)

- **步 1**:`player_state.gd` 加 `reset()` + `player_state_test.gd` 加 reset 用例。(PLAN §3 步 1 / D-B)
- **步 2**:`project.godot` 附加 `Player` autoload(节点名 `Player`、类型 `PlayerState`,避 `class_name PlayerState` 冲突)。(PLAN §3 步 2 / D-A / F1)
- **步 3**:`game_controller.gd` `_boot` 改读 `/root/Player` + reset-on-boot。(PLAN §3 步 3 / D-B)
- **步 4**:测试隔离收口——reset-on-boot 已足,未加 `before_test` 防御(守"勿过度",PLAN §3 步 4)。(PLAN §3 步 4)

## 3. How I verified it(命令 + 结果)

1. **步 1**:全套 `GdUnitCmdTool -a res://test` → **156/156、0 errors/0 failures/0 orphans、exit 0**(155 基线 + 1 新 reset 测)。
2. **步 2 前置**:`grep "class_name Player" src/`(全 `src/`)→ **无命中**(节点名 `Player` 不撞任何全局类名)。
3. **步 2**:`godot --headless --import` → **无** `hides an autoload singleton` / `Failed to create an autoload` / `Parse Error`(输出 `IMPORT_CLEAN`);全套 **156/156、0 orphans、exit 0**(`_boot` 此时仍 `PlayerState.new()`,`/root/Player` 空转无害)。
   - 注:`--import` headless 跑完会遗留一个 ~900MB godot 进程(编辑器态残留),已 `taskkill` 清掉再跑测试,避免文件锁。
4. **步 3**:`--check-only src/core/game_controller.gd` → `CHECK_CLEAN`(无 error/warning,守 warning-as-error);
   `game_controller_test.gd` 单跑 → **6/6、0 orphans、exit 0**(**F3 首验关口达成:`/root/Player` 在 gdUnit CmdTool headless 下确有实例**,`test_reboot_restores_from_save` 走共享单例 + reset 仍绿)。
5. **步 4**:全套**连跑两次** → 两次均 **156/156、0 orphans、exit 0**(无顺序依赖/无串状态);最终 `--import` → `IMPORT_CLEAN`。
   - 标准流程第 3 步(手动 Play)**本批不适用**:§0 不切 autoload(仍 `Combat`+`Player`,`Game` 未注),工程处中间态不可 Play——Play 验收归 EI §F(项目测试政策:纯逻辑单测,UI/演出手测)。

## 4. Deviations from the plan(偏差)

- **无语义偏差。** 一处计划外的**附带文档同步**:`game_controller.gd` 类头 docstring 两行原写"持有…PlayerState"/"autoload 注册留步 5",
  改 `_boot` 后已成事实错误(PlayerState 不再自持、`Player` autoload 已注),故就地更新为"读全局 `/root/Player` 不自持"/"Combat→Game 切换留步 5"。
  仅触及我本就在改的那段所描述的行为,非 drive-by 重构。

## 5. Wiring Contract — 给 Engine Integrator 的桥(**务必读 PLAN-batch3-s0.md §6**)

> **关键:`Player` autoload 已由本批(§0)注册完毕并经 `--import`+156/0 自验。EI 切勿重复添加 `Player`。**

**autoload 表当前态(EI 接手时):**
```
[autoload]
Combat="*res://src/combat/combat_director.gd"
Player="*res://src/core/meta/player_state.gd"   ← 本批新增,已就位,勿重加
```

**EI 在 INTEGRATION-STEPS §A 实际只需做(`Player` 行原样保留):**
1. **删** `Combat="*res://src/combat/combat_director.gd"`。
2. **加** `Game="*res://src/core/game_controller.gd"`,排在 `Player` **之下**(`Game._boot` 初始化期读 `/root/Player`,Player 须先初始化 → 顺序 `Player`↑ `Game`↓)。
3. **校验**最终 `[autoload]` = `Player`(上)+ `Game`(下)两行,无 `Combat`、无重复 `Player`;`--import` 无 `hides an autoload singleton`。

**节点/类型约定:**
- autoload 节点名 **`Player`**(非 `PlayerState`),脚本 `res://src/core/meta/player_state.gd`(`class_name PlayerState` 作类型)。**Godot 4.6.3 禁止 autoload 名 = 全局类名**(实证 `--import` 报 `hides an autoload singleton`),故同 `Game`/`GameController` 先例用"节点名≠类名"。
- `GameController._boot` 现 `get_node("/root/Player") as PlayerState`——**强依赖 `Player` autoload 在场且排在 `Game` 之上**。若 EI 误删 `Player` 或排错序 → `_boot` 取空 → 启动崩。
- 本批**未**注册 `Game`、**未**改 `DataRegistry`(仍 GC 持有 RefCounted,D-D)、**未**删任何 src、**未**退役任何测试。

**信号/导出字段:** 本批无新 `@export`、无新信号、无新 input-map/group/collision 依赖。`PlayerState.reset()` 是纯内部方法,无接线点。

## 6. Flags / Open questions

- **F1〔待回写文档,非阻塞本批〕** autoload 节点名实证只能用 `Player`(非 `PlayerState`)。`ARCHITECTURE.md §1/§3.2/§4-不变量8`、`arch/REFACTOR-02`、`INTEGRATION-STEPS §A` 里"PlayerState autoload / Node Name 填 PlayerState"措辞与代码不符 → 待 Arch Guard 回写事实源 / EI 回写其 owned §A(改为"autoload 节点 `Player`,类型 `PlayerState`")。代码已按 `Player` 落地,文档措辞滞后不影响运行。
- **F2〔已闭环〕** §0 的附加 `Player` 注册已落 + EI 交接已写清(本 §5 + PLAN §6),EI 不会二重注册。
- **无新 blocking flag。** §0 达成,可进 INTEGRATION-STEPS §A(EI/人,不可逆)。
