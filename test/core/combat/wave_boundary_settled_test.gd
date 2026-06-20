extends GdUnitTestSuite
## 〔SC-02 / 10-ingame-flow-nav 步1〕wave_boundary_settled 信号回归:波清空推进 与 团灭回退
## 两条波界路径都发且只发一次(包裹法);无监听者时既有推进/回退逻辑不变(其余测套覆盖)。

const MAX_HP := GameKeys.STAT_MAX_HP
const ATTACK := GameKeys.STAT_ATTACK
const ASPD := GameKeys.STAT_ATTACK_SPEED

func _enemy(hp: float, atk: float) -> EnemyDef:
	var e := EnemyDef.new()
	e.max_hp = hp
	e.attack = atk
	e.attack_speed = 1.0
	e.drop_chance = 0.0
	return e

func _stage(kills: Array, boss_hp: float, scene_hp := 1.0, scene_atk := 0.0) -> StageConfig:
	var st := StageConfig.new()
	st.stage_name = "测试关"
	var arr: Array[SceneConfig] = []
	for k in kills:
		var sc := SceneConfig.new()
		sc.enemy = _enemy(scene_hp, scene_atk)
		sc.kill_count = k
		arr.append(sc)
	st.scenes = arr
	st.boss = _enemy(boss_hp, 0.0)
	return st

func _member(hp: float, atk: float) -> Entity:
	var e: Entity = auto_free(Entity.new(Entity.Team.PLAYER))
	var s := StatsComponent.new()
	s.set_base(MAX_HP, hp)
	s.set_base(ATTACK, atk)
	s.set_base(ASPD, 1.0)
	e.stats = s
	e.current_hp = hp
	return e

func _arena(hero: Entity) -> CombatArena:
	var a: CombatArena = auto_free(CombatArena.new())
	a.tuning = CombatTuning.new()
	a.tuning.tick_seconds = 1.0
	var party: Array[Entity] = [hero]
	a.players = party
	return a

func _prog(a: CombatArena) -> ProgressionController:
	var p := ProgressionController.new()
	p.arena = a
	return p

## 波清空推进:一波(1血怪)被清 → advance_after_wave → 信号发恰 1 次。
func test_wave_clear_emits_settled_once() -> void:
	var a := _arena(_member(1000.0, 100.0))
	var p := _prog(a)
	var count := [0]
	p.wave_boundary_settled.connect(func(): count[0] += 1)
	p.begin_run([_stage([1, 1, 1], 500.0)] as Array[StageConfig])
	a.tick_combat()  # 杀场景0一波 → 推进到场景1
	assert_int(count[0]).is_equal(1)
	assert_int(p.cur_scene).is_equal(1)  # 包裹未改变推进语义

## 团灭回退:脆皮被秒 → retreat_after_wipe → 信号发恰 1 次。
func test_wipe_emits_settled_once() -> void:
	var a := _arena(_member(5.0, 1.0))
	var p := _prog(a)
	var count := [0]
	p.wave_boundary_settled.connect(func(): count[0] += 1)
	# 怪 1000 血脆皮打不动、atk100 一击秒;卡在 (0,1) 团灭。
	var stages: Array[StageConfig] = [_stage([5, 5, 5], 1000.0, 1000.0, 100.0)]
	p.begin_run(stages, 0, 1)
	a.tick_combat()  # 团灭回退
	assert_int(count[0]).is_equal(1)
	assert_int(p.mode).is_equal(ProgressionController.Mode.GRINDING)
