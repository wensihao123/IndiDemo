---
artifact: REVIEW
feature: 00-foundation-redesign
role: Reviewer
status: done
updated: 2026-06-19
inputs: [REVIEW-batch3.md §3 (S1 原始诊断), CHANGES-batch3-s1.md, src/core/combat/entity.gd, src/core/game_controller.gd, src/core/items/equipment_component.gd, src/core/meta/character.gd, src/core/items/item_instance.gd, test/core/game_controller_test.gd]
next: Engine Integrator(步 5)
---

# REVIEW — batch3 S1 修复(自动穿装持久化 · 方案 B)

## 1. 结论 / Verdict

**APPROVE WITH NITS.**

S1(REVIEW-batch3 §3 诊断的"自动穿装只 buff 战斗壳、重 boot 即丢")已按用户拍定的**方案 B(存档收口)**正确闭合。改动最小、忠实方案、依赖方向不破、含卸下边界、测试真实可证伪。独立重跑全绿。两条 nit 均无需动作。

独立验证:
- 全量重跑 `res://test`:**155/155 | 25 suites | 0 errors/0 failures/0 flaky/0 skipped | exit 0**。
- 定向 `game_controller_test.gd`:**6/6 | 0 orphans**(4 原 + 2 新)。
- 与 CHANGES-batch3-s1 §3 声称一致。

## 2. 必须修 / Must-fix

无。

## 3. 应该修 / Should-fix

无。

## 4. 吹毛求疵 / Nits(均无需动作,仅记录)

- **N1(信息性)别名共享**:`entity.gd:73` `c.equipped[slot] = item` 让 `Character.equipped[slot]` 与活体 `EquipmentComponent._slots[slot]` 指向**同一个 `ItemInstance`**。当前无害——`ItemInstance` 在战斗中从不被改写(战斗只动 `StatsComponent`/`current_hp`),且存档经 `to_dict()` 深拷、跨 boot 经 `from_dict` 重建、`get_starting_roster` 亦深拷,故内存别名不会污染持久层或跨局串。**仅作未来警示**:若日后 `ItemInstance` 变为可变(如局内强化/磨损),此处需改深拷快照。不阻塞。
- **N2(防御冗余)** `game_controller.gd:108` 的 `if arena == null: return` 在 `_autosave` 外层已保证 `player_state/progression != null`(三者同在 `_boot` 创建)后才会到达,理论上 arena 必非 null。属防御性冗余,无害,保留即可。

## 5. 查过但没问题 / What I checked but found fine

- **方案 B 忠实度**:`_autosave()` 落盘前调 `_sync_party_equipment()`,逐活体 `Entity.write_equipment_into(c)` 把 `EquipmentComponent` 三槽快照回 `Character.equipped` —— 正是用户拍定的"存档时收口",未碰 LootIntake/战斗热路径,范围未漂。
- **写穿到持久层**:`party_characters[i]` 经 `_active_party()` 与 `player_state.roster[i]` 是**同一 Character 引用**,故 `c.equipped` 写入直达 roster → 被 `SaveSystem` 序列化。配对逻辑(同序、`c==null`/`e==null`/越界三重跳过)对空位与未 begin_run(`party_characters` 为空 → 零迭代,仅存默认 roster)均安全。
- **卸下边界**:`entity.gd:74-75` 槽空时 `c.equipped.erase(slot)` —— `test_unequipped_slot_clears_from_roster_on_save` 实证(局内 unequip → 收口后 roster 该槽消失 + 重 boot 仍无)。用户点名的边界已覆盖。
- **测试可证伪性**:`test_auto_equipped_gear_persists_across_reboot` 先断言 `roster[0].equipped.has(weapon) == false`(证明修复前的缝真实存在),再 tick→boss→autosave→断言落盘 + 重 boot 读回 base_id/ilvl=5。这是会在没有本修复时 FAIL 的真 E2E,非空跑。
- **遍历范围**:`write_equipment_into` 走 `GameKeys.SLOTS`(weapon/armor/accessory 三槽规范集);`Character.equipped` 的键只可能来自 `equip(slot∈SLOTS)` 或存档 `from_dict`,无越界键残留之虞。
- **范围正确性**:仅闭 EQUIPPED 去向;BAGGED/DECOMPOSED 去向本就经 `PlayerState`(bag/材料)持久,不在本修复内,无重复或遗漏。
- **过度设计**:仅 2 个小方法、零新类/新配置/新依赖;Entity 侧方法与 `from_character` 对称,职责归位合理,不算过度抽象。
- **约定**:早返回、`snake_case`、注释只解释"为什么";无新插件/无硬编码数值。`project-context` §4 hard NOs 全守。
- **并行造桥**:旧 `test/combat/*`、`project.godot`、旧 director 未动;0 orphans 维持。
- **F-PS-autoload**:本修复未触碰,仍按既有决策留步 5 解 —— 路由无误。
