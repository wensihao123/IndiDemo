---
artifact: REVIEW
feature: 00-foundation-redesign
role: Reviewer
status: draft
updated: 2026-06-19
inputs: [PLAN-batch3-s0.md, CHANGES-batch3-s0.md, project-context.md, src/core/meta/player_state.gd, src/core/game_controller.gd, project.godot, test/core/player_state_test.gd, test/core/game_controller_test.gd, (独立重跑) GdUnitCmdTool 全套]
next: Engine Integrator
---

# REVIEW — 步 5 §0:PlayerState 升 autoload(reset-on-boot)前置代码改

> 审 `CHANGES-batch3-s0.md` 落地的 4 步(`PlayerState.reset()` / 附加 `Player` autoload / `_boot` 复用 `/root/Player`+reset-on-boot / 隔离收口)。读了真实代码 + project.godot + 两套测试,**独立重跑全套**核实结果。

## 1. Verdict

**APPROVE WITH NITS — 0 must-fix / 0 should-fix。** 4 步逐条对得上 PLAN,无作用域漂移,无不可逆动作越界。独立重跑全套 **156/156、0 errors/0 failures/0 orphans、exit 0**,与 CHANGES 自报一致。可进 INTEGRATION-STEPS §A(EI/人,不可逆)。仅 2 条信息性 nit,无需动作。

## 2. Must-fix(阻塞)

无。

## 3. Should-fix(非阻塞)

无。

## 4. Nits(信息性,留给人/EI 知会,本批不需动)

- **N1〔测试覆盖拓扑·非缺陷〕`game_controller_test.gd:81 test_reboot_restores_from_save` 对 `reset()` 回归不可证伪。** 现 gc/gc2 共用同一 `/root/Player`:若 `reset()` 退化成 no-op,gc2 仍持 gc 写入的内存态 `roster=[hero]`,该用例**照样绿**(假阴性盲点)。但它对它真正要守的目标(save/load round-trip)**仍可证伪**——若 from_dict/load 坏 → reset 清空后无数据读回 → `roster.size()==0` FAIL。而 `reset()` 本身的正确性由专测 `player_state_test.gd:43 test_reset_clears_all_persistent_state`(独立 `PlayerState.new()`)守住。**两测合计覆盖完整**,故仅记拓扑、不要求加测(守"勿过度",PLAN §3 步 4 亦明示 before_test 防御非必需)。
- **N2〔契约·已在 Wiring Contract 注明〕`game_controller.gd:39 get_node("/root/Player")` 硬失败语义。** 若 `Player` autoload 缺席(如编辑器里单独跑某场景、或 EI 误删该行),`_boot` 取 null → `.reset()` 崩。这是 **PLAN F3 刻意选择**(不加 `get_node_or_null`+`new` 回退,以保共享单例 + reboot 测试忠实),且 CHANGES §5 Wiring Contract 已显式告警"误删 `Player` 或排错序 → 启动崩"。属设计契约非缺陷;EI 接线时遵 PLAN §6 三态表即可。

## 5. What I checked but found fine(覆盖声明)

- **`reset()` 实现(player_state.gd:30-33)**:`roster.clear()`/`bag.clear()`/`materials.clear()` 三者全清,与 reset-on-boot 语义、专测断言一致。
- **`_boot` 改写(game_controller.gd:37-40)**:`get_node("/root/Player") as PlayerState`(`as` 转型避 narrowing→warning-as-error)+ `player_state.reset()`,位置在 save/默认分支(52-58)**之前**,`add_child` 已删。顺序正确:reset 清残留 → load 存档 / 默认 roster 填充。
- **默认分支(58)**:`player_state.roster = get_starting_roster()` 在 reset 之后重填 roster;bag/materials 保持 reset 后的空态(新档应然),无残留。
- **`add_child(player_state)` 移除的影响面**:grep 全 `src/` 的 `player_state` 用法——arena/save_system/loot_intake 全部按**对象引用**消费(`arena.player_state = player_state` 等),无一依赖它是 GC 子节点 / 调 `get_parent()` / 靠 GC 释放。改为 `/root/Player`(autoload,持久在树)后 `material_gained` 信号路径仍成立(Node 进树意图未变,反而更稳)。**无破坏。**
- **`project.godot [autoload]`(20-21)**:`Combat` 行原样保留,**新增** `Player="*res://src/core/meta/player_state.gd"`,**未加 `Game`、未删 `Combat`**——与 PLAN D-C / Out-of-scope 完全一致,不可逆部分未越界。
- **autoload 名合法性**:`grep "class_name Player" src/` 无命中(我复核);`Player` 节点名不撞任何全局类名,规避 D-A 实证的 `hides an autoload singleton`。
- **0 orphans 成因**:`/root/Player` 为引擎托管 autoload,不计 orphan;hero/ItemInstance 为 RefCounted,数组清空即释放。独立重跑确认 0 orphans。
- **独立重跑**:`GdUnitCmdTool -a res://test` → **156/156、0 orphans、exit 0**(155 基线 + 1 新 reset 测),与 CHANGES §3 自报吻合。
- **测试政策符合**:本批纯逻辑/配置,无 UI 验收点;手动 Play 归 EI §F(项目测试政策一致)。
- **约定/hard-NO**:无新插件、无计划外重构(docstring 两行同步属"改到的那段"的事实订正,非 drive-by)、无硬编码数值。守住。
