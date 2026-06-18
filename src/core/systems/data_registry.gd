extends RefCounted
class_name DataRegistry
## 数据层:加载 + 校验装备/词缀/掉落表模板,对外发类型化 def(ARCHITECTURE §3.2)。
## 本批为普通类(非 autoload,PLAN D2);autoload 注册留第二批层 8 + Engine Integrator。
## 校验是防策划数据错的第一道闸(ARCHITECTURE §4#6):类型/门槛/部位池合法性。

const DEFAULT_CONFIG_DIR := "res://data/config"

var _item_bases: Dictionary = {}   # slot(StringName) -> ItemBaseDef
var _affixes: Array[AffixDef] = []
var _loot_table: LootTableDef = null
var _starting_roster: Array[Character] = []   # 默认起始队伍(PLAN D3,取代旧 director @export warrior_*)
var _errors: Array[String] = []


## 从磁盘加载三份 JSON 并 ingest(PLAN D3:目录可注入,默认是结构常量非平衡数值)。
## 返回是否成功(无错误);失败详情见 get_load_errors()。
func load_all(config_dir: String = DEFAULT_CONFIG_DIR) -> bool:
	_errors.clear()
	var bases: Variant = _read_json(config_dir.path_join("item_bases.json"))
	var affixes: Variant = _read_json(config_dir.path_join("affix_pool.json"))
	var table: Variant = _read_json(config_dir.path_join("loot_tables.json"))
	var roster: Variant = _read_json(config_dir.path_join("starting_roster.json"))
	if not _errors.is_empty():
		return false
	if not (bases is Dictionary):
		_errors.append("item_bases.json 顶层须为对象")
	if not (affixes is Array):
		_errors.append("affix_pool.json 顶层须为数组")
	if not (table is Dictionary):
		_errors.append("loot_tables.json 顶层须为对象")
	if not (roster is Array):
		_errors.append("starting_roster.json 顶层须为数组")
	if not _errors.is_empty():
		return false
	ingest(bases, affixes, table)        # 填 _errors(三模板)
	_ingest_starting_roster(roster)      # 追加 roster 错(不清 _errors)
	return _errors.is_empty()


## 校验并构建 def 对象(可被测试直接喂内存数据,无需 fixture 文件,PLAN D3)。
## 任何校验错收进 _errors 且不静默吞;返回是否全部通过。
func ingest(bases: Dictionary, affixes: Array, table: Dictionary) -> bool:
	_item_bases.clear()
	_affixes.clear()
	_loot_table = null
	_errors.clear()
	_ingest_bases(bases)
	_ingest_affixes(affixes)
	_ingest_loot_table(table)
	return _errors.is_empty()


# ── 访问器 ────────────────────────────────────────────────────────────────────

func get_item_base(slot: StringName) -> ItemBaseDef:
	return _item_bases.get(slot)


## 某部位词缀池:slot_pool 含该 slot 的全部 AffixDef。
func get_affixes_for_slot(slot: StringName) -> Array[AffixDef]:
	var out: Array[AffixDef] = []
	for a in _affixes:
		if a.slot_pool.has(slot):
			out.append(a)
	return out


func get_loot_table() -> LootTableDef:
	return _loot_table


## 默认起始队伍的深拷贝(每次新建 Character,避免装备/状态跨局串)。
func get_starting_roster() -> Array[Character]:
	var out: Array[Character] = []
	for c in _starting_roster:
		out.append(Character.from_dict(c.to_dict()))
	return out


## 供测试直接喂内存 roster 数据(并行 ingest();清错后单独校验 roster)。
func ingest_starting_roster(roster: Array) -> bool:
	_errors.clear()
	_ingest_starting_roster(roster)
	return _errors.is_empty()


func get_load_errors() -> Array[String]:
	return _errors


func is_valid() -> bool:
	return _errors.is_empty()


