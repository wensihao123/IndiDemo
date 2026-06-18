---
artifact: REFACTOR
feature: cross-cutting
role: Arch Guard
status: draft
updated: 2026-06-19
inputs: [ARCHITECTURE.md, project-context.md, BACKLOG.md, feedbacks/Refactor-Ideas.md, src/combat/combat_director.gd, src/combat/party_member.gd, src/combat/enemy_def.gd, src/combat/scene_config.gd, src/combat/stage_config.gd, src/combat/combat_view.gd, 04-loot-equipment/FEATURE-DESIGN.md, 04-loot-equipment/PLAN.md, 04-loot-equipment/CONTEXT-FINDINGS.md, project.godot]
next: Planner
---

# REFACTOR-01 — 底层地基重设计 (Foundation Redesign)

> 跨多 feature 的整体地基重构。承用户 `feedbacks/Refactor-Ideas.md` 的架构愿景 + 2026-06-19 三项 scope 拍板。
> 本文 = 根因诊断 + 目标形态(已落 ARCHITECTURE.md) + **有序结构性迁移策略** + 影响面 + 风险/被否选项。
> **策略级,不写代码 / 不写文件级步骤**(那是 Planner 的 PLAN)。

## 1. 触发 / Trigger

表面触发 = **04-loot-equipment 装不进现结构**(PLAN 要给 `PartyMember` 临时补 `_base` 快照、新建 Inventory autoload、打 K6 current_hp 补丁——全是往"没为持久角色设计的结构"上拧螺丝)。
深层触发 = 用户决定**整体重铺底层**(`Refactor-Ideas.md`):组件化实体 + 模板/实例两层 + modifier 属性 + PoE 装备流水线,并把战斗扩成 lane 多敌团战。
**时机最干净:04 尚未实现(`CHANGES` 空、`src/loot/` 不存在)、项目无任何存档历史 → 无玩家数据迁移负担。**

## 2. 现状诊断 / Diagnosis

`CombatDirector`(autoload `Combat`,~440 行)是 **God object**,一身揽下:①队伍数据 ②敌人单实例运行时 ③进度状态机 ④战斗数值解算 ⑤掉落 roll ⑥tick 驱动。`PartyMember` 的 8 维是**扁平最终值**字段,由 director 每局用 `@export warrior_*` **重建**。

**根因(一根):项目没有「持久元状态」与「单局战斗模拟」的分层。** director 既当持久数据的家、又每局重建队伍;一旦功能需要"跨局存在的角色状态"(装备/材料/等级/存档),就与"director 拥有并每局重建队伍"正面冲突。三处放大:

- **R1 · 无属性分层** — 字段即生效值,无 base/装备/buff 来源区分 → 装备汇总要 retrofit、脱装易残留、`@export warrior_*` 与"开局白装基底"语义双重计数(04 CONTEXT-FINDINGS C-C 已记)。
- **R2 · 无持久层** — 一切每局从 `@export` 重建,没有可序列化的家 → 04 装备、05 城镇、07 存档、v2 等级全卡在这;BACKLOG 自记"跨局保留依赖 07 存档(现队伍每局由 director 重建)"。
- **R3 · 单敌硬编码 + 数据/逻辑/表现纠缠** — 敌人是 director 上的 `_enemy_def`+`_enemy_hp` 单实例(队伍却是数组);战斗解算、进度、掉落、tick 全挤在一个文件 → 团战(v2)、空间化战斗无处落地。

## 3. 目标形态 / Target shape

**完整目标见 `harness/ARCHITECTURE.md`(本次新建)。** 相对现状的 delta:

| 维度 | 现状 | 目标 |
|------|------|------|
| 分层 | director 一锅端 | 数据层 / 持久层 / 单局战斗层 / 表现层,依赖单向 |
| 属性 | 扁平最终值字段 | `StatsComponent`:`Final=(Base+ΣFlat)×(1+ΣPercent)` + 脏标记;modifier 无损卸载 |
| 实体 | `PartyMember`(RefCounted,director 持有) | 组件化 `Entity` 空壳(Stats/Equipment/Skill/AICombat/Animation),玩家与怪共享 |
| 持久 | 无,每局重建 | `PlayerState` autoload(roster + 背包 + 材料)= 存档目标;`SaveSystem` |
| 数据 | 仅 .tres | 混合:.tres(怪/实体/关卡)+ JSON(海量词缀/基底),`DataRegistry` 加载校验 |
| 装备 | 无 | `ItemBaseDef`/`AffixDef`(模板)→ `LootGenerator` roll → `ItemInstance`(实例) |
| 敌方 | 单实例 | lane 多实体 + 目标选择(团战在地基内) |
| 战斗结构 | director 解算单敌 | `CombatArena` 编排,伤害委托 `SkillComponent`(02/03 六维公式搬入);`ProgressionController` 承 FSM |
| 战斗位置 | 无空间 | 槽位/分路抽象(前/后排,接近→射程→出手),非真实 2D 物理 |

**保留不丢:** 02/03 的 6 维公式(护甲减伤/闪避/暴击/秒回/软狂暴/攻速 cadence)、固定步长后台 tick、掉落事件→稀有度模型、Boss 解锁/团灭回退 FSM、04 设计的 B-4 PoE Tier roll、`FloatingShell` 悬浮窗外壳(不动)。

## 4. 调整策略 / Strategy(依赖序,逐层落定再上一层,中途不断)

> 策略级层序;**Planner 据此拆成有序可验证 PLAN**(每层带验证 + 回归锚)。不建议一锅端成单个 PLAN。

