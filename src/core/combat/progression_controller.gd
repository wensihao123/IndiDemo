extends RefCounted
class_name ProgressionController
## 跨场推进 FSM(承 combat_director 进度状态机 :242-396,逐条等值):场景游标 0→1→2→Boss、
## Boss 永久解锁、团灭回退四条、卡关 GRINDING、通关倒计时/修整。职责正交于 CombatArena:
## Arena 跑单场并在敌死/团灭时回调本类(advance_after_kill / retreat_after_wipe / process_countdown),
## 本类据进度配置令 Arena 开下一场(start_battle)。内部 new 敌实体(RefCounted,不留 orphan)。

## 场景游标:0/1/2 = 三个普通场景,3 = 关底 Boss(承 director BOSS_SCENE)。
const BOSS_SCENE := 3

## 进度模式(承 director Mode)。
enum Mode { PROGRESSING, GRINDING, STAGE_CLEAR_COUNTDOWN, RESTING }
## GRINDING 态下入队的宏观操作,在本轮结束(当前敌人死亡)执行(承 director QueuedAction)。
enum QueuedAction { NONE, PUSH, REST }

## 关底 Boss 被击杀:已永久解锁下一关。stage = 被通的那一关序号(承 director 信号)。
signal boss_cleared(stage: int)
## 玩家点"修整"离开本轮:v1 落 stub(承 director 信号)。
signal rest_requested

## 受控的单场编排器(begin_run 时回写 arena.progression = self)。
var arena: CombatArena = null

## 进度配置:本局可玩的关卡(顺序即关序)。
var stages: Array[StageConfig] = []
var cur_stage := 0
var cur_scene := 0
## 已解锁到的最高关序号;Boss 击杀永久前进,绝不回退。
var max_unlocked_stage := 0

var mode := Mode.PROGRESSING
## 团灭回退后"推进"按钮的目标落点;GRINDING 态点推进会跳到这里。
var advance_target_stage := 0
var advance_target_scene := 0
## STAGE_CLEAR_COUNTDOWN 态剩余秒数(供视图显示);<=0 即自动推进。
var countdown_remaining := 0.0

var _kills_this_scene := 0
var _queued := QueuedAction.NONE


## 接入关卡配置并从指定游标开局,回写 arena 反向引用并自动刷当前敌人(承 begin_run :245-253)。
func begin_run(p_stages: Array[StageConfig], stage := 0, scene := 0) -> void:
	stages = p_stages
	cur_stage = stage
	cur_scene = scene
	max_unlocked_stage = maxi(max_unlocked_stage, stage)
	_kills_this_scene = 0
	mode = Mode.PROGRESSING
	if arena != null:
		arena.progression = self
	_spawn_current()


## 当前游标对应的敌人(Boss 场景取关底 Boss);越界返回 null(承 current_enemy_def :257-265)。
func current_enemy_def() -> EnemyDef:
	if cur_stage < 0 or cur_stage >= stages.size():
		return null
	var st := stages[cur_stage]
	if cur_scene == BOSS_SCENE:
		return st.boss
	if cur_scene >= 0 and cur_scene < st.scenes.size():
		return st.scenes[cur_scene].enemy
	return null


## 据当前游标建敌实体并令 Arena 开场;def 为 null(越界/出关)→ 清空敌人(承 _spawn_current :268-269)。
func _spawn_current() -> void:
	if arena == null:
		return
	var def := current_enemy_def()
	if def == null:
		arena.enemies = []
		return
	var es: Array[Entity] = [Entity.from_enemy_def(def)]
	arena.start_battle(es)


