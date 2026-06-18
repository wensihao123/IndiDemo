---
artifact: PLAN
feature: 02-auto-combat-loop
role: Planner
status: draft
updated: 2026-06-18
inputs: [FEATURE-DESIGN.md, project-context.md, 01/floating_shell.gd, 01/floating_shell.tscn]
next: Implementer
---

# PLAN — 自动战斗循环 (Auto Combat Loop)

## 1. Goal / 目标(一句话)
落地 02 的**符号/轻演出版**自动战斗循环:1 战士(4 格队伍只填第 1 格)在配置驱动下自动
逐场景打怪→Boss、永久解锁下一关、团灭回退无尽刷、推进/修整两个宏观按钮,**后台持续 tick**,
战斗持续产出**掉落事件流**喂给 03;前台 MainArea 为当前态读出(不补演)。

## 2. Approach & key decisions / 思路与关键决策

> 全程守 project-context §4 hard-NO:平衡数值走 Resource 不硬编码;不提前为 03/04/06 抽象
> (先 3 行重复);不引插件;符号版美术用占位 primitive 不阻塞逻辑。

- **D1〔模拟落点 = Autoload 单例 `CombatDirector`〕**(用户拍板 2026-06-18)
  - **What:** 注册一个 Autoload 节点 `CombatDirector`(`src/combat/combat_director.gd`),
    它持有全部战斗/进度状态、跑固定步长 tick、发掉落与状态信号。前台视图只订阅它、读它。
  - **Why:** 后台持续推进是 MVP 硬需求(project-context §0);Autoload 天然独立于场景树,
    日后熬过"修整→城镇"(04)场景切换与存档加载(06)无需重写。
  - **Rejected:** 挂在 shell 场景下的子节点——v1 够用且更不越界,但 04/06 落地需迁移;用户
    选择一步到位的 Autoload,接受其轻微"为未落地系统提前布局"。

- **D2〔战斗解算 = 抽象 DPS 交换,无真实坐标〕**
  - **What:** 每个逻辑 tick:队伍对**当前敌人**结算伤害,敌人对**最前存活成员**结算伤害;
    敌人 HP≤0 → 死亡事件 + 掉落 roll + 下一个敌人入场;成员 HP≤0 → 倒下;队伍**≥1 人存活**
    则继续,**全灭 = 团灭**。纯数据,无 DisplayServer/UI 依赖 → 可 headless 单测。
  - **Why:** 符号/轻演出版没有走位/横版(FEATURE-DESIGN §4、F5),战斗即数值交换即可。
  - **Rejected:** 带位置/碰撞的横版解算——属 Later 全套演出,撞范围裁定。

- **D3〔平衡全部走 Resource〕**(FEATURE-DESIGN F1,守 hard-NO)
  - **What:** 自定义 Resource 脚本承载数值:`EnemyDef`(hp/atk/掉落表)、`StageConfig`
    (3 个普通场景各自的敌人 + 清场判定 + 1 个 Boss 的 `EnemyDef`)。作者手填 `.tres`:
    关1 完整、关2 至少第 1 场景且**调得稍硬**以触发卡关(FEATURE-DESIGN §6)。
  - **清场判定** = **击杀固定数量**(F1 三选一里取最简的 kill-count;波数/计时不做),数量进配置。
  - **调值意图**(Boss 略强于下一关前两场景)= 填 `.tres` 时的取值约定,**非代码硬规则**(F1)。
  - **Why:** 数值不硬编码、留 playtest 调;关数/敌人种类纯数据扩展不改逻辑。

- **D4〔进度 = (stage, scene) 游标 + 永久解锁标志〕**
  - **What:** 游标 `cur_stage:int`、`cur_scene:int`(0/1/2 = 三个普通场景,3 = Boss)。
    `max_unlocked_stage` 记录已解锁到的最高关。Boss(scene==3)击杀一次 →
    `max_unlocked_stage = max(…, cur_stage+1)`,**永久**;此后该 Boss 永不再战。
  - **Why:** Boss 是一次性门(FEATURE-DESIGN §3);游标 + 解锁标志是表达它的最小状态。

