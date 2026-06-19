extends GdUnitTestSuite
## PLAN 步 5d 验证:CombatArena 单局解算 + tick。
## 断言值逐条迁自 formula_test(11)+ combat_director_test(5)+ tick_driver_test(2),改为驱动 Arena。

const MAX_HP := GameKeys.STAT_MAX_HP
const ATTACK := GameKeys.STAT_ATTACK
const ASPD := GameKeys.STAT_ATTACK_SPEED

func _player(hp: float, atk: float, extra := {}) -> Entity:
	var e: Entity = auto_free(Entity.new(Entity.Team.PLAYER))
	var s := StatsComponent.new()
	s.set_base(MAX_HP, hp)
	s.set_base(ATTACK, atk)
	s.set_base(ASPD, 1.0)                     # 承 formula_test _member 默认攻速 1.0
	for k in extra.keys():
		s.set_base(k, float(extra[k]))
	e.stats = s
	e.current_hp = hp
	return e

func _enemy(hp: float, atk: float, spd := 1.0) -> Entity:
	var def := EnemyDef.new()
	def.max_hp = hp
	def.attack = atk
	def.attack_speed = spd
	def.drop_chance = 0.0
	return auto_free(Entity.from_enemy_def(def))

func _arena(tick := 0.1) -> CombatArena:
	var a: CombatArena = auto_free(CombatArena.new())
	a.tuning = CombatTuning.new()
	a.tuning.tick_seconds = tick
	a.rng.seed = 7
	return a

func _solo(e: Entity) -> Array[Entity]:
	var arr: Array[Entity] = [e]
	return arr

# ── 暴击(formula_test:26-52)────────────────────────────────────────────────

func test_crit_doubles_a_hit_when_chance_is_one() -> void:
	var a := _arena(1.0)
	var m := _player(1000.0, 10.0, {GameKeys.STAT_CRIT_CHANCE: 1.0, GameKeys.STAT_CRIT_MULT: 2.0})
	a.players = _solo(m)
	var last := [0.0, false]
	a.hit_dealt.connect(func(amount, is_crit): last[0] = amount; last[1] = is_crit)
	var enemy := _enemy(1000.0, 0.0, 0.0)
	a.start_battle(_solo(enemy))
	a.tick_combat()
	assert_float(last[0]).is_equal(20.0)            # 10 × 2
	assert_bool(last[1]).is_true()
	assert_float(enemy.current_hp).is_equal(980.0)

func test_no_crit_when_chance_is_zero() -> void:
	var a := _arena(1.0)
	var m := _player(1000.0, 10.0, {GameKeys.STAT_CRIT_CHANCE: 0.0})
	a.players = _solo(m)
	var last := [0.0, true]
	a.hit_dealt.connect(func(amount, is_crit): last[0] = amount; last[1] = is_crit)
	a.start_battle(_solo(_enemy(1000.0, 0.0, 0.0)))
	a.tick_combat()
	assert_float(last[0]).is_equal(10.0)
	assert_bool(last[1]).is_false()

# ── 闪避(formula_test:56-77)────────────────────────────────────────────────

func test_dodge_negates_incoming_hit_when_chance_is_one() -> void:
	var a := _arena(1.0)
	var m := _player(100.0, 1.0, {GameKeys.STAT_DODGE_CHANCE: 1.0})
	a.players = _solo(m)
	var dodged := [-1]
	a.player_dodged.connect(func(idx): dodged[0] = idx)
	a.start_battle(_solo(_enemy(1000.0, 50.0, 1.0)))
	a.tick_combat()
	assert_float(m.current_hp).is_equal(100.0)      # 未掉血
	assert_int(dodged[0]).is_equal(0)

func test_no_dodge_takes_full_hit_when_chance_is_zero() -> void:
	var a := _arena(1.0)
	var m := _player(100.0, 1.0, {GameKeys.STAT_DODGE_CHANCE: 0.0})
	a.players = _solo(m)
	a.start_battle(_solo(_enemy(1000.0, 50.0, 1.0)))
	a.tick_combat()
	assert_float(m.current_hp).is_equal(50.0)       # 100 - 50

# ── 护甲(formula_test:81-101)──────────────────────────────────────────────

