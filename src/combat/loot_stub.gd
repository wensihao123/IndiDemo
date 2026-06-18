extends Node
class_name LootStub
## 临时掉落监听:订阅 CombatDirector.loot_dropped 并打印事件(PLAN D7 stub)。
## 真正的物品生成 / 入库 = step 03;本步只证明事件流通了。

@export var director_path: NodePath

func _ready() -> void:
	var director := get_node_or_null(director_path)
	if director != null and director.has_signal("loot_dropped"):
		director.loot_dropped.connect(_on_loot_dropped)

func _on_loot_dropped(kind: StringName, rarity: StringName) -> void:
	print("[loot] 掉落 kind=%s rarity=%s" % [kind, rarity])
