---
artifact: BALANCE-CHANGE
feature: 08-team-combat
role: Num Smith
status: draft
updated: 2026-06-20
inputs: [BALANCE.md, balance/BALANCE-CHANGE-03-team-combat.md, balance/BALANCE-CHANGE-04-difficulty-progression.md, harness/features/08-team-combat/FEATURE-DESIGN.md, assets/data/combat/stage_02.tres, assets/data/combat/stage_01.tres, src/combat/scene_config.gd, src/combat/enemy_def.gd, src/core/combat/progression_controller.gd]
next: Implementer
---

# BALANCE-CHANGE-05 — 关2 团战铺波(复算落值)

## 1. 触发 / Trigger
BALANCE-CHANGE-03(团战 08)§6/§7 显式 defer:**"关2 敌单值更高,照搬关1 的 WAVE_SIZE+配比会过载;
Implementer 落关2 `.tres` 前回 num-smith 复算一次。"** Producer 在 06 收口后把"关2 `.tres` 团战铺波"
列为 Next①。本文即这次复算:把关2 三个普通场景从**单敌**(现状)改写成团战波,给出确切组成 +
2 个新远程 EnemyDef 数值 + `kill_count` 调整,交 Implementer 直接落 `stage_02.tres`。

用户 2026-06-20 拍板波规模哲学:**"守 ≤4,靠敌单值加压"**——难度来自更高敌单值、不靠人海,
不改代码(`MAX_WAVE_SLOTS=4` / `melee_gate_capacity G=2` 均不动)。本文在该哲学下落安全值。

## 2. 现状诊断 / Diagnosis
**`stage_02.tres` 三个普通场景仍是单敌**(`Scene1=EliteOrc` / `Scene2=ShadowWolf` / `Scene3=Ogre`,
全走旧 `enemy` 单敌 fallback,无 `enemy_group`)——08 团战门控/排位/远程机制在关2 **完全没被行使**。
关1 已是团战(Scene1 2近 / Scene2 2近+1远 / Scene3 3近+1远),关2 反而退回单敌 = 体验断档。

**根因不在"敌不够多",而在两条耦合约束**,直接决定关2 能铺多重的波:
- **约束 A:关2 敌单值是关1 的 ~2.3×。** 关1 兽人 hp28/atk3 → 关2 食人魔 hp85/atk7。**照搬关1 的
  Scene3=4(3 近战+1 远程)配比,关2 会过载**(见 §6 被否项实算:Scene3=4 单波 ~42% EHP,两波近团灭)。
- **约束 B(主导项):场景内波间不回血。** `progression_controller.gd` 的 `_revive_party()` **只在
  清场时**调用(`_kills_this_scene >= kill_count`),**同场景波与波之间不回血、阵亡不复活**。
  → 一个场景的总承伤 = `ceil(kill_count / WAVE_SIZE)` 波**累积**,不是单波。`kill_count` 与 `WAVE_SIZE`
  必须**一起**定,否则单波看着安全、整场叠下来团灭。关2 现 `kill_count=7`、若 `WAVE_SIZE=3` → 每场 3 满波累积,
  关2 单值下直接爆。这是关1 没充分暴露、关2 必须正面处理的约束。

诊断结论:关2 波规模要**比关1 更克制**(用户哲学一致),且**同时收 `kill_count`** 把每场累积波数压到 2,
让关2 普通场景是"踏实可刷的练级带",把墙单点留在 Boss(BALANCE-CHANGE-04,本文不碰)。

## 3. 目标数值 / Target numbers(delta vs `stage_02.tres` 现状)

### 3a. 三普通场景波组成(WAVE_SIZE 统一 = 3,门控 G=2 不变)
| 场景 | 现状 | 目标波(序=排位前→后) | 近/远 | `kill_count` |
|------|------|------------------------|-------|--------------|
| Scene1 | `EliteOrc`×1 | `[EliteOrc, EliteOrc, EliteOrc]` | 3 近 / 0 远 | **7→6** |
| Scene2 | `ShadowWolf`×1 | `[ShadowWolf, ShadowWolf, RangedSlingerS2]` | 2 近 / 1 远 | **7→6** |
| Scene3 | `Ogre`×1 | `[Ogre, Ogre, RangedSlingerS3]` | 2 近 / 1 远 | **7→6** |
| Boss | `BossOrcChieftain`×1 | **不动**(墙,BALANCE-CHANGE-04) | 1 | — |

- **WAVE_SIZE 全 = 3**(非用户预览的 1/3/3/4 里的 Scene3=4):比关1(2/3/4)整体收一档,
  完全贴合"靠敌单值加压、不靠人海"——关2 单值已是难度来源,波规模拉平到 3 即可,见 §6 偏离说明。
- **关2 普通近战(EliteOrc/ShadowWolf/Ogre)数值全不动**——hp/atk/ilvl/掉落维持现值(墙文档只抬 Boss)。
- **`kill_count` 7→6**:与约束 B 配套,使每场 = `ceil(6/3)=2` 满波累积(整除、干净)。同时对齐关1
  多波场景约定(关1 Scene2/Scene3 已是 `kill_count=6`)。
