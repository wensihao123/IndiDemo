---
updated: 2026-06-19
---

# ARCHITECTURE — test-2 (2D 横版挂机 ARPG)

> 项目的**架构事实源**(Arch Guard 维护)。Planner / Game Designer 开新功能**之前**对照这里,
> 把"装不下旧结构"的不兼容提前拦下。它必须与真实代码一致;陈旧的架构比没有更糟。
>
> ✅ **REFACTOR-01 地基重构已落地(2026-06-19)。** 四层结构 = 当前真实代码:`src/core/{stats,items,combat,meta,systems,data}/*`
> 为组件化实体 + 模板/实例两层 + per-run 战斗 + autoload 持久根;旧单敌 `CombatDirector` 已删(仅留若干
> "承 combat_director" 出处注释)。表现层切换至 `Game`(GameController)autoload 已完成(步 5 §A–§F)。
> 全套 gdUnit4 **117/117、0 orphans、18 套**。后续单层细节(lane 几何 / 数值专章)仍在 §6 张力清单里。

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

> **座位约定(REFACTOR-02,2026-06-19):** 持久根 `PlayerState` 是 **autoload**(**节点名 = `Player`**,
> 不可用 `PlayerState`——会撞 `class_name` 致注册失败;`get_node("/root/Player") as PlayerState`),任何系统经全局单例直达;
> 单局编排座 `Game`(GameController,autoload)持有 per-run(arena/progression)+ 只读 `DataRegistry`,
> **读** PlayerState 但**不"拥有"**它。`DataRegistry` 故意保持 owned-RefCounted(非 autoload,见 §3.2/§6)。

## 2. 数据模型 / Data model

核心切分:**静态模板(只读蓝图)** vs **运行时实例(可序列化状态)**。

### 2.1 静态模板(只读;混合存储)
| 模板 | 存储 | 内容 |
|------|------|------|
| `EnemyDef` | `.tres`(现有,扩) | 怪基础 8 维 + 掉落权重 + `item_level` + **`position_class` enum{MELEE 近/RANGED 远}(默认 MELEE,REFACTOR-04 落实)** + sprite |
| `StageConfig` / `SceneConfig` | `.tres`(现有,扩) | `StageConfig`=3 普通场景 + Boss;`SceneConfig`=**一波多敌 `enemy_group: Array[EnemyDef]`(序=排位前→后)+ `kill_count`**(REFACTOR-04;旧 `enemy` 字段留作 fallback)。lane 几何留 §6 |
| `ItemBaseDef` | **JSON**(`data/config/item_bases.json`) | 装备基底:部位 / 招牌轴 / 基底值随 ilvl 曲线 |
| `AffixDef` | **JSON**(`data/config/affix_pool.json`) | 词缀:stat / kind(flat\|percent) / 各 Tier{区间, ilvl 门槛, weight} / 可出部位池 |
| `LootTableDef` | `.tres` 或 JSON | 部位 roll 权重 / 稀有度→词缀条数(白0/蓝1-2/金3+) / 分解门槛 |

> **存储分工(2026-06-19 定):** 少而要在 Inspector 调手感的(怪/实体/关卡) → `.tres`;海量、要 Claude
> 批量生成 + 肉眼 review 的(词缀库/装备基底)→ JSON。**内存里都是同一套带类型对象**,JSON 仅是磁盘作者格式。

