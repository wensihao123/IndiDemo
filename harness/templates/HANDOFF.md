---
feature: NN-slug                 # e.g. 01-double-jump
status: in-progress              # backlog | in-progress | done | parked
updated: YYYY-MM-DD
---
# HANDOFF — <Feature 名>

> 每个功能一份,放在 `harness/features/<NN-slug>/HANDOFF.md`。
> 它是这个功能的"单一事实来源":人类只看它就知道走到哪、下一步开哪个 role session。
> 每个 role 干完活必须更新自己那一行的状态 + "下一步"。

## 管线状态
| 阶段 | Role | Artifact | 状态 |
|------|------|----------|------|
| 设计 | Game Designer | FEATURE-DESIGN.md | — |
| 勘探 | Explorer | CONTEXT-FINDINGS.md | —(进陌生代码才需要) |
| 计划 | Planner | PLAN.md | — |
| 实现 | Implementer | CHANGES.md | — |
| 审查 | Reviewer | REVIEW.md | — |
| 美术 | Art Spec | ASSET-SPEC.md / ACCEPTANCE.md | — |
| 接线 | Engine Integrator | INTEGRATION-STEPS.md | — |

> 状态取值:`—`(未开始) / `draft` / `accepted` / `blocked` / `superseded`

## 下一步
<开哪个 role、喂哪些 artifact。例:开 `/role-planner NN-slug`,喂 FEATURE-DESIGN.md>

## 决策记录
- YYYY-MM-DD <关键决策 + 来源 artifact>

## 未决 flags
- <从各 artifact 的 "Flags / Open questions" 汇总的阻塞项;清空了就写"无">
