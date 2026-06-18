extends Node
class_name CombatDirector
## 战斗模拟核心(PLAN D1:将注册为 Autoload,step 7 接入)。
## 本步只含单场战斗解算:队伍齐攻当前敌人、敌人反击最前存活成员、敌人死亡 / 团灭判定。
## 进度推进(场景/Boss)= step 4;掉落 = step 3;固定步长 tick 驱动 = step 7。

signal enemy_defeated(enemy: EnemyDef)
signal party_wiped
## 一次击杀的掉落事件:kind ∈ {gold, material, equipment};rarity ∈ {white, blue, gold}。
## 每次击杀最多发一次(0/1),金币种类一律记 white(PLAN D7)。物品具体内容 = step 03。
signal loot_dropped(kind: StringName, rarity: StringName)
## 关底 Boss 被击杀:已永久解锁下一关(PLAN D4)。stage = 被通的那一关序号。
signal boss_cleared(stage: int)
## 玩家点"修整"离开本轮:v1 落到 stub(真城镇 = 04,PLAN D6/Out-of-scope)。
signal rest_requested
## 一次命中已结算(PLAN D7,additive):amount = 实际扣敌血量,is_crit = 是否暴击。View 据此逐命中飘字。
signal hit_dealt(amount: float, is_crit: bool)
## 某成员闪避了敌人一次出手(0 伤害,无血量差,View 无法从 HP 推出 → 显式发)。member_index = party 下标。
signal player_dodged(member_index: int)
## 当前敌人缠斗超阈值进入软狂暴(每场最多发一次;start_battle 复位)。
signal enemy_enraged

const PARTY_SLOTS := 4
## 场景游标取值:0/1/2 = 三个普通场景,3 = 关底 Boss(PLAN D4)。
const BOSS_SCENE := 3

## 进度模式(PLAN D5/D6)。
## PROGRESSING:击杀推进游标;GRINDING:团灭回退后原地无尽刷,等玩家推进/修整;
## STAGE_CLEAR_COUNTDOWN:通关 Boss 后 5s 倒计时,无操作自动推进、可点修整;
## RESTING:玩家点修整后的占位/暂停态(stub,真城镇 = 04,PLAN §5 留 Implementer 定最简占位)。
enum Mode { PROGRESSING, GRINDING, STAGE_CLEAR_COUNTDOWN, RESTING }
## GRINDING 态下玩家入队的宏观操作,在"本轮结束"(当前敌人死亡)执行(PLAN D6)。
enum QueuedAction { NONE, PUSH, REST }

const KIND_GOLD := &"gold"
const KIND_MATERIAL := &"material"
const KIND_EQUIPMENT := &"equipment"
const RARITY_WHITE := &"white"
const RARITY_BLUE := &"blue"
const RARITY_GOLD := &"gold"

@export_group("v1 战士")
## 默认战士数值(走 @export 配置,不硬编码进逻辑)。招募 / 多职业 = v2。
@export var warrior_name := "战士"
@export var warrior_max_hp := 120.0
@export var warrior_attack := 6.0
## 战士的战斗维度占位(PLAN D3/F1;精调留数值专章)。攻速 = 每秒出手次数。
@export var warrior_attack_speed := 1.0
@export var warrior_armor := 0.0
@export_range(0.0, 1.0) var warrior_dodge_chance := 0.0
@export_range(0.0, 1.0) var warrior_crit_chance := 0.0
@export var warrior_crit_mult := 2.0
@export var warrior_hp_regen := 0.0

@export_group("公式")
## 护甲递减减伤常数 K:减伤 = armor/(armor+K);armor==K 时恰减 50%(PLAN D4,占位 50)。
@export var armor_k := 50.0

@export_group("软狂暴")
## 同一敌人缠斗超过此秒数进入狂暴,输出按 ramp 线性陡增,根除"互相打不动"死局(PLAN D5,占位)。
@export var enrage_threshold_sec := 25.0
## 狂暴后每多缠斗 1 秒,敌人伤害倍率额外 +此值(线性占位,曲线形状留 F1)。
@export var enrage_ramp_per_sec := 0.5

