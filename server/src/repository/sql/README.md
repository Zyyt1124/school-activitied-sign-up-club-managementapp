# SQL 适配器（待实现）

目标：在不改 `service` 的前提下，把 `memory.cj` 换成真实数据库。

## 要实现的接口

- `UserRepository`
- `ClubRepository`
- `ActivityRepository`
- `SignRepository`
- `MessageRepository`
- `TxRunner`

## 事务

```text
TxRunner.run(body):
  begin
  try:
    result = body()
    commit
    return result
  catch:
    rollback
    throw
```

业务错误 `Outcome.Err` 不是异常，但是否回滚由调用方决定：
报名 / 取消里的 `Err` 都应该回滚，所以 service 在返回 `Err` 前不要做已提交的写操作。

## 关键 SQL

见 [`server/db/queries.sql`](../../../db/queries.sql)：

- `tryReserveSeat`：条件 UPDATE，rowcount 为准；
- `releaseSeat`：`remain_count < max_count` 条件；
- `create sign`：捕获 `uk_sign_active` / `uk_sign_idempotency` 冲突；
- 取消：先锁活动行，再锁报名行。

## 驱动

仓颉标准库提供 `std.database.sql`（`Connection` / `Statement` / `Transaction`）。
先用它接 PostgreSQL / GaussDB；如果驱动能力不足，再评估 C FFI 接 libpq。

## 测试

至少覆盖：

1. 50 并发抢 10 个名额，成功 10 条；
2. 同一幂等键重试，报名记录只有 1 条；
3. 取消后名额 +1，重复取消不重复加；
4. 越权查询名单返回 `FORBIDDEN`；
5. 事务中途失败，名额和报名记录都回滚。
