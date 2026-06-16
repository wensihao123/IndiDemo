# style-basic-2d — 2D 图形工程纪律（Godot 适配）

> **这是什么**:一份**与玩法无关、与具体画风无关**的 2D 图形素材**工程规范**。它只回答
> "素材该怎么造、怎么导入、怎么进场景树才稳定一致",不规定"这游戏长什么样"(那是
> 项目自己的 `STYLE-BIBLE.md`:调色板、线条、视角、母题)。
>
> **怎么用**:复制到游戏项目 `harness/style-basic-2d.md`,替换所有 `<尖括号占位符>`,
> 按你的游戏增删 §6 的功能类别。它几乎不随项目变化,可跨项目复用。复制后在本行下方加一行
> `updated: <YYYY-MM-DD>`。
>
> **版本**:机制基于 Godot **4.x**(建议 4.4+,当前稳定 4.6.x)。`TileMapLayer`、`Parallax2D`
> 为 4.3+ 引入;更早版本用 `TileMap` / `ParallaxBackground` 替换。
>
> **归属提示**:标〔EI〕的章节(§4、§7,及 §9 内对应项)是 **Engine Integrator** 的权威领域,
> Art Spec **只引用、不维护**。solo 下不拆文件,但出问题按这个归属找人。

---

## 0. 三支柱（全文每条规矩都服务其中之一）

- **统一性(Consistency)**:同类素材看起来像"一套",靠统一的导入预设、调色约束、命名,
  而不是逐张手调。一致的廉价外观胜过不一致的昂贵素材。
- **规范性(Discipline)**:分层、不烘焙、源/运行时隔离——这些纪律保证素材可被引擎稳定消费,
  而不是"能跑就行"。
- **稳定性(Stability)**:锚点、默认朝向、命名一旦定下就别改;改名/改锚点会**级联**成一堆
  断引用和错位。先锁死,后产出。

---

## 1. 目标（不变）

- **玩法可读**:玩家在目标设备与最小显示尺寸下,能快速区分前景实体、背景装饰、反馈、界面。
- **工程可接入**:素材的 `res://` 路径、导入设置、图集/帧资源、加载与 fallback 策略稳定,
  可被 Godot 的导入与导出流程消费。

本规范只定义"怎么画、怎么导入、怎么进场景树";画什么、什么调调,以项目 `STYLE-BIBLE.md` 为准。

---

## 2. 分层规则 → Godot 节点结构

任何 2D 游戏的画面都可归到这四层。**层是图形职责的划分,与具体游戏对象无关。**

| 层 | 职责 | Godot 落地 |
| --- | --- | --- |
| 背景层 | 地形、远景、氛围(不交互、不含玩法实体) | `TileMapLayer`+`TileSet`,或 `Sprite2D` / `Parallax2D`;低 `z_index` 或独立 `CanvasLayer`(layer<0) |
| 实体层 | 运行时存在、会动或可被作用的对象 | 各自独立 `.tscn`,运行时 `instantiate()`;父节点开 `y_sort_enabled` 做脚底排序 |
| 反馈层 | 瞬时视觉:命中、状态、范围、预警 | `GPUParticles2D` / `CPUParticles2D` / `Line2D` / 一次性 `AnimatedSprite2D` / 着色器;可独立开关 |
| UI 层 | HUD、按钮、图标、弹窗 | `Control` 树挂在高 `layer` 的 `CanvasLayer` 上 |

- **世界内排序**优先用父 `Node2D` 的 `y_sort_enabled`(按 Y 自动排),跨层再用 `z_index` / `z_as_relative`。
- **UI 永远放独立 `CanvasLayer`**,不随 `Camera2D` 移动/缩放,恒在世界之上。

---

## 3. 核心原则:基础素材只承载"固有身份",运行时状态一律不烘焙

这是全文最重要的一条。基础图 = `region` / `SpriteFrames` 里那一帧的样子;**其余一切随状态
变化的东西都是节点或材质参数,绝不画进 PNG**。Godot 对这些状态几乎都有现成机制:

