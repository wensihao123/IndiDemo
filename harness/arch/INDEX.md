# arch/ 索引

跨功能的架构调整文档(Arch Guard 产出)。架构事实源在 `harness/ARCHITECTURE.md`。

| # | 文档 | 触发 | 状态 | 下一步 |
|---|------|------|------|--------|
| 01 | [REFACTOR-01 底层地基重设计](REFACTOR-01-foundation-redesign.md) | 04 装不进旧结构 + 用户决定整体重铺(组件化/模板实例/modifier/PoE 装备/lane 团战) | draft | `/role-planner 00-foundation-redesign`(把 §4 八层拆成有序 PLAN);Producer 回写 BACKLOG/project-context |
| 02 | [REFACTOR-02 PlayerState 座位决策](REFACTOR-02-playerstate-seat.md) | REFACTOR-01 步 5 autoload 注册的座位分叉(EI 〔F-Arch-seat〕):单座 vs 拆座 | draft | `/role-planner 00-foundation-redesign`(把 §4 四步落成步 5 §0 PLAN:`PlayerState.reset()` → `_boot` 改读全局+reset-on-boot → 测试隔离收口) |
| 03 | [REFACTOR-03 城镇强化+元操作+暂停恢复](REFACTOR-03-town-meta-ops.md) | 05-town:强化等级 / 战斗外读写持久态 / 进城暂停挂机 —— **判定=装得下,加性扩展无需重构** | draft | `/num-smith 05-town-gear-upgrade`(强化数值+材料经济)→ `/role-planner 05-town-gear-upgrade`(§4 五步依赖序落 PLAN) |
| 04 | [REFACTOR-04 团战:一波多敌+近/远站位门控](REFACTOR-04-team-combat.md) | 08-team:一波多敌 —— **判定=装得下,但需拆 Arena↔Progression 刷怪/推进契约(每杀一只→每清一波,新不变量 #12)+ EnemyDef/SceneConfig 加性扩展 + 点亮 in_range 门控。波 size=1 向后等价** | draft | `/num-smith 08-team-combat`(波规模/近远配比/门控容量 G/远程伤害权重,守 i4)→ `/role-planner 08-team-combat`(§4 五步依赖序落 PLAN,步 3 契约拆分单独成步) |

> 执行家:`harness/features/00-foundation-redesign/`(放 PLAN/CHANGES/REVIEW);设计源 = 本 REFACTOR-01 + `harness/ARCHITECTURE.md`。03/04 留作设计/历史档。
