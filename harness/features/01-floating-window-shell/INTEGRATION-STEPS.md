---
artifact: INTEGRATION-STEPS
feature: 01-floating-window-shell
role: Engine Integrator (Godot)
status: accepted
updated: 2026-06-18
inputs: [project-context.md, style-basic-2d.md(§4/§7/§9 EI), CHANGES.md(Wiring Contract), ASSET-SPEC.md, ACCEPTANCE.md, PLAN.md]
next: 本功能接线已验收;回 Producer 拉下一项 或 /role-reviewer 审代码质量
---

# INTEGRATION-STEPS — 悬浮窗外壳

> 你(人类)在 Godot 4.6 编辑器里照做,把结果(截图/报错/Inspector 状态)回报给我验收。
> **本功能的 `CHANGES.md`(Wiring Contract)尚不存在**(Implementer 未跑)。按 EI 契约,
> 没有 Wiring Contract 不能编场景接线步骤(否则=瞎猜)。故本文分两段:
> - **Phase 1(现在就能做)**:素材导入预设 + 项目图形设置——不依赖代码,PLAN R4 要求 EI 先行。
> - **Phase 2(挂起 / BLOCKED)**:场景树、挂脚本、@export、信号、窗口/输入项目设置——
>   **必须等 Implementer 出 CHANGES.md** 我才能给确切步骤。下面只列出"会需要什么"的占位。

---

## Phase 1 — 项目图形设置 + 素材导入 ✅ 已验收(2026-06-18)
> EI 核验通过:`.import` 三件 compress=Lossless / mipmaps off / fix_alpha_border on;
> `project.godot` rendering_method=gl_compatibility、viewport 1280×250、过滤 Linear(默认)、
> stretch disabled(默认)。无报错。

### A. 项目级图形设置(Project > Project Settings)
1. **渲染模式切 Compatibility。** Rendering → Renderer → 顶部 `Rendering Method` 改为
   **`gl_compatibility`**(右上角可能要你**重启编辑器**生效)。依据 PLAN D5(常驻挂件,省资源)。
   - Verify:重启后编辑器右下角/输出无渲染报错;项目仍能打开。
2. **默认纹理过滤 = Linear。** Rendering → Textures → Canvas Textures →
   `Default Texture Filter` = **`Linear`**(平滑手绘风,非像素;style-basic-2d §4.1 本项目已定死)。
   - Verify:该项显示 Linear。
3. **Stretch 模式 = disabled。** Display → Window → Stretch → `Mode` = **`disabled`**
   (PLAN D7:主区恒 800×250 不随屏宽缩放;**有意偏离** style-basic-2d §4.4 的 canvas_items 默认)。
   `viewport_width/height` 给种子值(如 `1280` × `250`)即可,运行时窗口尺寸由代码按工作区覆盖。
   - Verify:Stretch Mode 显示 disabled。
   > 注:窗口 `borderless / always_on_top / 实际尺寸`、Input Map 动作、主场景设定属代码侧
   > (PLAN step1,Implementer 改 project.godot)→ 不在本 Phase,见 Phase 2 / Flag F6。

### B. 导入三件占位素材(平滑风预设)
> 素材已在项目内:hero/icon 在 `res://assets/sprites/placeholder/`,bg 在 `res://assets/sprites/bg/`。
> 它们首次被 Godot 看到时已用默认设置自动导入,这里改成平滑风预设后 **Reimport**。
> 平滑风预设(style-basic-2d §4.2):**Compress=Lossless,Mipmaps=Off,Filter=Linear,
> Fix Alpha Border=On**。

4. FileSystem dock 选中 `res://assets/sprites/placeholder/hero_warrior_placeholder.png` →
   Import dock 设:
   - `Compress > Mode` = **Lossless**
   - `Mipmaps > Generate` = **关**
   - `Process > Fix Alpha Border` = **开**
   - (Filter 跟随项目默认 Linear,无需逐张设)
   → 点 **Reimport**。
   - Verify:放大看角色边缘平滑无暗边/彩边、透明干净;无导入报错。
5. 对 `res://assets/sprites/placeholder/icon_handle_placeholder.png` 重复 step 4 设置 → Reimport。
   - Verify:图标边缘干净、透明正常。
