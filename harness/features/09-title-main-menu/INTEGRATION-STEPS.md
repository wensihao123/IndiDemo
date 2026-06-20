---
artifact: INTEGRATION-STEPS
feature: 09-title-main-menu
role: Engine Integrator (Godot)
status: accepted
updated: 2026-06-20
inputs: [harness/features/09-title-main-menu/CHANGES.md, harness/features/09-title-main-menu/PLAN.md, harness/project-context.md, harness/style-basic-2d.md, scenes/shell/floating_shell.tscn, src/shell/game_flow.gd]
next: 人(手动 Play 验收)→ Reviewer
---

# INTEGRATION-STEPS · 09-title-main-menu(前门 + 系统枢纽)

> 集成对象:给悬浮窗补上 `GameFlow` 流程机——启动落居中主菜单窗、选完收缩贴底进游戏、游戏中 `[☰]` 回菜单。
>
> **本功能无新美术资源**(主菜单/三屏/`[☰]` 全是占位文字,视觉交 Art Spec → CHANGES Wiring W7),故**没有导入步骤**。
> Implementer 已把 `GameFlow` 节点 + `stages` 导出**直接写进** `floating_shell.tscn`,故编辑器侧主要是**核对**而非搭建。
> 真正只有你能验的是 **GUI 跑动**(点按钮、看窗口几何变化、看 Esc 行为)——即 §D 验收脚本。

## ✅ 验收结果(2026-06-20)
人手动 Play 验收**通过**:主菜单功能全链路无问题(启动落菜单、收缩进游戏、`[☰]` 回菜单、覆盖/退出确认、Esc、几何)。
本 artifact 转 **accepted**。剩余仅占位视觉(交 Art Spec,见 Flags W7)与代码评审(Reviewer)。

## 0. 我已替你跑过的自动闸(全绿,你不必重跑)
- `godot --headless --import` → exit 0,无导入报错(新脚本 `game_flow.gd` 的 `.uid` 已生成并回填进 .tscn ext_resource)。
- `godot --headless --quit-after 3`(启动主场景 3 秒)→ exit 0,**`_ready` 链零报错**:含 autoload `Player`/`Game` boot +
  GameFlow `call_deferred("_enter_title")` → `enter_menu_geometry()` → 几何 Tween,headless 下不崩。
- gdUnit4 全量 156/156 PASS(Implementer 已跑,CHANGES §3)。
- ⇒ 编译 / 导入 / 场景加载 / 纯逻辑**已确认无回归**;下面只剩 GUI 表现要你肉眼验。

## A. 打开场景,核对 GameFlow 节点(Scene dock)
1. FileSystem dock → 打开 `res://scenes/shell/floating_shell.tscn`。
2. Scene dock 里确认节点树为(GameFlow 应是 **`FloatingShell` 的直接子节点**,排在最后):
   ```
   FloatingShell (Control)
   ├ BgStrip (TextureRect)
   ├ MainArea (Control)
   │  ├ Hero (Sprite2D)
   │  ├ CombatView (Control)
   │  └ TownView (Control)
   ├ Handle (TextureButton)
   ├ CollapseBtn (Button)
   └ GameFlow (Control)        ← 新增,必须在这一层(不是 MainArea 下)
   ```
   - **Verify**:`GameFlow` 存在、类型 `Control`、是 `FloatingShell` 直接子;节点名无红色"脚本/资源丢失"叹号图标。
     (层级很关键:`game_flow.gd._ready` 用 `_shell = get_parent()` 取外壳,移到 MainArea 下会取错父、几何 API 失效。)

## B. 核对 GameFlow 的脚本与 @export(Inspector)
3. 选中 `GameFlow` 节点 → 看 Inspector 顶部:Script = `res://src/shell/game_flow.gd`。
4. Inspector 里找 **`Stages`** 数组属性(GameFlow 唯一的 @export):应为 **Array[StageConfig],含 2 个元素** —
   `stage_01.tres`、`stage_02.tres`(顺序如此)。
   - **Verify**:点开数组,两格都不是 `<empty>`/红色;鼠标悬停显示 `res://assets/data/combat/stage_01.tres` /
     `stage_02.tres`。
   - 若为空 → 拖 `res://assets/data/combat/stage_01.tres`、`stage_02.tres`(FileSystem dock)依次进数组两格。
     **这是本功能关卡表的唯一事实源**(已从 CombatView 搬来,Wiring W1)。
5. 顺手核对 `MainArea/CombatView` 选中后 Inspector **不再有 `Stages` 属性**(已迁出,Wiring W2)。
   - **Verify**:CombatView 的 Inspector 无 Stages 字段(或为空且无引用)。

## C. 全局/信号/输入(本功能零编辑器接线)
6. **Autoload 不变**:Project Settings → Globals/Autoload 应仍是 `Player`(上)→ `Game`(下)两枚,顺序不动。本功能未加/未改 autoload。
7. **无需在编辑器连任何信号**:四菜单屏按钮、`[☰]`、Esc 全在代码里 `.pressed.connect(...)` / `_unhandled_input` 接好;
   `game_flow` / `town_view` 两个 group 在各自 `_ready` 用 `add_to_group(...)` 注册(非编辑器)。Node dock → Signals 无需操作。
8. **无新 Input Map 动作**:Esc 走 `KEY_ESCAPE` 硬判,F1/F2 沿用 floating_shell 既有 `@export` 键码。Project Settings → Input Map 不动。
   - **Verify**(B+C 合并):Inspector/全局核对完毕,无红色空导出、autoload 两枚不变。

