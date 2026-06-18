extends Control
class_name CombatView
## MainArea 内的战斗视图(PLAN D9 / step 8):订阅 Combat(autoload)信号 + 每帧读当前态渲染。
## 纯读出、不补演 —— 收起时隐藏、模拟照跑;展开直接画当前态(FEATURE-DESIGN §3)。
## 符号/轻演出版:敌人用占位 primitive,伤害飘字 + 战斗日志 + 进度读出 + 推进/修整按钮 + 掉落分级 FX。
## 正式敌人符号 / 蓝光柱 / 金光 FX / 音效 = Art Spec → Image Prompt 下游补(PLAN §5 Flag)。

## 本局可玩关卡;在场景里把 stage_01 / stage_02 的 .tres 拖进来(数据走 Resource,不硬编码路径)。
@export var stages: Array[StageConfig] = []

const LOG_LINES := 4
const RARITY_COLOR := {
	&"white": Color(0.85, 0.85, 0.85),
	&"blue": Color(0.4, 0.6, 1.0),
	&"gold": Color(1.0, 0.82, 0.25),
}
const PARTY_HP_BAR_W := 100.0
const PARTY_ALIVE_COLOR := Color(0.35, 0.8, 0.4)
const PARTY_DEAD_COLOR := Color(0.45, 0.45, 0.45)

# 敌人贴图布局:全部敌人脚底落同一地平线、按显示高缩放(ASSET-SPEC §1:屏上 ~70–125px)。
# 原生尺寸 128/160/176 × ENEMY_SPRITE_SCALE → ~91/114/125,保留"Boss/食人魔更大"的体型差。
const ENEMY_GROUND_Y := 180.0
const ENEMY_CENTER_X := 635.0
const ENEMY_SPRITE_SCALE := 0.71
const ENEMY_DISPLAY_MIN_H := 70.0
const ENEMY_DISPLAY_MAX_H := 125.0
# 掉落 FX 贴图:固定视觉常量,按 EI 接线契约由代码引用(INTEGRATION-STEPS F1 P2-d)。
# fx_light_pillar 为纯白底实顶渐隐,运行时 modulate 染稀有度色;sparkle 叠在光柱根部。
const FX_LIGHT_PILLAR := preload("res://assets/sprites/fx/fx_light_pillar.png")
const FX_LOOT_SPARKLE := preload("res://assets/sprites/fx/fx_loot_sparkle.png")

var _combat: Node = null
var _log: Array[String] = []
var _last_enemy_hp := 0.0
# 小队状态栏:每格一行(名字 + 血条 + 数值),v1 只填第 0 格,结构支持 4 格。
var _party_name: Array[Label] = []
var _party_hp_bg: Array[ColorRect] = []
var _party_hp_bar: Array[ColorRect] = []
var _party_hp_text: Array[Label] = []

@onready var _progress_label := Label.new()
@onready var _log_label := Label.new()
@onready var _enemy_sprite := TextureRect.new()
@onready var _enemy_panel := ColorRect.new()  # 贴图缺失时的回退占位(EnemyDef.sprite 为空)
@onready var _enemy_name := Label.new()
@onready var _enemy_hp_bar_bg := ColorRect.new()
@onready var _enemy_hp_bar := ColorRect.new()
@onready var _countdown_label := Label.new()
@onready var _push_btn := Button.new()
@onready var _rest_btn := Button.new()
@onready var _flash := ColorRect.new()
@onready var _fx_layer := Control.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_combat = get_node_or_null("/root/Combat")
	if _combat == null:
		_progress_label.text = "(无 Combat 单例)"
		return
	_combat.enemy_defeated.connect(_on_enemy_defeated)
	_combat.party_wiped.connect(_on_party_wiped)
	_combat.boss_cleared.connect(_on_boss_cleared)
	_combat.loot_dropped.connect(_on_loot_dropped)
	_combat.rest_requested.connect(_on_rest_requested)
	_push_btn.pressed.connect(func(): _combat.request_push())
	_rest_btn.pressed.connect(func(): _combat.request_rest())
	if not stages.is_empty():
		_combat.begin_run(stages)
	_push_log("⚔ 战斗开始")


