# 总体架构与端云边界

## 1. 一句话架构

**ArkTS 负责界面与交互，仓颉负责业务正确性，云数据库负责持久化。**

三者之间只有两条通道：

```text
ArkTS 端侧  ──HTTPS + JSON──▶  仓颉云侧服务  ──SQL / 事务──▶  云数据库
   UI / 状态 / 只读缓存          鉴权 / 规则 / 事务 / 幂等        唯一数据源
```

```text
┌────────────────────────────── ArkTS 端侧 ──────────────────────────────┐
│ pages / components / viewmodel                                         │
│        │                                                               │
│        ▼                                                               │
│  ApiClient（唯一网络出口）      SessionStore（token / user / 只读缓存） │
└───────────────────────────────┬────────────────────────────────────────┘
                                │ HTTPS + JSON
                                │ Authorization: Bearer <token>
                                │ Idempotency-Key: <uuid>（写操作）
┌───────────────────────────────▼────────────────────────────────────────┐
│                         仓颉云侧服务（CampusApi）                       │
│  AuthService   ActivityService   ClubService   SignUpService   Message  │
│        │                                                               │
│        ▼                                                               │
│  TxRunner（事务边界）                                                   │
│        │                                                               │
│        ▼                                                               │
│  UserRepository / ClubRepository / ActivityRepository / SignRepository  │
└───────────────────────────────┬────────────────────────────────────────┘
                                │ SQL（参数化，私网）
┌───────────────────────────────▼────────────────────────────────────────┐
│              云数据库 PostgreSQL / GaussDB（唯一数据源）                 │
└────────────────────────────────────────────────────────────────────────┘
```

## 2. 端云边界：四条硬规则

1. **端侧不直连数据库。**
   端侧没有数据库地址、账号、密码，也不执行 SQL。所有读写都经过
   `ApiClient` → 仓颉服务。

2. **云侧不信任端侧。**
   角色、权限、名额、状态流转全部在云侧重新校验。端侧传来的 `role`、
   `remainCount`、`state` 只用于展示，不能作为业务依据。

3. **事务边界在 service 层。**
   报名 = 「校验 + 扣名额 + 写报名记录 + 写消息」，必须在一个事务里。
   `TxRunner.run { ... }` 是唯一的事务入口；repository 只提供原子操作，
   不自己开事务。

4. **写操作幂等。**
   端侧为每次用户动作生成一个 `Idempotency-Key`，重试时复用同一个键。
   云侧用唯一索引兜底，重复请求返回第一次的结果，不重复扣名额。

## 3. 为什么把业务放在仓颉侧

报名业务最容易出错的地方不是页面，而是：

- 多人同时报名，剩余名额被超扣；
- 用户重复提交，产生多条报名记录；
- 报名截止后仍能取消，名额被错误归还；
- 负责人越权操作别的社团；
- 活动状态从「已结束」被改回「报名中」。

这些都需要强类型、显式错误分支和事务支持。仓颉侧的实现方式：

| 仓颉特性 | 在本项目中的落点 |
| --- | --- |
| 封闭 enum + 穷举 `match` | `ActivityState` 状态机；新增状态时编译期提醒补分支 |
| 泛型 enum `Outcome<T, E>` | 报名 / 取消 / 发布等业务统一返回成功或可枚举错误 |
| `Option<T>` | 查询结果、可空外键、负责人所属社团 |
| 接口 + 依赖注入 | `Repository`、`TxRunner`、`Clock` 都可在内存 / SQL / 测试实现间切换 |
| 并发原语 | 内存实现用 `Mutex` 串行化写操作；SQL 实现用行锁 + 条件更新 |
| C FFI（`@C`，可选） | 核心校验库导出给端侧做提交前预校验；最终裁决仍在云侧 |
| cjpm / cjc | 包管理与编译；`cjpm.toml` 声明模块，`src/` 下按目录分包 |

> 我们没有为了「用特性而用特性」。`Outcome`、状态机、`Clock` 注入都是
> 因为报名业务确实需要它们；宏暂时不用，见 `04-cangjie-guidelines.md`。

## 4. 端侧分层

```text
pages/            页面：只负责渲染与用户事件
components/       可复用 UI：ActivityCard、StateTag、EmptyState
common/api/       ApiClient：唯一网络出口，统一错误 / token / 幂等键
common/auth/      SessionStore：preferences 里的会话
common/models.ets 与端云契约一一对应的 DTO
common/constants/ 颜色、间距、字号 token（与 PPT 同一套色板）
```

页面不直接调用 `http`，也不直接 `JSON.parse` 响应；这些都在 `ApiClient`
里完成。这样换 mock、换 baseUrl、加日志都只改一个地方。

## 5. 云侧分层

```text
api/           DTO + JSON 编码 + CampusApi 门面
service/       业务规则、权限、事务编排
repository/    仓储接口 + 内存实现 + TxRunner
domain/        纯模型、状态机、Outcome、BizError、Clock
transport/     （待补）HTTP 路由、鉴权中间件、请求反序列化
```

依赖方向单向：`api → service → repository → domain`。

- `domain` 不依赖任何仓储、网络、数据库。
- `service` 只依赖接口，不知道底层是 HashMap 还是 PostgreSQL。
- `repository` 的内存实现用于演示和测试；SQL 适配器按同样接口实现。
- `api` 负责把领域对象转成 DTO，不写业务规则。

## 6. 一次报名的完整链路

```text
1. 用户在活动详情页点「立即报名」
2. 端侧生成 Idempotency-Key（同一动作重试时复用）
3. POST /v1/activities/{id}/sign-ups
   Authorization: Bearer ...
   Idempotency-Key: ...
4. 云侧鉴权，得到 Actor(userId, role, leaderClubId)
5. SignUpService.signUp：
   a. 查活动，校验存在 / 状态 / 报名时间
   b. 查是否已有未取消报名 -> ALREADY_SIGNED
   c. 查幂等键 -> 命中则返回原结果
   d. tryReserveSeat：条件 UPDATE，rowcount=1 才算占到名额
   e. 写报名记录（唯一索引兜底）
   f. 写站内消息
   g. 提交事务
6. 端侧拿到 SignUpReceipt，更新剩余名额和按钮状态
```

任何一步失败，整个事务回滚：名额不会少，报名记录不会多。

## 7. 部署形态

- **端侧**：HarmonyOS 26 设备 / 模拟器，Stage 模型，ArkTS。
- **云侧**：仓颉服务部署在华为云（容器 / ECS / FunctionGraph 均可），
  只暴露 HTTPS API；数据库放私网，仅允许服务访问。
- **数据库**：PostgreSQL 兼容的华为云数据库（RDS / GaussDB）。
- **配置**：数据库连接串、token 密钥、短信 / 推送凭据只存在云侧环境变量，
  不进代码库，也不下发端侧。

## 8. 第一阶段的非目标

为了避免 12 周计划失控，以下内容不在最小闭环内：

- 真实校园统一身份认证对接（先用 seed 账号模拟）；
- 支付、票务、复杂推荐；
- 多租户 / 多学校；
- 端侧离线写队列（写请求必须在线，读可以缓存）；
- 自建 IM / 复杂消息推送（先做站内消息 + 通知权限）。

这些都可以在最小闭环跑通后再加，不影响当前架构。
