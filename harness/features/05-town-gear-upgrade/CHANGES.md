---
artifact: CHANGES
feature: 05-town-gear-upgrade
role: Implementer
status: draft
updated: 2026-06-19
inputs: [PLAN.md, arch/REFACTOR-03-town-meta-ops.md, balance/BALANCE-CHANGE-02-town-gear-upgrade.md, project-context.md, ARCHITECTURE.md, BALANCE.md]
next: Engine Integrator
---

# CHANGES — 05 城镇:手动换装 + 对比面板 + 装备强化

## 1. 摘要 / What & why
按 PLAN 五步依赖序落地(先逻辑后表现):①`ItemInstance += enhance_level`②`enhance.json`+`EnhanceConfigDef`
③`to_modifiers` 接强化加成 ④`PlayerState` 换装/强化元操作 ⑤`Game.pause_run/resume_run` + `TownView`。
前 4 步 + 5a 纯逻辑全 gdUnit4 覆盖,5b(`TownView`)纯表现层手动 Play。**全量 145/145 绿、0 orphan、现有测试无回归**(实现前 117+ → 现 145,新增 28 个用例)。

## 2. 改了哪些文件 / Files touched

### 新增
| 文件 | 内容 |
|------|------|
| `data/config/enhance.json` | 强化四常量配置(`per_level 0.10 / cap 10 / cost_base 1 / cost_step 1`),走配置不硬编码(hard-NO)。 |
| `src/core/data/enhance_config_def.gd` | `class_name EnhanceConfigDef`(RefCounted,只读蓝图)。字段 `per_level/cap/cost_base/cost_step` + 助手 `cost_for_level(L)=cost_base+cost_step×L`、`is_max(L)=L>=cap`。成本/上限单一真源,UI 与持久层共用。 |
| `src/combat/town_view.gd` | `class_name TownView`(extends Control)。MainArea 内城镇工作台(详见 §4 Wiring Contract)。 |
| `test/core/item_instance_test.gd` | 步1:`enhance_level` 序列化 round-trip + 旧档缺键→0(3 用例)。 |
| `test/core/enhance_config_test.gd` | 步2:`enhance.json` 干净加载 + 成本曲线 `1+L` + 满级判定 + 畸形配置报错(5 用例)。 |
| `test/core/item_enhance_modifier_test.gd` | 步3:强化件主轴多一条正确 FLAT、副轴 `attack_speed` 不被强化(守 i4)、`level=0` 无强化条、全 source=self(守 i1)(4 用例)。 |