- **Scene1 纯近战**:作为关2 团战入门场,远程留到 Scene2 起引入——对齐关1(Scene1 也纯近战 2 哥布林)。
  `floor(WAVE_SIZE/3)=1` 的远程配比指南从 Scene2 起兑现,Scene1 故意降一档为可读入门,见 §6。

### 3b. 2 个新远程 EnemyDef(`position_class = 1` RANGED;权重套同档近战 0.6×)
按 BALANCE.md §5:`远程 attack≈0.6×同档近战、hp≈0.6×同档近战`(漏血而非主伤),`drop_chance/item_level`
对齐同场景近战、稀有度权重照关2 梯度。

**`RangedSlingerS2`(配 Scene2,基准 = ShadowWolf atk6/hp65/ilvl18):**
```
display_name   = "投石暗影手"   # 占位名,Art Spec 可改;沿用暗影狼贴图占位
position_class = 1              # RANGED,不受门控
max_hp         = 40.0          # 0.6×65 = 39 → 40
attack         = 4.0          # 0.6×6 = 3.6 → 4
item_level     = 18           # = ShadowWolf 同场景
drop_chance    = 0.6
weight_gold=60 / weight_material=25 / weight_equipment=15
rarity_weight_white=78 / blue=18 / gold=4
```

**`RangedSlingerS3`(配 Scene3,基准 = Ogre atk7/hp85/ilvl24):**
```
display_name   = "投石食人魔"   # 占位名;沿用食人魔贴图占位
position_class = 1
max_hp         = 50.0          # 0.6×85 = 51 → 50
attack         = 4.0          # 0.6×7 = 4.2 → 4
item_level     = 24           # = Ogre 同场景
drop_chance    = 0.65
weight_gold=55 / weight_material=27 / weight_equipment=18
rarity_weight_white=72 / blue=22 / gold=6
```
> 两远程 atk 都落 4(0.6× 后四舍五入撞值,档距太近),靠 hp(40 vs 50)与 ilvl(18 vs 24)区分深度,可接受。
> 贴图本期沿用同场景近战占位(`sprite` 字段),专属远程美术留 Art Spec / 全局 UI·juice 轮,不挡数值落地。

### 3c. 承伤校验(目标值,峰值并发 DPS × 清场时长法,BALANCE-CHANGE-03 §3d)
模型:敌 `attack_speed=1`(默认);近战门控 G=2(同时最多 2 名活跃)、远程恒输出;到手系数 =
`1 − armor/(armor+50)`(P1-顶配 armor16 → ×0.758;P1-基线 armor11 → ×0.82);玩家清场 DPS P1-顶配≈34。

**单波承伤(% 当前 EHP):**
| 场景 | 单波 raw 累计 | P1-顶配(EHP220) | P1-基线(EHP173) |
|------|---------------|------------------|------------------|
| Scene1(3 近) | ~36.7 | 27.8(**12.6%**) | 30.1(17.4%) |
| Scene2(2 近+1 远) | ~54.2 | 41.1(**18.7%**) | 44.4(25.7%) |
| Scene3(2 近+1 远) | ~78.5 | 59.5(**27.0%**) | 64.4(37.2%) |

**整场累积(`kill_count=6` → 每场 2 满波、波间不回血):**
| 场景 | P1-顶配累积 | P1-基线累积 |
|------|-------------|-------------|
| Scene1 | ~25% | ~35% |
| Scene2 | ~37% | ~51% |
| Scene3 | **~54%** | **~74%** |

→ **即使 P1-基线(刚通关1 的地板玩家)整场累积也 < 100%、不团灭**;Scene3 P1-基线 ~74% 是最紧的一档
(刻意——最深普通场景、紧贴 Boss 墙前),但仍留生存余量。关2 普通场景 = 可持续练级带,墙单点在 Boss。✓
单波 P1-顶配 12–27%,落在 BALANCE-CHANGE-03 §3d 目标带(单波 ≲ 20–25% EHP;Scene3 27% 略高但因
波间累积已用 `kill_count` 兜住,整场 54% 安全)。

## 4. 调整策略 / Strategy(依赖序,交 Implementer 直接落 `.tres`)
纯数据改 `stage_02.tres`,无代码改动(结构 08 已建,WAVE_SIZE≤4 适配 `MAX_WAVE_SLOTS=4`)。按序:
1. **先建 2 个远程 `sub_resource`**(`RangedSlingerS2` / `RangedSlingerS3`,§3b 值)——它们是波数组要引用的叶子,先存在。
2. **改三场景为 `enemy_group`**(§3a):各场景加 `enemy_group = Array[...]([...])`,序 = 排位前→后;
   **保留旧 `enemy` 单敌字段**(fallback,`scene_config.gd:8-9` 约定,勿删)。
