---
artifact: INTEGRATION-STEPS
feature: 02-auto-combat-loop
role: Engine Integrator (Godot)
status: accepted       # Part 1 + Part 2 均人工照做并验收通过(2026-06-18):敌人正式贴图 + 蓝/金光柱 OK,--import 0
updated: 2026-06-18
inputs: [CHANGES.md(Wiring Contract §5 E), ASSET-SPEC.md, ACCEPTANCE.md, style-basic-2d.md(§4/§7 EI), project-context.md, floating_shell.tscn, combat_view.gd, enemy_def.gd, stage_01.tres, stage_02.tres]
next: 接线轨道收口;可选 /role-reviewer 02-auto-combat-loop 复核 F1 增量
---

# INTEGRATION-STEPS — 02 自动战斗循环正式素材导入接线

> 把已验收的 13 件正式素材接进 Godot(4.6,GDScript)。**两阶段:**
> - **Part 1 ✅ 已验收(纯编辑器/导入):** 全 13 件导入预设 + 把 01 的 3 个占位贴图(战士/背景/handle)
>   重指到正式名 + 清占位 + headless 校验通过。
> - **Part 2(F1 已落地 · 待人工照做):** 8 只敌人贴图在 `stage_01/02.tres` 里赋值;FX 两张图由代码 `preload`
>   无须接线。Implementer 已补齐 `EnemyDef.sprite` + `combat_view.gd` 的 `TextureRect`/FX 逻辑(见 F1)。
>
> 环境提醒:本机 Godot 可执行为 `godot.exe`(非文档旧名)。校验命令照此。

---

## Part 1 — 可立即照做

### A. 导入预设(全 13 件,平滑风统一)— style-basic-2d §4.2「平滑风」
> 资源已在 `res://assets/sprites/` 下正确分目录(enemies/ fx/ hero/ bg/ ui/)。首次打开编辑器 Godot
> 会自动为每个 PNG 生成 `*.import`。下面统一设预设,避免逐张不一致(§4 统一性根基)。

1. 打开 Godot 编辑器加载本项目。等 FileSystem dock 出现全部 PNG(若刚拖入,等导入扫描跑完)。
2. **先确认项目默认过滤 = 平滑:** Project Settings → General → Rendering → Textures →
   **Default Texture Filter = `Linear`**(本项目未显式写该键,默认即 Linear,符合平滑风;若被改成 Nearest 要改回)。
   - Verify:该项显示 Linear。
3. 在 FileSystem dock 里**框选这 12 个透明件**(enemies/ 下 8 + fx/ 下 2 + hero/hero_warrior.png + ui/icon_handle.png)。
   `bg_strip.png` 不透明,单独设(见步 5)。
4. 选中状态下切到 **Import dock**(默认在 Scene dock 同侧标签),设:
   - **Compress → Mode = `Lossless`**
   - **Mipmaps → Generate = 关(取消勾选)**
   - **Process → Fix Alpha Border = 开(勾选)** ← 平滑透明边消暗/彩边,style-basic-2d §4.2 必开
   - (可选稳妥)**Detect 3D → Compress To = `Disabled`**,防被误判 3D 用途而自动 VRAM 压糊。
   - 点 **Reimport**。
   - Verify:12 件缩放时平滑不发糊;透明边无暗框/彩边。
5. 选 `bg/bg_strip.png`,Import dock 同样设 **Compress = Lossless / Mipmaps 关 / Fix Alpha Border 开**(满底图开不开都行,统一开无害),Reimport。
   - Verify:背景清晰、无压缩噪点。
6. **提交所有 `*.import`**(`assets/sprites/**/**.png.import`)进版本控制;确认 `.godot/` 已在 `.gitignore`(style-basic-2d §4.3)。

### B. 01 占位转正 —— 重指 `floating_shell.tscn` 的 3 个贴图引用
> 这 3 件在场景里是 `ext_resource` Texture2D,直接在 Inspector 换贴图即可(纯编辑器,无代码)。
> 现引用:`bg_strip_placeholder.png` / `hero_warrior_placeholder.png` / `icon_handle_placeholder.png`。

7. 打开 `res://scenes/shell/floating_shell.tscn`。
8. Scene dock 选 **`BgStrip`**(TextureRect)→ Inspector → **Texture** 字段 → 点贴图右侧下拉 → **Load**
   → 选 `res://assets/sprites/bg/bg_strip.png`(或从 FileSystem 拖该文件到 Texture 字段)。
   - 保持 `texture_repeat = 2`(Enabled)、`stretch_mode = 1`(Tile)不变。
