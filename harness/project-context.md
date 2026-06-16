# Project Context (shared by all roles)

> 这是所有 role 的"共享内存"。每个 session 都应先读这一份。
> 保持它简短、事实化、可信——它一错,所有 role 跟着错。
>
> 用法:把本模版复制到游戏项目的 `harness/project-context.md` 并填实所有占位符。

## 0. 游戏一句话 + 支柱
- 这是个什么游戏,给谁玩:[e.g. 高难度但宽容的 2D 平台跳跃,给硬核手感党]
- 设计支柱(2-4 条,所有 feature 都要服务它们):
  - [e.g. 死亡永远是"我的错,但只差一点"]
  - [e.g. 即死即重开,零等待]
- v1 的完成定义(给 Producer 用):[e.g. 15 关 + 1 个 boss,可上架的最小版本]

## 1. 引擎与技术栈
- 引擎 + 版本:Godot [e.g. 4.3 stable]  ← 务必写准,Integrator 按这个版本给步骤
- 脚本语言:[GDScript / C#]
- 目标平台:[e.g. PC (Windows/Linux), itch.io]
- 美术风格基线:[e.g. 像素风,基准分辨率 320x180,整数缩放]
- 测试:[e.g. gdUnit;命令 ...]
- 其它工具:[lint / format / 静态检查命令]

## 2. 目录约定
```
<game-project>/          [Godot 项目根,= res://]
  project.godot
  src/                    [脚本]
  scenes/                 [.tscn]
  assets/
    sprites/
    audio/
  harness/                [role 的 artifact,纳入版本控制]
    project-context.md    [本文件]
    BACKLOG.md            [Producer]
    STYLE-BIBLE.md        [Art Spec]
    features/<NN-slug>/   [每个功能一目录:FEATURE-DESIGN / PLAN / CHANGES / ... / HANDOFF.md]
```

## 3. 代码约定
- 命名:[e.g. 文件 snake_case,节点 PascalCase,signal 过去式 died/jumped]
- 风格:[e.g. 优先 composition over inheritance;早返回]
- 信号 vs 直调:[e.g. 跨系统用 signal,父子内部可直调]
- 注释:[e.g. 只在"为什么"不显然时注释]

## 4. 禁止事项(hard NOs)
- [e.g. 不引入新插件/AddOn,除非计划明确批准]
- [e.g. 不动 `src/legacy/**`]
- [e.g. 密钥/路径不硬编码]
- [e.g. 不做计划外的"顺手重构"或"顺手加功能"]

## 5. 验证一次改动是否 OK 的标准流程
按顺序,全绿才算通过:
```
[e.g. godot --headless --check-only]
[e.g. 跑测试命令]
[e.g. 手动:打开 X 场景按 Play,观察 Y]
```

## 6. 当前已知的坑 / 临时约束
- [e.g. 输入系统正在重构,别动 input_manager]
- [e.g. 某 autoload 还没建,依赖它的功能要先 flag]