1. **数据层地基** — `DataRegistry` autoload + def 类型;保留 `EnemyDef`/`StageConfig`(.tres),新增 `ItemBaseDef`/`AffixDef`(JSON)+ 加载**校验**。不接战斗。
2. **属性引擎** — `StatsComponent`(modifier 列表 + 脏标记)+ `StatModifier`。**独立可测**;把 02/03 数值测改造成读 StatsComponent。
3. **持久层** — `Character` + `PlayerState` autoload(背包/材料)+ `EquipmentComponent`(穿脱→注入/回收 modifier)。先内存态,数据设计成可序列化。
4. **掉落流水线** — `LootGenerator`(模板→`ItemInstance`,承 04 B-4 PoE roll)。纯逻辑测(ilvl 门槛/词缀不重复/部位池/稀有度→条数)。
5. **战斗层重构** — `Entity` 空壳 + `SkillComponent`(搬入 6 维公式)+ `AICombatComponent`(lane 站位/目标选择/多敌)+ `CombatArena` 编排;`ProgressionController` 承 FSM。战斗实体**从 roster 快照 + EnemyDef 生成**。**此步替换 `CombatDirector`。**
6. **表现层** — `AnimationComponent` + `CombatView` 改读新事件;符号/占位先行(正式序列帧待 Art Spec)。
7. **存档** — `SaveSystem` 序列化 `PlayerState`(队伍/背包/材料/进度)。
8. **接线 + 全回归** — `project.godot` 重注册 autoload(`Combat` → 新系统集)、迁现有 .tres、跑全 gdUnit4 + `--headless --check-only` + 手动 Play 端到端。

## 5. 影响面与迁移 / Blast radius & migration

- **几乎重写 `src/combat/*`**:`combat_director.gd` 拆成 `CombatArena`+`ProgressionController`+`SkillComponent`;`party_member.gd` → `Entity`+组件;`loot_stub.gd` 弃。`enemy_def.gd`/`stage_config.gd`/`scene_config.gd` 保留并扩(lane/item_level)。
- **新增**:`src/core/{components,systems,entities,data}/`、`src/meta/`(或 systems 内)`player_state.gd`、`data/config/*.json`、`scenes/autoload/*`。具体目录由 Planner 定,建议同步更新 project-context §2。
- **`project.godot`**:autoload 由单 `Combat` 改为多系统(`DataRegistry`/`PlayerState` 等)= **引擎侧人工点,必经 Engine Integrator**。
- **测试**:02/03 的 45 用例需改造(读 StatsComponent / Arena 而非 director 字段),**但公式断言值不变** = 回归锚;新增 stats/loot/equip/arena 测试。
- **不动**:`floating_shell.gd` / `floating_shell.tscn`(纯窗口外壳)。
- **迁移负担为零**:无存档历史、无玩家数据;现有 `stage_01/02.tres` 数据可平移(扩字段取默认)。
- **04-loot-equipment 现有 PLAN 作废重排**:B-4 设计 + LootTables + Tier 表**有效保留**;但"retrofit 到 PartyMember"的接线方式被新地基取代(装备→`EquipmentComponent`→`StatsComponent` modifier),04 的实现并入本重构第 3-4 层。

## 6. 风险与被否选项 / Risks & rejected alternatives

**风险**
- **大爆炸重写** → 缓解:§4 分层有序、每层独立可测、保留 02/03 公式 + 测试做回归锚、无数据迁移负担;Planner 切成多 PLAN 分批落、每批全绿再下一批。
- **撞 v1 符号式 / hard-NO"不为 v2 提前抽象"** → 用户已知情拍 Producer 级 scope call("打好基础,以后添砖加瓦快");**须回写 BACKLOG + project-context**(标 Producer,见 §7)。
- **GDScript 组件化节点开销** → lane 抽象档已限复杂度;Stats 等纯算组件可 RefCounted,只表现/tick 组件用 Node(ARCHITECTURE §6 软决策)。
- **JSON 失类型/校验** → `DataRegistry` 启动校验为强制闸(类型/门槛/部位池合法性)。

**被否选项**
- **只补 04 地基(最小 retrofit)** → 用户否(要完整重构);且 07 存档时多半再搬一次。
- **转 C#**(Refactor-Ideas 字面) → 否:弃 02/03 战斗 + 45 测试 + 撞 project-context 语言约定。
- **真实 2D 物理战斗**(自由移动/碰撞/抛射) → 否:伤支柱 1"瞥一眼看懂"、对 800×250 悬浮窗偏重。
- **全 JSON / 全 .tres** → 否:混合取两者长(.tres 调手感 + JSON 利 Claude 批量生成词缀)。

## 7. 交接 Planner / Handoff

- **把 §4 八层拆成有序可验证 PLAN**(建议分批:数据→属性→持久→掉落=第一批可纯逻辑收口;战斗→表现→存档=第二批),每步带验证 + F4 式回归清单(守 02/03 公式断言不破)。
- **04-loot-equipment**:现有 PLAN 标 superseded,B-4 设计/LootTables/Tier 表移植进本重构第 3-4 层;Game Designer 的 FEATURE-DESIGN 仍是装备数值设计来源。
- **Producer 待办(本重构产生,非 Planner 落地项)**:更新 BACKLOG scope line(团战/演出/存档提前进 v1 地基)+ project-context(§1 确认 GDScript、§2 目录约定、v1 完成定义)。
- **引擎侧人工点**:autoload 重注册 + JSON/`.tres` 资源指派 → 第 8 层经 Engine Integrator 人机回报闭环。
- **数值全占位**:lane 几何、词缀完整 Tier 表、属性成长曲线 → 与 03/04 的 F1 合并成总数值专章。
