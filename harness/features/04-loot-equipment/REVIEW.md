---
artifact: REVIEW
feature: 04-loot-equipment
role: Reviewer
status: draft
updated: 2026-06-19
inputs: [PLAN.md, CHANGES.md, project-context.md, BALANCE-CHANGE-01-loot-equipment.md, src/core/systems/loot_generator.gd, src/core/combat/combat_arena.gd, src/combat/combat_view.gd, assets/data/combat/stage_01.tres, assets/data/combat/stage_02.tres, test/core/loot_generator_test.gd, test/core/combat/arena_loot_test.gd]
next: 人工 Play 验收 → 完成收口
---

# REVIEW — 04 掉落装备:稀有度权重接线 + 只读查阅面板 + item_level 阶梯

## 1. Verdict
**APPROVE WITH NITS.** 代码正确、忠实于 PLAN 7 步 + BALANCE-CHANGE-01,无范围外改动,无 hard-NO 违规。
我独立复跑:gdUnit4 **123/123 绿(18 套,exit 0)**、`--check-only` `combat_view.gd` exit 0、8 个 `item_level` 与定稿表逐一核对一致。
**唯一未闭环的不是代码缺陷**:Step 3-6 全是 UI,按测试政策(project-context §5 + R2)只能手动 Play,本切片尚未人验 —— 见 §3「必须人验」,这是收口前的必过闸,但不阻塞代码审查通过。

## 2. Must-fix (blocking)
无。未发现阻塞性正确性 / 安全 / 忠实度问题。

## 3. Should-fix (non-blocking)
- **(流程,非代码)必须人验后才能标 done。** `CHANGES.md §4` 的 6 条人验清单尚未执行。重点确认:
  - 清单#1 切换按钮 `(360,12)` 与进度标题 `(16,12)` / 推进按钮 `(660,12)` 不重叠、开合无报错;
  - 清单#4 自动填空时右栏跳变 + 绿闪;清单#5 关1→关2 推进后蓝/金件 ilvl 肉眼变高;
  - 清单#6 R1 800×250 模态面板不永久压战斗。
  *为何要紧:* UI 正确性无法 gdUnit4 覆盖,唯一验证手段就是 Play;在人验前本功能不可视为完成。
- **`combat_view.gd:565` `ent.stats.get_final(stat)` 未守 `ent.stats == null`。** 紧邻的 `ent.equipment` 在 557 行做了 `!= null` 守卫,`ent.stats` 没有。
  *为何要紧:* 玩家活体 `Entity.from_character` 必带 `stats`,当前路径不会触发 null,故非阻塞;但两个组件守卫不对称,若日后出现「半装配 Entity」会空引用。*方向:* 与 `equipment` 同样加一道 `if ent.stats != null` 或在 `_panel_entity` 处统一保证。

## 4. Nits (optional)
- **`combat_view.gd:583-584` `_flash_equip_col` 几何 `(420,6)/(360,238)` 是手填魔数**,与 `_equip_col` 位置 `(430,34)` 不联动。纯表现、可接受;若日后挪栏位需手动同步。建议(可选)从 `_equip_col` 推导或提为常量。
- **`combat_view.gd:539` 左栏 bag 列表无上限 / 无滚动**,包多时会纵向溢出 800×250。已知 **F-BAG 明确推后**(PLAN §4),仅记录,不在本切片处理。
- **命名:`inst.base_id` 实际承载的是 slot(`weapon/armor/accessory`)**,`_rebuild_bag_col` 用 `_slot_text(inst.base_id)` 正确但字段名易误读。属既有数据模型命名(非本切片引入),不在此修。

## 5. What I checked but found fine (覆盖说明)
- **`LootGenerator.pick_weighted`(loot_generator.gd:7-19):** 归一化加权正确;边界全覆盖且有测——空数组 / 全零 / 权重和≤0 → 早返回 0;负权重 `maxf(0,…)` 归零;浮点 `r<acc` 累加定位无越界(`randf()<1` 保证 `r<total`,尾返回 `size-1` 仅理论兜底)。4 个 gdUnit4 用例(含 20000 次分布 ±3%)非空洞。
- **`combat_arena.gd:_drop_loot`(163-166):** 权重数组 `[white,blue,gold]` 与 `GameKeys.RARITIES=[white,blue,gold]` 下标严格对齐;`idx → RARITIES[idx]` 正确;slot 保持均匀(忠实范围)。2 个极端权重用例(100/0/0 全白、0/0/100 全金,4 seed)证明读的是 `def` 字段而非随机。
- **面板刷新时机(combat_view.gd:247-251, 517-529):** 事件驱动(打开 + 可见时 `item_dropped`),不进 `_process`,与 FEATURE-DESIGN「掉落→填空→跳变」时机一致;`_refresh_panel` 三重 null 守卫(`_gc/_bag_col/_equip_col`)。
- **R3 活体空守卫(`_panel_entity` 570-576 + `_rebuild_equip_col` 552-555):** `begin_run` 前 `players` 空 → 右栏显「(未进入战斗)」,不空引用。✅
- **模态 / z-order:** `_panel`(STOP, full-rect)隐藏时不拦输入(Godot hidden Control 不收 mouse);`_panel_btn` 在 `_panel` 之后 add → 永远在遮罩之上可点关;开面板时推进/修整按钮被遮罩吃掉(modal,符合预期),战斗 `_process` 照跑不打断(守支柱 1)。
- **不变量:** 面板**纯读** `bag[]` / `EquipmentComponent.get_equipped` / `StatsComponent.get_final`,不写装备态,i3「自动填空只增不替」由后端保证、面板不破;item_level 仅改 `.tres` 值,不动公式 → i4/i6 不受影响。
- **hard-NO:** 无新插件;无顺手重构/加功能(对照 PLAN 逐步,零偏差);数值(稀有度权重 / item_level)全走 `EnemyDef` 字段与 `.tres`,未硬编进逻辑;面板的颜色/坐标是 UI 布局常量,非平衡参数。✅
- **D6 属性格式化(623-634):** 暴击率/闪避 `%`、暴伤 `×N.NN`、攻速/回血 `/s`、余整数 —— 与 PLAN D6 一致;词缀值复用同函数,口径统一。
- **BALANCE-CHANGE-01 落地:** 8 个 `item_level`(1/3/6/10 · 14/18/24/30)与定稿 §3(a) 表逐一一致;`stage_0*.tres` 加载经全套测试(含 arena_loot 走 `from_enemy_def`)间接覆盖,check-only 不报错。