### 修改
| 文件 | 改动 |
|------|------|
| `src/core/items/item_instance.gd` | 加 `var enhance_level: int = 0`;`to_dict`/`from_dict` 读写(缺省 0 旧档无缝)。`to_modifiers`:若 `enhance_level>0` 且有招牌轴,按 `base_value(signature_axes[0], ilvl) × cfg.per_level × enhance_level` 追加**一条 FLAT**(`source=self`)。仅主轴 → 天然排除 weapon 的 `attack_speed`(在 `[1]` 位)→ DPS 对强化等级线性(守 i4);FLAT 并入 ΣFlat 守 i2、随 source 精确卸下守 i1。 |
| `src/core/systems/data_registry.gd` | `load_all` 读第 5 份 `enhance.json`(顶层须对象);新增 `_ingest_enhance`(校验 `per_level>0 / cap≥1 / cost_base≥0 / cost_step≥0`)、`get_enhance_config()`、`ingest_enhance()`(测试喂内存)。`_enhance_config` 字段。 |
| `src/core/meta/player_state.gd` | 新增三元操作:`equip_from_bag(c,slot,item)`(背包件穿上,原件无损退包;城镇主动路径可替换,区别于挂机 i3 只增不替)、`unequip_to_bag(c,slot)`(脱下退包,空槽无操作)、`enhance_item(item,cfg)->bool`(满级/材料不足→拒绝且**不扣半截材料**;否则扣 `slot|white` 成本 +1 级,守 i7 确定性纯增益)。 |
| `src/core/game_controller.gd` | 新增 `pause_run()`(先 `_sync_party_equipment()` 把战斗中自动穿的装备冲回持久 `Character`、再 `arena.running=false`,守不变量 #11)、`resume_run()`(据持久 `Character` re-snapshot 玩家 Entity 吃下城镇换装/强化,**用冻结前 `current_hp` 夹 `[0,new_max]`**,守 i5 不免费回血;re-point `arena.loot_equipment`;`arena.running=true`)。 |
| `test/core/player_state_test.gd` | 步4:换装(交换/空槽/脱下)+ 强化(成功扣材料/`1+L` 成本曲线/材料不足不扣/满级拒绝)7 用例。 |
| `test/core/game_controller_test.gd` | 步5a:pause 冻结+收口、resume 保 HP 不回血、resume 吃下城镇换装 3 用例。 |

## 3. 关键决策落点 / Decision trace(对 PLAN)
| PLAN | 实际落点 |
|------|---------|
| D1 强化走 `to_modifiers` FLAT 仅主轴 | `item_instance.gd` to_modifiers,`signature_axes[0]`,守 i1/i2/i4/i7 ✅ |
| D2 四常量走 `enhance.json`+`EnhanceConfigDef` | 新配置 + 新 def + DataRegistry 加载/校验 ✅ |
| D3 元操作放 `PlayerState`,`cfg` 由调用方传入 | `enhance_item(item, cfg)` 不反向依赖 registry ✅ |
| D4 resume re-snapshot + HP 夹紧 + 先冲洗装备 | `pause_run`/`resume_run` 配对 ✅ |
| D5 `TownView` 挂 MainArea、读 Game、复用 8 维格式化 | `town_view.gd`,见 §4 ✅ |

## 4. Wiring Contract(交 Engine Integrator)

**目标**:把 `TownView` 挂进悬浮窗主区,让"进城/出城"可手动验收。逻辑零改动,只接场景。

### W1 — 在 `scenes/shell/floating_shell.tscn` 的 `MainArea` 下新增 `TownView` 节点
- **父**:`MainArea`(与现有 `CombatView` 平级,**排在 `CombatView` 之后** → 城镇遮罩叠在战斗视图上)。
- **节点名**:必须叫 `TownView`(脚本里无硬依赖名字,但 §W2 的查找依赖它在 `MainArea` 下;CombatView 名字被 TownView 用 `get_parent().get_node_or_null("CombatView")` 引用——**`CombatView` 节点名须保持 `CombatView` 不变**)。
- **type**:`Control`,挂脚本 `res://src/combat/town_view.gd`。
- **布局**:`anchors_preset = 15`(Full Rect,锚满 800×250 主区),同 CombatView。
- 无 `@export` 需在 Inspector 填(TownView 自建全部子节点,无外部资源依赖)。

### W2 — 自带的接线(TownView `_ready` 已做,EI 无需手接)
- `_gc = get_node_or_null("/root/Game")` — 读 autoload `Game`(GameController)。
- `_combat_view = get_parent().get_node_or_null("CombatView")` — 找同级战斗视图,进城时 `visible=false`、出城时 `true`。
- **进城**(点"进城"按钮):`Game.pause_run()` → 显城镇遮罩 + 隐 CombatView。
- **出城**(点"出城"按钮):`Game.resume_run()` → 隐遮罩 + 显 CombatView。
- 城镇遮罩 `mouse_filter = STOP` 吃掉点击,不漏到战斗层(同 04 的只读面板模式)。

### W3 — 前置依赖(必须已满足才有意义)
- `Game`(GameController)须为 autoload 且 `begin_run` 已开局(否则 `pause_run`/`resume_run` 的 `arena` 为空,二者已守空安全返回——但城镇对比/强化需要 roster 有角色)。**v1 单战士:`player_state.roster` 首个非空 Character 即操作对象。**
- 背包要有同槽可换件、材料桶 `slot|white` 要有量,换装/强化/对比才看得到效果(playtest 时可先挂机刷一会儿积累背包+材料,再进城)。

### W4 — 手动验收清单(EI 接好后人来点)
1. 战斗中点"进城" → 挂机冻结(敌人/血条不再动)、城镇工作台出现。
2. 左栏三槽点选 → 中栏显该槽强化信息(等级/成本/拥有材料)、右栏列该槽可换背包件。
3. 右栏某背包件下显**逐轴差值**:升绿↑、降红↓(对比面板)。点"换" → 装上、原件回背包、面板刷新。
4. 中栏"强化 +1":材料够则可点,点后等级 +1、材料扣 `1+L`、主轴数值上升;满 +10 显"已满级"且禁用;材料不足按钮置灰。
5. 点"出城" → 挂机恢复,**血量不回满**(沿用进城前的 HP),且城镇里换/强化的装备在战斗中生效(攻击/护甲等变化)。

## 5. 风险 / 已知限制
- **5b 未自动化测**:`TownView` 是表现层,按项目测试策略(纯逻辑才 gdUnit4)仅手动 Play 验。**底层数据通路(换装/强化/暂停恢复)已全 gdUnit4 覆盖**,TownView 只是其薄表现壳。
- **新 class_name 需 reimport**:新增 `EnhanceConfigDef`/`TownView` 后,首次 `--check-only`/测试前需跑一次 `godot --headless --import` 刷新全局类缓存(否则报"找不到类型")。EI 在编辑器打开会自动 reimport。
- **对比面板口径**:差值 = 「换上候选件后角色 8 维终值」−「当前终值」,经真实属性引擎算(克隆 Character 计算,不改原件),诚实反映整角色变化(含强化/affix/PERCENT 交互),非裸件对比。
- **材料偏富余**(BALANCE-CHANGE-02 §6 延伸):白材料产速 > 强化消耗,后期可能过剩 → 若 playtest 刺眼优先调 `enhance.json` 的 `cost_step`↑(陡化成本),不动产出。
