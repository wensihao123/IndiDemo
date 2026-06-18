extends RefCounted
class_name LootIntake
## 掉落 intake 编排(04 §3.8 填空优先于分解):生成→消费的桥,流水线尾。
## 空槽→穿(含白);否则白(≤分解门槛)→出材料;蓝/金→进包。返回去向供调用方/测试断言。
## 注:本批不传 Character —— equip 经 EquipmentComponent 绑定的 StatsComponent 即可,角色侧同步留第二批接线。

const EQUIPPED := &"equipped"
const DECOMPOSED := &"decomposed"
const BAGGED := &"bagged"


static func handle_drop(instance: ItemInstance, equipment: EquipmentComponent, player_state: PlayerState, loot_table: LootTableDef) -> StringName:
	var slot := instance.base_id
	if equipment.is_slot_empty(slot):
		equipment.equip(slot, instance)
		return EQUIPPED
	if loot_table.should_decompose(instance.rarity):
		player_state.add_material(slot, instance.rarity, loot_table.material_per_decompose)
		return DECOMPOSED
	player_state.add_to_bag(instance)
	return BAGGED