| 运行时状态(禁止烘焙进素材) | Godot 运行时实现 |
| --- | --- |
| 受击闪白 / 状态染色(中毒、冰冻、灼烧) | `modulate` / `self_modulate` + `Tween` 或 `AnimationPlayer` |
| 左右朝向 | `flip_h`(**不要画两套方向**) |
| 血条 / 进度 / 护盾 | 子节点 `TextureProgressBar` 或 `_draw()` |
| 选中框 / 范围圈 / 吸附环 | 独立可开关节点、`Line2D`,或 `_draw()`,**不进底图** |
| 等级 / 数字 / 冷却 / 禁用态 | 子 `Label` 或着色器 uniform,运行时设置 |
| 描边 / 外发光(高亮时) | `CanvasItemMaterial` 着色器,运行时切 uniform |

> 一句话:**底图只画"它本来是什么";"它现在处于什么状态"全是运行时叠加。**

---

## 4. 导入设置规范〔EI〕

Godot 在导入时就决定了素材的画质与体积。**每类素材统一导入预设,避免逐张手调出现不一致**
(这是统一性的工程根基)。

### 4.1 项目级默认(Project Settings)
- `rendering/textures/canvas_textures/default_texture_filter`:
  - 像素风 → **Nearest**(关线性过滤,避免模糊)。
  - 平滑风 → **Linear**。
  - 个别节点用 `CanvasItem.texture_filter` 覆盖。
- 选像素风还是平滑风**先定死**,它决定下面整套预设。

### 4.2 导入预设(Import 面板,按类别统一)
| 类别 | Compress | Mipmaps | Filter | 其他 |
| --- | --- | --- | --- | --- |
| 2D 精灵 / UI(像素风) | **Lossless** | 关 | Nearest | 确认 Filter=Nearest 且无 Mipmaps,否则缩放发糊 |
| 2D 精灵 / UI(平滑风) | **Lossless** | 大量缩放再开 | Linear | **开 `Fix Alpha Border`**,消除透明边暗/彩边 |
| 核心图集 / 大图 | **Lossless** | 关 | 跟随风格 | 禁止 VRAM 压缩破坏锐度 |
| 仅 3D 用贴图 | VRAM Compressed | 视情况 | Linear | 2D 一般不用 |

- 改完一类预设后用「Reimport」批量套用,或「Set as Default for ...」。

### 4.3 版本控制
- **每个资源旁的 `*.import` 必须提交**(如 `hero.png.import`),否则他人/CI 拉取后导入设置丢失。
- `.godot/`(含导入缓存)**加入 `.gitignore`**,不提交。
- `export_presets.cfg` 提交;其中密钥类字段不要提交明文。

### 4.4 逻辑分辨率与拉伸
- Project Settings → Display → Window → Size:`viewport_width/height` = `<逻辑分辨率,如 1280×720>`。
- Stretch:`mode = canvas_items`(推荐,平滑缩放)或 `viewport`(像素完美);`aspect = keep`/`expand` 按项目定。
- 背景按逻辑分辨率制作,运行时铺满;不要在素材里处理多分辨率。

---

## 5. 命名与目录治理(`res://` 范式)

### 5.1 源文件 ≠ 运行时文件(用 `.gdignore` 强制隔离)
| 路径(示例) | 用途 | 规则 |
| --- | --- | --- |
| `res://assets/...` | 运行时素材 | 只放被场景实际引用的资源 |
| `res://assets/sprites/` | 精灵 / 图集 PNG | 配套 `AtlasTexture`/`SpriteFrames` `.tres` |
| `res://assets/ui/` | UI 图、`Theme`、`NinePatchRect` 底图 | 不烘焙文字 |
| `res://_source/` | **源文件**(.aseprite/.psd/.kra/.wav) | 放空文件 `.gdignore`,Godot 不导入、不导出 |

> `.gdignore`:在任意文件夹放一个名为 `.gdignore` 的空文件,Godot 跳过整个文件夹。
> 这是把源图/PSD/WAV 留在仓库、又不进运行时/导出包的官方做法。

### 5.2 命名约定(稳定性的第一道闸)
- **全小写 `snake_case`**,明确类型:`<前缀>_<对象>_<变体>.<扩展名>`,如 `hero_idle.png`、`icon_chain.png`、`bg_riverside_01.png`。
- **强制小写**:Godot 导出到 Linux/Web 时路径**大小写敏感**,不一致会在这些平台加载失败。
- 禁止空格、非 ASCII、`final_final` 类后缀、生成器随机串。
- 场景 `.tscn`;资源 `.tres`(文本,可 diff,推荐)/`.res`(二进制,更小)。
- **命名一旦被场景引用就别改**——改名级联成断引用。先想好再落盘。

---