func test_armor_equal_to_k_halves_incoming_damage() -> void:
	var a := _arena(1.0)
	a.tuning.armor_k = 50.0
	var m := _player(1000.0, 1.0, {GameKeys.STAT_ARMOR: 50.0})
	a.players = _solo(m)
	a.start_battle(_solo(_enemy(1000.0, 100.0, 1.0)))
	a.tick_combat()
	assert_float(m.current_hp).is_equal(950.0)      # 1000 - 100×0.5

func test_zero_armor_takes_full_damage() -> void:
	var a := _arena(1.0)
	a.tuning.armor_k = 50.0
	var m := _player(1000.0, 1.0, {GameKeys.STAT_ARMOR: 0.0})
	a.players = _solo(m)
	a.start_battle(_solo(_enemy(1000.0, 100.0, 1.0)))
	a.tick_combat()
	assert_float(m.current_hp).is_equal(900.0)      # 1000 - 100

# ── 回血(formula_test:105-127)─────────────────────────────────────────────

func test_hp_regen_heals_each_tick() -> void:
	var a := _arena(0.1)
	var m := _player(100.0, 0.0, {ASPD: 0.0, GameKeys.STAT_HP_REGEN: 5.0})
	m.current_hp = 50.0
	a.players = _solo(m)
	a.start_battle(_solo(_enemy(1000.0, 0.0, 0.0)))
	a.tick_combat()
	assert_float(m.current_hp).is_equal(50.5)       # +5 × 0.1

func test_hp_regen_capped_at_max_hp() -> void:
	var a := _arena(0.1)
	var m := _player(100.0, 0.0, {ASPD: 0.0, GameKeys.STAT_HP_REGEN: 5.0})
	m.current_hp = 99.9
	a.players = _solo(m)
	a.start_battle(_solo(_enemy(1000.0, 0.0, 0.0)))
	a.tick_combat()
	assert_float(m.current_hp).is_equal(100.0)      # 封顶

# ── 攻速 → 出手频率(容差断言)─────────────────────────────────────────────

func test_attack_speed_governs_hit_frequency() -> void:
	var a := _arena(0.1)
	var m := _player(1000.0, 1.0, {ASPD: 1.0})
	a.players = _solo(m)
	var hits := [0]
	a.hit_dealt.connect(func(_amt, _c): hits[0] += 1)
	a.start_battle(_solo(_enemy(1.0e9, 0.0, 0.0)))
	for i in 100:
		a.tick_combat()
	assert_int(hits[0]).is_between(8, 12)           # ~10 次

func test_double_attack_speed_roughly_doubles_hits() -> void:
	var a := _arena(0.1)
	var m := _player(1000.0, 1.0, {ASPD: 2.0})
	a.players = _solo(m)
	var hits := [0]
	a.hit_dealt.connect(func(_amt, _c): hits[0] += 1)
	a.start_battle(_solo(_enemy(1.0e9, 0.0, 0.0)))
	for i in 100:
		a.tick_combat()
	assert_int(hits[0]).is_between(17, 23)          # ~20 次

# ── 软狂暴(formula_test:159-214)───────────────────────────────────────────

func test_soft_enrage_triggers_once_after_threshold() -> void:
	var a := _arena(0.1)
	a.tuning.enrage_threshold_sec = 0.5
	var m := _player(1.0e9, 0.0, {ASPD: 0.0})
	a.players = _solo(m)
	var enrage_count := [0]
	a.enemy_enraged.connect(func(): enrage_count[0] += 1)
	a.start_battle(_solo(_enemy(1.0e9, 10.0, 0.0)))
	for i in 4:
		a.tick_combat()                              # 0.4 < 0.5
	assert_bool(a.enraged).is_false()
	assert_int(enrage_count[0]).is_equal(0)
	a.tick_combat()                                  # 0.5 ≥ 阈值
	assert_bool(a.enraged).is_true()
	assert_int(enrage_count[0]).is_equal(1)
	for i in 20:
		a.tick_combat()
	assert_int(enrage_count[0]).is_equal(1)          # 每场最多一次

