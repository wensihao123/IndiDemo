extends RefCounted
class_name Entity
## 战斗实体空壳(ARCHITECTURE §3.1):持组件 + 单场运行时 current_hp + 阵营/排位。
## 逻辑组件(skill/ai)= RefCounted,由 CombatArena 直接方法调用驱动(不靠 _process,保 headless 确定)。
## D5/F5 回写:本应是 Node2D 空壳,但 ProgressionController 每场内部 new 敌实体,Node 会在
## headless 测里留 orphan(纯逻辑层摩擦)→ 按 PLAN F5 预授权退为 RefCounted。表现层(层6)
## 另挂可视 Node 引用本实体,不混入战斗逻辑层。lane 仅作数据位保留。

enum Team { PLAYER, ENEMY }

var team: Team = Team.PLAYER
var stats: StatsComponent
var equipment: EquipmentComponent          # 敌人无装备时为 null
var skill: SkillComponent
var ai: AICombatComponent
## 单场运行时血量(绝不写回模板 Character/EnemyDef;start_battle 复位)。
var current_hp := 0.0
## 波内排位序(0=最前;由 from_enemy_def 烙;lane 几何留数值专章,此处仅作排位整数,守 #7 无坐标)。
var lane := 0
## 站位类别镜像(08 团战 REFACTOR-04 §3c):供 CombatArena 门控判定读「谁是近战/远程」。
var position_class: EnemyDef.PositionClass = EnemyDef.PositionClass.MELEE
## 来源敌模板(供敌死掉落取 item_level;玩家实体为 null)。
var source_enemy_def: EnemyDef = null


func _init(p_team: Team = Team.PLAYER) -> void:
	team = p_team
	skill = SkillComponent.new()
	ai = AICombatComponent.new()


func max_hp() -> float:
	return stats.get_final(GameKeys.STAT_MAX_HP)


func is_alive() -> bool:
	return current_hp > 0.0


func take_damage(amount: float) -> void:
	current_hp = maxf(0.0, current_hp - amount)


## 回血封顶满血(承 combat_director:177;default hp_regen=0 → 无操作)。
func heal(amount: float) -> void:
	current_hp = minf(max_hp(), current_hp + amount)


## 复位单场出手进度(承 start_battle 对 attack_progress 的清零)。
func reset_swing() -> void:
	skill.attack_progress = 0.0


## ── 工厂 ──────────────────────────────────────────────────────────────────────

## 由持久 Character 快照建玩家实体:base_stats→StatsComponent + 装备经 EquipmentComponent 注入,血满。
static func from_character(c: Character, registry: DataRegistry) -> Entity:
	var e := Entity.new(Team.PLAYER)
	e.stats = c.build_stats()
	e.equipment = EquipmentComponent.new(e.stats, registry)
	for slot in c.equipped.keys():
		e.equipment.equip(slot, c.equipped[slot])
	e.current_hp = e.max_hp()
	return e


## 把当前装备态快照回写持久 Character(存档收口/方案 B):战斗中自动穿上的装备落进 roster,不随重 boot 丢。
## 槽空则清掉 Character 该槽(承卸下边界);敌实体无 equipment 时空操作。
func write_equipment_into(c: Character) -> void:
	if equipment == null or c == null:
		return
	for slot in GameKeys.SLOTS:
		var item := equipment.get_equipped(slot)
		if item != null:
			c.equipped[slot] = item
		else:
			c.equipped.erase(slot)


## 由 EnemyDef 快照建敌实体:数值进 StatsComponent base(无装备),血满。
## rank = 波内排位序(0=最前;08 团战门控按序取前 G 名近战);烙 position_class 供门控读。
static func from_enemy_def(def: EnemyDef, rank := 0) -> Entity:
	var e := Entity.new(Team.ENEMY)
	e.source_enemy_def = def
	e.lane = rank
	e.position_class = def.position_class
	var s := StatsComponent.new()
	s.set_base(GameKeys.STAT_MAX_HP, def.max_hp)
	s.set_base(GameKeys.STAT_ATTACK, def.attack)
	s.set_base(GameKeys.STAT_ATTACK_SPEED, def.attack_speed)
	e.stats = s
	e.current_hp = e.max_hp()
	return e
