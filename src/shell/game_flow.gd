extends Control
class_name GameFlow
## 表现层流程协调节点(REFACTOR-05 / STATE-CHANGE-01):把"启动→主菜单→进游戏""游戏中 [☰] 回菜单"
## 等流程决策从 CombatView/TownView 收拢成一台显式流程机。向下调 Game(autoload)机制方法、横向调
## floating_shell 几何 API、自管四个菜单屏的 .visible。纯表现:逻辑层永不反依赖本节点(ARCHITECTURE §3.3)。

enum Flow { BOOT, TITLE, EXPLORE, TOWN, MENU_OVERLAY }
## [☰] 来源态:继续时回到哪个游戏语境(D6;GameFlow 不跟踪城镇态,由发起视图显式带入)。
enum Return { NONE, EXPLORE, TOWN }

## 本局可玩关卡(承自 CombatView 搬来;数据走 Resource,场景里拖 .tres,不硬编码路径)。
@export var stages: Array[StageConfig] = []

var _gc: Node = null          # /root/Game(GameController)
var _shell: Control = null    # 最近 FloatingShell(几何 API 宿主)
var _flow := Flow.BOOT
var _menu_return_to := Return.NONE
## 〔SC-02 D5〕「待回城」寄存器:EXPLORE 中点回城置真,下一波界结算时返城(支柱 1:不打断本波)。
var _return_pending := false

# 四菜单屏(代码建,减 .tscn 改动,同 CombatView/_build_ui 风格):主菜单 / 设置 / 覆盖确认 / 退出确认。
var _main_screen: Control = null
var _settings_screen: Control = null
var _overwrite_screen: Control = null
var _quit_screen: Control = null
var _continue_btn: Button = null  # 主菜单"继续":按 Game.has_save 切可点性


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("game_flow")
	_gc = get_node_or_null("/root/Game")
	_shell = get_parent() as Control
	# 〔SC-02 D4〕监听波界结算:待回城置真时,本波结算后延迟返城(call_deferred 避 tick 内重入)。
	if _gc != null and _gc.progression != null:
		_gc.progression.wave_boundary_settled.connect(_on_wave_boundary_settled)
	_build_screens()
	# 子节点 _ready 先于父:此刻 FloatingShell._ready 尚未跑(它随后 snap 到 expanded)。
	# 故延后入 TITLE,让 shell 几何先就位再切 MENU,否则被 shell 的 _snap_window 覆写回贴底。
	call_deferred("_enter_title")


# --- 流程入口 -----------------------------------------------------------

func _enter_title() -> void:
	_flow = Flow.TITLE
	_menu_return_to = Return.NONE
	if _shell != null:
		_shell.enter_menu_geometry()
	_show_only(_main_screen)
	_refresh_main_default()


## 〔SC-02 D3〕新游戏/继续落点 = 城镇枢纽(暂停):隐菜单屏、暂停 sim、开城镇视图、几何收缩贴底。
## 有意接受支柱 1"启动即陪伴"让位(落点决策方式 3),点「出征」才开打(on_depart)。
func _enter_town_hub() -> void:
	_flow = Flow.TOWN
	_menu_return_to = Return.NONE
	_return_pending = false
	_hide_all_screens()
	if _gc != null:
		_gc.pause_run()  # begin_run/new_game 已把 running 置真,落城镇即暂停
	var tv := get_tree().get_first_node_in_group("town_view")
	if tv != null and tv.has_method("show_town"):
		tv.show_town()
	if _shell != null:
		_shell.enter_game_geometry()


# --- 转移(照 STATE-CHANGE-01 §3.1 转移表)-------------------------------

func on_continue() -> void:
	# MENU_OVERLAY 的"继续" = 回来源态;TITLE 的"继续" = 按存档续战游标开局。
	if _flow == Flow.MENU_OVERLAY:
		_resume_to_source()
		return
	if _gc != null:
		_gc.begin_run(stages)  # 默认 stage/scene < 0 → 取存档续战游标
	_enter_town_hub()


func on_new_game() -> void:
	# 有档先过覆盖确认(破坏性动作);无档直接开 0-0 新局。
	if _gc != null and _gc.has_save:
		_show_only(_overwrite_screen)
	else:
		_do_new_game()


func _do_new_game() -> void:
	if _gc != null:
		_gc.new_game(stages)
	_enter_town_hub()


func on_open_settings() -> void:
	_show_only(_settings_screen)


func on_settings_back() -> void:
	_show_only(_main_screen)
	_refresh_main_default()


func on_quit() -> void:
	_show_only(_quit_screen)


func on_quit_confirm() -> void:
	if _gc != null:
		_gc.quit_game()


func on_quit_cancel() -> void:
	_show_only(_main_screen)
	_refresh_main_default()


func on_overwrite_confirm() -> void:
	_do_new_game()


func on_overwrite_cancel() -> void:
	_show_only(_main_screen)
	_refresh_main_default()


## [☰] 入口(CombatView/TownView 调):放大回主菜单覆盖层,记来源态。
## 守支柱 1:**不动 Game.arena.running**——菜单不暂停 sim。
func open_menu(src: Return) -> void:
	_menu_return_to = src
	_flow = Flow.MENU_OVERLAY
	if _shell != null:
		_shell.enter_menu_geometry()
	_show_only(_main_screen)
	_refresh_main_default()


## 从 MENU_OVERLAY 回来源态:仅恢复几何 + 隐菜单屏;running 维持来源值
## (EXPLORE 仍在打 / TOWN 仍暂停),不调 begin_run/resume——TownView 状态原样保留(D6)。
func _resume_to_source() -> void:
	var dest := _menu_return_to
	_menu_return_to = Return.NONE
	_hide_all_screens()
	if _shell != null:
		_shell.enter_game_geometry()
	_flow = Flow.TOWN if dest == Return.TOWN else Flow.EXPLORE


