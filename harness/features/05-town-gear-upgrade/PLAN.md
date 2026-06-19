---
artifact: PLAN
feature: 05-town-gear-upgrade
role: Planner
status: draft
updated: 2026-06-19
inputs: [project-context.md, ARCHITECTURE.md, BALANCE.md, FEATURE-DESIGN.md, arch/REFACTOR-03-town-meta-ops.md, balance/BALANCE-CHANGE-02-town-gear-upgrade.md, src/core/items/item_instance.gd, src/core/meta/{player_state,character}.gd, src/core/game_controller.gd, src/core/combat/{entity,combat_arena}.gd, src/core/systems/data_registry.gd, src/combat/combat_view.gd, src/shell/floating_shell.gd]
next: Implementer
---

# PLAN — 05 城镇:手动换装 + 对比面板 + 装备强化

## 1. Goal
点亮独立城镇界面:进城暂停挂机,3 槽手动换装 + 8 维对比差值面板 + 确定性装备强化(+1、三槽通吃、花材料),出城恢复挂机并带着变强出去打。

## 2. Approach & key decisions
按 REFACTOR-03 §4 五步依赖序落地:**先数据模型 → 属性引擎 → 持久层元操作 → 编排暂停/恢复 → 表现层 UI**(先逻辑后表现,前 4 步纯逻辑 gdUnit4 可测,中途不破现 117+ 绿)。强化数值锚全部取 BALANCE-CHANGE-02。

- **D1 — `enhance_level` 加成走 `to_modifiers` 的 source=self 通道,FLAT、仅作用 `signature_axes[0]`。**
  - 为什么:REFACTOR-03 不变量 #10 + BALANCE-CHANGE-02 i7。`signature_axes[0]` = 每槽主轴(weapon→`attack`、armor→`armor`、accessory→其 pick_one 轴),**天然排除 weapon 的次轴 `attack_speed`**(在 `[1]` 位)→ DPS 对强化等级保持线性,守 i4。FLAT 并入 ΣFlat 守 i2、随 source 精确卸下守 i1。
  - 否决:PERCENT 加成(放大全身该属性、与他件纠缠、weapon 易踩超线性);强化全部 signature_axes(weapon 双轴 attack×attack_speed 准平方放大,违 i4)。

- **D2 — 四个强化常量走新配置 `data/config/enhance.json` + `EnhanceConfigDef`,由 `DataRegistry` 加载。**
  - 为什么:hard-NO「数值不硬编码进逻辑」。沿用既有 def 模式(同 `LootTableDef`):一份配置一个 typed def + getter + 校验闸。`to_modifiers` 已收 `registry` 参数可直接读;成本/上限的单一真源放 def 上的静态助手,UI 与持久层共用。
  - 否决:塞进 `loot_tables.json`(语义不属掉落表);硬编码常量(破 hard-NO)。

- **D3 — 换装/强化 = 持久层元操作,放 `PlayerState` 方法(它已拥有 roster/bag/materials)。**
  - 为什么:REFACTOR-03 §5「元操作作用持久层、绝不进 per-run 战斗层」。`PlayerState` 是这三者的唯一持有者,已有 `add_material/add_to_bag` 同类方法,加换装/强化最内聚,无需新建 service(守「别过度设计」)。强化所需的 `EnhanceConfigDef` 由调用方(城镇 UI,持 `Game.registry`)传入 → `PlayerState` 不反向依赖 registry。
  - 否决:新建 TownService 类(v1 就 3 个方法,过度抽象);放战斗层(破边界)。

