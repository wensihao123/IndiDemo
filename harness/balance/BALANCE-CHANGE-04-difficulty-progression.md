---
artifact: BALANCE-CHANGE
feature: 06-difficulty-progression
role: Num Smith
status: draft
updated: 2026-06-20
inputs: [BALANCE.md, harness/features/06-difficulty-progression/FEATURE-DESIGN.md, assets/data/combat/stage_01.tres, assets/data/combat/stage_02.tres, data/config/starting_roster.json, data/config/item_bases.json, data/config/affix_pool.json, src/core/combat/skill_component.gd, src/core/combat/combat_tuning.gd, src/combat/enemy_def.gd]
next: Planner
---

# BALANCE-CHANGE-04 — 难度推进:把"墙"定出来(关2 Boss = 单调闸门兑现)

## 1. 触发 / Trigger
功能 **06-difficulty-progression**(v1 闭环收口)需要"一堵玩家撞得到的墙":GD 在 FEATURE-DESIGN
里把数字交给 num-smith,核心不变量 = **「关1 顶配 gear 纯 AFK 过不去、回城用关2 级掉落/强化变强能过」**
(支柱 2 / BALANCE i6 单调闸门的兑现落点)。GD 给的墙位选项:**关2 入口 vs 关2 Boss**。本档定墙。

## 2. 现状诊断 / Diagnosis
**根因不是某只怪 HP 太低,而是整条「关2 功率带」坐在「关1 通关后玩家功率带」之下——墙在数值上根本不存在。**

逆推玩家功率带(伤害公式见 BALANCE §3a,稳态 DPS 见 §3b,EHP = `max_hp/(1 − armor/(armor+50))`):

| 阶段 | 装备假设 | DPS≈ | EHP≈ | armor≈ |
|------|----------|------|------|--------|
| **P1-baseline** 关1 通关·白装 ilvl6-10 | 白武+白甲+空饰品,无强化 | ~25 | ~173 | ~11 |
| **P1-topped** 关1 顶配·蓝装 ilvl10 满词缀 | 蓝武+蓝甲+蓝饰,无/低强化 | ~34 | ~220 | ~16 |
| **P2** 关2 刷过·掉落 ilvl14-24 + 强化 | 关2 级蓝装 + 部分强化 | ~53-66 | ~282-328 | ~28-30 |

对照关2 现状敌人(逆推自 `stage_02.tres`,**所有敌人 atk 来自 .tres 显式值**):

| 关2 内容 | hp | atk | ilvl | 对 P1-topped 的实测 |
|----------|----|----|------|----------------------|
| Scene1 精英兽人 EnemyEliteOrc | 50 | 5 | 14 | 秒级清,几乎不掉血 |
| Scene2 暗影狼 EnemyShadowWolf | 65 | 6 | 18 | 同上 |
| Scene3 食人魔 EnemyOgre | 85 | 7 | 24 | 掉血~79% 白P1 EHP,仍稳过 |
| **Boss 兽人酋长 BossOrcChieftain** | **220** | **9** | 30 | **TTK ~9-13s、受伤 < EHP,轻松过** |

**关2 Boss(全关最硬)的 hp220/atk9 都压不住刚通关1 的玩家**:P1-topped 打它 TTK≈13s、期间受伤
远不及 220 EHP。→ 玩家"刷关2 = 走过场",**回城变强毫无理由**,06 想点亮的闭环空转。这正是
BALANCE §6 该补的债:i6 闸门有 ilvl 阶梯(掉落变强),却**没有任何一档内容把玩家挡在外面**,
"变强够到下一个怪"缺了"够不着"的那一端。

## 3. 目标数值 / Target numbers(delta vs BALANCE §3f / §6)
**墙落「关2 Boss 兽人酋长」,不落关2 入口。** 单点抬硬,关2 普通场景与关1 一律不动:

