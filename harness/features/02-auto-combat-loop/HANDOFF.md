---
feature: 02-auto-combat-loop
status: done
updated: 2026-06-20 (frontmatter 状态校正:02 早已收口,见 BACKLOG Done/Decision log 2026-06-18)
---
# HANDOFF — 自动战斗循环 (Auto Combat Loop)

> 每个功能一份。它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 想法 | Design Jam | IDEA.md | draft(粗胚已出,8 节 + 7 条 Open threads) |
| 设计 | Game Designer | FEATURE-DESIGN.md | draft(7 节,IDEA 7 threads 全收敛 + 用户拍板关卡/团灭/修整;**+S2 拍板:回血模型 = 单场景+Boss 两道门、卡关必须真能发生**;留 F1-F5 给 Planner/平衡/跨功能) |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | —(01 已落地悬浮窗外壳,02 会建在其主区内,值得勘探) |
| 计划 | Planner | PLAN.md | draft(9 步 + 10 条关键决策;Sim=Autoload 拍板,数值全走 Resource) |
| 实现 | Implementer | CHANGES.md | draft(9 步 + **F1 美术接线增量**全落地;**32** gdUnit4 用例全绿 0 orphan;import 0;已补 REVIEW S1 偏差 4 回血/状态栏 + 偏差 5 敌人/FX 贴图 + 偏差 6 修两处测试 Variant 推断;step 7/8/9 + F1 待人工 Play 验) |
| 审查 | Reviewer | REVIEW.md | accepted(**APPROVE**,第 3 轮含 F1 美术接线增量;0 must-fix;F1 逐行复核 graceful 降级/缩放/FX 无 orphan/偏差6 测试修正均 OK;新增 N4 名签遮挡 / N5 FX 路径硬编码=契约内可接受,均不阻塞;S2 仍留 Designer) |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | accepted(13 件**整组通过、零遗留**:尺寸/透明/配色/基调/朝向全达标;M1 改名已完成=`hero_warrior.png` 在位;~~M2 朝向~~ 经用户复核已撤销=均朝左) |
| 出图 prompt | Image Prompt | IMAGE-PROMPTS.md | draft(13 条成品 prompt 编译齐 = 项目四段前缀逐字 + 单 asset 要求;`IMAGE-PROMPT-PREFIX.md` ① 已注入锁定 palette hex;各条带 image2 画布选择 + 下采样/抠图 post-gen) |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | **accepted**(**Part 1 + Part 2 全部验收通过** 2026-06-18:13 件导入 + 01 三占位转正 + 8 只敌人 `sprite` 已赋图,`--import` 退出码 0,Play 走查敌人正式贴图 + 蓝/金光柱 OK;FX 走代码无须接线) |

> 状态取值:`—`(未开始) / `draft` / `accepted` / `blocked` / `superseded` / `done`

## 下一步
**逻辑闭环已收口(2026-06-18):代码 ✅ / 审查 ✅ APPROVE / 文档 ✅ / 设计 ✅ S2 / 人工验收 ✅。**
**美术规格已出(Art Spec,2026-06-18):** `ASSET-SPEC.md` 列 13 件正式素材(敌人 8 + 掉落 FX 2 +
01 占位转正 3);`STYLE-BIBLE.md` palette/线条/视角锁定为**方案 A 暖木治愈**(hex 见 §4)。

**素材已验收通过、零遗留(Art Spec,2026-06-18):** `ACCEPTANCE.md` 出齐——13 件实测**整组 PASS**:
尺寸全命中、透明/格式对、配色落在方案 A、描边暖棕系非纯黑、基调治愈、同系怪与 Boss 可分、敌人**全部朝左**、
`fx_light_pillar` 纯白底实顶渐隐、无运行时状态烘焙。M1 改名已完成(`hero_warrior.png` 在位)、~~M2 朝向~~
经用户复核撤销(均朝左)。**素材轨道至此放行,等接线。**

**接线步骤已出(Engine Integrator,2026-06-18):** `INTEGRATION-STEPS.md` 给出点击级清单,分两部分——

**Part 1〔人类现在就能在 Godot 编辑器里照做〕**
1. **导入预设**(全 13 件,平滑风统一):确认 Project Settings → Default Texture Filter = `Linear`;
   框选 12 个透明件 → Import dock 设 Compress=`Lossless` / Mipmaps Generate=关 / Process Fix Alpha Border=开
   (可选 Detect 3D Compress To=Disabled)→ Reimport;`bg_strip.png` 同样设;提交所有 `*.import`。
