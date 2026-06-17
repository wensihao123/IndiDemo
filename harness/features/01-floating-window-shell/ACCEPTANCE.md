---
artifact: ACCEPTANCE
feature: 01-floating-window-shell
role: Art Spec
status: accepted
updated: 2026-06-17
inputs: [ASSET-SPEC.md, STYLE-BIBLE.md, FEATURE-DESIGN.md, project-context.md, 交付的三件 PNG]
next: Engine Integrator
---

# ACCEPTANCE — 悬浮窗外壳占位素材

> 对照 ASSET-SPEC §5 验收清单逐项判。客观项用工具实测(尺寸/透明/格式/包围盒),
> 主观项肉眼判。占位阶段从宽:够用即过,偏差记为 flag 留正式美术阶段处理。

## 总览
| 素材 | 判定 | 一句话 |
|---|---|---|
| `hero_warrior_placeholder.png` | **PASS** | 修订后脚底贴底(底边距=0)、居中、尺寸/透明达标 |
| `bg_strip_placeholder.png` | **PASS(占位通过)** | 尺寸/不透明/无 UI 达标;接缝与信息量两处软偏差,记 flag |
| `icon_handle_placeholder.png` | **PASS** | 全项达标 |

---

## 资产 1 — hero_warrior_placeholder.png
通用:
- [x] 文件名与 §2 一致(`hero_warrior_placeholder.png`,小写 snake_case)。
- [x] 平滑风、非像素(无点阵锯齿)。
- [x] 不含运行时状态(无血条/数字/选中/特效)。

资产 1 专项:
- [x] 画布恰为 **128×160**(实测 128×160)。
- [x] 背景透明、无色键残留、无明显毛边(实测 32bppArgb 带 alpha,边缘干净)。
- [x] 水平居中(实测左边距=右边距=27px,完美居中)。
- [x] **角色脚底贴画布最底一行 —— 修订后达标。** 复测包围盒 y[29..159],底边距=0
      (脚底落在第 159 行,即画布最底行)。pivot bottom-center 可直接坐实地面线。
      (原交付底部留空 14px,作者已把内容整体下移修正。)
- [x] 单张静态(无帧序列)。
- [~] 朝右且镜像后不出错 —— **软偏差**:交付图是**正面偏 3/4 视角**(基本对称),不是明确朝右
      侧面。无不对称文字/徽记,`flip_h` 不会出错;但正面图 flip_h 视觉变化很小,达不到
      "朝右→镜像复用朝左"的本意。占位可接受。

**修复建议(脚底贴底,二选一):**
1. **美术侧(推荐,保持 128×160 不变):** 把不透明内容整体下移 14px,顶部补 14px 透明,
   使脚底落在第 159 行。重存后回报复验。
2. **接入侧(Engine Integrator 吸收):** 不改图,接入时把 Sprite2D 的 pivot/offset 设到
   实际脚底行(y=145)而非画布底,运行时 bob 以该点为基准。
   → 若走此路,**本条转为 INTEGRATION-STEPS 的待办**,资产 1 即视为占位通过。

---

## 资产 2 — bg_strip_placeholder.png
通用:
- [x] 文件名与 §2 一致。
- [x] 平滑风、非像素。
- [x] 不含运行时状态。

资产 2 专项:
- [x] 画布恰为 **256×250**(实测 256×250)。
- [x] 满底不透明、无 alpha(实测 24bppRgb,全图 0 个非不透明像素)。
- [x] 无 UI/文字/玩法实体/血条/范围/调试标记(肉眼:纯城镇风景底,干净)。
- [~] **左右边缘无缝 —— 软偏差(占位接受)。** 实测左右边缘平均 RGB 差 ≈ 17.5
      (>30 才肉眼明显;17.5 属"凑近平铺能看出、远观不明显")。占位阶段可用。

**软 flag(不挡占位,留正式美术阶段处理):**
- F-BG1 接缝未真无缝(RGB 差 ~17.5)。横向平铺到全屏宽时,接缝会周期性出现。
  正式美术需 offset-50%+heal 修到 <~8,或改"单张够宽整图不平铺 / 纯色渐变底"。
- F-BG2 **信息量偏高**:交付图是细节清晰的城镇全景(教堂塔、风车、山、树都清晰),
  比 ASSET-SPEC §3 要求的"低对比、低信息量氛围底"更抢眼,有与前景主角抢注意力的风险。
  占位可用;正式阶段建议降对比/虚化远景,让它"安静地待在身后"。

---

## 资产 3 — icon_handle_placeholder.png
通用:
- [x] 文件名与 §2 一致。
- [x] 平滑风、非像素。
- [x] 不含运行时状态。

资产 3 专项:
- [x] 画布恰为 **64×64**、透明背景(实测 64×64,32bppArgb 带 alpha)。
- [x] 小尺寸可读:盾+剑+月桂徽记,强轮廓、形块分明,32px 缩略下主体仍可辨认。
- [x] 无烘焙文字(徽记内无字母/数字)。

---

## 结论与下一步
- **三件全部占位通过**,可直接进入接入。资产 1 脚底已修订到位(走了修图路线,无需 EI 吸收偏移)。
- 软 flag F-BG1 / F-BG2 不挡本期占位,登记到正式美术替换阶段。

## 仍存 flags(本 role 视角,向上滚动)
- 〔Art〕STYLE-BIBLE 调色板 hex 未锁:本批占位用描述性暖调过关;正式美术前必须补 hex
  并据此重出 ASSET-SPEC + 重生三图。
- 〔需 EI/setup〕`style-basic-2d.md` 仍在 `harness/templates/`,未提升到 `harness/` 根
  并填实〔EI〕占位(导入预设 Lossless/Linear/Mipmaps off/Fix Alpha Border、逻辑分辨率、
  接入)。本 spec 的导入意图须由 Engine Integrator 落实。
