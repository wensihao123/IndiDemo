extends RefCounted
class_name StatsComponent
## 属性引擎:基底 + 修饰符列表 → 终值 Final = (base + Σflat) × (1 + Σpercent)。
## 脏标记缓存:任何写操作置脏,读时按需重算整张表(ARCHITECTURE §3.2)。
## invariant #2(无损):add 后按 source 移除,终值精确回到 add 前 —— 卸装备不能掉精度。

var _base: Dictionary = {}            # stat(StringName) -> float
var _modifiers: Array[StatModifier] = []
var _cache: Dictionary = {}           # stat(StringName) -> float
var _dirty: bool = true


func set_base(stat: StringName, value: float) -> void:
	_base[stat] = value
	_dirty = true


func get_base(stat: StringName) -> float:
	return float(_base.get(stat, 0.0))


func add_modifier(mod: StatModifier) -> void:
	_modifiers.append(mod)
	_dirty = true


## 按来源移除全部修饰符(卸装备/buff 到期);返回移除条数。
func remove_modifiers_by_source(source: Variant) -> int:
	var before := _modifiers.size()
	var kept: Array[StatModifier] = []
	for m in _modifiers:
		if m.source != source:
			kept.append(m)
	_modifiers = kept
	if _modifiers.size() != before:
		_dirty = true
	return before - _modifiers.size()


func clear_modifiers() -> void:
	if not _modifiers.is_empty():
		_modifiers.clear()
		_dirty = true


func get_final(stat: StringName) -> float:
	if _dirty:
		_recompute()
	return float(_cache.get(stat, 0.0))


func _recompute() -> void:
	var flat: Dictionary = {}      # stat -> Σflat
	var percent: Dictionary = {}   # stat -> Σpercent
	for m in _modifiers:
		if m.kind == StatModifier.Kind.PERCENT:
			percent[m.stat] = float(percent.get(m.stat, 0.0)) + m.value
		else:
			flat[m.stat] = float(flat.get(m.stat, 0.0)) + m.value
	_cache.clear()
	var stats := {}
	for s in _base.keys():
		stats[s] = true
	for s in flat.keys():
		stats[s] = true
	for s in percent.keys():
		stats[s] = true
	for s in stats.keys():
		var v := (get_base(s) + float(flat.get(s, 0.0))) * (1.0 + float(percent.get(s, 0.0)))
		_cache[s] = v
	_dirty = false