6. 对 `res://assets/sprites/bg/bg_strip_placeholder.png` 重复 step 4 设置 → Reimport。
   - Verify:背景为不透明实底、无多余透明;边缘平滑。
   - ⚠ **平铺(tiling)不是导入设置**(见 Flag F2):Godot 4 的纹理重复由**节点** `texture_repeat`
     或项目默认 `default_texture_repeat` 控制,**留到 Phase 2** 在 bg 的 `TextureRect` 上设
     `texture_repeat = Enabled`。本步只确保 bg 本身导入正确。
7. **提交 `*.import`、忽略 `.godot/`**(style-basic-2d §4.3):确认
   `hero_warrior_placeholder.png.import` / `icon_handle_placeholder.png.import` /
   `bg_strip_placeholder.png.import` 三个文件随图一起纳入版本控制;`.godot/` 加进 `.gitignore`。
   - Verify:`git status` 能看到三个 `.import`;`.godot/` 不在待提交列表。
   - ⚠ 见 Flag F4:当前 `G:\Games` 不是 git 仓库,若尚未 `git init` 本条暂记为待办。

### Phase 1 校验(headless,style-basic-2d §7)
8. 命令行跑:`godot --headless --import`
   - Verify:无导入报错(三张图重导入干净)。

---

## Phase 2 — 场景接线核对 + 运行验收 ✅ 已验收(2026-06-18)
> EI 核验通过:§C 解析/导入、§D 场景结构、§E @export/信号(含步骤 9 Ctrl+S 清 null)、§F 项目设置、
> §G 版本控制 全部如述;Run(步骤 17–18)横条贴底不压任务栏、平铺、角色微动、收起/展开干净无抖动、
> per-pixel 透明收起态无残留方块、F2 置顶均经人工 Play 验收 OK。R1/R3/per-pixel/编辑器 null 风险全部关闭。
>
> (CHANGES.md Wiring Contract 已就位)
> Implementer 走"代码 + 手写 .tscn"路线:节点树/纹理/脚本/信号都已在文件里写定。故本 Phase
> **以核对(verify)为主、几乎不拖拽**。逐组做完把结果(截图/报错/Inspector)回报给我验收。
> 命令里的 Godot 路径用你的安装:`G:\Godot\Godot_v4.6.3\Godot_v4.6.3-stable_win64.exe`。

### C. 解析 / 导入校验(先确保不报错 —— Implementer 本机无 godot,这步替它补上)
1. PowerShell 跑无头重导入:
   `& "G:\Godot\Godot_v4.6.3\Godot_v4.6.3-stable_win64.exe" --headless --path "G:\Games\test-2" --import`
   - Verify:无导入报错(三图早已按平滑风导入,应秒过)。
2. 脚本语法检查:
   `& "G:\Godot\Godot_v4.6.3\Godot_v4.6.3-stable_win64.exe" --headless --path "G:\Games\test-2" --check-only --script res://src/shell/floating_shell.gd`
   - Verify:**无任何解析/编译错误输出**(这是 CHANGES §6 留给 Phase 2 的关键一步)。
   - 备选:直接在编辑器打开项目,看底部 Output / Debugger 面板无脚本报错红字。

### D. 场景结构核对(Scene dock + Inspector)
3. 打开 `res://scenes/shell/floating_shell.tscn`。对照 Wiring Contract 看 Scene dock 节点树:
   `FloatingShell`(Control)→ 子 `BgStrip`(TextureRect)、`MainArea`(Control,其下 `Hero` Sprite2D)、
   `Handle`(TextureButton)、`CollapseBtn`(Button)。
   - Verify:五节点齐、类型对、层级对;`FloatingShell` 右侧有脚本图标(挂着 `floating_shell.gd`)。
4. 选 `BgStrip` → Inspector:`Texture` = bg_strip_placeholder;`Stretch Mode` = **Tile**;
   展开 CanvasItem → Texture → `Repeat` = **Enabled**。
   - Verify:三项如述(这是背景能平铺不拉伸的关键)。
5. 选 `Hero` → Inspector:`Texture` = hero_warrior_placeholder;`Centered` = 开;`Position` = (400, 170)。
6. 选 `Handle` → Inspector:`Texture Normal` = icon_handle_placeholder;`Visible` = 关(默认隐藏)。
7. 选 `CollapseBtn` → Inspector:`Text` = "收起"。