## 6. 按图形功能的素材规格

> 不按"游戏对象"(敌人/炮塔/Boss…)分类——不是所有游戏都有这些。按**图形在画面里的功能角色**
> 分。先给通用骨架,再举五个几乎所有 2D 游戏都会遇到的功能角色。
> **用法:把你游戏里的具体对象映射到这些功能角色,按需增删,不要为玩法专属概念新开一类。**

### 6.0 通用规格骨架(任意图形对象都套这个)
1. **功能定位**:它在画面里扮演什么图形角色(前景/背景/反馈/界面)。
2. **可读性要求**:在 `<逻辑分辨率>` 和最小显示尺寸下要能被一眼识别成什么。
3. **固有身份 vs 运行时状态**:必含(身份)/ 不得含(运行时状态,见 §3)。
4. **锚点与朝向**:`centered`/`offset`(脚底或中心)、默认朝向、是否 `flip_h` 镜像。
5. **状态与变体**:`SpriteFrames` 动画名 / 跨状态不变量。
6. **Godot 落地**:节点 + 资源类型。

### 6.1 可动前景元素(会动、有状态、按需朝向)
- 透明 PNG,不带色键底、文字、对话框;运行时只加载已抠图透明 PNG。
- 朝向用 `flip_h` 复用;服饰文字/非对称标志镜像后不能出错。状态(受击/染色/血条)全运行时叠加,见 §3。
- **Godot 落地**:独立 `.tscn`;`AnimatedSprite2D`(+`SpriteFrames`)或 `Sprite2D`+`AnimationPlayer`;
  需碰撞/被作用时配 `Area2D` / `CharacterBody2D`;血条为子 `TextureProgressBar`。

### 6.2 静态背景 / 环境元素(铺底、不交互)
- 固定 `<逻辑分辨率>`,可直接铺满;**无 UI、文字、玩法实体、血条、范围、选中、调试标记**。
- 核心地标是清晰视觉锚点;主路径/可活动区视觉连续,两侧留运行时承载空间。
- **Godot 落地**:整图 → `Sprite2D`(或多层 `Parallax2D` 做视差),低 `z_index` 或 layer<0;
  拼块 → `TileMapLayer`+`TileSet`(瓦片在 `_source` 出图,`TileSet` 里切);背景不开碰撞、不混实体。

### 6.3 瞬时反馈元素(特效:命中 / 状态 / 范围 / 预警)
- 优先运行时绘制/粒子,复杂纹理才出图;只表达"这次发生了什么",**不承担数值/冷却/等级/血量**。
- **预警先于命中**;范围提示只在相关对象被选中时显示;不长时间遮挡关键路线/关键对象。
- 命中闪白统一走目标的 `modulate`;同屏密集时透明度/长度/粒子量可控。
- **Godot 实现手段表**(按反馈形态选,与玩法无关):

| 反馈形态 | Godot 实现 | 备注 |
| --- | --- | --- |
| 直线 / 抛射 | 投射物 `.tscn`(`Sprite2D`+`Area2D`),按 `rotation` 对齐方向 | 默认朝向写进规格 |
| 链条 / 光束 / 牵引 | `Line2D`(多点、贴图、`width_curve`) | 目标切换清空点列,避免残留 |
| 持续区域(火/雾/毒) | `GPUParticles2D`+`Area2D`,或着色器面片 | 边缘柔和,中间不遮对象 |
| 扇形 / 波纹 | 着色器面片 或 `_draw()` | 预警色与命中色用不同 uniform |
| 一次性爆点 / 闪光 | `AnimatedSprite2D` 播完 `queue_free()` | 贴图按 §4 出透明 PNG,标注朝向锚点 |

### 6.4 界面元素(UI / 图标)
- 简洁图形,**不把文字烘焙进图片**;图标小尺寸可读,强轮廓高对比。
- 冷却/次数/禁用/选中由运行时绘制,不导出多份带数字的图。
- **Godot 落地**:
  - 文字一律 `Label`/`RichTextLabel`,绝不进图标 PNG。
  - 可拉伸面板/按钮底用 `NinePatchRect`(切九宫格,留好 `patch_margin`)。
  - 统一外观维护在 `Theme`(`.tres`),按钮态(normal/hover/pressed/disabled)用 `StyleBox`,不出多张图。
  - 冷却遮罩用 `TextureProgressBar`(径向)或着色器。

