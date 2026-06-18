extends GdUnitTestSuite
## PLAN step 3 验证:扩展战斗公式六维 + 软狂暴本身的机制正确性(03-combat-formula-ext)。
## 用 0.0/1.0 极值或注入 rng.seed 去随机;cadence 用容差断言,绝不断言精确逐 tick 计数(PLAN Flag-C)。

func _member(hp: float, atk: float) -> PartyMember:
	# 默认无任何加成的成员;各测试按需覆盖单一维度,隔离验证。
	var m := PartyMember.new("战士", hp, atk)
	m.attack_speed = 1.0
	return m

func _enemy(hp: float, atk: float, spd := 1.0) -> EnemyDef:
	var e := EnemyDef.new()
	e.max_hp = hp
	e.attack = atk
	e.attack_speed = spd
	e.drop_chance = 0.0
	return e

func _director() -> CombatDirector:
	var d: CombatDirector = auto_free(CombatDirector.new())
	d.rng.seed = 7
	return d

# ── 暴击 ────────────────────────────────────────────────────────────────────

func test_crit_doubles_a_hit_when_chance_is_one() -> void:
	var d := _director()
	d.tick_seconds = 1.0  # attack_speed 1.0 × 1.0 = 恰每 tick 出手一次(整数,无浮点漂移)
	var m := _member(1000.0, 10.0)
	m.crit_chance = 1.0
	m.crit_mult = 2.0
	d.party = [m, null, null, null]
	var last := [0.0, false]
	d.hit_dealt.connect(func(amount, is_crit): last[0] = amount; last[1] = is_crit)
	d.start_battle(_enemy(1000.0, 0.0, 0.0))  # 敌人不还手、高血存活
	d.tick_combat()
	assert_float(last[0]).is_equal(20.0)        # 10 × 2
	assert_bool(last[1]).is_true()
	assert_float(d.enemy_hp()).is_equal(980.0)

func test_no_crit_when_chance_is_zero() -> void:
	var d := _director()
	d.tick_seconds = 1.0
	var m := _member(1000.0, 10.0)
	m.crit_chance = 0.0
	d.party = [m, null, null, null]
	var last := [0.0, true]
	d.hit_dealt.connect(func(amount, is_crit): last[0] = amount; last[1] = is_crit)
	d.start_battle(_enemy(1000.0, 0.0, 0.0))
	d.tick_combat()
	assert_float(last[0]).is_equal(10.0)
	assert_bool(last[1]).is_false()

# ── 闪避(全有/全无)─────────────────────────────────────────────────────────

func test_dodge_negates_incoming_hit_when_chance_is_one() -> void:
	var d := _director()
	d.tick_seconds = 1.0
	var m := _member(100.0, 1.0)  # 低攻,敌人高血存活到能还手
	m.dodge_chance = 1.0
	d.party = [m, null, null, null]
	var dodged := [-1]
	d.player_dodged.connect(func(idx): dodged[0] = idx)
	d.start_battle(_enemy(1000.0, 50.0, 1.0))
	d.tick_combat()  # 我方打敌(敌存活)→ 敌出手被闪避
	assert_float(d.party[0].current_hp).is_equal(100.0)  # 未掉血
	assert_int(dodged[0]).is_equal(0)                    # 第 0 格闪避

func test_no_dodge_takes_full_hit_when_chance_is_zero() -> void:
	var d := _director()
	d.tick_seconds = 1.0
	var m := _member(100.0, 1.0)
	m.dodge_chance = 0.0  # armor 默认 0 → 无减伤
	d.party = [m, null, null, null]
	d.start_battle(_enemy(1000.0, 50.0, 1.0))
	d.tick_combat()
	assert_float(d.party[0].current_hp).is_equal(50.0)  # 100 - 50

# ── 护甲(递减减伤 armor/(armor+K))────────────────────────────────────────

func test_armor_equal_to_k_halves_incoming_damage() -> void:
	var d := _director()
	d.tick_seconds = 1.0
	d.armor_k = 50.0
	var m := _member(1000.0, 1.0)
	m.armor = 50.0  # = armor_k → 减伤恰 50%
	d.party = [m, null, null, null]
	d.start_battle(_enemy(1000.0, 100.0, 1.0))
	d.tick_combat()
	assert_float(d.party[0].current_hp).is_equal(950.0)  # 1000 - 100×0.5

func test_zero_armor_takes_full_damage() -> void:
	var d := _director()
	d.tick_seconds = 1.0
	d.armor_k = 50.0
	var m := _member(1000.0, 1.0)
	m.armor = 0.0
	d.party = [m, null, null, null]
	d.start_battle(_enemy(1000.0, 100.0, 1.0))
	d.tick_combat()
	assert_float(d.party[0].current_hp).is_equal(900.0)  # 1000 - 100

# ── 每秒回血(场内即时,封顶满血)──────────────────────────────────────────

