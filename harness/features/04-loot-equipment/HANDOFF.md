---
feature: 04-loot-equipment
status: in-progress
updated: 2026-06-18
---
# HANDOFF — 暗黑式掉落与装备 (Loot & Equipment)

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。
>
> ⚠ **2026-06-18 顺延改号:本功能原为 `03-loot-equipment`,现顺延为 `04-loot-equipment`**——
> 因 03 被拆成两块,扩战斗公式提到前面单列为新 feature `03-combat-formula-ext`,装备系统排其后。
> IDEA.md 正文里的"03"字样多为"本掉落/装备功能"的旧简称,理解为本(04)功能即可。

## 依赖(前置)
**前置 `03-combat-formula-ext` 已于 2026-06-18 收口(done)。** 战斗公式已扩出 6 维(攻击/攻速/护甲减伤/闪避/暴击/每秒回血),
本功能的基底/词缀直接建立在这之上,`PartyMember` 相应字段已就绪。**依赖已解除,可推进。**

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 立意 | Design Jam | IDEA.md | draft(2026-06-18 在 03 收口后**重刷**:大半旧 §8 已关,基底/词缀模型已定,待 Game Designer 细化) |
| 设计 | Game Designer | FEATURE-DESIGN.md | draft(2026-06-18:用户逐条拍板 A1/A2/A3/B4/B5/C6/C7;B4 用 ilvl+词缀分阶池取代 IDEA"通吃";§8 留 F-A ilvl来源 + F1 数值专章) |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | draft(2026-06-18:已摸清掉落发射点/PartyMember/无等级概念/无分层/无背包存档;7 条 flag 交 Planner) |
| 计划 | Planner | PLAN.md | draft(2026-06-18:追认 D-1/D-2/D-3 + 拍 §5#6 current_hp 跟随[K6] + 8 步有序计划 + F4 回归清单;新拍 K7 gold/material 直掉 no-op→flag F-D) |
| 实现 | Implementer | CHANGES.md | — |
| 审查 | Reviewer | REVIEW.md | — |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | — |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | — |

> 状态取值:`—`(未开始) / `draft` / `accepted` / `blocked` / `superseded`

## 下一步
**⚠ 2026-06-19 — 本功能被 `harness/arch/REFACTOR-01-foundation-redesign.md` 整体地基重构接管。**
用户决定在 04 实现前整体重铺底层(组件化实体 / 模板-实例两层 / modifier 属性 / PoE 装备流水线 / lane 团战)。
- **现有 PLAN.md 标 superseded**:其"retrofit 到 `PartyMember`(`_base` 快照 + Inventory autoload + K6 补丁)"的接线方式被新地基取代——装备改走 `EquipmentComponent` → `StatsComponent` modifier。
- **保留有效**:FEATURE-DESIGN 的 B-4 PoE 式 ilvl+分阶池设计、LootTables、Tier 表、填空/分解/只读包规则 —— 移植进 REFACTOR-01 §4 的第 3-4 层(持久层 + 掉落流水线)。
- **下一步 = 开 `/role-planner`,喂 `harness/arch/REFACTOR-01-foundation-redesign.md` + `harness/ARCHITECTURE.md`**,把 §4 八层拆成有序可验证 PLAN(建议分批落)。04 的装备实现并入该重构,不再单独走原 PLAN。

> (历史)原计划:PLAN.md 8 步 retrofit + Step 8 autoload 注册 = 引擎侧人工点。已被 REFACTOR-01 取代,留痕备查。

Planner 已交付(详见 PLAN.md):
- **追认** D-1(属性分层 K1/K2)、D-2(扩 `loot_dropped(kind,rarity,item_level)` K3)、D-3(`Inventory` 场景型 autoload K4)。
- **新拍** §5#6 = K6(`max_hp` 变动时 current_hp:存活加差额、死亡不复活、夹 [0,max]);K5(类型化数据类+配置资源);K7(gold/material 直掉 04 内 no-op→新增 flag F-D)。
- 8 步有序计划(每步带验证)+ F4 回归清单(含已枚举的 loot_test.gd 26/35/47/63/76 两参 lambda 同步点)。

> **D-1 是语义决策**,建议 Planner 顺手在 FEATURE-DESIGN §3.5 补一行记上(或下次 GD pass 收口);决策已留痕于本 HANDOFF + CONTEXT-FINDINGS。
> **数值仍全占位**(§8 F1,建议与 03 F1 合并成总数值专章);**B4 词缀是 PoE 式 ilvl+分阶池,守 §8 F5 别外溢**。

## 决策记录
- 2026-06-18 — 装备 = **基底 + 词缀**;稀有度 = 词缀条数(白 0 / 蓝 1-2 / 金 3+)。来源:用户。
- 2026-06-18 — 槽位 = 武器 / 护甲 / 饰品(3 槽,每槽 1 件)。来源:用户。
- 2026-06-18 — 进包前过滤:低稀有度(默认白)**自动分解成材料**,够好的(蓝/金)进包。来源:用户。
- 2026-06-18 — 承接 02 的 `loot_dropped(kind, rarity)` 事件边界(02 只产事件,物品实例/词缀 roll 归本功能)。
- 2026-06-18 — **[Producer] 03 拆两块、扩公式提前**:新建前置 `03-combat-formula-ext`,本功能顺延为 04。详见 BACKLOG。
- **2026-06-18 — [Design Jam 重刷,03 收口后] 以下五条本轮敲定/刷新(详见 IDEA §4/§8):**
  - **基底专属轴 + 词缀通吃**:基底随部位固定给身份,词缀池可 roll 任意 6 维(攻击/攻速/护甲/闪避/暴击/回血)。来源:用户。
  - **三槽招牌基底**:武器=攻击+攻速、护甲=护甲、**饰品=生命/闪避/秒回 三选一**(每件随机)。来源:用户。
  - **04 UI = 只读掉落包**(悬浮窗里点开能查阅掉了什么,**只能看不能换**,方便直接测试掉落)。来源:用户。
  - **手动换装 + 对比面板 → 挪到 05 城镇**(04 不做)。来源:用户。⚠ 这右移了 BACKLOG 原 04 scope,见下 flag B1。
  - **保留自动填空槽**(空槽自动穿对应掉落、绝不替换已穿戴的)= 04 唯一的挂机变强来源。来源:用户。
- **2026-06-18 — [Explorer session,用户当场拍板 3 条接线决策](待 Planner/GD 在 PLAN/FEATURE-DESIGN 追认):**
  - **D-1 属性分层(语义,归 GD 文档):** `@export warrior_*` = **裸职业基础值**;装备(含开局白装)在其上**叠加**,total = 基础 + Σ装备。开局白装 ilvl=1 数值很小,基本不改 03 已调好的手感、不双重计数。来源:用户。
  - **D-2 掉落接口(归 Planner):** **直接扩 `loot_dropped` 签名带上 ilvl(/物品载荷)** —— 接受 LootStub / CombatView / 掉落测试 2 参 lambda 的同步改动(F4)。ilvl 来源 = **`EnemyDef` 新增 `@export item_level`**(走配置、Boss 给更高,守 hard-NO;`_roll_loot(def)` 处 def 在手)。来源:用户(签名)+ Explorer 建议(item_level 源,待 Planner 确认)。
  - **D-3 状态归属(归 Planner):** **新建 `Inventory`/`LootSystem` autoload** 放背包 + 材料库存 + 消费逻辑(填空/分解 + 物品实例/词缀 roll);**装备槽挂在各 `PartyMember`**(支持 4 人各自 3 槽),重算属性写回 PartyMember。**04 仅内存态**,数据设计成可序列化,save/load 留后续功能(不并入,守 hard-NO)。来源:用户。

## 未决 flags
> 来自 IDEA.md §8(交 Game Designer 收敛;带 ⚠ 的先过 Producer)。

**⚠ 边界变更(本轮引入,建议 Producer 追认):**
- **B1 · 04/05 边界右移** — 手动换装+对比面板从 04 挪到 05,04 只做只读掉落包。建议 Producer 更新 BACKLOG 的 04/05 scope 行。

**本轮已关掉(留痕,不再 open):**
- ✅ 旧#1 战斗模型容不容得下攻速/护甲 → **03 已解决**,6 维齐备。
- ✅ 旧#2 词缀池 → **通吃 6 维**(具体集合+数值留 GD)。
- ✅ 旧#3 饰品基底 → **生命/闪避/秒回三选一**。
- ✅ 旧#5 换装 UI 落哪 → **04 只读掉落包 / 换装归 05**(见 B1)。

**仍待 Game Designer 拍板:**
1. 词缀 roll 细则(每部位能 roll 哪些维 / 数值区间 / 暴击 roll 率还是倍率 / 攻速步长)。
2. 稀有度数值梯度(每条词缀数值范围、是否随稀有度抬高、基底数值是否随稀有度浮动)。
3. 战士开局空装还是自带基础装?(04 唯一变强来源是自动填空,开局全空前期"叮叮叮"很热闹。)
4. 04 单独 playtest 的乐趣验证(换装挪 05 后 04 介入只剩"看",是否需一点临时换装入口自测?)。
5. 分解门槛默认值与可配置度。
6. 分解产出什么材料、喂给谁(04 只产"得到 X 材料"数据,打造消耗归 05)。
7. 自动填空槽与未来套装/词缀的兼容(标准注记)。
8. 掉落包/背包满了的兜底。
