---
artifact: CHANGES
feature: 04-loot-equipment
role: Implementer
status: draft
updated: 2026-06-19
inputs: [PLAN.md, harness/balance/BALANCE-CHANGE-01-loot-equipment.md, project-context.md, ARCHITECTURE.md, BALANCE.md, src/core/systems/loot_generator.gd, src/core/combat/combat_arena.gd, src/combat/combat_view.gd, src/combat/enemy_def.gd, src/core/game_keys.gd]
next: Reviewer
---

# CHANGES — 04 掉落装备:稀有度权重接线 + 只读查阅面板 + item_level 阶梯

> 落地 PLAN.md(收窄版 7 步)+ BALANCE-CHANGE-01(8 个怪 item_level)。后端流水线已由 REFACTOR-01
> 落定,本切片**不重做后端**,只交付:① 稀有度读权重;② 只读查阅面板;③ item_level 阶梯(纯 .tres)。

## 1. 做了什么 / What changed
- **稀有度权重接线(PLAN Step 1-2):** 掉落稀有度从均匀随机改为读 `EnemyDef.rarity_weight_{white,blue,gold}`。
  - 新增纯静态 `LootGenerator.pick_weighted(weights, rng) -> int`(归一化加权挑选;空数组/权重和≤0/全零 → 返回 0;负权重按 0)。
  - `combat_arena.gd:_drop_loot` 构造 `[white,blue,gold]` 权重数组 → `pick_weighted` → `GameKeys.RARITIES[idx]`。slot 仍均匀(范围外)。
- **只读查阅面板(PLAN Step 3-6):** `CombatView` 内代码构建一个默认隐藏的全区模态 `Panel` + "背包/装备" 切换按钮。
  - 左栏 `_bag_col`:遍历 `_gc.player_state.bag`,每件「部位 · ilvl · 稀有度(RARITY_COLOR 着色)」+ 词缀行;空包显「(空)」。
  - 右栏 `_equip_col`:取首个非空活体 `Entity`(`_arena.players`),3 槽 `get_equipped`(空槽「—」)+ 8 维 `stats.get_final` 按 D6 语义格式化。
  - 刷新事件驱动:打开时 + 面板可见时收到 `item_dropped` 时重建两栏;`EQUIPPED` 时右栏闪一下绿(「变强显形」)。不进 `_process`。
- **item_level 阶梯(BALANCE-CHANGE-01):** 8 个 `EnemyDef` 子资源新增 `item_level` 字段(关1 哥布林1/野狼3/兽人6/王10;关2 精英兽人14/暗影狼18/食人魔24/酋长30),解锁词缀 Tier 上阶梯(原全默认 1、死锁)。纯 `.tres` 值编辑,零代码、零公式。

## 2. 触及文件 / Files touched
- `src/core/systems/loot_generator.gd` — 加静态 `pick_weighted`(纯逻辑,gdUnit4 可测)。
- `src/core/combat/combat_arena.gd` — `_drop_loot` 稀有度选择改读权重(注释同步)。
- `src/combat/combat_view.gd` — 新增 `_panel/_panel_btn/_bag_col/_equip_col/_panel_visible` 成员 + `_build_panel/_toggle_panel/_refresh_panel/_rebuild_bag_col/_rebuild_equip_col/_panel_entity/_flash_equip_col/_make_label/_slot_text/_stat_name/_format_stat_value`;`_on_item_dropped` 尾加面板刷新钩子;`_build_ui` 尾调 `_build_panel`。
- `assets/data/combat/stage_01.tres` — 4 个怪 `item_level`(1/3/6/10)。
- `assets/data/combat/stage_02.tres` — 4 个怪 `item_level`(14/18/24/30)。
- `test/core/loot_generator_test.gd` — +4 `pick_weighted` 用例(全零→0、空→0、单非零命中、分布≈权重)。
- `test/core/combat/arena_loot_test.gd` — +2 加权稀有度用例(100/0/0 全白、0/0/100 全金,多种子)+ `_enemy_rarity` 夹具。

