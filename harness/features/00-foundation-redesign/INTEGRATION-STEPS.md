---
artifact: INTEGRATION-STEPS
feature: 00-foundation-redesign
role: Engine Integrator (Godot)
status: draft
updated: 2026-06-19
inputs: [PLAN-batch3.md §3 步5, PLAN-batch3-s0.md §6, CHANGES-batch3.md Wiring Contract §4, CHANGES-batch3-s1.md, CHANGES-batch3-s0.md Wiring Contract §5, REVIEW-batch3-s0.md, project.godot, scenes/shell/floating_shell.tscn, src/core/game_controller.gd, src/core/meta/player_state.gd, src/combat/combat_view.gd]
next: 人(在编辑器执行 §A–§F 并回报;§0 已由 Implementer 交付并经 Reviewer 通过)
---

# INTEGRATION-STEPS — 第三批步 5:不可逆切换 + 全回归 + 手动 Play

> 本步是 REFACTOR-01 唯一不可逆的引擎侧切换:切 autoload `Combat`→`PlayerState`/`Game` + 删旧 director +
> 退役 7 旧测 + 全回归 + 手动 Play。**Godot 4.6.3 / GDScript / Windows。** 一次原子完成(否则 autoload 悬空)。
>
> **执行模型:** §A–§F 是你(人)在 Godot 编辑器里照做、把结果回报给我验收。**§0 已完成(见下),可直接从 §A 起。**

---

## §0 先决条件 ✅ 已完成(Implementer 交付 + Reviewer 通过,无需你做)

> **本节已落地,留作背景。你从 §A 开始。**

原 F-PS-autoload = 方案 C(PlayerState 升 autoload + `_boot` 复用全局单例)的**先决代码改已由 Implementer 完成**
(`CHANGES-batch3-s0.md`),并经 **Reviewer 通过**(`REVIEW-batch3-s0.md`,APPROVE WITH NITS / 0 must / 0 should),
独立重跑全套 **156/156、0 orphans**。已落地三件:
1. `PlayerState.reset()`(清 roster/bag/materials),`_boot` 改 `player_state = get_node("/root/Player") as PlayerState` + `reset()`(删 `add_child`)。
2. **测试隔离**靠 reset-on-boot 收口(`test_reboot_restores_from_save` 走共享单例 + reset 仍绿)。
3. **关键 — `Player` autoload 已注册**:Implementer 在 `project.godot [autoload]` **已附加** `Player="*res://src/core/meta/player_state.gd"`,
   经 `--import` 自验无 `hides an autoload singleton`。

**⚠ 因此 §A 与原计划不同两点(实证修正,见 F1/F2):**
- **autoload 节点名是 `Player`,不是 `PlayerState`。** Godot 4.6.3 禁止 autoload 名 = 全局类名(`player_state.gd` 有 `class_name PlayerState`),
  实证 `--import` 直接报 `Class "PlayerState" hides an autoload singleton`。故节点名用 `Player`(类型仍 `PlayerState`),同 `Game`/`GameController` 先例。
- **`Player` 已经注册好了,§A 不要再加 `Player`** —— 否则二重注册。§A 你只需:删 `Combat`、加 `Game`(排 `Player` 之下)。

---

## §A 切 autoload(Project Settings)

> **接手时 `[autoload]` 现状(§0 后):** `Combat`(第一行) + `Player`(第二行)。你的目标态:`Player`(上) + `Game`(下),无 `Combat`。

Godot 4.6:菜单 **Project → Project Settings…**,选 **Autoload** 选项卡(若你的版本标签是「Globals」,是同一处)。

1. 在 autoload 列表里选中 **`Combat`** 行(指向 `res://src/combat/combat_director.gd`),点列表右上的 **删除(垃圾桶)** 按钮移除它。
   - **不要动 `Player` 行**(已由 §0 注册好,指向 `res://src/core/meta/player_state.gd`)。**不要再新增 `Player`**。
