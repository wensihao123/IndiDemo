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
# 〔08 团战〕一波多敌占位渲染:N==1 维持单敌大图;N>1 横排缩小,前排(lane 小)靠左(近战士)。
# 防呆:本值 = 同屏可渲染敌数上限,与 BALANCE WAVE_SIZE 上限(关1=4)耦合。num-smith 复算关2 若 WAVE_SIZE>4,
# 须同步抬本值,否则 _update_enemy 静默截断尾部敌人(解算照打 → 玩家被看不见的敌人扣血,REVIEW §3)。
const MAX_WAVE_SLOTS := 4
const WAVE_SLOT_STEP := 72.0      # 多敌时相邻槽中心间距
const WAVE_SLOT_HP_W := 56.0      # 多敌时单只血条宽
const WAVE_SLOT_MAX_H := 78.0     # 多敌时贴图显示高上限
const WAVE_SLOT_MIN_H := 50.0
const SLOT_MELEE_COLOR := Color(0.8, 0.25, 0.25)
const SLOT_RANGED_COLOR := Color(0.4, 0.55, 0.85)  # 远程占位偏蓝,一眼区分近/远
const SLOT_DEAD_COLOR := Color(0.45, 0.45, 0.45)
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
# 〔08 团战〕一波多敌渲染槽池;slot 0 复用下面单敌节点,1..MAX_WAVE_SLOTS-1 为追加槽,按 arena.enemies 逐只画。
var _slot_sprite: Array[TextureRect] = []
var _slot_panel: Array[ColorRect] = []
var _slot_hp_bg: Array[ColorRect] = []
var _slot_hp_bar: Array[ColorRect] = []

@onready var _progress_label := Label.new()
@onready var _log_label := Label.new()
@onready var _enemy_sprite := TextureRect.new()
@onready var _enemy_panel := ColorRect.new()  # 贴图缺失时的回退占位(EnemyDef.sprite 为空)
@onready var _enemy_name := Label.new()
@onready var _enemy_hp_bar_bg := ColorRect.new()
@onready var _enemy_hp_bar := ColorRect.new()
@onready var _countdown_label := Label.new()
@onready var _enrage_label := Label.new()  # 敌人软狂暴横幅(克制:窗内一行,读 enraged 态)
@onready var _retreat_invite_label := Label.new()  # 〔06〕卡关时克制的"回城变强"邀请(只读 GRINDING 态,不弹窗、可无视)
@onready var _push_btn := Button.new()
@onready var _flash := ColorRect.new()
@onready var _fx_layer := Control.new()
# 只读查阅面板(掉落包 + 当前装备双栏);默认隐藏,按钮切显隐,事件驱动刷新(不每帧)。
@onready var _panel := Panel.new()
@onready var _panel_btn := Button.new()
var _bag_col: VBoxContainer = null
var _equip_col: VBoxContainer = null
var _panel_visible := false


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
	_push_btn.pressed.connect(func(): _prog.request_push())
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
	# 〔08 团战〕按 arena.enemies 逐只渲染整波(前排死也留场=灰显,呈现车轮/隔位);名字取集火最前存活。
	var ents: Array = _arena.enemies
	var n: int = ents.size()
	var front: Entity = _living_enemy()
	_enemy_name.visible = front != null
	if front == null:
		for i in MAX_WAVE_SLOTS:
			_hide_slot(i)
		return
	_enemy_name.text = front.source_enemy_def.display_name if front.source_enemy_def != null else "敌人"
	for i in MAX_WAVE_SLOTS:
		var ent: Entity = ents[i] if i < n else null
		if ent != null:
			_render_slot(i, ent, n)
		else:
			_hide_slot(i)


