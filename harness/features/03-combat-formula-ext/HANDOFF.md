---
feature: 03-combat-formula-ext
status: done
updated: 2026-06-18
---
# HANDOFF — 扩 02 战斗公式以支持装备维度 (Combat Formula Extension)

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。

## 这是什么 / 为什么先做
04-loot-equipment(暗黑式掉落/装备)的基底与词缀要表达**攻速、护甲减伤**乃至更多维度(暴击/吸血等),
但 02-auto-combat-loop 当前 tick 模型里**只有"全队总攻击打当前敌人、敌人打前排"**——无攻速、无减伤。
用户拍板:**趁现在把战斗公式一次扩到位**(词缀是装备核心的一半;现 refactor 比 v1 压扁、v2 再 reopen 更省事)。
故本 feature = **reopen 02 战斗解算做受控扩展**,作为 04 装备系统的前置。

## 范围(待 Game Designer 在此框内细化)
- **扩 02 战斗公式**:攻速 → 出手频率;护甲 → 减伤;并为更丰富词缀预留维度(暴击/吸血等,具体由 Game Designer 定)。
- 必须**守住 02 已收口的成果**:掉落事件流(`loot_dropped`)、Boss 解锁、团灭回退、后台持续推进、4 格队伍地基
  **不破坏**(扩展而非重写)。
- 数值平衡走 Resource/配置,不硬编码(守 hard-NO)。
- **不含**:套装、宝石、词条重铸(留 v2);装备物品系统本身(归 04)。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | draft(已定公式形态/语义/侵入边界;数值留专章) |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | draft(已摸清 tick_combat/PartyMember/EnemyDef + 7 个 gdUnit4 suite 的时序敏感断言) |
| 计划 | Planner | PLAN.md | draft(D1-D7 决策已定 + 7 步有序计划 + flags A-F) |
| 实现 | Implementer | CHANGES.md | draft(7 步全实现 + 审后清 2 个 should-fix;check-only 0 + 45/45 gdUnit4 绿;手动 Play F7 待用户) |
| 审查 | Reviewer | REVIEW.md | draft(**APPROVE WITH NITS**;独立重跑 45/45 绿;0 must-fix,2 should-fix) |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | —(可能不需新增美术) |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | —(若动 Resource 字段则需要) |

> 状态取值:`—`(未开始) / `draft` / `accepted` / `blocked` / `superseded`

## 下一步
审查已出:**APPROVE WITH NITS**(REVIEW.md;Reviewer 独立重跑 45/45 绿)。**0 must-fix**,机制忠实 PLAN、02 收口成果未破坏。
**两个 should-fix 已于 2026-06-18 清掉**(Implementer;详见 CHANGES.md §7),check-only 0 + 全套独立重跑 45/45 绿:
- `combat_view.gd` `_on_hit_dealt`/`_on_player_dodged` 已加 `if not visible: return`(收起态零飘字开销)。
- `combat_director.gd` 护甲减伤已防 0/0(`denom<=0` 跳过减伤)。
- 3 个 nit 按 REVIEW 判定不改(无行为影响)。

→ **已收口(status: done)**。两个 should-fix 已清;**2026-06-18 用户手动 Play(F7)通过,未发现问题**,Flag-E/Flag-F 均已实机确认。

**本功能完成。** 下一棒:**04-loot-equipment**(暗黑式掉落/装备),建立在本 feature 扩好的 6 维战斗公式之上——武器给攻击/攻速、护甲给护甲、饰品三选一、暴击作词缀(见下方 Game Designer 决策记录)。

> **⚠ 2026-06-19 — 本功能已 done,其成果被 `harness/arch/REFACTOR-01-foundation-redesign.md` 整体地基重构接管(承接,非废弃)。**
> 6 维公式(攻速 cadence / 护甲减伤 / 闪避 / 暴击 / 每秒回血 / 软狂暴)**保留搬入** REFACTOR-01 §4 第 5 层的 `SkillComponent`,
> 公式断言值不变 = 回归锚(REFACTOR-01 §5)。**承载结构变**:单敌 director 解算 → lane 多实体 + 组件,但本 feature 的数值/语义不丢。
> 本目录留作设计/历史档,不再单独推进;后续战斗实现并入 00-foundation-redesign 的重构 PLAN。

实现期 flag 终态(详见 CHANGES §6/§7):A 已按推荐落地;C 已守(无逐 tick 精确断言);
D 回血飘字本轮未做(尽力而为项,不阻塞,可留 04/后续);F View 飘字 Play 已复看通过;E 用户 Play 已确认。

## 决策记录
- 2026-06-18 — **[Producer/用户] 03 拆两块,扩公式提前单列为本 feature。** 用户推翻"扩公式→v2"的初裁,
  理由:词缀是装备核心一半,趁现在 refactor 战斗公式比 v1 压扁、v2 再 reopen 更省事。装备系统顺延为 04,
  建立在本 feature 扩好的公式之上。来源:用户(2026-06-18);详见 BACKLOG 决策记录。

## 决策记录(补:Game Designer 拍板 2026-06-18)
- 攻速模型 = **(a) 离散命中**:每成员/敌人按 attack_speed cadence 出手,暴击等按"每次命中"结算(用户选)。
- v1 扩 **6 个维度**:攻速、护甲(减伤=护甲/(护甲+K) 递减)、闪避(全有/全无)、暴击(率+倍率)、每秒回血、
  (攻击/生命已有)。防御三轴全要(护甲+闪避+回血),用户拍板。
- **软狂暴(用户新增)**:同一敌人缠斗超阈值→输出陡增至分出胜负,根除"互相打不动"死局;**因此无需对回血/防御设硬上限**。
- 部位基底:武器=攻击+攻速、护甲=护甲、饰品∈{生命/闪避/回血}三选一(暂定);暴击作词缀。
- 数值全部"大致合理"占位、不设硬上限,精调留数值设计专章。

## 未决 flags(详见 FEATURE-DESIGN §7)
- **F1 数值设计专章(必做后续)**:所有数值(攻速基准、护甲 K、暴击率/倍率、闪避率、回血速率、狂暴阈值/曲线、
  02 怪血等比重定)留专章精调,暂用占位值跑通机制。
- **F2 饰品基底三选一**({生命/闪避/回血})未定死,可等 04 设计物品时一并定,不阻塞本功能。
- **F3 防御冗余观察**:护甲/闪避/回血是否 playtest 中糊成一坨"更耐打";保留砍并其一的余地。
- **F4 回归风险(交 Planner/Implementer)**:reopen 02——cadence 改写 `tick_combat` + 加字段,**必须**重跑
  02 gdUnit4 全套 + headless;DPS 重定会改击杀/团灭时序,**时序敏感断言需更新**;守住掉落/解锁/回退/后台模拟/回血粒度。
- **F5 软狂暴配置位**:阈值/曲线放 EnemyDef(每怪)还是全局?倾向全局默认 + EnemyDef 可覆盖(走配置)。交 Planner。
- **F6 范围提醒**:只扩"装备要用的战斗维度";等级/经验、团战仍 Later,**不顺手并入**(守 hard-NO)。吸血本轮未选(与回血同 niche)。
- **F7 可读性硬要求**:软狂暴 + 闪避的"死因可读"是支柱 1 验收点,非可选润色;Art/GameFeel 须落地提示钩子。
