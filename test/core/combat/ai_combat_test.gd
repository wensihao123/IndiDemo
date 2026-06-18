extends GdUnitTestSuite
## PLAN 步 5c 验证:AICombatComponent 选最前存活 + 占位射程。

func _enemy(hp: float) -> Entity:
	var def := EnemyDef.new()
	def.max_hp = hp
	return auto_free(Entity.from_enemy_def(def))

func test_selects_front_most_living() -> void:
	var ai := AICombatComponent.new()
	var a := _enemy(10.0)
	var b := _enemy(10.0)
	var targets: Array = [a, b]
	assert_object(ai.select_target(null, targets)).is_same(a)

func test_skips_dead_returns_next_living() -> void:
	var ai := AICombatComponent.new()
	var dead := _enemy(10.0)
	dead.take_damage(999.0)
	var alive := _enemy(10.0)
	var targets: Array = [dead, alive]
	assert_object(ai.select_target(null, targets)).is_same(alive)

func test_all_dead_returns_null() -> void:
	var ai := AICombatComponent.new()
	var d1 := _enemy(10.0); d1.take_damage(999.0)
	var d2 := _enemy(10.0); d2.take_damage(999.0)
	var targets: Array = [d1, d2]
	assert_object(ai.select_target(null, targets)).is_null()

func test_in_range_is_placeholder_true() -> void:
	var ai := AICombatComponent.new()
	assert_bool(ai.in_range(null, _enemy(10.0))).is_true()
