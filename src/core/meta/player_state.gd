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


## 手动换装(城镇主动路径,可替换;区别于挂机自动填空 i3 只增不替):
## 把背包里的 item 穿到 c 的 slot;原装备(若有)无损退回背包。
func equip_from_bag(c: Character, slot: StringName, item: ItemInstance) -> void:
	bag.erase(item)
	var prev: Variant = c.equipped.get(slot)
	if prev != null:
		bag.append(prev)
	c.equipped[slot] = item


## 脱下 c 的 slot 装备退回背包(空槽则无操作)。
func unequip_to_bag(c: Character, slot: StringName) -> void:
	var item: Variant = c.equipped.get(slot)
	if item == null:
		return
	c.equipped.erase(slot)
	bag.append(item)


## 强化 item 一级(确定性 +1,守 i7):满级 / 材料不足 → 拒绝且不扣半截材料,返回是否成功。
## 消耗该件所在槽的白材料 slot|white(item.base_id == slot)。
func enhance_item(item: ItemInstance, cfg: EnhanceConfigDef) -> bool:
	if item == null or cfg == null:
		return false
	if cfg.is_max(item.enhance_level):
		return false
	var cost := cfg.cost_for_level(item.enhance_level)
	if get_material(item.base_id, GameKeys.RARITY_WHITE) < cost:
		return false
	add_material(item.base_id, GameKeys.RARITY_WHITE, -cost)
	item.enhance_level += 1
	return true


## 清空全部持久态(roster/bag/materials)。autoload 在测试进程内持久,_boot 须 reset-on-boot
## 从干净态起,再 load 存档/默认 roster(ARCHITECTURE §4 不变量 8 / REFACTOR-02 §3)。
func reset() -> void:
	roster.clear()
	bag.clear()
	materials.clear()


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
