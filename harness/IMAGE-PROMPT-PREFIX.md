updated: 2026-06-17

# IMAGE-PROMPT-PREFIX(项目级四段前缀 · 锁定)

> 每条喂 image2 的 prompt 都 = 本文件的 ①②③ 前缀(逐字复用)+ ④ 排除项 + 该 asset 的具体要求。
> ①②③ 全项目逐字一致,保证跨次生图风格稳定;**只在你明确要求时才改**(改它=改全项目观感)。
> 状态:占位阶段锁定。**已知缺口:① 调色板 hex 尚未在 STYLE-BIBLE 锁定**,暂用描述性色调,
> 待正式美术补 hex 后回来更新本前缀并 bump updated。

## ① 风格锚定 / Style anchor(英文,逐字复用)
Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines and soft cel shading, rounded chibi proportions (large head-to-body ratio), side-view (side-scroller) perspective; a warm, high-value, low-saturation cozy storybook palette (exact hex TBD); smooth painterly rendering — NOT pixel art, no hard pixelated or aliased edges, no harsh gradient-as-texture.

## ② 参考锚定 / Visual reference(英文,逐字复用)
Visual reference: in the visual spirit of MapleStory's hand-drawn 2D look, capturing its cute rounded chibi character proportions, clean readable silhouettes, and warm cheerful storybook mood, rendered as an original work — do not copy any specific copyrighted character, logo, or scene.

## ③ 技术约束 / Technical(英文,逐字复用;单 asset 精确画布/比例/透明在具体要求里覆盖)
Technical: render on the chosen fixed canvas at high, crisp resolution intended for clean HIGH-QUALITY (smooth, non-pixel) downscaling to the game's in-window display sizes (main play area 800×250; characters shown around 128×160 tall); transparent background (PNG alpha) unless stated otherwise; single subject centered at a consistent scale.

## ④ 排除项类别表 / Exclusions(按 asset 大类查;单 asset 具体排除项接在默认值后)
| asset 大类 | 默认排除项 ④(正面陈述) | 默认背景 |
|---|---|---|
| 角色 character | no other characters, no background scenery, no UI or text | transparent |
| 道具/物品 prop/item | no characters or people, no background, single isolated object | transparent |
| 技能特效 VFX | no characters, no background, no UI — effect only | transparent |
| 背景/场景 background/env | no characters, no foreground props, no UI or text | opaque, full-bleed |
| 图标/UI icon/UI | no photorealistic detail, no background, flat, no extra text | transparent |
| 地块 tileset/tile | no characters, no baked lighting or shadows, seamless/tileable | per use |
