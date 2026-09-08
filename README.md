# LoveSpace

LoveSpace 是一款只属于两个人的私密情侣应用。它把日常记录、共同计划和彼此互动集中在同一个空间里，让重要日期、照片、心情与生活中的小事都能被认真保存。

项目同时支持 Android 应用和 iPhone 主屏幕 Web App，两端共享同一套业务数据与交互体验。账号固定为两位使用者，所有共享内容均按照情侣关系进行权限校验。

## 功能

- 首页：纪念日、每日问答、双方心情、未读消息和最近动态
- 每日问答：双方分别回答，全部提交后共同揭晓
- 点滴与时间轴：文字、图片、日期、标签、感谢墙和随机回忆
- 心情：每日记录、私密可见性与月历回顾
- 相册：相册管理、多图上传、收藏与照片浏览
- 纪念日：倒数、累计天数、重复日期与提醒设置
- 共同任务：任务分配、完成状态与积分奖励
- 今天吃什么：菜品、分类、规格、点单和订单记录
- 甜蜜积分：积分流水、等级与自定义兑换项目
- 愿望清单：想做、进行中和已实现状态
- 时光胶囊：在约定日期前隐藏正文与照片
- 默契测试：独立选择答案后查看双方结果
- 一起变好：健康目标、每日记录、双人挑战与饮食参考
- 周报与月报：回顾双方的健康节奏和共同生活记录
- 通知中心：未读状态、系统通知与业务页面跳转
- 个人中心：头像昵称、账号安全、设备通知与应用更新

## 客户端技术栈

- Flutter / Dart
- Material 3
- GoRouter
- Shared Preferences
- Flutter Secure Storage
- Image Picker
- Android 个推 SDK
- Service Worker / Web Push / PWA

## 服务端技术栈

- Java 21
- Spring Boot 3.5
- Spring Security
- MySQL 8.4
- Flyway
- JWT、一次性刷新令牌与 BCrypt
- S3 兼容对象存储
- Web Push / VAPID
- Getui REST API V2
- Transactional Outbox

## 可靠性与隐私

- 双人空间数据隔离与服务端关系校验
- 问答答案在双方提交前保持隐藏
- 私密心情仅自己可见
- 创建请求使用幂等标识，避免弱网重试产生重复数据
- 并发登录续期采用 single-flight 刷新
- 图片使用私有对象存储和短期授权地址
- 最近内容缓存与文字草稿恢复
- 通知投递支持重试、租约和失效订阅停用

## 项目结构

```text
lovespace/
├── app/             # Flutter Android 与 Web/PWA 客户端
├── server/          # Spring Boot 服务端
├── design-system/   # 视觉规范与设计令牌
├── docs/            # 产品及技术资料
└── scripts/         # 项目辅助脚本
```

## 目标设备

- Android：一加 12 / ColorOS
- iPhone：iOS 主屏幕 Web App

LoveSpace 不开放公共注册或多人空间，产品始终围绕两位固定使用者设计。