@export_group("进度")
## 通关 Boss 后的倒计时长度(秒);无操作到点自动推进(PLAN D6,留 playtest 调)。
@export var stage_clear_countdown_sec := 5.0

@export_group("模拟")
## 固定逻辑步长(秒);累加器按此步进,使战斗结果帧率无关、后台稳定推进(PLAN D8)。
@export var tick_seconds := 0.1

## 4 格队伍,空格为 null;v1 只填第 0 格。
var party: Array[PartyMember] = []

var _enemy_def: EnemyDef = null
var _enemy_hp := 0.0
## 敌人单场运行时状态(PLAN D2:绝不写回共享 Resource EnemyDef)。start_battle 复位。
var _enemy_attack_progress := 0.0
var _enemy_fight_time := 0.0
## 当前敌人是否已进入软狂暴(供 View 持续读;PLAN D7)。
var enraged := false

## 掉落 roll 用;测试可注入种子保证可复现(PLAN D10)。
var rng := RandomNumberGenerator.new()

## 进度配置:本局可玩的关卡(顺序即关序)。空 = 未接进度,tick 只解算单场(step 2/3 行为)。
var stages: Array[StageConfig] = []
## 进度游标(PLAN D4)。cur_scene 见 BOSS_SCENE 注释。
var cur_stage := 0
var cur_scene := 0
## 已解锁到的最高关序号;Boss 击杀永久前进,绝不回退(PLAN D4)。
var max_unlocked_stage := 0

var mode := Mode.PROGRESSING
## 团灭回退后,"推进"按钮的目标落点(PLAN D5);GRINDING 态下点推进会跳到这里。
var advance_target_stage := 0
var advance_target_scene := 0
## STAGE_CLEAR_COUNTDOWN 态剩余秒数(供视图显示);<=0 即自动推进。
var countdown_remaining := 0.0

var _progression_active := false
var _kills_this_scene := 0
var _queued := QueuedAction.NONE
var _accum := 0.0


func _ready() -> void:
	if party.is_empty():
		init_default_party()


## 固定步长累加器:把可变帧 delta 切成等长逻辑步,逐步推进倒计时 + 战斗(PLAN D8)。
## 收起态(15fps)与展开态(60fps)结果一致;窗口失焦/被遮挡照常推进(后台 tick)。
func _process(delta: float) -> void:
	if not _progression_active:
		return
	_accum += delta
	# 防卡死:单帧最多补若干步(超大 delta 时不无限循环)。
	var guard := 0
	while _accum >= tick_seconds and guard < 1000:
		_accum -= tick_seconds
		guard += 1
		process_countdown(tick_seconds)
		tick_combat()


## 建默认队伍:4 格,只填第 0 格战士。
func init_default_party() -> void:
	party = []
	party.resize(PARTY_SLOTS)
	party[0] = PartyMember.new(warrior_name, warrior_max_hp, warrior_attack, warrior_attack_speed, warrior_armor, warrior_dodge_chance, warrior_crit_chance, warrior_crit_mult, warrior_hp_regen)


## 开始一场针对指定敌人的战斗(刷新敌人血量)。
func start_battle(enemy_def: EnemyDef) -> void:
	_enemy_def = enemy_def
	_enemy_hp = enemy_def.max_hp if enemy_def != null else 0.0
	# 复位单场运行时状态(PLAN D2):新敌人出手进度/缠斗计时/狂暴态归零,成员出手进度清零。
	_enemy_attack_progress = 0.0
	_enemy_fight_time = 0.0
	enraged = false
	for m in party:
		if m != null:
			m.attack_progress = 0.0


func has_living_enemy() -> bool:
	return _enemy_def != null and _enemy_hp > 0.0


func has_living_member() -> bool:
	for m in party:
		if m != null and m.is_alive():
			return true
	return false


func enemy_hp() -> float:
	return _enemy_hp


