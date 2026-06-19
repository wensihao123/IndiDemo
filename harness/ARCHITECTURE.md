---
updated: 2026-06-19
---

# ARCHITECTURE — test-2 (2D 横版挂机 ARPG)

> 项目的**架构事实源**(Arch Guard 维护)。Planner / Game Designer 开新功能**之前**对照这里,
> 把"装不下旧结构"的不兼容提前拦下。它必须与真实代码一致;陈旧的架构比没有更糟。
>
> ⚠ **本文描述的是 2026-06-19 拍板的「目标地基」,尚未落地。** 现有 `src/combat/*`(02/03 收口
> 的单敌 director 战斗)是**被本目标取代的现状**;迁移策略见 `harness/arch/REFACTOR-01-foundation-redesign.md`。
> 迁移完成前,代码现状 = §6 标注的"待迁移现状";迁移每推进一层,回写本文对应小节。

## 1. 架构一句话 / Overview

组件化实体 + **模板/实例两层数据** + **持久元状态 与 单局战斗模拟 分层** + **表现与逻辑分离(headless 可演算)**。
四个层,依赖只能自上而下,严禁反向:

```
[表现层]  CombatView / AnimationComponent        —— 只读状态、监听事件,不参与任何数值
   ▲ (监听 signal)
[单局战斗层] CombatArena / ProgressionController   —— per-run,可弃;从持久层快照生成战斗实体
   ▲ (读快照)
[持久元状态层] PlayerState(autoload) / SaveSystem  —— 跨局存在、= 存档目标:roster + 背包 + 材料
   ▲ (读模板)
[数据层]  DataRegistry(Game 持有·RefCounted) + 静态模板  —— 只读蓝图:.tres + JSON,启动加载校验
```

> **座位约定(REFACTOR-02,2026-06-19):** 持久根 `PlayerState` 是 **autoload**,任何系统经全局单例直达;
> 单局编排座 `Game`(GameController,autoload)持有 per-run(arena/progression)+ 只读 `DataRegistry`,
> **读** PlayerState 但**不"拥有"**它。`DataRegistry` 故意保持 owned-RefCounted(非 autoload,见 §3.2/§6)。

## 2. 数据模型 / Data model

核心切分:**静态模板(只读蓝图)** vs **运行时实例(可序列化状态)**。

### 2.1 静态模板(只读;混合存储)
| 模板 | 存储 | 内容 |
|------|------|------|
| `EnemyDef` | `.tres`(现有,扩) | 怪基础 8 维 + 掉落权重 + `item_level` + 站位类别(近/远) + sprite |
| `StageConfig` / `SceneConfig` | `.tres`(现有,扩) | 关卡 / 波次 / lane 布局(一波几个、站哪排) |
| `ItemBaseDef` | **JSON**(`data/config/item_bases.json`) | 装备基底:部位 / 招牌轴 / 基底值随 ilvl 曲线 |
| `AffixDef` | **JSON**(`data/config/affix_pool.json`) | 词缀:stat / kind(flat\|percent) / 各 Tier{区间, ilvl 门槛, weight} / 可出部位池 |
| `LootTableDef` | `.tres` 或 JSON | 部位 roll 权重 / 稀有度→词缀条数(白0/蓝1-2/金3+) / 分解门槛 |

> **存储分工(2026-06-19 定):** 少而要在 Inspector 调手感的(怪/实体/关卡) → `.tres`;海量、要 Claude
> 批量生成 + 肉眼 review 的(词缀库/装备基底)→ JSON。**内存里都是同一套带类型对象**,JSON 仅是磁盘作者格式。

### 2.2 运行时实例(可序列化)
- `ItemInstance` — `{ base: ItemBaseDef, ilvl, rarity, affixes: Array[AffixRoll] }`;`AffixRoll = {stat, tier, value, kind}`。**掉落瞬间由 LootGenerator 生成**,唯一可序列化。
- `Character`(**持久**) — `{ id, 职业, base_stats(8 维裸值), equipped: {slot→ItemInstance}, level(later) }`。**存档单元。**
- 战斗 `Entity`(**per-run**) — Node2D 空壳,挂组件;每局从 `Character` 快照(或 `EnemyDef`)生成,战斗结束即弃。
- `StatModifier` — `{ stat, kind(FLAT|PERCENT), value, source }`;装备/buff 往 `StatsComponent` 注入。

