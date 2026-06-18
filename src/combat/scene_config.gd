extends Resource
class_name SceneConfig
## 一个普通场景:刷哪种怪 + 清场所需击杀数。
## 清场判定 = 击杀固定数量(PLAN D3 取 kill-count;波数 / 计时本期不做)。

@export var enemy: EnemyDef
## 清场所需击杀数量(达标 → 进下一场景)。
@export var kill_count: int = 5
