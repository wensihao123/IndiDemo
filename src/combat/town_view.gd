extends Control
class_name TownView
## MainArea 内的城镇枢纽(05-town + SC-02 / 10-ingame-flow-nav):城镇 = 家/枢纽,落点即此(暂停)。
## 纯视图执行器(SC-02 D2):**不再自决进出城**——pause/resume + flow 转移全由 GameFlow 主导;
## 本类只暴露 show_town()/show_combat() 切自身与兄弟 CombatView 的 .visible,及枢纽内四子板块导航。
## 枢纽四入口:小队(换装+对比)/ 工匠(强化)/ 酒馆(占位)/ 出征(选已解锁关→出击)。
## 子板块 = 覆盖式 overlay(.visible 切换),不开 Flow 态(M2 只认"在不在城镇")。
## 纯表现 + 调持久层元操作(equip_from_bag / enhance_item),逻辑已 gdUnit4 测。v1 单战士操作首个非空 roster。

const RARITY_COLOR := {
	&"white": Color(0.85, 0.85, 0.85),
	&"blue": Color(0.4, 0.6, 1.0),
	&"gold": Color(1.0, 0.82, 0.25),
}
const UP_COLOR := Color(0.4, 0.9, 0.45)    # 升:绿
const DOWN_COLOR := Color(0.95, 0.45, 0.4) # 降:红
const FLAT_COLOR := Color(0.7, 0.72, 0.78)

enum Board { HUB, PARTY, SMITH, TAVERN, DEPART }

var _gc: Node = null                  # /root/Game(GameController)
var _combat_view: Control = null      # 同 MainArea 的 CombatView,城镇态隐藏
var _selected_slot: StringName = GameKeys.SLOT_WEAPON
var _board := Board.HUB

var _town_root: Control = null        # 城镇内容根(默认隐藏,show_town/show_combat 切)
var _hub_root: Control = null         # 枢纽层(四入口 + 进度速览)
var _hub_progress: Label = null
# 四覆盖式子板块根(互斥 .visible)。
var _party_overlay: Control = null
var _smith_overlay: Control = null
var _tavern_overlay: Control = null
var _depart_overlay: Control = null
# 子板块内容列。
var _party_slot_col: VBoxContainer = null
var _party_bag_col: VBoxContainer = null
var _smith_slot_col: VBoxContainer = null
var _smith_enh_col: VBoxContainer = null
var _depart_col: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("town_view")  # 供 GameFlow 命令 show_town/show_combat + 查询 overlay 态
	_build_ui()
	_gc = get_node_or_null("/root/Game")
	_combat_view = get_parent().get_node_or_null("CombatView")
	_town_root.visible = false


# --- 纯视图切换(SC-02 D2:GameFlow 调,本类不碰 running)----------------------

## 显城镇枢纽:本视图可见 + 隐兄弟 CombatView + 复位到枢纽层并刷新。pause/resume 由 GameFlow 负责。
func show_town() -> void:
	_town_root.visible = true
	if _combat_view != null:
		_combat_view.visible = false
	_show_board(Board.HUB)
	_refresh()


## 显战斗视图:隐本城镇内容 + 显 CombatView。pause/resume 由 GameFlow 负责。
func show_combat() -> void:
	_town_root.visible = false
	if _combat_view != null:
		_combat_view.visible = true


# --- 枢纽 ↔ 子板块导航(overlay,非 Flow 态)---------------------------------

func _show_board(board: Board) -> void:
	_board = board
	_hub_root.visible = board == Board.HUB
	_party_overlay.visible = board == Board.PARTY
	_smith_overlay.visible = board == Board.SMITH
	_tavern_overlay.visible = board == Board.TAVERN
	_depart_overlay.visible = board == Board.DEPART
	if board != Board.HUB:
		_refresh()


## 供 GameFlow Esc 处理查询/收起(SC-02 R4:Esc 权威留 GameFlow,本类只答"有无子板块开"+收起)。
func is_overlay_open() -> bool:
	return _board != Board.HUB