2. **01 占位转正**:`floating_shell.tscn` 里 `BgStrip.Texture`→`bg_strip.png`(留 repeat/tile)、
   `MainArea/Hero.Texture`→`hero_warrior.png`(留 position 400,170 居中)、`Handle.Texture Normal`→`icon_handle.png`;保存。
3. **清占位**:对 3 个 `*_placeholder.png` 先 **View Owners…** 确认无引用,再连 `.import` Delete(⚠ 删除不可逆,有 owner 则停下回报)。
4. **headless 校验**:`godot.exe --headless --import` 退出码 0。
   - **回报给 EI 验收**:步 2/3 的 2D 视图截图(看到正式战士+背景+handle)+ 步 4 退出码与输出。
   - 顺手核 **W1**:把窗口拉宽让 `bg_strip` 平铺,目视有无竖缝(实测边缘均差 ≈3%),有则回报 Art 补 1–2px。

**Part 2〔F1 已落地 · 点击级清单已就绪,人类现在就能在编辑器照做〕**
- **F1 ✅ 已落地**(Implementer 2026-06-18):`enemy_def.gd` 加 `@export var sprite: Texture2D`(走 Resource、不硬编码);
  `combat_view.gd` 敌人占位 ColorRect→`TextureRect`(按显示高缩放、脚底落地平线、朝左无 flip;贴图缺失回退占位色块)、
  `_spawn_pillar` ColorRect→`fx_light_pillar` 贴图 + `modulate` 染稀有度 + 根部 `fx_loot_sparkle`,`_gold_flash` 保持 ColorRect。
  另修两处测试 Variant 推断(偏差 6)。**`--import` 0 + 32 用例全绿。**(详见 CHANGES §1 增量 / §4 偏差 5-6 / §5 Wiring Contract E)
- EI 已复核 `EnemyDef.sprite` 出现、FX 由代码 `preload`(无须编辑器接线),据此写成 INTEGRATION-STEPS **§Part 2 步 16–24**。

**接线轨道已收口 ✅(Engine Integrator,2026-06-18):** Part 2 人工照做并验收通过——
8 只敌人 `sprite` 在 `stage_01/02.tres` 全部赋图,`--import` 退出码 0,Play 走查敌人显示正式手绘贴图、
击杀出蓝/金光柱,用户回报"没有问题"。13 件正式素材至此全部上场,逻辑闭环 + 美术接线双轨完成。

**F1 美术接线增量已过审 ✅(Reviewer,2026-06-18,第 3 轮):** REVIEW.md verdict = **APPROVE,0 must-fix**。
逐行复核 `enemy_def.gd` 加字段(纯增、走 Resource)、`combat_view.gd` 敌人 TextureRect + graceful 降级 +
缩放/地平线对齐 + FX 染色无 orphan + 偏差6 测试类型修正,均无问题。新增 2 条非阻塞 nit:
N4(敌人名签固定位可能压到高个 Boss 贴图上沿,Play 时顺看)、N5(FX 路径硬编码 = EI 契约内、对 2 张定死视觉资源属可接受)。

**02-auto-combat-loop 整功能收口 ✅:** 逻辑(Implementer)+ 审查(Reviewer,APPROVE)+ 设计 S2(Game Designer)+
美术规格/验收(Art Spec)+ 接线(Engine Integrator,Part 1+2 accepted)+ 人工 Play 验收 全部完成。
**下一步:** 去 Producer(`/role-producer`)从 BACKLOG 起下一个功能;N4/S2 等非阻塞项随后续 playtest/平衡自然处理。

> 〔已出·Image Prompt 2026-06-18〕`IMAGE-PROMPTS.md` 13 条成品 prompt + `IMAGE-PROMPT-PREFIX.md`
> ① 注入锁定 palette hex(用户授权)。素材已据此生成并通过验收(除 M1/M2)。

> **逻辑部分已可收口**;美术为占位换正式素材的增量轨道,不阻塞逻辑闭环。
> 以下 A/B 为逻辑收口轨迹,均已完成:

**A. 文档收尾(should-fix)** — ✅ 全部完成
- **S1 〔✅ 已修+复审核实〕** — `CHANGES.md` 已与代码同步:三处回血(过场景 `:238` / 通关 `:223` /
  卡关满轮 `:209-216`)+ 小队状态栏补进 §1,§4 加偏差 4(已授权),测试计数 30→32,Wiring Contract §5 未动。
- **S2 〔✅ 已拍板,Game Designer 2026-06-18〕** — 回血模型确认为**预期**:移除跨场景 attrition(违背支柱1
  低负担陪伴),难度门槛改挂"单场景内损耗 + Boss"两道门。已写进 FEATURE-DESIGN §3"队伍回血/难度模型"
  + §5 playtest 问题 + F1。**平衡硬约束:卡关必须真能发生**(存在满血也过不去的配置点),否则取舍循环失效——
  留 Planner/playtest 守此约束调数值。代码不改。

**B. 人工 Play 验收 3 处**(只能在 Godot 里验,headless 无法验)— ✅ 用户 2026-06-18 验收通过
1. **〔✅〕step 7 后台 tick** — 收起(缩到 handle)等数秒再展开,进度应已前进;15fps 收起态与 60fps 展开态推进一致。
2. **〔✅〕step 8 视图** — 余光可读"第几关第几场景 / 推进还是卡关刷";收起再展开直接显示当前态不补演;
   金装掉落窗口内一闪、不弹 OS 通知;**小队状态栏 HP 可读**(新增,见 S1)。
3. **〔✅〕step 9 两关闭环** — 关1 打到 Boss → 解锁 → 推进关2;把关2 调到打不过 → 团灭回退无尽刷 →
   推进重试 / 修整(落 RESTING stub,**点修整后战斗永久挂起属预期 stub,非 bug**,见 REVIEW N3)。

> 已完成(Implementer,2026-06-18):PLAN 9 步代码全落地。30 gdUnit4 用例全绿(0 errors/failures/orphans),
> `--import` 退出码 0。**关键偏差(CHANGES §4):Autoload 注册名 = `Combat`**(脚本 `class_name CombatDirector`
> 与 Autoload 不能同名,Godot 强制);游戏代码取单例用 `Combat`,类型引用用 `CombatDirector`。
> 换关卡只改 `CombatView.stages` 的 `.tres` 列表(见 CHANGES §5 Wiring Contract),不碰代码。
- **PLAN 已定的关键地基(Implementer 照做,勿自行改 D1):**
  - **D1 战斗模拟核心 = Autoload 单例 `CombatDirector`**(用户拍板 2026-06-18),帧率无关固定步长 tick。
  - **D3/D7 数值与掉落表全走 Resource(`.tres`),不硬编码**(守 hard-NO);02 只产
    `loot_dropped(kind, rarity)` 事件,物品词条归 03。
  - **修整 = `rest_requested` 信号 + stub 落点**(真城镇 = 04);Boss 一次性门、团灭回退规则见 PLAN D4/D5。
- **⚠ Producer 范围裁定仍在(2026-06-18)**:02 v1 = **符号/轻演出版**;横版全套演出在 Later(F5)。
  本期敌人符号 / 光柱 / 金光 FX 用引擎 primitive **占位**,正式美术走下游 Art Spec,不阻塞逻辑闭环。

### Playtest 反馈 → 已改 / 新增 flag(Implementer,2026-06-18)
- **〔已改〕过场景回血**:每清完一个普通场景 + 通关 Boss → 全队回满(原本只在团灭回退时回血)。
- **〔已改〕卡关刷怪回血**:GRINDING 态刷满该场景 `kill_count` = 一轮完成 → 全队回满再刷,
  血不再越刷越低导致回退(用户报的 bug)。入队的推进/修整仍在单敌死亡即执行(PLAN D6 不变)。
- **〔已加测试〕** `test_party_heals_full_after_clearing_a_scene`、`test_grind_round_heals_party_so_hp_does_not_erode`。
- **〔Later/v2,已记 BACKLOG〕等级 / 经验系统** —— 击杀给经验、升级长属性。基于现 code base **低成本纯增量**
  (`PartyMember`/`EnemyDef` 加字段 + `tick_combat` 挂 `_award_xp`,曲线走 Resource);跨局保留依赖 06 存档。
  落地前需 Game Designer 定经验来源/升级曲线/升哪些属性。源:02 playtest。