## 渲染第 i 个敌槽:按贴图原生比例缩放到地平线;N==1 居中大图、N>1 横排缩小;死者灰显;远程偏蓝。
func _render_slot(i: int, ent: Entity, n: int) -> void:
	var def: EnemyDef = ent.source_enemy_def
	var tex: Texture2D = def.sprite if def != null else null
	var dead: bool = not ent.is_alive()
	var ranged: bool = ent.position_class == EnemyDef.PositionClass.RANGED
	var single: bool = n <= 1
	# 槽位中心 x:单敌居中;多敌横排,以 ENEMY_CENTER_X 为簇心、前排(i 小)靠左。
	var cx: float = ENEMY_CENTER_X
	if not single:
		cx = ENEMY_CENTER_X - float(n - 1) * WAVE_SLOT_STEP * 0.5 + float(i) * WAVE_SLOT_STEP
	var sprite: TextureRect = _slot_sprite[i]
	var panel: ColorRect = _slot_panel[i]
	if tex != null:
		var native_w := float(tex.get_width())
		var native_h := float(tex.get_height())
		var cap_h: float = ENEMY_DISPLAY_MAX_H if single else WAVE_SLOT_MAX_H
		var min_h: float = ENEMY_DISPLAY_MIN_H if single else WAVE_SLOT_MIN_H
		var disp_h := clampf(native_h * ENEMY_SPRITE_SCALE, min_h, cap_h)
		var disp_w := disp_h * (native_w / native_h) if native_h > 0.0 else disp_h
		sprite.texture = tex
		sprite.size = Vector2(disp_w, disp_h)
		sprite.position = Vector2(cx - disp_w * 0.5, ENEMY_GROUND_Y - disp_h)
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.55) if dead else Color.WHITE
		sprite.visible = true
		panel.visible = false
	else:
		var pw: float = 70.0 if single else 44.0
		var ph: float = 90.0 if single else 64.0
		var base := SLOT_RANGED_COLOR if ranged else SLOT_MELEE_COLOR
		panel.color = base.darkened(0.5) if dead else base
		panel.size = Vector2(pw, ph)
		panel.position = Vector2(cx - pw * 0.5, ENEMY_GROUND_Y - ph)
		panel.visible = true
		sprite.visible = false
	var hp_w: float = 120.0 if single else WAVE_SLOT_HP_W
	var bx := cx - hp_w * 0.5
	var by := ENEMY_GROUND_Y + 6.0
	var bg: ColorRect = _slot_hp_bg[i]
	var bar: ColorRect = _slot_hp_bar[i]
	bg.size = Vector2(hp_w, 8.0)
	bg.position = Vector2(bx, by)
	bg.visible = true
	var maxhp := ent.max_hp()
	var frac := clampf(ent.current_hp / maxhp, 0.0, 1.0) if maxhp > 0.0 else 0.0
	bar.size = Vector2(hp_w * frac, 8.0)
	bar.position = Vector2(bx, by)
	bar.color = SLOT_DEAD_COLOR if dead else (SLOT_RANGED_COLOR if ranged else SLOT_MELEE_COLOR)
	bar.visible = true


func _hide_slot(i: int) -> void:
	_slot_sprite[i].visible = false
	_slot_panel[i].visible = false
	_slot_hp_bg[i].visible = false
	_slot_hp_bar[i].visible = false


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
	_retreat_invite_label.visible = grinding  # 〔06〕卡关时才邀请回城,平时隐藏(不打断陪伴)
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
		ProgressionController.Mode.STAGE_CLEAR_COUNTDOWN:
			return "第 %d 关 · 通关" % stage_no
		ProgressionController.Mode.GRINDING:
			var where := "Boss" if sc == ProgressionController.BOSS_SCENE else "场景 %d/3" % (sc + 1)
			# 〔06〕卡关可读:一眼看懂"卡在哪一档墙、不是 bug",余光可读(回城邀请见 _retreat_invite_label)。
			return "⛰ 第 %d 关 · %s · 卡住了 · 安全刷怪中" % [stage_no, where]
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
	# 〔06〕突破庆祝:打通"末关"(v1 内容终点)比普通过关更重 = 里程碑级占位庆祝(全屏更亮更久的闪);
	# 普通关维持原"👑 通关"。末关之后进终点循环重刷 Boss(决策 B),故本回调会重复触发,占位接受重复("再次通关")。
	var is_last := _prog != null and stage >= _prog.stages.size() - 1
	if is_last:
		_push_log("🏆 打通 v1 全部内容!终点关 · 循环挑战 Boss")
		_milestone_flash()
	else:
		_push_log("👑 通关第 %d 关!" % (stage + 1))


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
	# 面板开着时事件驱动刷新:自动填空把掉落穿上 → 右栏属性行实时跳变(兑现"看见变强")。
	if _panel_visible:
		_refresh_panel()
		if dest == LootIntake.EQUIPPED:
			_flash_equip_col()


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


