---
feature: 05-town-gear-upgrade
status: in-progress
updated: 2026-06-19
---
# HANDOFF — 05 城镇:手动换装 + 对比面板 + 装备强化

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。

## 一句话
**支柱 2「变强够到下一个怪」在 v1 的高光落点** —— 回城把挂机产出主动转化成战力:
① 1 战士 3 槽**手动换装** + **对比面板**(逐项差值绿↑红↓);② **装备强化**(确定性 +1、三槽通吃、花材料、数值随级升)。
后端持久层(roster / 背包 / 材料 / `EquipmentComponent` 无损穿脱)已由 `00` 落地;05 = 点亮城镇主动构筑 + 引入 v1 第一个材料消耗口。

## 依赖(前置)
- **持久层已就位(`00-foundation-redesign`)**:`PlayerState`(roster / 背包 / 材料)、`EquipmentComponent` 无损穿脱、
  `ItemInstance`(base + ilvl + rarity + affixes)均已落地并可序列化。05 在其上加「强化」与「战斗外读写」。
- **04 已收口(done)**:只读掉落/装备查阅面板 + 8 维格式化 + 变强绿闪视觉语言,05 的换装/对比可复用其表现语言。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | **draft(2026-06-19)** — 用户拍板三条:① 城镇=独立界面(进城暂停挂机)② 强化=独立「强化等级」加成 ③ 强化作用所有装备(放宽 BACKLOG「+1 武器」)。GD 红线:强化确定性/无失败/纯增益。已开 3 个 flag(F-ARCH 阻塞前置 / F-NUM / 材料经济) |
| 架构 | Arch Guard | arch/REFACTOR-03-town-meta-ops.md | **draft(2026-06-19)— 判定:装得下,加性扩展无需重构。** 三决策:① `ItemInstance += enhance_level`(骑 `to_modifiers(source=self)` 既有缝,守 i1/i2,序列化向后兼容)② `DataRegistry` 维持 owned-RefCounted、城镇经 `Game.registry` 读(**否决升 autoload**,闭 §6 复审债)③ `Game.pause_run/resume_run` + 出城据改后 `Character` re-snapshot 玩家 Entity、HP 带值夹紧(守 i5 不免费回血)。新增不变量 #10/#11。ARCHITECTURE.md 已回写 |
| 数值 | Num Smith | balance/BALANCE-CHANGE-02-town-gear-upgrade.md | **draft(2026-06-19)** — 强化数值定稿。① 幅度=每级 +10% 主轴基底(FLAT 线性,weapon 只强化 attack 不碰 attack_speed 守 i4)② 成本=`1+L`(满件累计 55,花 `slot|white`)③ 上限=**+10**(满级翻倍)④ 三槽同公式仅主轴不同。材料经济校验:**无材料荒、反偏富余**(产出>消耗,强化=v1 首个沉淀口)。回城**不回血**(沿用架构默认守 i5)。新增不变量 i7,BALANCE.md 已回写 |
| 计划 | Planner | PLAN.md | **draft(2026-06-19)** — 五步依赖序落 file-level:① `ItemInstance += enhance_level`+序列化 ② `enhance.json`+`EnhanceConfigDef`+DataRegistry 加载 ③ `to_modifiers` 接强化(FLAT、仅 `signature_axes[0]`、跳 attack_speed 守 i4)④ `PlayerState` 换装/强化元操作(扣 `slot|white`、封顶)⑤ `Game.pause_run/resume_run`(冲洗活体装备→持久 + re-snapshot HP 带值夹 i5)+ `TownView`(手动 Play)。步 1-5a 纯逻辑 gdUnit4,步 5b 手动。5 key decisions + 5 flags |
| 实现 | Implementer | CHANGES.md | **draft(2026-06-19)** — 五步全落地(①`ItemInstance += enhance_level`②`enhance.json`+`EnhanceConfigDef`③`to_modifiers` 接强化④`PlayerState` 换装/强化元操作⑤`Game.pause_run/resume_run`+`TownView`)。**gdUnit4 全量 145/145 绿、0 orphan、现有测试无回归**(117+→145,新增 28 用例)。5b(`TownView`)纯表现层待手动 Play。含 §4 Wiring Contract 交 EI |
| 审查 | Reviewer | REVIEW.md | — |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | — |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | **accepted(2026-06-19)** — 人类已照 INTEGRATION-STEPS 在 `MainArea`(`CombatView` 之后)挂上 `TownView`,Play **验收通过**:进城冻结挂机 + 城镇工作台、三槽选 + 对比面板逐轴差值、换装、强化 +1、出城不回血且改动生效,全部 OK。接线极简(全自接,无 @export/手连信号/素材)。**界面仍是占位程序美术,UI/juice 经用户拍板推迟到功能全做完后统一处理(不进 05)。** |

