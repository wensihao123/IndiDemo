---
feature: 04-loot-equipment
status: done
updated: 2026-06-19
---
# HANDOFF — 暗黑式掉落与装备 (Loot & Equipment)

> 🔻 **2026-06-19 Producer 收窄(scope cut):04 后端已被 REFACTOR-01 地基重构整体吸收并落地**
> ——`LootGenerator`/`LootIntake`/`ItemInstance`/`AffixRoll`/`EquipmentComponent` + ilvl+分阶池 +
> 空槽自动穿/白分解/蓝金进包分流,全部已在 `src/core/{items,systems}/` 落地并测过(117/117)。
> **04 余下范围 = 仅「表层点亮 + 数值定稿」**:只读掉落包 UI、词缀数值梯度、分解门槛、开局空装与否等。
> **不再重做后端。** 下方 §管线状态里 FEATURE-DESIGN/CONTEXT-FINDINGS/PLAN 三件均标 `superseded`
> (它们假设旧 `CombatDirector`/`PartyMember`/`Inventory autoload` 结构,已被四层架构取代)。

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
| 设计 | Game Designer | FEATURE-DESIGN.md | **draft(2026-06-19 收窄重写)**:范围收为「① 表层查阅面板 ② 数值粗定」;后端段标"已落地不再设计";用户拍板 掉落包+当前装备双栏 / 8 维属性明细(不做战力分) / 数值粗定交 num-smith。旧版机制设计已 superseded(被代码取代) |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | superseded(2026-06-19:摸的是旧 director/PartyMember 结构,已被四层架构取代;新接入对照 ARCHITECTURE.md) |
| 计划 | Planner | PLAN.md | **draft(2026-06-19 收窄重写)**:7 步有序计划——① 只读双栏查阅面板(代码建于 CombatView,读活体 Entity + bag,自动填空显形)② `LootGenerator.pick_weighted` + `_drop_loot` 接 `EnemyDef.rarity_weight_*`(修 F-RARITY-WIRE)。仅 Step1-2 可 gdUnit4 测,Step3-7 手动 Play。不碰后端/架构。旧 8 步 retrofit PLAN 已 superseded |
| 实现 | Implementer | CHANGES.md | **draft(2026-06-19 落地)**:PLAN 7 步 + BALANCE-CHANGE-01 全落。① `LootGenerator.pick_weighted` + `_drop_loot` 读 `rarity_weight_*`;② `CombatView` 只读双栏面板(背包/装备 + 8 维 + 填空绿闪);③ 8 个 EnemyDef `item_level` 阶梯。**gdUnit4 123/123 绿**(+6 新)、check-only 退出 0。**Step 3-6 UI 仅手动 Play 待人验(R2)** |
| 审查 | Reviewer | REVIEW.md | **draft(2026-06-19)— APPROVE WITH NITS**:无 must-fix;独立复跑 gdUnit4 123/123 绿、check-only 退出 0、8 个 item_level 逐一核对一致。2 条 should-fix(非阻塞):① UI 必须人验后才能标 done(测试政策无法 gdUnit4 覆盖);② `combat_view.gd:565 ent.stats.get_final` 缺 `ent.stats==null` 守卫(与 557 行 `ent.equipment` 守卫不对称,当前路径不触发)。**两条均已闭环:人验通过 + 守卫已补(check-only/123 测绿)→ 04 done** |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | — |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | — |

> 状态取值:`—`(未开始) / `draft` / `accepted` / `blocked` / `superseded`

## 下一步
**✅ 2026-06-19 — 04 收口(done)。** 人验 6 条已由用户走查通过;Reviewer should-fix #1 已补
(`combat_view.gd` `_rebuild_equip_col` 加 `ent.stats != null` 守卫,与 `ent.equipment` 守卫对称),
check-only exit 0、gdUnit4 **123/123 绿(18 套,exit 0)无回归**。PLAN 7 步 + BALANCE-CHANGE-01 全部落地并验收。

**本功能无后续棒。** 剩余皆为已登记的推后债,不阻塞本功能:
- **F-KIND(交 Producer)** — 掉落种类(金币/材料 kind)是否纳入 v1 —— GD 倾向推后;本切片掉落恒为装备。
- **F-BAG(推后)** — 满包兜底,playtest 发现包爆再定。
- 债-3 阶选择曲线化 / 债-5 狂暴回血校准 / 债-6 词缀池扩充 → 留 playtest/后续(见 BALANCE.md §6)。
- **05 城镇** 承接手动换装 / 对比面板 / 打造强化(本功能范围外)。

> (历史)旧 FEATURE-DESIGN/PLAN/CONTEXT-FINDINGS 假设旧 director 结构,已 superseded;勿据旧 8 步后端 PLAN 重做。

