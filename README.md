# 校园活动与社团管理平台

基于 **仓颉 + ArkTS + 鸿蒙 Stage 模型** 的校园社团活动一站式平台。

- 端侧：HarmonyOS 26 / API 26，ArkTS + ArkUI
- 业务：仓颉 1.0.5，云侧服务
- 数据：PostgreSQL / 华为云 GaussDB
- 角色：学生 / 社团负责人 / 学校管理员

> 当前仓库是**地基版本**：端侧可编译出 unsigned HAP，仓颉服务五个 package
> 全部编译通过；命令行演示已写好，但本机仓颉运行时启动异常（换环境后即可运行）。
> 端云契约、数据库 schema、12 周计划和上架清单已经落文档。界面里的社团 /
> 消息 / 后台还是占位，按 12 周计划逐步补齐。

## 目录

```text
.
├── app/                    # HarmonyOS 端侧（DevEco Studio 26 打开）
│   ├── entry/src/main/ets/
│   │   ├── pages/          # Index / Login / Main / ActivityDetail
│   │   ├── components/     # ActivityCard / StateTag / EmptyState
│   │   └── common/         # ApiClient / SessionStore / models / theme
│   └── README.md
├── server/                 # 仓颉云侧服务
│   ├── src/domain/         # 纯领域：状态机 / Outcome / BizError / Clock
│   ├── src/repository/     # 仓储接口 + 内存实现 + TxRunner
│   ├── src/service/        # 报名 / 活动 / 社团 / 权限 / 消息 / 鉴权
│   ├── src/api/            # DTO + JSON + CampusApi 门面
│   ├── db/                 # schema.sql / queries.sql / seed.sql
│   └── README.md
├── docs/                   # 架构、数据库、接口、仓颉规范、上架、12 周计划
├── scripts/pptx/           # 开题 / 中期答辩 PPT 脚本
├── 校园活动与社团管理.pptx          # 修改后的开题 PPT（14 页）
├── 校园活动与社团管理_中期答辩.pptx  # 中期答辩 PPT（15 页）
├── 校园活动与社团管理_原版备份.pptx  # 修改前备份
└── app大致设计思路.docx             # 最初的设计思路
```

## 快速开始

### 端侧

1. DevEco Studio 26 打开 `app/`；
2. SDK 选 HarmonyOS 26.0.0（API 26）；
3. 建 `app/local.properties`：`sdk.dir=D:\\DevEco Studio\\sdk`（已 gitignore）；
4. 运行 `entry`。

命令行构建：

```powershell
cd app
$env:PATH = "D:\DevEco Studio\jbr\bin;D:\DevEco Studio\tools\node;" + $env:PATH
$env:DEVECO_SDK_HOME = "D:\DevEco Studio\sdk"
& "D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p product=default -p module=entry@default `
  assembleHap --no-daemon
```

### 云侧

```bash
cd server
cjpm build
```

如果本机 `cjpm` / 运行时启动崩溃，用兜底脚本（当前这台机器需要）：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

产物：`server/build/campus_demo.exe`。运行前把仓颉运行时加入 `PATH`：

```powershell
$env:PATH = "C:\Program Files (x86)\Cangjie\runtime\lib\windows_x86_64_cjnative;$env:PATH"
.\build\campus_demo.exe
```

> 说明：本机 Cangjie 1.0.5 的 `cjc` 可以完整编译五个 package，但 `cjpm` 和
> 生成的 exe 启动时会 `0xC0000005`。这是本机运行时问题；代码本身编译通过，
> 换机器 / DevEco 仓颉工具链即可运行。

## 核心设计

```text
ArkTS 端侧  ──HTTPS + JSON──▶  仓颉云侧服务  ──SQL / 事务──▶  云数据库
   UI / 状态 / 只读缓存          鉴权 / 规则 / 事务 / 幂等        唯一数据源
```

四条硬规则：

1. 端侧不直连数据库，不持有数据库凭据；
2. 云侧不信任端侧传来的角色 / 名额 / 状态；
3. 报名 = 校验 + 扣名额 + 写记录 + 写消息，在一个事务边界内；
4. 写操作带 `Idempotency-Key`，重试不重复扣名额。

详细设计：

- [总体架构与端云边界](docs/01-architecture.md)
- [数据库设计与事务](docs/02-database.md)
- [端云接口契约](docs/03-api-contract.md)
- [仓颉实现规范](docs/04-cangjie-guidelines.md)
- [上架审核准备](docs/05-appgallery-review.md)
- [12 周开发计划](docs/06-roadmap-12weeks.md)
- [Git 工作流](docs/07-dev-workflow.md)
- [开题 PPT 修改说明](docs/08-ppt-change-log.md)
- [中期答辩 PPT 说明](docs/09-midterm-defense.md)

## 开题 PPT 改了什么

按老师反馈：

1. **发挥仓颉特色** → 新增「仓颉不是胶水，而是业务内核」页；
2. **数据库交互 / 端云边界** → 新增「端云边界、数据库交互与上架审核」页，
   并把技术选型、事务实现改成「端侧不直连数据库」；
3. **上架审核（无 AI 更简单）** → 明确不涉及生成式 AI，列了隐私 / 权限 /
   账号注销 / 内容审核清单；
4. **分工细化成 12 周** → 拆成 W1–W6、W7–W12 两页，含 A/B/C 分工、周末交付物、
   里程碑和风险预案。

原版备份保留在 `校园活动与社团管理_原版备份.pptx`。

## 分支约定

- **不要直接动 `main`。**
- 个人集成分支：`Zyy`（当前）。
- 功能分支：`feat/xxx`、`fix/xxx`，合并回 `Zyy` 后再向组长仓库提 PR。
- 提交信息用 `feat:` / `fix:` / `docs:` / `test:` / `chore:`。
- 不提交 `build/`、`oh_modules/`、`local.properties`、签名文件、数据库密码。

详见 [Git 工作流](docs/07-dev-workflow.md)。

## 当前状态

| 模块 | 状态 |
| --- | --- |
| 端侧登录 / 活动列表 / 详情 / 报名取消 | 骨架可编译 |
| 端侧社团 / 消息 / 负责人后台 / 管理员后台 | 占位，待 W4–W9 |
| 仓颉 domain / repository / service / api | 可编译，内存实现 |
| SQL schema / 核心 SQL | 已出 |
| SQL 适配器 / HTTP transport | 待 W3–W4 |
| 开题 PPT | 已按反馈修改，14 页 |
| 中期答辩 PPT | 15 页，按「成果 / 问题 / 计划」组织 |
| 12 周计划 / 上架清单 | 已出 |

## 下一步

1. 接 HTTP transport：登录、活动列表、活动详情、报名 / 取消；
2. 把端侧 `Main.ets` 的占位换成真实接口；
3. 实现 SQL 适配器，跑通 W6 最小闭环；
4. 按 W7–W12 补消息、统计、管理员后台、上架材料。
