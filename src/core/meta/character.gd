extends RefCounted
class_name Character
## 持久角色单元:身份 + 8 维基底 + 已装备(slot→ItemInstance)。可序列化(PLAN D6)。
## 运行时由 base_stats 建 StatsComponent;equipped 是持久记录,装备实例存 base_id 回查重建。

var id: StringName
var class_id: StringName
var display_name: String = ""                # 队伍显示名(持久角色数据,View 平迁名字来源,PLAN D7)
var base_stats: Dictionary = {}              # stat(StringName) -> float
var equipped: Dictionary = {}                # slot(StringName) -> ItemInstance


func _init(p_id: StringName = &"", p_class_id: StringName = &"") -> void:
	id = p_id
	class_id = p_class_id


## 由持久基底建一个属性引擎(不含装备 modifier;装备由 EquipmentComponent 另行注入)。
func build_stats() -> StatsComponent:
	var s := StatsComponent.new()
	for stat in base_stats.keys():
		s.set_base(StringName(stat), float(base_stats[stat]))
	return s


func to_dict() -> Dictionary:
	var eq: Dictionary = {}
	for slot in equipped.keys():
		eq[String(slot)] = (equipped[slot] as ItemInstance).to_dict()
	return {"id": String(id), "class_id": String(class_id), "display_name": display_name,
		"base_stats": base_stats.duplicate(), "equipped": eq}


static func from_dict(d: Dictionary, _registry: DataRegistry = null) -> Character:
	var c := Character.new(StringName(d.get("id", "")), StringName(d.get("class_id", "")))
	c.display_name = String(d.get("display_name", ""))
	c.base_stats = (d.get("base_stats", {}) as Dictionary).duplicate()
	var eq_in: Dictionary = d.get("equipped", {})
	for slot in eq_in.keys():
		c.equipped[StringName(slot)] = ItemInstance.from_dict(eq_in[slot])
	return c