func close_overlay_to_hub() -> void:
	_show_board(Board.HUB)


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


# --- 渲染:据当前打开的子板块刷新对应内容 ------------------------------------

func _refresh() -> void:
	_rebuild_hub_progress()
	match _board:
		Board.PARTY:
			_rebuild_slot_selector(_party_slot_col)
			_rebuild_party_bag()
		Board.SMITH:
			_rebuild_slot_selector(_smith_slot_col)
			_rebuild_smith_enhance()
		Board.DEPART:
			_rebuild_depart()
		_:
			pass


func _rebuild_hub_progress() -> void:
	if _hub_progress == null:
		return
	if _gc == null or _gc.progression == null:
		_hub_progress.text = ""
		return
	var prog = _gc.progression
	var stage_no: int = prog.cur_stage + 1
	var sc: int = prog.cur_scene
	var where := "Boss" if sc == ProgressionController.BOSS_SCENE else "场景 %d/3" % (sc + 1)
	_hub_progress.text = "当前进度:第 %d 关 · %s(挂机已暂停)" % [stage_no, where]


## 可选槽列表(小队 / 工匠共用):显当前装备,▶ 标选中槽,点击切槽并刷新。
func _rebuild_slot_selector(col: VBoxContainer) -> void:
	for ch in col.get_children():
		ch.queue_free()
	var c := _hero()
	if c == null:
		col.add_child(_label("(无角色)", 12, FLAT_COLOR))
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
		var scol := FLAT_COLOR
		if inst != null:
			desc = "ilvl%d %s%s" % [inst.ilvl, _rarity_text(inst.rarity),
				(" +%d" % inst.enhance_level) if inst.enhance_level > 0 else ""]
			scol = RARITY_COLOR.get(inst.rarity, FLAT_COLOR)
		row.add_child(_label("  " + desc, 12, scol))
		col.add_child(row)


## 小队·换装:列选中槽的可换背包件 + 换上后各轴差值(绿↑红↓)。
func _rebuild_party_bag() -> void:
	for ch in _party_bag_col.get_children():
		ch.queue_free()
	var c := _hero()
	if c == null or _gc.player_state == null:
		return
	_party_bag_col.add_child(_label("— 背包(%s)—" % _slot_text(_selected_slot), 13, Color(0.85, 0.88, 0.92)))
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
		_party_bag_col.add_child(head)
		if equipped != null:
			var after := _final_stats_if_equipped(c, _selected_slot, inst)
			for axis in GameKeys.STATS:
				var delta: float = float(after.get(axis, 0.0)) - float(cur_stats.get(axis, 0.0))
				if absf(delta) < 0.001:
					continue
				var arrow := "↑" if delta > 0.0 else "↓"
				var dcol := UP_COLOR if delta > 0.0 else DOWN_COLOR
				_party_bag_col.add_child(_label("      %s %s%s" % [_stat_name(axis), arrow,
					_format_stat_value(axis, absf(delta))], 10, dcol))
	if not any:
		_party_bag_col.add_child(_label("(无可换 %s)" % _slot_text(_selected_slot), 11, FLAT_COLOR))


