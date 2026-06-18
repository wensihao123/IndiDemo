extends Node
class_name PlayerState
## 持久元状态层根(ARCHITECTURE §3.1):角色队伍 + 背包 + 分解材料。
## 本批不注册 autoload(PLAN D2);用 Node 是为日后进树发跨系统 signal。可序列化(D6)。

signal material_gained(slot: StringName, rarity: StringName, amount: int)

var roster: Array[Character] = []
var bag: Array[ItemInstance] = []
var materials: Dictionary = {}   # "slot|rarity" -> int


## 材料按 (部位×稀有度) 累加;发 material_gained 供 UI/成就等跨系统消费。
func add_material(slot: StringName, rarity: StringName, amount: int = 1) -> void:
	var key := _mat_key(slot, rarity)
	materials[key] = int(materials.get(key, 0)) + amount
	material_gained.emit(slot, rarity, amount)


func get_material(slot: StringName, rarity: StringName) -> int:
	return int(materials.get(_mat_key(slot, rarity), 0))


func add_to_bag(instance: ItemInstance) -> void:
	bag.append(instance)


func to_dict() -> Dictionary:
	var roster_d: Array = []
	for c in roster:
		roster_d.append(c.to_dict())
	var bag_d: Array = []
	for i in bag:
		bag_d.append(i.to_dict())
	return {"roster": roster_d, "bag": bag_d, "materials": materials.duplicate()}


func from_dict(d: Dictionary, registry: DataRegistry = null) -> void:
	roster.clear()
	bag.clear()
	materials.clear()
	for cd in d.get("roster", []):
		roster.append(Character.from_dict(cd, registry))
	for idict in d.get("bag", []):
		bag.append(ItemInstance.from_dict(idict))
	for k in d.get("materials", {}).keys():
		materials[k] = int(d["materials"][k])


func _mat_key(slot: StringName, rarity: StringName) -> String:
	return "%s|%s" % [slot, rarity]