> 状态取值:`—`(未开始) / `draft` / `accepted` / `blocked` / `superseded`

## 下一步
**✅ 2026-06-19 — 05 城镇全链路落地 + 接线验收通过,功能层 DONE。** 设计→架构→数值→计划→实现→接线 六棒齐;
人类 Play 验收:进城冻结、三槽换装 + 对比面板逐轴差值、强化 +1、出城不回血且改动生效,全部 OK。
gdUnit4 全量 145/145 绿。**剩余仅 UI/juice 表现层**(界面现为占位程序美术)。

**下一棒:**
- **无即时下一棒** —— 用户拍板:UI/juice(界面皮 + 换装绿闪 / 强化特效 / 音,FEATURE-DESIGN §4)**推迟到 v1 功能全做完后统一处理**,不在 05 范围内、暂不进 BACKLOG。
- 待整体功能闭环完成后,再开 **Art Spec** 统一做城镇/战斗的 UI 与 juice 一轮。
- Producer 可在 BACKLOG 把 05 标 ✅(功能完成),并记一笔"全局 UI/juice 待功能收尾后统一排"。

## 决策记录
- **2026-06-19 — [用户拍板] 城镇 = 独立界面**(进城暂停当前挂机,出城恢复),非 04 式悬浮窗内模态。来源:用户。
- **2026-06-19 — [用户拍板] 强化 = 独立「强化等级」加成**(给 `ItemInstance` 加强化态,提升装备数值);
  具体数值交 num-smith;牵扯结构改动先 /arch-guard 审计。来源:用户。
- **2026-06-19 — [用户拍板] 强化作用于所有装备**(三槽通吃),放宽 BACKLOG 原「材料 +1 武器」。来源:用户(待 Producer 在 BACKLOG 追认)。
- **2026-06-19 — [GD 红线] 强化确定性 / 无失败 / 纯增益**(守支柱 3 非赌场);数值在此约束内由 num-smith 定。

## 未决 flags
- **✅ F-ARCH(已解除 2026-06-19)** — Arch Guard 判定**装得下,加性扩展无需重构**。三件审完并定案(见 REFACTOR-03 + ARCHITECTURE.md):
  ① 强化等级骑 `to_modifiers(source=self)` 既有缝、守 i1/i2;② `DataRegistry` 维持 owned、否决 autoload(§6 复审债已闭);
  ③ 暂停态归 `Game` 编排座(`pause_run/resume_run`),出城 re-snapshot HP 夹紧不免费回血。新增不变量 #10/#11。
- **✅ F-NUM(已解除 2026-06-19)** — Num Smith 定稿(BALANCE-CHANGE-02):幅度 +10%/级主轴基底(FLAT 线性)、
  成本 `1+L`、上限 +10、三槽同公式。材料经济校验通过(无荒、偏富余)。四常量走配置勿硬编码。新增不变量 i7。
- **✅ 材料来源是否够(已校验=够,反偏富余)** — Num Smith 经济校验:白材料产速(每 `slot|white` ~0.15-0.2/击杀)远超
  强化消耗(满件 55),**无材料荒**,**v1 无需扩来源**。开放点反转为「材料或过剩」→ 真过剩则陡化 `ENH_COST_STEP`,非降产出。
- **🟢 支柱 1 相容(已判定相容,待 playtest 确认)** — 城镇暂停挂机 vs 后台持续推进:前者是前台主动界面,二者不冲突。
- **✅ i3 澄清(已补)** — Num Smith 在 BALANCE-CHANGE-02 §6 明确:手动换装可替换(玩家主动)vs 自动填空只增不替(i3,挂机)
  是两条独立路径,强化不改 i3;强化加成随 `ItemInstance` 走,换下放包再穿回保留等级。
- **🟢 Producer 知会** — 05 scope 放宽(强化从「+1 武器」扩到「所有装备」),待 BACKLOG 追认。