## 工匠·强化:选中槽装备的 +N → +N+1 花费与按钮(v1 仅承现有"强化 +1")。
func _rebuild_smith_enhance() -> void:
	for ch in _smith_enh_col.get_children():
		ch.queue_free()
	var c := _hero()
	if c == null:
		return
	var inst: ItemInstance = c.equipped.get(_selected_slot)
	_smith_enh_col.add_child(_label("— %s —" % _slot_text(_selected_slot), 13, Color(0.85, 0.88, 0.92)))
	if inst == null:
		_smith_enh_col.add_child(_label("(空槽,先到小队穿上装备)", 11, FLAT_COLOR))
		return
	var cfg: EnhanceConfigDef = _registry().get_enhance_config() if _registry() != null else null
	if cfg == null:
		return
	if cfg.is_max(inst.enhance_level):
		_smith_enh_col.add_child(_label("强化:+%d(已满级)" % inst.enhance_level, 12, Color(1.0, 0.82, 0.25)))
		return
	var cost := cfg.cost_for_level(inst.enhance_level)
	var owned: int = _gc.player_state.get_material(inst.base_id, GameKeys.RARITY_WHITE)
	_smith_enh_col.add_child(_label("强化:+%d → +%d  花 %d 白材料(拥有 %d)"
		% [inst.enhance_level, inst.enhance_level + 1, cost, owned], 12, FLAT_COLOR))
	var enh_btn := Button.new()
	enh_btn.text = "强化 +1"
	enh_btn.disabled = owned < cost
	enh_btn.add_theme_font_size_override("font_size", 12)
	enh_btn.pressed.connect(_on_enhance.bind(inst))
	_smith_enh_col.add_child(enh_btn)


## 出征·选关:列 0..max_unlocked_stage 已解锁关 + "继续当前进度"出击(SC-02 D4)。
func _rebuild_depart() -> void:
	for ch in _depart_col.get_children():
		ch.queue_free()
	if _gc == null or _gc.progression == null:
		return
	var prog = _gc.progression
	var stages: Array = prog.stages
	_depart_col.add_child(_label("— 出征 · 选择关卡 —", 13, Color(0.85, 0.88, 0.92)))
	# 主出击:继续当前游标关(resume,吃下城镇换装/强化)。
	var cur_no: int = prog.cur_stage + 1
	var cont_btn := Button.new()
	cont_btn.text = "▶ 出击:继续第 %d 关(沿用当前进度)" % cur_no
	cont_btn.add_theme_font_size_override("font_size", 13)
	cont_btn.pressed.connect(_on_depart_continue)
	_depart_col.add_child(cont_btn)
	_depart_col.add_child(_label("— 或重选已解锁关卡 —", 11, FLAT_COLOR))
	for i in stages.size():
		var st = stages[i]
		var unlocked: bool = i <= prog.max_unlocked_stage
		var nm: String = st.stage_name if st != null and st.stage_name != "" else "第 %d 关" % (i + 1)
		var btn := Button.new()
		btn.text = ("第 %d 关 · %s" % [i + 1, nm]) + ("" if unlocked else "(未解锁)")
		btn.disabled = not unlocked
		btn.add_theme_font_size_override("font_size", 12)
		if unlocked:
			btn.pressed.connect(_on_depart_stage.bind(i))
		_depart_col.add_child(btn)


# --- 交互 ---------------------------------------------------------------

func _game_flow() -> Node:
	return get_tree().get_first_node_in_group("game_flow")


func _on_menu_pressed() -> void:
	# [☰] 系统枢纽:带来源态 TOWN,继续时恢复城镇几何且维持暂停。
	var gf := _game_flow()
	if gf != null:
		gf.open_menu(GameFlow.Return.TOWN)


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


## 出击:继续当前进度(resume,GameFlow 据 stage<0 走 resume_run)。
func _on_depart_continue() -> void:
	var gf := _game_flow()
	if gf != null:
		gf.on_depart(-1, -1)


## 出击:重选某已解锁关(begin_run 从该关场景 0 重装)。
func _on_depart_stage(stage: int) -> void:
	var gf := _game_flow()
	if gf != null:
		gf.on_depart(stage, 0)


# --- UI 构建(代码建子节点,减 .tscn 改动;占位排布交 Art Spec 全局 UI·juice 轮)----

func _build_ui() -> void:
	_town_root = Control.new()
	_town_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_town_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_town_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.09, 0.12, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_town_root.add_child(bg)

	_build_hub()
	_party_overlay = _build_overlay("小队 · 换装")
	_smith_overlay = _build_overlay("工匠 · 强化")
	_tavern_overlay = _build_overlay("酒馆")
	_depart_overlay = _build_overlay("出征")
	_build_party_overlay()
	_build_smith_overlay()
	_build_tavern_overlay()
	_build_depart_overlay()
	_show_board(Board.HUB)


