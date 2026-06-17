---
artifact: IMAGE-PROMPTS
feature: 01-floating-window-shell
role: Image Prompt
status: accepted
updated: 2026-06-17
inputs: [ASSET-SPEC.md, STYLE-BIBLE.md, style-basic-2d.md, project-context.md, IMAGE-PROMPT-PREFIX.md]
next: Engine Integrator
---

# IMAGE-PROMPTS — 悬浮窗外壳

> 已编译 01 全部 3 件占位素材:主角 / 两侧背景 / 收起 handle。
> 成品 prompt 已内联完整四段前缀 + 具体要求,可直接整段粘进 image2。
>
> **进度(2026-06-17):** 三件均已生图、按各自 Post-gen 处理并通过 image-prompt 角色的技术预检
> (尺寸/透明/格式客观达标):
> - `hero_warrior_placeholder.png` → 128×160 / 32bppArgb 带 alpha ✓
> - `bg_strip_placeholder.png` → 256×250 / 24bppRgb 全图不透明 ✓(左右接缝平均 RGB 差 ~17.5,主观项留 Art Spec 判)
> - `icon_handle_placeholder.png` → 64×64 / 32bppArgb 带 alpha ✓
> 正式验收(ACCEPTANCE.md,含主观项)由 Art Spec 角色出。

## 项目前缀(锁定,来自 IMAGE-PROMPT-PREFIX.md,逐字复用)
- ① Art style: hand-drawn 2D cartoon illustration ... (见前缀文件 §①)
- ② Visual reference: MapleStory 手绘 2D 神韵 ... (见前缀文件 §②)
- ③ Technical: smooth 非像素、为下采样而高清生成 ... (见前缀文件 §③)

---

## hero_warrior_placeholder — 角色:主区占位战士
- **类别:** 角色 character → 默认排除:no other characters, no background scenery, no UI or text(透明背景)。
- **本 asset 追加排除:** full body fully visible with feet at the very bottom edge; facing right; one single neutral standing idle pose; no asymmetric text or emblem that would look wrong when mirrored (flip_h).

- **Prompt (EN) —— 整段可直接粘贴:**
> Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines and soft cel shading, rounded chibi proportions (large head-to-body ratio), side-view (side-scroller) perspective; a warm, high-value, low-saturation cozy storybook palette (exact hex TBD); smooth painterly rendering — NOT pixel art, no hard pixelated or aliased edges, no harsh gradient-as-texture. Visual reference: in the visual spirit of MapleStory's hand-drawn 2D look, capturing its cute rounded chibi character proportions, clean readable silhouettes, and warm cheerful storybook mood, rendered as an original work — do not copy any specific copyrighted character, logo, or scene. Technical: render on a 1024×1024 canvas at high, crisp resolution intended for clean high-quality (smooth, non-pixel) downscaling to the game's in-window character size (~128×160 tall); transparent background (PNG alpha); single subject centered at a consistent scale. Exclusions: no other characters, no background scenery, no UI or text; isolated on a clean transparent background; full body fully visible with the feet at the very bottom edge of the frame; facing right; a single neutral standing idle pose; no asymmetric text or emblem that would look wrong when mirrored. Subject: a cute original chibi warrior hero — stocky, friendly, approachable proportions, simple warm-toned plate-and-leather armor, holding a short sword in the right hand and a small round shield in the left, calm confident idle stance, standing flat on an implied ground line, centered in frame, isolated on transparent background.

- **Canvas / size:** 1024×1024,透明背景开。
  (asset 比例 128:160 = 0.8,落在近正方形区间 → 1024×1024;不用竖向画布。)
- **Post-gen 处理(中文):**
  1. 生成后若有杂底/阴影投影,清成纯透明;确认是干净 alpha。
  2. 居中裁成 **4:5** 比例(从 1024×1024 取 819×1024,保证脚底贴下边、左右留匀边)。
  3. **平滑高质量**下采样(Lanczos/Area,**非最近邻**——本作是手绘平滑风,不是像素)到 **128×160**。
  4. 命名 `hero_warrior_placeholder.png`,放 `res://assets/sprites/placeholder/`。
  5. 回报给 Art Spec 对照 ASSET-SPEC §5 验收(尺寸 128×160 / 透明 / 脚底居中 / 单张静态 / 朝右)。

## bg_strip_placeholder — 背景:主区两侧延展的占位底
- **类别:** 背景/场景 background/env → 默认排除:no characters, no foreground props, no UI or text(不透明、满底)。
- **本 asset 追加排除:** low-contrast, low-detail ambient only; **horizontally seamless / tileable**(左右边缘相接可重复);nothing in sharp focus.