## 3. 如何验证 / Verification
- **语法/加载闸:** `godot --headless --check-only --script res://src/combat/combat_view.gd` → 退出 0、无 script error。
- **全套 gdUnit4:** `--headless -s GdUnitCmdTool.gd -a res://test` → **123/123 通过**(原 117 + 新 6),0 errors/0 failures,退出 0。
  - `loot_generator_test`:11/11(含 4 新 `pick_weighted`)。`arena_loot_test`:5/5(含 2 新加权稀有度)。
- **手动 Play(R2 — UI 仅手动验,见下"待人验"):** 面板开合、双栏内容、自动填空绿闪、item_level 推进后包内蓝/金件 ilvl 上升 —— **尚未由人在 Godot 编辑器 Play 确认**,留 Reviewer/用户走查。

## 4. Wiring Contract(接线契约)
> 本切片**无新场景节点、无 Inspector 接线点、无 autoload 改动** —— 面板全部代码内建于 `CombatView._build_ui`,
> 稀有度接线只在 `_drop_loot` 内读既有 `@export`。故**不需要 Engine Integrator 人工接线**(F-ARCH-OK)。
- **`CombatView` 依赖(运行时,既有,未新增外部依赖):** `/root/Game`(GameController)→ `.arena`(CombatArena)、
  `.progression`、`.player_state`(PlayerState,读 `.bag`)、`.party_characters`。面板新读 `_gc.player_state.bag`
  与 `_arena.players[i]` 活体 `Entity`(`.equipment.get_equipped`/`.stats.get_final`)。这些在 `begin_run` 后填实;
  面板对空态有守卫(`_panel_entity` 判空 → 右栏显「(未进入战斗)」)。
- **`.tres` 契约:** `EnemyDef.item_level`(已存在 `@export int = 1`)现由 stage_0*.tres 显式赋值;
  `rarity_weight_*`(已存在 `@export`)现被 `_drop_loot` 实际读取。无新字段、无 schema 变更、存档向后兼容
  (`item_level` 不进存档关键路径,旧档背包物品保留各自生成时的 ilvl)。
- **给 Reviewer 的人验清单(手动 Play floating_shell):**
  1. "背包/装备" 按钮出现且可开合;面板开时不报错、遮罩吃点击、按钮仍可点关。
  2. 挂机掉出蓝/金 → 开面板左栏见条目 + 稀有度着色 + 词缀;白装不在包(被穿/分解)。
  3. 右栏显当前武器/护甲/饰品(开局空饰品显「—」)+ 8 维数值(暴击率/闪避 %、暴伤 ×、攻速/回血 /s、余整数)。
  4. 开着面板挂机,空饰品槽被自动填上 → 右栏对应行跳变 + 绿闪;已穿戴槽不被替换。
  5. 关卡推进(关1→关2)后,新掉落蓝/金件 ilvl 明显升高(肉眼可见 Tier/词缀变强)。
  6. R1:800×250 下面板不永久压住战斗关键信息(模态覆盖式,关掉即恢复)。

## 5. 偏差 / 范围外 / Flags
- **零偏差:** 严格按 PLAN 7 步 + BALANCE-CHANGE-01 落地,未顺手加功能/重构(守 project-context 硬 NO)。
- **范围外(未做,PLAN §4):** 手动换装/对比面板/打造/强化(→05);kind roll 金币材料(F-KIND 待 Producer,掉落仍恒装备);
  slot 权重(仍均匀);数值精调(F-NUM 已由 num-smith 定 item_level 阶梯,其余 Tier/base/权重数字未动);满包兜底(F-BAG)。
- **F-NUM 已落:** 稀有度权重数字与 item_level 阶梯均取 BALANCE-CHANGE-01 定稿值,非占位。其余债(债-3 阶选择均匀、
  债-6 词缀池薄)留 v1 之后,见 BALANCE.md §6。
- **R2(显式声明):** Step 3-6 全是 UI,按测试政策只能手动 Play 验,本 session 未跑人验 —— 交 Reviewer/用户。
- **R1 待人验:** 800×250 双栏紧凑度需手动确认。面板设计为全区模态覆盖(开时半遮战斗),关掉即恢复,降低压屏风险。