## 一次击杀后推进(承 _advance_after_kill :273-314,逐条等值):
## GRINDING → 先执行入队推进/修整,否则计本场景击杀、满 kill_count 回满再刷;
## Boss → 永久解锁 + 进 5s 通关倒计时;普通场景 → 计数达标进下一场景(末场景→Boss),过场景回满。
func advance_after_kill() -> void:
	if mode == Mode.GRINDING:
		if _queued == QueuedAction.PUSH:
			_queued = QueuedAction.NONE
			_execute_push()
			return
		if _queued == QueuedAction.REST:
			_queued = QueuedAction.NONE
			_enter_rest()
			return
		_kills_this_scene += 1
		var gst := stages[cur_stage]
		var gneed: int = gst.scenes[cur_scene].kill_count if (cur_scene >= 0 and cur_scene < gst.scenes.size()) else 1
		if _kills_this_scene >= gneed:
			_kills_this_scene = 0
			_revive_party()
		_spawn_current()
		return
	if cur_scene == BOSS_SCENE:
		var beaten_stage := cur_stage
		max_unlocked_stage = maxi(max_unlocked_stage, beaten_stage + 1)
		boss_cleared.emit(beaten_stage)
		_revive_party()
		advance_target_stage = beaten_stage + 1
		advance_target_scene = 0
		mode = Mode.STAGE_CLEAR_COUNTDOWN
		countdown_remaining = _countdown_len()
		return
	_kills_this_scene += 1
	var st := stages[cur_stage]
	var need: int = st.scenes[cur_scene].kill_count if cur_scene < st.scenes.size() else 1
	if _kills_this_scene >= need:
		cur_scene = BOSS_SCENE if cur_scene + 1 >= st.scenes.size() else cur_scene + 1
		_kills_this_scene = 0
		_revive_party()
	_spawn_current()


## 团灭回退(承 _retreat_after_wipe :368-396,四条规则):算无尽刷落点 + 推进按钮目标,进 GRINDING,复活重刷。
func retreat_after_wipe() -> void:
	var s := cur_stage
	var i := cur_scene
	if i == BOSS_SCENE:
		cur_scene = _last_normal_scene(s)
		advance_target_stage = s
		advance_target_scene = BOSS_SCENE
	elif i >= 1:
		cur_scene = i - 1
		advance_target_stage = s
		advance_target_scene = i
	elif s > 0:
		cur_stage = s - 1
		cur_scene = _last_normal_scene(s - 1)
		advance_target_stage = s
		advance_target_scene = 0
	else:
		cur_stage = 0
		cur_scene = 0
		advance_target_stage = 0
		advance_target_scene = 0
	_kills_this_scene = 0
	mode = Mode.GRINDING
	_revive_party()
	_spawn_current()


## ── 玩家宏观操作:推进 / 修整 + 倒计时(承 director :320-341)──────────────────

## 玩家点"推进":GRINDING 态入队,在本轮结束执行。
func request_push() -> void:
	if mode == Mode.GRINDING:
		_queued = QueuedAction.PUSH


## 玩家点"修整":GRINDING 态入队本轮结束执行;倒计时态立即修整并取消自动推进。
func request_rest() -> void:
	if mode == Mode.GRINDING:
		_queued = QueuedAction.REST
	elif mode == Mode.STAGE_CLEAR_COUNTDOWN:
		countdown_remaining = 0.0
		_enter_rest()


## 倒计时推进(由 Arena 固定步长 tick 驱动;测试可直接喂 delta)。到点无操作 → 自动推进。
func process_countdown(delta: float) -> void:
	if mode != Mode.STAGE_CLEAR_COUNTDOWN:
		return
	countdown_remaining -= delta
	if countdown_remaining <= 0.0:
		countdown_remaining = 0.0
		_execute_push()


## 执行推进:跳到 advance_target 落点,回 PROGRESSING 并刷怪。
func _execute_push() -> void:
	cur_stage = advance_target_stage
	cur_scene = advance_target_scene
	_kills_this_scene = 0
	mode = Mode.PROGRESSING
	_spawn_current()


## 进入"修整"stub:停刷怪(清空 Arena 敌人)+ 进 RESTING + 发信号。
func _enter_rest() -> void:
	if arena != null:
		arena.enemies = []
	mode = Mode.RESTING
	rest_requested.emit()


## 关 stage 的最后一个普通场景下标(通常 = 2);供回退落点用。
func _last_normal_scene(stage: int) -> int:
	if stage < 0 or stage >= stages.size():
		return 0
	return maxi(0, stages[stage].scenes.size() - 1)


## 把 Arena 全部存在成员回满(团灭回退、过场景、通关时调用)。
func _revive_party() -> void:
	if arena == null:
		return
	for p in arena.players:
		if p != null:
			p.current_hp = p.max_hp()


## 通关倒计时长度:取 Arena 的 tuning 配置,未注则回退默认 5s。
func _countdown_len() -> float:
	if arena != null and arena.tuning != null:
		return arena.tuning.stage_clear_countdown_sec
	return 5.0
