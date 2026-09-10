# LoveSpace Flutter 客户端

同一套 Flutter 代码构建 Android APK 与 iPhone 可添加到主屏幕的 Web App。当前已包含首页、每日问答、点滴、心情、通知中心、个人中心、相册、纪念日、共同任务、点菜、甜蜜积分、愿望、时光胶囊、默契测试、感谢墙、回忆时间轴、健康记录、双人挑战、周报与月报。底部四项为「首页、相册、点滴、我的」，支持点击与左右滑动切换并保留页面状态；生活工具可从首页快捷入口及「我的」进入。部分创建型请求使用客户端请求 ID 防止重试重复入库。核心内容会缓存最近一页并保留文字草稿，不持久化待上传图片。

愿望支持想做、进行中、已实现三段状态；时光胶囊在约定日期前只返回标题与日期，不返回正文和照片。菜单支持图片、分类、上下架、规格与加价选择。健康页支持目标资料、每日体重、饮食参考和挑战，只共享服务端隐私规则允许的数据；周报与月报分别汇总健康节奏和双方可见的心情、问答、点滴与积分。

## 本地运行

先启动 `server/` 中的 MySQL、对象存储和 Spring Boot 后端。

Android 模拟器默认访问 `http://10.0.2.2:8080`：

```powershell
flutter run -d android
```

Web 开发服务器需显式指定后端地址：

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

本地后端默认允许 `localhost` 与 `127.0.0.1` 的任意端口，并使用非 Secure 的 Lax 刷新 Cookie。生产 Profile 会恢复 `Secure + SameSite=Strict`；生产部署推荐让 Web App 与 `/api` 使用同一 HTTPS 域名。

真机连接局域网后端时，使用电脑的局域网地址覆盖 API：

```powershell
flutter run -d android --dart-define=API_BASE_URL=http://192.168.x.x:8080
```

## 检查与构建

```powershell
flutter analyze
flutter test
flutter build web --release --pwa-strategy=none `
  --dart-define=API_BASE_URL=https://example.com `
  --dart-define=VAPID_PUBLIC_KEY=你的VAPID公钥

flutter build apk --release `
  -PGETUI_APPID=你的个推AppID `
  --dart-define=API_BASE_URL=https://example.com
```

Web 使用自定义根作用域 `push-sw.js`；`flutter_bootstrap.js` 不注册 Flutter 默认 PWA worker。iPhone 需先用 Safari 添加到主屏幕，再由用户点击“开启通知”。Web 服务器必须将未知前端路径回退到 `index.html`，并将 `/api` 反向代理到 Spring Boot。

Android 保留包名 `com.lovespace.lovespace_app`。正式构建前把仓库外 keystore 信息写入忽略提交的 `android/key.properties`（样例见 `android/key.properties.example`）；建议运行 `../scripts/build-android-release.ps1` 同时生成签名 APK、SHA-256 和静态更新清单。个推只在用户明确同意后初始化；一加/ColorOS 仍需允许通知、后台运行并关闭电池优化，用户强制停止应用后不承诺系统推送到达。