- **D5〔团灭回退规则照 FEATURE-DESIGN §3 逐条实现〕**
  - 团灭于 (S, scene i)，i∈{0,1,2} 普通场景或 3=Boss:
    - i≥1(普通):回退到 **(S, i-1)** 无尽刷。
    - i==0(本关第一场景)且 S 非首关:**跳过上一关 Boss**,回退到 **(S-1, 2)** 刷;
      在此点点推进 → 进 **(S, 0)**(**不重打 Boss**)。
    - i==0 且 S 为首关:**原地**在 (S,0) 无尽刷(无上一关可退,边缘态)。
    - i==3(Boss 未通即团灭):回退到 **(S, 2)** 刷;推进 → 重新挑战 (S,3) Boss
      (Boss 仅在**已击杀后**永不再战;未杀前可经推进重试)。
  - **Why:** 避免"卡第一场景→反复重打上一关 Boss";Boss 永不作刷怪/回退落点。

- **D6〔推进/修整按钮:倒计时 + 本轮结束执行〕**
  - 通关 Boss 后:**5 秒倒计时**,期间显示**修整**按钮;无操作 → **自动推进**到 (S+1, 0)。
  - 卡关刷怪时:**推进 + 修整 同时显示**;点击 → **入队**,在**本轮结束**执行。
    - **"本轮" 定义 = 当前敌人被击杀那一刻**(最快响应、最简;非清完整场景)。留 playtest(F4)。
    - 推进 = 从回退点进入目标关第一场景重试(D5 已定推进落点)。
    - 修整 = 触发"离开本轮"信号 → v1 落到 **stub**(暂停态/占位),真城镇 = 04(F2)。
  - **F3 立即推进按钮**:默认**不做**,只留扩展位;playtest 觉得等 5 秒烦再加。
  - **Why:** 玩家唯一杠杆,战斗仍全自动(FEATURE-DESIGN §3)。

- **D7〔掉落事件流 = 03 接口边界〕**
  - **What:** `CombatDirector` 发信号 `loot_dropped(kind: StringName, rarity: StringName)`
    —— kind ∈ {`gold`,`material`,`equipment`},rarity ∈ {`white`,`blue`,`gold`}。
    **02 只产"掉了 X 稀有度一件 / 金 / 材料"事件,物品词条细节归 03。** 稀有度/种类按
    配置掉落表 roll(走 Resource,不硬编码)。v1 接一个 **stub 监听**(打日志 + 触发视图 FX)。
  - **Why:** FEATURE-DESIGN §3/§7 明确边界,避免 02 越界进 03。

- **D8〔固定步长 tick,帧率无关 + 后台持续〕**
  - **What:** `CombatDirector._process(delta)` 用**累加器**按固定逻辑步长(`TICK := 0.1s`,
    `@export` 可调)推进模拟;不按渲染帧。这样 shell 收起态 `Engine.max_fps=15` 与展开态
    `60` 下战斗结果**一致**,且窗口失焦/被遮挡照常推进。
  - **Why:** 01 收起态降帧到 15;模拟必须帧率无关才能后台稳定推进、结果可复现。
  - **注意 minimize vs collapse:** 01 的"收起"是缩到 64×64 handle(窗口仍在,_process 照跑),
    **非最小化**;真最小化时 OS 可能节流,属 v1 范围外(留 §5 风险,手动验)。

- **D9〔视图 = MainArea 内的当前态读出(MVC 解耦)〕**
  - **What:** 新增视图脚本/节点挂在 shell `MainArea` 下,**订阅** `CombatDirector` 信号 +
    在 `_process`/显示时**读当前状态渲染**。收起时视图隐藏、模拟照跑;展开 → 直接画当前态
    (**不补演**错过的战斗,FEATURE-DESIGN §3)。
  - 视图元素(符号/轻演出):复用 01 微动 Hero 作战士;敌人用**占位 primitive**(ColorRect/
    Polygon2D + Label)从右侧出现;伤害飘字 + 战斗日志行("⚔ 击败 哥布林 +3 金");
    进度读出("第 N 关 · 场景 2/3" 或 "Boss");推进/修整按钮 + 倒计时。
  - **掉落分级 FX(守支柱 1/3):** 白=默默;蓝=轻响+光柱;金=**窗口内**一闪+音效+极短停顿;
    **限窗口内、不弹 OS 通知、不抢焦点**(FEATURE-DESIGN §4)。
  - **占位优先:** v1 用引擎内置 primitive 占位,真敌人符号/光柱/金光 FX 走 Art Spec → Image
    Prompt 下游补,**不阻塞**本期逻辑闭环(见 §5 Flag)。

