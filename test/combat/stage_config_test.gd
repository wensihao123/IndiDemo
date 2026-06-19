extends GdUnitTestSuite
## PLAN step 1 验证:两关配置 .tres 能加载、结构与字段正确(数值走 Resource 的回归网)。

const STAGE_01 := "res://assets/data/combat/stage_01.tres"
const STAGE_02 := "res://assets/data/combat/stage_02.tres"

func test_stage_01_loads_with_three_scenes_and_boss() -> void:
	var stage: StageConfig = load(STAGE_01)
	assert_object(stage).is_not_null()
	assert_str(stage.stage_name).is_equal("第一关")
	assert_int(stage.scenes.size()).is_equal(3)
	assert_object(stage.boss).is_not_null()
	assert_str(stage.boss.display_name).is_equal("哥布林王")

func test_stage_01_scenes_have_enemy_and_kill_count() -> void:
	var stage: StageConfig = load(STAGE_01)
	for scene in stage.scenes:
		assert_object(scene.enemy).is_not_null()
		assert_int(scene.kill_count).is_greater(0)
		assert_float(scene.enemy.max_hp).is_greater(0.0)
		assert_float(scene.enemy.attack).is_greater(0.0)

func test_difficulty_increases_across_scenes() -> void:
	var stage: StageConfig = load(STAGE_01)
	var prev_hp := 0.0
	for scene in stage.scenes:
		assert_float(scene.enemy.max_hp).is_greater(prev_hp)
		prev_hp = scene.enemy.max_hp

func test_stage_02_loads_and_scene1_harder_than_stage1_scene3() -> void:
	var s1: StageConfig = load(STAGE_01)
	var s2: StageConfig = load(STAGE_02)
	assert_object(s2).is_not_null()
	assert_int(s2.scenes.size()).is_equal(3)
	# 关2 第一场景调得比关1 第三场景硬,以便能触发卡关(PLAN §6 / step1)。
	assert_float(s2.scenes[0].enemy.max_hp).is_greater(s1.scenes[2].enemy.max_hp)

## 06 立墙锁值:关2 Boss 兽人酋长 = 一堵真墙(BALANCE-CHANGE-04)。锁住 hp480/atk24,防静默回退。
func test_stage_02_boss_is_the_wall() -> void:
	var s2: StageConfig = load(STAGE_02)
	assert_object(s2.boss).is_not_null()
	assert_str(s2.boss.display_name).is_equal("兽人酋长")
	assert_float(s2.boss.max_hp).is_equal(480.0)
	assert_float(s2.boss.attack).is_equal(24.0)

## BALANCE-CHANGE-05 锁波结构:关2 三普通场景 = 团战波(WAVE_SIZE 3、kill_count 6),
## Scene2/3 末位为远程;防静默回退到单敌或漏掉远程。
func test_stage_02_scenes_are_team_waves() -> void:
	var s2: StageConfig = load(STAGE_02)
	for scene in s2.scenes:
		assert_int(scene.wave_defs().size()).is_equal(3)
		assert_int(scene.kill_count).is_equal(6)
	# Scene1 纯近战(团战入门);Scene2/3 末位为远程(隔位漏血)。
	assert_int(s2.scenes[0].wave_defs()[2].position_class).is_equal(EnemyDef.PositionClass.MELEE)
	assert_int(s2.scenes[1].wave_defs()[2].position_class).is_equal(EnemyDef.PositionClass.RANGED)
	assert_int(s2.scenes[2].wave_defs()[2].position_class).is_equal(EnemyDef.PositionClass.RANGED)

func test_loot_fields_in_valid_range() -> void:
	for path in [STAGE_01, STAGE_02]:
		var stage: StageConfig = load(path)
		var defs: Array = []
		for scene in stage.scenes:
			defs.append(scene.enemy)
		defs.append(stage.boss)
		for d in defs:
			assert_float(d.drop_chance).is_between(0.0, 1.0)
			assert_float(d.weight_gold + d.weight_material + d.weight_equipment).is_greater(0.0)
			assert_float(d.rarity_weight_white + d.rarity_weight_blue + d.rarity_weight_gold).is_greater(0.0)
