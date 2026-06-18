extends RefCounted
class_name ItemInstance
## 运行时装备实例:存模板 id(base_id=slot)而非对象引用,取 def 时回查 DataRegistry(PLAN D6 可序列化)。
## 终值贡献 = 基底招牌轴(按 ilvl 算)+ 每条 affix;to_modifiers 把它摊成 StatModifier 喂属性引擎。

var base_id: StringName              # = slot(item_bases.json 以 slot 为键)
var ilvl: int = 1
var rarity: StringName = GameKeys.RARITY_WHITE
var signature_axes: Array[StringName] = []   # 本件实际生效的招牌轴(ALL=全轴 / PICK_ONE=选中那一轴)
var affixes: Array[AffixRoll] = []


func _init(p_base_id: StringName = &"", p_ilvl: int = 1, p_rarity: StringName = GameKeys.RARITY_WHITE) -> void:
	base_id = p_base_id
	ilvl = p_ilvl
	rarity = p_rarity


## 摊成 modifier 列表喂 StatsComponent;source=本实例,保证按 source 无损卸下(不变量 #2)。
func to_modifiers(registry: DataRegistry) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	var base := registry.get_item_base(base_id)
	if base != null:
		for axis in signature_axes:
			out.append(StatModifier.new(axis, StatModifier.Kind.FLAT, base.base_value(axis, ilvl), self))
	for roll in affixes:
		out.append(StatModifier.new(roll.stat, StatModifier.kind_from_name(roll.kind), roll.value, self))
	return out


func to_dict() -> Dictionary:
	var rolls: Array = []
	for r in affixes:
		rolls.append(r.to_dict())
	var axes: Array = []
	for a in signature_axes:
		axes.append(String(a))
	return {"base_id": String(base_id), "ilvl": ilvl, "rarity": String(rarity),
		"signature_axes": axes, "affixes": rolls}


static func from_dict(d: Dictionary) -> ItemInstance:
	var inst := ItemInstance.new(StringName(d.get("base_id", "")), int(d.get("ilvl", 1)),
		StringName(d.get("rarity", GameKeys.RARITY_WHITE)))
	var axes: Array[StringName] = []
	for a in d.get("signature_axes", []):
		axes.append(StringName(a))
	inst.signature_axes = axes
	var rolls: Array[AffixRoll] = []
	for r in d.get("affixes", []):
		rolls.append(AffixRoll.from_dict(r))
	inst.affixes = rolls
	return inst
