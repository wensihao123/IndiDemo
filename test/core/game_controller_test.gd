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

# F-SaveBoss 回归:两关速通(每关 1 无害场景 + 1血 Boss),验通关后续战不回 boss。
func _two_quick_stages() -> Array[StageConfig]:
	var out: Array[StageConfig] = []
	for nm in ["一关", "二关"]:
		var st := StageConfig.new()
		st.stage_name = nm
		st.scenes = [_scene(_enemy(1.0, 0.0), 1)] as Array[SceneConfig]
		st.boss = _enemy(1.0, 0.0)
		out.append(st)
	return out

# F-SaveBoss:打通第一关 Boss 后自动存档落在 boss 那格(cur_scene=3,游标待倒计时才推进),
# 重 boot 续战须据 max_unlocked 判别"已通"→ 续到第二关开头,而非重打 boss。
func test_reboot_after_boss_resumes_past_boss_not_refight() -> void:
	var gc := _booted_gc()
	gc.player_state.roster = [_hero()] as Array[Character]
	gc.begin_run(_two_quick_stages())
	gc.arena.tick_combat()  # 杀场景0 → Boss
	gc.arena.tick_combat()  # 杀第一关 Boss → max_unlocked=1,自动存档(cur 仍 = (0, BOSS))
	assert_int(gc.progression.cur_scene).is_equal(ProgressionController.BOSS_SCENE)  # 存档瞬态确在 boss 格
	# 重 boot 读同档 + 开局 → 续到第二关开头,不回 boss
	var gc2 := _booted_gc(true)
	gc2.begin_run(_two_quick_stages())
	assert_int(gc2.progression.cur_stage).is_equal(1)
	assert_int(gc2.progression.cur_scene).is_equal(0)
	assert_object(gc2.progression.current_enemy_def()).is_not_null()  # 第二关场景0 有怪,非 boss/空

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

# ── 09-title-main-menu PLAN 步1:has_save / new_game 接缝 ─────────────────────

# 无存档 boot → has_save = false(供主菜单默认态守卫)。
func test_boot_without_save_sets_has_save_false() -> void:
	var gc := _booted_gc(false)
	assert_bool(gc.has_save).is_false()

# new_game:重置起始 roster + 从 0,0 开局 + 落盘;has_save 转 true。
func test_new_game_resets_begins_and_saves() -> void:
	var gc := _booted_gc(false)
	# 先弄脏持久态:塞个非起始角色,验 new_game 会重置回起始 roster。
	gc.player_state.roster = [_hero()] as Array[Character]
	gc.new_game(_quick_stages())
	assert_bool(gc.player_state.roster.is_empty()).is_false()        # 起始 roster 已填
	assert_int(gc.progression.cur_stage).is_equal(0)                 # 从头开局
	assert_int(gc.progression.cur_scene).is_equal(0)
	assert_object(gc.arena.players[0]).is_not_null()                # 队伍就位
	assert_bool(gc.has_save).is_true()
	assert_bool(FileAccess.file_exists(TMP_PATH)).is_true()          # 已覆盖落盘

# new_game 落盘后,重 boot 读档 → has_save = true(存在非空档)。
func test_reboot_after_new_game_sees_save() -> void:
	var gc := _booted_gc(false)
	gc.new_game(_quick_stages())
	var gc2 := _booted_gc(true)
	assert_bool(gc2.has_save).is_true()


# ── PLAN 步5a:进/出城 暂停-恢复(05-town) ───────────────────────────────────

# 进城暂停:停 arena.running + 把战斗中自动穿的装备收口写回 roster(城镇可见)。
func test_pause_run_freezes_and_syncs_equipment() -> void:
	var gc := _booted_gc()
	gc.player_state.roster = [_hero()] as Array[Character]
	gc.begin_run(_quick_stages())
	var weapon := ItemInstance.new(GameKeys.SLOT_WEAPON, 5, GameKeys.RARITY_GOLD)
	gc.arena.players[0].equipment.equip(GameKeys.SLOT_WEAPON, weapon)
	assert_bool(gc.player_state.roster[0].equipped.has(GameKeys.SLOT_WEAPON)).is_false()
	gc.pause_run()
	assert_bool(gc.arena.running).is_false()
	assert_bool(gc.player_state.roster[0].equipped.has(GameKeys.SLOT_WEAPON)).is_true()  # 已收口

# 出城恢复:re-snapshot 吃下城镇换装/强化,且不免费回血(沿用暂停时 HP 夹新 max)。
func test_resume_run_resnapshots_and_preserves_hp() -> void:
	var gc := _booted_gc()
	gc.player_state.roster = [_hero()] as Array[Character]
	gc.begin_run(_quick_stages())
	# 模拟战斗损血
	gc.arena.players[0].current_hp = 300.0
	gc.pause_run()
	# 城镇强化:战士武器主轴 +,不改 max_hp → resume 后血量应保持 300(不回满 1000)。
	gc.resume_run()
	assert_bool(gc.arena.running).is_true()
	assert_float(gc.arena.players[0].current_hp).is_equal(300.0)  # 守 i5 不免费回血

# 出城再快照吃下城镇换装:暂停后给 roster 角色换上新武器,resume 后活体带上它。
func test_resume_run_picks_up_town_equipment_change() -> void:
	var gc := _booted_gc()
	gc.player_state.roster = [_hero()] as Array[Character]
	gc.begin_run(_quick_stages())
	gc.pause_run()
	# 城镇把武器穿到持久 Character(party_characters[0] 与 roster[0] 同对象)
	gc.party_characters[0].equipped[GameKeys.SLOT_WEAPON] = ItemInstance.new(GameKeys.SLOT_WEAPON, 7, GameKeys.RARITY_GOLD)
	gc.resume_run()
	var equipped: ItemInstance = gc.arena.players[0].equipment.get_equipped(GameKeys.SLOT_WEAPON)
	assert_object(equipped).is_not_null()
	assert_int(equipped.ilvl).is_equal(7)

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
