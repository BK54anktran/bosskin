import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import '../../data/services/auth_service.dart';
import '../config/server_config.dart';

/// Lớp nền bản đồ dùng chung cho cả app.
///
/// Ô bản đồ lấy qua BE (`/api/v1/map-tiles/{z}/{x}/{y}.png`) thay vì gọi thẳng
/// tile.openstreetmap.org, để người dùng ở mạng chặn OSM vẫn xem được bản đồ.
/// BE cần đăng nhập nên gửi kèm token; trình duyệt tự cache ô 30 ngày.
TileLayer appTileLayer() {
  final auth = AuthService.instance;
  // Khi sysadmin impersonate, dùng token của company user (giống ApiService)
  final token = (auth.impersonatingUser ?? auth.currentUser)?.token;
  return TileLayer(
    urlTemplate: '${ServerConfig.baseUrl}/map-tiles/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.bosskin.app',
    maxNativeZoom: 18,
    tileProvider: CancellableNetworkTileProvider(
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    ),
  );
}
