# 仓颉云侧服务

这是整个项目的业务内核。它不负责渲染界面，也不把 SQL 写在业务代码里。

## 目录

```text
server/
├── cjpm.toml
├── src/
│   ├── main.cj                 # 命令行冒烟演示（调用 CampusApi）
│   ├── domain/                 # 纯领域模型：状态机、Outcome、BizError、Clock
│   ├── repository/             # 仓储接口 + 内存实现 + TxRunner
│   │   └── sql/                # SQL 适配器（待实现，见 README）
│   ├── service/                # 报名 / 活动 / 社团 / 权限 / 消息 / 鉴权
│   ├── api/                    # DTO、JSON 编码、CampusApi 门面
│   └── transport/              # HTTP 路由 / 鉴权中间件（待实现，见 README）
├── scripts/build.ps1           # cjpm 不可用时的 cjc 兜底编译脚本
└── build/                      # 编译产物（已 gitignore）
```

依赖方向是单向的：

```text
api -> service -> repository -> domain
```

`domain` 不依赖任何仓储或网络；`repository` 只依赖 `domain`；`service` 依赖
`repository` 接口；`api` 负责把领域对象转成端云契约。SQL 适配器以后只需要
实现 `repository/repos.cj` 里的接口，service 一行都不用改。

## 构建

标准方式：

```bash
cd server
cjpm build
```

当前这台机器的 `cjpm` 在启动时崩溃（编译器和代码本身没问题），可以使用兜底脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

脚本会按 `domain -> repository -> service -> api -> main` 的顺序调用 `cjc`，
产物是 `build/campus_demo.exe`。运行前需要把仓颉运行时目录加入 `PATH`：

```powershell
$env:PATH = "C:\Program Files (x86)\Cangjie\runtime\lib\windows_x86_64_cjnative;$env:PATH"
.\build\campus_demo.exe
```

> 已在本机用 `cjc` 完整编译通过五个 package。若 `campus_demo.exe` 启动时
> 出现 `0xC0000005`，是本机仓颉运行时的问题，不是业务代码；换一台机器或
> 使用 DevEco 的仓颉工具链即可运行。编译器版本：Cangjie 1.0.5。

## 演示流程

`main.cj` 用固定时钟和内存仓储跑一遍：

1. 学生登录，浏览活动
2. 报名（带幂等键）
3. 同一个幂等键重试，验证不会重复扣名额
4. 换键重复报名，验证 `ALREADY_SIGNED`
5. 取消报名，名额归还
6. 负责人创建草稿并发布
7. 管理员审核新社团
8. 查看消息中心

它和未来 HTTP 适配器调用的是同一个 `CampusApi`，所以这些场景可以直接
变成接口契约测试。

## 接真实数据库时做什么

1. 在 `repository/` 下新增 `sql/`，实现 `UserRepository`、`ClubRepository`、
   `ActivityRepository`、`SignRepository`、`MessageRepository`。
2. 实现 `TxRunner`：`run` 里 `begin -> body -> commit`，异常时 `rollback`。
3. `tryReserveSeat` 用条件 UPDATE，`releaseSeat` 带 `remain_count < max_count`
   条件；报名记录用 `(activity_id, user_id) WHERE is_cancel = false` 唯一索引兜底。
4. 用 `server/db/schema.sql` 建表，`server/db/queries.sql` 里的 SQL 作为起点。
5. 保持 `service` 不变：业务规则、事务边界、权限判断都不应该跟着数据库方言走。

## 故意没做的事

- 没有引入宏（`@Derive`、自定义 `@RequireRole`）：当前工具链的宏运行时在
  本机不可用，先用手写 `match` 保证可编译。换到正常环境后再评估。
- 没有内置 HTTP 服务器：先把契约、业务、事务边界做对，再接 `transport` 层。
- 没有做 JWT：`InMemoryTokenService` 只用于演示，生产环境要换成带过期时间、
  可主动失效的会话服务。