Planner 已交付(详见 PLAN.md):
- **追认** D-1(属性分层 K1/K2)、D-2(扩 `loot_dropped(kind,rarity,item_level)` K3)、D-3(`Inventory` 场景型 autoload K4)。
- **新拍** §5#6 = K6(`max_hp` 变动时 current_hp:存活加差额、死亡不复活、夹 [0,max]);K5(类型化数据类+配置资源);K7(gold/material 直掉 04 内 no-op→新增 flag F-D)。
- 8 步有序计划(每步带验证)+ F4 回归清单(含已枚举的 loot_test.gd 26/35/47/63/76 两参 lambda 同步点)。

> **D-1 是语义决策**,建议 Planner 顺手在 FEATURE-DESIGN §3.5 补一行记上(或下次 GD pass 收口);决策已留痕于本 HANDOFF + CONTEXT-FINDINGS。
> **数值仍全占位**(§8 F1,建议与 03 F1 合并成总数值专章);**B4 词缀是 PoE 式 ilvl+分阶池,守 §8 F5 别外溢**。

## 决策记录
- **2026-06-19 — [Producer] 04 收窄为「表层 + 数值定稿」。** 后端(掉落流水线 / 装备 modifier / ilvl 分阶池)
  已被 REFACTOR-01 整体吸收并落地,04 不再重做后端;余下仅只读掉落包 UI + 词缀/梯度/门槛等数值定稿。
  FEATURE-DESIGN/CONTEXT-FINDINGS/PLAN 三件标 superseded(均假设旧 director 结构)。来源:用户(scope 拍板)。详见 BACKLOG 决策日志。
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

**🔻 收窄后的现行 flags(2026-06-19,来自 FEATURE-DESIGN §7):**
- **✅ F-NUM(已落地,Implementer 交付)** — BALANCE-CHANGE-01 定稿的 8 个 EnemyDef `item_level` 阶梯
  (关1 1→10 / 关2 14→30,解债-1)已写入 `stage_0*.tres`;其余数值维持现值。check-only 退出 0。
  **遗留(非 04 阻塞):** 债-3 阶选择曲线化、债-5 狂暴/回血校准、债-6 词缀池扩充 → 留 playtest/后续;债-4 = F-KIND(下条)。
- **✅ F-RARITY-WIRE(已落地,Implementer 交付)** — `LootGenerator.pick_weighted` 纯静态加权 +
  `combat_arena.gd:_drop_loot` 改读 `EnemyDef.rarity_weight_*`,金/白不再等概率(守支柱 3)。
  gdUnit4 覆盖:`pick_weighted` 4 用例(边界+分布) + `arena_loot_test` 2 用例(极端权重)。
- **⚠ F-KIND(交 Producer 拍)** — 掉落种类(金币/材料 kind)是否纳入 v1 04。现每次掉落必是装备;GD 倾向**推后**
  (装备掉落优先守 fantasy;材料已有"白装自动分解"来源)。
- **F-BAG(推后)** — 掉落包满包兜底,v1 不做,playtest 发现包爆再定。
- **F-ARCH-OK(确认)** — 表层面板纯读已落地态,不改架构,无需 /arch-guard。
- **✅ F-REVIEW-NIT(已闭环)** — `combat_view.gd` `_rebuild_equip_col` 已补 `ent.stats != null` 守卫
  (与 `ent.equipment` 守卫对称);check-only exit 0、gdUnit4 123/123 绿。
  另有 Nits(`_flash_equip_col` 手填几何魔数、bag 列表无滚动=F-BAG 已推后),仅记录不在本切片处理。

**已被收窄/落地关掉(留痕,不再 open):**
- ✅ 旧"仍待 GD"#1/#2/#5(词缀 roll 细则 / 稀有度梯度 / 词缀池)→ **机制已成代码事实**(`loot_generator` + 配置 JSON);数值部分并入 F-NUM。
- ✅ 旧#3 战士开局空装 → **A-1 已落地**(自带白武/白甲、空饰品;`starting_roster.json`)。
- ✅ 旧#4 04 临时换装入口 → **不需**:收窄版用"当前装备+8 维属性面板 + 填空显形"显性兑现变强,无需临时换装;真换装归 05。
- ✅ 旧#5/#6 分解门槛/产物 → **已落地**(白全分解、`material_per_decompose:1`、按部位×稀有度材料);门槛值精调归 F-NUM。
- ✅ 旧 B1 04/05 边界右移 → **Producer 已追认**(BACKLOG 决策日志 2026-06-19);换装/对比/打造归 05。
- ✅ 旧 F-A ilvl 来源 → **已解决**:`EnemyDef.item_level`(走配置)。
- 标准注记:F3 自动填空与未来套装/词缀兼容(绝不自动替换已穿戴)= 长期约定,非 v1 阻塞。