- **D10〔测试遵循 project-context §5〕**
  - gdUnit4 **纯逻辑**单测(`CombatDirector` 无 UI 依赖,可 headless):战斗解算/团灭、进度
    游标/Boss 解锁、团灭回退各 case、掉落 roll 分布、按钮入队时机/倒计时。
  - UI/演出/后台 tick **手动** Play 验。每步先 `godot --headless --check-only` 过关。
  - **Godot 可执行文件 = `G:\Godot\Godot_v4.6.3\godot.exe`**(非 INTEGRATION 文档里写的
    `Godot_v4.6.3-stable_win64.exe`,后者本机不存在;见 01 CHANGES §9 旁路发现)。

## 3. Ordered steps / 有序步骤

> 每步先过 `godot --headless --check-only`。逻辑步配 gdUnit4 测试,UI/演出步手动验。

1. **平衡配置 Resource + 2 关数据**
   - 写 `src/combat/enemy_def.gd`(`class_name EnemyDef`:hp/atk/掉落表/显示名)与
     `src/combat/stage_config.gd`(`class_name StageConfig`:3 普通场景[各敌人 + kill-count] + Boss EnemyDef)。
   - 作者填 `assets/data/combat/stage_01.tres`(完整)、`stage_02.tres`(至少场景1 且稍硬)。
   - Files: `src/combat/enemy_def.gd`, `src/combat/stage_config.gd`, `assets/data/combat/*.tres`。
   - **Verify:** `--check-only` 退出码 0;在编辑器 / 单测里 `load(".tres")` 出非空、字段正确。

2. **战斗解算核心(单场战斗,无进度)**
   - `src/combat/combat_director.gd` 起步:队伍数据(4 格 slot,只填 1 战士;结构支持 N)、
     当前敌人、`tick_combat()` 一步伤害交换、敌人死亡 / 成员倒下 / 团灭判定;发
     `enemy_defeated`、`party_wiped` 信号。**不含**进度/掉落/tick 驱动。
   - Files: `src/combat/combat_director.gd`, `src/combat/party_member.gd`(若需)。
   - **Verify:** gdUnit4:① 一定 tick 后敌人 HP 归零→`enemy_defeated`;② 成员 HP 归零但
     队伍≥1 存活→战斗继续;③ 全灭→`party_wiped`。headless 跑过。

3. **掉落事件流 + 稀有度 roll(03 接口)**
   - 敌人死亡时按掉落表 roll → 发 `loot_dropped(kind, rarity)`;写一个 stub 监听打印事件。
   - Files: `src/combat/combat_director.gd`, `src/combat/loot_stub.gd`(stub 监听)。
   - **Verify:** gdUnit4:给定固定掉落表 + 注入随机种子,roll 分布落在预期区间;每次敌人死亡
     恰发 0/1 次 `loot_dropped` 且 kind/rarity 取值合法。

4. **进度状态机:场景游标 + 清场 + Boss 永久解锁**
   - 场景 kill-count 达标 → 进下一场景(0→1→2→3=Boss);Boss 击杀 → `max_unlocked_stage`
     前进 + 发 `boss_cleared(stage)`;进入下一关第一场景。
   - Files: `src/combat/combat_director.gd`。
   - **Verify:** gdUnit4:连续击杀推进游标 0→1→2→Boss;Boss 死后解锁标志 +1 且不再回到该 Boss。

5. **团灭回退逻辑(D5 全部 case)**
   - 实现 i≥1 / i==0 跳 Boss 退上一关场景3 / 首关首场景原地 / Boss 未通团灭退场景2 四条。
   - Files: `src/combat/combat_director.gd`。
   - **Verify:** gdUnit4 四个用例各一:断言团灭后游标落点正确,且推进落点不触碰已/未通 Boss 规则。

6. **推进/修整 按钮模型 + 倒计时 + 本轮结束执行**
   - 状态:`STAGE_CLEAR_COUNTDOWN`(Boss 后 5s,修整按钮 + 无操作自动推进)、`GRINDING`
     (推进 + 修整 同显,点击入队、当前敌人死亡时执行)。修整 → 发 `rest_requested`(v1 stub)。
   - Files: `src/combat/combat_director.gd`。
   - **Verify:** gdUnit4:① 倒计时到点无操作 → 自动推进;② 倒计时内点修整 → 发 `rest_requested`、
     不自动推进;③ 卡关点推进 → 当前敌人死亡那刻才切到推进目标(本轮结束执行)。