2. 加 **Game**:点 **Path** 旁文件夹图标 → 选 `res://src/core/game_controller.gd`;**Node Name** 填 `Game`;点 **Add**。
3. **顺序关键**:`Player` 必须排在 `Game` **之上**(autoload 按列表自上而下初始化;`Game._boot` 会读 `/root/Player`)。
   删 `Combat` 后 `Player` 在第一行、`Add` 的 `Game` 落到末行 → 顺序天然就是 `Player`(上)、`Game`(下),通常无需调整;
   若不是,选中行用 **上/下箭头** 调成 `Player`(上)、`Game`(下)。
   - **Verify:** autoload 列表**只剩两行**,顺序为 `Player` → `Game`,**没有 `Combat`、没有重复的 `Player`**。两行 Path 无红字(脚本路径有效)。

## §B 删旧 director 源码(FileSystem dock)

5. 在 **FileSystem dock** 展开 `res://src/combat/`,依次右键 → **Delete** 这三个文件:
   - `combat_director.gd`
   - `party_member.gd`
   - `loot_stub.gd`
   - 删除时若 Godot 弹"该文件被引用"警告 → **停下并回报我**(说明还有残留引用,属代码 gap,不要强删)。正常情况下
     `combat_view` 已改读 `/root/Game`、`Combat` autoload 已在 §A 移除,应无引用、可干净删除。
   - **Verify:** `res://src/combat/` 下只剩 `combat_view.gd`、`enemy_def.gd`、`stage_config.gd`、`scene_config.gd`(这四个保留,D8)。

## §C 退役引用旧 director 的旧测试(FileSystem dock)

6. 展开 `res://test/combat/`,右键 → **Delete** 这 **7 个**:
   - `combat_director_test.gd`、`formula_test.gd`、`progression_test.gd`、`retreat_test.gd`、
     `button_countdown_test.gd`、`tick_driver_test.gd`、`loot_test.gd`
   - **保留 `stage_config_test.gd`**(只测 StageConfig,不引用 director,继续绿)。
   - **Verify:** `res://test/combat/` 下只剩 `stage_config_test.gd`。

## §D 重导入(注册 `Game` autoload + 删档后的 class 表刷新)

7. 让我替你跑无头导入与全回归(你不必手动):你完成 §A–§C 后**回报"删改完成"**,我执行
   `godot --headless --import` + `-a res://test`。
   - 或你自己在终端跑:`"G:/Godot/Godot_v4.6.3/godot.exe" --headless --import`(注册 `Game` autoload、刷新删档后的 class 表)。
   - 注:`--import` 跑完可能遗留一个编辑器态 godot 进程占内存/锁文件(§0 已遇),若随后命令报文件忙 → 先在任务管理器结束残留 `godot.exe` 再重跑。

## §E 全回归(命令行,期望全绿)

8. 跑全套:`"G:/Godot/Godot_v4.6.3/godot.exe" --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test`
   - **期望:** `test/core/*`(含步1-3新增 + S1 + §0 的 reset 测)+ `test/core/combat/*`(56)+ `test/combat/stage_config_test.gd`,
     **0 errors / 0 failures / 0 orphans / exit 0**。**§0 后切换前基线 = 156**;删 director + 退役 7 旧测后总数 = 156 − 退役 7 旧测的用例数(由实际数为准)。
   - **若有红 / orphan / 编译错 → 回报我**(常见:某退役测漏删;或 `Game`/`Player` autoload 顺序错 → `_boot` 取空 `/root/Player`)。

## §F 手动 Play(floating_shell.tscn — 唯一肉眼验收)

> `scenes/shell/floating_shell.tscn` 的 `MainArea/CombatView` 节点脚本 = `res://src/combat/combat_view.gd`,且
> `stages = [stage_01.tres, stage_02.tres]` **已在场景里指派好**(无需你再拖)。直接 Play 主场景即可。