### E. @export / 信号核对(合同声明已内部接线,不需在编辑器连)
8. 选 `FloatingShell` → Inspector 看脚本导出项:应见 `content_fade_duration`(0.12)、`idle_bob_amplitude`(4)、
   `idle_bob_period`(2)、`idle_scale_amplitude`(0.015)、`fps_expanded`(60)、`fps_collapsed`(15)、
   `key_toggle_collapse`(F1)、`key_toggle_always_on_top`(F2)。
   - Verify:字段都在、有默认值;**不应出现 `transition_duration`,也不应有字段显示为空/红**。
9. **清理上次保存遗留的 `= null` 导出**(编辑器在改脚本时把导出写成了 null,还残留已删的
   `transition_duration`)。在 `floating_shell.tscn` 标签页按 **Ctrl+S 重存一次**。
   - Verify:重存后回步骤 8 看导出已恢复脚本默认值;场景无报错。
10. 信号:`Handle.pressed` 与 `CollapseBtn.pressed` 在脚本 `_ready()` 里 `connect`(非编辑器连)。
    Node dock → Signals 里它们显示"未在编辑器连接"是**正常**的,无需手动连。生效与否在 Run 验证。

### F. 项目设置核对(Project > Project Settings,打开"高级设置"才看得全)
11. Application → Run → `Main Scene` = `res://scenes/shell/floating_shell.tscn`。
12. Display → Window → Size:`Borderless` = On、`Always On Top` = On、`Transparent` = On。
13. Display → Window → Per Pixel Transparency → `Allowed` = On。
14. Display → Window → Stretch → `Mode` = `disabled`。
15. Rendering → Renderer → `Rendering Method` = `gl_compatibility`(Phase 1 已设,确认未变)。
    - Verify:11–15 各项如述。

### G. 版本控制(style-basic-2d §9〔EI〕)
16. `git status` 确认三个 `*.import`(hero/icon/bg)已被跟踪;`.godot/` 不在待提交列表。
    - Verify:`.gitignore` 已含 `.godot/`(已核对);三 `.import` 在版本控制内。F4 旧"非 git 仓库"已解除。

---

## Run & expected behavior
17. ⚠ **先确保游戏以独立桌面窗口运行,而非编辑器内嵌 Game 窗口**:Editor → Editor Settings →
    搜 `embed` → Run/Window Placement → `Game Embed Mode` = **Disabled**(上次已处理,确认仍是)。
    内嵌窗口下贴桌面底/透明都不成立。
18. 按 **Play**。期望:
    - 屏幕**最底部**出现全屏宽、250px 高悬浮条,**底边贴任务栏上沿、不重叠不遮挡**(R3 实测点)。
    - 两侧背景**横向平铺、不拉伸**;中央 800×250 主区居中;占位战士底部居中、轻柔上下浮动。
    - 点"收起"或按 **F1**:横条**淡出** → 右下角**干净盾牌图标淡入**(无灰方块底、无几何抖动);
      点盾牌或再按 F1 → 平滑唤回全宽条。
    - 收起态:盾牌图标四周是桌面(per-pixel 透明生效)。
    - 窗口聚焦时按 **F2**:切换置顶——关闭后其它窗口能盖住它,再按恢复在最前。

## Flags(Phase 2)
- **R1(已由 Implementer 化解)** 逐帧缩窗抖动 → CHANGES §8.3 已改为"交叉淡变 + 几何瞬切",
  运行时确认收起/展开无抖动即可关闭此风险。
- **R2** F1/F2 仅窗口**聚焦时**响应(Godot 无内建全局热键);本期主路径是点按钮/handle。属设计取舍,非缺陷。
- **R3〔需你肉眼确认〕** `screen_get_usable_rect` 是否真避开任务栏——步骤 18 第一条务必确认不压任务栏。
  若你是多屏/高 DPI 且贴位不准,回报我,可能需退回手测任务栏高。
- **per-pixel 透明** 本机此前肉眼已通过(收起态干净盾牌);仍属"个别显卡/DPI 可能有瑕疵"项,
  Compatibility 渲染下尤其再看一眼收起态边缘有无残留方块/暗边。
- **〔编辑器残留〕** `transition_duration = null` 等导出 → 步骤 9 重存清理后即消。
- **F5(沿用)** Stretch=disabled 是对 style-basic-2d §4.4 默认的有意偏离(PLAN D7),已记录。
- **接线 0 拖拽** 是 Implementer 偏离 3(纹理 ext_resource 内嵌、信号代码连),非缺陷;EI 仅核对。
