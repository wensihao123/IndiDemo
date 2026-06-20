---
artifact: IMAGE-PROMPTS
feature: 10-ingame-flow-nav
role: Image Prompt
status: draft
updated: 2026-06-20
inputs: [ASSET-SPEC.md, STYLE-BIBLE.md, style-basic-2d.md, IMAGE-PROMPT-PREFIX.md]
next: Engine Integrator
---

# IMAGE-PROMPTS — 城镇枢纽 + 五子板块(全局 UI·juice 轮)

> 把 `ASSET-SPEC.md` 的 25 件 brief 编译成**可直接粘给 image2(gpt-image)的英文成品 prompt**。
> 每条 = **项目四段前缀 ①②③(逐字复用,锁在 `IMAGE-PROMPT-PREFIX.md`)+ ④ 排除项 + 该 asset 具体要求**。
> image2 只出三种画布(1024×1024 / 1024×1536 / 1536×1024);小图一律**大图生成→高质量平滑下采样**到 ASSET-SPEC 精确像素。
> **全轮非像素**(平滑手绘),透明背景须显式点明;九宫格件**四角可花、四边须平铺无缝**;**任何 asset 都不烘焙文字/数字/状态**。

---

## 锁定前缀(来自 IMAGE-PROMPT-PREFIX.md,每条 prompt 已内联,勿改)

**①+②+③** =
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown line color #3a2e2a, not pure black) and soft single-layer cel shading, rounded chibi proportions (large head-to-body ratio), side-view (side-scroller) perspective; a warm, high-value, low-saturation cozy storybook palette of #c98a5e (warm wood) / #f5e9d6 (cream) / #7fb069 (fresh green) / #4a7c59 (deep green) / #e8943c (warm orange accent) / #2b2536 (deep UI base); smooth painterly rendering — NOT pixel art, no hard pixelated or aliased edges, no harsh gradient-as-texture. Visual reference: in the visual spirit of MapleStory's hand-drawn 2D look, capturing its cute rounded chibi character proportions, clean readable silhouettes, and warm cheerful storybook mood, rendered as an original work — do not copy any specific copyrighted character, logo, or scene. Technical: render on the chosen fixed canvas at high, crisp resolution intended for clean HIGH-QUALITY (smooth, non-pixel) downscaling to the game's in-window display sizes; transparent background (PNG alpha) unless stated otherwise; single subject centered at a consistent scale.`

> 下面每条 **Prompt (EN)** 已把上面这段 ①②③ 完整内联在最前,再接 ④ 排除项 + 具体要求 —— **整块可直接复制粘贴**。

---

## 通用 Post-gen 纪律(所有件适用,再叠各件特例)
- image2 出大图 → 用**平滑(non-pixel)**重采样(Lanczos/双三次,**非**最近邻——本项目不是像素风)缩到 ASSET-SPEC 精确像素。
- 透明件:导出 PNG 带 alpha;清半透明毛边(EI 侧再开 `Fix Alpha Border`)。
- 九宫格件:缩到基准画布后,**自查四边在给定 `patch_margin` 下平铺无缝、四角花纹不落进中心可拉伸区**。
- 删掉模型可能自带的任何文字/水印/数字。

---

# A. 共用 UI 框架件 — `res://assets/sprites/ui/frame/`(九宫格,五板块复用)