## 推进一个战斗步(PLAN D4):缠斗计时/狂暴 → 每秒回血 → 队伍按攻速离散命中(暴击) →
## 敌死则结算掉落/推进 → 否则敌人按攻速出手(闪避→护甲减伤,狂暴加成) → 团灭判定。
## 外层胜负结构与下游事件(敌血≤0 / 全员倒)不变;只换两处伤害施加(FEATURE-DESIGN §3.8)。
func tick_combat() -> void:
	if not has_living_enemy() or not has_living_member():
		return
	# 缠斗计时 + 软狂暴触发(每场最多发一次)。
	_enemy_fight_time += tick_seconds
	if not enraged and _enemy_fight_time >= enrage_threshold_sec:
		enraged = true
		enemy_enraged.emit()
	# 每 tick 回血(场内即时,封顶满血;default hp_regen=0 → 无操作)。
	for m in party:
		if m != null and m.is_alive() and m.hp_regen > 0.0:
			m.current_hp = minf(m.max_hp, m.current_hp + m.hp_regen * tick_seconds)
	# 队伍进攻:逐成员累计出手,打出离散命中(可多次/tick),首杀即 break。
	for m in party:
		if m == null or not m.is_alive():
			continue
		m.attack_progress += m.attack_speed * tick_seconds
		var guard := 0
		while m.attack_progress >= 1.0 and guard < 1000:
			m.attack_progress -= 1.0
			guard += 1
			var dmg := m.attack
			var is_crit := m.crit_chance > 0.0 and rng.randf() < m.crit_chance
			if is_crit:
				dmg *= m.crit_mult
			_enemy_hp = maxf(0.0, _enemy_hp - dmg)
			hit_dealt.emit(dmg, is_crit)
			if _enemy_hp <= 0.0:
				break
		if _enemy_hp <= 0.0:
			break
	if _enemy_hp <= 0.0:
		var defeated := _enemy_def
		_enemy_def = null
		enemy_defeated.emit(defeated)
		_roll_loot(defeated)
		if _progression_active:
			_advance_after_kill()
		return
	# 敌人进攻:按攻速累计出手,打最前存活成员(闪避 → 护甲减伤,狂暴加成)。
	_enemy_attack_progress += _enemy_def.attack_speed * tick_seconds
	var eguard := 0
	while _enemy_attack_progress >= 1.0 and eguard < 1000:
		_enemy_attack_progress -= 1.0
		eguard += 1
		var target := _front_living_member()
		if target == null:
			break
		var raw := _enemy_def.attack * _enrage_mult()
		if target.dodge_chance > 0.0 and rng.randf() < target.dodge_chance:
			player_dodged.emit(party.find(target))
			continue
		# 护甲递减;denom<=0(armor 与 armor_k 同为 0,配置 footgun)时跳过减伤,避免 0/0=NaN。
		var denom := target.armor + armor_k
		var reduced := raw if denom <= 0.0 else raw * (1.0 - target.armor / denom)
		target.take_damage(reduced)
	if not has_living_member():
		party_wiped.emit()
		if _progression_active:
			_retreat_after_wipe()


## 狂暴伤害倍率:未狂暴 = 1.0;狂暴后随超阈值时长线性陡增(占位线性,曲线留 F1)。
func _enrage_mult() -> float:
	if not enraged:
		return 1.0
	return 1.0 + enrage_ramp_per_sec * (_enemy_fight_time - enrage_threshold_sec)


func _front_living_member() -> PartyMember:
	for m in party:
		if m != null and m.is_alive():
			return m
	return null


## ── 进度状态机(PLAN step 4 / D4)──────────────────────────────────────────

## 接入关卡配置并从指定游标开局,自动刷当前敌人。stages 为空时进度不生效。
func begin_run(p_stages: Array[StageConfig], stage := 0, scene := 0) -> void:
	stages = p_stages
	cur_stage = stage
	cur_scene = scene
	max_unlocked_stage = maxi(max_unlocked_stage, stage)
	_kills_this_scene = 0
	mode = Mode.PROGRESSING
	_progression_active = true
	_spawn_current()


