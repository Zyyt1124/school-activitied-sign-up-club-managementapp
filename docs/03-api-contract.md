# 端云接口契约（v1）

> 这是端侧 `common/models.ets`、云侧 `server/src/api/dto.cj` 和测试用例的
> 唯一对齐依据。W2 冻结后，字段变更必须走 PR，并同步修改三处。

## 1. 通用约定

| 项 | 约定 |
| --- | --- |
| Base URL | `/v1`，生产环境必须 HTTPS |
| 编码 | UTF-8，`application/json` |
| 时间 | `Int64`，Unix 毫秒时间戳（例如 `1780000000000`） |
| ID | `Int64`，JSON number；校园规模下不会超过 JS 安全整数 |
| 字段命名 | API 用 camelCase；数据库用 snake_case，由仓储层映射 |
| 鉴权 | `Authorization: Bearer <token>` |
| 请求追踪 | `X-Request-Id`（可选，服务端没有则生成） |
| 幂等 | 写操作带 `Idempotency-Key`（建议 UUID / 随机串，长度 ≤ 96） |

### 错误响应

所有非 2xx 响应统一为：

```json
{
  "code": "NO_SEAT",
  "message": "名额已满，报名失败",
  "requestId": "req_01J..."
}
```

端侧根据 `code` 做分支，`message` 只用于展示。

### 错误码

| code | HTTP | 场景 |
| --- | --- | --- |
| `BAD_CREDENTIALS` | 401 | 学号或密码错误 |
| `UNAUTHORIZED` | 401 | token 缺失 / 失效 |
| `FORBIDDEN` | 403 | 角色或社团归属不匹配 |
| `ACTIVITY_NOT_FOUND` | 404 | 活动不存在 |
| `CLUB_NOT_FOUND` | 404 | 社团不存在 |
| `MESSAGE_NOT_FOUND` | 404 | 消息不存在 |
| `NOT_IN_SIGN_PERIOD` | 409 | 不在报名时段 / 活动未开放报名 |
| `ALREADY_SIGNED` | 409 | 已经报名，不能重复报名 |
| `NO_SEAT` | 409 | 名额已满 |
| `CANCEL_CLOSED` | 409 | 报名已截止，不能取消 |
| `NOT_SIGNED` | 409 | 尚未报名 |
| `IDEMPOTENCY_KEY_REUSED` | 409 | 幂等键被其他用户 / 活动使用 |
| `INVALID_STATE_TRANSITION` | 409 | 活动状态不允许该操作 |
| `CLUB_NOT_PENDING` | 409 | 社团不在待审核状态 |
| `INVALID_TITLE` / `INVALID_MAX_COUNT` / `INVALID_SIGN_PERIOD` / `INVALID_ACTIVITY_TIME` | 400 | 参数校验失败 |
| `INVALID_CLUB_NAME` | 400 | 社团名称为空 |

## 2. 角色与权限

| 操作 | 学生 | 社团负责人 | 学校管理员 |
| --- | --- | --- | --- |
| 浏览公开活动 / 社团 | ✅ | ✅ | ✅ |
| 报名 / 取消 | ✅ | ✅ | ✅ |
| 创建社团申请 | ✅ | ✅ | ✅ |
| 发布 / 编辑本社团活动 | ❌ | ✅ | ✅ |
| 查看本社团报名名单 | ❌ | ✅ | ✅ |
| 审核入社申请 | ❌ | ✅ | ✅ |
| 审核社团注册 | ❌ | ❌ | ✅ |
| 下架违规活动 / 社团 | ❌ | ❌ | ✅ |
| 全校统计 | ❌ | ❌ | ✅ |

云侧每次请求都重新校验，端侧隐藏按钮只是体验优化，不是安全边界。

## 3. 接口清单

### 3.1 认证

| 方法 | 路径 | 角色 | 说明 |
| --- | --- | --- | --- |
| POST | `/auth/login` | 公开 | 学号 + 密码登录 |
| POST | `/auth/logout` | 登录 | 注销当前 token |
| GET | `/me` | 登录 | 获取当前用户（W3 实现） |

**POST /auth/login**

```json
{
  "studentId": "student",
  "password": "123456"
}
```

```json
{
  "token": "demo-token-3-1",
  "user": {
    "userId": 3,
    "studentId": "student",
    "name": "朱同学",
    "role": "student",
    "college": "软件学院"
  }
}
```

### 3.2 活动

| 方法 | 路径 | 角色 | 说明 |
| --- | --- | --- | --- |
| GET | `/activities?state=open&cursor=` | 公开 | 活动列表 |
| GET | `/activities/{id}` | 公开 | 活动详情；登录时返回 `signed` |
| POST | `/activities` | 负责人 / 管理员 | 创建草稿 |
| PATCH | `/activities/{id}` | 负责人 / 管理员 | 编辑草稿或报名中活动 |
| POST | `/activities/{id}/publish` | 负责人 / 管理员 | 草稿 → 报名中 |
| POST | `/activities/{id}/close` | 负责人 / 管理员 | 报名中 → 报名结束 |
| POST | `/activities/{id}/archive` | 负责人 / 管理员 | 报名结束 → 已结束 |
| POST | `/activities/{id}/disable` | 管理员 | 下架违规活动 |

**GET /activities?state=open**