7. **固定步长 tick 驱动 + 注册 Autoload + 后台持续推进**
   - `_process(delta)` 累加器按 `TICK` 步进调 step2-6 的推进;在 `project.godot` 注册
     Autoload `CombatDirector`。
   - Files: `src/combat/combat_director.gd`, `project.godot`(Autoload 注册)。
   - **Verify:** 手动:Play → 战斗自动推进;**把 shell 收起(缩到 handle)等若干秒再展开 →
     进度已前进**(后台 tick 生效);15fps 收起态与 60fps 展开态推进速度一致(累加器帧率无关)。

8. **视图:MainArea 内当前态读出(符号/轻演出 + 掉落 FX + 按钮 UI)**
   - 新视图脚本挂 `MainArea`:订阅信号 + 读当前态渲染敌人占位、伤害飘字、战斗日志、进度读出;
     推进/修整按钮 + 倒计时;掉落分级 FX(白默默/蓝光柱/金窗口内一闪+音效+极短停顿,限窗口内)。
   - 复用 01 Hero 作战士;敌人/光柱/金光先用 primitive 占位。
   - Files: `scenes/shell/floating_shell.tscn`(MainArea 下加视图节点)、`src/combat/combat_view.gd`。
   - **Verify:** 手动 Play:余光一瞥能看懂"第几关第几场景 / 在推进还是卡关刷";收起再展开**直接显示
     当前态不补演**;金装掉落窗口内一闪不弹 OS 通知。

9. **闭环走查(2 关验收)**
   - 手动:从关1 打到 Boss → 解锁 → 推进关2;把关2 调到打不过 → 团灭 → 回退无尽刷 →
     推进重试 / 修整(落 stub)。验证 FEATURE-DESIGN §5 的体感问题。
   - **Verify:** 全链路 `--check-only` 0 + gdUnit4 全绿 + 手动闭环演示通过。

## 4. Out of scope / 明确不做
- 真实城镇回城整备(= 04);v1 "修整" 只发 `rest_requested` 信号 + stub 落点。
- 掉落物的**具体词条 / 物品实例 / 背包穿戴**(= 03);02 只产 kind+rarity 事件。
- 横版全套战斗演出(怪精灵 / 攻受击动画 / 走位 / 掉落迸出)= Later(F5)。
- 多职业 / 技能 / 真实组队 build;v1 只填 1 战士(数据留 N 人地基)。
- 离线结算(完全关程序后的收益);v1 只做"程序运行中窗口收起/失焦"的后台 tick。
- save/load(= 06)、多关数值精调 / 难度曲线调优、多区域。
- 波数 / 计时型清场判定(本期清场 = kill-count 一种)。
- 立即推进按钮(F3,默认不做,仅留扩展位)。

## 5. Risks & Flags / 风险与未决
- **〔Flag,留 Art→Image Prompt〕** 敌人符号 / 蓝光柱 / 金光 FX 的正式美术未出;v1 用 primitive
  占位**不阻塞逻辑**,但"瞥一眼可读 / 金光惊喜感"的真实手感要等占位换正式素材后才能终判
  (撞 FEATURE-DESIGN §5 验收点)。建议本期逻辑闭环后开 `/role-art-spec 02-auto-combat-loop`。
- **〔Flag,留 04〕** `rest_requested` 的 stub 落点形态(暂停 / 占位面板)需 Implementer 定一个
  最简占位;04 落地后替换为真城镇。02 不替 04 设计城镇。
- **〔风险,手动验〕** 后台 tick:01"收起"是缩窗非最小化 → `_process` 照跑;但**真最小化 /
  OS 节流 / `low_processor_mode`** 下可能停 tick。本机需实测确认收起态持续推进(step7 验收点);
  最小化场景属 v1 范围外。
- **〔风险〕** `Engine.max_fps` 由 shell 在收起态设为 15、影响全局含 `CombatDirector._process`;
  已用固定步长累加器抵消(D8),但需 step7 实测 15fps 下推进不卡顿、不掉 tick。
- **〔平衡,留 playtest〕** kill-count 数量、各场景/Boss 数值曲线("Boss 略强于下一关前两场景")、
  5 秒倒计时长短、"本轮 = 单个敌人死亡"的响应粒度——全部走配置 / `@export`,数值留 playtest 调(F1/F4)。
- **〔提醒,非本期改〕** INTEGRATION-STEPS 沿用的 Godot exe 名 `Godot_v4.6.3-stable_win64.exe`
  本机不存在,实际 `godot.exe`;校验命令请用 `godot.exe`(已记 01,留 EI 顺手改)。