### 6.5 动画
- 首版可用运行时位移/缩放/`flip`/`modulate`/拉伸做"假动画"——即 `AnimationPlayer` 动
  `position`/`scale`/`modulate`/`rotation`,先把手感跑起来。
- 帧动画:状态先少后多,优先 `idle/move/action/hit/death`;脚底锚点、身体中心、阴影稳定;
  每帧留透明边距,附加物/光效不被裁切。
- **Godot 落地**:帧动画 → `SpriteFrames`(`.tres`)挂 `AnimatedSprite2D`,每个动画设 `loop`、`speed`;
  网格图集 → `hframes`/`vframes`/`frame` 或 `region_rect`;属性动画/混合 → `AnimationPlayer`、`AnimationTree`。
  帧宽高、帧数、`fps`、锚点、`loop` 写入资源或接入说明。

---

## 7. 运行时接入与构建校验〔EI〕

- 新图集/帧动画必须建好对应 `AtlasTexture` / `SpriteFrames` `.tres` 并被场景引用;不留无引用的孤儿资源。
- 新实体以独立 `.tscn` 注册;运行时 `preload()`(路径常量)或 `load()`(动态)实例化。
- 资源加载失败要优雅降级:返回安全场景并给可重试提示,**不 crash**(`load()` 返回 null 要判空)。
- 源文件夹用 `.gdignore` 排除,既不导入也不进导出包;运行时目录只留被引用资源。
- 导出用 Export 预设;Resources 过滤设「Export selected + dependencies」只打包引用到的资源。

改素材或接入后,本地/CI 跑一次校验:
```bash
godot --headless --import                          # 无头重导入,捕获导入错误
godot --headless --quit-after 2                    # 可选:触发脚本/场景加载期错误
godot --headless --check-only --script res://path/to/script.gd   # 可选:单脚本语法检查
```

---

## 8. 交付模板

### 8.1 单个素材(通用)
```text
素材名：
功能角色（前景实体/背景/反馈/界面）：
用途：
res:// 运行时路径：
源文件路径（_source/，.gdignore）：
画布/帧尺寸：
游戏内显示尺寸：
导入预设（Compress/Filter/Mipmaps/Fix Alpha Border）：
透明背景：
Godot 节点/资源（Sprite2D / AnimatedSprite2D+SpriteFrames / TextureRect…）：
锚点（centered/offset，脚底或中心）：
默认朝向 & 是否 flip_h 镜像：
必须包含（固有身份）：
不得包含（运行时状态清单，见 §3）：
状态/变体（SpriteFrames 动画名）：
验收方式：
```

### 8.2 背景
```text
场景 / 区域：
res:// 运行时路径：
画布尺寸：<逻辑分辨率>
拉伸模式（canvas_items/viewport）：
Godot 落地（Sprite2D / Parallax2D / TileMapLayer+TileSet）：
核心地标 / 视觉锚点：
主路径 / 可活动区描述：
运行时实体承载区域：
不得烘焙（UI/文字/实体/血条/范围/标记）：
加载/降级策略：
验收方式：
```

---

## 9. 验收清单

- [ ] 在 `<逻辑分辨率>` 下,前景实体、背景装饰、反馈、界面互不误读;最小显示尺寸下仍可辨认。
- [ ] **任一基础素材不含运行时状态**(血条/范围/数字/选中/状态特效)——它们都应是节点 / `modulate` / `_draw()`。← §3 总检查
- [ ] 背景层无 UI、文字、玩法实体、血条、范围圈、调试标记。
- [ ] 透明 PNG 无色键残留、无毛边:平滑风已开 `Fix Alpha Border`;像素风已确认 `Filter=Nearest` 且无 Mipmaps 发糊。
- [ ] 镜像方向用 `flip_h`,未冗余画左右两套(或已在元数据注明必须单独画的例外)。
- [ ] UI 文字走 `Label`/`Theme`,未烘焙进图标;可拉伸件用 `NinePatchRect`。
- [ ] 文件名全小写 `snake_case`,无空格/非 ASCII(Linux/Web 导出大小写安全)。
- [ ] 源文件位于带 `.gdignore` 的 `_source/`,未进运行时/导出包。
- [ ] 〔EI〕所有资源的 `*.import` 已提交;`.godot/` 已 gitignore。
- [ ] 〔EI〕改素材后 `godot --headless --import` 无导入报错;改脚本后语法检查通过。
