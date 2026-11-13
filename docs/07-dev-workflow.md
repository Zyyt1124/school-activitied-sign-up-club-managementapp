# 团队协作与 Git 工作流

## 1. 分支模型

```text
upstream/main（组长仓库，受保护）
        ▲
        │ PR（由组长合并）
        │
origin/Zyy（你的 fork，个人集成分支）
        ▲
        │ merge --no-ff / PR
        │
feat/xxx、fix/xxx（短期分支，1–3 天）
```

规则：

- **不要在 `main` 上直接提交。** `main` 只接受 PR。
- 个人集成分支用 `Zyy`（当前分支）；每个功能从 `Zyy` 切短期分支。
- 分支命名：
  - `feat/signup-idempotency`
  - `fix/cancel-seat-leak`
  - `docs/api-contract-v1`
  - `chore/ci-build`
- 合并前先 `git fetch` + rebase / merge 最新 `Zyy`，解决冲突后再提 PR。
- 不要 force push 共享分支（`main`、`Zyy`）。
- 一个 PR 只做一件事，控制在 400 行以内；大功能拆成多个 PR。

### 日常命令

```bash
# 开始一天的工作
git switch Zyy
git pull origin Zyy

# 开功能分支
git switch -c feat/signup-idempotency

# 提交
git add <files>
git commit -m "feat(signup): add idempotency key to sign-up"

# 推送
git push -u origin feat/signup-idempotency

# 合并回个人分支（本地）
git switch Zyy
git merge --no-ff feat/signup-idempotency
git push origin Zyy
```

如果 fork 需要同步组长仓库：

```bash
git remote add upstream git@github.com:<组长账号>/<仓库名>.git
git fetch upstream
git switch Zyy
git rebase upstream/main   # 或 merge，团队统一一种
```

## 2. 提交信息

格式：

```text
<type>(<scope>): <subject>

<body 可选>
```

`type`：

- `feat` 新功能
- `fix` 修 bug
- `docs` 文档
- `test` 测试
- `refactor` 重构（不改行为）
- `chore` 构建 / 依赖 / 配置
- `style` 格式（不改逻辑）

示例：

```text
feat(signup): reserve seat with conditional update

- repository.tryReserveSeat returns false when remain_count = 0
- service maps it to NO_SEAT
- add idempotency-key lookup before reserving
```

要求：

- 主题行不超过 72 字符；
- 一次提交只做一件事；
- 不提交生成物（`build/`、`*.hap`、`*.exe`、`*.cjo`、`*.a`）；
- 不提交密钥、`local.properties`、签名文件。

## 3. PR 检查清单

提 PR 前逐项确认：

- [ ] 从最新 `Zyy` 切出，已解决冲突
- [ ] `scripts/build.ps1` 通过（仓颉五个 package）
- [ ] `hvigorw assembleHap` 通过（ArkTS 编译）
- [ ] 新增 / 修改的接口已同步 `docs/03-api-contract.md`
- [ ] 端侧 `models.ets` 与云侧 `dto.cj` 字段一致
- [ ] 正常 / 空 / 错误 / 越权四种情况都考虑
- [ ] 没有把 token、数据库密码、手机号写进日志
- [ ] 没有提交 `build/`、`oh_modules/`、`local.properties`
- [ ] PR 描述写清楚：改了什么、为什么、怎么验证、截图 / 录屏

## 4. 代码评审重点

评审不是找格式问题（交给格式化 / linter），优先看：

1. **边界**：端侧有没有偷偷访问数据库 / 拼 SQL？
2. **权限**：云侧有没有重新校验角色和社团归属？
3. **事务**：扣名额、写记录、写消息是否在同一个 `tx.run` 里？
4. **幂等**：重试会不会重复扣名额 / 重复报名？
5. **状态机**：非法流转有没有被 `canTransition` 拦住？
6. **错误码**：端侧能不能根据 `code` 做分支？
7. **敏感信息**：日志、响应、截图里有没有学号 / 手机号 / token？
8. **契约**：字段命名、时间单位、分页语义是否一致？

## 5. 本地构建

### 仓颉

```bash
cd server
cjpm build
# 或
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

### HarmonyOS

```powershell
cd app
$env:PATH = "D:\DevEco Studio\jbr\bin;D:\DevEco Studio\tools\node;" + $env:PATH
$env:DEVECO_SDK_HOME = "D:\DevEco Studio\sdk"
& "D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p product=default -p module=entry@default `
  assembleHap --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`。

### 提交前自检

```bash
git status
git diff --stat
git diff --check          # 空白 / 冲突标记
```

## 6. 环境与密钥

- `app/local.properties` 是本机 SDK 路径，**已 gitignore**。
- 数据库连接串、token 密钥、推送凭据只放云侧环境变量 / 密钥管理服务。
- 签名文件（`.p12`、`.cer`、`.p7b`）和密码不进仓库。
- 如果误提交了密钥：
  1. 立即在云侧轮换；
  2. 从 Git 历史移除（`git filter-repo`）；
  3. 通知团队。

## 7. 目录归属（建议）

| 目录 | 主责 | 互审 |
| --- | --- | --- |
| `app/entry/src/main/ets/pages/` | A | B / C |
| `app/entry/src/main/ets/common/api/` | A + C | B |
| `server/src/domain/` | B | C |
| `server/src/service/` | B | A / C |
| `server/src/repository/` | C | B |
| `server/db/` | C | B |
| `docs/` | 全员 | 全员 |

## 8. 文档同步

以下文件是「同一份契约的不同投影」，改一处必须同步：

```text
docs/03-api-contract.md
app/entry/src/main/ets/common/models.ets
server/src/api/dto.cj
server/src/service/*.cj
```

PR 里如果只改了其中一处，评审直接打回。
