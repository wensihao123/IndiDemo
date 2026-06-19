extends Node
class_name CombatArena
## 单局战斗编排 + 固定步长 tick(替换 combat_director 的解算/tick 部分,值不变;承 :115-226)。
## 职责正交于 ProgressionController(跨场推进):Arena 跑一局、发 enemy_defeated/party_wiped,
## Progression 监听后令 Arena 开下一场。组件(skill/ai)由本类直接方法调用驱动(不靠 _process)。

## 同名同义信号,供层 6 View 平迁(承 combat_director 信号)。
signal hit_dealt(amount: float, is_crit: bool)
signal player_dodged(member_index: int)
signal enemy_defeated(enemy: EnemyDef)
signal party_wiped
signal enemy_enraged
## 敌死掉落:instance = 产出的 ItemInstance,destination ∈ LootIntake.{EQUIPPED/DECOMPOSED/BAGGED}(5e 接线)。
signal item_dropped(instance: ItemInstance, destination: StringName)

var players: Array[Entity] = []
var enemies: Array[Entity] = []
var tuning: CombatTuning = CombatTuning.new()
var rng := RandomNumberGenerator.new()

## 当前敌人缠斗计时(每场战斗,承 _enemy_fight_time)+ 软狂暴态(供 View 读)。
var battle_time := 0.0
var enraged := false

## 固定步长累加器(承 :118)。running 时 _process 才推进;测试可直接调 tick_combat()。
var running := false
var _accum := 0.0
## 本 tick 内是否因敌死触发了新战斗(progression 推进/补刷)。承 director:一次击杀后 return,
## 当 tick 不让新生敌反击(:197-204 的 return)。start_battle 置位,tick_combat 顶部复位。
var _battle_restarted := false

## 5e/5f 接线点(默认空,保持 5d 纯解算可独立测)。
var registry: DataRegistry = null
var player_state: PlayerState = null
var loot_equipment: EquipmentComponent = null    # 掉落填空目标(v1 = 战士装备;5e 注入)
var progression = null                            # ProgressionController(5f 注入)

var _loot_gen := LootGenerator.new()


## 开始一场:置敌、复位缠斗计时/狂暴/各实体出手进度(承 start_battle :136-145)。
func start_battle(enemy_entities: Array[Entity]) -> void:
	enemies = enemy_entities
	battle_time = 0.0
	enraged = false
	running = true
	_battle_restarted = true
	for p in players:
		if p != null:
			p.reset_swing()
	for e in enemies:
		if e != null:
			e.reset_swing()


func _has_living(group: Array[Entity]) -> bool:
	for e in group:
		if e != null and e.is_alive():
			return true
	return false


func has_living_enemy() -> bool:
	return _has_living(enemies)


func has_living_member() -> bool:
	return _has_living(players)


## 〔08 团战 §3c〕前 G 名存活近战门控集合:按排位序(enemies 数组序)取存活近战前 G 名。
## 远程不入此集合(隔位恒可出手,不占门控名额);G = tuning.melee_gate_capacity。
func _front_melee_attackers() -> Array[Entity]:
	var cap: int = tuning.melee_gate_capacity
	var out: Array[Entity] = []
	for e in enemies:
		if e == null or not e.is_alive():
			continue
		if e.position_class == EnemyDef.PositionClass.RANGED:
			continue
		out.append(e)
		if out.size() >= cap:
			break
	return out


## 固定步长累加器:可变帧 delta 切成等长逻辑步(承 :115-125;倒计时委托 Progression)。
func _process(delta: float) -> void:
	if not running:
		return
	_accum += delta
	var guard := 0
	while _accum >= tuning.tick_seconds and guard < 1000:
		_accum -= tuning.tick_seconds
		guard += 1
		if progression != null:
			progression.process_countdown(tuning.tick_seconds)
		tick_combat()