## #1 frame_board — 板块主面板底框(核心 · 9-slice 96×96 / margin 24)
- **④ Exclusions:** no characters, no people, no text, no numbers, no icons inside, flat UI frame element, center left empty — corner ornament must NOT extend into the tileable center.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown line color #3a2e2a, not pure black) and soft single-layer cel shading, rounded chibi proportions (large head-to-body ratio), side-view (side-scroller) perspective; a warm, high-value, low-saturation cozy storybook palette of #c98a5e (warm wood) / #f5e9d6 (cream) / #7fb069 (fresh green) / #4a7c59 (deep green) / #e8943c (warm orange accent) / #2b2536 (deep UI base); smooth painterly rendering — NOT pixel art, no hard pixelated or aliased edges, no harsh gradient-as-texture. Visual reference: in the visual spirit of MapleStory's hand-drawn 2D look, capturing its clean readable silhouettes and warm cheerful storybook mood, rendered as an original work — do not copy any specific copyrighted character, logo, or scene. Technical: render on a 1024×1024 canvas at high, crisp resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no characters, no people, no text, no numbers, no icons inside, flat UI frame element, center left empty, corner ornament must not extend into the center. Subject: an ornate warm carved-wood rectangular UI board frame, like a cozy storybook bulletin-board, with delicate gold filigree flourishes only at the four corners and a thick warm-wood (#c98a5e) border edged in subtle warm-orange (#e8943c); the entire interior is a flat semi-transparent deep purple-grey (#2b2536 at ~92% opacity) empty fill; the border pattern along each straight edge is simple and seamlessly repeatable (no directional motif), restrained and not busy, so text placed on top later stays high-contrast and readable; centered, filling the canvas with a few px margin.`
- **Canvas / size:** 1024×1024, transparent (PNG alpha)
- **Post-gen:** 平滑缩到 **96×96**;切边设 `patch_margin=24`;自查四边平铺无缝、金花头只在四角不入中心;中心半透可透出底层。

## #2 frame_inset — 子区内嵌底(核心 · 9-slice 48×48 / margin 14)
- **④ Exclusions:** no characters, no text, no numbers, no icons, flat recessed UI inset, seamless tileable edges, corner detail must not enter the center.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown line color #3a2e2a, not pure black) and soft single-layer cel shading, rounded chibi proportions, side-view perspective; a warm, high-value, low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges, no harsh gradient. Visual reference: in the visual spirit of MapleStory's hand-drawn 2D look, clean readable silhouettes and warm cozy mood, original work — do not copy any copyrighted character or logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no characters, no text, no numbers, no icons, flat recessed UI inset panel, seamless tileable edges, corner detail must not enter the center. Subject: a smaller, darker recessed inner-panel frame for holding a grid or detail box, a slim carved-wood border with a thin warm-orange line, the interior a flat semi-transparent darker deep purple-grey (one shade deeper than #2b2536); low-key and subordinate so foreground content reads clearly; thin edges, simple seamlessly repeatable border, centered filling the canvas.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **48×48**;`patch_margin=14`;比 frame_board 更深一档、更窄边;四边平铺无缝。

## #3 banner_title — 顶部标题牌(核心 · 9-slice 80×40 / margin 28)
- **④ Exclusions:** no text, no letters, no numbers, no characters, center span left blank for runtime label, flat UI banner, horizontally tileable middle.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a, not pure black) and soft cel shading, rounded chibi proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory's hand-drawn 2D look, clean readable silhouettes, warm cheerful mood, original work — no copyrighted character or logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no text, no letters, no numbers, no characters, center span left blank for a runtime label, flat UI banner element, the middle section horizontally tileable. Subject: a centered horizontal title plaque / banner header, warm carved wood with gold scrollwork flourishes at the two ends and a clean flat blank middle span (cream #f5e9d6 or warm wood) where a title will be placed later; like a cozy storybook signboard; the end flourishes are decorative but restrained, the middle is plain and seamlessly stretchable; centered on the canvas.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **80×40**;`patch_margin=28`(两端花头计入切边);中段须可水平平铺、留白给运行时标题。

