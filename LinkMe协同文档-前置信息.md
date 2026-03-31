Windows 骞冲彴蹇€熷畨瑁呬笌杩愯锛圖art / Flutter锛?

1. 鍓嶆彁
- Windows 10 鎴栨洿楂橈紝寮€鍚紑鍙戣€呮ā寮忥紙鍙€夛級銆?
- 宸插畨瑁?Git锛堝彲閫変絾鎺ㄨ崘锛夈€?

2. 涓嬭浇涓庡畨瑁咃紙鎺ㄨ崘锛氬彧瀹夎 Flutter锛屽畠鑷甫 Dart锛?
- Flutter SDK锛氳闂?https://docs.flutter.dev/get-started/install/windows 涓嬭浇鏈€鏂扮殑 Flutter SDK zip锛岃В鍘嬪埌渚嬪 `C:\src\flutter`銆?
- Dart SDK锛堝彲閫夛級锛氳嫢闇€鐙珛瀹夎锛岃闂?https://dart.dev/get-dart 涓嬭浇骞惰В鍘嬶紝鏀惧埌渚嬪 `C:\dart-sdk`銆?
  - 璇存槑锛欶lutter SDK 宸插寘鍚?Dart锛屽彲璺宠繃鐙珛 Dart 瀹夎銆?

3. 閰嶇疆绯荤粺鐜鍙橀噺
- 灏?Flutter 鍔犲叆 PATH锛氬皢 `C:\src\flutter\bin` 娣诲姞鍒扮郴缁熺幆澧冨彉閲?`Path`銆?
- 鑻ュ崟鐙畨瑁?Dart锛氬皢 `C:\dart-sdk\bin` 娣诲姞鍒?`Path`銆?
- Android锛堣嫢鏋勫缓 Android锛夛細璁剧疆 `ANDROID_HOME`锛堟垨 `ANDROID_SDK_ROOT`锛夋寚鍚?Android SDK 鐩綍锛屼笖灏?`%ANDROID_HOME%\platform-tools` 娣诲姞鍒?`Path`銆?

4. 楠岃瘉瀹夎锛堟祴璇曟垚鍔燂級
- 鎵撳紑 PowerShell锛岃繍琛岋細

```powershell
flutter --version
dart --version    # 鍙€?
flutter doctor -v
```

- 棰勬湡锛歚flutter --version` 涓?`flutter doctor` 鑳芥纭繍琛岋紝`flutter doctor` 涓嶆樉绀洪樆姝㈠紑鍙戠殑涓ラ噸閿欒銆?

5. 椤圭洰渚濊禆涓庤繍琛岋紙鍦ㄩ」鐩牴鐩綍鎵ц锛?
- 鑾峰彇渚濊禆锛?

```powershell
flutter pub get
```

- 杩愯椤圭洰锛堥€夋嫨鐩爣璁惧锛夛細

```powershell
# 鍒楀嚭鍙敤璁惧
flutter devices
# 鍦?Windows 妗岄潰涓婅繍琛?
flutter run -d windows
# 鍦?Android 妯℃嫙鍣?璁惧涓婅繍琛?
flutter run -d <device-id>
```

- 鏋勫缓鍙戝竷鍖咃紙Android锛夛細

```powershell
flutter build apk --release
```

6. 棰濆娉ㄦ剰
- iOS 鏋勫缓闇€ macOS锛沵acOS 涓撶敤姝ラ涓嶅寘鍚湪姝ゆ枃妗ｃ€?
- 鑻ヤ娇鐢ㄥ師鐢熸彃浠讹紙濡?AMap锛夛紝鍙兘闇€瑕佸湪 Android Studio 涓厤缃澶栫殑鍘熺敓 SDK/key銆?

甯歌闂涓庤В鍐筹細
Q: PowerShell 涓彁绀?'flutter' 涓嶆槸鍐呴儴鎴栧閮ㄥ懡浠?
A: 纭 `C:\src\flutter\bin` 宸插姞鍏ョ郴缁?`Path`锛岄噸鍚粓绔垨娉ㄩ攢鍚庨噸鍚敓鏁堛€?

Q: `flutter doctor` 鏄剧ず Android licenses 鏈帴鍙?
A: 杩愯 `flutter doctor --android-licenses` 骞舵寜鎻愮ず鎺ュ彈锛屾垨鍦?Android Studio 鐨?SDK 绠＄悊鍣ㄤ腑瀹夎缂哄け缁勪欢銆?

Q: 鍦?Windows 涓婃瀯寤烘姤閿欒姹傚畨瑁?Visual Studio
A: Windows 妗岄潰鏋勫缓闇€瑕佸畨瑁呭甫鏈?C++ 鐨?Visual Studio锛堟寜 Flutter 瀹樻柟鏂囨。瀹夎鎵€闇€宸ヤ綔璐熻浇锛夈€傚涓嶉渶瑕佹闈紝浣跨敤 Android/iOS 鐩爣銆?

Q: `flutter pub get` 澶辫触鎴栬秴鏃?
A: 妫€鏌ョ綉缁滄垨浠ｇ悊璁剧疆锛涘彲灏濊瘯 `flutter pub cache repair` 鎴栧垏鎹㈠埌绋冲畾缃戠粶鍚庨噸璇曘€?

Q: 杩愯鏃舵彁绀虹己灏?Android SDK 鎴栨湭鎵惧埌 Java
A: 瀹夎 Android Studio锛屽苟纭繚 `ANDROID_HOME`/`ANDROID_SDK_ROOT` 涓?Java JDK 璺緞姝ｇ‘閰嶇疆锛圝DK 11+ 鎺ㄨ崘锛夈€?

Q: 椤圭洰浣跨敤绗笁鏂瑰師鐢?SDK锛堥珮寰峰湴鍥撅級鎶ラ敊鎴栭渶瑕?key
A: 鏌ラ槄楂樺痉鎻掍欢鏂囨。锛岄厤缃?API key銆佸寘鍚?绛惧悕鎴栭摼鎺ュ師鐢熷簱锛涢儴鍒嗘湇鍔￠渶鐢宠鍟嗙敤鎺堟潈锛堣繘鍏ラ珮寰峰紑鍙戣€呭钩鍙扮敵璇?锛夈€?

Q: 纭鐜瀹屽叏鍙敤浠ヨ繘琛屽彂甯?
A: `flutter doctor -v` 涓嶅簲鏄剧ず闃绘鍙戝竷鐨勯敊璇紱CI 涓繍琛?`flutter analyze` 涓?`flutter test`锛堣嫢瀛樺湪娴嬭瘯锛夈€?

Q: 鏋勫缓浜х墿娓呯悊
A: 鍦ㄩ」鐩牴杩愯 `flutter clean`锛岀劧鍚庨噸鏂?`flutter pub get`銆?

---
浠撳簱鍦板潃锛歨ttps://github.com/AligoGroup/LinkMe_Flutter_frontend.git
鍗忓悓鏂囨。鏇存柊锛?026-2-4

