extends GdUnitTestSuite
## PLAN 步3 验证:GameController 装配 + 驱动 + 存档闭环(层8 接线 D1)。
## ① begin_run 后队伍/敌人就位;② tick → 敌死、进度推进;③ Boss 通关→自动存档落盘;④ 重 boot 读档恢复。

const TMP_PATH := "user://test_gc_save.json"
const MAX_HP := GameKeys.STAT_MAX_HP
const ATTACK := GameKeys.STAT_ATTACK
const ASPD := GameKeys.STAT_ATTACK_SPEED

func after_test() -> void:
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))

func _enemy(hp: float, atk: float) -> EnemyDef:
	var e := EnemyDef.new()
	e.max_hp = hp
	e.attack = atk
	e.attack_speed = 1.0
	e.drop_chance = 0.0
	return e

func _scene(enemy: EnemyDef, kills: int) -> SceneConfig:
	var s := SceneConfig.new()
	s.enemy = enemy
	s.kill_count = kills
	return s

# 一关:1 个 1血无害场景 + 1血 Boss → 强战士两 tick 通关。
func _quick_stages() -> Array[StageConfig]:
	var st := StageConfig.new()
	st.stage_name = "速通关"
	st.scenes = [_scene(_enemy(1.0, 0.0), 1)] as Array[SceneConfig]
	st.boss = _enemy(1.0, 0.0)
	return [st] as Array[StageConfig]

func _hero() -> Character:
	var c := Character.new(&"warrior", &"warrior")
	c.display_name = "战士"
	c.base_stats = {ATTACK: 1000.0, MAX_HP: 1000.0, ASPD: 1.0}
	return c

# 以注入参数 boot(关自动 boot、关读档、用临时档路径),roster 注 1 个强战士。
func _booted_gc(load_save: bool = false) -> GameController:
	var gc: GameController = auto_free(GameController.new())
	gc.auto_boot = false
	gc.save_path = TMP_PATH
	add_child(gc)
	gc._boot(DataRegistry.DEFAULT_CONFIG_DIR, load_save)
	gc.arena.tuning.tick_seconds = 1.0  # 每 actor 每 tick 一击(攻速1×tick1),还原逐 tick 确定推进
	return gc

func test_begin_run_assembles_party_and_enemy() -> void:
	var gc := _booted_gc()
	gc.player_state.roster = [_hero()] as Array[Character]
	gc.begin_run(_quick_stages())
	assert_int(gc.arena.players.size()).is_equal(GameController.PARTY_SLOTS)  # 4 格
	assert_object(gc.arena.players[0]).is_not_null()
	assert_object(gc.arena.players[1]).is_null()                              # 空位 null 容错
	assert_object(gc.progression.current_enemy_def()).is_not_null()
	assert_str(gc.party_characters[0].display_name).is_equal("战士")

func test_tick_advances_progression() -> void:
	var gc := _booted_gc()
	gc.player_state.roster = [_hero()] as Array[Character]
	gc.begin_run(_quick_stages())
	assert_int(gc.progression.cur_scene).is_equal(0)
	gc.arena.tick_combat()  # 杀场景0 → 推进到 Boss
	assert_int(gc.progression.cur_scene).is_equal(ProgressionController.BOSS_SCENE)

func test_boss_clear_autosaves() -> void:
	var gc := _booted_gc()
	gc.player_state.roster = [_hero()] as Array[Character]
	gc.begin_run(_quick_stages())
	gc.arena.tick_combat()  # → Boss
	gc.arena.tick_combat()  # 杀 Boss → boss_cleared → 自动存档
	assert_int(gc.progression.max_unlocked_stage).is_equal(1)
	var loaded := gc.save_system.load_file(TMP_PATH)
	assert_dict(loaded).is_not_empty()
	assert_int(int((loaded.get("progress", {}) as Dictionary).get("max_unlocked_stage", 0))).is_equal(1)

func test_reboot_restores_from_save() -> void:
	# 先跑一局通 Boss 落档
	var gc := _booted_gc()
	gc.player_state.roster = [_hero()] as Array[Character]
	gc.begin_run(_quick_stages())
	gc.arena.tick_combat()
	gc.arena.tick_combat()  # 落档 max_unlocked_stage=1
	# 新 GameController 读同一临时档 → roster/进度恢复
	var gc2 := _booted_gc(true)
	assert_int(gc2.player_state.roster.size()).is_equal(1)
	assert_str(gc2.player_state.roster[0].display_name).is_equal("战士")
	assert_int(gc2.progression.max_unlocked_stage).is_equal(1)

# S1(方案 B):战斗中自动穿到的装备须随存档收口进 roster,重 boot 不丢。
func test_auto_equipped_gear_persists_across_reboot() -> void:
	var gc := _booted_gc()
	gc.player_state.roster = [_hero()] as Array[Character]
	gc.begin_run(_quick_stages())
	# 模拟 LootIntake EQUIPPED 路径:把武器穿到当局活体 Entity(战士初始空武器槽)。
	var weapon := ItemInstance.new(GameKeys.SLOT_WEAPON, 5, GameKeys.RARITY_GOLD)
	gc.arena.players[0].equipment.equip(GameKeys.SLOT_WEAPON, weapon)
	assert_bool(gc.player_state.roster[0].equipped.has(GameKeys.SLOT_WEAPON)).is_false()  # 尚未落持久层
	gc.arena.tick_combat()  # → Boss
	gc.arena.tick_combat()  # 杀 Boss → 自动存档(先收口写回 roster 再落盘)
	var persisted: ItemInstance = gc.player_state.roster[0].equipped.get(GameKeys.SLOT_WEAPON)
	assert_object(persisted).is_not_null()
	assert_int(persisted.ilvl).is_equal(5)
	# 重 boot 读同档 → 武器仍在
	var gc2 := _booted_gc(true)
	var reloaded: ItemInstance = gc2.player_state.roster[0].equipped.get(GameKeys.SLOT_WEAPON)
	assert_object(reloaded).is_not_null()
	assert_str(String(reloaded.base_id)).is_equal(String(GameKeys.SLOT_WEAPON))
	assert_int(reloaded.ilvl).is_equal(5)

# S1 卸下边界:局内脱下的装备,收口须把 roster 对应槽清掉(不残留旧件)。
func test_unequipped_slot_clears_from_roster_on_save() -> void:
	var hero := _hero()
	hero.equipped[GameKeys.SLOT_WEAPON] = ItemInstance.new(GameKeys.SLOT_WEAPON, 3, GameKeys.RARITY_WHITE)
	var gc := _booted_gc()
	gc.player_state.roster = [hero] as Array[Character]
	gc.begin_run(_quick_stages())  # Entity 从 Character 带上该武器
	gc.arena.players[0].equipment.unequip(GameKeys.SLOT_WEAPON)  # 局内脱下
	gc.arena.tick_combat()
	gc.arena.tick_combat()  # 杀 Boss → 自动存档收口
	assert_bool(gc.player_state.roster[0].equipped.has(GameKeys.SLOT_WEAPON)).is_false()
	var gc2 := _booted_gc(true)
	assert_bool(gc2.player_state.roster[0].equipped.has(GameKeys.SLOT_WEAPON)).is_false()
