---
artifact: REFACTOR
feature: 05-town-gear-upgrade
role: Arch Guard
status: draft
updated: 2026-06-19
inputs: [ARCHITECTURE.md, BALANCE.md, project-context.md, features/05-town-gear-upgrade/FEATURE-DESIGN.md, features/05-town-gear-upgrade/HANDOFF.md, src/core/items/{item_instance,equipment_component}.gd, src/core/stats/{stat_modifier,stats_component}.gd, src/core/systems/{data_registry,save_system}.gd, src/core/meta/{player_state,character}.gd, src/core/{game_controller}.gd, src/core/combat/{entity,combat_arena}.gd]
next: Planner
---

# REFACTOR-03 — 05 城镇:强化态 + 战斗外元操作 + 暂停/恢复

## 0. 判定(先说结论)
**05 装得下当前四层架构 —— 全部加性扩展,无推倒式重构、无边界搬迁、无依赖反向。** 三个触发点都落在
**已有缝**上:① 强化骑 `ItemInstance.to_modifiers(source=self)` 这条既有属性引擎缝;② `DataRegistry`
座位**维持现状**(本案正式否决"升 autoload",闭合 ARCHITECTURE §6 复审债);③ 暂停/恢复用 `arena.running`
既有开关 + `Game` 加一个编排 API。本文记录这三处**决策 + 一条新契约(出城回血口径)**,作为 Planner 的目标形态。

## 1. 触发 / Trigger
05-town 引入三件结构性诉求:**(a) 装备强化等级**(给可序列化 `ItemInstance` 加态并接入属性引擎);
**(b) 战斗外读写持久态/模板**(换装/对比/强化在挂机之外发生,`DataRegistry` 由单消费者变多消费者
—— ARCHITECTURE §6 预埋的复审点);**(c) 进城暂停挂机、出城恢复**(per-run 战斗态的冻结/解冻 + 玩家
在城镇改了装备后如何生效)。用户已拍:城镇=独立界面、强化=独立"强化等级"加成、强化作用所有装备,
并明示"牵扯结构修改先 arch 审计"。

## 2. 现状诊断 / Diagnosis
逐条对照真实代码,看现结构能否承接,根因在哪:

**(a) 强化等级 —— 数据模型 + 属性引擎接入**
`ItemInstance`(`item_instance.gd`)现有字段 `{base_id, ilvl, rarity, signature_axes, affixes}`,其
**全部终值贡献已统一收口于一个方法**:`to_modifiers(registry) -> Array[StatModifier]`,每条 modifier 的
`source = self`(本实例)。`EquipmentComponent.equip` 注入这批 modifier、`unequip` 按 `source` 精确回收
(无损,i1)。`StatsComponent` 终值 = `(base+Σflat)×(1+Σpercent)`(i2)。
→ **根因层面:这里没有冲突。** 强化只需 `ItemInstance` 多一个可序列化字段 `enhance_level`,并让
`to_modifiers` 据它**多摊几条(或放大招牌轴的)`StatModifier`(source 仍 = self)**。无损卸载、属性合成式
**天然继续成立**(强化贡献和装备贡献走同一条 source=self 通道,一并卸下)。这正是 ARCHITECTURE §5 已写的
扩展点"新能力 = 经 `StatModifier` 接入 `StatsComponent`"。**属加性扩展,非重构。**

**(b) DataRegistry 座位 —— 单 → 多消费者**
`DataRegistry`(`data_registry.gd`)现为 `Game` 持有的 **RefCounted(非 autoload)**,只读、加载后不可变、
不发信号。当前消费者:`Game` 自身 + 注入给 `arena.registry` + 经 `EquipmentComponent._registry` 传进
`ItemInstance.to_modifiers(registry)`。**关键事实:`Game._boot()` 无条件创建并加载 `registry`**(在
`begin_run` 之前、与是否有活跃战斗无关)→ **只要 `Game` boot 过,`Game.registry` 恒可用。**
城镇是**表现层**消费者(像 `CombatView` 一样挂在 shell 下),要在战斗外读模板:算对比差值、算强化预览
(`to_modifiers(registry)` 求和)。`CombatView` 现已经 `Game`(autoload)读 `arena`/`player_state`。
→ **根因层面:也没有冲突。** 城镇可走**同一条路**读 `Game.registry`(或构造时注入一份只读引用),
**无须把 `DataRegistry` 升成 autoload**。§6 原则本就是"autoload 只留给真正全局/可变持久/发信号的根
(`PlayerState`),只读依赖保持 owned";且 autoload 必须是 Node,会**重新引入 D4 极力规避的数据层单测 orphan**。

