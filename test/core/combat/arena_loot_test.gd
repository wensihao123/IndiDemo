extends GdUnitTestSuite
## PLAN 步 5e 验证:敌死 → PoE 掉落流水线(ilvl 来自 EnemyDef.item_level)→ 入 PlayerState;F7 顺序。

const MAX_HP := GameKeys.STAT_MAX_HP
const ATTACK := GameKeys.STAT_ATTACK
const ASPD := GameKeys.STAT_ATTACK_SPEED

func _registry() -> DataRegistry:
	var bases := {
		"weapon": {"slot": "weapon", "signature_mode": "all", "signature_axes": ["attack"],
			"base_curves": {"attack": {"base": 3.0, "per_ilvl": 0.5}}},
		"armor": {"slot": "armor", "signature_mode": "all", "signature_axes": ["max_hp"],
			"base_curves": {"max_hp": {"base": 10.0, "per_ilvl": 2.0}}},
		"accessory": {"slot": "accessory", "signature_mode": "pick_one", "signature_axes": ["dodge_chance"],
			"base_curves": {"dodge_chance": {"base": 0.01, "per_ilvl": 0.0}}},
	}
	var affixes := [
		{"stat": "attack", "kind": "flat", "slot_pool": ["weapon"],
			"tiers": [{"tier": 1, "min": 1.0, "max": 3.0, "ilvl_req": 1, "weight": 1.0}]},
	]
	var table := {"rarity_affix_count": {"white": [0, 0], "blue": [1, 2], "gold": [3, 4]},
		"decompose_threshold": "white", "material_per_decompose": 1}
	var r := DataRegistry.new()
	r.ingest(bases, affixes, table)
	return r

func _hero(r: DataRegistry) -> Entity:
	var c := Character.new(&"战士", &"warrior")
	c.base_stats = {MAX_HP: 1000.0, ATTACK: 100.0, ASPD: 1.0}
	return auto_free(Entity.from_character(c, r))

func _arena_with_loot(r: DataRegistry, ps: PlayerState, hero: Entity) -> CombatArena:
	var a: CombatArena = auto_free(CombatArena.new())
	a.tuning = CombatTuning.new()
	a.tuning.tick_seconds = 1.0
	a.rng.seed = 11
	a.registry = r
	a.player_state = ps
	a.loot_equipment = hero.equipment
	var party: Array[Entity] = [hero]
	a.players = party
	return a

func _enemy(hp: float, ilvl: int) -> Entity:
	var def := EnemyDef.new()
	def.max_hp = hp
	def.attack = 0.0
	def.attack_speed = 0.0
	def.drop_chance = 1.0          # 必掉,去随机
	def.item_level = ilvl
	return auto_free(Entity.from_enemy_def(def))

func _enemy_rarity(hp: float, ilvl: int, w: float, b: float, g: float) -> Entity:
	var def := EnemyDef.new()
	def.max_hp = hp
	def.attack = 0.0
	def.attack_speed = 0.0
	def.drop_chance = 1.0
	def.item_level = ilvl
	def.rarity_weight_white = w
	def.rarity_weight_blue = b
	def.rarity_weight_gold = g
	return auto_free(Entity.from_enemy_def(def))

func test_rarity_follows_enemy_weights_all_white() -> void:
	# 权重 100/0/0 → 任何 seed 都只能出白。
	for s in [1, 2, 7, 99]:
		var r := _registry()
		var ps: PlayerState = auto_free(PlayerState.new())
		var a := _arena_with_loot(r, ps, _hero(r))
		a.rng.seed = s
		var dropped := [null]
		a.item_dropped.connect(func(inst, _d): dropped[0] = inst)
		var es: Array[Entity] = [_enemy_rarity(50.0, 5, 100.0, 0.0, 0.0)]
		a.start_battle(es)
		a.tick_combat()
		assert_str((dropped[0] as ItemInstance).rarity).is_equal(GameKeys.RARITY_WHITE)

func test_rarity_follows_enemy_weights_all_gold() -> void:
	# 权重 0/0/100 → 任何 seed 都只能出金。
	for s in [1, 2, 7, 99]:
		var r := _registry()
		var ps: PlayerState = auto_free(PlayerState.new())
		var a := _arena_with_loot(r, ps, _hero(r))
		a.rng.seed = s
		var dropped := [null]
		a.item_dropped.connect(func(inst, _d): dropped[0] = inst)
		var es: Array[Entity] = [_enemy_rarity(50.0, 5, 0.0, 0.0, 100.0)]
		a.start_battle(es)
		a.tick_combat()
		assert_str((dropped[0] as ItemInstance).rarity).is_equal(GameKeys.RARITY_GOLD)

func test_enemy_death_drops_item_with_enemy_item_level_into_player_state() -> void:
	var r := _registry()
	var ps: PlayerState = auto_free(PlayerState.new())
	var hero := _hero(r)
	var a := _arena_with_loot(r, ps, hero)
	var dropped := [null, &""]
	a.item_dropped.connect(func(inst, dest): dropped[0] = inst; dropped[1] = dest)
	var es: Array[Entity] = [_enemy(50.0, 7)]
	a.start_battle(es)
	a.tick_combat()                # 战士 atk100 秒杀 50 血怪 → 掉落
	var inst: ItemInstance = dropped[0]
	assert_object(inst).is_not_null()
	assert_int(inst.ilvl).is_equal(7)                          # ilvl 来自 EnemyDef.item_level
	assert_array(GameKeys.SLOTS).contains([inst.base_id])      # 合法槽位
	# 战士三槽初始皆空 → 填空优先 → 该件穿上(EQUIPPED)。
	assert_str(dropped[1]).is_equal(LootIntake.EQUIPPED)
	assert_bool(hero.equipment.is_slot_empty(inst.base_id)).is_false()

func test_defeat_and_drop_fire_from_same_kill_in_order() -> void:
	# F7:拆成 Arena(enemy_defeated)+ 掉落接线后,二者须由同一次敌死按序触发。
	var r := _registry()
	var ps: PlayerState = auto_free(PlayerState.new())
	var a := _arena_with_loot(r, ps, _hero(r))
	var seq: Array[StringName] = []
	a.enemy_defeated.connect(func(_e): seq.append(&"defeated"))
	a.item_dropped.connect(func(_i, _d): seq.append(&"dropped"))
	var es: Array[Entity] = [_enemy(50.0, 3)]
	a.start_battle(es)
	a.tick_combat()
	assert_array(seq).is_equal([&"defeated", &"dropped"])

func test_no_drop_when_pipeline_not_wired() -> void:
	# 5d 纯解算:registry/player_state/loot_equipment 未注 → 不掉落、不崩(保独立可测)。
	var a: CombatArena = auto_free(CombatArena.new())
	a.tuning = CombatTuning.new()
	a.tuning.tick_seconds = 1.0
	var party: Array[Entity] = [_player_atk()]
	a.players = party
	var fired := [0]
	a.item_dropped.connect(func(_i, _d): fired[0] += 1)
	var es: Array[Entity] = [_enemy(10.0, 5)]
	a.start_battle(es)
	a.tick_combat()
	assert_int(fired[0]).is_equal(0)

func _player_atk() -> Entity:
	var e: Entity = auto_free(Entity.new(Entity.Team.PLAYER))
	var s := StatsComponent.new()
	s.set_base(MAX_HP, 1000.0)
	s.set_base(ATTACK, 100.0)
	s.set_base(ASPD, 1.0)
	e.stats = s
	e.current_hp = 1000.0
	return e