func test_hp_regen_heals_each_tick() -> void:
	var d := _director()
	d.tick_seconds = 0.1
	var m := _member(100.0, 0.0)   # 不进攻
	m.attack_speed = 0.0
	m.hp_regen = 5.0
	m.current_hp = 50.0            # 先受过伤
	d.party = [m, null, null, null]
	d.start_battle(_enemy(1000.0, 0.0, 0.0))  # 敌不还手
	d.tick_combat()
	assert_float(d.party[0].current_hp).is_equal(50.5)  # +5 × 0.1

func test_hp_regen_capped_at_max_hp() -> void:
	var d := _director()
	d.tick_seconds = 0.1
	var m := _member(100.0, 0.0)
	m.attack_speed = 0.0
	m.hp_regen = 5.0
	m.current_hp = 99.9
	d.party = [m, null, null, null]
	d.start_battle(_enemy(1000.0, 0.0, 0.0))
	d.tick_combat()
	assert_float(d.party[0].current_hp).is_equal(100.0)  # 封顶,不溢出

# ── 攻速 → 出手频率(容差断言,勿精确逐 tick)──────────────────────────────

func test_attack_speed_governs_hit_frequency() -> void:
	var d := _director()
	d.tick_seconds = 0.1
	var m := _member(1000.0, 1.0)
	m.attack_speed = 1.0  # ≈ 每 10 tick 一次
	d.party = [m, null, null, null]
	var hits := [0]
	d.hit_dealt.connect(func(_a, _c): hits[0] += 1)
	d.start_battle(_enemy(1.0e9, 0.0, 0.0))  # 巨血,百 tick 内死不了
	for i in 100:
		d.tick_combat()
	assert_int(hits[0]).is_between(8, 12)  # ~10 次,留浮点容差(Flag-C)

func test_double_attack_speed_roughly_doubles_hits() -> void:
	var d := _director()
	d.tick_seconds = 0.1
	var m := _member(1000.0, 1.0)
	m.attack_speed = 2.0  # ≈ 每 5 tick 一次
	d.party = [m, null, null, null]
	var hits := [0]
	d.hit_dealt.connect(func(_a, _c): hits[0] += 1)
	d.start_battle(_enemy(1.0e9, 0.0, 0.0))
	for i in 100:
		d.tick_combat()
	assert_int(hits[0]).is_between(17, 23)  # ~20 次

# ── 软狂暴 ──────────────────────────────────────────────────────────────────

func test_soft_enrage_triggers_once_after_threshold() -> void:
	var d := _director()
	d.tick_seconds = 0.1
	d.enrage_threshold_sec = 0.5
	var m := _member(1.0e9, 0.0)  # 不进攻、不死
	m.attack_speed = 0.0
	d.party = [m, null, null, null]
	var enrage_count := [0]
	d.enemy_enraged.connect(func(): enrage_count[0] += 1)
	d.start_battle(_enemy(1.0e9, 10.0, 0.0))  # 巨血敌不死(攻速 0 不还手,只测计时)
	for i in 4:
		d.tick_combat()          # fight_time → 0.4 < 0.5
	assert_bool(d.enraged).is_false()
	assert_int(enrage_count[0]).is_equal(0)
	d.tick_combat()              # fight_time → 0.5 ≥ 阈值
	assert_bool(d.enraged).is_true()
	assert_int(enrage_count[0]).is_equal(1)
	for i in 20:
		d.tick_combat()          # 继续缠斗
	assert_int(enrage_count[0]).is_equal(1)  # 每场最多发一次

func test_enrage_amplifies_enemy_damage() -> void:
	var d := _director()
	d.tick_seconds = 0.1
	d.enrage_threshold_sec = 0.5
	d.enrage_ramp_per_sec = 0.5
	var m := _member(1.0e9, 0.0)
	m.attack_speed = 0.0
	d.party = [m, null, null, null]
	d.start_battle(_enemy(1.0e9, 10.0, 10.0))  # 敌攻速 10 → 每 tick 出手一次
	var hp0 := d.party[0].current_hp
	d.tick_combat()                            # tick1:未狂暴,单次伤害 = 10
	var loss_pre := hp0 - d.party[0].current_hp
	for i in 20:
		d.tick_combat()                        # 越过阈值,狂暴倍率随时长增大
	var hp_before := d.party[0].current_hp
	d.tick_combat()
	var loss_post := hp_before - d.party[0].current_hp
	assert_bool(d.enraged).is_true()
	assert_float(loss_pre).is_equal(10.0)
	assert_float(loss_post).is_greater(loss_pre)  # 狂暴后单次伤害更高

func test_start_battle_resets_enrage_state() -> void:
	var d := _director()
	d.tick_seconds = 0.1
	d.enrage_threshold_sec = 0.5
	var m := _member(1.0e9, 0.0)
	m.attack_speed = 0.0
	d.party = [m, null, null, null]
	d.start_battle(_enemy(1.0e9, 10.0, 0.0))
	for i in 10:
		d.tick_combat()
	assert_bool(d.enraged).is_true()
	d.start_battle(_enemy(1.0e9, 10.0, 0.0))  # 新敌人
	assert_bool(d.enraged).is_false()
	assert_float(d._enemy_fight_time).is_equal(0.0)
