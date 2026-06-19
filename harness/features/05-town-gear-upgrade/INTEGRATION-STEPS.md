---
artifact: INTEGRATION-STEPS
feature: 05-town-gear-upgrade
role: Engine Integrator
status: draft
updated: 2026-06-19
inputs: [CHANGES.md (§4 Wiring Contract), project-context.md, style-basic-2d.md, scenes/shell/floating_shell.tscn, src/combat/town_view.gd]
next: 人类验收(照做并回报) → 通过后 Art Spec(juice)
---

# INTEGRATION-STEPS — 05 城镇:把 TownView 挂进悬浮窗

整合目标:把 `TownView` 挂进 `floating_shell.tscn` 的 `MainArea`,让"进城/出城"可手动验收。
**逻辑零改动**,只接一个节点 —— `TownView._ready` 会自建全部子节点、自己找 `/root/Game` 和同级
`CombatView`、自己建"进城/出城"按钮并接好信号。**无 @export 要填、无信号要手连、无素材要导入。**

> 前置事实(EI 已核对当前场景):`MainArea`(Control,800×250)下现有 `Hero`(Sprite2D)+
> `CombatView`(Control,anchors_preset=15,挂 combat_view.gd,持 stages → 它 `_ready` 里调
> `Game.begin_run` 开局)。本次只在其后**追加一个** `TownView` 兄弟节点。

---

## A. 刷新类缓存(新 class_name,必做一次)

本功能新增了两个全局类 `EnhanceConfigDef`、`TownView`。直接在 Scene dock 加节点前,Godot 的全局
类缓存需先认得它们,否则可能报"找不到类型 TownView"。

1. **若你在编辑器外**:先在项目根跑一次无头导入刷新缓存(PowerShell):
   ```
   & "G:/Godot/Godot_v4.6.3/godot.exe" --headless --import
   ```
   - Verify:命令结束无 "Could not find type" / parse error 输出。
2. **若你直接开编辑器**:打开 `test-2` 项目,等左下角导入进度条跑完即可(编辑器会自动 reimport)。
   - Verify:FileSystem dock 里 `src/combat/town_view.gd`、`src/core/data/enhance_config_def.gd`
     图标正常(不是红色报错图标)。

---

## B. 加 TownView 节点(Scene dock)

3. 打开场景 `res://scenes/shell/floating_shell.tscn`(FileSystem dock 双击)。
4. 在 Scene dock 里**选中 `MainArea`** 节点。
5. 点 Scene dock 顶部的 **`+`(Add Child Node)**,搜索并选 **`Control`**,Create。
6. 把新建的这个 Control **改名为 `TownView`**(双击节点名或 F2)。
   - **关键**:它现在应是 `MainArea` 的子节点,且**排在 `CombatView` 之后**(列表里在 CombatView
     下方)。若它跑到了 CombatView 上面,在 Scene dock 里把它拖到 CombatView 下方
     —— 城镇遮罩要叠在战斗视图之上,顺序错了出城时遮罩会被战斗视图盖住。
   - 期望此刻 `MainArea` 的子节点顺序:`Hero` → `CombatView` → `TownView`。
   - Verify:Scene dock 树形如下
     ```
     FloatingShell
      ├ BgStrip
      ├ MainArea
      │  ├ Hero
      │  ├ CombatView
      │  └ TownView        ← 新增,在 CombatView 之后
      ├ Handle
      └ CollapseBtn
     ```

## C. 挂脚本 + 锚布局(Inspector)

7. 选中 `TownView`,在 Scene dock 节点名旁点 **附加脚本图标**(或右键 → Attach Script)。
   - 在弹窗里**不要新建**,选 **Load** → 指到 `res://src/combat/town_view.gd` → Open。
   - (脚本里 `class_name TownView` 已带,附上后节点类型显示为 TownView。)
   - Verify:Scene dock 里 `TownView` 节点带脚本图标,Inspector 顶部显示脚本 `town_view.gd`。
8. 选中 `TownView`,Inspector 里设 **Layout → Anchors Preset = `Full Rect`**(=15,锚满 800×250
   主区,同 `CombatView`)。
   - (脚本 `_ready` 里也会 `set_anchors_preset(FULL_RECT)` 兜底,但在编辑器里设好可见布局正确。)
   - Verify:2D 视图里 `TownView` 的边框铺满 800×250 主区,与 `CombatView` 重合。
