extends Control
class_name TownView
## MainArea 内的城镇工作台(05-town,REFACTOR-03):进城暂停挂机 → 手动换装 + 对比面板 + 装备强化。
## 独立界面(非模态浮窗):进城 Game.pause_run() 冻结战斗、显本视图、隐 CombatView;出城反之 Game.resume_run()。
## 纯表现 + 调持久层元操作(PlayerState.equip_from_bag / unequip_to_bag / enhance_item),逻辑已 gdUnit4 测。
## v1 单战士:操作首个非空 roster Character 的三槽。

const RARITY_COLOR := {
	&"white": Color(0.85, 0.85, 0.85),
	&"blue": Color(0.4, 0.6, 1.0),
	&"gold": Color(1.0, 0.82, 0.25),
}
const UP_COLOR := Color(0.4, 0.9, 0.45)    # 升:绿
const DOWN_COLOR := Color(0.95, 0.45, 0.4) # 降:红
const FLAT_COLOR := Color(0.7, 0.72, 0.78)

var _gc: Node = null                  # /root/Game(GameController)
var _combat_view: Control = null      # 同 MainArea 的 CombatView,进城时隐藏
var _selected_slot: StringName = GameKeys.SLOT_WEAPON

@onready var _enter_btn := Button.new()     # 战斗态可见:进城
@onready var _town_root := Control.new()    # 城镇内容根(默认隐藏)
@onready var _leave_btn := Button.new()     # 城镇态可见:出城
@onready var _slot_col := VBoxContainer.new()    # 左:三槽 + 当前装备 + 强化
@onready var _compare_col := VBoxContainer.new() # 中:选中槽的对比/强化信息
@onready var _bag_col := VBoxContainer.new()     # 右:可换入背包件


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_gc = get_node_or_null("/root/Game")
	_combat_view = get_parent().get_node_or_null("CombatView")
	_town_root.visible = false


# --- 进/出城 -------------------------------------------------------------

func _enter_town() -> void:
	if _gc == null:
		return
	_gc.pause_run()
	_town_root.visible = true
	_enter_btn.visible = false
	if _combat_view != null:
		_combat_view.visible = false
	_refresh()


func _leave_town() -> void:
	if _gc == null:
		return
	_gc.resume_run()
	_town_root.visible = false
	_enter_btn.visible = true
	if _combat_view != null:
		_combat_view.visible = true


# --- 数据 ---------------------------------------------------------------

func _hero() -> Character:
	if _gc == null or _gc.player_state == null:
		return null
	for c in _gc.player_state.roster:
		if c != null:
			return c
	return null


func _registry() -> DataRegistry:
	return _gc.registry if _gc != null else null


## 角色当前 8 维终值(经属性引擎,反映装备 + 强化)。
func _final_stats(c: Character) -> Dictionary:
	var d: Dictionary = {}
	if c == null or _registry() == null:
		return d
	var e := Entity.from_character(c, _registry())
	for axis in GameKeys.STATS:
		d[axis] = e.stats.get_final(axis)
	return d


## 把 c 的 slot 换成 candidate 后的 8 维终值(克隆角色算,不改原件)。
func _final_stats_if_equipped(c: Character, slot: StringName, candidate: ItemInstance) -> Dictionary:
	var clone := Character.from_dict(c.to_dict())
	clone.equipped[slot] = ItemInstance.from_dict(candidate.to_dict())
	return _final_stats(clone)


# --- 渲染 ---------------------------------------------------------------

func _refresh() -> void:
	_rebuild_slots()
	_rebuild_compare()
	_rebuild_bag()


