extends RefCounted
class_name GameKeys
## 地基层共享词汇表(只读常量,不依赖任何其它脚本)。
## 战斗 8 维 / 装备槽位 / modifier 种类 / 稀有度 的规范 StringName 都收在这里,
## 供数据层(DataRegistry 校验)、持久层、掉落流水线统一引用,避免散落字面量。

# ── 战斗 8 维(与 PartyMember 字段同名)────────────────────────────────────────
const STAT_ATTACK := &"attack"
const STAT_MAX_HP := &"max_hp"
const STAT_ATTACK_SPEED := &"attack_speed"
const STAT_ARMOR := &"armor"
const STAT_DODGE_CHANCE := &"dodge_chance"
const STAT_CRIT_CHANCE := &"crit_chance"
const STAT_CRIT_MULT := &"crit_mult"
const STAT_HP_REGEN := &"hp_regen"

const STATS: Array[StringName] = [
	STAT_ATTACK, STAT_MAX_HP, STAT_ATTACK_SPEED, STAT_ARMOR,
	STAT_DODGE_CHANCE, STAT_CRIT_CHANCE, STAT_CRIT_MULT, STAT_HP_REGEN,
]

# ── 装备槽位(3 槽,每槽 1 件;04 §3.1)──────────────────────────────────────
const SLOT_WEAPON := &"weapon"
const SLOT_ARMOR := &"armor"
const SLOT_ACCESSORY := &"accessory"

const SLOTS: Array[StringName] = [SLOT_WEAPON, SLOT_ARMOR, SLOT_ACCESSORY]

# ── 基底招牌轴模式(ItemBaseDef.signature_mode)────────────────────────────────
const SIG_ALL := &"all"            # 全部招牌轴都生效(武器:攻击+攻速)
const SIG_PICK_ONE := &"pick_one"  # 掉落时随机选一条招牌轴(饰品:生命/闪避/秒回三选一)

const SIG_MODES: Array[StringName] = [SIG_ALL, SIG_PICK_ONE]

# ── modifier / 词缀种类 ───────────────────────────────────────────────────────
const KIND_FLAT := &"flat"        # 平加:进 ΣFlat
const KIND_PERCENT := &"percent"  # 百分比:进 ΣPercent

const KINDS: Array[StringName] = [KIND_FLAT, KIND_PERCENT]

# ── 稀有度(白 < 蓝 < 金;rank 用于分解门槛比较)──────────────────────────────
const RARITY_WHITE := &"white"
const RARITY_BLUE := &"blue"
const RARITY_GOLD := &"gold"

const RARITIES: Array[StringName] = [RARITY_WHITE, RARITY_BLUE, RARITY_GOLD]


## 稀有度序数(white=0 < blue=1 < gold=2);未知稀有度返回 -1。
static func rarity_rank(rarity: StringName) -> int:
	return RARITIES.find(rarity)
