---
artifact: ACCEPTANCE
feature: 02-auto-combat-loop
role: Art Spec
status: accepted       # 13 件整组通过;M1 改名已完成,零遗留,可直接进 EI
updated: 2026-06-18
inputs: [ASSET-SPEC.md, STYLE-BIBLE.md, style-basic-2d.md, 交付素材 13 件]
next: Engine Integrator 导入接线(/role-engine-integrator-godot 02-auto-combat-loop)
---

# ACCEPTANCE — 自动战斗循环正式素材(13 件)

> 逐项对 ASSET-SPEC §5 客观清单判定。尺寸/透明用 System.Drawing 实测,接缝/FX/描边色用脚本采样,
> 画风/朝向/配色/基调肉眼核。**总判:整组通过(accepted)**——画质/尺寸/透明/配色/基调全达标,
> 敌人全部朝左(对)。唯一遗留 = `hero_warrior` 文件名拼错(M1,机械改名,非美术问题)。
>
> **更正(2026-06-18):** 初判曾把 #1/#2/#3/#5/#6 误读为"朝右"并开了 M2 朝向决策——经用户对实图
> 复核,**8 只敌人均朝左**,3/4 chibi 缩略图易判反,我的首读有误。**M2 撤销,无朝向问题。**

## 总览

| # | 资源 | 尺寸 | 透明 | 命名/路径 | 画风/配色/基调 | 朝向 | 判定 |
|---|------|------|------|-----------|----------------|------|------|
| 1 | enemy_goblin | 128×128 ✓ | ✓ | ✓ | ✓ | 朝左 ✓ | **PASS** |
| 2 | enemy_wolf | 128×128 ✓ | ✓ | ✓ | ✓ | 朝左 ✓ | **PASS** |
| 3 | enemy_orc | 128×128 ✓ | ✓ | ✓ | ✓ | 朝左 ✓ | **PASS** |
| 4 | enemy_goblin_king | 160×176 ✓ | ✓ | ✓ | ✓ 暖橙王冠+披风 | 朝左 ✓ | **PASS** |
| 5 | enemy_orc_elite | 128×128 ✓ | ✓ | ✓ | ✓ 加肩甲,与#3 可分 | 朝左 ✓ | **PASS** |
| 6 | enemy_wolf_shadow | 128×128 ✓ | ✓ | ✓ | ✓ 深紫灰,与#2 可分 | 朝左 ✓ | **PASS** |
| 7 | enemy_ogre | 160×160 ✓ | ✓ | ✓ | ✓ 体型最大、憨 | 朝左 ✓ | **PASS** |
| 8 | enemy_orc_chieftain | 160×176 ✓ | ✓ | ✓ | ✓ 暖橙图腾杖、最魁梧 | 朝左 ✓ | **PASS** |
| 9 | fx_light_pillar | 64×256 ✓ | ✓ | ✓ | ✓ 纯白底实顶渐隐 | — | **PASS** |
| 10 | fx_loot_sparkle | 128×128 ✓ | ✓ | ✓ | ✓ 中性白放射 | — | **PASS** |
| 11 | hero_warrior | 128×160 ✓ | ✓ | ✓(已改名) | ✓ 朝右、剑盾镜像安全 | 朝右 ✓ | **PASS** |
| 12 | bg_strip | 256×250 ✓ | 不透明 ✓ | ✓ | ✓ 暖木城镇+绿 | — | **PASS**(W1 接缝引擎里核) |
| 13 | icon_handle | 64×64 ✓ | ✓ | ✓ | ✓ 盾徽、无文字 | — | **PASS** |

**13 件全 PASS,M1 改名已完成,零遗留——可直接进 Engine Integrator。**

## 客观实测记录
- **尺寸/透明**:13 件全部命中 ASSET-SPEC §1 画布;敌人/FX/hero/icon 均 32bppArgb 带 alpha;
  `bg_strip` 24bppRgb 不透明(满底,符合)。
