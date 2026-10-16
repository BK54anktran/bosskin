import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';

class GeoRepository {
  final _api = ApiService.instance;

  /// Nhờ backend mở link Google Maps (kể cả link rút gọn) để lấy toạ độ.
  Future<LatLng> resolveMapsLink(String url) {
    return _api.post<LatLng>(
      '/geo/resolve-maps-link',
      (data) {
        final m = Map<String, dynamic>.from(data as Map);
        return LatLng((m['latitude'] as num).toDouble(), (m['longitude'] as num).toDouble());
      },
      {'url': url},
    );
  }
}
