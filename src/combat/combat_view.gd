extends Control
class_name CombatView
## MainArea 内的战斗视图(REFACTOR-01 层6):订阅 Game(autoload)的 arena+progression 信号 + 每帧读态渲染。
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

var _gc: Node = null              # /root/Game(GameController)
var _arena: CombatArena = null    # _gc.arena(单局战斗)
var _prog: ProgressionController = null  # _gc.progression(跨场推进)
var _log: Array[String] = []
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
@onready var _enrage_label := Label.new()  # 敌人软狂暴横幅(克制:窗内一行,读 enraged 态)
@onready var _push_btn := Button.new()
@onready var _rest_btn := Button.new()
@onready var _flash := ColorRect.new()
@onready var _fx_layer := Control.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_gc = get_node_or_null("/root/Game")
	if _gc == null:
		_progress_label.text = "(无 Game 单例)"
		return
	_arena = _gc.arena
	_prog = _gc.progression
	_arena.enemy_defeated.connect(_on_enemy_defeated)
	_arena.party_wiped.connect(_on_party_wiped)
	_arena.hit_dealt.connect(_on_hit_dealt)
	_arena.player_dodged.connect(_on_player_dodged)
	_arena.enemy_enraged.connect(_on_enemy_enraged)
	_arena.item_dropped.connect(_on_item_dropped)
	_prog.boss_cleared.connect(_on_boss_cleared)
	_prog.rest_requested.connect(_on_rest_requested)
	_push_btn.pressed.connect(func(): _prog.request_push())
	_rest_btn.pressed.connect(func(): _prog.request_rest())
	if not stages.is_empty():
		_gc.begin_run(stages)
	_push_log("⚔ 战斗开始")


func _process(_delta: float) -> void:
	if _gc == null or not visible:
		return
	_update_enemy()
	_update_party()
	_update_progress_and_buttons()


# --- 渲染 ---------------------------------------------------------------

func _update_enemy() -> void:
	var living: Entity = _living_enemy()
	var alive: bool = living != null
	_enemy_name.visible = alive
	_enemy_hp_bar_bg.visible = alive
	_enemy_hp_bar.visible = alive
	if not alive:
		_enemy_sprite.visible = false
		_enemy_panel.visible = false
		return
	var def: EnemyDef = _prog.current_enemy_def()
	var tex: Texture2D = def.sprite if def != null else null
	# 有贴图 → 显示正式敌人(脚底落地平线、按显示高缩放);无贴图 → 回退到占位色块。
	_enemy_sprite.visible = tex != null
	_enemy_panel.visible = tex == null
	if tex != null and _enemy_sprite.texture != tex:
		_layout_enemy_sprite(tex)
	var hp: float = living.current_hp
	var maxhp: float = living.max_hp()
	if def != null:
		_enemy_name.text = def.display_name
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


# 第一个存活敌实体(血量从战斗壳读,名字/贴图仍走 def）。
func _living_enemy() -> Entity:
	for e in _arena.enemies:
		if e != null and e.is_alive():
			return e
	return null


func _update_party() -> void:
	# 名字取持久 Character(party_characters),血/存活取 per-run Entity(arena.players),两者同序。
	var ents: Array = _arena.players
	var chars: Array = _gc.party_characters
	for i in _party_name.size():
		var e: Entity = ents[i] if i < ents.size() else null
		var present: bool = e != null
		_party_name[i].visible = present
		_party_hp_bg[i].visible = present
		_party_hp_bar[i].visible = present
		_party_hp_text[i].visible = present
		if not present:
			continue
		var maxhp: float = e.max_hp()
		var hp: float = e.current_hp
		var frac := clampf(hp / maxhp, 0.0, 1.0) if maxhp > 0.0 else 0.0
		var c: Character = chars[i] if i < chars.size() else null
		_party_name[i].text = c.display_name if c != null else "战士"
		_party_hp_bar[i].size.x = PARTY_HP_BAR_W * frac
		_party_hp_bar[i].color = PARTY_ALIVE_COLOR if e.is_alive() else PARTY_DEAD_COLOR
		_party_hp_text[i].text = "%d/%d" % [int(ceil(hp)), int(maxhp)]


