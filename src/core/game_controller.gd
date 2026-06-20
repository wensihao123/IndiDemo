extends Node
class_name GameController
## 装配座(PLAN D1):持有 per-run CombatArena+ProgressionController、DataRegistry,
## **读**全局持久根 PlayerState(/root/Player,不自持·REFACTOR-02);
## _ready 装配 + 从存档/默认 roster 建队 + 把 arena 挂进树(固定步长 tick 驱动战斗)。表现层只读它。
## Combat→Game autoload 切换留步 5(Engine Integrator);DataRegistry 由本类持有不单独注册(D4)。

const PARTY_SLOTS := 4

var registry: DataRegistry = null
var player_state: PlayerState = null
var arena: CombatArena = null
var progression: ProgressionController = null
var party_characters: Array[Character] = []
var save_system := SaveSystem.new()

var save_path := "user://savegame.json"
## 测试可置 false 跳过 _ready 自动 boot,改以注入参数手动调 _boot。
var auto_boot := true

## boot 时落定:存档文件是否存在且非空(供主菜单"继续 vs 新游戏"默认态守卫读)。new_game 后置 true。
var has_save := false

## 从存档恢复的续战游标(begin_run 不显式传 stage/scene 时用)。
var _resume_stage := 0
var _resume_scene := 0


func _ready() -> void:
	if auto_boot:
		_boot()


## 装配一局所需的所有系统(与 _ready 分离,便于测试注入 config_dir / 关存档)。
func _boot(config_dir: String = DataRegistry.DEFAULT_CONFIG_DIR, load_save: bool = true) -> void:
	registry = DataRegistry.new()
	if not registry.load_all(config_dir):
		push_error("DataRegistry 加载失败:%s" % "\n".join(registry.get_load_errors()))

	# 复用全局持久根(REFACTOR-02):不自持。reset-on-boot 清残留态(autoload 在测试进程内持久),
	# 再由下方 load 存档 / 默认 roster 填充——证存档文件而非内存残留驱动恢复。
	player_state = get_node("/root/Player") as PlayerState
	player_state.reset()

	arena = CombatArena.new()
	arena.tuning = CombatTuning.new()
	add_child(arena)
	arena.registry = registry
	arena.player_state = player_state

	progression = ProgressionController.new()
	progression.arena = arena
	progression.boss_cleared.connect(_on_boss_cleared)

	var save: Dictionary = {}
	if load_save:
		save = save_system.load_file(save_path)
	has_save = not save.is_empty()
	if not save.is_empty():
		save_system.apply(save, player_state, progression, registry)
	else:
		player_state.roster = registry.get_starting_roster()
	_resume_stage = progression.cur_stage
	_resume_scene = progression.cur_scene
	# boss 清算的自动存档落在 boss 那格(cur_scene 等通关倒计时后才推进 → 见 ProgressionController._execute_push),
	# 据已永久解锁判别"boss 已通"→ 续到下一关开头,免重开重打 boss;打一半就关时 max 未 +1(==cur_stage)→ 续回 boss。
	if _resume_scene == ProgressionController.BOSS_SCENE and progression.max_unlocked_stage > _resume_stage:
		_resume_stage = progression.max_unlocked_stage
		_resume_scene = 0


## 开一局:据 roster 建 4 格队伍(空位 null 容错)、注掉落填空目标、令 Progression 从续战游标开局。
## stage/scene < 0 → 取存档续战游标(新档为 0,0)。
func begin_run(stages: Array[StageConfig], stage: int = -1, scene: int = -1) -> void:
	var s := stage if stage >= 0 else _resume_stage
	var sc := scene if scene >= 0 else _resume_scene
	party_characters = _active_party()
	var ents: Array[Entity] = []
	for c in party_characters:
		if c != null:
			ents.append(Entity.from_character(c, registry))
		else:
			ents.append(null)
	arena.players = ents
	# 掉落填空目标 = 首个存活成员(v1 战士)的 EquipmentComponent(承第二批 Wiring Contract §4)。
	for e in ents:
		if e != null:
			arena.loot_equipment = e.equipment
			break
	progression.begin_run(stages, s, sc)


## 新游戏:覆盖单档(落盘即清旧档,无需 SaveSystem.delete)。清持久态 → 重置起始 roster → 从头开局 → 立即落盘。
## 破坏性动作,调用方(GameFlow)对有档玩家须先过覆盖确认。
func new_game(stages: Array[StageConfig]) -> void:
	player_state.reset()
	player_state.roster = registry.get_starting_roster()
	_resume_stage = 0
	_resume_scene = 0
	begin_run(stages, 0, 0)
	has_save = true
	_autosave()


## 退出游戏:autosave 后退进程(供退出确认用,不依赖 WM_CLOSE_REQUEST 通知一定触发)。
func quit_game() -> void:
	_autosave()
	get_tree().quit()


## 进城:冻结当前挂机,先把活体装备收口写回持久 roster(否则城镇看不到/会改丢战斗中自动穿的装备)。
## 不变量 #11:战斗外只写持久层。
func pause_run() -> void:
	if arena == null:
		return
	_sync_party_equipment()
	arena.running = false


## 出城:据持久 roster Character 重新快照玩家 Entity(吃下城镇里的换装/强化改动),
## 守 i5:沿用暂停时的 current_hp 夹到新 max_hp(装备变更后 max 可能变),不免费回血。
func resume_run() -> void:
	if arena == null:
		return
	var old := arena.players
	var ents: Array[Entity] = []
	for i in party_characters.size():
		var c := party_characters[i]
		if c == null:
			ents.append(null)
			continue
		var e := Entity.from_character(c, registry)
		var old_hp := e.max_hp()  # 无旧实体可参照时(防御)默认满,正常路径下被下面覆盖
		if i < old.size() and old[i] != null:
			old_hp = old[i].current_hp
		e.current_hp = clampf(old_hp, 0.0, e.max_hp())
		ents.append(e)
	arena.players = ents
	for e in ents:
		if e != null:
			arena.loot_equipment = e.equipment
			break
	arena.running = true


## roster 补齐到 PARTY_SLOTS 格(不足填 null,守 MVP 4 格空位容错)。
func _active_party() -> Array[Character]:
	var out: Array[Character] = []
	for i in PARTY_SLOTS:
		out.append(player_state.roster[i] if i < player_state.roster.size() else null)
	return out


func _on_boss_cleared(_stage: int) -> void:
	_autosave()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave()


func _autosave() -> void:
	if save_system != null and player_state != null and progression != null:
		_sync_party_equipment()
		save_system.save(player_state, progression, save_path)


## 存档前收口(方案 B):把每个活体 Entity 的装备态写回对应 roster Character,
## 使战斗中自动穿到的装备进入持久层(否则只 buff 战斗壳、重 boot 即丢)。
## party_characters[i] 与 arena.players[i] 同序配对;空位/无 arena 时跳过。
func _sync_party_equipment() -> void:
	if arena == null:
		return
	for i in party_characters.size():
		var c := party_characters[i]
		if c == null or i >= arena.players.size():
			continue
		var e := arena.players[i]
		if e != null:
			e.write_equipment_into(c)
