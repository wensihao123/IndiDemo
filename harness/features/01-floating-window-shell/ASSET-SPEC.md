---
artifact: ASSET-SPEC
feature: 01-floating-window-shell
role: Art Spec
status: draft
updated: 2026-06-17
inputs: [project-context.md, STYLE-BIBLE.md, style-basic-2d.md, FEATURE-DESIGN.md]
next: 人类(出图/找图)→ 回报给 Art Spec 验收
---

# ASSET-SPEC — 悬浮窗外壳占位素材

> 本期全部为**占位素材**:目的是让窗口"活起来"并验证布局,不追求最终美术。
> 三件:① 占位角色 ② 两侧占位背景 ③ 收起 handle 图标。
> 工程纪律遵 `style-basic-2d.md`,外观遵 `STYLE-BIBLE.md`(平滑风 / Linear / 非像素)。

## 1. Asset list(尺寸 / 锚点 / 透明)
| # | 名称 | 用途 | 画布尺寸(px) | 锚点 pivot | 透明 |
|---|------|------|--------------|------------|------|
| 1 | `hero_warrior_placeholder` | 主区里的占位战士,证明"小队还活着" | **128×160**(单张静态) | **脚底居中**(bottom-center) | 是 |
| 2 | `bg_strip_placeholder` | 主区两侧延展的占位背景,适配全屏宽 | **256×250**(**可水平平铺/tileable**) | 左上(0,0) | 否(满底) |
| 3 | `icon_handle_placeholder` | 收起态屏幕边缘的小 handle 图标 | **64×64** | 居中 | 是 |

补充约束:
- 资产 1 为**单张静态 PNG**,**待机微动靠运行时**(`AnimationPlayer` 动 position/scale/modulate
  做呼吸/浮动),**不出帧序列**(遵 STYLE-BIBLE §6 / style-basic-2d §3、§6.5)。
- 资产 2 必须**左右无缝平铺**(右边缘接左边缘),因为屏宽未知、要横向重复铺满主区两侧。
- 资产 1 朝向默认朝右,运行时用 `flip_h` 复用;身上不要有左右不对称且镜像后会出错的标志。

## 2. Naming & format(命名与格式 —— 先锁,勿后改)
- 文件名(全小写 snake_case):
  - `hero_warrior_placeholder.png`
  - `bg_strip_placeholder.png`
  - `icon_handle_placeholder.png`
- 运行时目录:`res://assets/sprites/placeholder/`(角色、handle)、`res://assets/sprites/bg/`(背景)。
- 格式:**PNG**(资产 1、3 透明;资产 2 不透明)。
- 源文件(若有 .kra/.psd):放 `res://_source/`(带 `.gdignore`,不进运行时/导出)。
- 名字含 `placeholder`,方便日后正式美术替换时一眼识别、批量换。

## 3. Style constraints(外观约束)
- 平滑手绘风,**非像素**;中等粗细清晰描边、圆润、Q 萌(遵 STYLE-BIBLE §0/§1/§3)。
- 角色:一个能看出是"战士"的占位剪影即可(暖色调、握个武器/盾的意象),明度偏高。
- 背景:低对比、低信息量的氛围底(如柔和的城镇/户外色块),**不得**含 UI、文字、玩法实体、
  血条、范围、调试标记(style-basic-2d §6.2)。
- handle:极简、强轮廓、小尺寸可读(如一个小队/盾牌徽记);不烘焙文字。
- 占位阶段不强求贴合最终 palette,但整体色调需落在 STYLE-BIBLE 的暖调/高明度倾向内。

## 4. Generation prompts(可直接喂 AI 出图,每件一条)
- **资产 1 hero_warrior_placeholder**:
  "Hand-drawn 2D cartoon warrior character, MapleStory-like cute chibi style, smooth
  clean outlines (not pixel art), facing right, holding a sword and small shield,
  warm palette, full body standing on the ground, neutral idle pose, transparent
  background, centered, single static sprite. Canvas 128x160, character feet at the
  bottom-center." (中文:手绘卡通 Q 版战士,枫之谷风,平滑描边非像素,朝右持剑盾,暖色,
  站立待机,透明背景,脚底贴画布底部居中。)
- **资产 2 bg_strip_placeholder**:
  "Soft hand-drawn 2D ambient background strip, MapleStory-like, gentle warm town /
  outdoor atmosphere, low contrast, no characters, no UI, no text, **horizontally
  tileable / seamless left-right edges**, smooth painterly (not pixel). Canvas 256x250."
- **资产 3 icon_handle_placeholder**:
  "Minimal cute emblem icon (small shield / party crest), MapleStory-like, bold clean
  outline, smooth (not pixel), transparent background, readable at small size, no text.
  Canvas 64x64, centered."

## 5. Acceptance checklist(验收 —— 客观可测;回报素材后逐项判)
通用:
- [ ] 文件名与 §2 完全一致(全小写 snake_case,无空格/非 ASCII)。
- [ ] 平滑风、**非像素**(无硬点阵锯齿观感)。
- [ ] 不含任何运行时状态(血条/数字/选中/状态特效)——遵 style-basic-2d §3。

资产 1 hero_warrior_placeholder:
- [ ] 画布恰为 **128×160**。 [ ] 背景透明、无色键残留、无明显毛边。
- [ ] 角色**脚底贴画布最底一行**、水平居中(pivot bottom-center 可用)。
- [ ] 单张静态(无帧序列)。 [ ] 朝右且镜像后不出错。

资产 2 bg_strip_placeholder:
- [ ] 画布恰为 **256×250**。 [ ] **左右边缘无缝**(并排平铺看不出接缝)。
- [ ] 满底不透明、无 UI/文字/实体/血条/范围/调试标记。

资产 3 icon_handle_placeholder:
- [ ] 画布恰为 **64×64**、透明背景。 [ ] 小尺寸(如 32px 显示)仍可辨认。 [ ] 无烘焙文字。

## 6. Flags / Open questions
- 〔需 EI〕导入预设(平滑风:Lossless / Linear / Mipmaps off / **开 Fix Alpha Border**)与
  各资源 `*.import` 提交,属 Engine Integrator;本 spec 只声明意图。
- 占位角色"待机微动"的具体手段(bob 幅度/频率)属 Game Feel/实现层,本 spec 只要求**单张静态图**。
- 这些是占位图;正式美术阶段需带 palette hex 回到 STYLE-BIBLE 重新出 spec 替换。