func _build_hub() -> void:
	_hub_root = Control.new()
	_hub_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hub_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_town_root.add_child(_hub_root)

	var title := Label.new()
	title.text = "城镇 · 枢纽(家)"
	title.position = Vector2(20, 8)
	title.add_theme_font_size_override("font_size", 16)
	_hub_root.add_child(title)

	_hub_progress = _label("", 13, Color(0.8, 0.85, 0.9))
	_hub_progress.position = Vector2(20, 36)
	_hub_root.add_child(_hub_progress)

	# [☰] 系统枢纽入口(城镇态)。
	var menu_btn := Button.new()
	menu_btn.text = "☰"
	menu_btn.position = Vector2(740, 10)
	menu_btn.pressed.connect(_on_menu_pressed)
	_hub_root.add_child(menu_btn)

	# 四入口(占位横排)。出征最右、视觉权重最高留 Art Spec。
	var entries := [
		["小队", Board.PARTY],
		["工匠", Board.SMITH],
		["酒馆", Board.TAVERN],
		["出征", Board.DEPART],
	]
	var x := 30.0
	for e in entries:
		var b := Button.new()
		b.text = e[0]
		b.custom_minimum_size = Vector2(160, 56)
		b.position = Vector2(x, 90)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_show_board.bind(e[1]))
		_hub_root.add_child(b)
		x += 185.0


## 通用子板块外壳:标题 + 返回枢纽按钮;内容由各 _build_*_overlay 填。默认隐藏。
func _build_overlay(title_text: String) -> Control:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.visible = false
	_town_root.add_child(ov)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(20, 8)
	title.add_theme_font_size_override("font_size", 16)
	ov.add_child(title)

	var back := Button.new()
	back.text = "← 返回枢纽"
	back.position = Vector2(660, 10)
	back.add_theme_font_size_override("font_size", 12)
	back.pressed.connect(close_overlay_to_hub)
	ov.add_child(back)
	return ov


func _build_party_overlay() -> void:
	_party_slot_col = VBoxContainer.new()
	_party_slot_col.position = Vector2(20, 40)
	_party_slot_col.add_theme_constant_override("separation", 4)
	_party_overlay.add_child(_party_slot_col)

	# 背包可换件可能很多 → ScrollContainer(占位,精修留 UI·juice 轮)。
	var bag_scroll := ScrollContainer.new()
	bag_scroll.position = Vector2(300, 40)
	bag_scroll.size = Vector2(480, 200)
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_party_overlay.add_child(bag_scroll)
	_party_bag_col = VBoxContainer.new()
	_party_bag_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_bag_col.add_theme_constant_override("separation", 1)
	bag_scroll.add_child(_party_bag_col)


func _build_smith_overlay() -> void:
	_smith_slot_col = VBoxContainer.new()
	_smith_slot_col.position = Vector2(20, 40)
	_smith_slot_col.add_theme_constant_override("separation", 4)
	_smith_overlay.add_child(_smith_slot_col)

	_smith_enh_col = VBoxContainer.new()
	_smith_enh_col.position = Vector2(300, 40)
	_smith_enh_col.add_theme_constant_override("separation", 3)
	_smith_overlay.add_child(_smith_enh_col)


func _build_tavern_overlay() -> void:
	var lbl := _label("酒馆 · 招募(敬请期待)", 14, FLAT_COLOR)
	lbl.position = Vector2(40, 110)
	_tavern_overlay.add_child(lbl)


func _build_depart_overlay() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 40)
	scroll.size = Vector2(760, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_depart_overlay.add_child(scroll)
	_depart_col = VBoxContainer.new()
	_depart_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_depart_col.add_theme_constant_override("separation", 4)
	scroll.add_child(_depart_col)


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
