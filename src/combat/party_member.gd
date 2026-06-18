extends RefCounted
class_name PartyMember
## 一个运行时队伍成员(战斗中的可变状态,区别于纯配置)。
## v1 只填 1 个战士,但结构支持 N 人(4 格队伍,见 PLAN D1 / FEATURE-DESIGN §3)。

var display_name: String
var max_hp: float
var attack: float
var current_hp: float

func _init(p_name := "战士", p_max_hp := 100.0, p_attack := 4.0) -> void:
	display_name = p_name
	max_hp = p_max_hp
	attack = p_attack
	current_hp = p_max_hp

func is_alive() -> bool:
	return current_hp > 0.0

func take_damage(amount: float) -> void:
	current_hp = maxf(0.0, current_hp - amount)
