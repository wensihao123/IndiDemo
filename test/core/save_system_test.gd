extends GdUnitTestSuite
## PLAN 步2 验证:SaveSystem round-trip(层7 持久落盘 D2)。
## ① PlayerState(roster+bag+材料)+ 三进度游标 save→load_file→apply 后逐一等值;② 读不存在档返回 {}。

const TMP_PATH := "user://test_save.json"

func _saver() -> SaveSystem:
	return SaveSystem.new()

func _sample_item() -> ItemInstance:
	var inst := ItemInstance.new(GameKeys.SLOT_WEAPON, 12, GameKeys.RARITY_GOLD)
	inst.signature_axes = [GameKeys.STAT_ATTACK]
	inst.affixes = [AffixRoll.new(GameKeys.STAT_ATTACK, GameKeys.KIND_PERCENT, 1, 0.2)]
	return inst

func after_test() -> void:
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))

func test_save_load_round_trip() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	var c := Character.new(&"warrior", &"warrior")
	c.display_name = "战士"
	c.base_stats = {GameKeys.STAT_ATTACK: 6.0, GameKeys.STAT_MAX_HP: 120.0}
	ps.roster.append(c)
	ps.add_to_bag(_sample_item())
	ps.add_material(GameKeys.SLOT_ARMOR, GameKeys.RARITY_WHITE, 3)
	var prog := ProgressionController.new()
	prog.max_unlocked_stage = 1
	prog.cur_stage = 1
	prog.cur_scene = 2

	var saver := _saver()
	assert_bool(saver.save(ps, prog, TMP_PATH)).is_true()

	var ps2: PlayerState = auto_free(PlayerState.new())
	var prog2 := ProgressionController.new()
	var loaded := saver.load_file(TMP_PATH)
	assert_dict(loaded).is_not_empty()
	saver.apply(loaded, ps2, prog2)

	# 持久数据等值(借 to_dict 全量对比 roster/bag/材料)
	assert_dict(ps2.to_dict()).is_equal(ps.to_dict())
	# 三进度游标等值
	assert_int(prog2.max_unlocked_stage).is_equal(1)
	assert_int(prog2.cur_stage).is_equal(1)
	assert_int(prog2.cur_scene).is_equal(2)

func test_load_nonexistent_returns_empty() -> void:
	var saver := _saver()
	assert_dict(saver.load_file("user://绝不存在的档.json")).is_empty()

func test_apply_empty_dict_is_noop() -> void:
	var ps: PlayerState = auto_free(PlayerState.new())
	var prog := ProgressionController.new()
	prog.cur_stage = 5
	_saver().apply({}, ps, prog)
	assert_int(prog.cur_stage).is_equal(5)  # 空档不动既有状态
	assert_int(ps.roster.size()).is_equal(0)