func test_enrage_amplifies_enemy_damage() -> void:
	var a := _arena(0.1)
	a.tuning.enrage_threshold_sec = 0.5
	a.tuning.enrage_ramp_per_sec = 0.5
	var m := _player(1.0e9, 0.0, {ASPD: 0.0})
	a.players = _solo(m)
	a.start_battle(_solo(_enemy(1.0e9, 10.0, 10.0)))  # 敌攻速10 → 每 tick 出手一次
	var hp0 := m.current_hp
	a.tick_combat()                                  # tick1:未狂暴,伤害 = 10
	var loss_pre := hp0 - m.current_hp
	for i in 20:
		a.tick_combat()
	var hp_before := m.current_hp
	a.tick_combat()
	var loss_post := hp_before - m.current_hp
	assert_bool(a.enraged).is_true()
	assert_float(loss_pre).is_equal(10.0)
	assert_float(loss_post).is_greater(loss_pre)     # 狂暴后单次更高

func test_start_battle_resets_enrage_state() -> void:
	var a := _arena(0.1)
	a.tuning.enrage_threshold_sec = 0.5
	var m := _player(1.0e9, 0.0, {ASPD: 0.0})
	a.players = _solo(m)
	a.start_battle(_solo(_enemy(1.0e9, 10.0, 0.0)))
	for i in 10:
		a.tick_combat()
	assert_bool(a.enraged).is_true()
	a.start_battle(_solo(_enemy(1.0e9, 10.0, 0.0)))  # 新敌人
	assert_bool(a.enraged).is_false()
	assert_float(a.battle_time).is_equal(0.0)

# ── 单场解算(combat_director_test:13-65)──────────────────────────────────

func test_enemy_defeated_after_enough_ticks() -> void:
	var a := _arena(1.0)
	a.players = _solo(_player(100.0, 10.0))
	var count := [0]
	a.enemy_defeated.connect(func(_e): count[0] += 1)
	a.start_battle(_solo(_enemy(25.0, 1.0)))
	for i in 10:
		a.tick_combat()
	assert_int(count[0]).is_equal(1)
	assert_bool(a.has_living_enemy()).is_false()

func test_member_down_but_party_continues_when_one_alive() -> void:
	var a := _arena(1.0)
	var fragile := _player(5.0, 2.0)
	var tank := _player(200.0, 8.0)
	var party: Array[Entity] = [fragile, tank]
	a.players = party
	var wiped := [false]
	a.party_wiped.connect(func(): wiped[0] = true)
	a.start_battle(_solo(_enemy(500.0, 10.0)))       # 高血敌,几 tick 不死
	for i in 3:
		a.tick_combat()
	assert_bool(fragile.is_alive()).is_false()       # 脆皮倒
	assert_bool(tank.is_alive()).is_true()           # 坦克在
	assert_bool(a.has_living_member()).is_true()
	assert_bool(wiped[0]).is_false()

func test_party_wiped_when_all_down() -> void:
	var a := _arena(1.0)
	a.players = _solo(_player(12.0, 3.0))
	var wiped := [0]
	var defeated := [0]
	a.party_wiped.connect(func(): wiped[0] += 1)
	a.enemy_defeated.connect(func(_e): defeated[0] += 1)
	a.start_battle(_solo(_enemy(500.0, 6.0)))         # 敌远强 → 必团灭
	for i in 10:
		a.tick_combat()
	assert_int(wiped[0]).is_equal(1)
	assert_int(defeated[0]).is_equal(0)
	assert_bool(a.has_living_member()).is_false()

func test_single_character_roster_yields_one_living_member() -> void:
	# 替代 director.init_default_party:v1 由单角色 roster 快照建一员存活队伍。
	var registry: DataRegistry = null
	var c := Character.new(&"战士", &"warrior")
	c.base_stats = {MAX_HP: 120.0, ATTACK: 6.0, ASPD: 1.0}
	var hero: Entity = auto_free(Entity.from_character(c, registry))
	var party: Array[Entity] = [hero]
	var a := _arena(1.0)
	a.players = party
	assert_int(a.players.size()).is_equal(1)
	assert_bool(a.players[0].is_alive()).is_true()
	assert_float(a.players[0].max_hp()).is_equal(120.0)

# ── 固定步长累加器(tick_driver_test:32-58)────────────────────────────────

func _respawning_arena(tick: float, kills: Array) -> CombatArena:
	# 1血/atk0 怪,杀掉即补一只 → 还原 tick_driver「每 tick 恰一杀」的累加器观测。
	var a := _arena(tick)
	var warrior := _player(1000.0, 100.0, {ASPD: 15.0})  # 攻速15 → 每 tick ≥1 出手
	a.players = _solo(warrior)
	a.enemy_defeated.connect(func(_e):
		kills[0] += 1
		a.start_battle(_solo(_enemy(1.0, 0.0, 0.0))))
	a.start_battle(_solo(_enemy(1.0, 0.0, 0.0)))
	return a