# ── 解析 + 校验 ───────────────────────────────────────────────────────────────

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_errors.append("找不到配置文件:%s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		_errors.append("JSON 解析失败:%s" % path)
	return parsed


func _ingest_bases(bases: Dictionary) -> void:
	for slot in bases.keys():
		var slot_sn := StringName(slot)
		var raw: Variant = bases[slot]
		if not (raw is Dictionary):
			_errors.append("基底 %s 须为对象" % slot)
			continue
		if not GameKeys.SLOTS.has(slot_sn):
			_errors.append("基底 %s:未知部位" % slot)
			continue
		var d: ItemBaseDef = ItemBaseDef.new()
		d.slot = slot_sn
		d.signature_mode = StringName(raw.get("signature_mode", GameKeys.SIG_ALL))
		if not GameKeys.SIG_MODES.has(d.signature_mode):
			_errors.append("基底 %s:未知 signature_mode=%s" % [slot, d.signature_mode])
		d.signature_axes = _to_stringname_array(raw.get("signature_axes", []))
		for axis in d.signature_axes:
			if not GameKeys.STATS.has(axis):
				_errors.append("基底 %s:招牌轴 %s 不是合法维度" % [slot, axis])
		var curves: Variant = raw.get("base_curves", {})
		if curves is Dictionary:
			d.base_curves = curves
		else:
			_errors.append("基底 %s:base_curves 须为对象" % slot)
		_item_bases[slot_sn] = d


func _ingest_affixes(affixes: Array) -> void:
	for i in affixes.size():
		var raw: Variant = affixes[i]
		if not (raw is Dictionary):
			_errors.append("词缀[%d] 须为对象" % i)
			continue
		var a: AffixDef = AffixDef.new()
		a.stat = StringName(raw.get("stat", ""))
		if not GameKeys.STATS.has(a.stat):
			_errors.append("词缀[%d]:stat=%s 不是合法维度" % [i, a.stat])
		a.kind = StringName(raw.get("kind", GameKeys.KIND_FLAT))
		if not GameKeys.KINDS.has(a.kind):
			_errors.append("词缀[%d]:未知 kind=%s" % [i, a.kind])
		a.slot_pool = _to_stringname_array(raw.get("slot_pool", []))
		for s in a.slot_pool:
			if not GameKeys.SLOTS.has(s):
				_errors.append("词缀[%d]:部位池含未知部位 %s" % [i, s])
		var tiers: Variant = raw.get("tiers", [])
		if tiers is Array and not (tiers as Array).is_empty():
			a.tiers = tiers
			_validate_tiers(i, tiers)
		else:
			_errors.append("词缀[%d]:tiers 须为非空数组" % i)
		_affixes.append(a)


func _validate_tiers(affix_index: int, tiers: Array) -> void:
	for t in tiers:
		if not (t is Dictionary):
			_errors.append("词缀[%d]:某 Tier 非对象" % affix_index)
			continue
		var lo := float(t.get("min", 0.0))
		var hi := float(t.get("max", 0.0))
		if lo > hi:
			_errors.append("词缀[%d] Tier%s:min(%s) > max(%s)" % [affix_index, t.get("tier"), lo, hi])
		if int(t.get("ilvl_req", 0)) < 1:
			_errors.append("词缀[%d] Tier%s:ilvl_req 须 ≥ 1" % [affix_index, t.get("tier")])


func _ingest_loot_table(table: Dictionary) -> void:
	var d: LootTableDef = LootTableDef.new()
	var rc: Variant = table.get("rarity_affix_count", {})
	if rc is Dictionary:
		var typed: Dictionary = {}
		for rarity in rc.keys():
			var rsn := StringName(rarity)
			if not GameKeys.RARITIES.has(rsn):
				_errors.append("掉落表:未知稀有度 %s" % rarity)
				continue
			var pair: Variant = rc[rarity]
			if pair is Array and (pair as Array).size() == 2 and int(pair[0]) <= int(pair[1]):
				typed[rsn] = pair
			else:
				_errors.append("掉落表 %s:词缀条数须为 [min,max] 且 min≤max" % rarity)
		d.rarity_affix_count = typed
		# 完整性闸:三档稀有度须齐全,缺档会让该档静默掉成 0 条词缀(策划数据陷阱)。
		for required in GameKeys.RARITIES:
			if not typed.has(required):
				_errors.append("掉落表:缺稀有度 %s 的词缀条数配置" % required)
	else:
		_errors.append("掉落表:rarity_affix_count 须为对象")
	d.decompose_threshold = StringName(table.get("decompose_threshold", GameKeys.RARITY_WHITE))
	if not GameKeys.RARITIES.has(d.decompose_threshold):
		_errors.append("掉落表:未知分解门槛 %s" % d.decompose_threshold)
	d.material_per_decompose = int(table.get("material_per_decompose", 1))
	_loot_table = d


func _ingest_starting_roster(roster: Array) -> void:
	_starting_roster.clear()
	for i in roster.size():
		var raw: Variant = roster[i]
		if not (raw is Dictionary):
			_errors.append("起始 roster[%d] 须为对象" % i)
			continue
		var id_str := String(raw.get("id", ""))
		if id_str.is_empty():
			_errors.append("起始 roster[%d]:id 不能为空" % i)
		var c: Character = Character.new(StringName(id_str), StringName(raw.get("class_id", "")))
		c.display_name = String(raw.get("display_name", ""))
		var bs: Variant = raw.get("base_stats", {})
		if bs is Dictionary:
			for stat in (bs as Dictionary).keys():
				var stat_sn := StringName(stat)
				if not GameKeys.STATS.has(stat_sn):
					_errors.append("起始 roster[%d]:未知属性 %s" % [i, stat])
					continue
				var v: Variant = bs[stat]
				if not (v is float or v is int):
					_errors.append("起始 roster[%d]:属性 %s 值须为数字" % [i, stat])
					continue
				c.base_stats[stat_sn] = float(v)
		else:
			_errors.append("起始 roster[%d]:base_stats 须为对象" % i)
		_starting_roster.append(c)


func _to_stringname_array(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if v is Array:
		for e in v:
			out.append(StringName(e))
	return out
