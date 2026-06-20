---
artifact: INTEGRATION-STEPS
feature: 10-ingame-flow-nav
role: Engine Integrator
status: draft
updated: 2026-06-20
inputs: [CHANGES.md, REVIEW.md, PLAN.md, project-context.md, style-basic-2d.md, scenes/shell/floating_shell.tscn, src/shell/game_flow.gd, src/combat/town_view.gd, src/combat/combat_view.gd]
next: 作者(人)按 §B 在编辑器 Play 验收并回报
---

# INTEGRATION-STEPS · 10-ingame-flow-nav(游戏内板块流程收编 + 城镇枢纽落点 + 待回城)

## 0. 一句话 + 前提核对
集成对象 = STATE-CHANGE-02 落码:新游戏/继续**落城镇枢纽且暂停** → 出征选关出击 → 探索挂机 →
「回城」待本波结算返城 → 城镇换装/强化再出击。

**关键结论:本块无任何编辑器接线工作。** 我已逐项核对 CHANGES §5 Wiring Contract 对真码 + 真场景:
- **无 .tscn / .tres / 资源导入改动** —— `style-basic-2d.md` §4 导入预设、§7 接入校验本块不触发。
- 所需节点 `scenes/shell/floating_shell.tscn` **已全部就位、无需新建/改名/拖 @export**:
  - `GameFlow`(根 `FloatingShell` 的**末子节点**,line 80;`stages` @export 已拖
    `stage_01.tres` / `stage_02.tres`,line 88)。**末节点 = `_unhandled_input` 最先收 Esc**,
    REVIEW 确认的 Esc 集中裁决前提成立。
  - `CombatView` / `TownView`(均在 `MainArea` 下,互为兄弟,line 43 / 52)→ TownView
    `get_parent().get_node_or_null("CombatView")` 取兄弟成立。
- 所有跨层连接**代码内自完成**,无需 Node dock > Signals 手连:
  - `GameFlow._ready`:`add_to_group("game_flow")` + `Game.progression.wave_boundary_settled.connect
    (_on_wave_boundary_settled)`(game_flow.gd:32/36-37)。
  - `TownView._ready`:`add_to_group("town_view")`(town_view.gd:45)。
  - 信号源 `Game.progression` 在 GameFlow `_ready` 前已建(autoload `Game._ready→_boot` 先于场景节点)
    —— REVIEW §1 已核成立。

→ 故本文 **§A = headless 复校(可选,已绿)**,**§B = 表现层 Play 手验(本块的真正验收点)**。
照 §B 在编辑器逐项 Play 并把结果(看到什么 / 截图 / 报错)回报给我收口。

---

## A. Headless 复校(可选 · CHANGES §3 / REVIEW 已确认全绿)
> 改动纯脚本,作者若想自证可复跑;非必须。在项目根 `G:\Games\test-2` 下执行。

1. **解析 / 编译**(应 0 Parse Error):
   ```
   "G:\Godot\Godot_v4.6.3\godot.exe" --headless --import
   ```
   - Verify:命令跑完退出、终端无 `SCRIPT ERROR` / `Parse Error`。
2. **单测回归**(应 0 failures / 0 orphans;含新增 `wave_boundary_settled_test.gd` 2 用例):
   ```
   "G:\Godot\Godot_v4.6.3\godot.exe" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test
   ```
   - Verify:尾部汇总 `158` 左右 cases、`0 errors · 0 failures · 0 orphans`、退出码 0。
   - 注:headless 跑 gdUnit4 **必须带 `--ignoreHeadlessMode`**,否则 rc=103「Headless not supported」。

---

## B. 表现层 Play 手验(逐项观察并回报 · 落地 CHANGES §6)
> 入口:在 FileSystem dock 双击 `res://scenes/shell/floating_shell.tscn` 打开,按 **F6**(运行当前场景)
> 或直接 **F5**(运行主场景,若已设为主场景)。悬浮窗会贴屏底出现。

### B1. 落点 = 城镇枢纽且暂停(支柱 1 让位,D3)
1. 启动 → 应停在**主菜单覆盖层**(TITLE)。点「新游戏」(无档)或「继续」(有档)。
   - **Verify**:进入后落在**城镇枢纽**(非战斗),且**挂机不自动跑**(没有敌人在打、进度数字不滚动)。
   - **Verify**:枢纽顶部能看到进度速览(`_hub_progress`,如「第 N 关」)+ [☰] + 四入口钮。
2. (有档时)从主菜单「继续」进入,**Verify**:同样落城镇且暂停,不直接续战。

### B2. 城镇枢纽四入口 + 子板块导航(D6)
3. 依次点四入口钮:**小队 / 工匠 / 酒馆 / 出征** → 各自 overlay 打开。
   - **Verify · 小队**:能选槽位、看背包候选、换装;换装后属性差值(绿↑ / 红↓)显示。
   - **Verify · 工匠**:能选槽位、对装备「强化 +1」。
   - **Verify · 酒馆**:显占位「敬请期待」类文案(本块只接壳,符合预期,非缺陷)。
   - **Verify · 出征**:见关卡列表 —— 已解锁关可点、未解锁关**置灰 + (未解锁)**。
4. 任一子板块内点「← 返回枢纽」→ 回到枢纽四入口。**Verify**:回到枢纽且四 overlay 收起。