- **D4 — 出城恢复 = 玩家 Entity re-snapshot,且「先冲洗活体装备→持久、再重建、HP 带值夹紧」。**
  - 为什么:`begin_run` 的玩家 Entity 是 `Entity.from_character` 快照(`game_controller.gd:77`),城镇只改持久层 `Character`,不重建则变强不生效(REFACTOR-03 §2c)。**进城暂停时必须先 `_sync_party_equipment()` 把战斗中自动穿到的装备冲回 `Character`**,否则 resume re-snapshot 会丢这批自动装备。重建后 `from_character` 默认满血(`entity.gd:61`)→ 必须用**冻结前的 `current_hp` 覆盖并夹 `[0,new_max]`**(守 i5 不免费回血)。
  - 否决:城镇直接编辑活体 `Entity.EquipmentComponent`(双写、破 i4#4 持久层是事实源,且战斗未跑时无活体);朴素 rebuild 满血(免费回血站,违 i5)。

- **D5 — 城镇 = MainArea 内新 `TownView` 表现节点,与 `CombatView` 并列、同样读 `/root/Game`;对比面板复用 04 的 8 维格式化。**
  - 为什么:REFACTOR-03「城镇是表现层消费者,像 CombatView 一样挂 shell 下读 Game」。8 维差值口径/绿↑红↓/`_format_stat_value` 已在 `combat_view.gd` 建好(04),复用其表现语言(FEATURE-DESIGN §4 要求一致)。
  - 否决:独立 Window/场景(v1 悬浮窗就一个主区,新窗口超范围);把城镇塞进 CombatView(职责混淆)。

## 3. Ordered steps

### 步 1 — `ItemInstance += enhance_level` + 序列化(数据模型叶子,无下游依赖)
- **动作**:`item_instance.gd` 加字段 `var enhance_level: int = 0`;`to_dict()` 写入 `"enhance_level": enhance_level`;`from_dict()` 读 `int(d.get("enhance_level", 0))`(**缺省 0 → 旧档无缝**)。`_init` 不动(默认 0)。
- **文件**:`src/core/items/item_instance.gd`。
- **验证**:`--headless --check-only` 退 0;新单测 `test_item_instance`:`to_dict/from_dict` round-trip 后 `enhance_level` 保值;旧 dict(无该键)→ from_dict 得 0。

### 步 2 — 强化配置 `enhance.json` + `EnhanceConfigDef` + `DataRegistry` 加载
- **动作**:
  1. 新建 `data/config/enhance.json`:`{"per_level": 0.10, "cap": 10, "cost_base": 1, "cost_step": 1}`(数值取 BALANCE-CHANGE-02 §3)。
  2. 新建 `src/core/data/enhance_config_def.gd`(class_name `EnhanceConfigDef`,RefCounted):字段 `per_level/cap/cost_base/cost_step`;助手 `cost_for_level(level:int)->int { return cost_base + cost_step*level }`、`is_max(level:int)->bool { return level >= cap }`。
  3. `data_registry.gd`:`load_all` 加读 `enhance.json`、顶层须为 Dictionary 校验;新增 `_ingest_enhance(d)`(校验 per_level≥0、cap≥1、cost_base≥0、cost_step≥0,收 `_errors`);存 `_enhance_config`;getter `get_enhance_config() -> EnhanceConfigDef`。
- **文件**:`data/config/enhance.json`(新)、`src/core/data/enhance_config_def.gd`(新)、`src/core/systems/data_registry.gd`。
- **验证**:`--check-only` 退 0;新单测:喂合法内存数据 → `get_enhance_config()` 各值正确、`cost_for_level(0..9)` = 1..10、`is_max(10)` 真;喂非法(cap=0 / 缺字段)→ `load_all`/ingest 返 false 且 `get_load_errors()` 非空。

### 步 3 — `to_modifiers` 接强化加成(属性引擎,依赖步 1+2)
- **动作**:`item_instance.gd` 的 `to_modifiers(registry)` 末尾追加:`if enhance_level > 0 and not signature_axes.is_empty():` 取 `var cfg := registry.get_enhance_config()`、`var axis := signature_axes[0]`、`var bonus := base.base_value(axis, ilvl) * cfg.per_level * enhance_level`、`out.append(StatModifier.new(axis, StatModifier.Kind.FLAT, bonus, self))`。(`base` 已在方法内取得;cfg 为 null 时跳过防御。)
- **文件**:`src/core/items/item_instance.gd`。
- **验证**:`--check-only` 退 0;新单测:
  - 同一 weapon `enhance_level=5` vs `0`:`to_modifiers` 多出一条 `attack` FLAT = `base_value(attack,ilvl)*0.10*5`,**且 `attack_speed` 那条不变**(不被强化,守 i4)。
  - 强化件经 `EquipmentComponent.equip` 后 `StatsComponent.get_final(attack)` 升、`unequip` 后**完全回裸基础**(强化 FLAT 随 source=self 一并卸下,守 i1)。
  - `enhance_level=0` → modifier 列表与现状一致(无回归)。

### 步 4 — 持久层换装/强化元操作(依赖步 1-3)
- **动作**:`player_state.gd` 新增三方法(纯持久态操作,无 UI):
  - `equip_from_bag(c: Character, slot: StringName, item: ItemInstance) -> void`:校验 `item.base_id == slot`;若 `c.equipped.has(slot)` 则旧件 `add_to_bag`;从 `bag` 移除 `item`;`c.equipped[slot] = item`(守 i1 无损:旧件回包不丢)。
  - `unequip_to_bag(c: Character, slot: StringName) -> void`:有装备则移入 `bag` 并 `c.equipped.erase(slot)`。
  - `enhance_item(item: ItemInstance, cfg: EnhanceConfigDef) -> bool`:`if cfg.is_max(item.enhance_level): return false`;`var cost := cfg.cost_for_level(item.enhance_level)`;`var have := get_material(item.base_id, RARITY_WHITE)`;`if have < cost: return false`(**不扣半截**);扣材料(`add_material(item.base_id, white, -cost)`)、`item.enhance_level += 1`、`return true`。
  - 注:强化吃 `item.base_id|white` 材料(只有白材料实际产出,BALANCE-CHANGE-02);材料为负扣减——确认 `add_material` 接受负 amount(它是 `+= amount`,可),或加 `spend_material` 助手保对称,Implementer 择一。
- **文件**:`src/core/meta/player_state.gd`(必要时加 `spend_material`)。
- **验证**:`--check-only` 退 0;新单测 `test_player_state`:
  - 换装:满槽换 → 旧件进包、新件上身、包内数量守恒;空槽换 → 无旧件回包。`base_id != slot` 不生效。
  - 强化:材料足 → +1 且扣对应 `slot|white`;材料不足 → 返 false、等级与材料**均不变**;到 `cap` → 返 false。

### 步 5a — `Game.pause_run/resume_run` 编排 API(依赖步 1-4)
- **动作**:`game_controller.gd` 新增:
  - `pause_run() -> void`:`if arena == null: return`;`_sync_party_equipment()`(先冲洗活体装备→持久,免 resume 丢自动装备);`arena.running = false`。
  - `resume_run() -> void`:`if arena == null: return`;逐 `i in party_characters.size()`:`c = party_characters[i]`,空或越界跳过;`var old_hp := arena.players[i].current_hp if arena.players[i] != null else 0.0`;`var e := Entity.from_character(c, registry)`;`e.current_hp = clampf(old_hp, 0.0, e.max_hp())`(守 i5);`arena.players[i] = e`。重指 `arena.loot_equipment` = 首个非空 player 的 `equipment`(同 `begin_run:81-85`)。最后 `arena.running = true`。
- **文件**:`src/core/game_controller.gd`。
- **验证**:`--check-only` 退 0;新单测 `test_game_controller`(`auto_boot=false` + 注入 config_dir,沿用现有测试模式):
  - pause 后 `arena.running == false`,tick 不推进;resume 后 `== true`。
  - **HP 带值夹紧**:置某 player `current_hp` 为非满值 → pause → 改其 `Character.equipped` 提升 max_hp → resume → 新 `current_hp == 旧值`(未被重置满血)、且 ≤ 新 max。
  - **变强生效**:resume 前给 Character 换上更强 weapon → resume 后 `arena.players[i].stats.get_final(attack)` 反映新装备。
  - **不丢自动装备**:pause 前活体有自动穿到、未同步的装备 → pause(冲洗)→ resume 后该装备仍在。

### 步 5b — 城镇表现层 `TownView`(依赖步 5a;纯 View,手动 Play 验)
- **动作**:新建 `src/combat/town_view.gd`(class_name `TownView`,extends Control),挂进 `scenes/shell/floating_shell.tscn` 的 `MainArea`(与 CombatView 并列,默认隐藏):
  - 「进城」入口(CombatView 或 shell 主区一个按钮)→ 显 TownView + `Game.pause_run()` + 隐 CombatView;「出城」→ `Game.resume_run()` + 隐 TownView + 显 CombatView。
  - 读 `Game.player_state.roster[0]`(v1 战士)+ `Game.player_state.bag` + `Game.registry`。
  - **换装区**:3 槽显当前件;背包列表可选;选中 → 调 `player_state.equip_from_bag/unequip_to_bag`,刷新。
  - **对比面板**:聚焦背包某件 → 8 维差值 = `sum(候选.to_modifiers(registry))` − `sum(当前槽件.to_modifiers(registry))`,逐项绿↑/红↓,复用 04 `_format_stat_value`/稀有度色;空槽与 0 比。
  - **强化区**:选一件 → 显当前等级 + 下一级成本 `cfg.cost_for_level(level)` + 持有材料;材料足且未满级 → 「强化」可点 → `player_state.enhance_item(item, cfg)` 成功则数值跳变刷新;不足→禁用+「材料不够」;满级→「已满级」禁用。
- **文件**:`src/combat/town_view.gd`(新)、`scenes/shell/floating_shell.tscn`(挂节点 + 进/出城按钮接线)。**配置走 Resource**:TownView 不 `preload` 配置路径,经 `Game.registry` 取(守 hard-NO)。
- **验证**(手动 Play,project-context §5):进城→挂机暂停(战斗停);换装→槽数值跳变+绿闪、旧件回包;对比→差值绿↑红↓一眼可辨;强化→花材料数值升、计数减、满级/材料不足正确禁用;出城→挂机从暂停处恢复、带着变强继续打,血量不被重置满。

## 4. Out of scope
- 招募 / 多角色换人(v1 只 1 战士;3 槽对它生效,roster 结构已支持 N 人但不点亮)。
- 金币消耗口 / 装备出售(债-4 kind 未接线,F-KIND 属 Producer)。
- 城镇手动分解蓝/金补材料(经济校验已判 v1 不需,材料偏富余)。
- 批量强化、套装、镶嵌、重铸、合成、技能升级。
- 强化失败/掉级/碎裂(GD 红线明确排除)。
- 「回城回血」旋钮(BALANCE-CHANGE-02 §3d 定 v1 不回血,沿用架构默认)。
- 强化/换装的正式美术演出(绿闪强度、强化特效贴图、音效)= Art Spec / Engine Integrator 下游;本计划只接 04 已有的轻表现。

## 5. Risks & Flags / Open questions
- **🟢 F1 新配置文件**:`enhance.json` + `EnhanceConfigDef` 是数据 + typed def,非新插件/依赖,合 hard-NO 与既有 def 模式;风险低。Implementer 注意 `load_all` 加文件后,所有现有测试若注入自定义 config_dir 需确保该目录也有 `enhance.json`(或 ingest 路径容缺省)——**建议 ingest 缺文件时报错明确**,与现 4 份 JSON 一致对待。
- **🟡 F2 测试 fixture 连带**:步 2 给 `DataRegistry.load_all` 加第 5 份必读 JSON → 任何用真实 `res://data/config` 的测试不受影响,但若有测试指向**自建临时 config_dir** 则需补 `enhance.json`。Implementer 落地时 grep `load_all(`/`DEFAULT_CONFIG_DIR` 核一遍,免连带挂测。
- **🟡 F3 enhance 轴 = `signature_axes[0]` 约定**:对现 3 槽数据正确(weapon→attack、armor→armor、accessory→pick_one)。**若日后新增基底把次轴排到 [0]**,强化会作用错轴 → 在 `item_bases.json` 旁或 def 注释记一句「[0] = 主强化轴」约定。当前非阻塞。
- **🟡 F4 HP 带值夹紧手感**:进/出城 HP 不重置(守 i5)对玩家可能意外(「回城没回血」)。BALANCE-CHANGE-02 已定 v1 不回血;**playtest 确认**是否有「回城惩罚感」,若有再交 GD 加显式回血旋钮(走配置),非本计划。
- **🟡 F5 步 5b 范围较大**:换装 + 对比 + 强化三块 UI 一节,纯手动验。若实测体量过大,可在 Implementer 阶段把「换装+对比」与「强化」拆两个 pass 落地(都挂在步 1-5a 之上,互不阻塞)。美术 juice 走 Art Spec 下游。
- **🟢 进城时机**:v1 假定城镇在**挂机进行中**进入(有活跃 run);团灭修整态下进城,resume 行为沿用现有 progression 修整逻辑,不特殊处理。