**(c) 暂停/恢复 + 城镇改装如何生效**
`CombatArena` 有 `running` 标志,`_process` 仅在 `running` 时推进 tick(`combat_arena.gd:26/72-73`)。
→ **暂停 = `running=false` 冻结 per-run 模拟在内存原地;恢复 = `running=true`。** 无需序列化、无丢失。
**真正的张力在这里**:玩家活体 `Entity` 是 `begin_run` 时由 `Entity.from_character` **快照**出来的
(`game_controller.gd:77`、`entity.gd:55-62`);城镇改的是**持久层** `Character.equipped` / `bag` /
`ItemInstance.enhance_level`。若只 `running=true` 恢复,**活体 Entity 仍是旧快照,城镇里的变强不生效**,
要等下一次 `begin_run` 才反映 —— 与 fantasy"调强了再出去打"直接矛盾。
另一记暗礁:`Entity.from_character` 末行 `current_hp = max_hp()`(满血)。若出城用 re-snapshot 让改装生效,
**朴素 rebuild 会顺带满血 → 城镇变成免费回血站**,违反 i5 精神(`装备增量不偷偷治疗`)。

## 3. 目标形态 / Target shape(delta vs ARCHITECTURE.md)
**§2 数据模型 — `ItemInstance` 加一字段:**
- `ItemInstance += enhance_level: int = 0`(可序列化)。`to_dict/from_dict` 带上;`from_dict` **缺省 0**
  → **旧档向后兼容**(老物品读成未强化)。`to_modifiers(registry)` 据 `enhance_level` 追加/放大
  `StatModifier`(source 仍 = self,具体公式 = num-smith 的 F-NUM,架构不定数)。

**§3.2 全局系统 — `DataRegistry` 座位定案(闭合 §6 复审债):**
- **维持 owned-RefCounted,不升 autoload。** 多消费者(城镇)经**其拥有者 `Game` 暴露的只读引用
  `Game.registry`** 获取,或在城镇构造时注入同一引用。理由:immutable read-only 蓝图不值得一个 autoload
  座位,且 Node-autoload 会重新引入数据层单测 orphan(D4)。

**§4 不变量 — 新增两条契约:**
- **(新)强化经同一 source 通道**:`enhance_level` 的属性贡献**必须**经 `ItemInstance.to_modifiers`
  产出的 `StatModifier(source=self)` 注入,**绝不**旁路直写 `Character.base_stats` 或终值 —— 保证 i1
  无损卸载、i2 属性合成式继续成立(脱下强化件,强化加成随之精确回收)。