9. 按 **F5(Play)** 运行主场景。逐项观察并回报(截图最好):
   - [ ] 战斗自动跑(无需点按钮);敌人占位符号 + 队伍第 0 格(战士)血条/名字「战士」正确显示。
   - [ ] 命中飘伤害字;暴击有区分;闪避显示 MISS。
   - [ ] 敌血条随击打下降;击杀后推进到下一场景/敌人。
   - [ ] **推进/修整按钮**:GRINDING 态可点推进;修整进 RESTING 占位;通关倒计时自动推进。
   - [ ] 掉落 FX 按稀有度:白/蓝光柱 + 金色金闪;战斗日志显示去向(穿上/分解/进包)。
   - [ ] Boss 通关横幅;团灭 → 回退刷怪恢复。
10. **存档 round-trip(挂机刚需)**:
   - [ ] 打到 Boss 通关后**关掉程序**(触发 `WM_CLOSE_REQUEST` autosave;或自然 boss_cleared 已存)。
   - [ ] 确认 `user://savegame.json` 已生成(路径:`%APPDATA%\Godot\app_userdata\Test2\savegame.json`)。
   - [ ] **重开程序** → 进度续到已解锁关(`max_unlocked_stage` 不归零),roster 仍在。
   - [ ] **(验 S1)** 若战斗中战士空槽自动穿到过装备:重开后该装备仍在战士身上(掉装持久化未丢)。

## Run & expected behavior(总）

完成态 = §E 全套绿(0 orphans)+ §F 清单逐项 OK + 存档重开续档肉眼确认。此时重构在新地基上端到端跑通:
表现层读 `Game.arena`/`Game.progression`、`GameController` 装配驱动一局、`SaveSystem` 落盘 `PlayerState`+进度,
旧 `Combat` director 彻底退场。

## Flags

- **〔F-PS-autoload-code〕✅ 已解决(§0 完成)** 方案 C 的 `_boot` 改 + 测试隔离 + `Player` autoload 注册已由 Implementer 落地、
  Reviewer 通过(156/156、0 orphans)。**§A 不再 blocking,可直接执行。** 唯一遗留:节点名是 `Player`(非 `PlayerState`),`Player` 已注册勿重加(F1/F2,已并入 §0/§A)。
- **〔F1 文档措辞回写,非阻塞〕** `ARCHITECTURE.md §1/§3.2/§4-不变量8`、`arch/REFACTOR-02`、本文旧版均写"PlayerState autoload / Node Name 填 PlayerState",
  与实证不符 → 应改"autoload 节点 `Player`,类型 `PlayerState`"。本文 §0/§A 已更正;ARCHITECTURE/REFACTOR-02 待 Arch Guard 顺手回写(代码已按 `Player` 跑,文档滞后不影响运行)。
- **〔F-Cutover〕** 本步不可逆。回退手段:`project.godot` autoload 改回 `Combat=...` + 删掉 `Game` 行(`Player` 行保留,§0 已并入基线);
  用版本控制还原本次 commit 即可。删文件前确保已提交,便于 `git checkout` 找回。**建议执行前先 commit 当前 §0 绿状态(156/156)。**
- **〔F-Arch〕** D4:`DataRegistry` 不注册 autoload、由 `Game` 持有(经 `Game.registry` 可达)。**待 Arch Guard 回写
  ARCHITECTURE §3.2**(非阻塞本步)。
- **〔F-Producer〕** 切换后新增 autoload `PlayerState`/`Game` + 新文件 → 提示 Producer 更新 project-context §2 目录约定
  与 v1 完成定义(装配/存档已就位)。非本步落地项。
- **场景假设:** 我据 `floating_shell.tscn` 文本确认了 `CombatView` 脚本路径与 `stages` 指派(第 41/48/49 行)。
  若你在编辑器里看到 `CombatView` 的 Inspector `Stages` 为空(红/0 项),**回报我** —— 不应发生,但若发生需重新拖
  `stage_01.tres`/`stage_02.tres` 进 `Stages` 数组。
