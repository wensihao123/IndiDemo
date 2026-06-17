---
feature: 01-floating-window-shell
status: done
updated: 2026-06-18
---
# HANDOFF — 悬浮窗外壳 (Floating Window Shell)

> 每个功能一份。它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | accepted |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | —(空项目无既有代码,预计可跳过) |
| 计划 | Planner | PLAN.md | draft(7 步 + 8 条关键决策,可交 Implementer) |
| 实现 | Implementer | CHANGES.md | 人工 Play 验收通过 + REVIEW 后清 2 项 nit(headless --check-only 退出码 0) |
| 审查 | Reviewer | REVIEW.md | APPROVE WITH NITS:无 must-fix;2 项非阻塞清理(死参数 / 隐式 get 依赖) |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | accepted:三件占位素材全部通过(hero 脚底已修订贴底) |
| 出图 prompt | Image Prompt | IMAGE-PROMPTS.md | accepted(3 件已生图并通过技术预检) |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | accepted:Phase 1 + Phase 2 全部人工验收通过(接线/项目设置/Run 无问题) |

> 状态取值:`—`(未开始) / `draft` / `accepted` / `blocked` / `superseded`

## 下一步
**REVIEW 两项 nit 已清(Implementer)**(2026-06-18,CHANGES §9):① 删死分支
`_apply_expanded_geometry`,`_ready` 改走 `_snap_window(_expanded_rect())`;② `_layout_main_area`
改接 `win_w` 形参,去掉"set 后立刻 get window size"的隐式依赖。纯重构无行为变更,
`godot.exe --headless --check-only --script floating_shell.gd` **退出码 0、无解析错**。
**至此 设计→实现→接线→审查→清理 全链路走完,REVIEW must-fix 与 nit 均已结清,本功能完成。**

- **✅ 已结项(Producer,2026-06-18)**:01 移入 BACKLOG 的 Done;Now 推进到 **02-auto-combat-loop**。
  下一棒不再属于本功能 —— 开 `/role-game-designer 02-auto-combat-loop`(或先 `/design-jam`)起 02。
- **留作 backlog 的非阻塞项**:R2 全局热键(失焦也响应)建议另立项;ACCEPTANCE F-BG1/F-BG2
  背景接缝/信息量待正式美术;STYLE-BIBLE 调色板 hex/线条参数待正式美术前补。
- **⚠ 给 EI 文档修正**:INTEGRATION-STEPS 命令里的 `Godot_v4.6.3-stable_win64.exe` 在本机不存在,
  实际可执行文件是 `G:\Godot\Godot_v4.6.3\godot.exe`(见 CHANGES §9 旁路发现);下次 EI session 顺手更正路径。

## PLAN 留给后续的待确认点(非阻塞)
- R2:全局快捷键(失焦也响应)本期不做,建议另立 backlog 项;本期热键仅窗口聚焦时生效。
- R1:收起/展开若 OS 窗口几何 Tween 在 Windows 抖动,退路=瞬切几何+仅内容滑动。
- R3:`screen_get_usable_rect` 避开任务栏需在你的机器实测确认。
- 快捷键默认 F1=收起 / F2=置顶,Implementer 可改。

## 决策记录
- 2026-06-17 直接从 project-context + BACKLOG 起手设计,未跑 Design Jam(需求清晰)。来源:用户指示。
- 2026-06-17 外壳定位为支柱 1"伙伴"的物理载体;本期可见成果 = 一个待机微动的占位角色。来源:FEATURE-DESIGN.md。
- 2026-06-17 4 个设计 flag 全部拍板(来源:用户):
  F1 默认置顶 + 快捷键可切换;F2 窗口坐任务栏之上、贴上沿不重叠;F3 收起用屏幕边缘 handle;
  F4 "还在挂机"微提示推到 02,本期只做静态 handle。

## 未决 flags
- 〔Impl 偏离,已记 CHANGES §4〕**F1/F2 走代码原始键码,无 InputMap 动作**;**待机微动用 `_process`
  正弦而非 AnimationPlayer**;3 纹理在 .tscn 内 `ext_resource` 引用(无 `@export` 纹理字段)。
  → EI 不必在 Input Map 面板加动作、不必拖拽纹理。
- 置顶/收起快捷键默认 F2/F1(PLAN),Implementer 可改(脚本 `@export`)。
- ~~〔需 EI/setup〕style-basic-2d.md 提升到 harness 根并填占位~~ → **已完成**(2026-06-17,EI):
  已提升,填实"平滑风→Linear、Stretch=disabled、主区 800×250"等项目特例。
- 〔EI→Impl〕**PLAN R4 措辞已纠正**:Godot 4 无逐图"导入 repeat";平铺靠 bg `TextureRect` 的
  `texture_repeat=Enabled`(Phase 2 节点级设),非导入设置。
- 〔EI〕全局快捷键(失焦也响应)Godot 无内建,本期仅焦点内热键;真全局热键建议另立 backlog(PLAN R2)。
- 〔setup〕`G:\Games` 当前非 git 仓库;`.import` 提交 / `.godot` gitignore 待 `git init` 后落地(EI F4)。
- 〔Art〕调色板 hex、线条精确参数占位阶段未锁;正式美术前需回 STYLE-BIBLE 补并重出 spec。
- 〔Art,留正式美术〕背景接缝未真无缝(RGB 差 ~17.5)、背景信息量偏高有抢戏风险(ACCEPTANCE F-BG1/F-BG2)。