- **(新)出城恢复 = 玩家侧 re-snapshot 且不免费回血**:城镇**只写持久层**(`Character.equipped` /
  `PlayerState.bag` / `ItemInstance.enhance_level`),**不直接动活体 `Entity`/`EquipmentComponent`**
  (守 i4#4 持久层是事实源、per-run 可弃)。出城恢复时由 `Game` **据(已改的)`Character` 重建玩家
  `Entity`,并把旧 `current_hp` 带过去夹到 `[0, new_max]`(i5:存活加差额、死亡不复活、**装备增量不治疗**)。
  敌方/战场进度(`progression.cur_stage/cur_scene`)不受影响。

**§5 扩展点 — 新增"战斗外元操作"缝:**
- **换装/强化/(未来分解)= 持久层元操作**:作用于 `Character.equipped` / `PlayerState.bag` /
  `ItemInstance`,由**持久层**承载(`PlayerState`/`Character` 上的方法,或一个薄 meta service),供
  **表现层城镇**调用。**绝不**放进 per-run 战斗层。对比差值 = 读 `to_modifiers(Game.registry)` 求和,纯只读。

**§3.2 `GameController` — 加暂停/恢复编排 API(不动边界):**
- `Game` 增 `pause_run()` / `resume_run()`(切 `arena.running` + 触发上面的玩家 re-snapshot)。城镇
  (表现层)经 `Game` autoload 调用 —— 属"运行控制",非持久态穿透,与 i8 不冲突(i8 管的是持久态读取走
  `/root/Player`,不是运行控制)。

## 4. 调整策略 / Strategy(依赖序,Planner 排步时照此先后)
1. **先落数据模型最底层**:`ItemInstance += enhance_level` + 序列化(默认 0 向后兼容)。这是叶子,无下游依赖。
2. **再接属性引擎**:`to_modifiers` 据 `enhance_level` 出 `StatModifier(source=self)`(数值占位,待 F-NUM 填)。
   先有缝、单测无损卸载仍成立,再让 num-smith 填幅度。
3. **持久层元操作**:在持久层加"换装(bag↔Character.equipped 搬 `ItemInstance`)/强化(+1 + 扣材料)"方法
   —— 纯持久态操作,可 gdUnit4 测(无 UI)。强化扣 `PlayerState.materials`,门槛/成本待 F-NUM。
4. **编排 API**:`Game.pause_run/resume_run`,resume 内做"玩家 Entity re-snapshot + current_hp 带值夹紧"。
   这步依赖 1-3 已就位(改装才有东西可生效)。
5. **最后才是表现层城镇 UI**(换装/对比/强化面板)—— 纯 View,按 §5 政策手动 Play 验,挂在 1-4 之上。
> 1-3 可 gdUnit4 覆盖(纯逻辑);4 的 HP 带值夹紧也可单测;5 手动 Play。**先逻辑后表现**,中途不破当前 117+ 绿。

## 5. 影响面与迁移 / Blast radius & migration
- **改动文件(预估,Planner 细化)**:`item_instance.gd`(加字段 + 序列化 + to_modifiers)、持久层
  (`player_state.gd`/`character.gd` 或新 meta 方法)、`game_controller.gd`(pause/resume + resume re-snapshot)、
  表现层新城镇 UI(新文件,挂 shell)。`stats_component`/`equipment_component`/`stat_modifier` **不改**
  (强化复用其现有 source 机制)。`DataRegistry` **不改座位**(仅城镇侧多取一处 `Game.registry`)。
- **存档迁移**:`enhance_level` 加进 `ItemInstance.to_dict`;`from_dict` 缺省 0 → **旧档无缝**,无需版本号
  跳变(`SaveSystem.SAVE_VERSION` 暂可不动;若 num-smith 另加字段再议)。换装/强化结果落 `Character.equipped`
  /`bag`/`materials`,均已在现有存档 round-trip 路径内(`PlayerState.to_dict`)。
- **向后兼容**:现挂机自动填空(i3 只增不替)路径**完全不动**;城镇手动换装是**另一条**持久层路径,二者并存。
- **回归锚**:现 117+ gdUnit4 必须保持绿;新加的无损卸载(强化件)、HP 带值夹紧、换装搬移均应补纯逻辑测。

## 6. 风险与被否选项 / Risks & rejected alternatives
- **被否① 升 `DataRegistry` 为 autoload。** 否因:它 immutable read-only、无信号,autoload 须 Node 会重引
  D4 数据层单测 orphan,违 §6"只读依赖保持 owned"。现 `Game.registry` 已恒可用,够了。
- **被否② 城镇直接编辑活体 `Entity.EquipmentComponent`(双写持久 + 活体)。** 否因:破 i4#4(持久层才是事实源、
  per-run 可弃),且战斗未开时根本无活体可写。改"只写持久 + 出城 re-snapshot"更忠实。
- **被否③ 出城朴素 rebuild(满血)。** 否因:把城镇变成免费回血站,违 i5 精神。改"带 current_hp 夹紧"。
- **风险 A(交 GD/num,设计旋钮)**:"回城是否回血"本身是**设计/数值决策**——架构默认**不免费回血**(守 i5),
  但若 GD 想让回城兼具补给意图,可在此契约上**显式**加一道"回城回 X%"的设计选择(走配置),架构两可。已 flag。
- **风险 B(交 num-smith)**:`enhance_level` 的属性贡献公式(放大招牌轴 vs 加独立 flat)、材料成本/上限。
  架构只保证"经 source=self 的 modifier 注入"这条缝两种都装得下;**数字与公式形态 = F-NUM**。
- **风险 C(轻,实现注意)**:暂停 `running=false` 时若有别的 tick 来源(后台 15fps 等)须确保也认 `running`
  门(现 `_process` 已认)。Planner 核一遍无第二条推进路径即可。

## 7. 交接 Planner / Handoff
Planner 把 §4 的 5 步依赖序落成具体 file-level PLAN(每步带验证);**前 4 步纯逻辑可 gdUnit4 测、第 5 步手动 Play**:
1. `ItemInstance += enhance_level` + 序列化(默认 0);2. `to_modifiers` 接强化(数值占位待 F-NUM);
3. 持久层换装/强化元操作(扣材料);4. `Game.pause_run/resume_run` + resume 玩家 re-snapshot(HP 带值夹 i5);
5. 城镇表现层 UI(换装/对比差值/强化面板)。
**前置依赖**:第 2、3 步的**具体数值**等 **`/num-smith 05`**(强化幅度/成本/上限 + 材料经济)落 BALANCE-CHANGE;
架构缝已就位,Planner 可先排骨架、数值占位,num-smith 出数后填。**"回城是否回血"** 需 GD/num 给一句口径
(架构默认不回血)。
