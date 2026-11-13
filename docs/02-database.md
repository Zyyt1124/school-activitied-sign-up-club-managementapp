# 数据库设计与事务边界

> 目标数据库：PostgreSQL 14+ / 华为云 GaussDB（PostgreSQL 兼容）。
> DDL 见 [`server/db/schema.sql`](../server/db/schema.sql)，
> 核心 SQL 见 [`server/db/queries.sql`](../server/db/queries.sql)。

## 1. 表与职责

| 表 | 职责 | 关键约束 |
| --- | --- | --- |
| `app_user` | 用户、角色、学号、学院、手机号、密码哈希 | `student_id` 唯一；`role` 枚举校验 |
| `club` | 社团资料、负责人、审核状态 | `leader_id` 外键；`status ∈ pending/active/disabled` |
| `activity` | 活动信息、名额、报名窗口、状态机 | `remain_count ∈ [0, max_count]`；`sign_start < sign_end ≤ activity_time` |
| `activity_sign` | 报名记录、取消 / 签到状态、幂等键 | 未取消记录 `(activity_id, user_id)` 唯一；`idempotency_key` 唯一 |
| `message` | 站内消息 | 按用户 + 已读 + 时间建索引 |
| `audit_log` | 管理员审核 / 下架 / 导出等敏感操作 | 只追加，不修改 |

## 2. 为什么这样设计

### 2.1 剩余名额是「热字段」，必须原子更新

不要在业务代码里：

```text
select remain_count;          -- 读到 1
if (remain_count > 0) {       -- 两个人同时判断为真
    update remain_count = 0;  -- 两个人都报名成功 -> 超报
}
```

正确做法是条件 UPDATE，以 rowcount 为准：

```sql
update activity
set remain_count = remain_count - 1,
    version = version + 1
where activity_id = $1
  and status = 'open'
  and remain_count > 0;
-- rowcount = 1：占到名额
-- rowcount = 0：名额满 / 活动不在报名中
```

### 2.2 防重复报名用 partial unique index

```sql
create unique index uk_sign_active
    on activity_sign(activity_id, user_id)
    where is_cancel = false;
```

- 未取消时，同一用户同一活动只能有一条记录；
- 取消后可以重新报名；
- 并发重复提交时，数据库直接拒绝第二条，比「先查再插」可靠。

### 2.3 幂等键全局唯一

```sql
create unique index uk_sign_idempotency
    on activity_sign(idempotency_key)
    where idempotency_key is not null;
```

端侧网络超时重试时复用同一个键。服务端先查键：

- 命中且用户 / 活动一致 → 返回第一次的报名结果；
- 命中但上下文不一致 → `IDEMPOTENCY_KEY_REUSED`；
- 未命中 → 正常走扣名额 + 写记录。

### 2.4 取消与报名使用同一把锁顺序

报名：先更新 `activity` 行（拿到行锁），再 `insert activity_sign`。

取消：先 `select activity ... for update`，再 `select activity_sign ... for update`，
最后更新两张表。两边都是「活动行 → 报名行」，不会互相死锁。

### 2.5 取消后名额归还也要带条件

```sql
update activity
set remain_count = remain_count + 1
where activity_id = $1
  and remain_count < max_count;
```

避免重复取消 / 异常重试把名额加到超过上限。

## 3. 状态机与数据库约束

活动状态：

```text
draft ──▶ open ──▶ closed ──▶ archived
  │        │          │
  └────────┴──────────┴──▶ disabled（管理员下架）
```

- 数据库用 `check` 约束保证状态值合法；
- 业务层用 `canTransition(from, to)` 保证流转合法；
- 两者不重复：数据库防脏数据，业务层防越权操作。

## 4. 索引与查询

已经建立的索引：

- `activity(status, sign_start)`：首页只查 `open` 且按报名时间排序；
- `activity(club_id, status)`：社团主页查本社团活动；
- `activity_sign(activity_id, is_cancel)`：负责人看名单；
- `activity_sign(user_id, sign_time desc)`：我的报名；
- `message(user_id, is_read, created_at desc)`：消息中心未读优先；
- `audit_log(created_at desc)`：管理员审计。

导出名单时按 `sign_time` 升序；如果数据量大，再考虑按活动分区或异步导出，
当前校园规模不需要。

## 5. 事务边界清单

| 业务操作 | 事务内包含 |
| --- | --- |
| 报名 | 查幂等键（可前置）→ 扣名额 → 写报名记录 → 写消息 |
| 取消 | 锁活动 → 锁报名 → 标记取消 → 归还名额 → 写消息 |
| 发布活动 | 校验权限 / 参数 → 改状态 → 写审计（可选） |
| 审核社团 | 改社团状态 → 升级负责人角色 → 写审计 |
| 下架活动 | 改状态 → 写审计 → 给报名用户写消息 |

注意：**消息写入在事务内，消息推送在事务外**。推送失败不能回滚报名；
应用内消息中心是兜底，推送是增强。

## 6. 迁移、备份与安全

### 迁移

- `server/db/schema.sql` 是 v1 基线；
- 后续每次变更新增 `server/db/migrations/00x_xxx.sql`，不修改已执行的迁移；
- 迁移脚本必须可重复执行（`if not exists` / 幂等 DDL），并先在测试库跑一遍。

### 备份

- 云数据库开启自动备份 + 时间点恢复（PITR）；
- 每次上线前手动做一次快照；
- 报名高峰期（开学季）把备份保留时间调长。

### 安全

- 数据库只在私网，安全组只放行云侧服务；
- 连接串放环境变量 / 密钥管理服务，不进 Git；
- 应用账号最小权限：`select/insert/update/delete`，不给 DDL；
- 所有 SQL 参数化，禁止字符串拼接；
- 日志不打印手机号、学号、token 明文；
- 导出名单属于敏感操作，写审计日志并限制角色。

## 7. 从内存实现切到 SQL 的步骤

当前 `server/src/repository/memory.cj` 是内存实现，用于演示和契约测试。
接真实数据库时：

1. 新建 `server/src/repository/sql/`，实现五个 Repository 接口；
2. 实现 `TxRunner`：`begin → body → commit / rollback`；
3. `tryReserveSeat` 用上面的条件 UPDATE；
4. `SignRepository.create` 捕获唯一索引冲突，映射为 `ALREADY_SIGNED` /
   `IDEMPOTENCY_KEY_REUSED`；
5. 在 `main.cj` / 部署配置里切换仓储实现；
6. service 层零改动。

这一步是 W3–W4 的主要任务，也是「数据库交互实现层」的验收点。
