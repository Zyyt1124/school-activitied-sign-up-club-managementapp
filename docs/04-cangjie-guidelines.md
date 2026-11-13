# 仓颉实现规范

## 1. 工具链

| 项 | 版本 / 路径 |
| --- | --- |
| Cangjie | 1.0.5（`cjc` / `cjpm`） |
| JDK / Node（DevEco 内置） | DevEco Studio 26 自带 |
| HarmonyOS SDK | HarmonyOS 26.0.0 / API 26 |
| 包管理 | `cjpm`；本机可用 `scripts/build.ps1` 兜底 |

```bash
# 标准构建
cd server
cjpm build

# 本机兜底（cjpm / 运行时启动崩溃时）
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

当前这台机器上 `cjc` 可以完整编译，但 `cjpm` 和生成的 exe 启动时会
`0xC0000005`。这是本机仓颉运行时的问题；代码本身已通过五个 package 的
编译验证。换机器 / 换 DevEco 工具链后可直接 `cjpm run`。

## 2. 包结构

```text
campus（根包，src/main.cj）
├── campus.domain      纯领域：不能 import repository / service / api
├── campus.repository  仓储接口 + 内存实现
├── campus.service     业务规则 + 事务编排 + 权限
└── campus.api         DTO + JSON + CampusApi 门面
```

规则：

- 依赖只能往下走：`api → service → repository → domain`；
- `domain` 里不出现 `HashMap` 以外的 IO、网络、数据库；
- `service` 只依赖接口，不 import 内存实现；
- `api` 不写业务判断，只做参数转换。

## 3. 业务错误：用 `Outcome`，不靠异常

```cangjie
public enum Outcome<T, E> {
    | Ok(T)
    | Err(E)
}
```

业务方法统一返回 `Outcome<T, BizError>`：

```cangjie
public func signUp(...): Outcome<SignUpReceipt, BizError> {
    ...
    return fail<SignUpReceipt>(conflictError("NO_SEAT", "名额已满"))
    ...
    return succeed<SignUpReceipt>(receipt)
}
```

约定：

- `BizError` 的 `code` 是端侧分支用的稳定标识，`detail` 是给人看的文案；
- 可预期的失败（名额满、重复报名、越权）用 `Err`；
- 不可预期的失败（数据库连不上、空指针）才用异常；
- 在闭包 / `match` 分支里，编译器有时推断不出 `Ok/Err` 的泛型参数，
  用 `succeed<T>` / `fail<T>` 把类型写清楚。

## 4. 状态机：封闭 enum + 穷举 match

```cangjie
public enum ActivityState {
    | Draft
    | Open
    | Closed
    | Archived
    | Disabled
}

public func canTransition(from: ActivityState, to: ActivityState): Bool {
    match ((from, to)) {
        case (Draft, Open) => true
        case (Open, Closed) => true
        case (Closed, Archived) => true
        case _ => false
    }
}
```

- 不要用字符串表示状态；
- 新增状态时，`match` 会让编译器提醒补分支；
- 数据库的 `check` 约束是第二道防线，不是替代品。

## 5. 事务：`TxRunner` 是唯一边界

```cangjie
return tx.run<Outcome<SignUpReceipt, BizError>>({ =>
    // 校验
    // 扣名额（仓储原子操作）
    // 写报名记录
    // 写消息
})
```

- repository 不自己开事务；
- 内存实现的 `TxRunner` 用 `Mutex` 串行化；
- SQL 实现里 `run` 负责 `begin / commit / rollback`；
- 事务里不要做网络请求、推送、文件 IO。

## 6. 仓储：接口在 `repository`，SQL 在适配器

```cangjie
public interface ActivityRepository {
    func tryReserveSeat(activityId: Int64): Bool
    func releaseSeat(activityId: Int64): Unit
}
```

- `tryReserveSeat` 的语义是「原子尝试」，不是「查询 + 修改」；
- SQL 实现用条件 UPDATE，以 rowcount 为准；
- 内存实现用 `Mutex` 包住整个 service 操作；
- service 只依赖接口，切换实现时零改动。

## 7. 时间：注入 `Clock`

不要直接在业务里 `DateTime.now()`。用：

```cangjie
public interface Clock {
    func nowMillis(): Int64
}
```

- 生产用 `SystemClock`；
- 测试用 `FixedClock`；
- 报名窗口、消息时间、创建时间都从 `Clock` 取，测试可复现。

## 8. 权限：集中在 `service/permissions.cj`

```cangjie
public func canManageClub(actor: Actor, clubId: Int64): Bool {
    match (actor.role) {
        case Admin => true
        case ClubLeader => match (actor.leaderClubId) {
            case Some(id) => id == clubId
            case None => false
        }
        case Student => false
    }
}
```

- 不要在每个 handler 里重复写 `if role == ...`；
- `Actor` 由鉴权层构造，端侧传来的角色不可信；
- 越权返回 `Forbidden`，不要返回 404 隐藏资源（除非产品明确要求）。

## 9. 不要为了用特性而用特性

当前**没有**使用：

- `@Derive` / 自定义宏：本机宏运行时不可用，先手写 `match`；
- 复杂泛型 / 运算符重载：可读性优先；
- 反射：业务代码不需要。

如果后面工具链稳定，可以评估：

- `@RequireRole` 宏生成权限校验；
- `@Derive[Equatable]` 简化枚举比较；
- `spawn` 处理导出、提醒等旁路任务（注意不要跨事务）。

## 10. 新增一个业务的检查清单

1. 在 `domain` 定义模型 / 状态 / 错误码；
2. 在 `repository` 加接口方法（如果需要新的原子操作）；
3. 在 `service` 写业务方法，用 `tx.run` 包住写操作；
4. 在 `api/dto.cj` 加 DTO 和 `toJson()`；
5. 在 `api/facade.cj` 加门面方法；
6. 在 `docs/03-api-contract.md` 加接口和错误码；
7. 在 `app/common/models.ets` 加对应类型；
8. 用 `scripts/build.ps1` 编译，确认五个 package 都过；
9. 补契约测试 / 手动 demo。

## 11. 代码风格

- 4 空格缩进；一行不超过 120 字符；
- 公共类型 / 函数写 `public`，其余默认私有；
- 文件名用小写 + 下划线：`signup_service.cj`；
- 注释解释「为什么」，不解释「是什么」；
- 中文注释可以，错误码 / 字段名保持英文；
- 不提交 `build/`、`*.exe`、`*.cjo`、`*.a`。