func _process(_delta: float) -> void:
	if _combat == null or not visible:
		return
	_update_enemy()
	_update_party()
	_update_progress_and_buttons()


# --- 渲染 ---------------------------------------------------------------

func _update_enemy() -> void:
	var alive: bool = _combat.has_living_enemy()
	_enemy_name.visible = alive
	_enemy_hp_bar_bg.visible = alive
	_enemy_hp_bar.visible = alive
	if not alive:
		_enemy_sprite.visible = false
		_enemy_panel.visible = false
		_last_enemy_hp = 0.0
		return
	var def: EnemyDef = _combat.current_enemy_def()
	var tex: Texture2D = def.sprite if def != null else null
	# 有贴图 → 显示正式敌人(脚底落地平线、按显示高缩放);无贴图 → 回退到占位色块。
	_enemy_sprite.visible = tex != null
	_enemy_panel.visible = tex == null
	if tex != null and _enemy_sprite.texture != tex:
		_layout_enemy_sprite(tex)
	var hp: float = _combat.enemy_hp()
	var maxhp: float = def.max_hp if def != null else maxf(hp, 1.0)
	if def != null:
		_enemy_name.text = def.display_name
	# 伤害飘字:从敌人血量逐帧下降推出(视图读出,不需新信号)。
	if _last_enemy_hp > 0.0 and hp < _last_enemy_hp:
		_spawn_damage_float(_last_enemy_hp - hp)
	_last_enemy_hp = hp
	var frac := clampf(hp / maxhp, 0.0, 1.0) if maxhp > 0.0 else 0.0
	_enemy_hp_bar.size = Vector2(120.0 * frac, 8.0)


## 按贴图原生比例缩放到目标显示高,并把脚底对齐地平线、水平居中于敌人锚点。
func _layout_enemy_sprite(tex: Texture2D) -> void:
	var native_w := float(tex.get_width())
	var native_h := float(tex.get_height())
	var disp_h := clampf(native_h * ENEMY_SPRITE_SCALE, ENEMY_DISPLAY_MIN_H, ENEMY_DISPLAY_MAX_H)
	var disp_w := disp_h * (native_w / native_h) if native_h > 0.0 else disp_h
	_enemy_sprite.texture = tex
	_enemy_sprite.size = Vector2(disp_w, disp_h)
	_enemy_sprite.position = Vector2(ENEMY_CENTER_X - disp_w * 0.5, ENEMY_GROUND_Y - disp_h)


func _update_party() -> void:
	var members: Array = _combat.party
	for i in _party_name.size():
		var m = members[i] if i < members.size() else null
		var present: bool = m != null
		_party_name[i].visible = present
		_party_hp_bg[i].visible = present
		_party_hp_bar[i].visible = present
		_party_hp_text[i].visible = present
		if not present:
			continue
		var maxhp: float = m.max_hp
		var hp: float = m.current_hp
		var frac := clampf(hp / maxhp, 0.0, 1.0) if maxhp > 0.0 else 0.0
		_party_name[i].text = m.display_name
		_party_hp_bar[i].size.x = PARTY_HP_BAR_W * frac
		_party_hp_bar[i].color = PARTY_ALIVE_COLOR if m.is_alive() else PARTY_DEAD_COLOR
		_party_hp_text[i].text = "%d/%d" % [int(ceil(hp)), int(maxhp)]


func _update_progress_and_buttons() -> void:
	_progress_label.text = _progress_text()
	var mode: int = _combat.mode
	var Mode := CombatDirector.Mode
	var grinding := mode == Mode.GRINDING
	var countdown := mode == Mode.STAGE_CLEAR_COUNTDOWN
	_push_btn.visible = grinding
	_rest_btn.visible = grinding or countdown
	_countdown_label.visible = countdown
	if countdown:
		_countdown_label.text = "通关!%.1fs 后推进" % maxf(0.0, _combat.countdown_remaining)