9. Scene dock 选 **`MainArea/Hero`**(Sprite2D)→ Inspector → **Texture** → Load `res://assets/sprites/hero/hero_warrior.png`。
   - 保持 `position = (400,170)`、`centered`(默认 on)不变:128×160 居中于 y=170 → 脚底落 y=250 地平线,与占位一致。
10. Scene dock 选 **`Handle`**(TextureButton)→ Inspector → **Texture Normal** → Load `res://assets/sprites/ui/icon_handle.png`。
11. `Ctrl+S` 保存场景。
    - Verify:2D 视图里背景=暖木城镇条、主区战士=正式手绘战士(朝右)、收起态 handle=盾徽;无红色"missing resource"。

### C. 清理旧占位(确认无引用后)
12. FileSystem dock 逐个**右键 → View Owners…** 确认下列文件 **owners 为空**(B 步已把唯一引用换走):
    - `res://assets/sprites/bg/bg_strip_placeholder.png`
    - `res://assets/sprites/placeholder/hero_warrior_placeholder.png`
    - `res://assets/sprites/placeholder/icon_handle_placeholder.png`
13. 确认空 owners 后,右键 **Delete**(连同各自 `.import`)。若 `assets/sprites/placeholder/` 变空,一并删该空目录。
    - ⚠ 删除不可逆:务必先做步 12 的 owners 检查。若任一文件仍有 owner,**停下回报**,不要硬删。
    - Verify:删除后回 `floating_shell.tscn` 按 Play,无 "missing/invalid resource" 报错。

### D. Part 1 headless 校验(style-basic-2d §7)
14. 命令行项目根跑:
    ```
    godot.exe --headless --import
    ```
    - Verify:退出码 0,无导入报错(占位删除后无悬空 uid 警告)。
15. 可选触发场景加载期错误:
    ```
    godot.exe --headless --quit-after 2
    ```
    - Verify:无 "Failed loading resource" / 无脚本报错。

**回报给我(Part 1 验收):** 步 11 / 13 的 2D 视图截图(看到正式战士+背景+handle)、步 14 的退出码与输出。

---

## Part 2 — 敌人(8)+ FX(2)接线【F1 已落地 · 可照做】

> F1 已由 Implementer 落地(见 CHANGES §1 增量 / Wiring Contract §E),我已复核:
> - `src/combat/enemy_def.gd` 新增 `@export var sprite: Texture2D`(分组「外观」,贴图随 Resource 走、不硬编码路径)。
> - `src/combat/combat_view.gd` 敌人改用 `_enemy_sprite: TextureRect`(贴图缺失才回退旧 `ColorRect` 占位);
>   `_spawn_pillar` 改用 `fx_light_pillar` 贴图 + `modulate` 染稀有度,`fx_loot_sparkle` 叠在光柱根部。
> - **FX 两张图由代码 `preload` 固定路径引用(属代码侧),EI 无需在编辑器接线** —— 只剩敌人贴图要在 `.tres` 里赋值。
>
> 所以 Part 2 = 在两个 stage 数据文件里,给 8 只敌人(含 2 boss)的 `sprite` 字段拖入对应 PNG。纯编辑器、无代码。

### E. stage_01.tres — 给 4 只敌人赋贴图
16. FileSystem dock 双击 `res://assets/data/combat/stage_01.tres` 打开(它是 StageConfig,敌人是内联 EnemyDef 子资源)。
17. Inspector 里展开 **`boss`** 子资源(点左侧三角)→ 找到分组 **「外观」→ `Sprite`** 字段 → 从 FileSystem dock 把
    `res://assets/sprites/enemies/enemy_goblin_king.png` **拖到** 该 `Sprite` 字段(或点字段下拉 → Load 选它)。
    - 这是 boss **哥布林王(BossGoblinKing)**。
18. 展开 **`scenes`** 数组 → 逐个展开 `scenes[i]` → 展开其内联 **`enemy`** 子资源 → 「外观」`Sprite` 拖图:
    - `scenes[0].enemy` = **哥布林(EnemyGoblin)** → `enemy_goblin.png`
    - `scenes[1].enemy` = **野狼(EnemyWolf)** → `enemy_wolf.png`
    - `scenes[2].enemy` = **兽人(EnemyOrc)** → `enemy_orc.png`