## 当前游标对应的敌人(Boss 场景取关底 Boss);越界返回 null。
func current_enemy_def() -> EnemyDef:
	if cur_stage < 0 or cur_stage >= stages.size():
		return null
	var st := stages[cur_stage]
	if cur_scene == BOSS_SCENE:
		return st.boss
	if cur_scene >= 0 and cur_scene < st.scenes.size():
		return st.scenes[cur_scene].enemy
	return null


func _spawn_current() -> void:
	start_battle(current_enemy_def())


## 一次击杀后推进进度:Boss → 永久解锁 + 进下一关;普通场景 → 计数达标进下一场景。
func _advance_after_kill() -> void:
	# 团灭回退后原地无尽刷。入队的推进/修整在"本轮结束"(当前敌人死亡)立即执行(PLAN D6,响应优先)。
	if mode == Mode.GRINDING:
		if _queued == QueuedAction.PUSH:
			_queued = QueuedAction.NONE
			_execute_push()
			return
		if _queued == QueuedAction.REST:
			_queued = QueuedAction.NONE
			_enter_rest()
			return
		# 无入队 = 继续刷:计入本场景击杀,刷满 kill_count = 一轮完成 → 全队回满再刷(用户拍板 2026-06-18)。
		_kills_this_scene += 1
		var gst := stages[cur_stage]
		var gneed := gst.scenes[cur_scene].kill_count if (cur_scene >= 0 and cur_scene < gst.scenes.size()) else 1
		if _kills_this_scene >= gneed:
			_kills_this_scene = 0
			_revive_party()
		_spawn_current()
		return
	if cur_scene == BOSS_SCENE:
		var beaten_stage := cur_stage
		max_unlocked_stage = maxi(max_unlocked_stage, beaten_stage + 1)
		boss_cleared.emit(beaten_stage)
		# 通关回满:下一关满状态开局(过场景回血,用户拍板 2026-06-18)。
		_revive_party()
		# 不立刻推进:进 5s 倒计时,无操作自动推进、可点修整(PLAN D6)。
		advance_target_stage = beaten_stage + 1
		advance_target_scene = 0
		mode = Mode.STAGE_CLEAR_COUNTDOWN
		countdown_remaining = stage_clear_countdown_sec
		return
	_kills_this_scene += 1
	var st := stages[cur_stage]
	var need := st.scenes[cur_scene].kill_count if cur_scene < st.scenes.size() else 1
	if _kills_this_scene >= need:
		# 清完最后一个普通场景 → 直接进 Boss(数据通常 3 场景,但不写死场景数)。
		cur_scene = BOSS_SCENE if cur_scene + 1 >= st.scenes.size() else cur_scene + 1
		_kills_this_scene = 0
		# 过场景回血:每清完一个场景全队回满(用户拍板 2026-06-18)。
		_revive_party()
	_spawn_current()


## ── 玩家宏观操作:推进 / 修整 + 倒计时(PLAN step 6 / D6)──────────────────

## 玩家点"推进":GRINDING 态入队,在本轮结束(当前敌人死亡)执行(PLAN D6)。
func request_push() -> void:
	if mode == Mode.GRINDING:
		_queued = QueuedAction.PUSH


## 玩家点"修整":GRINDING 态入队本轮结束执行;倒计时态立即修整并取消自动推进。
func request_rest() -> void:
	if mode == Mode.GRINDING:
		_queued = QueuedAction.REST
	elif mode == Mode.STAGE_CLEAR_COUNTDOWN:
		countdown_remaining = 0.0
		_enter_rest()


## 倒计时推进(由固定步长 tick 驱动,step 7;测试可直接喂 delta)。到点无操作 → 自动推进。
func process_countdown(delta: float) -> void:
	if mode != Mode.STAGE_CLEAR_COUNTDOWN:
		return
	countdown_remaining -= delta
	if countdown_remaining <= 0.0:
		countdown_remaining = 0.0
		_execute_push()