| 字段 | 现值 | 目标值 | Δ |
|------|------|--------|---|
| `BossOrcChieftain.max_hp` | 220 | **480** | ×2.18 |
| `BossOrcChieftain.attack` | 9 | **24** | ×2.67 |

其余**全部保持**:关2 三个普通场景(精英兽人/暗影狼/食人魔)不动、关1 全不动、Boss 的
`item_level=30` 与掉落权重(gold35/mat25/equip40、white35/blue45/gold20)不动
——**ilvl30 掉落 = 过墙奖励,墙后第一份关3 级装,原样保留**。

**墙的功率带校验(目标值下):**
- **P1-baseline(白装裸过关1)**:DPS25 → TTK≈19s;Boss atk24/速1 × armor11 减伤 ≈ 单手 21,
  19s 内挨 ~19 下 ≈ 400 伤 ≫ 173 EHP → **硬过不去**(团灭软退,符合不变量)。
- **P1-topped(关1 顶配蓝装)**:DPS34 → TTK≈14s;单手实伤 ≈ 20,14s 挨 ~14 下 ≈ 280 ≫ 220 EHP
  → **约差 17% 过不去**(死在 ~13s)。这是有意:关1 顶配也得回城吃关2 掉落,才迈过墙。
- **P2(关2 刷过·掉落+强化)**:DPS53-66 → TTK≈7-9s;armor28-30 → 单手实伤 ≈ 15,
  9s 挨 ~9 下 ≈ 135,占 282-328 EHP 的 **33-49%** → **能过、且留安全垫**(踏实兑现、非惊险)。

→ 不变量成立:**关1 顶配纯 AFK 过不去、回城用关2 级掉落/强化变强能过**。墙是"软"的:即便不主动
回城,被动掉落(i3 空槽自动填)最终也把玩家抬进 P2 带,只是远慢于主动调整(守 FEATURE-DESIGN §3.3
边界态①不死锁)。

