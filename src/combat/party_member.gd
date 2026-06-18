extends RefCounted
class_name PartyMember
## 一个运行时队伍成员(战斗中的可变状态,区别于纯配置)。
## v1 只填 1 个战士,但结构支持 N 人(4 格队伍,见 PLAN D1 / FEATURE-DESIGN §3)。

var display_name: String
var max_hp: float
var attack: float
var current_hp: float

## 战斗维度(PLAN D3,默认 = 设计自然单位:每秒挥 1 次、无任何防御/暴击加成)。
## attack_speed = 每秒出手次数;armor 走递减减伤 armor/(armor+K);dodge/crit_chance ∈ 0..1。
var attack_speed: float
var armor: float
var dodge_chance: float
var crit_chance: float
var crit_mult: float
var hp_regen: float

## 出手进度累加器(单场运行时状态,非配置):每 tick += attack_speed*tick_seconds,满 1 出手一次。
var attack_progress := 0.0

func _init(p_name := "战士", p_max_hp := 100.0, p_attack := 4.0, p_attack_speed := 1.0, p_armor := 0.0, p_dodge_chance := 0.0, p_crit_chance := 0.0, p_crit_mult := 2.0, p_hp_regen := 0.0) -> void:
	display_name = p_name
	max_hp = p_max_hp
	attack = p_attack
	current_hp = p_max_hp
	attack_speed = p_attack_speed
	armor = p_armor
	dodge_chance = p_dodge_chance
	crit_chance = p_crit_chance
	crit_mult = p_crit_mult
	hp_regen = p_hp_regen

func is_alive() -> bool:
	return current_hp > 0.0

func take_damage(amount: float) -> void:
	current_hp = maxf(0.0, current_hp - amount)