# --- SC-02 出征 / 待回城 转移 -------------------------------------------

## 〔SC-02 D4〕TownView「出征」调:从城镇枢纽开打。stage<0 = 继续当前进度(续战游标),
## 否则跳指定关开头;守 stage<=max_unlocked_stage(D4),越权直接忽略。开打=resume/begin_run 置 running 真。
func on_depart(stage: int, scene: int) -> void:
	if _gc == null:
		return
	var prog: ProgressionController = _gc.progression
	if prog != null and stage > prog.max_unlocked_stage:
		return
	if stage < 0:
		_gc.resume_run()  # 续当前进度:重快照队伍 + running=true,不动游标
	else:
		_gc.begin_run(stages, stage, scene)
	var tv := get_tree().get_first_node_in_group("town_view")
	if tv != null and tv.has_method("show_combat"):
		tv.show_combat()
	_flow = Flow.EXPLORE
	_return_pending = false
	if _shell != null:
		_shell.enter_game_geometry()


## 〔SC-02 D5〕CombatView「回城」调:EXPLORE 中切「待回城」标记(再点取消,R3)。
## 不立即返城——守不变量 #12 + 支柱 1,等本波结算(_on_wave_boundary_settled)才返。
func on_request_return() -> void:
	if _flow != Flow.EXPLORE:
		return
	_return_pending = not _return_pending


func is_return_pending() -> bool:
	return _return_pending


## 〔SC-02 D5〕波界结算钩子:待回城且仍在探索 → 延迟返城(call_deferred 避免在 Arena.tick 内重入)。
func _on_wave_boundary_settled() -> void:
	if _flow == Flow.EXPLORE and _return_pending:
		_return_pending = false
		call_deferred("_return_to_town_deferred")


func _return_to_town_deferred() -> void:
	_enter_town_hub()


# --- Esc 约定(UX-CHANGE-01 §0)-----------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ESCAPE:
		return
	# 子层(设置/覆盖确认/退出确认)Esc = 退一级回主菜单。
	if _settings_screen.visible or _overwrite_screen.visible or _quit_screen.visible:
		_show_only(_main_screen)
		_refresh_main_default()
		get_viewport().set_input_as_handled()
		return
	# 顶层 MENU_OVERLAY 的 Esc = 继续(回来源);顶层 TITLE 为根屏无 Esc 出口。
	if _flow == Flow.MENU_OVERLAY and _main_screen.visible:
		on_continue()
		get_viewport().set_input_as_handled()
		return
	# 〔SC-02 D6/R4〕城镇枢纽 Esc 分层:子板块开着 = 退回枢纽;已在枢纽 = 开菜单覆盖层。
	# GameFlow 为树末节点,_unhandled_input 最先收 Esc → 集中裁决,免与 TownView 抢吃。
	if _flow == Flow.TOWN:
		var tv := get_tree().get_first_node_in_group("town_view")
		if tv != null and tv.has_method("is_overlay_open") and tv.is_overlay_open():
			tv.close_overlay_to_hub()
		else:
			open_menu(Return.TOWN)
		get_viewport().set_input_as_handled()


# --- 屏可见性 -----------------------------------------------------------

func _refresh_main_default() -> void:
	# 有档:继续可点(主操作);无档:继续 disabled(新游戏为主)。
	var has_save: bool = _gc != null and _gc.has_save
	if _continue_btn != null:
		_continue_btn.disabled = not has_save


func _show_only(screen: Control) -> void:
	_main_screen.visible = screen == _main_screen
	_settings_screen.visible = screen == _settings_screen
	_overwrite_screen.visible = screen == _overwrite_screen
	_quit_screen.visible = screen == _quit_screen


func _hide_all_screens() -> void:
	_main_screen.visible = false
	_settings_screen.visible = false
	_overwrite_screen.visible = false
	_quit_screen.visible = false


# --- 菜单屏构建(占位:尺寸/视觉/排布交 Art Spec,并入全局 UI·juice 一轮)----

func _build_screens() -> void:
	_build_main_screen()
	_build_settings_screen()
	_overwrite_screen = _build_confirm_screen(
		"已有存档,新游戏将覆盖旧存档。确定?", on_overwrite_confirm, on_overwrite_cancel)
	_quit_screen = _build_confirm_screen("确定退出游戏?", on_quit_confirm, on_quit_cancel)
	_hide_all_screens()


func _build_main_screen() -> void:
	_main_screen = _make_screen()
	var box := _centered_box(_main_screen)
	var title := Label.new()
	title.text = "test-2"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	_continue_btn = _menu_button(box, "继续", on_continue)
	_menu_button(box, "新游戏", on_new_game)
	_menu_button(box, "设置", on_open_settings)
	_menu_button(box, "退出", on_quit)


func _build_settings_screen() -> void:
	_settings_screen = _make_screen()
	var box := _centered_box(_settings_screen)
	var lbl := Label.new()
	lbl.text = "设置(占位 · 音量/键位重映射/关于待补)"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	box.add_child(lbl)
	_menu_button(box, "返回", on_settings_back)


func _build_confirm_screen(msg: String, on_confirm: Callable, on_cancel: Callable) -> Control:
	var s := _make_screen()
	var box := _centered_box(s)
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	box.add_child(lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_menu_button(row, "确定", on_confirm)
	_menu_button(row, "取消", on_cancel)
	return s


func _make_screen() -> Control:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	s.visible = false
	add_child(s)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.10, 0.98)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	s.add_child(bg)
	return s


func _centered_box(screen: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	return box


func _menu_button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 0)
	b.pressed.connect(cb)
	box.add_child(b)
	return b