19. `Ctrl+S` 保存。
    - Verify:每个 `Sprite` 字段显示对应贴图缩略图,非 `<empty>`。

### F. stage_02.tres — 给 4 只敌人赋贴图
20. 打开 `res://assets/data/combat/stage_02.tres`,同 E 步操作:
    - `boss` = **兽人酋长(BossOrcChieftain)** → `enemy_orc_chieftain.png`
    - `scenes[0].enemy` = **精英兽人(EnemyEliteOrc)** → `enemy_orc_elite.png`
    - `scenes[1].enemy` = **暗影狼(EnemyShadowWolf)** → `enemy_wolf_shadow.png`
    - `scenes[2].enemy` = **食人魔(EnemyOgre)** → `enemy_ogre.png`
21. `Ctrl+S` 保存。敌人全部朝左(ACCEPTANCE 已核),**无需 `flip_h`**。
    - Verify:8 个 `Sprite` 字段(两文件合计)全部非空。
22. 提交两个 `.tres`(`assets/data/combat/stage_01.tres`、`stage_02.tres`)。

### G. Part 2 headless 校验 + Play 走查
23. 命令行项目根跑 `godot.exe --headless --import`,确认退出码 0、无报错(FX 两张图随场景被打包)。
24. 编辑器按 Play(`floating_shell.tscn`),观察战斗自动走怪:
    - 每只敌人显示**正式手绘贴图**(脚底落同一地平线,屏上高 ~70–125px),不再是红色块。
    - 击杀掉**蓝装**出蓝光柱(染 `#6699ff`)、**金装**出金光柱(染 `#ffd24a`)+ 根部 sparkle;白装无柱。
    - 切到第二关后 4 只敌人同样显示正式贴图。

**回报给我(Part 2 验收):** 步 19/21 的 Inspector 截图(看到 `Sprite` 字段已赋图)、步 23 退出码、
步 24 战斗 2D 截图(敌人正式贴图 + 蓝/金光柱各一张)。

---

## Run & expected behavior
- **Part 1 后(已验收):** Play 时底部悬浮条背景=暖木城镇手绘条(随窗宽平铺)、主区中央=正式 Q 萌战士(朝右);
  点"收起"→ 缩成盾徽 handle,再展开恢复。
- **Part 2 后(本轮目标):** 战斗中敌人显示正式手绘贴图(朝左、脚底同一地平线),击杀蓝/金装出对应色光柱+sparkle;
  两关 8 只敌人全部正式贴图,再无红色块占位。进度/日志/小队状态栏照常。
- **回退保险:** 若某 `.tres` 的 `sprite` 漏赋,该怪自动回退到旧 ColorRect 占位(代码 graceful degradation),不崩。

## Flags
- **F1〔已解决 · 2026-06-18〕** 敌人/FX 的代码缺口已由 Implementer 补齐(CHANGES §1 增量 / §5 Wiring Contract E):
  `enemy_def.gd` 加了 `@export var sprite: Texture2D`;`combat_view.gd` 敌人改 `TextureRect`、`_spawn_pillar` 改用
  `fx_light_pillar`+`modulate`、叠 `fx_loot_sparkle`,`_gold_flash` 仍保持 `ColorRect`(ASSET-SPEC §1B)。FX 由代码
  `preload` 固定路径,EI 无须接线。剩余仅敌人贴图赋值 → 见上 §Part 2(步 16–24)。
- **F2〔W1 · bg_strip 接缝〕** ACCEPTANCE 实测左右边缘均差 ≈3%(近无缝非全无缝)。Part 1 步 8 接好后,
  把窗口横向拉宽让 `BgStrip` 平铺,**目视有无竖缝**;若可见,回报 Art(补 1–2px 接缝)。不阻塞接线。
- **F3〔导入过滤〕** 平滑风靠**项目默认 `default_texture_filter = Linear`**(步 2);Godot 4.x 的 Filter 不在
  Import dock 而在项目/节点级,故无逐张 Filter 设置。若个别节点需覆盖,用 `CanvasItem.texture_filter`。
- **F4〔音效/hitstop〕** 金装掉落音效 + 极短停顿:无音频管线,本期不接,留后续(承 ASSET-SPEC §6 / CHANGES §6)。
- **F5〔假设〕** 我未见编辑器实况,Part 1 步骤基于 `floating_shell.tscn` 当前文本(BgStrip/Hero/Handle 三节点
  及其贴图 ext_resource)。若你的场景树已与此不同,回报 Scene dock 截图我再校。