**不变量:模板只读绝不写回;`Character`/`ItemInstance`/背包/进度 = 跨局保留;战斗 `Entity` 每局可弃。**

## 3. 模块边界与依赖 / Module boundaries & dependencies

### 3.1 组件(挂在战斗 `Entity` 空壳上;玩家与怪共享同一套)
| 组件 | 职责 | 边界 |
|------|------|------|
| `StatsComponent` | 持 base + modifier 列表;`Final = (Base + ΣFlat) × (1 + ΣPercent)`,脏标记缓存;对外**只读**最终值 | 不知道装备/技能存在,只认 modifier |
| `EquipmentComponent` | 管槽位;穿/脱 `ItemInstance` → 向 `StatsComponent` 注入/回收 modifier(**无损卸载**) | 只翻译"装备→modifier",不算最终值 |
| `SkillComponent` | 读 `StatsComponent` 最终值;普攻/技能的**射程判定 / CD / 伤害结算**(02/03 的 6 维公式搬入此处) | 不碰动画/位置移动;只出"对谁造成多少" |
| `AICombatComponent` | 轻量状态机:寻敌 / 接近(lane)/ 进射程 / 出手 / 目标选择(集火/AoE) | 不算伤害(委托 Skill);不播动画 |
| `AnimationComponent` | 监听 AI/Skill 事件播序列帧,**纯表现** | **绝不参与数值**;缺席不影响演算 |

### 3.2 全局系统
| 系统 | 形态 | 职责 |
|------|------|------|
| `GameController`(`Game`) | **autoload** | **单局编排座 + boot 入口**:读全局 `PlayerState`、持有 `DataRegistry`+per-run `arena`/`progression`,装配并驱动一局;autosave。**不"拥有"持久态**(REFACTOR-02) |
| `DataRegistry` | **`Game` 持有(RefCounted,非 autoload)** | 启动加载 + **校验** .tres/JSON 模板,对外发 def 对象;经 `Game.registry` 可达(D4:Node-autoload 会令数据层单测留 orphan,故 owned;05-town 需战斗外读模板时复审,见 §6) |
| `LootGenerator` | 纯逻辑模块 | 模板→实例流水线:据 怪/ilvl/掉落表 roll `ItemInstance`(B-4 PoE 式 Tier) |
| `CombatArena` / `CombatResolver` | per-run | 编排一局:lane 站位、固定步长 tick、目标选择;伤害结算**委托 SkillComponent** |
| `ProgressionController` | per-run | 进度状态机(承现 director 的 PROGRESSING/GRINDING/倒计时/REST + 团灭回退 + Boss 解锁) |
| `PlayerState` | **autoload(持久根)** | **持久** roster + 背包 + 材料库存 = 存档目标;有 `material_gained` 跨系统信号 + `reset()`(boot 时清态,守测试隔离) |
| `SaveSystem` | 系统 | 序列化 `PlayerState` |

### 3.3 允许的依赖方向(**严禁反向**)
- 表现层 → 战斗层 / 持久层(只读 + 监听 signal);
- 战斗层 → 持久层(读 `Character` 快照)+ 数据层;
- 持久层 → 数据层;
- 系统 → 数据层;
- 组件:同 `Entity` 内可直调,跨实体 / 跨系统用 **signal**;
- **数据层不依赖任何;持久层不依赖战斗层;逻辑层不依赖表现层。**

## 4. 关键不变量与约定 / Invariants & contracts

