extends GdUnitTestSuite
## PLAN step 3 验证:每次击杀恰发 0/1 次 loot_dropped、kind/rarity 取值合法、
## 注入种子后掉落分布落在预期区间(PLAN D7 / D10)。

func _enemy(drop_chance: float, w_gold: float, w_mat: float, w_equip: float) -> EnemyDef:
	var e := EnemyDef.new()
	e.max_hp = 1.0
	e.attack = 0.0
	e.drop_chance = drop_chance
	e.weight_gold = w_gold
	e.weight_material = w_mat
	e.weight_equipment = w_equip
	return e

func _director_with_seed(seed_value: int) -> CombatDirector:
	var d: CombatDirector = auto_free(CombatDirector.new())
	d.party = [PartyMember.new("战士", 100.0, 10.0), null, null, null]
	d.rng.seed = seed_value
	return d

func test_no_drop_when_chance_zero() -> void:
	var d := _director_with_seed(1)
	var events := [0]
	d.loot_dropped.connect(func(_k, _r): events[0] += 1)
	for i in 200:
		d.start_battle(_enemy(0.0, 70.0, 22.0, 8.0))
		d.tick_combat()  # 1 攻即杀(怪 1 血)
	assert_int(events[0]).is_equal(0)

func test_always_drops_when_chance_one() -> void:
	var d := _director_with_seed(2)
	var events := [0]
	d.loot_dropped.connect(func(_k, _r): events[0] += 1)
	var kills := 50
	for i in kills:
		d.start_battle(_enemy(1.0, 70.0, 22.0, 8.0))
		d.tick_combat()
	assert_int(events[0]).is_equal(kills)  # 每次击杀恰发一次

func test_kind_and_rarity_values_are_valid() -> void:
	var d := _director_with_seed(3)
	var valid_kinds := ["gold", "material", "equipment"]
	var valid_rarities := ["white", "blue", "gold"]
	var seen := {"kind_ok": true, "rarity_ok": true}
	d.loot_dropped.connect(func(k, r):
		if not valid_kinds.has(String(k)):
			seen["kind_ok"] = false
		if not valid_rarities.has(String(r)):
			seen["rarity_ok"] = false
	)
	for i in 300:
		d.start_battle(_enemy(1.0, 50.0, 30.0, 20.0))
		d.tick_combat()
	assert_bool(seen["kind_ok"]).is_true()
	assert_bool(seen["rarity_ok"]).is_true()

func test_gold_kind_always_white_rarity() -> void:
	# 只有金币种类 → 任何掉落必为 white(金币一律记白,PLAN D7)。
	var d := _director_with_seed(4)
	var all_white := [true]
	d.loot_dropped.connect(func(k, r):
		if String(k) == "gold" and String(r) != "white":
			all_white[0] = false
	)
	for i in 200:
		d.start_battle(_enemy(1.0, 100.0, 0.0, 0.0))
		d.tick_combat()
	assert_bool(all_white[0]).is_true()

func test_drop_distribution_in_expected_range() -> void:
	# drop_chance=0.5,固定种子,1000 次击杀:掉落次数应落在 ~500 附近的宽区间。
	var d := _director_with_seed(12345)
	var events := [0]
	d.loot_dropped.connect(func(_k, _r): events[0] += 1)
	var kills := 1000
	for i in kills:
		d.start_battle(_enemy(0.5, 70.0, 22.0, 8.0))
		d.tick_combat()
	assert_int(events[0]).is_between(420, 580)