### 2.2 运行时实例(可序列化)
- `ItemInstance` — `{ base_id(=slot), ilvl, rarity, signature_axes, affixes: Array[AffixRoll], enhance_level:int=0 }`;`AffixRoll = {stat, tier, value, kind}`。**掉落瞬间由 LootGenerator 生成**,可序列化。`enhance_level`(05 城镇强化态)默认 0、`from_dict` 缺省 0 → 旧档向后兼容;其属性贡献经 `to_modifiers(source=self)` 注入(见 §4#10)。
- `Character`(**持久**) — `{ id, 职业, base_stats(8 维裸值), equipped: {slot→ItemInstance}, level(later) }`。**存档单元。**
- 战斗 `Entity`(**per-run**) — **`RefCounted` 空壳**(F5:本拟 Node2D,但每场 new 敌实体会在 headless 测留 orphan → 退 RefCounted;表现层另挂可视 Node 引用本实体,不混入逻辑层),挂组件;每局从 `Character` 快照(或 `EnemyDef`)生成,战斗结束即弃。
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
| `DataRegistry` | **`Game` 持有(RefCounted,非 autoload)— 座位已定案(REFACTOR-03)** | 启动加载 + **校验** .tres/JSON 模板,对外发 def 对象;`Game._boot` 无条件创建 → `Game.registry` 恒可用(与是否有活跃战斗无关)。多消费者(05 城镇战斗外读模板)经 `Game.registry` 读或构造时注入,**不升 autoload**(immutable read-only 不值 autoload 座位 + 避 D4 数据层单测 orphan) |
| `LootGenerator` | 纯逻辑模块 | 模板→实例流水线:据 怪/ilvl/掉落表 roll `ItemInstance`(B-4 PoE 式 Tier) |
| `CombatArena` / `CombatResolver` | per-run | 编排一局:lane 站位、固定步长 tick、目标选择;伤害结算**委托 SkillComponent** |
| `ProgressionController` | per-run | 进度状态机(承现 director 的 PROGRESSING/GRINDING/倒计时/REST + 团灭回退 + Boss 解锁) |
| `PlayerState` | **autoload(持久根,节点名 `Player`)** | **持久** roster + 背包 + 材料库存 = 存档目标;有 `material_gained` 跨系统信号 + `reset()`(boot 时清态,守测试隔离)。节点名取 `Player` 避撞 `class_name PlayerState` |
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
7. **战斗站位 = 槽位/分路抽象**(2026-06-19 定):实体站抽象排位(前/后排 × 序)+ "接近→进射程→出手",**无真实 2D 自由移动 / 碰撞 / 抛射物**。守支柱 1"瞥一眼看懂"。**团战实现约定(REFACTOR-04):近战门控 = "前 G 名存活近战可出手、其余排队补位"(G=`CombatTuning.melee_gate_capacity`);远程不受门控(隔位恒可出手)。纯由数组序 + `position_class` 标签算得,仍无坐标/移动。**
8. **持久根经全局直达,不穿 `Game`**(REFACTOR-02,2026-06-19):`PlayerState` 是 autoload 唯一实例;非 per-run 消费者(城镇/存档/UI)读全局 `PlayerState`,**绝不**经 `Game.player_state` 反穿战斗编排座。`Game.player_state` 仅为战斗座自用的同实例缓存引用——**唯一对象、非第二份**。`Game` 持有 per-run + 只读 registry,不"拥有"持久态。
9. **续战游标据永久解锁判别"Boss 已通"**(F-SaveBoss,2026-06-19):Boss 清算的 autosave 落档时 `cur_scene` 仍 = `BOSS_SCENE`(游标待通关倒计时后 `ProgressionController._execute_push` 才推进),`max_unlocked_stage` 却已 +1。故 `GameController._boot` 续战读取须判别:**`saved cur_scene == BOSS_SCENE 且 max_unlocked_stage > cur_stage` ⇒ Boss 已通 ⇒ 续到 `(max_unlocked_stage, 0)`**(下一关开头);否则(`max == cur_stage` = 打一半就关)续回原 Boss 续打。判别唯一性靠"团灭回退只落普通场景、绝不把 cur_scene 设回更早关 Boss"保证。存档格式 / progression FSM 不参与此判别。
10. **强化贡献经同一 source 通道**(REFACTOR-03,05 城镇):`ItemInstance.enhance_level` 的属性贡献**必须**经 `to_modifiers` 产出的 `StatModifier(source=self)` 注入,**绝不**旁路直写 `Character.base_stats`/终值 —— 保证 i1 无损卸载、i2 属性合成式继续成立(脱下强化件,强化加成随之精确回收)。
11. **战斗外元操作只写持久层 + 出城 re-snapshot 不免费回血**(REFACTOR-03,05 城镇):城镇换装/强化**只写持久层**(`Character.equipped`/`PlayerState.bag`/`ItemInstance.enhance_level`),**不直接动活体 `Entity`/`EquipmentComponent`**(守不变量 4 持久层=事实源);`Game.pause_run/resume_run` 切 `arena.running`,出城恢复时据(已改的)`Character` **重建玩家 `Entity` 并把旧 `current_hp` 夹到 `[0,new_max]`**(守 i5:存活加差额、装备增量不治疗;"回城是否回血"是其上的设计旋钮,默认否)。
12. **战斗推进以"波清空"为粒度,刷怪不打断未清空的波**(REFACTOR-04,08 团战):敌方一场 = 一波多敌(`SceneConfig.enemy_group`)。`enemy_defeated`/掉落/击杀计数仍 **per-enemy**;但"刷下一波 / 推进场景 / 倒计时"只在 `not _has_living(enemies)`(或团灭回退 / 玩家推进)时触发,`ProgressionController._spawn_current` **绝不**在波未清空时替换 `arena.enemies`。守"一波多敌可逐个被清,而非杀一只就整波重刷"。**波 size=1 退化为旧单敌 director 行为,逐位等价**(向后兼容基线)。

## 5. 扩展点 / Extension points

- **新词缀 / 装备基底** = 往 JSON 池加一条,**不碰代码**(DataRegistry 校验后即生效)。
- **新职业 / 新怪** = 新 def + 组件组合,不改解算。
- **新能力(技能/被动/buff)** = 往 `Entity` 挂组件,经 `StatModifier` 接入 `StatsComponent`。
- **等级 / 经验(v2)** = `Character` 加 level + 成长曲线 → 写 base_stats;存档地基已就位(无需再重构)。
- **多敌团战** = lane 多实体已在地基内;**08 落实(REFACTOR-04)**:加 `SceneConfig.enemy_group` 多敌 + `EnemyDef.position_class` 近/远 + 近战门控,**并把刷怪/推进契约由 per-enemy 拆为 per-wave(新不变量 #12)**。波 size=1 向后等价。
- **真存档 / 多档 / 离线结算** = 扩 `SaveSystem`;持久层已是序列化目标。
- **战斗外元操作(换装 / 强化 / 未来分解)= 持久层缝**(REFACTOR-03,05 城镇):作用于 `Character.equipped`/`PlayerState.bag`/`ItemInstance`(含 `enhance_level`),由**持久层**承载(`PlayerState`/`Character` 方法或薄 meta service),供**表现层城镇**调用;对比差值 = 只读 `to_modifiers(Game.registry)` 求和。**绝不放进 per-run 战斗层**(守不变量 4/11)。

## 6. 已知张力与债 / Known tensions & debt

- **【已落地】整体地基重构**(REFACTOR-01)完成:02/03 的 6 维公式已搬入 `SkillComponent`(值不变)、单敌 director 换为 `CombatArena`+`ProgressionController`+组件、表现层切 `Game` autoload(步 5 §A–§F)。`src/combat/*` 现仅剩表现层 `combat_view.gd` + def 资源(`enemy_def`/`stage_config`/`scene_config`)。**残留代码注释债**:`enemy_def.gd:9`、`stage_config.gd:4` 仍写"逻辑在 CombatDirector",为陈旧出处注释(逻辑已在 skill_component/progression_controller),留 Implementer drive-by-safe 顺手修。
- **Producer 待回写**:本目标把 BACKLOG 的"团战/演出"与 project-context"符号式 v1"提前了(用户 2026-06-19 拍 scope call);需更新 BACKLOG scope line + project-context §1 语言/§2 目录约定/v1 完成定义。
- **表现层依赖正式美术** — `AnimationComponent` 序列帧需 Art Spec 出 asset;符号/占位先行,不阻塞数值地基。
- **lane 布局是新设计** — 档位数(几排/一波几位)、站位几何、接近时长待 playtest 定;ARCHITECTURE 只定"槽位抽象"原则,具体值留数值专章。**08(REFACTOR-04)落实了"一波多敌 + 近/远 + 近战门控"这层(纯数组序+标签,守 #7);真 lane 几何 / 接近时长 / 一场多波编排仍留作未来债。**
- **组件 Node vs RefCounted —【已决 F5】**:`Entity` + 逻辑组件(Stats/Equipment/Skill/AICombat)全 `RefCounted`,由 `CombatArena` 直接方法调用驱动(不靠 `_process`,保 headless 确定 + 免 orphan);`AnimationComponent` 等表现节点在层 6 树内另挂、引用战斗实体但不混入逻辑。
- **save 格式版本化** — 以后加字段需版本号 + 迁移;留 `SaveSystem` 设计,本期内存态先行。
- **JSON 校验严格度** — DataRegistry 校验是防策划数据错的第一道闸,别偷懒(类型/门槛/部位池合法性)。
- **✅ `DataRegistry` 座位已定案(REFACTOR-03,2026-06-19)** — 05-town 把它变多消费者,复审结论 = **维持 owned-RefCounted,不升 autoload**:城镇经 `Game.registry`(`Game._boot` 无条件创建、恒可用)读或构造时注入。理由:immutable read-only 蓝图不值 autoload 座位,且 Node-autoload 会重引 D4 数据层单测 orphan。原则不变(autoload 只留给可变持久/发信号的根 `PlayerState`,只读依赖保持 owned)。**§6 复审债闭合。**
- **`PlayerState` autoload 测试隔离(REFACTOR-02)** — autoload 在测试进程内持久,故 `_boot` 须 **reset-on-boot**(`player_state.reset()` 清 roster/bag/材料后再 load/默认 roster);"重启"语义用 reset+load 表达,比"new 第二个 GameController"更忠实(证存档文件而非内存残留驱动恢复)。落地见 `arch/REFACTOR-02-playerstate-seat.md` §4 = 步 5 §0。