func _progress_text() -> String:
	var s: int = _combat.cur_stage
	var sc: int = _combat.cur_scene
	var stage_no := s + 1
	match _combat.mode:
		CombatDirector.Mode.RESTING:
			return "修整中(占位 · 城镇 = 04)"
		CombatDirector.Mode.STAGE_CLEAR_COUNTDOWN:
			return "第 %d 关 · 通关" % stage_no
		CombatDirector.Mode.GRINDING:
			var where := "Boss" if sc == CombatDirector.BOSS_SCENE else "场景 %d/3" % (sc + 1)
			return "第 %d 关 · %s · 卡关刷怪" % [stage_no, where]
		_:
			if sc == CombatDirector.BOSS_SCENE:
				return "第 %d 关 · Boss" % stage_no
			return "第 %d 关 · 场景 %d/3" % [stage_no, sc + 1]


# --- 信号回调 -----------------------------------------------------------

func _on_enemy_defeated(enemy: EnemyDef) -> void:
	var nm := enemy.display_name if enemy != null else "敌人"
	_push_log("⚔ 击败 %s" % nm)


func _on_party_wiped() -> void:
	_push_log("💀 团灭 · 回退刷怪")


func _on_boss_cleared(stage: int) -> void:
	_push_log("👑 通关第 %d 关!" % (stage + 1))


func _on_rest_requested() -> void:
	_push_log("🏕 修整(占位)")


func _on_loot_dropped(kind: StringName, rarity: StringName) -> void:
	_push_log("💎 掉落 %s(%s)" % [_kind_text(kind), _rarity_text(rarity)])
	match rarity:
		&"blue":
			_spawn_pillar(RARITY_COLOR[&"blue"])
		&"gold":
			_spawn_pillar(RARITY_COLOR[&"gold"])
			_gold_flash()
		# 白:默默,无额外 FX(守支柱 1/3,PLAN D9)。


# --- FX(占位)----------------------------------------------------------

func _spawn_damage_float(amount: float) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % int(round(amount))
	lbl.position = Vector2(ENEMY_CENTER_X + randf_range(-20, 12), ENEMY_GROUND_Y - 110.0)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_fx_layer.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 36.0, 0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(lbl.queue_free)


func _spawn_pillar(color: Color) -> void:
	# 蓝/金掉落:fx_light_pillar 正式贴图(白底实顶渐隐)在敌人脚底升起,modulate 染稀有度色后淡出。
	var pillar_h := 150.0
	var pillar_w := pillar_h * float(FX_LIGHT_PILLAR.get_width()) / float(FX_LIGHT_PILLAR.get_height())
	var pillar := TextureRect.new()
	pillar.texture = FX_LIGHT_PILLAR
	pillar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pillar.modulate = color
	pillar.size = Vector2(pillar_w, pillar_h)
	pillar.position = Vector2(ENEMY_CENTER_X - pillar_w * 0.5, ENEMY_GROUND_Y - pillar_h)
	pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(pillar)
	var tw := create_tween()
	tw.tween_property(pillar, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pillar.queue_free)
	_spawn_sparkle(color)


func _spawn_sparkle(color: Color) -> void:
	# fx_loot_sparkle 叠在光柱根部(脚底)做一下放射(INTEGRATION-STEPS F1 P2-d 可选)。
	var s := 48.0
	var spark := TextureRect.new()
	spark.texture = FX_LOOT_SPARKLE
	spark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spark.modulate = color
	spark.size = Vector2(s, s)
	spark.position = Vector2(ENEMY_CENTER_X - s * 0.5, ENEMY_GROUND_Y - s * 0.5)
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(spark)
	var tw := create_tween()
	tw.tween_property(spark, "modulate:a", 0.0, 0.45)
	tw.tween_callback(spark.queue_free)


func _gold_flash() -> void:
	# 金装掉落:窗口内一闪(限窗口内、不弹 OS 通知、不抢焦点,PLAN D9)。
	# 极短停顿 + 音效 = 占位待补(无音频素材;hitstop 留 playtest,PLAN §5 Flag)。
	_flash.modulate.a = 0.0
	_flash.visible = true
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.5, 0.06)
	tw.tween_property(_flash, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func(): _flash.visible = false)


# --- 日志 ---------------------------------------------------------------

func _push_log(line: String) -> void:
	_log.append(line)
	while _log.size() > LOG_LINES:
		_log.pop_front()
	_log_label.text = "\n".join(_log)