## 推进一个战斗步(承 combat_director.tick_combat :166-226,逐条等值):
## 缠斗计时/狂暴 → 每秒回血 → 我方按攻速离散命中(暴击)→ 敌死结算 → 敌按攻速出手(闪避→护甲,狂暴加成)→ 团灭判定。
func tick_combat() -> void:
	if not _has_living(enemies) or not _has_living(players):
		return
	_battle_restarted = false
	# 缠斗计时 + 软狂暴触发(每场最多一次)。
	battle_time += tuning.tick_seconds
	if not enraged and battle_time >= tuning.enrage_threshold_sec:
		enraged = true
		enemy_enraged.emit()
	# 每 tick 回血(场内即时,封顶满血;default hp_regen=0 → 无操作)。
	for p in players:
		if p != null and p.is_alive():
			var regen: float = p.stats.get_final(GameKeys.STAT_HP_REGEN) * tuning.tick_seconds
			if regen > 0.0:
				p.heal(regen)
	# 我方进攻:逐成员累计出手,打最前存活敌(可多次/tick),敌死即结算。
	for idx in players.size():
		var p: Entity = players[idx]
		if p == null or not p.is_alive():
			continue
		p.skill.accumulate(p.stats.get_final(GameKeys.STAT_ATTACK_SPEED), tuning.tick_seconds)
		for _s in p.skill.pending_swings():
			var target: Entity = p.ai.select_target(p, enemies)
			if target == null:
				break
			var res: Dictionary = p.skill.resolve_hit(p, target, tuning, rng)
			if res["dodged"]:
				continue
			target.take_damage(res["amount"])
			hit_dealt.emit(res["amount"], res["is_crit"])
			if not target.is_alive():
				_handle_enemy_defeated(target)
				if _battle_restarted:
					return        # 信号处理器(测试/View)在敌死回调里重开战 → 本 tick 即止,新生敌不反击
		if not _has_living(enemies):
			break
	# 〔08 团战 #12〕一波清空才推进/刷下一波(per-wave);未清空则继续本 tick 敌方反击。
	# _battle_restarted 已真 = 信号处理器(测试/View)已重开战 → 不重复推进。
	if not _has_living(enemies):
		if progression != null and not _battle_restarted:
			progression.advance_after_wave()
		return
	# 敌进攻:按攻速累计出手,打最前存活成员(闪避→护甲减伤,狂暴加成)。
	# 〔08 团战 §3c〕近战门控:仅「前 G 名存活近战」可出手(余者排队补位,不蓄力);远程隔位恒可出手。
	var mult: float = tuning.enrage_mult(battle_time, enraged)
	var active_melee := _front_melee_attackers()
	for e in enemies:
		if e == null or not e.is_alive():
			continue
		if e.position_class != EnemyDef.PositionClass.RANGED and not active_melee.has(e):
			continue
		e.skill.accumulate(e.stats.get_final(GameKeys.STAT_ATTACK_SPEED), tuning.tick_seconds)
		for _s in e.skill.pending_swings():
			var target: Entity = e.ai.select_target(e, players)
			if target == null:
				break
			var res: Dictionary = e.skill.resolve_hit(e, target, tuning, rng, mult)
			if res["dodged"]:
				player_dodged.emit(players.find(target))
				continue
			target.take_damage(res["amount"])
	if not _has_living(players):
		party_wiped.emit()
		if progression != null:
			progression.retreat_after_wipe()


## 敌死结算:发 enemy_defeated → 掉落(5e)→ per-enemy 计杀(08 团战 #12)。
## 〔REFACTOR-04 §3b〕不再在此重刷:推进/刷下一波延到 tick 检测「波清空」时调 advance_after_wave。
func _handle_enemy_defeated(entity: Entity) -> void:
	var def: EnemyDef = entity.source_enemy_def
	enemy_defeated.emit(def)
	_drop_loot(def)
	if progression != null:
		progression.register_kill()


## 掉落钩子:敌死 → PoE 流水线产 ItemInstance(ilvl=def.item_level)→ LootIntake 路由进 PlayerState。
## 接线未注满(registry/player_state/loot_equipment 任一空)时跳过 → 保 5d 纯解算可独立测。
## slot 为占位规则(随机选,留数值专章);rarity 按 EnemyDef 的 rarity_weight_* 加权(白重、Boss 偏蓝金)。
func _drop_loot(def: EnemyDef) -> void:
	if def == null or registry == null or player_state == null or loot_equipment == null:
		return
	if rng.randf() >= def.drop_chance:
		return
	var slot: StringName = GameKeys.SLOTS[rng.randi() % GameKeys.SLOTS.size()]
	var rarity_idx := LootGenerator.pick_weighted(
		[def.rarity_weight_white, def.rarity_weight_blue, def.rarity_weight_gold], rng)
	var rarity: StringName = GameKeys.RARITIES[rarity_idx]
	var inst := _loot_gen.generate(slot, def.item_level, rarity, registry, rng)
	var dest := LootIntake.handle_drop(inst, loot_equipment, player_state, registry.get_loot_table())
	item_dropped.emit(inst, dest)
