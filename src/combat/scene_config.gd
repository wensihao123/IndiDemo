extends Resource
class_name SceneConfig
## 一个普通场景:刷哪一波怪 + 清场所需击杀数。
## 清场判定 = 击杀固定数量(PLAN D3 取 kill-count;波数 / 计时本期不做)。
## 08 团战(REFACTOR-04 §3a):一波多敌走 enemy_group(序=排位前→后);旧 enemy 留作 fallback。

## 一波敌人组成,数组顺序 = 排位序(前→后);每只的近/远由其 EnemyDef.position_class 决定。
## 非空 → 用之;空 → 回退到单敌 enemy(向后兼容,旧 .tres 不改即 size-1 波)。
@export var enemy_group: Array[EnemyDef] = []
## 旧单敌字段(REFACTOR-04 fallback):enemy_group 空时包成 [enemy]。
@export var enemy: EnemyDef
## 清场所需击杀数量(按敌死累计,达标 → 进下一场景;BALANCE-CHANGE-03 §5 多波累积)。
@export var kill_count: int = 5


## 取本场景一波的敌人定义(REFACTOR-04 §3a 取波 helper):
## enemy_group 非空用之,否则回退单敌 [enemy],都空返回空数组。
func wave_defs() -> Array[EnemyDef]:
	if not enemy_group.is_empty():
		return enemy_group
	if enemy != null:
		var arr: Array[EnemyDef] = [enemy]
		return arr
	return []