- **`fx_light_pillar`**:不透明像素平均 RGB = **(255,255,255) 纯白** ✓;x 范围 20–43(64 宽内居中)✓;
  下半屏像素 2166 ≫ 上半屏 723 → 底实顶渐隐、底部锚定 ✓。运行时 `modulate` 染蓝/金不会串色。
- **`bg_strip` 水平接缝**:col0 vs col255 均差 R=9.7 / G=7.4 / B=5.4(≈3%)。接近无缝但**非零**,
  并排平铺边界可能有一道**轻微可见缝**(预测中的 image2 弱项)。→ 见下方 ⚠。
- **描边色采样(最暗 200 px 均值)**:goblin (63,40,18) 暖棕✓;orc (17,10,4) 偏深但暖向;
  wolf_shadow (14,6,16) 因本体即暗影深紫,采样被本体污染、非纯描边。**整体读作暖棕系、非纯黑**,通过;
  仅 orc 个别最暗处接近黑(暖向),记小 nit,不阻塞。
- **无运行时状态烘焙**:13 件均无血条/数字/伤害字/选中框/染色,符合 style-basic-2d §3 ✓。

## 必修 / 需决策(放行给 EI 前)

### ~~M1〔命名〕~~ —— 已完成(2026-06-18,用户改名)
原 `hero_warriorpng.png` 漏点;用户已改名为 `assets/sprites/hero/hero_warrior.png`(实测在位),
与 ASSET-SPEC §2 一致。像素本身 128×160、朝右、剑盾镜像安全,全部通过。**零遗留。**

### ~~M2〔朝向〕~~ —— 已撤销(2026-06-18,用户复核实图)
初判误把 #1/#2/#3/#5/#6 读成"朝右";经用户对实际渲染图复核,**8 只敌人均朝左**,符合 ASSET-SPEC
锁定(从右侧出现、面向左边小队;hero 朝右)。3/4 chibi 在缩略图里朝向易判反,是我的首读失误。
**无需 `flip_h`、无需重生成。** EI 端敌人 `Sprite2D` 不必额外翻转(仍可保留 `flip_h` 数据通道备日后用)。

## ⚠ 待确认(不阻塞,但请在引擎里核)
- **W1 `bg_strip` 接缝**:均差 ≈3%,理论接近无缝。请在 EI 导入后**并排平铺两张实看**:若边界有可见
  竖缝,补 1–2px 接缝(image2 不保证完美无缝,ASSET-SPEC §6 已预警)。可接受则免动。
- **W2 orc 描边个别最暗处接近黑**(暖向,非纯黑):极小 nit,不影响整体暖棕观感,不要求改。

## 通过项确认(对支柱)
- **可读性(支柱 1)**:同系怪都分得清——哥布林↔哥布林王(体型+暖橙王冠)、兽人↔精英兽人(肩甲)、
  野狼↔暗影狼(明暗/紫灰)✓;两 Boss 体型显著更大 + 暖橙点睛,余光可读"关口门"✓。
- **基调(支柱 1)**:全员 Q 萌治愈、不血腥惊悚(连暗影狼/食人魔都憨萌)✓。
- **FX 不烘焙颜色**:光柱/星辉中性白,留运行时按稀有度染 ✓。

## Flags → 下游
- **〔→ EI〕** 敌人全部朝左,无需 flip。`combat_view.gd` 敌人占位 `ColorRect`(`_enemy_panel`)换成
  `Sprite2D`/`TextureRect`,按 `current_enemy_def()` 切贴图;贴图↔EnemyDef 绑定走 Resource
  (`@export var sprite: Texture2D`),不硬编码路径(ASSET-SPEC §6 / project-context §4)。
- **〔→ EI〕** M1 改名后,把 floating_shell 等对 `hero_warrior_placeholder` / `bg_strip_placeholder` /
  `icon_handle_placeholder` 的引用重指到正式名;旧 `*_placeholder.*` 确认无引用后清理(ASSET-SPEC §6)。
- **〔→ EI〕** 导入预设:Lossless / Linear / Mipmaps off / 开 Fix Alpha Border(尤其平滑边缘的敌人/FX)。
- **〔留后续〕** 金装音效 + hitstop(无音频管线),非美术贴图。
