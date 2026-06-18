extends GdUnitTestSuite
## PLAN 步 5a 验证:Entity 工厂(from_character / from_enemy_def)+ current_hp 边界(层5)。

func _registry() -> DataRegistry:
	var bases := {
		"weapon": {"slot": "weapon", "signature_mode": "all", "signature_axes": ["attack"],
			"base_curves": {"attack": {"base": 3.0, "per_ilvl": 0.5}}},
	}
	var table := {"rarity_affix_count": {"white": [0, 0], "blue": [1, 2], "gold": [3, 4]},
		"decompose_threshold": "white"}
	var r := DataRegistry.new()
	r.ingest(bases, [], table)
	return r

func test_from_character_injects_base_and_equipment() -> void:
	var r := _registry()
	var c := Character.new(&"hero", &"warrior")
	c.base_stats = {GameKeys.STAT_ATTACK: 5.0, GameKeys.STAT_MAX_HP: 100.0}
	var w := ItemInstance.new(GameKeys.SLOT_WEAPON, 10, GameKeys.RARITY_BLUE)
	w.signature_axes = [GameKeys.STAT_ATTACK]                # ilvl10 招牌攻击 = 3 + 0.5×10 = 8
	w.affixes = [AffixRoll.new(GameKeys.STAT_ATTACK, GameKeys.KIND_FLAT, 1, 5.0)]
	c.equipped = {GameKeys.SLOT_WEAPON: w}
	var e: Entity = auto_free(Entity.from_character(c, r))
	assert_int(e.team).is_equal(Entity.Team.PLAYER)
	assert_float(e.stats.get_final(GameKeys.STAT_ATTACK)).is_equal(18.0)  # base5 + 招牌8 + flat5
	assert_float(e.max_hp()).is_equal(100.0)
	assert_float(e.current_hp).is_equal(100.0)               # 建出即满血

func test_from_enemy_def_reads_enemy_stats() -> void:
	var def := EnemyDef.new()
	def.max_hp = 250.0
	def.attack = 12.0
	def.attack_speed = 1.5
	var e: Entity = auto_free(Entity.from_enemy_def(def))
	assert_int(e.team).is_equal(Entity.Team.ENEMY)
	assert_float(e.max_hp()).is_equal(250.0)
	assert_float(e.stats.get_final(GameKeys.STAT_ATTACK)).is_equal(12.0)
	assert_float(e.stats.get_final(GameKeys.STAT_ATTACK_SPEED)).is_equal(1.5)
	assert_float(e.current_hp).is_equal(250.0)
	assert_object(e.source_enemy_def).is_same(def)

func test_take_damage_floors_at_zero() -> void:
	var def := EnemyDef.new()
	def.max_hp = 30.0
	var e: Entity = auto_free(Entity.from_enemy_def(def))
	e.take_damage(20.0)
	assert_float(e.current_hp).is_equal(10.0)
	assert_bool(e.is_alive()).is_true()
	e.take_damage(999.0)
	assert_float(e.current_hp).is_equal(0.0)                 # 不为负
	assert_bool(e.is_alive()).is_false()

func test_heal_caps_at_max_hp() -> void:
	var def := EnemyDef.new()
	def.max_hp = 100.0
	var e: Entity = auto_free(Entity.from_enemy_def(def))
	e.take_damage(60.0)                                      # → 40
	e.heal(5.0)
	assert_float(e.current_hp).is_equal(45.0)
	e.heal(999.0)
	assert_float(e.current_hp).is_equal(100.0)               # 封顶
