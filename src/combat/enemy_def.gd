extends Resource
class_name EnemyDef
## 一种怪的数值与掉落配置。数值走 Resource、不硬编码进逻辑(PLAN D3 / FEATURE-DESIGN F1)。
## 普通怪与关底 Boss 共用此结构;Boss 只是数值更高的 EnemyDef。

@export var display_name: String = "怪物"
@export var max_hp: float = 10.0
@export var attack: float = 1.0
## 每秒出手次数(PLAN D2/D6:占位 1.0,走配置不硬编码;运行时出手进度/狂暴态在 CombatDirector,不写回 Resource)。
@export var attack_speed: float = 1.0

@export_group("外观")
## 战斗视图里这种怪的贴图(美术已锁定:敌人一律朝左,无需 flip)。贴图随 Resource 走、
## 不硬编码路径(ASSET-SPEC §6 / project-context §4)。留空 = 视图回退到占位色块。
@export var sprite: Texture2D

@export_group("掉落")
## 本次击杀"有掉落"的概率,0..1;否则本次无掉落(每次击杀最多发一次掉落事件,PLAN D7)。
@export_range(0.0, 1.0) var drop_chance: float = 0.6
## 物品等级(PoE 流水线 ilvl 来源,REFACTOR-01 层5 D6;additive,旧权重字段保留待层8退役)。
## 决定掉落可取的词缀 Tier 上限;占位 1,留数值专章。
@export var item_level: int = 1
## 掉落种类相对权重(金 / 材料 / 装备),roll 时归一化。
@export var weight_gold: float = 70.0
@export var weight_material: float = 22.0
@export var weight_equipment: float = 8.0
## 物品稀有度相对权重(白 / 蓝 / 金),roll 时归一化;金币种类一律记为白。
@export var rarity_weight_white: float = 80.0
@export var rarity_weight_blue: float = 18.0
@export var rarity_weight_gold: float = 2.0