func _milestone_flash() -> void:
	# 〔06〕v1 终点里程碑庆祝:比普通金装一闪更重(更亮、更久)的占位全屏闪。
	# 用独立 overlay(不复用 _flash,免与金装闪共享色态);正式特效/音留全局 UI·juice 统一轮。
	var m := ColorRect.new()
	m.color = Color(1.0, 0.95, 0.6)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.modulate.a = 0.0
	_fx_layer.add_child(m)
	var tw := create_tween()
	tw.tween_property(m, "modulate:a", 0.85, 0.12)
	tw.tween_property(m, "modulate:a", 0.0, 0.7)
	tw.tween_callback(m.queue_free)


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

	# 〔08 团战〕slot 0 = 上面单敌节点;再追加 MAX_WAVE_SLOTS-1 套(贴图/占位块/血条),供多敌波横排渲染。
	_slot_sprite = [_enemy_sprite]
	_slot_panel = [_enemy_panel]
	_slot_hp_bg = [_enemy_hp_bar_bg]
	_slot_hp_bar = [_enemy_hp_bar]
	for _i in range(1, MAX_WAVE_SLOTS):
		var sp := TextureRect.new()
		sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sp.stretch_mode = TextureRect.STRETCH_SCALE
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp.visible = false
		add_child(sp)
		_slot_sprite.append(sp)
		var pn := ColorRect.new()
		pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pn.visible = false
		add_child(pn)
		_slot_panel.append(pn)
		var bg := ColorRect.new()
		bg.color = Color(0.15, 0.15, 0.15)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.visible = false
		add_child(bg)
		_slot_hp_bg.append(bg)
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		add_child(bar)
		_slot_hp_bar.append(bar)

	_countdown_label.position = Vector2(330, 110)
	_countdown_label.add_theme_font_size_override("font_size", 16)
	_countdown_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	add_child(_countdown_label)

	# 〔06〕卡关回城邀请:进度读出下方一行克制提示,仅 GRINDING 态显(_update_progress_and_buttons 控),不弹窗、可无视。
	_retreat_invite_label.text = "打不过?回城强化 / 换装,变强后点「推进」再冲一次"
	_retreat_invite_label.position = Vector2(16, 36)
	_retreat_invite_label.add_theme_font_size_override("font_size", 12)
	_retreat_invite_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	_retreat_invite_label.visible = false
	add_child(_retreat_invite_label)

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

	_build_panel()


## 只读查阅面板:全区模态遮罩 + 左栏掉落包 / 右栏当前装备&8 维属性;切换按钮叠在最上保持可点。
func _build_panel() -> void:
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP   # 开启时吃掉点击,不漏到战斗层
	add_child(_panel)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.09, 0.93)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(bg)

	var bag_head := Label.new()
	bag_head.text = "— 掉落包 —"
	bag_head.position = Vector2(20, 10)
	bag_head.add_theme_font_size_override("font_size", 14)
	_panel.add_child(bag_head)

	var equip_head := Label.new()
	equip_head.text = "— 当前装备 —"
	equip_head.position = Vector2(430, 10)
	equip_head.add_theme_font_size_override("font_size", 14)
	_panel.add_child(equip_head)

	# 掉落包可能堆很多件 → 套 ScrollContainer 才能滚到底(占位面板,精修留 UI·juice 轮)。
	var bag_scroll := ScrollContainer.new()
	bag_scroll.position = Vector2(20, 34)
	bag_scroll.size = Vector2(400, 206)
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(bag_scroll)

	_bag_col = VBoxContainer.new()
	_bag_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_col.add_theme_constant_override("separation", 1)
	bag_scroll.add_child(_bag_col)

	_equip_col = VBoxContainer.new()
	_equip_col.position = Vector2(430, 34)
	_equip_col.add_theme_constant_override("separation", 1)
	_panel.add_child(_equip_col)

	# 切换按钮 add 在 _panel 之后 → 永远叠在遮罩之上 → 开着也能点关。
	_panel_btn.text = "背包/装备"
	_panel_btn.position = Vector2(360, 12)
	_panel_btn.pressed.connect(_toggle_panel)
	add_child(_panel_btn)