func _kind_text(kind: StringName) -> String:
	match kind:
		&"gold": return "金币"
		&"material": return "材料"
		&"equipment": return "装备"
		_: return String(kind)


func _rarity_text(rarity: StringName) -> String:
	match rarity:
		&"white": return "白"
		&"blue": return "蓝"
		&"gold": return "金"
		_: return String(rarity)


# --- UI 构建(代码建子节点,减少 .tscn 改动)-----------------------------

## 左上小队状态栏:每格一行 名字 + 血条底 + 血条 + 数值;空格隐藏(_update_party 控制)。
func _build_party_bars() -> void:
	var slots: int = CombatDirector.PARTY_SLOTS
	for i in slots:
		var row_y := 42.0 + i * 24.0
		var nm := Label.new()
		nm.position = Vector2(16, row_y - 4)
		nm.add_theme_font_size_override("font_size", 12)
		nm.visible = false
		add_child(nm)
		_party_name.append(nm)

		var bg := ColorRect.new()
		bg.color = Color(0.15, 0.15, 0.15)
		bg.size = Vector2(PARTY_HP_BAR_W, 10)
		bg.position = Vector2(86, row_y)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.visible = false
		add_child(bg)
		_party_hp_bg.append(bg)

		var bar := ColorRect.new()
		bar.color = PARTY_ALIVE_COLOR
		bar.size = Vector2(PARTY_HP_BAR_W, 10)
		bar.position = Vector2(86, row_y)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		add_child(bar)
		_party_hp_bar.append(bar)

		var txt := Label.new()
		txt.position = Vector2(192, row_y - 4)
		txt.add_theme_font_size_override("font_size", 11)
		txt.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		txt.visible = false
		add_child(txt)
		_party_hp_text.append(txt)


func _build_ui() -> void:
	_progress_label.position = Vector2(16, 12)
	_progress_label.add_theme_font_size_override("font_size", 18)
	add_child(_progress_label)

	_build_party_bars()

	_log_label.position = Vector2(16, 150)
	_log_label.add_theme_font_size_override("font_size", 13)
	_log_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	add_child(_log_label)

	# 敌人正式贴图(脚底落地平线、按显示高缩放;布局在 _layout_enemy_sprite 里随贴图设定)。
	_enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_enemy_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_sprite.visible = false
	add_child(_enemy_sprite)

	# 敌人回退占位:EnemyDef.sprite 为空时显示的色块 + 名字 + 血条(贴图接好后不再出现)。
	_enemy_panel.color = Color(0.7, 0.3, 0.3)
	_enemy_panel.size = Vector2(70, 90)
	_enemy_panel.position = Vector2(600, 90)
	_enemy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_enemy_panel)

	_enemy_name.position = Vector2(596, 64)
	_enemy_name.add_theme_font_size_override("font_size", 14)
	add_child(_enemy_name)

	_enemy_hp_bar_bg.color = Color(0.15, 0.15, 0.15)
	_enemy_hp_bar_bg.size = Vector2(120, 8)
	_enemy_hp_bar_bg.position = Vector2(575, 186)
	_enemy_hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_enemy_hp_bar_bg)

	_enemy_hp_bar.color = Color(0.8, 0.25, 0.25)
	_enemy_hp_bar.size = Vector2(120, 8)
	_enemy_hp_bar.position = Vector2(575, 186)
	_enemy_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_enemy_hp_bar)

	_countdown_label.position = Vector2(330, 110)
	_countdown_label.add_theme_font_size_override("font_size", 16)
	_countdown_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	add_child(_countdown_label)

	_push_btn.text = "推进"
	_push_btn.position = Vector2(660, 12)
	_push_btn.visible = false
	add_child(_push_btn)

	_rest_btn.text = "修整"
	_rest_btn.position = Vector2(720, 12)
	_rest_btn.visible = false
	add_child(_rest_btn)

	# 金装一闪覆盖层(铺满主区)。
	_flash.color = Color(1.0, 0.9, 0.4)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	add_child(_flash)

	# FX 飘字/光柱挂载层(最上)。
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)
