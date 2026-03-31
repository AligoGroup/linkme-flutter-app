import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/foundation.dart';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/models/message.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../core/widgets/unified_toast.dart' as _toast show ToastExtension;

/// 发送位置页（简单版：发送“当前位置 + 可点击高德链接”）
/// - 地图 SDK：amap_flutter_map
/// - 定位 SDK：amap_flutter_location（单次定位，包含逆地理）
class SendLocationPage extends StatefulWidget {
  final String contactId;
  final bool isGroup;

  const SendLocationPage({super.key, required this.contactId, this.isGroup = false});

  @override
  State<SendLocationPage> createState() => _SendLocationPageState();
}

class _SendLocationPageState extends State<SendLocationPage> {
  static const String _iosAmapKey = String.fromEnvironment('AMAP_IOS_KEY', defaultValue: '');
  static const String _androidAmapKey = String.fromEnvironment('AMAP_ANDROID_KEY', defaultValue: '');
  // 你提供的 Key（开发测试用途）。正式建议通过 --dart-define 注入。
  static const String _fallbackIOSKey = '481cb5d80dc439440b1033f7a9da415f';
  // Android 端缺省不再留空，避免一直“定位中”。若未配置，将阻断并提示用户配置。
  static const String _fallbackAndroidKey = '';

  late AMapFlutterLocation _location;
  StreamSubscription<Map<String, Object>>? _sub;
  Timer? _timeoutTimer;

  CameraPosition _camera = const CameraPosition(target: LatLng(39.909187, 116.397451), zoom: 15);
  LatLng? _currentLatLng;
  String? _address;
  bool _locating = true;
  bool _showMyLocation = false; // 仅在权限通过后再开启地图蓝点，避免误判权限导致报错

  // 地图覆盖物
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();

