updated: 2026-06-17

# 图片后处理规格表(image2 → 游戏素材)

> **这是什么**:把 image2(gpt-image)的原始输出加工成可入库素材的**统一后处理规范**。
> image2 只能出三种固定画布(1024×1024 / 1024×1536 / 1536×1024),所以一律
> **"大图生成 → 裁比例 → 降采样到目标像素"**。本表锁定每类素材该处理成什么规格。
> 本作为**平滑手绘风(非像素)** → 降采样一律用 **Lanczos / Area**,**禁用最近邻**。
> (像素风项目才用最近邻;见 style-basic-2d §4。)

## A. 通用三步流水线
1. **去背 / 定透明**:该透明的(角色/图标/特效)抠成干净 alpha,导出 **32bpp PNG(带 alpha)**;
   背景类则保持**不透明 24/32bpp**、满底无 alpha。
2. **裁比例**:按目标 W:H 居中裁(角色脚底贴下边;图标居中)。
3. **降采样**:Lanczos/Area 平滑缩到目标像素;**不要**最近邻(会糊/锯齿,本作非像素)。

## B. 画布选择(image2 原图,按目标长宽比就近选)
| 目标比例 W/H | image2 画布 | 典型素材 |
|---|---|---|
| 0.8 – 1.25(近正方) | 1024×1024 | 角色、道具、图标、近方背景块 |
| < 0.8(竖向) | 1024×1536 | 立绘、竖向 UI |
| > 1.25(横向) | 1536×1024 | 横版背景、横幅 |

## C. 各类素材目标规格
| 素材类别 | 透明 | 像素格式 | 降采样滤镜 | 特殊处理 | 锚点 | 目录(res://) |
|---|---|---|---|---|---|---|
| 角色 character | 是 | 32bpp PNG +alpha | Lanczos/Area | 裁全身、脚底贴下边、朝右 | 脚底居中 | `assets/sprites/...` |
| 道具/物品 prop | 是 | 32bpp PNG +alpha | Lanczos/Area | 单物居中、去背 | 居中 | `assets/sprites/...` |
| 技能特效 VFX | 是 | 32bpp PNG +alpha | Lanczos/Area | 仅特效、去背 | 按用途 | `assets/sprites/fx/` |
| 背景/场景 bg | **否** | 24/32bpp 不透明 | Lanczos/Area | 满底;横向铺需**左右无缝** | 左上(0,0) | `assets/sprites/bg/` |
| 图标/UI icon | 是 | 32bpp PNG +alpha | Lanczos/Area | 小尺寸可读、无烘焙文字 | 居中 | `assets/ui/` 或 `sprites/` |
| 地块 tile | 视用途 | 视用途 | Lanczos/Area | **四向/水平无缝**、无烘焙光影 | 按 TileSet | `assets/sprites/tiles/` |

## D. 无缝平铺(背景/地块)补充
- image2 **不保证**真无缝。流程:降采样到目标尺寸 → 水平(必要时含竖直)offset 50% →
  手动 heal/克隆修接缝 → 并排平铺肉眼检查左右(上下)边缘。
- 反复修不平的退路:改用纯色 / 柔和渐变占位底(回 Art Spec 调 ASSET-SPEC)。

## E. 命名与归档(每件都遵守)
- 文件名全小写 `snake_case`,无空格/非 ASCII;占位素材名含 `placeholder` 便于日后替换。
- 存**已处理到目标像素**的成品(不是 1024 原图)。1024 原图要留则丢 `_source/`(带 `.gdignore`)。
- 导入设置(Lossless / Linear / Mipmaps off / 开 Fix Alpha Border)属 Engine Integrator,不在本表。

## F. 当前功能 01 的三件目标(示例)
| 文件名 | image2 画布 | 裁→目标像素 | 透明 | 目录 |
|---|---|---|---|---|
| `hero_warrior_placeholder.png` | 1024×1024 | 裁 4:5(819×1024)→ **128×160** | 是 | `assets/sprites/placeholder/` |
| `bg_strip_placeholder.png` | 1024×1024 | → **256×250**,做水平无缝 | 否 | `assets/sprites/bg/` |
| `icon_handle_placeholder.png` | 1024×1024 | → **64×64**(32px 可读) | 是 | `assets/sprites/placeholder/` |
