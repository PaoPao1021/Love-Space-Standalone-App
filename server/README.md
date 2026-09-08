# LoveSpace Java 后端

Spring Boot 3.5 / Java 21 后端，使用 MySQL 8.4、Flyway、JWT 与 S3 兼容私有对象存储。它同时服务 Flutter Android、Flutter Web/PWA，并在迁移期间保留原小程序调用契约。

## 已实现

- `/api/v1/functions/{name}`：现有云函数 action 契约的兼容入口。
- 账号密码登录、当前用户、single-flight 客户端刷新令牌轮换、单设备退出、全部设备退出和修改密码后撤销全部会话。
- 业务数据按 `couple_id` 与成员身份隔离。
- 私有对象上传、短期签名读取和对象引用解析。
- Android 个推 / Web Push 订阅登记，以及带租约、指数退避和失效订阅停用的持久化通知 outbox worker。
- 共同任务、点菜订单与积分兑换兼容接口；任务和菜品创建、点菜下单及积分操作使用幂等请求标识。
- 愿望、时光胶囊、健康记录与双人月报接口；愿望和胶囊创建使用幂等请求标识，锁定胶囊不会向客户端泄露正文。
- 15 个原业务集合对应的 Flyway 表结构与后续账号、会话、推送迁移。

通知覆盖每日问答完成、点滴发布、双方可见心情、照片上传、纪念日提前三天与当天，以及任务指派/完成、点菜订单、积分变化、愿望进展、胶囊创建和健康挑战完成。问答通知不包含答案正文；胶囊通知不包含正文；私密心情不通知对方。

## 本地依赖

```powershell
docker compose -f server/compose.yml up -d --wait
server/mvnw.cmd -f server/pom.xml spring-boot:run
```

默认端口：

- API：`127.0.0.1:8080`
- MySQL：`127.0.0.1:3306`
- S3Mock：`127.0.0.1:9090`

Compose 只用于本地 MySQL 与 S3Mock，不含后端、TLS、备份或高可用，不能作为生产部署配置。

## 初始化两名账号

服务器不提供公开注册或管理接口。首次部署时，通过一次性启动变量创建固定的两名账号和情侣关系：

```text
LOVESPACE_BOOTSTRAP_ENABLED=true
LOVESPACE_BOOTSTRAP_USER_A=partner.a
LOVESPACE_BOOTSTRAP_PASSWORD_A=至少12位强密码
LOVESPACE_BOOTSTRAP_NICKNAME_A=昵称A
LOVESPACE_BOOTSTRAP_USER_B=partner.b
LOVESPACE_BOOTSTRAP_PASSWORD_B=至少12位强密码
LOVESPACE_BOOTSTRAP_NICKNAME_B=昵称B
LOVESPACE_BOOTSTRAP_START_DATE=2024-01-01
```

用 `--spring.main.web-application-type=none` 启动一次。初始化在单个事务中执行，成功后进程自动退出；如用户名已存在则拒绝覆盖。完成后立即删除密码变量并将开关恢复为 `false`。

## 认证接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/v1/auth/login` | 用户名密码登录 |
| POST | `/api/v1/auth/refresh` | 一次性刷新令牌轮换 |
| GET | `/api/v1/auth/me` | 读取当前用户 |
| POST | `/api/v1/auth/logout` | 撤销当前刷新会话 |
| POST | `/api/v1/auth/logout-all` | 增加认证版本并撤销该用户全部会话 |
| POST | `/api/v1/auth/change-password` | 验证旧密码、修改密码并撤销全部会话 |

Android 登录传 `clientType=android`，刷新令牌返回在 JSON 中；Web 传 `clientType=web`，刷新令牌只写入 HttpOnly Cookie，不出现在响应体。

## 推送订阅接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| PUT | `/api/v1/push/subscriptions/{deviceId}` | 登记或更新 Getui/Web Push 订阅 |
| DELETE | `/api/v1/push/subscriptions/{deviceId}` | 停用当前用户的设备订阅 |

业务处理器只写 `notification_outbox`，不在事务内调用外部通知平台；后台 worker 租约领取后向个推 REST V2 或标准 Web Push 投递。每个账号每个平台只保留一个活动订阅。

## 关键配置

完整样例见 `.env.example`。

| 变量 | 用途 |
| --- | --- |
| `SPRING_PROFILES_ACTIVE` | 本地 `dev`，生产必须为 `prod` |
| `DB_URL` / `DB_USERNAME` / `DB_PASSWORD` | MySQL 连接 |
| `JWT_SECRET` | JWT HMAC 密钥，生产至少 32 字节随机值 |
| `ACCESS_TOKEN_TTL` / `REFRESH_TOKEN_TTL` | 默认 `15m` / `30d` |
| `CORS_ALLOWED_ORIGIN_PATTERNS` | 仅跨域部署需要；生产应填写精确 HTTPS 来源 |
| `S3_INTERNAL_ENDPOINT` | 后端访问 OSS/S3 的地址 |
| `S3_PUBLIC_ENDPOINT` | 签名下载 URL 使用的公开 HTTPS 地址 |
| `S3_REGION` / `S3_BUCKET` | 区域和私有桶 |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | 仅后端持有的存储凭据 |
| `S3_PATH_STYLE_ACCESS_ENABLED` | 本地 S3Mock 为 `true`，阿里云 OSS 为 `false` |
| `S3_CHUNKED_ENCODING_ENABLED` | 本地为 `true`，阿里云 OSS 为 `false` |
| `GETUI_APP_ID` / `GETUI_APP_KEY` / `GETUI_MASTER_SECRET` | 个推 REST V2 凭据，仅服务端持有 |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` / `VAPID_SUBJECT` | Web Push VAPID 配置；公钥另在 Web 构建时注入 |

开发配置允许 `localhost` 与 `127.0.0.1` 的任意端口，并使用非 Secure 的 Lax 刷新 Cookie。生产 Profile 强制 `Secure + SameSite=Strict`，推荐 Web 与 API 同域；若确需跨域，必须把 CORS 设置为精确来源并全程使用 HTTPS。

## 测试

```powershell
server/mvnw.cmd -f server/pom.xml test
```

Docker 可用时，Testcontainers 会验证 MySQL 8.4 和全部 Flyway 迁移；Docker 不可用时只跳过该集成测试。上线前必须在可用的 MySQL 8.4 环境再跑一次完整验证。

## 阿里云 OSS

使用 OSS 的 S3 兼容入口，配置实际地域 endpoint、region、bucket 与 RAM 最小权限凭据。保持桶私有、虚拟主机寻址开启、chunked encoding 关闭。`S3_PUBLIC_ENDPOINT` 必须是最终设备可访问的 HTTPS 地址，不能写容器内部主机名。
