# LoveSpace 香港节点部署与双机验收

## 发布顺序

1. 新域名解析到阿里云香港 ECS，只开放 22（限管理 IP）、80、443；MySQL 不映射公网端口。
2. 在私有 OSS 桶创建同地域 RAM 最小权限账号。Bucket CORS 只允许 `https://你的域名`，方法仅 `GET`、`HEAD`，不允许 `*` 来源。
3. 复制 `deploy/.env.production.example` 为 `deploy/.env.production` 并填入真实环境变量；文件不得提交 Git。
4. 生成 VAPID 密钥，把公钥同时注入 Web 构建，把私钥只放服务端环境变量。
5. 构建 Web 时使用：

   ```powershell
   flutter build web --release --pwa-strategy=none `
     --dart-define=API_BASE_URL=https://你的域名 `
     --dart-define=VAPID_PUBLIC_KEY=你的公钥
   ```

   `web/flutter_bootstrap.js` 已禁止 Flutter 默认 Service Worker；根作用域只由 `push-sw.js` 管理。
6. 在仓库外生成 release keystore，按 `app/android/key.properties.example` 配置，再运行：

   ```powershell
   ./scripts/build-android-release.ps1 `
     -ApiBaseUrl https://你的域名 `
     -GetuiAppId 你的个推AppID `
     -Version 1.0.0 -BuildNumber 1
   ```

   脚本会产出签名 APK、SHA-256 与静态更新清单；若 Web 已先构建，也会同步到 `app/build/web/releases/`，默认下载地址为同域 `/releases/lovespace-版本.apk`。
7. `docker compose -f deploy/compose.prod.yml --env-file deploy/.env.production up -d --build`。Caddy 自动签发 HTTPS，并把 PWA 与 `/api` 放在同一域名。

## 备份

每天调用 `deploy/backup.sh`。脚本使用 AES-256/PBKDF2 加密后上传 OSS；周日额外写入 weekly 前缀。在 OSS 生命周期中配置：

- `backups/daily/`：7 天后过期；
- `backups/weekly/`：28 天后过期（保留 4 个周备份）。

每月至少恢复一次到临时 MySQL，确认备份密码与文件可用。

## 双机验收

- 一加 12 / ColorOS 16.5：安装签名 APK，允许通知、后台运行并关闭电池优化；分别验证前台、后台、锁屏、划掉应用和重启。用户主动“强制停止”不属于必达范围。
- iPhone iOS 18.4+：Safari 打开 HTTPS 域名，添加到主屏幕，从主屏幕启动后点击“开启通知”；验证登录续期、相册选图、锁屏通知、角标与深链。
- 双向各走一次：回答每日问答、发布点滴、公开心情、上传照片；对端应实时刷新并收到通知。私密心情不得通知对方，问答通知不得包含答案。
- 双向验证共同任务：分别创建“我 / TA / 双方”任务，确认只有被指派方可以完成，奖励只发放一次且通知深链打开对应任务。
- 点菜与积分：一端下单后另一端收到通知并可查看订单；连续重试不得生成重复订单。双方各完成一次记积分、任务奖励和兑换，核对余额与流水一致。
- 愿望与胶囊：双方各创建、推进并完成一个愿望；创建胶囊后对端通知不得包含正文，开启日前两端都只能看到标题和日期，修改系统时间不得绕过服务端锁定。
- 健康与月报：两端各设置隐私级别并记录一天数据，确认对方只看到允许字段；完成挑战后的奖励与推送只产生一次，月报月份切换和汇总数字正常。
- 断网填写点滴与问答，关闭再打开后确认文字草稿仍在；恢复网络重试后数据库不得出现重复点滴、相册或照片。
