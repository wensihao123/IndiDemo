extends RefCounted
class_name AICombatComponent
## 目标选择(承 combat_director._front_living_member 的「集火最前存活」语义)。
## 〔08 团战〕近战门控/远程隔位判定已上移到 CombatArena(阵型级,需全 enemies 数组+排位序),
## 本组件只管「集火最前存活」目标选择;旧 in_range 占位已退役(REFACTOR-04 §3c)。

## 选敌对阵营最前存活者(数组顺序即排位);全死返 null。
func select_target(_self_entity: Entity, enemies: Array) -> Entity:
	for e in enemies:
		if e != null and (e as Entity).is_alive():
			return e
	return null
