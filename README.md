LinkMe Flutter Frontend

Windows 平台快速安装与运行（Dart / Flutter）

1. 前提
- Windows 10 或更高，开启开发者模式（可选）。
- 已安装 Git（可选但推荐）。

2. 下载与安装（推荐：只安装 Flutter，它自带 Dart）
- Flutter SDK：访问 https://docs.flutter.dev/get-started/install/windows 下载最新的 Flutter SDK zip，解压到例如 C:\src\flutter。
- Dart SDK（可选）：若需独立安装，访问 https://dart.dev/get-dart 下载并解压，放到例如 C:\dart-sdk。
  - 说明：Flutter SDK 已包含 Dart，可跳过独立 Dart 安装。

3. 配置系统环境变量
- 将 Flutter 加入 PATH：将 C:\src\flutter\bin 添加到系统环境变量 Path。
- 若单独安装 Dart：将 C:\dart-sdk\bin 添加到 Path。
- Android（若构建 Android）：设置 ANDROID_HOME（或 ANDROID_SDK_ROOT）指向 Android SDK 目录，且将 %ANDROID_HOME%\platform-tools 添加到 Path。

4. 验证安装（测试成功）
- 打开 PowerShell，运行：

```
flutter --version
dart --version    # 可选
flutter doctor -v
```

5. 项目依赖与运行（在项目根目录执行）
```
flutter pub get
flutter devices
flutter run -d windows
```

6. 额外注意
- iOS 构建需 macOS；macOS 专用步骤不包含在此文档。
- 若使用原生插件（如 AMap），可能需要在 Android Studio 中配置额外的原生 SDK/key。

Flutter前端仓库地址：https://github.com/AligoGroup/LinkMe_Flutter_frontend.git
学院仓库地址：https://github.com/AligoGroup/LinkMe_Java_bankend.git

常见问题见————>LinkMe协同文档-前置信息.md
