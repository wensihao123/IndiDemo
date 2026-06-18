extends GdUnitTestSuite
## PLAN step 2 验证:单场战斗解算 —— 敌人击败、成员倒下但队伍续战、全灭团灭。

func _member(p_name: String, hp: float, atk: float) -> PartyMember:
	return PartyMember.new(p_name, hp, atk)

func _enemy(hp: float, atk: float) -> EnemyDef:
	var e := EnemyDef.new()
	e.max_hp = hp
	e.attack = atk
	return e

func test_enemy_defeated_after_enough_ticks() -> void:
	var d: CombatDirector = auto_free(CombatDirector.new())
	# 攻速 1.0 × tick_seconds 1.0 = 每次 tick_combat() 恰每 actor 出手一次(整数,无浮点漂移),
	# 还原 02 "逐 tick 每 actor 一击" 的结构语义(PLAN Flag-C / Step 4)。
	d.tick_seconds = 1.0
	var p: Array[PartyMember] = [_member("战士", 100.0, 10.0), null, null, null]
	d.party = p
	var count := [0]
	d.enemy_defeated.connect(func(_e): count[0] += 1)
	d.start_battle(_enemy(25.0, 1.0))
	for i in 10:
		d.tick_combat()
	assert_int(count[0]).is_equal(1)
	assert_bool(d.has_living_enemy()).is_false()

func test_member_down_but_party_continues_when_one_alive() -> void:
	var d: CombatDirector = auto_free(CombatDirector.new())
	d.tick_seconds = 1.0  # 每 actor 每 tick 一击(见 Step 4 注释)
	var p: Array[PartyMember] = [_member("脆皮", 5.0, 2.0), _member("坦克", 200.0, 8.0), null, null]
	d.party = p
	var wiped := [false]
	d.party_wiped.connect(func(): wiped[0] = true)
	d.start_battle(_enemy(500.0, 10.0))  # 高血敌人,几 tick 内不会被击败
	for i in 3:
		d.tick_combat()
	assert_bool(d.party[0].is_alive()).is_false()  # 脆皮被击倒
	assert_bool(d.party[1].is_alive()).is_true()    # 坦克仍在
	assert_bool(d.has_living_member()).is_true()
	assert_bool(wiped[0]).is_false()                # ≥1 存活 → 不团灭

func test_party_wiped_when_all_down() -> void:
	var d: CombatDirector = auto_free(CombatDirector.new())
	d.tick_seconds = 1.0  # 每 actor 每 tick 一击(见 Step 4 注释)
	var p: Array[PartyMember] = [_member("战士", 12.0, 3.0), null, null, null]
	d.party = p
	var wiped := [0]
	var defeated := [0]
	d.party_wiped.connect(func(): wiped[0] += 1)
	d.enemy_defeated.connect(func(_e): defeated[0] += 1)
	d.start_battle(_enemy(500.0, 6.0))  # 敌人远强于唯一成员 → 必团灭
	for i in 10:
		d.tick_combat()
	assert_int(wiped[0]).is_equal(1)         # 团灭恰发一次
	assert_int(defeated[0]).is_equal(0)      # 敌人未被击败
	assert_bool(d.has_living_member()).is_false()

func test_init_default_party_fills_only_slot_0() -> void:
	var d: CombatDirector = auto_free(CombatDirector.new())
	d.init_default_party()
	assert_int(d.party.size()).is_equal(4)
	assert_object(d.party[0]).is_not_null()
	assert_object(d.party[1]).is_null()
	assert_bool(d.party[0].is_alive()).is_true()
