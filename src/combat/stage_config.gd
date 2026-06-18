extends Resource
class_name StageConfig
## 一关 = 3 个普通场景(难度逐级递增)+ 1 个关底 Boss(PLAN D3/D4)。
## Boss 击杀一次即永久解锁下一关,此后永不再战(逻辑在 CombatDirector,见 PLAN D4)。

@export var stage_name: String = "关卡"
## 三个普通场景,顺序即推进顺序(0→1→2)。本期固定 3 个。
@export var scenes: Array[SceneConfig] = []
## 关底 Boss。调值意图:略强于下一关前两个场景(FEATURE-DESIGN F1,留 playtest 调)。
@export var boss: EnemyDef