    _startLocate();
  }

  // 请求权限并开始定位；同时处理缺少 Key 或权限被拒绝的情况，避免无限 loading。
  Future<void> _startLocate() async {
    setState(() => _locating = true);

    // 0) Android 端必须提供高德 Key
    final iosKey = (_iosAmapKey.isNotEmpty) ? _iosAmapKey : _fallbackIOSKey;
    final androidKey = (_androidAmapKey.isNotEmpty) ? _androidAmapKey : _fallbackAndroidKey;
    if (Platform.isAndroid && (androidKey.isEmpty)) {
      setState(() {
        _locating = false;
        _address = 'Android 端缺少高德 Key，请使用 --dart-define=AMAP_ANDROID_KEY=你的Key 运行应用';
      });
      return;
    }

    // iOS 直接先走 CoreLocation 快速通道，避免 AMap 定位链路在部分系统上迟迟无回调
    if (Platform.isIOS) {
      try {
        final pos = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.best,
          timeLimit: const Duration(seconds: 5),
        );
        setState(() {
          _currentLatLng = LatLng(pos.latitude, pos.longitude);
          _address = null; // 逆地理交给高德再补，不阻塞发送
          _camera = CameraPosition(target: _currentLatLng!, zoom: 17);
          _markers
            ..clear()
            ..add(Marker(position: _currentLatLng!, infoWindow: const InfoWindow(title: '我的位置')));
          _locating = false; // 已拿到坐标，可立即发送
        });
      } catch (_) {
        // 忽略，继续走 AMap 链路
      }
      if (!_locating) return; // 已拿到坐标则不再等待 AMap
    }

    // 1) 高德定位隐私合规（必须在使用定位前调用）
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);

    // 3) 设置 Key（定位 SDK 需要单独设置）
    AMapFlutterLocation.setApiKey(androidKey, iosKey);

    // 4) 配置并发起单次定位
    _location = AMapFlutterLocation();
    final opt = AMapLocationOption(
      onceLocation: true,
      needAddress: true,
    );
    // iOS 14+ 精确定位临时用途 key，应和 Info.plist 的 NSLocationTemporaryUsageDescriptionDictionary 中的 key 一致
    opt.fullAccuracyPurposeKey = 'share_location';
    if (Platform.isIOS) {
      // 允许“精确/模糊任意一种”以避免在仅模糊授权时卡住
      opt.desiredLocationAccuracyAuthorizationMode =
          AMapLocationAccuracyAuthorizationMode.FullAndReduceAccuracy;
      // 放宽精度要求，提升首次拿到坐标的成功率
      opt.desiredAccuracy = DesiredAccuracy.NearestTenMeters;
      opt.distanceFilter = 0;
    }
    _location.setLocationOption(opt);

    _sub?.cancel();
    _sub = _location.onLocationChanged().listen((event) {
      try {
        // 优先判断报错字段，避免无限 loading
        final errCode = event['errorCode'];
        final errInfo = event['errorInfo'];
        if (errCode != null && (errCode as num).toInt() != 0) {
          setState(() {
            _locating = false;
            _address = '定位失败($errCode): ${errInfo ?? '未知错误'}';
          });
          return;
        }

        final lat = (event['latitude'] as num).toDouble();
        final lng = (event['longitude'] as num).toDouble();
        final adr = (event['address'] as String?) ?? '';
        setState(() {
          _currentLatLng = LatLng(lat, lng);
          _address = adr.isNotEmpty ? adr : null;
          _camera = CameraPosition(target: _currentLatLng!, zoom: 17);
          _markers
            ..clear()
            ..add(Marker(position: _currentLatLng!, infoWindow: InfoWindow(title: '我的位置', snippet: _shortAddress(adr))));
          _locating = false;
          _showMyLocation = true; // 权限已通过，允许地图显示蓝点
        });
      } catch (_) {
        setState(() => _locating = false);
      }
    });

    _location.startLocation();

    // 若 10 秒仍无回调，自动重启一次定位；再过 10 秒仍无回调则判定超时。
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || !_locating) return;
      try { _location.stopLocation(); } catch (_) {}
      _location.startLocation();
      _timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!mounted || !_locating) return;
        setState(() {
          _locating = false;
          _address = '定位超时';
        });
      });
    });
  }

  @override
  void dispose() {
    try {
      _location.stopLocation();
      _location.destroy();
      _sub?.cancel();
      _timeoutTimer?.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iosKey = (_iosAmapKey.isNotEmpty) ? _iosAmapKey : _fallbackIOSKey;
    final androidKey = (_androidAmapKey.isNotEmpty) ? _androidAmapKey : _fallbackAndroidKey;
    return Scaffold(
      appBar: AppBar(
        title: const Text('发送位置'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                 AMapWidget(
                   privacyStatement: const AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true),
                   apiKey: AMapApiKey(iosKey: iosKey, androidKey: androidKey.isNotEmpty ? androidKey : null),
                   initialCameraPosition: _camera,
                  myLocationStyleOptions: MyLocationStyleOptions(true),
                   markers: _markers,
                   onMapCreated: (c) {},
                 ),
                if (_locating)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
          _buildLocationPreview(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_currentLatLng == null || _locating) ? null : _send,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('发送位置'),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLocationPreview() {
    final ll = _currentLatLng;
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _address ?? (ll != null ? '经纬度: ${ll.latitude.toStringAsFixed(6)}, ${ll.longitude.toStringAsFixed(6)}' : '正在定位...'),
            style: AppTextStyles.body1,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (ll != null)
            Text(
              '(${ll.latitude.toStringAsFixed(6)}, ${ll.longitude.toStringAsFixed(6)})',
              style: AppTextStyles.caption,
            ),
          // 不再提供多余的引导按钮，仅在失败时展示简短文字
        ],
      ),
    );
  }

  Future<void> _send() async {
    final ll = _currentLatLng;
    if (ll == null) return;
    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();
    if (auth.user == null) {
      if (!mounted) return;
      context.showErrorToast('未登录');
      return;
    }

    // 构造高德可点击链接（好友可点开外部地图/浏览器查看）
    final encodedName = Uri.encodeComponent(_address ?? '我的位置');
    final markerUrl = 'https://uri.amap.com/marker?position=${ll.longitude},${ll.latitude}&name=$encodedName';
    final content = '位置：${_address ?? ''}\n$markerUrl';

    await chat.sendMessage(
      senderId: auth.user!.id,
      content: content,
      contactId: widget.contactId,
      isGroup: widget.isGroup,
      type: MessageType.link,
    );

    if (mounted) Navigator.of(context).pop();
  }

  String _shortAddress(String? a) {
    if (a == null || a.isEmpty) return '';
    return (a.length > 18) ? a.substring(0, 18) + '…' : a;
  }
}