### B3. Esc 分层 + [☰] 菜单(R4 · Esc 权威集中 GameFlow)
5. 在某子板块(如小队)打开时按 **Esc**。**Verify**:退回枢纽(不是直接弹主菜单)。
6. 已在枢纽根(无子板块)时按 **Esc**。**Verify**:开主菜单覆盖层(MENU_OVERLAY)。
7. 主菜单覆盖层点「继续」(或再按 Esc)。**Verify**:回到城镇枢纽且**仍暂停**。
8. 枢纽的 [☰] 钮点击。**Verify**:同样开主菜单覆盖层,继续后回枢纽暂停。

### B4. 出征 → 出击开打(D4 越权防护)
9. 出征 overlay → 点「▶ 出击:继续当前进度」。**Verify**:切到**探索/战斗视图**,对应关**开打**
   (敌人出现、自动战斗运行 = running)。
10. 回城后再出征 → 选一个**已解锁**关卡钮「出击」。**Verify**:从该关场景 0 重新开打。
11. (越权检查)未解锁关钮应**点不动**(disabled)。**Verify**:无法越级出征。

### B5. 城镇改动随出击生效(resume 重快照)
12. 出击前在**小队换装**或**工匠强化**做一处改动 → 再「继续当前进度」出击。
    - **Verify**:改动在战斗中**生效**(换的装备/强化后的属性反映到战斗表现)。

### B6. 待回城:本波结算才返城(支柱 1 / 不变量 #12 · D5)
13. 探索/战斗中找到右上「**回城**」钮 → 点击。
    - **Verify**:文案变「**已请求回城 · 本波后返**」,且战斗**不立即停**(当前波继续打)。
14. 等当前波结算(清空推进 **或** 团灭回退任一波界)。
    - **Verify**:结算后**自动切回城镇枢纽且暂停**;不是立刻、不是打断本波中途。
15. (撤销 R3)再次进战斗、点「回城」置「已请求」后**再点一次**。
    - **Verify**:标记撤销、按钮文案复原「回城」、继续挂机(不返城)。

---

## Run & expected behavior(总预期)
按 B1→B6 走完一条全链路:**启动 → 落城镇暂停 → 出征选关出击 → 探索挂机 → 点回城 → 本波结算返城暂停
→ 城镇换装/强化 → 再出击生效**。全程战斗只在 TOWN 暂停(支柱 1),「回城」永不打断进行中的波。
任一步偏离「Verify」即记下现象回报,我据此判断是接受、滚 flag、还是退回 Implementer。

---

## 手验发现(作者 Play 回报,2026-06-20)
- **EI-F1 · 小队换装无"当前成员"标识**(town_view.gd:94-100 `_hero()` 写死取 roster 首个非空成员;
  小队/工匠板块无成员选择器)。打开小队直接铺装备槽 + 背包,看不出在编辑哪个队员。**v1 单成员不出错,
  招募/多成员落地后会静默永远编辑 0 号成员。** 定性:**非本块引入、非回归**(复用既有单成员换装逻辑);
  多成员切换属 v1 scope 外(project-context §0「v1 只填 1 个战士」)。**不卡本块验收。**
  - **作者裁决(2026-06-20):现在加个"当前成员标签"**(小改,只标注现有单成员,不做切换)。
  - **交 Implementer 的精确规格**(EI 不自改码):在 `_rebuild_slot_selector(col)`(town_view.gd:156)
    顶部 —— `var c := _hero()` 的 null 守卫之后、`for slot in GameKeys.SLOTS:` 循环之前 —— 插一行成员名
    Label:`var nm := c.display_name if c.display_name != "" else "队员"`;
    `col.add_child(_label("当前编辑:%s" % nm, 13, Color(0.85,0.88,0.92)))`。
    **该函数被小队(`_party_slot_col`)与工匠(`_smith_slot_col`)共用 → 一处插入两板块都生效**,
    最小改动、无新结构、无新依赖。落码后作者复跑 §B 步骤 3 验证两板块顶部都显示成员名即可。

## Flags(回报时请特别留意 · 取自 REVIEW.md,均非阻断)
- **F-N1 · 菜单开着那一波的待回城延迟**:EXPLORE 中按 [☰] 开菜单时 **sim 不暂停**(开菜单不停战)。
  若你在「已请求回城」状态下开着菜单、恰好一波在此时结算 → 该波**不触发返城**,要等关掉菜单回
  EXPLORE 后的**下一波**才返。这是支柱 1 取舍下的预期行为,**不是 bug**;手验时若撞见请知悉,别误判。
- **F-S1 · `on_depart` 的 prog==null 守卫绕过**(game_flow.gd:156-164):理论缺口、实机不可达
  (progression 启动后恒在)。正常 Play 不会触发;仅记录,EI 后建议 Implementer 一行收紧。
- **F-S2 · 出征关卡列表 `prog.stages` 与出击用 `gf.stages` 双源耦合**:当前是同一 Array、索引对齐、
  无 bug。手验若出现「点 A 关却进了 B 关」的错位,立即回报(说明该不变量被破坏);否则视为债留后续。
- **F-资源/接线假设**:本文未涉任何 .tscn/.tres/导入改动,无 @export 待填、无 Signals 待手连
  —— 已对真场景 `floating_shell.tscn` + 真码核实。若你在 Scene dock 看到与 §0 不符的节点结构
  (如 GameFlow 不是根末子节点、TownView/CombatView 不在 MainArea 下),回报截图,我重核。
