---
artifact: CHANGES
feature: 00-foundation-redesign
role: Implementer
status: draft
updated: 2026-06-19
inputs: [REVIEW-batch3.md §3 (S1), HANDOFF.md 决策记录(用户拍方案 B), src/core/combat/entity.gd, src/core/game_controller.gd, src/core/items/equipment_component.gd, src/core/meta/character.gd, src/core/items/item_instance.gd]
next: Reviewer / Engine Integrator(步 5)
---

# CHANGES — batch3 S1 修复(自动穿装持久化 · 方案 B 存档收口)

> 范围:仅修 REVIEW-batch3.md §3 的 should-fix **S1**。用户拍板同步方案 = **B(存档时收口)**。
> 非 PLAN-batch3 内步骤 —— 由 Reviewer 发现、用户决策驱动(见 HANDOFF 决策记录 2026-06-19)。

## 1. What changed(逐文件)
- `src/core/combat/entity.gd` — 新增 `write_equipment_into(c: Character)`:把当前 `EquipmentComponent` 三槽装备态快照回写 `Character.equipped`(槽空则 erase),与 `from_character` 对称。
- `src/core/game_controller.gd` — 新增 `_sync_party_equipment()`(按 index 配对 `party_characters[i]`↔`arena.players[i]`,逐活体调 `write_equipment_into`);`_autosave()` 落盘前先调它。
- `test/core/game_controller_test.gd` — 加 2 个用例:`test_auto_equipped_gear_persists_across_reboot`(穿装→自动存档→重 boot 仍在)、`test_unequipped_slot_clears_from_roster_on_save`(局内脱下→收口清掉 roster 该槽)。

## 2. Why(映射到来源)
- REVIEW-batch3.md §3 **S1**:`loot_intake.gd:14-16` EQUIPPED 路径只 buff 活体 Entity 的 `EquipmentComponent`,从不回写 `Character.equipped` → 存档(序列化 `Character.equipped`)拿不到自动穿装,重 boot 即丢,打在 v1 核心循环(掉装→变强)。
- 用户决策(HANDOFF 2026-06-19)= **方案 B 存档时收口**:不改 LootIntake/战斗热路径,只在 `GameController._autosave()` 落盘前把活体装备态快照回 roster。改动局部、不动掉落契约,符合"最小满足"。
- `entity.gd` 承方案 B 的"局内态→持久态"职责(Entity 已经 `from_character` 读 Character,反向 `write_equipment_into` 同依赖方向,不破层次)。
- 卸下边界(用户明确点名):槽在 `EquipmentComponent` 为空时 `c.equipped.erase(slot)`,杜绝 roster 残留已脱下的旧件。

## 3. How I verified it
- `godot --headless --check-only`(随套件编译,无新脚本文件,纯 edit)✓
- 定向套件 `test/core/game_controller_test.gd`:**6/6**(4 原 + 2 新)| 0 errors/failures/orphans | exit 0 ✓
- 全量回归 `res://test`:**155/155**(原 153 + 2 新)| 25 suites | 0 errors/0 failures/0 flaky/0 skipped/**0 orphans** | exit 0 ✓
- 旧 `test/combat/*`(45)与 `project.godot`/旧 director 仍未动(并行造桥不破)。

## 4. Deviations from plan
无方案层偏差(严格照用户拍定的方案 B)。实现取舍 1 处,非语义偏差:
- 收口职责拆成 `Entity.write_equipment_into`(单实体快照)+ `GameController._sync_party_equipment`(配对编排),而非全堆在 `_autosave`。理由:与 `Entity.from_character` 对称、把"装备态读写"知识收在 Entity 内、`_autosave` 保持薄。未引入新类、未扩大依赖方向。

## 5. Wiring Contract(交 Engine Integrator)
**本次无新增引擎接线点**——纯逻辑内部改动,无新 `@export`、无新 autoload、无新 signal、无 input-map/group/layer 变更。
- `GameController._autosave()` 行为增强:落盘前自动调 `_sync_party_equipment()`。对步 5 的意义 = **手动 Play 验收"掉装→重启仍在"时,此缝已闭**(原 REVIEW-batch3 §3 列为"步 5 手测前须拍板"的项,现已实装 → 步 5 手测应能观察到自动穿装在重 boot 后保留)。
- 配对契约(供步 5 与后续多角色扩展知悉):`party_characters[i]` 与 `arena.players[i]` **同序对齐**(均长度 `PARTY_SLOTS`=4,空位 null);收口依赖该对齐。日后若改建队顺序须同步维护两数组同序。
- 依赖前提不变:仍走第三批 `Game`/`PlayerState` 装配(F-PS-autoload 决策仍待步 5 落,见下)。

## 6. Flags / Open questions
- **[F-PS-autoload 仍未决,步 5 切 autoload 前定]** 本次未触碰该项;GameController 仍自持 `PlayerState`。建议步 5 不注册 PlayerState autoload(详见 CHANGES-batch3 §4.1)。
- **[范围说明]** 仅闭"自动穿装(EQUIPPED 去向)"持久化缝。掉进背包(BAGGED)/分解(DECOMPOSED)去向本就经 `PlayerState.to_dict` 持久(bag/材料),不在本修复范围。
- **[非本次]** S1(承第二批的"4 槽位空位补测")是另一条同名 should-fix,仍列步 5 删 director 前并入;本次只解 REVIEW-batch3 §3 的自动穿装持久化 S1。
