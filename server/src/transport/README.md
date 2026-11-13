# transport 层（待实现）

这一层只做四件事，不写业务规则：

1. 解析 HTTP 请求（method / path / query / header / JSON body）；
2. 从 `Authorization: Bearer` 取 token，调用 `CampusApi.authenticate` 得到 `Actor`；
3. 调用 `CampusApi` 的对应方法；
4. 把 DTO / `BizError` 写成 HTTP 响应。

## 路由草案

| 方法 | 路径 | CampusApi 方法 |
| --- | --- | --- |
| POST | `/v1/auth/login` | `login` |
| POST | `/v1/auth/logout` | `logout` |
| GET | `/v1/activities` | `listActivities` |
| GET | `/v1/activities/{id}` | `activityDetail` |
| POST | `/v1/activities` | `createActivityDraft` |
| POST | `/v1/activities/{id}/publish` | `publishActivity` |
| POST | `/v1/activities/{id}/sign-ups` | `signUp` |
| DELETE | `/v1/activities/{id}/sign-ups` | `cancel` |
| GET | `/v1/activities/{id}/sign-ups` | `listSignUps` |
| GET | `/v1/clubs` | `listClubs` |
| POST | `/v1/clubs` | `createClub` |
| POST | `/v1/clubs/{id}/approve` | `approveClub` |
| GET | `/v1/messages` | `listMessages` |
| POST | `/v1/messages/{id}/read` | `markRead` |

## 错误映射

```text
BizError.status  -> HTTP status
BizError.code    -> 响应 body.code
BizError.detail  -> 响应 body.message
```

未知异常统一 `500` + `INTERNAL_ERROR`，不把堆栈返回端侧。

## 必须遵守

- 所有写接口必须校验 token；
- `Idempotency-Key` 原样传给 service；
- JSON 反序列化后做字段类型 / 长度校验；
- 不在 transport 层判断「是不是负责人」——那是 service 的事；
- 不在这里碰 SQL。
