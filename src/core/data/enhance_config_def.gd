extends RefCounted
class_name EnhanceConfigDef
## 强化数值模板(只读蓝图,BALANCE-CHANGE-02 定稿)。四常量走配置不硬编码进逻辑。
## 加成 = 主轴基底 × per_level × enhance_level(FLAT);成本 = cost_base + cost_step × L;上限 = cap。

## 每级加成 = 该件主轴基底值的百分比(线性叠加,不复利)。
var per_level: float = 0.10
## 强化上限(满级 = 主轴基底翻倍)。
var cap: int = 10
## L→L+1 成本基数。
var cost_base: int = 1
## L→L+1 成本每级增量。
var cost_step: int = 1


## 从 level → level+1 的材料成本(L 从 0 起)。
func cost_for_level(level: int) -> int:
	return cost_base + cost_step * level


## 是否已满级(不可再强化)。
func is_max(level: int) -> bool:
	return level >= cap