- **〔Later/v2,已记 BACKLOG〕车轮战 → 团战(单场多敌)** —— 基于现 code base **中等、一处干净重构**
  (敌方引入运行时实例 + 数组、`SceneConfig.enemy`→数组、解算加目标选择规则;掉落/回退/解锁/倒计时不动)。
  队伍侧已是数组(D2 预留)。落地前需 Game Designer 定目标选择规则(集火/分散/AoE)。源:02 playtest。

### Planner 留给 Implementer / Art / playtest 的 flag(PLAN §5)
- **〔Art,逻辑闭环后开〕** 敌人符号 / 蓝光柱 / 金光 FX 正式美术未出 → 占位先行,"可读性 / 金光惊喜"
  真手感待换正式素材后终判;建议闭环后开 `/role-art-spec 02-auto-combat-loop`。
- **〔留 04〕** `rest_requested` 的 stub 落点形态由 Implementer 定个最简占位,04 落地后替换为真城镇。
- **〔手动验〕** 后台 tick:01 收起是缩窗非最小化 → `_process` 照跑;真最小化 / OS 节流 / `low_processor_mode`
  可能停 tick(属 v1 范围外)。需本机实测收起态持续推进 + 15fps 下不掉 tick(PLAN step7)。
- **〔平衡,走配置 / playtest〕** kill-count 数量、各场景/Boss 数值曲线(Boss 略强于下一关前两场景)、
  5 秒倒计时长短、"本轮 = 单敌死亡"的响应粒度——全走 Resource/`@export`,数值留 playtest(F1/F4)。
- **〔提醒,非本期改〕** Godot exe 实际为 `godot.exe`(非文档里的 `Godot_v4.6.3-stable_win64.exe`),校验命令照此。

### Game Designer 留给 Planner / 平衡 / 跨功能的 flag(FEATURE-DESIGN §7)
- **F1〔平衡,走配置〕** 场景"清怪完成"判定(杀数/波数/计时)+ 各场景/Boss 数值曲线
  (含"Boss 略强于下一关前两场景")**走 Resource/配置,不硬编码**;具体数值留 playtest 调。
- **F2〔跨功能,依赖 04〕** 修整目的地 = 04 城镇;02 v1 里"修整"仅做离开本轮的钩子 + stub 落点。
- **F3〔交互细节,留 Planner〕** 通关 Boss 5 秒倒计时是否再给"立即推进"按钮跳过等待?
  默认设计=只给修整 + 自动推进;playtest 觉得等待烦再加。
- **F4〔体感,留 playtest〕** 5 秒倒计时够不够(玩家可能在别程序里错过修整窗口);因卡关态修整
  按钮长驻,错过仍可补救,默认可接受,留观察。
- **F5〔范围已裁,提醒〕** 横版全套战斗演出在 Later;本期任何"演出"诉求按符号/轻演出版做。

## 决策记录(jam 阶段)
- 2026-06-18 战斗呈现 = **有演出的小队横版打怪**(战士左、怪从右来,看得到走位/挥砍/飘字/掉血/掉落迸出)。来源:用户。
- 2026-06-18 探索结构 = **刷波 + 推进 混合**(平时原地刷波稳定产出,攒够攻势推进到更深更硬一段)。来源:用户。
- 2026-06-18 掉落反馈 = **按稀有度分级高调**(白默默/蓝轻响光柱/金全屏一闪+音效+0.3s 停顿)。来源:用户。

## 未决 flags(滚动到 IDEA §8,供 Game Designer / Producer)
- 推进闸门(击杀数/进度条/清波/计时)+ 区域是否有底/小 boss。
- 玩家在 02 是否有杠杆(纯观众 vs 开始/选区域/休整);与 04 城镇边界相关。
- 战士受伤/团灭如何收场(影响"低负担陪伴"手感)。
- 前台演出 ↔ 后台不可见模拟如何解耦/对齐。
- 金装演出强度/频率/作用域,避免打扰(撞支柱 1)与赌场化(撞支柱 3)。
- 掉落→03 接口边界(建议 02 只产"掉了 X 稀有度一件"事件)。
- ~~〔Producer 范围〕"有演出"成本远超 01,v1 演出版 vs 符号/日志版~~ → **已裁定(2026-06-18):
  v1 = 符号/轻演出版,横版全套演出移入 Later**(见上"下一步"与 BACKLOG decision log)。