## 执行推进:跳到 advance_target 落点,回到 PROGRESSING 并刷怪。
func _execute_push() -> void:
	cur_stage = advance_target_stage
	cur_scene = advance_target_scene
	_kills_this_scene = 0
	mode = Mode.PROGRESSING
	_spawn_current()


## 进入"修整"stub:停刷怪 + 进 RESTING 占位态 + 发信号(v1 暂停,真城镇 = 04)。
func _enter_rest() -> void:
	_enemy_def = null
	mode = Mode.RESTING
	rest_requested.emit()


## 关 S 的最后一个普通场景下标(通常 = 2);供回退落点用。
func _last_normal_scene(stage: int) -> int:
	if stage < 0 or stage >= stages.size():
		return 0
	return maxi(0, stages[stage].scenes.size() - 1)


## 团灭回退(PLAN D5 四条):算出无尽刷落点 + "推进"按钮目标,进 GRINDING,复活队伍重刷。
func _retreat_after_wipe() -> void:
	var s := cur_stage
	var i := cur_scene
	if i == BOSS_SCENE:
		# Boss 未通即团灭:退到 (S, 末普通场景) 刷;推进 → 重新挑战本关 Boss。
		cur_scene = _last_normal_scene(s)
		advance_target_stage = s
		advance_target_scene = BOSS_SCENE
	elif i >= 1:
		# 普通场景 1/2:退到 (S, i-1) 刷;推进 → 回到 (S, i)。
		cur_scene = i - 1
		advance_target_stage = s
		advance_target_scene = i
	elif s > 0:
		# 本关第一场景且非首关:跳过上一关 Boss,退到 (S-1, 末场景) 刷;推进 → (S, 0)。
		cur_stage = s - 1
		cur_scene = _last_normal_scene(s - 1)
		advance_target_stage = s
		advance_target_scene = 0
	else:
		# 首关第一场景:无上一关可退,原地刷(边缘态)。
		cur_stage = 0
		cur_scene = 0
		advance_target_stage = 0
		advance_target_scene = 0
	_kills_this_scene = 0
	mode = Mode.GRINDING
	_revive_party()
	_spawn_current()


## 把全部存在的成员血量回满(团灭回退、过场景、通关时调用)。
func _revive_party() -> void:
	for m in party:
		if m != null:
			m.current_hp = m.max_hp


## 一次击杀的掉落:先 roll 是否掉落,再 roll 种类,非金币再 roll 稀有度;金币一律 white。
## 最多发一次 loot_dropped(0/1),与 PLAN D7 一致。
func _roll_loot(def: EnemyDef) -> void:
	if def == null:
		return
	if rng.randf() >= def.drop_chance:
		return
	var kinds: Array[StringName] = [KIND_GOLD, KIND_MATERIAL, KIND_EQUIPMENT]
	var kind_weights := [def.weight_gold, def.weight_material, def.weight_equipment]
	var kind: StringName = _weighted_pick(kinds, kind_weights)
	var rarity: StringName = RARITY_WHITE
	if kind != KIND_GOLD:
		var rarities: Array[StringName] = [RARITY_WHITE, RARITY_BLUE, RARITY_GOLD]
		var rarity_weights := [def.rarity_weight_white, def.rarity_weight_blue, def.rarity_weight_gold]
		rarity = _weighted_pick(rarities, rarity_weights)
	loot_dropped.emit(kind, rarity)


## 按权重从 options 里挑一个;权重和 <= 0 时返回第 0 个(退化保护)。
func _weighted_pick(options: Array[StringName], weights: Array) -> StringName:
	var total := 0.0
	for w in weights:
		total += maxf(0.0, w)
	if total <= 0.0:
		return options[0]
	var pick := rng.randf() * total
	var acc := 0.0
	for i in options.size():
		acc += maxf(0.0, weights[i])
		if pick < acc:
			return options[i]
	return options[options.size() - 1]
