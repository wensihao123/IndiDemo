extends RefCounted
class_name SkillComponent
## 出手节奏 + 6 维伤害解算(承 combat_director.gd:182-194/188-190/215-220 公式,值不变)。
## attack_progress 落本组件(单场运行时态,CombatArena 每 tick 驱动);读属性一律经 owner.stats.get_final。

## 出手进度累加器:每 tick += attack_speed_final × dt,满 1 出手一次(承 PartyMember.attack_progress)。
var attack_progress := 0.0


## 累计出手进度(承 combat_director:182 / :206)。
func accumulate(attack_speed_final: float, dt: float) -> void:
	attack_progress += attack_speed_final * dt


## 取出本 tick 应出手次数(整数),并扣减进度;guard<1000 防爆(承 combat_director:183-184 的离散多次/tick)。
func pending_swings() -> int:
	var swings := 0
	while attack_progress >= 1.0 and swings < 1000:
		attack_progress -= 1.0
		swings += 1
	return swings


## 一次命中解算:暴击(自身 crit_*)→ 闪避(目标 dodge_chance)→ 护甲减伤(目标 armor/(armor+K))。
## 返回 {amount, is_crit, dodged};amount 为最终施加到 target 的伤害(已减伤;dodged 时为 0)。
## 值逐条对齐 formula_test.gd:暴击 atk×crit_mult、armor==K 半伤、armor=0 全额、denom<=0 跳过防 NaN。
func resolve_hit(attacker: Entity, target: Entity, tuning: CombatTuning, rng: RandomNumberGenerator, damage_mult := 1.0) -> Dictionary:
	var raw: float = attacker.stats.get_final(GameKeys.STAT_ATTACK) * damage_mult
	var crit_chance: float = attacker.stats.get_final(GameKeys.STAT_CRIT_CHANCE)
	var is_crit: bool = crit_chance > 0.0 and rng.randf() < crit_chance
	if is_crit:
		raw *= attacker.stats.get_final(GameKeys.STAT_CRIT_MULT)
	var dodge: float = target.stats.get_final(GameKeys.STAT_DODGE_CHANCE)
	if dodge > 0.0 and rng.randf() < dodge:
		return {"amount": 0.0, "is_crit": is_crit, "dodged": true}
	# 护甲递减;denom<=0(armor 与 K 同为 0,配置 footgun)时跳过减伤,避免 0/0=NaN。
	var armor: float = target.stats.get_final(GameKeys.STAT_ARMOR)
	var denom: float = armor + tuning.armor_k
	var amount: float = raw if denom <= 0.0 else raw * (1.0 - armor / denom)
	return {"amount": amount, "is_crit": is_crit, "dodged": false}