func _toggle_panel() -> void:
	_panel_visible = not _panel_visible
	_panel.visible = _panel_visible
	if _panel_visible:
		_refresh_panel()


## 事件驱动重建两栏(打开时 + 可见时收到掉落);不进 _process,精确对上"掉落→填空→跳变"时机。
func _refresh_panel() -> void:
	if _gc == null or _bag_col == null or _equip_col == null:
		return
	_rebuild_bag_col()
	_rebuild_equip_col()


func _rebuild_bag_col() -> void:
	for c in _bag_col.get_children():
		c.queue_free()
	var bag: Array = _gc.player_state.bag if _gc.player_state != null else []
	if bag.is_empty():
		_bag_col.add_child(_make_label("(空)", 12, Color(0.55, 0.55, 0.6)))
		return
	for inst in bag:
		var col: Color = RARITY_COLOR.get(inst.rarity, Color(0.85, 0.85, 0.85))
		_bag_col.add_child(_make_label(
			"%s · ilvl%d · %s" % [_slot_text(inst.base_id), inst.ilvl, _rarity_text(inst.rarity)], 13, col))
		for roll in inst.affixes:
			_bag_col.add_child(_make_label(
				"    %s %s" % [_stat_name(roll.stat), _format_stat_value(roll.stat, roll.value)],
				11, Color(0.72, 0.78, 0.85)))


func _rebuild_equip_col() -> void:
	for c in _equip_col.get_children():
		c.queue_free()
	var ent := _panel_entity()         # R3:begin_run 前无活体 → 守空,不空引用。
	if ent == null:
		_equip_col.add_child(_make_label("(未进入战斗)", 12, Color(0.55, 0.55, 0.6)))
		return
	for slot in GameKeys.SLOTS:
		var inst: ItemInstance = ent.equipment.get_equipped(slot) if ent.equipment != null else null
		var desc := "—"
		if inst != null:
			desc = "ilvl%d %s" % [inst.ilvl, _rarity_text(inst.rarity)]
		_equip_col.add_child(_make_label("%s: %s" % [_slot_text(slot), desc], 12, Color(0.85, 0.88, 0.92)))
	_equip_col.add_child(_make_label("", 6, Color.WHITE))   # 槽位/属性间隔
	if ent.stats != null:                                  # 与 equipment 守卫对称:半装配 Entity 不空引用。
		for stat in GameKeys.STATS:
			_equip_col.add_child(_make_label(
				"%s  %s" % [_stat_name(stat), _format_stat_value(stat, ent.stats.get_final(stat))],
				12, Color(0.8, 0.85, 0.9)))


# 第一个非空队员的活体 Entity(读它的 EquipmentComponent/StatsComponent 才能反映运行时自动填空)。
func _panel_entity() -> Entity:
	if _arena == null:
		return null
	for e in _arena.players:
		if e != null:
			return e
	return null


## 自动填空穿上掉落 → 右栏闪一下绿(纯表现,"变强显形");复用 tween 风格。
func _flash_equip_col() -> void:
	var g := ColorRect.new()
	g.color = Color(0.3, 1.0, 0.4, 0.0)
	g.position = Vector2(420, 6)
	g.size = Vector2(360, 238)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(g)
	var tw := create_tween()
	tw.tween_property(g, "color:a", 0.35, 0.08)
	tw.tween_property(g, "color:a", 0.0, 0.35)
	tw.tween_callback(g.queue_free)


func _make_label(text: String, size: int, color: Color) -> Label:
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


## D6:按维度语义格式化(百分比/倍率/每秒/整数),裸浮点不可读。
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
