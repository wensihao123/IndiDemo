extends RefCounted
class_name CombatTuning
## 战斗调参常量(可注入,守 hard-NO「数值不硬编码」;承 combat_director 的 @export 公式/狂暴/模拟参数)。
## CombatArena 持有一份,传给 SkillComponent 解算。测试像旧 d.armor_k=50 那样直接覆字段注入。

## 护甲递减减伤常数 K:减伤 = armor/(armor+K);armor==K 时恰减 50%(占位 50)。
var armor_k := 50.0

## 同一敌人缠斗超过此秒数进入软狂暴(占位,留数值专章)。
var enrage_threshold_sec := 25.0
## 狂暴后每多缠斗 1 秒,敌人伤害倍率额外 +此值(线性占位)。
var enrage_ramp_per_sec := 0.5

## 通关 Boss 后倒计时长度(秒);无操作到点自动推进(占位)。
var stage_clear_countdown_sec := 5.0

## 固定逻辑步长(秒);累加器按此步进,使战斗帧率无关(不变量 #3)。
var tick_seconds := 0.1

## 〔08 团战 §3a〕近战门控容量 G:同一 tick 至多前 G 名存活近战可够到战士出手(余者排队补位)。
## 远程隔位不占此名额。守 i8 纯加性(严禁「敌越多每个越强」的乘性放大);占位 2(BALANCE-CHANGE-03 §3a)。
var melee_gate_capacity := 2


## 狂暴伤害倍率:未狂暴 = 1.0;狂暴后随超阈值时长线性陡增(承 combat_director._enrage_mult)。
func enrage_mult(fight_time: float, enraged: bool) -> float:
	if not enraged:
		return 1.0
	return 1.0 + enrage_ramp_per_sec * (fight_time - enrage_threshold_sec)