## D. Run & expected behavior(★ 唯一需你亲手验的部分,逐条点 + 看)

> 按 **Play (F5)** 运行主场景 `floating_shell.tscn`。下面分组,每条给"操作 → 期望观察"。
> **存档位置**(用于切换有档/无档测试):`%APPDATA%\Godot\app_userdata\<项目名>\savegame.json`
> (`user://savegame.json`)。删它 = 回到"无档"首启状态。建议**先测无档、再测有档**。

### D1 · 启动落主菜单(无档)
- 先确保无存档(删上面那个 json,或干净环境首启)→ Play。
- **期望**:窗口落在工作区**居中**、约 **560×400** 的较大窗;显示 "test-2" 标题 + 四个按钮〔继续 / 新游戏 / 设置 / 退出〕;
  **「继续」置灰不可点**(无档);贴底 800×250 游戏条**不可见**。
  - 可接受瑕疵:启动瞬间可能有**一帧贴底条闪**再淡入居中菜单(已知,记给 Art Spec,CHANGES §5)。

### D2 · 新游戏(无档)→ 收缩进游戏
- 点〔新游戏〕。
- **期望**:**无覆盖确认**(无档不需要),窗口**收缩成贴底 800×250 条**、无明显抖动;进入战斗(出现进度读出"第 1 关…"、战斗日志滚动、敌人占位);从 0-0 新局开打。

### D3 · `[☰]` 回菜单,且 **sim 不暂停**(支柱 1 关键验收)
- 战斗中点右上 `[☰]`(占位文字 "☰",CombatView 左上偏右 ~(596,12))。
- **期望**:窗口**放大回居中主菜单窗**;此时**「继续」可点**(已有内存局)。
- **关键**:停在菜单几秒后点〔继续〕→ 回贴底战斗,**战斗日志/进度应已继续推进**(怪续打、可能掉了东西/团灭回退)——
  证明菜单覆盖层**没有暂停后台挂机**(若回来发现战斗"定格在离开那刻"= bug,记 Flag 回 Implementer)。

### D4 · 有档重启 → 继续(续战游标)
- D2 之后已写出存档。停掉运行 → 再 Play。
- **期望**:启动居中主菜单,**「继续」可点**(有档);点〔继续〕→ 收缩进游戏,**续到存档进度**(关卡/场景与上次一致,非从 0-0)。

### D5 · 新游戏(有档)→ 覆盖二次确认
- 主菜单(有档态)点〔新游戏〕。
- **期望**:弹**覆盖确认子屏**("已有存档,新游戏将覆盖旧存档。确定?" + 确定/取消)。
  - 点〔取消〕→ 回主菜单,存档不动。
  - 再〔新游戏〕→〔确定〕→ 开 0-0 新局并收缩进游戏(旧档被覆盖)。

### D6 · 设置 / 退出子屏
- 主菜单〔设置〕→ **期望**:占位设置屏("设置(占位 · …)" + 返回);点〔返回〕→ 回主菜单。
- 主菜单〔退出〕→ **期望**:退出确认屏(确定/取消);〔取消〕→ 回主菜单;〔确定〕→ **进程退出**(退出前 autosave)。

### D7 · Town 来源的 `[☰]`(维持暂停)
- 进游戏后,在战斗视图点〔进城〕进入城镇(挂机暂停)→ 在城镇点 `[☰]`(城镇态,~(650,10))。
- **期望**:放大回主菜单;点〔继续〕→ 回到**城镇**界面(不是战斗),且**仍处暂停**(城镇本就暂停,继续不应偷偷 resume/回血)。

### D8 · Esc 统一退一级
- 设置屏 / 覆盖确认屏 / 退出确认屏里按 **Esc** → **期望**:各退一级**回主菜单**。
- 顶层主菜单**作为游戏中覆盖层(MENU_OVERLAY)**时按 Esc → **期望**:等同〔继续〕,回来源态(Explore/Town)。
- 顶层主菜单**作为启动 TITLE** 时按 Esc → **期望**:**无反应**(根屏无 Esc 出口)。

### D9 · 几何 / 收起热键边界
- 进游戏(Explore)按 **F1** → **期望**:收起成 64×64 角标(handle),再 F1 展开——既有收起逻辑不受影响。
- 处于**主菜单(MENU 几何)**时按 **F1** → **期望**:**无反应**(MENU 态无收起出口)。
- 反复 MENU↔贴底切换 → **期望**:几何切换是"淡出→瞬间跳变→淡入",**无逐帧拖拽式抖动**。

## Flags / 待观察
- **占位排布(交 Art Spec,非 bug)**:`[☰]` 文字按钮位置(Combat (596,12) / Town (650,10))可能与〔推进〕(660,12,仅卡关显)
  /〔收起〕挤在一起;MENU 窗 560×400、四屏视觉、过渡手感、启动首帧贴底闪——均占位,见 CHANGES Wiring W7。
- **D3 是支柱 1 红线**:菜单覆盖层若暂停了挂机即违反"它首先是个伙伴",必须回报。
- **若某 @export 在 §B 为空**:说明 .tscn 的 stages 未正确随场景加载——回报我(EI),别在编辑器硬填后不记录。
- **若出现脚本报错**(尤其 `get_parent()` 取外壳为 null、group 找不到 GameFlow):停下回报 Implementer,勿在编辑器绕过(可能掩盖代码缺口)。

## 回报格式(给 EI 验收)
请按 D1–D9 逐条回 ✅/❌;❌ 项附**截图**或**控制台报错文本** + 你当时的操作。全 ✅ 我就把本 artifact 转 `accepted` 并更新 HANDOFF,交 Reviewer。