## #4 btn_normal — 通用按钮底(核心 · 9-slice 40×32 / margin 12)
- **④ Exclusions:** no text, no numbers, no icon, flat UI button base, stretchable, single button only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean readable shapes, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no text, no numbers, no icon, flat UI button base, stretchable, single button only. Subject: a cozy rounded-rectangle wooden UI button base in warm wood (#c98a5e) with a soft top highlight and a clean warm-brown outline, gentle and inviting, neutral resting state (no hover/pressed glow); the face is plain and stretchable for a 9-slice; centered on the canvas.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **40×32**;`patch_margin=12`;实心可读,无文字。

## #5 btn_primary — 主操作钮(核心 · 9-slice 40×32 / margin 12)
- **④ Exclusions:** no text, no numbers, no icon, flat UI button base, stretchable, single button only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean readable shapes, warm cheerful mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no text, no numbers, no icon, flat UI button base, stretchable, single button only. Subject: a bright primary call-to-action rounded-rectangle UI button base in warm orange (#e8943c) with a soft glossy top highlight and warm-brown outline, more vivid and eye-catching than a plain wood button (for confirm / start actions), neutral resting state; plain stretchable face for 9-slice; centered.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **40×32**;`patch_margin=12`;比 #4 更亮更醒目(暖橙 CTA)。

## #6 tab_on — 选中态页签(核心 · 9-slice 28×28 / margin 10)
- **④ Exclusions:** no text, no numbers, no icon, flat UI tab, top corners rounded, stretchable, single tab only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean shapes, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no text, no numbers, no icon, flat UI tab element, top corners rounded, stretchable, single tab only. Subject: a selected/active UI tab base, brightened warm wood (#c98a5e) with a raised lifted feel and a subtle warm-orange top edge, top corners rounded and bottom flush for joining a tab row; plain stretchable face; centered.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **28×28**;`patch_margin=10`;与 tab_off 成对(此为提亮上凸)。

## #7 tab_off — 未选态页签(核心 · 9-slice 28×28 / margin 10)
- **④ Exclusions:** no text, no numbers, no icon, flat UI tab, top corners rounded, stretchable, single tab only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean shapes, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no text, no numbers, no icon, flat UI tab element, top corners rounded, stretchable, single tab only. Subject: an unselected/inactive UI tab base, a desaturated darker muted wood that sits lower and recedes, no highlight, top corners rounded; plain stretchable face; centered. It should clearly read as dimmer and pushed-back versus the active tab.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **28×28**;`patch_margin=10`;去饱下沉、与 tab_on 余光可分。

## #8 slot_frame — 装备/物品槽(空槽,核心 · 定尺 44×44 / margin 14)
- **④ Exclusions:** no item inside, no characters, no text, no numbers, no rarity color (applied at runtime), neutral empty slot, single slot only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean readable shapes, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no item inside, no characters, no text, no numbers, no rarity color, neutral empty slot, single slot only. Subject: a rounded-square equipment/item slot frame, a carved wooden inset cell with a softly recessed darker interior and a clean neutral warm-brown border, empty and color-neutral so a rarity tint can be applied at runtime; cozy storybook UI; centered, filling most of the canvas.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **44×44**;`patch_margin=14`;中性无稀有度色、可运行时染。

## #9 slot_frame_sel — 槽选中态(核心 · 定尺 44×44 / margin 14)
- **④ Exclusions:** no item inside, no characters, no text, no numbers, no rarity color, single slot only — only the selection glow differs from #8.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean readable shapes, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no item inside, no characters, no text, no numbers, no rarity color, single slot only. Subject: the same rounded-square wooden item-slot frame as the neutral slot, but in its SELECTED state: ringed by a glowing warm-orange (#e8943c) highlight outline, the same recessed neutral interior; the orange selection glow is the only addition so it reads as "selected" at a glance; centered.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **44×44**;`patch_margin=14`;只比 #8 多一圈暖橙发光。

## #10 list_row — 列表行底(普通,核心 · 9-slice 24×28 / margin 9)
- **④ Exclusions:** no text, no numbers, no icon, flat UI list-row strip, semi-transparent, horizontally stretchable, single row only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean shapes, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no text, no numbers, no icon, flat UI list-row strip, semi-transparent, horizontally stretchable, single row only. Subject: a long thin horizontal list-row background strip for a member/stage list, very faint semi-transparent warm tint with a slim rounded warm-brown edge, low-key resting state; plain and horizontally stretchable for 9-slice; centered.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **24×28**;`patch_margin=9`;极淡半透,与 list_row_sel 成对。

## #11 list_row_sel — 列表行选中态(核心 · 9-slice 24×28 / margin 9)
- **④ Exclusions:** no text, no numbers, no icon, flat UI list-row strip, semi-transparent, horizontally stretchable, single row only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean shapes, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no text, no numbers, no icon, flat UI list-row strip, semi-transparent, horizontally stretchable, single row only. Subject: the same long thin horizontal list-row strip in its SELECTED state: a warm-wood (#c98a5e) highlighted fill with a bright warm-orange (#e8943c) accent color-bar along the left edge, clearly brighter than the resting row; plain stretchable middle; centered.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **24×28**;`patch_margin=9`;暖木高亮 + 左侧暖橙色条。

## #12 avatar_frame — 头像框(核心 · 定尺 48×48 / margin 14)
- **④ Exclusions:** no face inside, no character, no text, no numbers, center left transparent for a portrait, single frame only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean shapes, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling; transparent background (PNG alpha); single centered subject. no face inside, no character, no text, no numbers, center left fully transparent for a portrait, single frame only. Subject: a rounded-square / circular avatar portrait frame, carved warm wood with a thin delicate gold rim, the center fully transparent (just the empty ring/border) so a character portrait can sit inside; cozy storybook UI; centered, used at both small and large sizes.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **48×48**;`patch_margin=14`;中心透明留给头像;小/大头像共用按尺缩。

---

# B. 图标集 — `res://assets/sprites/ui/icons/`(基准 32×32,游戏内显示 16–24)

> 全部 **1024×1024 生成 → 缩到 32×32**;透明;暖棕描边 `#3a2e2a`(≈2px@32);一图一概念;圆润强轮廓高对比;**无字无数字**。
> 共同 ④:`no text, no numbers, no background, no characters (unless the concept is a figure), flat icon, single concept, bold readable silhouette at small size`。

### B1. 槽位/类型(核心,3)

## #B1-a icon_weapon — 武器·剑
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions, warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean readable silhouette, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling to a 32px game icon; transparent background (PNG alpha); single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a cute short sword with a warm-wood handle and a soft steel blade, a simple cozy game weapon icon, thick rounded outline, high contrast, centered, filling the icon area.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B1-b icon_armor — 护甲·胸甲
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions, warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean readable silhouette, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling to a 32px game icon; transparent background (PNG alpha); single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a rounded cute chest-plate / breastplate armor piece, soft steel with warm trim, a cozy game armor icon, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B1-c icon_accessory — 饰品·戒指/护符
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions, warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, clean readable silhouette, warm cozy mood, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling to a 32px game icon; transparent background (PNG alpha); single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a cute amulet / ring accessory with a small warm gem, a cozy game jewelry icon, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

### B2. 8 维属性(次要,8)— 简洁象征,可读优先

## #B2-a icon_stat_attack — 攻击(剑/拳)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean warm dark-brown #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a simple bold "attack power" symbol — a single upward sword (or a punching fist), warm and friendly, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B2-b icon_stat_hp — 生命(红心)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a plump rounded warm-red heart representing HP / vitality, soft and friendly, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B2-c icon_stat_atkspeed — 攻速(沙漏/快)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a cute hourglass with small motion/speed marks representing attack speed, warm tones, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B2-d icon_stat_armor — 护甲(盾)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a rounded sturdy shield representing armor / defense, soft steel with warm trim, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B2-e icon_stat_dodge — 闪避(残影/羽)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a light feather with a soft motion after-image swoosh representing dodge / evasion, airy and quick, warm tones, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B2-f icon_stat_crit — 暴击率(准星/星)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a bright sparkly star / crosshair-star representing critical-hit chance, cheerful warm-orange accent, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B2-g icon_stat_critmult — 暴伤(爆裂星)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a bursting impact star / explosive starburst representing critical-damage multiplier, more energetic than the plain crit star, warm-orange, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B2-h icon_stat_regen — 回血(心+绿叶/十字)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a warm-red heart paired with a small fresh-green leaf (or green plus/cross) representing health regeneration, gentle and restorative, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

### B3. 导航/操作(核心 8)

## #B3-a icon_menu — 菜单(☰ 三横)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a simple hamburger menu glyph — three stacked rounded horizontal bars in warm wood tone with a soft outline, cozy UI icon, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B3-b icon_settings — 设置(⚙ 齿轮)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a friendly rounded gear / cog representing settings, warm wood and soft steel, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B3-c icon_back — 返回(左弯箭头)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a rounded left-pointing back arrow, soft and chunky, warm wood tone, thick outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B3-d icon_bag — 背包
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a cute plump adventurer's backpack / pouch representing the bag, warm leather tones with a small buckle, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B3-e icon_enhance — 强化(铁锤+火星)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a cute blacksmith hammer with a couple of small warm-orange sparks representing enhance / upgrade, warm-wood handle, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B3-f icon_disassemble — 分解(碎裂/拆解)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a cracking / breaking-apart cube or shattering shard representing disassemble / salvage, small pieces splitting off, warm tones, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B3-g icon_power — 战力(盾叠交叉剑徽)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: a small heraldic emblem of a shield with two crossed swords representing combat power / battle rating, warm steel and wood, thick rounded outline, high contrast, centered.`
- **Canvas / size:** 1024×1024, transparent → 32×32

## #B3-h icon_depart — 出击(交叉双刀)
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth — NOT pixel art. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: 1024×1024 canvas, high resolution for smooth downscaling to a 32px icon; transparent background; single centered subject. no text, no numbers, no background, flat icon, single concept, bold readable silhouette at small size. Subject: two crossed blades / swords representing "depart to battle" / sortie, energetic and adventurous, warm steel, thick rounded outline, high contrast, centered. Keep it visibly distinct from the shield-and-swords power emblem (this one is just crossed blades, no shield).`
- **Canvas / size:** 1024×1024, transparent → 32×32

### B3 次要(可第二批)— `icon_sort / icon_lock / icon_check / icon_add_member / icon_continue / icon_material`
> 次要组(首版可用文字/纯色占位)。如出图,沿用上面 B 图标的同一前缀,Subject 各替换为:
- **icon_sort:** up/down sorting arrows pair（上下排序箭头）
- **icon_lock:** a chunky rounded padlock（圆润挂锁，锁定/未解锁）
- **icon_check:** a fresh-green check mark ✓（暖绿对勾，已通关）
- **icon_add_member:** a rounded frame with a plus and a small figure（圆框加号人形，添加成员）
- **icon_continue:** a looping circular arrow（循环箭头,继续挂机）
- **icon_material:** a single ore chunk / ingot, color-neutral so rarity tint applies at runtime（一块矿石/锭,中性可运行时染)
- **Canvas / size（每个）:** 1024×1024, transparent → 32×32

---

# C. 城镇枢纽场景 — `res://assets/sprites/town/`

## #13 bg_town — 城镇枢纽背景横幅(核心 · 800×250 满底)
- **④ Exclusions:** no characters, no foreground props, no UI, no text, no gameplay entities; opaque full-bleed background; low information, low contrast (it is a backdrop).
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions, side-view (side-scroller) perspective; warm high-value low-saturation cozy storybook palette of #c98a5e (warm wood) / #f5e9d6 (cream) / #7fb069 (fresh green) / #4a7c59 (deep green) / #e8943c (warm orange) / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges, no harsh gradient-as-texture. Visual reference: in the visual spirit of MapleStory's hand-drawn 2D town look, warm cheerful storybook mood, original work — do not copy any copyrighted scene. Technical: render on a 1536×1024 canvas at high resolution for smooth non-pixel downscaling to a wide 800×250 in-game banner; OPAQUE full-bleed background. no characters, no foreground props, no UI, no text, no gameplay entities; low information, low contrast as a backdrop. Subject: a wide, warm hand-drawn cozy town panorama — warm-wood cottages, a cobblestone path, distant soft hills under a gentle cream sky, dotted greenery and little flowers; calm and inviting; the composition reads as a horizontal strip with a plain middle band and edges that can be cropped left/right; deliberately soft and low-contrast so foreground buildings and UI placed on top stay readable.`
- **Canvas / size:** 1536×1024, **opaque** (no alpha)
- **Post-gen:** 中段裁成 **800×250**(3.2:1,左右可裁);平滑缩;确认低对比、无前景实体/文字。可另存 1600×250 @2x。

## #14 bld_forge — 打造建筑入口(核心 · 180×150 脚底居中 透明)
- **④ Exclusions:** no characters, no people, no text, no nameplate, no UI, single isolated building, transparent background, foot-centered.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D town look, warm cozy storybook mood, original work — no copyrighted scene. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling to a ~180×150 building sprite; transparent background (PNG alpha), the building's foot/base centered horizontally at the bottom. no characters, no people, no text, no nameplate, no UI, single isolated building. Subject: a cute cozy blacksmith forge building — a chimney with a soft warm wisp of smoke, an anvil and glowing warm-orange furnace fire visible, clearly reading as "the forge / crafting" at a glance; warm wood and stone; one self-contained building on transparent background.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 平滑缩到 **180×150**;脚底居中对齐;无名牌(运行时叠);剪影须与其余 3 建筑可区分。

## #15 bld_tavern — 酒馆建筑入口(核心 · 180×150 透明)
- **④ Exclusions:** no characters, no people, no text, no nameplate, no UI, single isolated building, transparent background, foot-centered.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D town look, warm cozy storybook mood, original work — no copyrighted scene. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling to a ~180×150 building sprite; transparent background (PNG alpha), building foot centered at the bottom. no characters, no people, no text, no nameplate, no UI, single isolated building. Subject: a warm cozy tavern building — wooden barrels by the door, a hanging mug/ale signboard (no letters on it), warm lamp light glowing in the windows, clearly reading as "tavern / resting spot" at a glance; warm wood; one self-contained building on transparent background.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **180×150**;脚底居中;招牌**不画字**;与其余建筑统一风格、剪影各异。

## #16 bld_party — 小队建筑入口(核心 · 180×150 透明)
- **④ Exclusions:** no characters, no people, no text, no nameplate, no UI, single isolated building, transparent background, foot-centered.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D town look, warm cozy storybook mood, original work — no copyrighted scene. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling to a ~180×150 building sprite; transparent background (PNG alpha), building foot centered at the bottom. no characters, no people, no text, no nameplate, no UI, single isolated building. Subject: a warm cozy little cottage / camp that reads as "the party's home base" — a hanging flag/banner, a small campfire or bench by the door, snug and welcoming; warm wood; one self-contained building on transparent background.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **180×150**;脚底居中;"队伍的家"感;剪影与铁匠铺/酒馆/城门可区分。

## #17 bld_depart — 出征建筑入口(核心 · 180×150 透明)
- **④ Exclusions:** no characters, no people, no text, no nameplate, no UI, single isolated structure, transparent background, foot-centered.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D town look, warm cozy storybook mood, original work — no copyrighted scene. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling to a ~180×150 structure sprite; transparent background (PNG alpha), structure foot centered at the bottom. no characters, no people, no text, no nameplate, no UI, single isolated structure. Subject: a town gate / signpost leading out to the wilds — wooden gate with fluttering pennants, a directional signpost, a glimpse of green fields beyond the gateway, clearly reading as "depart / set out to adventure" at a glance; warm wood; one self-contained structure on transparent background.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **180×150**;脚底居中;城门通向绿野远景;四建筑余光可分去向。

---

# D. 板块专属图 — `res://assets/sprites/town/`

## #18 portrait_warrior — 战士半身像(核心 · 128×128 透明)
- **④ Exclusions:** no frame, no border, no text, no numbers, no level, no UI, single character bust, transparent background.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean medium-weight outlines (warm dark-brown #3a2e2a) and soft cel shading, rounded chibi proportions (large head-to-body ratio), warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: in the visual spirit of MapleStory's cute chibi characters, warm friendly mood, original work — do not copy any copyrighted character. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling to a 128×128 portrait; transparent background (PNG alpha); single centered subject. no frame, no border, no text, no numbers, no level, no UI, single character bust. Subject: a cute Q-style warrior hero portrait, bust framing (chest up), face turned slightly to one side with a warm friendly expression, in light warrior gear; the same character as the in-combat warrior but in a portrait composition; centered, fits inside a circular avatar frame later.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **128×128**;胸口以上;与 `hero_warrior` 同角色;**不画框/Lv/数字**(框另出)。

## #19 portrait_lock — 未招募锁定剪影(次要 · 128×128 透明)
- **④ Exclusions:** no readable face, no text, no numbers, no frame, single silhouette, transparent background.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean outline, soft cel shading, rounded chibi proportions, cozy storybook feel; smooth — NOT pixel art, no aliased edges. Visual reference: MapleStory cute chibi silhouette, original work — no copyrighted character. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling to a 128×128 portrait; transparent background (PNG alpha); single centered subject. no readable face, no text, no numbers, no frame, single silhouette. Subject: a "not yet recruited" placeholder — the same bust framing as the warrior portrait but rendered as a flat grey desaturated silhouette with a small lock or question-mark symbol on it; mysterious and locked-feeling; centered.`
- **Canvas / size:** 1024×1024, transparent
- **Post-gen:** 缩到 **128×128**;与 portrait_warrior 同构图的灰阶剪影。

## #20 star_pip — 星级单颗(核心 · 24×24 透明)
- **④ Exclusions:** only ONE star, no text, no numbers, no background, flat icon, transparent.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean warm dark-brown #3a2e2a outline, soft cel shading, warm cozy storybook palette, warm-orange #e8943c fill; smooth — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: render on a 1024×1024 canvas at high resolution for smooth non-pixel downscaling to a 24×24 pip; transparent background (PNG alpha); single centered subject. only ONE star, no text, no numbers, no background, flat icon. Subject: a single plump rounded five-pointed star filled warm-orange (#e8943c) with a soft outline, cheerful, fully lit (lit/dim handled by runtime modulate); centered, filling the icon area.`
- **Canvas / size:** 1024×1024, transparent → 24×24
- **Post-gen:** 缩到 **24×24**;只出一颗、暖橙;亮暗交运行时 `modulate`。

## #21 arrow_upgrade — 升级箭头(次要 · 48×32 透明)
- **④ Exclusions:** no text, no numbers, single arrow, no background, flat icon, transparent.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon icon, clean #3a2e2a outline, soft cel shading, warm cozy storybook palette, warm-orange #e8943c; smooth — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D look, original work — no copyrighted logo. Technical: render on a 1536×1024 canvas at high resolution for smooth non-pixel downscaling to a wide 48×32 icon; transparent background (PNG alpha); single centered subject. no text, no numbers, single arrow, no background, flat icon. Subject: a chunky right-pointing upgrade/progression arrow in warm orange with a soft outline, conveying "level N to level N+1" advancement, friendly and clear; horizontally oriented, centered.`
- **Canvas / size:** 1536×1024, transparent → 48×32
- **Post-gen:** 裁/缩到 **48×32**(横向);暖橙递进;**无字**。

## #22 stage_preview_01 — 关卡 1 场景预览(次要 · 220×130)
- **④ Exclusions:** no enemies, no characters, no UI, no text, low-information scene backdrop only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean #3a2e2a outline and soft cel shading, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D scenery, warm cozy mood, original work — no copyrighted scene. Technical: render on a 1536×1024 canvas at high resolution for smooth non-pixel downscaling to a 220×130 preview thumbnail; background may be opaque or lightly transparent. no enemies, no characters, no UI, no text, low-information scene backdrop only. Subject: a small thumbnail-scale scene of a gentle forest trail — fresh-green (#7fb069) foliage, a soft dirt path, dappled light, calm and inviting (this is the "stage 1: forest path" preview); low information so an enemy sprite can be overlaid later; centered composition.`
- **Canvas / size:** 1536×1024, opaque/可半透 → 220×130
- **Post-gen:** 裁/缩到 **220×130**(1.69:1);低信息、无敌人/UI/文字(敌人运行时叠 `enemy_*`)。

## #23 stage_preview_02 — 关卡 2 场景预览(次要 · 220×130)
- **④ Exclusions:** no enemies, no characters, no UI, no text, low-information scene backdrop only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean #3a2e2a outline and soft cel shading, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D scenery, warm cozy mood, original work — no copyrighted scene. Technical: render on a 1536×1024 canvas at high resolution for smooth non-pixel downscaling to a 220×130 preview thumbnail; background may be opaque or lightly transparent. no enemies, no characters, no UI, no text, low-information scene backdrop only. Subject: a small thumbnail-scale scene of a more rugged, craggy terrain — rocky cliffs and deep-green (#4a7c59) brush, a slightly more perilous mood than the gentle forest, still warm storybook (this is the "stage 2" preview); low information so an enemy sprite can be overlaid later; centered.`
- **Canvas / size:** 1536×1024, opaque/可半透 → 220×130
- **Post-gen:** 裁/缩到 **220×130**;比 stage_01 更险峻;无敌人/UI/文字。

## #24 bg_tavern — 酒馆室内场景(次要 · 360×180)
- **④ Exclusions:** no text, no UI, no readable signage letters; opaque interior backdrop; foreground NPC may be present as scenery only.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean #3a2e2a outline and soft cel shading, side-view perspective; warm high-value low-saturation cozy storybook palette of #c98a5e / #f5e9d6 / #7fb069 / #4a7c59 / #e8943c / #2b2536; smooth painterly rendering — NOT pixel art, no aliased edges. Visual reference: MapleStory hand-drawn 2D interior, warm cozy mood, original work — no copyrighted scene. Technical: render on a 1536×1024 canvas at high resolution for smooth non-pixel downscaling to a 360×180 interior backdrop; opaque background. no text, no UI, no readable signage letters. Subject: a warm cozy tavern interior — a wooden bar counter, a friendly chibi barkeep behind it as scenery, ale barrels, warm lamp light and a snug atmosphere; serves as a "recruitment coming soon" placeholder backdrop; balanced low-key composition; centered.`
- **Canvas / size:** 1536×1024, opaque → 360×180
- **Post-gen:** 裁/缩到 **360×180**(2:1);占位升级用;招牌**无字**。

## #25 recruit_lock — 锁定招募位剪影(次要 · 80×120 脚底居中 透明)
- **④ Exclusions:** no readable face, no text, no numbers, no frame, single standing silhouette, transparent background, foot-centered.
- **Prompt (EN):**
`Art style: hand-drawn 2D cartoon illustration with clean outline, soft cel shading, rounded chibi proportions, cozy storybook feel; smooth — NOT pixel art, no aliased edges. Visual reference: MapleStory cute chibi silhouette, original work — no copyrighted character. Technical: render on a 1024×1536 canvas at high resolution for smooth non-pixel downscaling to a tall 80×120 sprite; transparent background (PNG alpha), figure foot centered at the bottom; single centered subject. no readable face, no text, no numbers, no frame, single standing silhouette. Subject: a "locked recruit slot" placeholder — a full standing chibi adventurer rendered as a flat grey desaturated silhouette with a small lock symbol on the chest, generic enough to stand in for warrior/archer/mage; mysterious locked feel; centered, standing pose.`
- **Canvas / size:** 1024×1536, transparent → 80×120
- **Post-gen:** 裁/缩到 **80×120**(竖向);灰剪影 + 胸前锁;3 招募位共用。

---

## 复用既有(本轮不重出)
- 出征**敌人预览** = 复用 02 的 `enemy_*`(8 张,`res://assets/sprites/enemies/`),运行时叠到 `stage_preview_*` 上。
- 战斗主区战士 = 复用 `hero_warrior`。
- **掉落预览物品图** = 复用本轮 B1 的 3 枚槽类型图标(`icon_weapon/armor/accessory`),稀有度运行时染边框(ASSET-SPEC §6 物品图标 flag)。

## 批次建议(若需分批出图,呼应 ASSET-SPEC §6)
1. **批 ①** A 框架件(#1–12)+ B 核心图标(B1 3 + B3 核心 8)——板块成形最小集。
2. **批 ②** C 城镇枢纽(#13–17)。
3. **批 ③** D 板块专属(#18–25)+ B2 属性 8 + B3 次要 6。

## Flags(编译侧)
- 全部 prompt 的 ①②③ 逐字取自 `IMAGE-PROMPT-PREFIX.md`(MapleStory 锚点 + 方案 A 暖木 palette);未改前缀。
- 九宫格件用方形 1024 生成,Post-gen 缩到基准画布后由 EI 在 Inspector 填 `patch_margin`(§1 值)——**切边是 EI 的事,出图阶段只保证四边可平铺、花纹只在四角**。
- 宽幅件(bg_town / arrow_upgrade / stage_preview_* / bg_tavern)用 1536×1024 生成后**裁中段**到目标比例;竖幅件(recruit_lock)用 1024×1536。
- image2 偶尔无视"透明"——若给了实底,Post-gen 抠图;§3 硬红线"无文字/数字"若被违反,重生成而非手改。