- **Prompt (EN) —— 整段可直接粘贴:**
> Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines and soft cel shading, rounded chibi proportions (large head-to-body ratio), side-view (side-scroller) perspective; a warm, high-value, low-saturation cozy storybook palette (exact hex TBD); smooth painterly rendering — NOT pixel art, no hard pixelated or aliased edges, no harsh gradient-as-texture. Visual reference: in the visual spirit of MapleStory's hand-drawn 2D look, capturing its cute rounded chibi character proportions, clean readable silhouettes, and warm cheerful storybook mood, rendered as an original work — do not copy any specific copyrighted character, logo, or scene. Technical: render on a 1024×1024 canvas at high, crisp resolution intended for clean high-quality (smooth, non-pixel) downscaling to a small repeating background tile (~256×250); single coherent scene at a consistent scale. Exclusions: no characters, no people, no creatures, no foreground props, no UI or text; an OPAQUE, full-bleed background (NOT transparent); a low-contrast, low-detail soft ambient backdrop with nothing in sharp focus; composed to be HORIZONTALLY SEAMLESS and tileable, so the left and right edges match when repeated side by side. Subject: a gentle warm ambient backdrop — a soft cozy town-and-outdoor atmosphere with muted, blurred distant shapes (soft sky, faint far scenery), calm and unobtrusive, meant to sit quietly behind the play area and repeat horizontally.

- **Canvas / size:** 1024×1024,**不透明**(背景满底)。
  (asset 比例 256:250 ≈ 1.0,近正方形 → 1024×1024。)
- **Post-gen 处理(中文):**
  1. **平滑高质量**下采样(Lanczos/Area)到 **256×250**。
  2. **做无缝平铺**:水平 offset 50% 后修接缝(image2 不保证真无缝,通常需手动 heal/克隆修一遍),
     再并排平铺检查左右边缘看不出接缝。
  3. 不透明、无 alpha;命名 `bg_strip_placeholder.png`,放 `res://assets/sprites/bg/`。
  4. 回报给 Art Spec 对照 ASSET-SPEC §5 验收(256×250 / 左右无缝 / 满底无 UI 文字实体)。

## icon_handle_placeholder — 图标:收起态屏幕边缘 handle
- **类别:** 图标/UI icon → 默认排除:no photorealistic detail, no background, flat, no extra text(透明背景)。
- **本 asset 追加排除:** bold clean outline; readable at small size (down to ~32px); no letters or numbers.

- **Prompt (EN) —— 整段可直接粘贴:**
> Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines and soft cel shading, rounded chibi proportions (large head-to-body ratio), side-view (side-scroller) perspective; a warm, high-value, low-saturation cozy storybook palette (exact hex TBD); smooth painterly rendering — NOT pixel art, no hard pixelated or aliased edges, no harsh gradient-as-texture. Visual reference: in the visual spirit of MapleStory's hand-drawn 2D look, capturing its cute rounded chibi character proportions, clean readable silhouettes, and warm cheerful storybook mood, rendered as an original work — do not copy any specific copyrighted character, logo, or scene. Technical: render on a 1024×1024 canvas at high, crisp resolution intended for clean high-quality (smooth, non-pixel) downscaling to a small icon (~64×64); transparent background (PNG alpha); single subject centered at a consistent scale. Exclusions: no photorealistic detail, no background scenery, no characters, flat and simple, no extra text, no letters or numbers; isolated on a clean transparent background; a bold clean outline that stays readable when shrunk to about 32px. Subject: a minimal cute emblem icon — a small rounded shield or little party crest bearing one simple symbol, warm tones, bold readable outline, flat shapes, centered, isolated on transparent background.

- **Canvas / size:** 1024×1024,透明背景开。
  (asset 比例 64:64 = 1.0,正方形 → 1024×1024。)
- **Post-gen 处理(中文):**
  1. 清干净 alpha(确认无杂底)。
  2. **平滑高质量**下采样(Lanczos/Area)到 **64×64**;在 32px 缩略下确认仍可辨认。
  3. 命名 `icon_handle_placeholder.png`,放 `res://assets/sprites/placeholder/`。
  4. 回报给 Art Spec 对照 ASSET-SPEC §5 验收(64×64 / 透明 / 32px 可读 / 无烘焙文字)。

## Flags
- ① 调色板 hex 未锁(STYLE-BIBLE TODO):三条 prompt 均用描述性暖色调替代。正式美术阶段补 hex 后,
  应更新 IMAGE-PROMPT-PREFIX.md 的 ① 并重生以求精确一致。
- bg_strip 的"无缝平铺":image2 不保证真无缝,Post-gen 几乎一定要手动修一遍接缝;若反复修不平,
  退路是改用纯色/柔和渐变占位底(回 Art Spec 调 spec)。