3. **同步收 `kill_count` 7→6**(三普通场景;Boss 无此字段)。
4. **Boss `sub_resource` 一字不动**(墙)。
5. 落值后跑回归:`stage_config_test`(关2 锁值用例 + 现有)应仍绿;若有团战波装载用例一并核。
   建议补一条锁值用例锁住"关2 三场景 `wave_defs().size()==3`、Scene2/3 末位 `position_class==RANGED`"防静默回退。

**牵动项(派生)**:`kill_count` 是这次唯一与波规模耦合的旋钮——若后续 playtest 要调关2 难度,
**优先动 `kill_count`(整场累积波数)再动波组成**,因波间不回血,`kill_count` 杠杆比加减一只怪更猛。

## 5. 影响面与迁移 / Blast radius & migration
- **触及文件**:仅 `assets/data/combat/stage_02.tres`(纯 Resource 数据)。+ 可选 `test/combat/stage_config_test.gd` 补锁值用例。
- **无代码改动**:`scene_config.gd` / `enemy_def.gd` / `progression_controller.gd` / `combat_view.gd` 均不动;
  `MAX_WAVE_SLOTS=4`、`melee_gate_capacity=2` 不动(WAVE_SIZE=3 ≤ 4)。
- **存档迁移:无。** 关卡配置是只读 Resource,不进存档;`PlayerState`/`SaveSystem` 存的是进度游标/装备,
  与波组成无关。老档重 boot 后照新波打,无字段迁移。
- **接线:无新接线**(Wiring 同 08——`CombatView.stages` 已含 `stage_02.tres`;改的是其内部 `sub_resource`)。
- **掉落经济**:新远程 `drop_chance`/权重对齐同场景近战,关2 击杀总数微增(每场多 2 只怪/波 × 2 波),
  材料/掉落产出小幅上行,仍在 BALANCE.md §4 "产出 > 消耗、净累积"区间,无失衡,无需调掉落。

## 6. 风险与被否选项 / Risks & rejected alternatives
- **被否:Scene3=4(3 食人魔 + 1 远程,= 用户预览图示值)。** 实算单波 raw ~123.5 → P1-顶配 ~42.5% EHP、
  P1-基线 ~58% EHP;`kill_count` 即便收到 6 也是 2 满波 → P1-顶配 85%、**P1-基线 ~117% = 团灭**。
  关2 单值下"3 近战 G=2 排队 + 高 atk 食人魔"承伤过载,违背"关2 普通场景应可持续刷"的意图(墙应单点在 Boss)。
  **故偏离用户预览的 Scene3=4,落 Scene3=3。** 这不违背用户的**哲学选择**("守 ≤4、靠敌单值加压"
  ——3 比 4 更"靠单值不靠人海",方向完全一致);预览里的 4 是图示档位、非硬指标,num-smith 拥有确切值,
  按承伤实算收到安全带。**这是本文最重要的一处偏离,Implementer 照本文 Scene3=3 落值,勿照预览。**
- **偏离:WAVE_SIZE 拉平为全 3(非关1 的 2/3/4 递增) + Scene1 纯近战。** 关2 靠单值加压,波规模无需再随深度涨;
  Scene1 纯近战对齐关1 入门场、给团战一个可读起步。属哲学内的合理收口,非过载规避。
- **🟡 待 playtest 主观裁定**:① 关2 普通场景"踏实可刷"手感(Scene3 P1-基线 74% 累积是否过紧);
  ② 远程漏血感是否成立(atk4 在到手系数后单下 ~3 血,需多下累积才显著)。调参旋钮:太紧先降 `kill_count`
  (6→5,每场仍 2 波但第二波不打满)或降远程 atk;太松抬 `kill_count` 或给 Scene3 补第 2 远程(破 v1 远程上限 1,慎)。
- **🟡 波间不回血是承伤主导项**——本文所有累积值建立在"场景内零回血、阵亡不复活直到清场"上。
  若未来加入波间小回血/或阵亡中途复活,关2 承伤会骤松,需回本文复算上调难度。记为依赖前提。
- **🟢 远程数守 v1 上限 1**(`floor(WAVE_SIZE/3)=1`),门控 G=2 不动,i8 威胁纯加性不破(无数量乘子)。

## 7. 交接 / Handoff
- **next: Implementer**(纯 `.tres` 数据落值,无结构/代码改动)。喂本文 §3+§4 直接改 `stage_02.tres`:
  建 2 远程 `sub_resource` → 三场景改 `enemy_group`(保留 `enemy` fallback)→ `kill_count` 7→6 → Boss 不动 →
  跑 `stage_config_test` 回归(建议补关2 波结构锁值用例)。
- **playtest 验证点**(§6 🟡):关2 普通场景可持续刷的手感、Scene3 最深档紧度、远程漏血感;
  调参优先级 `kill_count` > 远程 atk > 波组成。
- BALANCE.md 已同步:§3f 敌人锚点补关2 远程行、§5 团战指南标注关2 波规模落定于本文、§6 关2 单敌断档债关闭。
