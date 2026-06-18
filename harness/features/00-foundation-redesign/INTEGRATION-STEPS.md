---
artifact: INTEGRATION-STEPS
feature: 00-foundation-redesign
role: Engine Integrator (Godot)
status: draft
updated: 2026-06-19
inputs: [PLAN-batch3.md §3 步5, CHANGES-batch3.md Wiring Contract §4, CHANGES-batch3-s1.md, project.godot, scenes/shell/floating_shell.tscn, src/core/game_controller.gd, src/core/meta/player_state.gd, src/combat/combat_view.gd]
next: Implementer(先做 §0 _boot 代码改)→ 人(在编辑器执行 §A–§F 并回报)
---

# INTEGRATION-STEPS — 第三批步 5:不可逆切换 + 全回归 + 手动 Play

> 本步是 REFACTOR-01 唯一不可逆的引擎侧切换:切 autoload `Combat`→`PlayerState`/`Game` + 删旧 director +
> 退役 7 旧测 + 全回归 + 手动 Play。**Godot 4.6.3 / GDScript / Windows。** 一次原子完成(否则 autoload 悬空)。
>
> **执行模型:** §A–§F 是你(人)在 Godot 编辑器里照做、把结果回报给我验收。**但 §0 是先决代码改(Implementer 做),
> 未绿之前不要动编辑器任何一步。**

---

## §0 先决条件(BLOCKING · Implementer 代码改,不是编辑器步)

你拍了 F-PS-autoload = **「注册 PlayerState autoload + 改 `_boot` 复用 `/root/PlayerState`」**。这要求一处
`GameController._boot` 代码改,**超出我(Engine Integrator)职责 → 路由回 Implementer**。在它落地并全套重新绿之前,
**§A 之后的编辑器步一律不要执行**(否则 `Game` autoload 在 `_ready` 里 `PlayerState.new()` 与 `/root/PlayerState`
双实例,且测试隔离会坏)。

交 Implementer 的契约要求(由 Implementer/Planner 设计具体实现,我只列约束):
1. `src/core/game_controller.gd::_boot` 不再 `player_state = PlayerState.new(); add_child(player_state)`,
   改为取全局单例 `player_state = get_node("/root/PlayerState")`(autoload 已在树,**不要再 add_child**)。
2. **测试隔离**:现有 `test/core/game_controller_test.gd` 等在 `_boot` 后直接 `gc.player_state.roster = [...]`。
   若 `gc.player_state` 变成共享 autoload 单例,用例间会串状态,且 `test_reboot_restores_from_save`(造 gc + gc2
   两个 GameController 模拟重启)会让两者共用同一 PlayerState、"全新重启"语义失真。Implementer 须解决(如 `_boot`
   开头 reset PlayerState 的 roster/bag/materials,或测试在 `before_test` 清空 `/root/PlayerState`)。
3. 重跑全套 `-a res://test` 须回到 **全绿、0 orphans**(当前 155/155)才算先决达成。

> 注:若回头嫌该路径动测试成本高,可改回"只注 Game、不注 PlayerState"方案(Implementer/Reviewer 原推荐,零代码改)。
> 但既已拍 C,以上为 C 的落地前提。**§0 未绿 → STOP,先开 `/role-implementer 00-foundation-redesign`。**

---

## §A 切 autoload(Project Settings;§0 绿后才做)

Godot 4.6:菜单 **Project → Project Settings…**,选 **Autoload** 选项卡(若你的版本标签是「Globals」,是同一处)。

1. 在 autoload 列表里选中 **`Combat`** 行(指向 `res://src/combat/combat_director.gd`),点列表右上的 **删除(垃圾桶)** 按钮移除它。
2. 加 **PlayerState**:点 **Path** 旁文件夹图标 → 选 `res://src/core/meta/player_state.gd`;**Node Name** 填 `PlayerState`;点 **Add**。
3. 加 **Game**:同样选 `res://src/core/game_controller.gd`;**Node Name** 填 `Game`;点 **Add**。
4. **顺序关键**:`PlayerState` 必须排在 `Game` **之上**(autoload 按列表自上而下初始化;`Game._ready` 会读 `/root/PlayerState`)。
   选中行用 **上/下箭头** 调成:`PlayerState`(上)、`Game`(下)。
   - **Verify:** autoload 列表只剩两行,顺序为 `PlayerState` → `Game`,**没有 `Combat`**。两行 Path 无红字(脚本路径有效)。

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

## §D 重导入 / 注册新 autoload 与 class

7. 让我替你跑无头导入与全回归(你不必手动):你完成 §A–§C 后**回报"删改完成"**,我执行
   `godot --headless --import` + `-a res://test`。
   - 或你自己在终端跑:`"G:/Godot/Godot_v4.6.3/godot.exe" --headless --import`(注册新 autoload/class)。

## §E 全回归(命令行,期望全绿)

8. 跑全套:`"G:/Godot/Godot_v4.6.3/godot.exe" --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test`
   - **期望:** `test/core/*`(含步1-3新增 + S1)+ `test/core/combat/*`(56)+ `test/combat/stage_config_test.gd`,
     **0 errors / 0 failures / 0 orphans / exit 0**。删 director 后总数 = 155 − 退役7旧测的用例数(由实际数为准)。
   - **若有红 / orphan / 编译错 → 回报我**(常见:某退役测漏删、或 §0 未落导致 PlayerState 双实例)。

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

- **〔F-PS-autoload-code〕(BLOCKING,已路由 Implementer)** 你拍的方案 C 需 `_boot` 复用 `/root/PlayerState` +
  修测试隔离(§0)。这是代码改,超 EI 职责。**§A 起的编辑器步必须等 §0 全套绿后才执行。**
- **〔F-Cutover〕** 本步不可逆。回退手段:`project.godot` autoload 改回 `Combat=...`(用版本控制还原本次 commit 即可);
  删文件前确保已提交,便于 `git checkout` 找回。建议执行前先 commit 当前绿状态。
- **〔F-Arch〕** D4:`DataRegistry` 不注册 autoload、由 `Game` 持有(经 `Game.registry` 可达)。**待 Arch Guard 回写
  ARCHITECTURE §3.2**(非阻塞本步)。
- **〔F-Producer〕** 切换后新增 autoload `PlayerState`/`Game` + 新文件 → 提示 Producer 更新 project-context §2 目录约定
  与 v1 完成定义(装配/存档已就位)。非本步落地项。
- **场景假设:** 我据 `floating_shell.tscn` 文本确认了 `CombatView` 脚本路径与 `stages` 指派(第 41/48/49 行)。
  若你在编辑器里看到 `CombatView` 的 Inspector `Stages` 为空(红/0 项),**回报我** —— 不应发生,但若发生需重新拖
  `stage_01.tres`/`stage_02.tres` 进 `Stages` 数组。
