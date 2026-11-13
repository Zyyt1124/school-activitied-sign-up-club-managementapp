# ArkTS 端侧（HarmonyOS 26 / Stage 模型）

## 打开与运行

1. 用 DevEco Studio 26 打开本目录（`app/`）。
2. `File -> Project Structure -> SDK` 选择 HarmonyOS 26.0.0（API 26）。
3. 在项目根目录建 `local.properties`：

   ```properties
   sdk.dir=D:\\DevEco Studio\\sdk
   ```

   这个文件是本机路径，已在 `.gitignore` 中忽略，不要提交。
4. 连接模拟器或真机，运行 `entry`。

命令行构建（在没有登录签名时也能产出 unsigned HAP）：

```powershell
# 在 app/ 目录
$env:PATH = "D:\DevEco Studio\jbr\bin;D:\DevEco Studio\tools\node;" + $env:PATH
$env:DEVECO_SDK_HOME = "D:\DevEco Studio\sdk"
& "D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p product=default -p module=entry@default `
  assembleHap --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`。

## 页面与边界

```text
pages/
├── Index.ets            # 启动：恢复会话，决定去登录还是主页
├── Login.ets            # 学号 + 密码，调用 /auth/login
├── Main.ets             # Tabs：活动 / 社团 / 我的
└── ActivityDetail.ets   # 详情 + 报名 / 取消（带幂等键）

common/
├── api/ApiClient.ets    # 唯一允许发网络请求的类
├── api/ApiConfig.ets    # baseUrl，模拟器默认 10.0.2.2
├── auth/SessionStore.ets# preferences 里的 token / user
├── models.ets           # 与 docs/03-api-contract.md 对齐的 DTO
└── constants/AppTheme.ets
```

端侧规则：

- 不写 SQL，不持有数据库地址 / 账号 / 密码。
- 所有数据通过 `ApiClient` 走 HTTPS/JSON。
- 写操作（报名、取消）带 `Idempotency-Key`，网络重试不会重复提交。
- `SessionStore` 目前用 preferences；上架前把 token 迁到 HUKS，或至少缩短有效期。
- 读缓存可以离线，写请求必须在线。

## 当前进度

- 登录、活动列表、活动详情、报名 / 取消、我的页面骨架可编译。
- 社团页、消息中心、负责人后台、管理员后台是占位，按 12 周计划在 W4–W9 补齐。
- 目前只申请了 `ohos.permission.INTERNET`；后续加通知 / 扫码时再逐项申请并更新隐私清单。

## 接口联调

1. 先启动仓颉服务（或按 `docs/03-api-contract.md` 起一个 mock）。
2. 修改 `common/api/ApiConfig.ets` 的 `baseUrl`：
   - 模拟器：`http://10.0.2.2:8080/v1`
   - 真机：`http://<电脑局域网 IP>:8080/v1`
   - 生产：必须是 `https://`
3. 用 seed 账号登录：`student / 123456`、`leader / 123456`、`admin / 123456`。

## 下一步

- W3：把 `Main.ets` 的静态占位换成真实接口，补齐加载 / 空态 / 错误态。
- W4：社团列表、社团详情、入社申请。
- W5–W6：负责人发布表单、报名名单、导出入口。
- W9：管理员后台。