```json
{
  "items": [
    {
      "activityId": 1,
      "clubId": 1,
      "clubName": "开源技术社",
      "title": "鸿蒙原生应用开发分享会",
      "location": "图书馆报告厅",
      "state": "open",
      "remainCount": 50,
      "maxCount": 50,
      "signStart": 1780000000000,
      "signEnd": 1780600000000,
      "activityTime": 1780700000000
    }
  ],
  "nextCursor": ""
}
```

**GET /activities/{id}**

```json
{
  "activityId": 1,
  "clubId": 1,
  "clubName": "开源技术社",
  "title": "鸿蒙原生应用开发分享会",
  "description": "从 Stage 模型到端云协同……",
  "location": "图书馆报告厅",
  "state": "open",
  "remainCount": 49,
  "maxCount": 50,
  "signStart": 1780000000000,
  "signEnd": 1780600000000,
  "activityTime": 1780700000000,
  "signed": true
}
```

**POST /activities**（创建草稿）

```json
{
  "clubId": 1,
  "title": "社团例会：端云边界怎么划",
  "description": "用一个报名业务讲清楚……",
  "location": "实验楼 A305",
  "maxCount": 20,
  "signStart": 1780000000000,
  "signEnd": 1780172800000,
  "activityTime": 1780259200000
}
```

### 3.3 报名

| 方法 | 路径 | 角色 | 说明 |
| --- | --- | --- | --- |
| POST | `/activities/{id}/sign-ups` | 登录 | 报名；必须带 `Idempotency-Key` |
| DELETE | `/activities/{id}/sign-ups` | 登录 | 取消报名；建议带幂等键 |
| GET | `/activities/{id}/sign-ups` | 负责人 / 管理员 | 报名名单 |
| GET | `/activities/{id}/sign-ups/export` | 负责人 / 管理员 | 导出 Excel（W6） |
| POST | `/activities/{id}/check-ins` | 负责人 / 管理员 | 标记签到（W7） |

**POST /activities/{id}/sign-ups**

```http
POST /v1/activities/1/sign-ups
Authorization: Bearer demo-token-3-1
Idempotency-Key: 6f1c2f7e-8d0a-4a6e-9d2f-3b7c1a9e5d21
Content-Type: application/json

{}
```

成功：

```json
{
  "signId": 1,
  "activityId": 1,
  "userId": 3,
  "signTime": 1780001234567,
  "remainCount": 49
}
```

失败：

```json
{
  "code": "NO_SEAT",
  "message": "名额已满，报名失败",
  "requestId": "req_01J..."
}
```

**DELETE /activities/{id}/sign-ups**

成功返回同样的 `SignUpReceipt`，`remainCount` 是归还后的数量。
重复取消返回成功（幂等），不会重复归还名额。

### 3.4 社团

| 方法 | 路径 | 角色 | 说明 |
| --- | --- | --- | --- |
| GET | `/clubs` | 公开 | 正常状态社团列表 |
| GET | `/clubs/{id}` | 公开 | 社团主页 |
| POST | `/clubs` | 登录 | 创建社团申请（默认待审核） |
| POST | `/clubs/{id}/approve` | 管理员 | 审核通过 |
| POST | `/clubs/{id}/disable` | 管理员 | 禁用社团 |
| POST | `/clubs/{id}/join-requests` | 学生 | 提交入社申请 |
| GET | `/clubs/{id}/join-requests` | 负责人 / 管理员 | 查看入社申请 |
| POST | `/clubs/{id}/join-requests/{requestId}/approve` | 负责人 / 管理员 | 通过入社申请 |
| DELETE | `/clubs/{id}/members/{userId}` | 负责人 / 管理员 | 移出成员 |

> 入社申请 / 成员管理的数据表和接口在 W4 补齐；当前云侧已有社团创建与审核。

### 3.5 消息

| 方法 | 路径 | 角色 | 说明 |
| --- | --- | --- | --- |
| GET | `/messages` | 登录 | 我的消息，未读优先 |
| POST | `/messages/{id}/read` | 登录 | 标记已读 |

```json
{
  "items": [
    {
      "messageId": 1,
      "title": "报名成功",
      "content": "活动【鸿蒙原生应用开发分享会】报名成功，请按时参加。",
      "messageType": "signup",
      "read": false,
      "createdAt": 1780001234567
    }
  ]
}
```

### 3.6 管理员

| 方法 | 路径 | 角色 | 说明 |
| --- | --- | --- | --- |
| GET | `/admin/clubs/pending` | 管理员 | 待审核社团 |
| GET | `/admin/stats` | 管理员 | 全校活动 / 参与人数 |
| GET | `/admin/audit-logs` | 管理员 | 审计日志 |

## 4. 分页

列表接口统一返回：

```json
{
  "items": [],
  "nextCursor": ""
}
```

- `nextCursor` 为空表示没有下一页；
- 请求带 `?cursor=<nextCursor>&limit=20`；
- 游标对端侧不透明，不要解析；
- 第一期内部可以用 offset 实现，契约保持游标语义。

## 5. 契约冻结与变更

- **W2 冻结**：字段、错误码、角色矩阵定稿。
- 之后只允许**加法**：新增可选字段、新增错误码、新增接口。
- 删除 / 重命名字段、改变语义 → 升 `/v2`，并保留 `/v1` 至少一个版本。
- 每次变更同步：
  1. 本文件；
  2. `app/entry/src/main/ets/common/models.ets`；
  3. `server/src/api/dto.cj`；
  4. 对应的契约测试。