1. **模板只读** — 静态 def 绝不在运行时写回(现有 `EnemyDef` 已守;`CombatDirector` 用单场运行时状态隔离,延续此约定)。
2. **属性永远重算,绝不直写最终值** — 一切生效属性 = `base + Σmodifier` 经 §3.1 公式;根除脱装/buff 残留 bug。
3. **headless 可演算、帧率无关** — 固定步长 tick(承现 `tick_seconds` 累加器);收起 15fps / 展开 60fps / 后台,结算一致;表现层缺席不影响数值。
4. **跨局只保留持久层** — `Character`/背包/材料/进度可序列化跨局;战斗 `Entity` 每局从快照重建、可弃。
5. **信号过去式;跨系统 signal,实体内直调**(承 project-context §3)。
6. **数值/路径不硬编码** — 全走 `.tres`/JSON 配置(hard-NO);新增 `DataRegistry` 校验为第一道闸。
7. **战斗站位 = 槽位/分路抽象**(2026-06-19 定):实体站抽象排位(前/后排 × 序)+ "接近→进射程→出手",**无真实 2D 自由移动 / 碰撞 / 抛射物**。守支柱 1"瞥一眼看懂"。
8. **持久根经全局直达,不穿 `Game`**(REFACTOR-02,2026-06-19):`PlayerState` 是 autoload 唯一实例;非 per-run 消费者(城镇/存档/UI)读全局 `PlayerState`,**绝不**经 `Game.player_state` 反穿战斗编排座。`Game.player_state` 仅为战斗座自用的同实例缓存引用——**唯一对象、非第二份**。`Game` 持有 per-run + 只读 registry,不"拥有"持久态。

## 5. 扩展点 / Extension points

- **新词缀 / 装备基底** = 往 JSON 池加一条,**不碰代码**(DataRegistry 校验后即生效)。
- **新职业 / 新怪** = 新 def + 组件组合,不改解算。
- **新能力(技能/被动/buff)** = 往 `Entity` 挂组件,经 `StatModifier` 接入 `StatsComponent`。
- **等级 / 经验(v2)** = `Character` 加 level + 成长曲线 → 写 base_stats;存档地基已就位(无需再重构)。
- **多敌团战** = lane 多实体已在地基内,加波次配置即可。
- **真存档 / 多档 / 离线结算** = 扩 `SaveSystem`;持久层已是序列化目标。

## 6. 已知张力与债 / Known tensions & debt

- **【迁移中】这是整体地基重构**(REFACTOR-01)。现状 `src/combat/*` = 单敌 director,**待迁移**;02/03 的 6 维**公式保留**、只换承载结构(单敌→lane 多实体、director→组件)。迁移每层须保 45 个 gdUnit4 用例改造后回归通过。
- **Producer 待回写**:本目标把 BACKLOG 的"团战/演出"与 project-context"符号式 v1"提前了(用户 2026-06-19 拍 scope call);需更新 BACKLOG scope line + project-context §1 语言/§2 目录约定/v1 完成定义。
- **表现层依赖正式美术** — `AnimationComponent` 序列帧需 Art Spec 出 asset;符号/占位先行,不阻塞数值地基。
- **lane 布局是新设计** — 档位数(几排/一波几位)、站位几何、接近时长待 playtest 定;ARCHITECTURE 只定"槽位抽象"原则,具体值留数值专章。
- **组件是 Node 还是 RefCounted** — 倾向 Node2D `Entity` + Node 子组件(AnimationComponent 必在树内;AICombat 需 tick);纯算组件(Stats)可 RefCounted。**软决策,留 Planner/Implementer 定。**
- **save 格式版本化** — 以后加字段需版本号 + 迁移;留 `SaveSystem` 设计,本期内存态先行。
- **JSON 校验严格度** — DataRegistry 校验是防策划数据错的第一道闸,别偷懒(类型/门槛/部位池合法性)。
- **`DataRegistry` 座位待复审(REFACTOR-02)** — 现为 `Game` 持有的 RefCounted(只读、当前仅战斗座消费、免 Node-orphan 测试摩擦)。**原则:autoload 留给真正全局/多消费者/可变持久或发信号的根(PlayerState),只读单消费者依赖保持 owned**。**复审点:05-town 打造需在战斗外读模板时,DataRegistry 变多消费者 → 届时定"升 autoload(测试自 free)还是注入",别现在提前抽象(守 hard-NO)。**
- **`PlayerState` autoload 测试隔离(REFACTOR-02)** — autoload 在测试进程内持久,故 `_boot` 须 **reset-on-boot**(`player_state.reset()` 清 roster/bag/材料后再 load/默认 roster);"重启"语义用 reset+load 表达,比"new 第二个 GameController"更忠实(证存档文件而非内存残留驱动恢复)。落地见 `arch/REFACTOR-02-playerstate-seat.md` §4 = 步 5 §0。
