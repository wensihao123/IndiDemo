extends RefCounted
class_name SaveSystem
## 持久层落盘(PLAN D2):PlayerState(roster+bag+材料)+ 进度游标序列化到 user:// JSON。
## 纯逻辑、可 round-trip 单测;读不存在/损坏档返回 {} 不抛(让 GameController 走默认 roster)。

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://savegame.json"


## 组装顶层存档 dict(不落盘,便于单测对比)。
func to_save_dict(player_state: PlayerState, prog: ProgressionController) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player": player_state.to_dict(),
		"progress": {
			"max_unlocked_stage": prog.max_unlocked_stage,
			"cur_stage": prog.cur_stage,
			"cur_scene": prog.cur_scene,
		},
	}


func save(player_state: PlayerState, prog: ProgressionController, path: String = DEFAULT_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("存档写入失败:%s (err %d)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(to_save_dict(player_state, prog)))
	f.close()
	return true


## 读档:不存在/解析失败/顶层非对象 → 返回 {}(不抛,调用方据此走默认开局)。
func load_file(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return parsed


## 把存档 dict 写回 PlayerState + 进度游标(缺字段取默认;空 dict 时整体不动)。
func apply(d: Dictionary, player_state: PlayerState, prog: ProgressionController, registry: DataRegistry = null) -> void:
	if d.is_empty():
		return
	player_state.from_dict(d.get("player", {}), registry)
	var progress: Dictionary = d.get("progress", {})
	prog.max_unlocked_stage = int(progress.get("max_unlocked_stage", 0))
	prog.cur_stage = int(progress.get("cur_stage", 0))
	prog.cur_scene = int(progress.get("cur_scene", 0))
