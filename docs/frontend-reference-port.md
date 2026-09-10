# LoveSpace 前端移植记录

参考源码：本地 `../LoveSpace`，远程 `PaoPao1021/LoveSpace`，提交 `e459907`。
实现位置：`app/lib`，保留 Flutter / Android / Web 和独立版 API。

## 视觉与导航

- 采用小程序的奶油色 `#F8F5F3`、爱心色 `#E85D75`、文字色 `#2D2729`、白色卡片和圆角层级。
- 底部导航对应原版四项：首页、相册、点滴、我的。
- 首页按参考顺序组织双人资料、相恋天数、问答、心情、纪念日、健康、恋爱能量、回忆和六个快捷入口。
- 页面展示继续读取独立版服务端。首页的日期与双方资料来自 `couple.getInfo`，恋爱能量沿用参考的积分换算，健康来自 `fitness.dashboard`。
- 采用参考的固定浅色外观；系统深色模式不会改变奶油色画布。

## 页面对应

| 小程序页面 | Flutter 对应 |
| --- | --- |
| index | `/home` |
| login | `/login` 账号登录，`/connect` 创建或加入双人空间 |
| album / album-detail | `/album`、`/album/:albumId`；上传支持选择相册后直接打开图片选择器 |
| moments / moment-edit | `/moments` 与现有编辑表单；`?create=1` 直接新建 |
| anniversary / anniversary-detail | `/anniversaries` 列表、详情及编辑表单 |
| mood / mood-calendar | `/mood` 中的心情、对方心情和月份日历 |
| daily-question / quiz / thanks | `/daily-question`、`/quiz`、`/thanks` |
| timeline / capsule | `/timeline`、`/capsules` |
| tasks / wishes | `/tasks`、`/wishes` |
| points / points-records | `/points` 及积分明细流程 |
| menu / dish-detail / menu-order / order-history | `/menu` 及菜品详情、选餐和订单流程 |
| fitness / fitness-report / monthly-report | `/fitness`、`/fitness-report`、`/monthly-report` |
| profile / settings | `/profile`、`/settings` |

## 平台适配

小程序的微信登录由独立版账号密码替代，登录后未绑定的账号进入创建／加入空间页。上传、日历选择和部分详情编辑使用 Flutter 原生控件／底部表单，不模拟微信系统胶囊或微信权限弹窗。

设置页支持昵称、关系信息、邀请码复制、隐私说明、自定义背景和解除绑定。背景保存在当前设备的账号缓存，切换账号会清除当前显示并加载对应账号的背景；不上传到微信云存储。服务端没有返回的健康隐私数据不使用虚构值补齐。

跨 Flutter 与微信原生渲染的字体、emoji、平台控件存在差别；页面功能对应不等于逐像素截图相同。

## 本地运行

本机已安装 Flutter 3.47.3 / Dart 3.13.3。安装依赖与检查：

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

真实数据运行时，通过 `--dart-define=API_BASE_URL=...` 指向已配置的独立版服务端。

布局预览可在仓库根目录运行：

```sh
node scripts/preview-ui.mjs
```

打开 `http://127.0.0.1:4175`。这是本机演示接口，使用虚构账号与记录，仅用于展示构建后的界面，不代表正式数据库、上传、推送或所有写入流程的联调结果。页面交互测试使用 `app/test` 内的独立假接口。

README 的旧截图有明确的旧源码基线；查看当前效果应使用重新构建的本地预览。

## 验证记录

- `flutter analyze --no-pub`：无问题。
- `flutter test --no-pub`：39 项测试全部通过，覆盖页面布局、主要交互及数据序列化。
- `flutter build web --release --no-pub --no-web-resources-cdn`：构建成功，产物位于 `app/build/web`。
- 手机窄屏、大字体及部分横屏／平板尺寸由组件测试覆盖；尚未完成 Android／iOS 真机与正式后端全流程验收。