func _rebuild_slots() -> void:
	for ch in _slot_col.get_children():
		ch.queue_free()
	var c := _hero()
	if c == null:
		_slot_col.add_child(_label("(无角色)", 12, FLAT_COLOR))
		return
	for slot in GameKeys.SLOTS:
		var inst: ItemInstance = c.equipped.get(slot)
		var row := HBoxContainer.new()
		var sel_btn := Button.new()
		sel_btn.text = ("▶ " if slot == _selected_slot else "  ") + _slot_text(slot)
		sel_btn.add_theme_font_size_override("font_size", 12)
		sel_btn.pressed.connect(_on_select_slot.bind(slot))
		row.add_child(sel_btn)
		var desc := "—"
		var col := FLAT_COLOR
		if inst != null:
			desc = "ilvl%d %s%s" % [inst.ilvl, _rarity_text(inst.rarity),
				(" +%d" % inst.enhance_level) if inst.enhance_level > 0 else ""]
			col = RARITY_COLOR.get(inst.rarity, FLAT_COLOR)
		row.add_child(_label("  " + desc, 12, col))
		_slot_col.add_child(row)


func _rebuild_compare() -> void:
	for ch in _compare_col.get_children():
		ch.queue_free()
	var c := _hero()
	if c == null:
		return
	var inst: ItemInstance = c.equipped.get(_selected_slot)
	_compare_col.add_child(_label("— %s —" % _slot_text(_selected_slot), 13, Color(0.85, 0.88, 0.92)))
	if inst == null:
		_compare_col.add_child(_label("(空槽,从右侧背包穿上)", 11, FLAT_COLOR))
		return
	# 强化信息行 + 按钮
	var cfg: EnhanceConfigDef = _registry().get_enhance_config() if _registry() != null else null
	if cfg != null:
		if cfg.is_max(inst.enhance_level):
			_compare_col.add_child(_label("强化:+%d(已满级)" % inst.enhance_level, 12, Color(1.0, 0.82, 0.25)))
		else:
			var cost := cfg.cost_for_level(inst.enhance_level)
			var owned: int = _gc.player_state.get_material(inst.base_id, GameKeys.RARITY_WHITE)
			_compare_col.add_child(_label("强化:+%d → +%d  花 %d 白材料(拥有 %d)"
				% [inst.enhance_level, inst.enhance_level + 1, cost, owned], 12, FLAT_COLOR))
			var enh_btn := Button.new()
			enh_btn.text = "强化 +1"
			enh_btn.disabled = owned < cost
			enh_btn.add_theme_font_size_override("font_size", 12)
			enh_btn.pressed.connect(_on_enhance.bind(inst))
			_compare_col.add_child(enh_btn)


func _rebuild_bag() -> void:
	for ch in _bag_col.get_children():
		ch.queue_free()
	var c := _hero()
	if c == null or _gc.player_state == null:
		return
	_bag_col.add_child(_label("— 背包(%s)—" % _slot_text(_selected_slot), 13, Color(0.85, 0.88, 0.92)))
	var equipped: ItemInstance = c.equipped.get(_selected_slot)
	var cur_stats := _final_stats(c)
	var any := false
	for inst in _gc.player_state.bag:
		if inst.base_id != _selected_slot:
			continue
		any = true
		var col: Color = RARITY_COLOR.get(inst.rarity, FLAT_COLOR)
		var head := HBoxContainer.new()
		var swap_btn := Button.new()
		swap_btn.text = "换"
		swap_btn.add_theme_font_size_override("font_size", 11)
		swap_btn.pressed.connect(_on_swap.bind(inst))
		head.add_child(swap_btn)
		head.add_child(_label("  ilvl%d %s%s" % [inst.ilvl, _rarity_text(inst.rarity),
			(" +%d" % inst.enhance_level) if inst.enhance_level > 0 else ""], 12, col))
		_bag_col.add_child(head)
		# 对比面板:换上后各轴差值(绿↑红↓),只列有变化的轴。
		if equipped != null:
			var after := _final_stats_if_equipped(c, _selected_slot, inst)
			for axis in GameKeys.STATS:
				var delta: float = float(after.get(axis, 0.0)) - float(cur_stats.get(axis, 0.0))
				if absf(delta) < 0.001:
					continue
				var arrow := "↑" if delta > 0.0 else "↓"
				var dcol := UP_COLOR if delta > 0.0 else DOWN_COLOR
				_bag_col.add_child(_label("      %s %s%s" % [_stat_name(axis), arrow,
					_format_stat_value(axis, absf(delta))], 10, dcol))
	if not any:
		_bag_col.add_child(_label("(无可换 %s)" % _slot_text(_selected_slot), 11, FLAT_COLOR))


