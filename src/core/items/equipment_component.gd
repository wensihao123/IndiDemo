extends RefCounted
class_name EquipmentComponent
## 管 3 槽(weapon/armor/accessory):穿/脱 ItemInstance ↔ 向 StatsComponent 注入/回收 modifier。
## 注入 source=该实例 → unequip 时按 source 精确回收(无损,不变量 #2)。换装先脱旧再穿新,杜绝残留。

var _stats: StatsComponent
var _registry: DataRegistry
var _slots: Dictionary = {}   # slot(StringName) -> ItemInstance


func _init(stats: StatsComponent, registry: DataRegistry) -> void:
	_stats = stats
	_registry = registry


## 穿装:若该槽已穿先 unequip(无损回收旧件),再注入新件 modifier。返回被替换下来的旧件(无则 null)。
func equip(slot: StringName, instance: ItemInstance) -> ItemInstance:
	var prev := unequip(slot)
	_slots[slot] = instance
	for mod in instance.to_modifiers(_registry):
		_stats.add_modifier(mod)
	return prev


func unequip(slot: StringName) -> ItemInstance:
	var inst: ItemInstance = _slots.get(slot)
	if inst == null:
		return null
	_stats.remove_modifiers_by_source(inst)
	_slots.erase(slot)
	return inst


func get_equipped(slot: StringName) -> ItemInstance:
	return _slots.get(slot)


func is_slot_empty(slot: StringName) -> bool:
	return not _slots.has(slot)


func empty_slots() -> Array[StringName]:
	var out: Array[StringName] = []
	for slot in GameKeys.SLOTS:
		if not _slots.has(slot):
			out.append(slot)
	return out