## 4. 调整策略 / Strategy(依赖序)
本档是**纯值微调**(2 个 .tres 字段),无锚点链、无派生回算,顺序简单:
1. 改 `BossOrcChieftain.max_hp 220→480`(墙的"够不够久"——决定玩家 DPS 门槛)。
2. 改 `BossOrcChieftain.attack 9→24`(墙的"扛不扛得住"——决定玩家 EHP 门槛)。
3. 关2 普通场景、关1、Boss 其余字段(ilvl/掉落/稀有度权重)**一律不动**——墙是单点,不动梯度。
- **为何两维一起抬**:只抬 hp → 变成"磨血"耐久战(违支柱 1 不逼硬磨);只抬 atk → 残血玩家被秒、
  与"出城不回血"(#11)叠加成劝退尖刺。两维同抬,墙才是"DPS 不够杀不动 + EHP 不够扛不住"的
  **双门槛**,P2 两项都补齐才过 = "我全面变强了所以够到了"。

## 5. 影响面与迁移 / Blast radius & migration
- **触及文件**:仅 `assets/data/combat/stage_02.tres` 一个资源、其 `BossOrcChieftain` 一个 sub-resource、
  两个字段。无脚本改动、无新常量、无存档字段变化。
- **迁移**:无。敌人数值是 per-run 实例化、不持久化;无存档兼容问题。
- **不触及**:玩家属性、伤害公式、掉落系统、强化系统、进度 FSM(ProgressionController 团灭软退/
  推进/Boss 永久解锁全复用,06 不改骨架)。
- **结构空洞(非本档解决,转 Planner)**:过关2 Boss 之后**没有关3**(只有 stage_01/stage_02),
  `cur_stage→2` 越界 = 空波。这不是数值问题,是 v1 内容终点的**呈现**问题,归 Planner(FEATURE-DESIGN
  §3.3 边界态④"打通最后一关 = v1 内容终点收尾反馈")。
- **关2 团战铺波(08 deferred)**:墙不依赖铺波,本档维持关2 单敌波。若 Planner/后续决定给关2 铺多敌,
  须遵 BALANCE §5 团战 authoring 指南 + `WAVE_SIZE>4` 时同步抬 `combat_view.MAX_WAVE_SLOTS`(与本档无关)。

## 6. 风险与被否选项 / Risks & rejected alternatives
**风险(需 playtest 验证):**
- 🔴 **功率带估算依赖词缀 roll 方差**(债-3:阶选择均匀、不偏深度)。P1-topped/P2 的 DPS/EHP 是
  期望值;运气差的 P2 可能贴着 EHP 过、运气好的 P1-topped 可能勉强过。**墙的"准不准"最终由 playtest
  主观体感裁定**(FEATURE-DESIGN §5 成功标准③④)。若 playtest 显墙太松 → 优先再抬 atk(EHP 门槛
  比 DPS 门槛更"硬感");太硬 → 先降 atk 再降 hp。
- 🟡 **出城不回血(#11/i5)下的残血再战**:玩家若带残血点推进撞墙,EHP 实际打折。当前校验按满血算;
  残血撞墙更易团灭——但这正是"软退安全刷回血/或先在关2 普通场景回满"的设计意图(场景间 `_revive_party`
  回满),非缺陷。playtest 观察玩家是否被"残血硬撞"反复劝退。
- 🟡 **Boss atk24 单手实伤 ~20(对白 P1)≈ 22% 白 EHP**:对最脆的 P1-baseline 接近"4-5 下进死亡线",
  观感上是"明显打不过"而非"差一点"——这是有意(P1 就该被明确挡住),但留意别让玩家误读成 bug
  (06 表现层"卡关可读"要兜住,归 Planner/UI 轮)。

**被否选项:**
- **墙落「关2 入口」(精英兽人 Scene1)而非 Boss**:否。入口即墙 → 玩家关1 一通关就撞冷脸,关2 中段
  内容(暗影狼/食人魔)全被锁在墙后、永远刷不到 = "想变强却没有变强的素材"(鸡生蛋死锁)。墙落 Boss
  则关2 普通场景成为"够墙的练级带"(刷它们拿 ilvl14-24 掉落 → 进 P2 → 过 Boss),闭环自洽。
- **抬整条关2 功率带(普通场景一起抬)做"渐进难度曲线"**:否。违 Producer LESS(06 不造难度机器);
  且关2 普通场景现状本就是合理的递增练级梯度(Scene3 食人魔已吃到 ~79% 白 P1 EHP),够用。v1 一堵墙即可。
- **只抬 hp 或只抬 atk**:否,见 §4(磨血 / 秒杀尖刺,二者都违支柱)。
- **改伤害公式/加新机制制造墙**:否。纯值微调即可兑现墙,守 hard-NO(不加计划外系统、不动结构)。

## 7. 交接 / Handoff
- **本档是纯值微调**:`BossOrcChieftain` 两字段 `max_hp 220→480`、`attack 9→24`,Implementer 可直接落
  `assets/data/combat/stage_02.tres`。
- **但 06 功能整体需 Planner**:墙之外还有(a)墙后"v1 内容终点"呈现(过关2 Boss 无关3 → 收尾反馈)、
  (b)表现层"卡关可读 / 回城邀请 / 突破庆祝"占位落地(FEATURE-DESIGN §4)。这些是结构/呈现,超出纯值
  微调 → **next: `/role-planner 06-difficulty-progression`**,由 Planner 把"数值微调 + 终点呈现 + 卡关
  反馈"编成有序 PLAN(数值微调作为其中一步)。
- **playtest 验证清单**(过墙后主观裁定):① 关1 顶配纯 AFK 是否确实卡死在关2 Boss ② 回城吃关2 掉落/
  强化后回来是否"踏实地"过(非惊险压线、非空过)③ 软退安全刷期间是否安心无惩罚感 ④ 过墙庆祝是否够重。
