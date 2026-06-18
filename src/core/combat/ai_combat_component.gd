extends RefCounted
class_name AICombatComponent
## 目标选择(承 combat_director._front_living_member 的「集火最前存活」语义)。
## v1 lane 射程占位「恒在射程」;真 lane 几何 / 集火-AoE / 接近时长留数值专章(ARCHITECTURE §6)。

## 选敌对阵营最前存活者(数组顺序即排位);全死返 null。
func select_target(_self_entity: Entity, enemies: Array) -> Entity:
	for e in enemies:
		if e != null and (e as Entity).is_alive():
			return e
	return null


## v1 占位:恒在射程(lane 接近时长留数值专章)。
func in_range(_self_entity: Entity, _target: Entity) -> bool:
	return true