func _update_progress_and_buttons() -> void:
	_progress_label.text = _progress_text()
	var mode: int = _prog.mode
	var Mode := ProgressionController.Mode
	var grinding := mode == Mode.GRINDING
	var countdown := mode == Mode.STAGE_CLEAR_COUNTDOWN
	_push_btn.visible = grinding
	_rest_btn.visible = grinding or countdown
	_countdown_label.visible = countdown
	if countdown:
		_countdown_label.text = "通关!%.1fs 后推进" % maxf(0.0, _prog.countdown_remaining)
	# 软狂暴横幅:只要当前敌人处于狂暴态就常驻显示(start_battle 复位 enraged → 自动消失)。
	_enrage_label.visible = _arena.has_living_enemy() and _arena.enraged


func _progress_text() -> String:
	var s: int = _prog.cur_stage
	var sc: int = _prog.cur_scene
	var stage_no := s + 1
	match _prog.mode:
		ProgressionController.Mode.RESTING:
			return "修整中(占位 · 城镇 = 04)"
		ProgressionController.Mode.STAGE_CLEAR_COUNTDOWN:
			return "第 %d 关 · 通关" % stage_no
		ProgressionController.Mode.GRINDING:
			var where := "Boss" if sc == ProgressionController.BOSS_SCENE else "场景 %d/3" % (sc + 1)
			return "第 %d 关 · %s · 卡关刷怪" % [stage_no, where]
		_:
			if sc == ProgressionController.BOSS_SCENE:
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


func _on_hit_dealt(amount: float, is_crit: bool) -> void:
	# 每次我方出手一次,飘一次伤害字;暴击放大 + 变色(让死因/输出可读,PLAN D7/F7)。
	# 收起态(后台 tick 主态)不建飘字节点:本视图只在可见时渲染,模拟照跑(同 _process 那道闸)。
	if not visible:
		return
	_spawn_damage_float(amount, is_crit)


func _on_player_dodged(member_index: int) -> void:
	# 闪避:在被攻击成员的血条行飘 "MISS"(读出"为什么没掉血")。收起态不渲染(见 _on_hit_dealt)。
	if not visible:
		return
	_spawn_miss_float(member_index)


func _on_enemy_enraged() -> void:
	_push_log("🔥 敌人狂暴!伤害随时间攀升")


func _on_item_dropped(inst: ItemInstance, dest: StringName) -> void:
	var rarity: StringName = inst.rarity
	_push_log("💎 掉落 %s 装备 → %s" % [_rarity_text(rarity), _dest_text(dest)])
	match rarity:
		&"blue":
			_spawn_pillar(RARITY_COLOR[&"blue"])
		&"gold":
			_spawn_pillar(RARITY_COLOR[&"gold"])
			_gold_flash()
		# 白:默默,无额外 FX(守支柱 1/3,PLAN D9)。


# --- FX(占位)----------------------------------------------------------

func _spawn_damage_float(amount: float, is_crit := false) -> void:
	var lbl := Label.new()
	lbl.text = ("暴击 -%d" % int(round(amount))) if is_crit else ("-%d" % int(round(amount)))
	lbl.position = Vector2(ENEMY_CENTER_X + randf_range(-20, 12), ENEMY_GROUND_Y - 110.0)
	lbl.add_theme_color_override("font_color", Color(1, 0.45, 0.25) if is_crit else Color(1, 0.9, 0.4))
	lbl.add_theme_font_size_override("font_size", 22 if is_crit else 14)
	_fx_layer.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 36.0, 0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(lbl.queue_free)


func _spawn_miss_float(member_index: int) -> void:
	var lbl := Label.new()
	lbl.text = "MISS"
	var row_y := 42.0 + member_index * 24.0
	lbl.position = Vector2(120.0, row_y - 8.0)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	lbl.add_theme_font_size_override("font_size", 13)
	_fx_layer.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 22.0, 0.55)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.55)
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


func _dest_text(dest: StringName) -> String:
	match dest:
		LootIntake.EQUIPPED: return "装备"
		LootIntake.DECOMPOSED: return "分解"
		LootIntake.BAGGED: return "入包"
		_: return String(dest)


func _rarity_text(rarity: StringName) -> String:
	match rarity:
		&"white": return "白"
		&"blue": return "蓝"
		&"gold": return "金"
		_: return String(rarity)


# --- UI 构建(代码建子节点,减少 .tscn 改动)-----------------------------

## 左上小队状态栏:每格一行 名字 + 血条底 + 血条 + 数值;空格隐藏(_update_party 控制)。
func _build_party_bars() -> void:
	var slots: int = GameController.PARTY_SLOTS
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

	_enrage_label.text = "🔥 敌人狂暴"
	_enrage_label.position = Vector2(560, 40)
	_enrage_label.add_theme_font_size_override("font_size", 15)
	_enrage_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	_enrage_label.visible = false
	add_child(_enrage_label)

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