9. **不需要**在 Inspector 填任何 @export —— TownView 无导出字段,所有子节点(进城按钮 / 城镇
   遮罩 / 三栏)由脚本 `_build_ui()` 运行时自建。Inspector 里 TownView 下没有红色未填字段。

## D. 信号与全局(均已在代码里接好,无需手连)

10. **无需在 Node dock > Signals 手连任何信号。** 确认即可:
    - "进城"按钮 `pressed` → `_enter_town`(代码 `town_view.gd:223` 已 connect)。
    - "出城"按钮 `pressed` → `_leave_town`(`town_view.gd:244`)。
    - 槽位选择 / "换" / "强化 +1" 按钮均在 `_rebuild_*` 里运行时 connect。
11. **无需新增 Autoload。** `TownView._ready` 读现有 autoload `Game`(`/root/Game`,project.godot
    里 `Player` → `Game` 已注册)。确认 Project Settings > Autoload 里 `Player`、`Game` 在列即可。
12. **无需新增 Input Map / Group / 素材导入** —— 本功能零外部依赖。

---

## 保存

13. `Ctrl+S` 保存 `floating_shell.tscn`。
    - Verify:`floating_shell.tscn` 顶部 ext_resource 多了一条指向 `town_view.gd` 的 Script,
      `MainArea` 下多了 `[node name="TownView" ...]`。

---

## Run & expected behavior

14. 按 **Play(F5)**。
    - **战斗态**:主区正常挂机打怪(CombatView 照旧),顶部中央(约 x=300)多出一个 **"进城"** 按钮。
15. **点"进城"**:
    - 期望:挂机**冻结**(敌人/血条不再动)、CombatView 隐藏、铺满主区的深色 **"城镇 · 工作台"**
      遮罩出现,左栏三槽(武器/护甲/饰品)、中栏选中槽强化信息、右栏该槽可换背包件。
16. **左栏点某个槽**(如"护甲"):中栏切到该槽强化信息、右栏列该槽背包件。
17. **右栏某背包件**下显**逐轴差值**(升绿↑、降红↓);点其行首 **"换"**:装上、原件回背包、面板刷新。
18. **中栏"强化 +1"**:材料够则可点 → 等级 +1、材料按 `1+L` 扣、主轴数值上升;满 +10 显"已满级"且
    按钮禁用;材料不足时按钮置灰。
19. **点"出城"**:遮罩隐、CombatView 回显、挂机恢复;**血量不回满**(沿用进城前 HP),且城镇里换/
    强化过的装备在战斗中生效(攻击/护甲等数值变化)。

> 验收口径完整版见 CHANGES.md §4 W4(本节即其逐条落地)。

---

## Flags

- **F-SEED(验收数据前置,非接线缺陷)**:换装/对比/强化要"看得到效果",需 roster 首个战士有
  **同槽可换背包件** + 该槽 `slot|white` 材料有量。新档进城时背包/材料可能为空 → 三栏会显
  "(无可换 …)"且强化按钮灰。**验收前先让游戏挂机刷一会儿**(掉同槽件 + 攒白材料)再进城,
  否则面板是空的(属正常,不是 bug)。
- **F-VISUAL(轻微,非阻塞)**:"进城"按钮固定在 (300,12),可能与 CombatView 顶部进度/敌人
  标签视觉上靠近。若实测压字影响阅读,这是表现层位置微调,回报我或留给 Art Spec juice 阶段
  调整,不影响功能验收。
- **EI 假设**:本步骤基于当前 `floating_shell.tscn`(`MainArea` 下 Hero+CombatView)。若你的场景
  已被改动(如 CombatView 改过名),`TownView` 的同级查找 `get_node_or_null("CombatView")` 会
  失效 → 进城时 CombatView 不隐藏。**CombatView 节点名须保持 `CombatView` 不变。**
- **若第 7 步报"找不到类型 TownView"**:A 步类缓存没刷新 —— 关编辑器,跑一次
  `godot --headless --import`,重开编辑器再试。