func test_same_sim_time_yields_same_tick_count_regardless_of_frame_size() -> void:
	var big_kills := [0]
	var big := _respawning_arena(0.1, big_kills)
	big._process(1.0)                                # 一大帧 = 10 步

	var small_kills := [0]
	var small := _respawning_arena(0.1, small_kills)
	for i in 10:
		small._process(0.1)                          # 十小帧 = 10 步

	assert_int(big_kills[0]).is_equal(10)
	assert_int(small_kills[0]).is_equal(10)
	assert_int(big_kills[0]).is_equal(small_kills[0])

func test_accumulator_carries_remainder_across_frames() -> void:
	var kills := [0]
	var a := _respawning_arena(0.1, kills)
	a._process(0.05)                                 # < 0.1 → 不足一步
	assert_int(kills[0]).is_equal(0)
	a._process(0.05)                                 # 累计 0.1 → 恰一步
	assert_int(kills[0]).is_equal(1)

# ── 〔08 团战 §3c〕近战门控 + 远程隔位 ──────────────────────────────────────
# 玩家 atk0 → 不杀敌(敌不死、不推进),aspd1×tick1 → 每敌每 tick 恰一击,纯观测「谁够得着」。

func _foe(hp: float, atk: float, pc: EnemyDef.PositionClass, rank: int) -> Entity:
	var def := EnemyDef.new()
	def.max_hp = hp
	def.attack = atk
	def.attack_speed = 1.0
	def.drop_chance = 0.0
	def.position_class = pc
	return auto_free(Entity.from_enemy_def(def, rank))

func test_melee_gate_limits_active_attackers_to_capacity() -> void:
	var a := _arena(1.0)
	a.tuning.melee_gate_capacity = 2
	a.players = _solo(_player(1000.0, 0.0))
	var e0 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 0)
	var e1 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 1)
	var e2 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 2)
	a.start_battle([e0, e1, e2] as Array[Entity])
	a.tick_combat()
	# 前 2 名近战各出手 10,第 3 名排队 0 伤 → 玩家共失 20。
	assert_float(a.players[0].current_hp).is_equal(980.0)

func test_melee_gate_promotes_next_when_front_dies() -> void:
	var a := _arena(1.0)
	a.tuning.melee_gate_capacity = 2
	a.players = _solo(_player(1000.0, 0.0))
	var e0 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 0)
	var e1 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 1)
	var e2 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 2)
	a.start_battle([e0, e1, e2] as Array[Entity])
	e0.take_damage(999.0)                            # 前排死 → 存活近战前 2 = e1,e2
	a.tick_combat()
	assert_float(a.players[0].current_hp).is_equal(980.0)  # e1+e2 各 10,e0 死不出手

func test_ranged_attacks_regardless_of_gate() -> void:
	var a := _arena(1.0)
	a.tuning.melee_gate_capacity = 2
	a.players = _solo(_player(1000.0, 0.0))
	var m0 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 0)
	var m1 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 1)
	var m2 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 2)
	var r3 := _foe(100.0, 10.0, EnemyDef.PositionClass.RANGED, 3)
	a.start_battle([m0, m1, m2, r3] as Array[Entity])
	a.tick_combat()
	# 近战门控前 2(m0,m1)=20 + 远程隔位 r3=10;m2 排队 0 → 失 30。
	assert_float(a.players[0].current_hp).is_equal(970.0)

func test_higher_gate_capacity_lets_more_melee_attack() -> void:
	var a := _arena(1.0)
	a.tuning.melee_gate_capacity = 3                 # 覆值验门控容量可调
	a.players = _solo(_player(1000.0, 0.0))
	var e0 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 0)
	var e1 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 1)
	var e2 := _foe(100.0, 10.0, EnemyDef.PositionClass.MELEE, 2)
	a.start_battle([e0, e1, e2] as Array[Entity])
	a.tick_combat()
	assert_float(a.players[0].current_hp).is_equal(970.0)  # G=3 → 三只全出手 → 失 30