# --- 交互 ---------------------------------------------------------------

func _on_select_slot(slot: StringName) -> void:
	_selected_slot = slot
	_refresh()


func _on_swap(inst: ItemInstance) -> void:
	var c := _hero()
	if c == null:
		return
	_gc.player_state.equip_from_bag(c, _selected_slot, inst)
	_refresh()


func _on_enhance(inst: ItemInstance) -> void:
	var cfg: EnhanceConfigDef = _registry().get_enhance_config() if _registry() != null else null
	if cfg == null:
		return
	if _gc.player_state.enhance_item(inst, cfg):
		_refresh()


# --- UI 构建 ------------------------------------------------------------

func _build_ui() -> void:
	_enter_btn.text = "进城"
	_enter_btn.position = Vector2(300, 12)
	_enter_btn.pressed.connect(_enter_town)
	add_child(_enter_btn)

	_town_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_town_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_town_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.09, 0.12, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_town_root.add_child(bg)

	var title := Label.new()
	title.text = "城镇 · 工作台"
	title.position = Vector2(20, 8)
	title.add_theme_font_size_override("font_size", 16)
	_town_root.add_child(title)

	_leave_btn.text = "出城"
	_leave_btn.position = Vector2(710, 10)
	_leave_btn.pressed.connect(_leave_town)
	_town_root.add_child(_leave_btn)

	_slot_col.position = Vector2(20, 40)
	_slot_col.add_theme_constant_override("separation", 4)
	_town_root.add_child(_slot_col)

	_compare_col.position = Vector2(300, 40)
	_compare_col.add_theme_constant_override("separation", 3)
	_town_root.add_child(_compare_col)

	# 背包可换件可能很多 → 套 ScrollContainer 才能滚到底(占位,精修留 UI·juice 轮)。
	var bag_scroll := ScrollContainer.new()
	bag_scroll.position = Vector2(540, 40)
	bag_scroll.size = Vector2(250, 205)
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_town_root.add_child(bag_scroll)
	_bag_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_col.add_theme_constant_override("separation", 1)
	bag_scroll.add_child(_bag_col)


# --- 格式化(与 CombatView 同语言;v1 三行重复优于过早抽象)----------------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _slot_text(slot: StringName) -> String:
	match slot:
		GameKeys.SLOT_WEAPON: return "武器"
		GameKeys.SLOT_ARMOR: return "护甲"
		GameKeys.SLOT_ACCESSORY: return "饰品"
		_: return String(slot)


func _rarity_text(rarity: StringName) -> String:
	match rarity:
		&"white": return "白"
		&"blue": return "蓝"
		&"gold": return "金"
		_: return String(rarity)


func _stat_name(stat: StringName) -> String:
	match stat:
		GameKeys.STAT_ATTACK: return "攻击"
		GameKeys.STAT_MAX_HP: return "生命"
		GameKeys.STAT_ATTACK_SPEED: return "攻速"
		GameKeys.STAT_ARMOR: return "护甲"
		GameKeys.STAT_DODGE_CHANCE: return "闪避"
		GameKeys.STAT_CRIT_CHANCE: return "暴击率"
		GameKeys.STAT_CRIT_MULT: return "暴伤"
		GameKeys.STAT_HP_REGEN: return "回血"
		_: return String(stat)


func _format_stat_value(stat: StringName, v: float) -> String:
	match stat:
		GameKeys.STAT_CRIT_CHANCE, GameKeys.STAT_DODGE_CHANCE:
			return "%.1f%%" % (v * 100.0)
		GameKeys.STAT_CRIT_MULT:
			return "×%.2f" % v
		GameKeys.STAT_ATTACK_SPEED:
			return "%.2f/s" % v
		GameKeys.STAT_HP_REGEN:
			return "%.1f/s" % v
		_:
			return str(int(round(v)))
