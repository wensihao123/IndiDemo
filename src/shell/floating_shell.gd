extends Control
## 悬浮窗外壳控制器。主窗口即悬浮窗(PLAN D1):无边框、置顶、运行时贴主显示器底部。
## 负责:贴底定位、800×250 居中主区的窄屏兜底、占位角色待机微动、收起/展开状态机、置顶切换。

enum State { EXPANDED, COLLAPSED }

const MAIN_WIDTH := 800.0
const EXPANDED_HEIGHT := 250
const COLLAPSED_SIZE := Vector2i(64, 64)

@export_group("过渡")
## 收起/展开时内容淡入/淡出各自的时长(秒)。窗口几何在"全透明不可见"瞬间直接跳变,
## 不逐帧缓动几何 → 规避 Windows 改窗几何的抖动(PLAN R1 退路)。
@export var content_fade_duration := 0.12
@export_group("待机微动")
## 角色上下浮动幅度(像素)。PLAN D4。
@export var idle_bob_amplitude := 4.0
## 一个完整呼吸循环的时长(秒)。
@export var idle_bob_period := 2.0
## 缩放呼吸幅度(比例,0.015 = ±1.5%)。
@export var idle_scale_amplitude := 0.015
@export_group("帧率")
## 展开态封顶帧率。PLAN D6。
@export var fps_expanded := 60
## 收起态封顶帧率(几乎不动,进一步降耗)。
@export var fps_collapsed := 15
@export_group("热键")
## 收起/展开热键(默认 F1)。仅窗口聚焦时生效(PLAN R2)。
@export var key_toggle_collapse := KEY_F1
## 置顶切换热键(默认 F2)。
@export var key_toggle_always_on_top := KEY_F2

@onready var bg_strip: TextureRect = $BgStrip
@onready var main_area: Control = $MainArea
@onready var hero: Sprite2D = $MainArea/Hero
@onready var handle: TextureButton = $Handle
@onready var collapse_btn: Button = $CollapseBtn

var _state := State.EXPANDED
var _always_on_top := true
var _usable_rect := Rect2i()
var _hero_base_pos := Vector2.ZERO
var _hero_base_scale := Vector2.ONE
var _idle_time := 0.0
var _geom_tween: Tween


func _ready() -> void:
	_hero_base_pos = hero.position
	_hero_base_scale = hero.scale
	_resolve_usable_rect()
	_snap_window(_expanded_rect())
	Engine.max_fps = fps_expanded
	handle.pressed.connect(_on_toggle_pressed)
	collapse_btn.pressed.connect(_on_toggle_pressed)
	_refresh_visibility()


func _process(delta: float) -> void:
	# 待机微动靠代码 Tween 之外的逐帧正弦驱动:循环不依赖定位是否成功(PLAN step7)。
	if _state != State.EXPANDED:
		return
	_idle_time += delta
	var phase := TAU * _idle_time / idle_bob_period
	hero.position = _hero_base_pos + Vector2(0.0, -idle_bob_amplitude * sin(phase))
	var s := 1.0 + idle_scale_amplitude * sin(phase)
	hero.scale = _hero_base_scale * s


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == key_toggle_collapse:
			_toggle_collapse()
			get_viewport().set_input_as_handled()
		elif event.keycode == key_toggle_always_on_top:
			_toggle_always_on_top()
			get_viewport().set_input_as_handled()


# --- 定位 ---------------------------------------------------------------

func _resolve_usable_rect() -> void:
	# PLAN D2:用工作区矩形(已排除任务栏)。失败兜底到主屏整屏底部估算(PLAN step7/R3)。
	var screen := DisplayServer.window_get_current_screen()
	var ur := DisplayServer.screen_get_usable_rect(screen)
	if ur.size.x <= 0 or ur.size.y <= 0:
		var ss := DisplayServer.screen_get_size(0)
		var sp := DisplayServer.screen_get_position(0)
		ur = Rect2i(sp, ss)
	_usable_rect = ur


func _expanded_rect() -> Rect2i:
	var w := _usable_rect.size.x
	var pos := Vector2i(_usable_rect.position.x, _usable_rect.end.y - EXPANDED_HEIGHT)
	return Rect2i(pos, Vector2i(w, EXPANDED_HEIGHT))


func _collapsed_rect() -> Rect2i:
	var pos := _usable_rect.end - COLLAPSED_SIZE
	return Rect2i(pos, COLLAPSED_SIZE)


# --- 布局 ---------------------------------------------------------------

func _layout_main_area(win_w: float) -> void:
	# 主区恒 800×250 居中(PLAN D7);窄屏 <800 等比缩放并保持居中(PLAN R5/step3)。
	var area_scale := minf(1.0, win_w / MAIN_WIDTH) if win_w > 0.0 else 1.0
	main_area.scale = Vector2(area_scale, area_scale)
	var scaled_w := MAIN_WIDTH * area_scale
	main_area.position = Vector2((win_w - scaled_w) * 0.5, 0.0)


# --- 收起/展开状态机 -----------------------------------------------------

func _on_toggle_pressed() -> void:
	_toggle_collapse()


func _toggle_collapse() -> void:
	if _state == State.EXPANDED:
		_set_state(State.COLLAPSED)
	else:
		_set_state(State.EXPANDED)


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return
	_state = new_state
	_resolve_usable_rect()
	if _geom_tween and _geom_tween.is_valid():
		_geom_tween.kill()
	# 纯 alpha 交叉淡变期间保持高帧率(alpha 缓动很平滑);收起后的降帧放到序列末尾。
	Engine.max_fps = fps_expanded
	var target := _collapsed_rect() if _state == State.COLLAPSED else _expanded_rect()
	# 交叉淡变:① 当前内容淡到全透明 → ② 此刻窗口已不可见,直接跳变几何(规避 Windows 改窗几何抖动,
	# PLAN R1 退路) → ③ 切换该显示的节点(展开内容 / 收起 handle) → ④ 再淡回。
	_geom_tween = create_tween()
	_geom_tween.tween_property(self, "modulate:a", 0.0, content_fade_duration)
	_geom_tween.tween_callback(_snap_window.bind(target))
	_geom_tween.tween_callback(_refresh_visibility)
	_geom_tween.tween_property(self, "modulate:a", 1.0, content_fade_duration)
	if _state == State.COLLAPSED:
		_geom_tween.tween_callback(_apply_idle_fps)


func _snap_window(target: Rect2i) -> void:
	DisplayServer.window_set_size(target.size)
	DisplayServer.window_set_position(target.position)
	_layout_main_area(float(target.size.x))


func _apply_idle_fps() -> void:
	Engine.max_fps = fps_collapsed


func _refresh_visibility() -> void:
	var expanded := _state == State.EXPANDED
	bg_strip.visible = expanded
	main_area.visible = expanded
	collapse_btn.visible = expanded
	handle.visible = not expanded


# --- 置顶 ---------------------------------------------------------------

func _toggle_always_on_top() -> void:
	_always_on_top = not _always_on_top
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, _always_on_top)
