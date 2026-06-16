# Artifact Frontmatter 约定

每个 **per-feature** artifact(FEATURE-DESIGN / CONTEXT-FINDINGS / PLAN / CHANGES /
REVIEW / ASSET-SPEC / ACCEPTANCE / INTEGRATION-STEPS)文件**开头**都带这段 YAML
frontmatter,让任何冷启动的 session 一眼知道来历、状态、下一棒交给谁:

```yaml
---
artifact: PLAN                 # 类型:FEATURE-DESIGN | CONTEXT-FINDINGS | PLAN |
                               #       CHANGES | REVIEW | ASSET-SPEC | ACCEPTANCE |
                               #       INTEGRATION-STEPS
feature: 01-double-jump        # 所属功能 slug,= 目录名
role: Planner                  # 产出这份 artifact 的 role
status: draft                  # draft | accepted | superseded | blocked
updated: 2026-06-16            # 最后更新日期
inputs: [FEATURE-DESIGN.md, CONTEXT-FINDINGS.md]   # 实际消费的上游 artifact
next: Implementer              # 下一棒应由谁接手
---
```

字段语义:
- `status`:`draft` 刚产出待验收;`accepted` 人类/下游已采纳;`blocked` 卡在某个
  flag;`superseded` 被新版本取代(保留留痕,不删)。
- `inputs`:写你**真的读过并据以决策**的上游文件,不是"理论上相关"的。
- `next`:配合 HANDOFF.md 的"下一步",让交接无需口头说明。

**标准** 文件(project-context.md / BACKLOG.md / STYLE-BIBLE.md)是常驻、跨功能的,
不走这套 per-feature frontmatter,只需保留一行 `updated: YYYY-MM-DD`。
