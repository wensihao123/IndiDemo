extends GdUnitTestSuite
## PLAN step 6 验证:通关倒计时自动推进 / 修整取消推进、卡关推进+修整在本轮结束执行(PLAN D6)。

func _enemy(hp: float, atk: float) -> EnemyDef:
	var e := EnemyDef.new()
	e.max_hp = hp
	e.attack = atk
	e.drop_chance = 0.0
	return e

func _scene(enemy: EnemyDef, kills: int) -> SceneConfig:
	var s := SceneConfig.new()
	s.enemy = enemy
	s.kill_count = kills
	return s

# 一关:1 个无害场景(1血/atk0)+ 1血 Boss → 强战士两 tick 通关到倒计时。
func _quick_clear_stages() -> Array[StageConfig]:
	var st := StageConfig.new()
	st.stage_name = "速通关"
	var arr: Array[SceneConfig] = [_scene(_enemy(1.0, 0.0), 1)]
	st.scenes = arr
	st.boss = _enemy(1.0, 0.0)
	var st2 := StageConfig.new()
	st2.stage_name = "第二关"
	st2.scenes = [_scene(_enemy(1.0, 0.0), 1)] as Array[SceneConfig]
	st2.boss = _enemy(1.0, 0.0)
	var stages: Array[StageConfig] = [st, st2]
	return stages

func _strong_director() -> CombatDirector:
	var d: CombatDirector = auto_free(CombatDirector.new())
	d.party = [PartyMember.new("战士", 1000.0, 100.0), null, null, null]
	return d

# 混合关:scene0 无害可杀、scene1 致命 → 用于制造 GRINDING 态。
func _grind_director() -> CombatDirector:
	var d: CombatDirector = auto_free(CombatDirector.new())
	d.party = [PartyMember.new("脆皮", 5.0, 1.0), null, null, null]
	return d

func _mixed_stages() -> Array[StageConfig]:
	var st := StageConfig.new()
	st.stage_name = "混合关"
	var arr: Array[SceneConfig] = [
		_scene(_enemy(1.0, 0.0), 5),      # scene0 无害,1 击可杀
		_scene(_enemy(1000.0, 100.0), 5), # scene1 致命
		_scene(_enemy(1.0, 0.0), 5),
	]
	st.scenes = arr
	st.boss = _enemy(1000.0, 100.0)
	var stages: Array[StageConfig] = [st]
	return stages

func test_countdown_auto_advances_when_no_action() -> void:
	var d := _strong_director()
	d.begin_run(_quick_clear_stages())
	d.tick_combat()  # 杀场景0 → Boss
	d.tick_combat()  # 杀 Boss → 倒计时
	assert_int(d.mode).is_equal(CombatDirector.Mode.STAGE_CLEAR_COUNTDOWN)
	d.process_countdown(d.stage_clear_countdown_sec * 0.5)
	assert_int(d.mode).is_equal(CombatDirector.Mode.STAGE_CLEAR_COUNTDOWN)  # 未到点
	assert_int(d.cur_stage).is_equal(0)
	d.process_countdown(d.stage_clear_countdown_sec)  # 越过 0
	assert_int(d.mode).is_equal(CombatDirector.Mode.PROGRESSING)
	assert_int(d.cur_stage).is_equal(1)
	assert_int(d.cur_scene).is_equal(0)

func test_rest_during_countdown_cancels_auto_advance() -> void:
	var d := _strong_director()
	var rested := [0]
	d.rest_requested.connect(func(): rested[0] += 1)
	d.begin_run(_quick_clear_stages())
	d.tick_combat()
	d.tick_combat()  # → 倒计时
	d.request_rest()
	assert_int(rested[0]).is_equal(1)
	assert_int(d.mode).is_equal(CombatDirector.Mode.RESTING)
	assert_int(d.cur_stage).is_equal(0)  # 未推进
	d.process_countdown(d.stage_clear_countdown_sec + 5.0)  # 不应再自动推进
	assert_int(d.cur_stage).is_equal(0)
	assert_int(d.mode).is_equal(CombatDirector.Mode.RESTING)

func test_push_executes_at_round_end_while_grinding() -> void:
	var d := _grind_director()
	d.begin_run(_mixed_stages(), 0, 1)  # 卡致命 scene1
	d.tick_combat()                      # 团灭 → 退到 (0,0) GRINDING
	assert_int(d.mode).is_equal(CombatDirector.Mode.GRINDING)
	d.request_push()
	assert_int(d.cur_scene).is_equal(0)  # 入队但本轮未结束 → 还没推进
	d.tick_combat()                      # 杀掉 scene0 怪 = 本轮结束 → 执行推进
	assert_int(d.mode).is_equal(CombatDirector.Mode.PROGRESSING)
	assert_int(d.cur_stage).is_equal(0)
	assert_int(d.cur_scene).is_equal(1)  # 推进回原卡关点

func test_rest_executes_at_round_end_while_grinding() -> void:
	var d := _grind_director()
	var rested := [0]
	d.rest_requested.connect(func(): rested[0] += 1)
	d.begin_run(_mixed_stages(), 0, 1)
	d.tick_combat()  # 团灭 → GRINDING (0,0)
	d.request_rest()
	assert_int(rested[0]).is_equal(0)    # 本轮未结束,尚未触发
	d.tick_combat()  # 杀 scene0 怪 = 本轮结束 → 修整
	assert_int(rested[0]).is_equal(1)
	assert_int(d.mode).is_equal(CombatDirector.Mode.RESTING)
	assert_bool(d.has_living_enemy()).is_false()  # 停刷怪
