import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'ar/ar_screen.dart';
import 'map/capsule_locked_sheet.dart';
import 'map/map_config.dart';
import 'map/spot_3d_view_page.dart';
import 'map/tourist_spot_models.dart';
import '../services/tourist_spot_api.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  static const Color _backgroundColor = Color(0xFFFFF6E6);
  static const Color _brown = Color(0xFF6F4135);
  static const Color _mutedText = Color(0xFFCDBBA8);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  static const _defaultCenter = LatLng(37.5665, 126.9780);

  final _spotApi = TouristSpotApi();
  final _mapController = MapController();

  List<TouristSpot> _spots = const [];
  List<CapsuleMapMarker> _capsules = const [];
  SpotFilter _filter = SpotFilter.all;
  bool _showCapsules = true;
  bool _loading = true;
  bool _checkingIn = false;
  MapStyle _mapStyle = MapStyle.streets;
  LatLng? _userLatLng;
  StreamSubscription<Position>? _positionSub;
  AnimationController? _cameraAnim;

  @override
  void initState() {
    super.initState();
    _refresh();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _cameraAnim?.dispose();
    super.dispose();
  }

  void _flyTo(LatLng dest, {double zoom = 17}) {
    _cameraAnim?.dispose();
    final start = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    final anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final curve = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
    anim.addListener(() {
      final t = curve.value;
      final lat = start.latitude + (dest.latitude - start.latitude) * t;
      final lng = start.longitude + (dest.longitude - start.longitude) * t;
      final z = startZoom + (zoom - startZoom) * t;
      final p = _safeLatLng(lat, lng);
      if (p == null) return;
      _mapController.move(p, z);
    });
    _cameraAnim = anim;
    anim.forward();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _spotApi.listSpots(),
      _spotApi.listCapsules(),
    ]);
    if (!mounted) return;
    setState(() {
      _spots = results[0] as List<TouristSpot>;
      _capsules = results[1] as List<CapsuleMapMarker>;
      _loading = false;
    });
  }

  Future<void> _startLocationUpdates() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final initialLatLng = _safeLatLng(initial.latitude, initial.longitude);
      if (initialLatLng != null) {
        setState(() => _userLatLng = initialLatLng);
        _mapController.move(initialLatLng, 14);
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        if (!mounted) return;
        final next = _safeLatLng(position.latitude, position.longitude);
        if (next == null) return;
        setState(() => _userLatLng = next);
      });
    } catch (_) {}
  }

  static LatLng? _safeLatLng(double lat, double lon) {
    if (lat.isNaN || lon.isNaN || lat.isInfinite || lon.isInfinite) return null;
    if (lat == 0 && lon == 0) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return LatLng(lat, lon);
  }

  Future<void> _centerOnUser() async {
    final loc = _userLatLng;
    if (loc != null) {
      _mapController.move(loc, 15);
      return;
    }
    await _startLocationUpdates();
  }

  void _zoomIn() {
    final z = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (z + 1).clamp(5.0, 20.0));
  }

  void _zoomOut() {
    final z = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (z - 1).clamp(5.0, 20.0));
  }

  Iterable<TouristSpot> get _visibleSpots {
    switch (_filter) {
      case SpotFilter.all:
        return _spots;
      case SpotFilter.undiscovered:
        return _spots.where((s) => !s.visited);
      case SpotFilter.completed:
        return _spots.where((s) => s.visited);
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earth = 6371000.0;
    final rad = math.pi / 180;
    final dLat = (b.latitude - a.latitude) * rad;
    final dLon = (b.longitude - a.longitude) * rad;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * rad) *
            math.cos(b.latitude * rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earth * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  Future<void> _discoverNearby() async {
    final user = _userLatLng;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 가져오지 못했어요.')),
      );
      return;
    }

    TouristSpot? nearest;
    double nearestDistance = double.infinity;
    for (final spot in _spots) {
      if (spot.visited) continue;
      final d = _distanceMeters(user, LatLng(spot.latitude, spot.longitude));
      if (d < nearestDistance) {
        nearest = spot;
        nearestDistance = d;
      }
    }

    if (nearest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 모든 관광지를 발견했어요!')),
      );
      return;
    }

    if (nearestDistance > nearest.radiusMeters) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '가장 가까운 미발견 장소까지 ${nearestDistance.toStringAsFixed(0)}m 남았어요.',
          ),
        ),
      );
      _mapController.move(LatLng(nearest.latitude, nearest.longitude), 15);
      return;
    }

    await _checkInSpot(nearest, source: 'manual');
  }

  Future<void> _checkInSpot(TouristSpot spot, {String source = 'ar'}) async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    final user = _userLatLng;
    final ok = await _spotApi.visitSpot(
      spotId: spot.id,
      source: source,
      latitude: user?.latitude,
      longitude: user?.longitude,
    );
    if (!mounted) return;
    setState(() => _checkingIn = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${spot.name}을(를) 발견했어요!')),
      );
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증에 실패했어요. 위치를 확인해주세요.')),
      );
    }
  }

  void _openSpotSheet(TouristSpot spot) {
    final spotLatLng = _safeLatLng(spot.latitude, spot.longitude);
    final user = _userLatLng;
    final isWithinRadius = user != null &&
        spotLatLng != null &&
        _distanceMeters(user, spotLatLng) <= spot.radiusMeters;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => Spot3DViewPage(
          spot: spot,
          isWithinRadius: isWithinRadius,
          onCheckIn: () => _checkInSpot(spot, source: 'manual'),
        ),
      ),
    )
        .then((_) {
      _refresh();
    });
  }

  void _openCapsuleSheet(CapsuleMapMarker capsule) {
    final capsuleLatLng = _safeLatLng(capsule.latitude, capsule.longitude);
    if (capsuleLatLng != null) {
      _flyTo(capsuleLatLng, zoom: 17);
    }
    String? spotName;
    for (final s in _spots) {
      if (s.visit?.capsuleId == capsule.id) {
        spotName = s.name;
        break;
      }
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CapsuleLockedSheet(capsule: capsule, spotName: spotName),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '관광지 필터',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MapPage._brown,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: SpotFilter.values
                    .map(
                      (f) => ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        selectedColor: MapPage._brown.withValues(alpha: 0.2),
                        onSelected: (_) {
                          setState(() => _filter = f);
                          Navigator.of(context).pop();
                        },
                      ),
                    )
                    .toList(),
              ),
              const Divider(height: 32),
              const Text(
                '내가 묻은 캡슐',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MapPage._brown,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '지도에 캡슐 표시',
                  style: TextStyle(color: MapPage._brown),
                ),
                value: _showCapsules,
                activeColor: MapPage._brown,
                onChanged: (value) {
                  setState(() => _showCapsules = value);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (!MapConfig.hasValidToken) {
      return const _MissingTokenView();
    }
    final user = _userLatLng;
    final center =
        (user != null && user.latitude.isFinite && user.longitude.isFinite)
            ? user
            : _defaultCenter;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        minZoom: 5,
        maxZoom: 20,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(-85.0, -180.0),
            const LatLng(85.0, 180.0),
          ),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.tileUrlTemplate(_mapStyle),
          userAgentPackageName: 'me.toricapsule.app',
          maxZoom: 22,
          tileSize: 512,
          zoomOffset: -1,
        ),
        MarkerLayer(markers: _buildMarkers()),
        const _MapboxAttribution(),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final spot in _visibleSpots) {
      final point = _safeLatLng(spot.latitude, spot.longitude);
      if (point == null) continue;
      markers.add(
        Marker(
          point: point,
          width: 56,
          height: 70,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => _openSpotSheet(spot),
            child: _SpotMarker(spot: spot),
          ),
        ),
      );
    }

    if (_showCapsules) {
      for (final capsule in _capsules) {
        if (!capsule.isBuried) continue;
        final point = _safeLatLng(capsule.latitude, capsule.longitude);
        if (point == null) continue;
        markers.add(
          Marker(
            point: point,
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: () => _openCapsuleSheet(capsule),
              child: _CapsuleMarker(locked: capsule.isLocked),
            ),
          ),
        );
      }
    }

    if (_userLatLng != null) {
      markers.add(
        Marker(
          point: _userLatLng!,
          width: 28,
          height: 28,
          child: const _UserMarker(),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MapPage._backgroundColor,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: ColoredBox(color: MapPage._backgroundColor)),
          Positioned.fill(child: _buildMap()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 92,
              child: Image.asset(
                'assets/images/auth/asset.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            top: 118,
            left: 16,
            child: Column(
              children: <Widget>[
                _MapControlButton(
                  label: 'AR',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext context) => const ArScreen(),
                      ),
                    ).then((_) => _refresh());
                  },
                ),
                const SizedBox(height: 12),
                _MapControlButton(
                  label: '관광지',
                  onTap: _discoverNearby,
                ),
                const SizedBox(height: 12),
                _MapControlButton(
                  icon: Icons.tune,
                  onTap: _showFilterMenu,
                ),
                const SizedBox(height: 12),
                _MapControlButton(
                  icon: Icons.near_me_outlined,
                  onTap: _centerOnUser,
                ),
              ],
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: Column(
              children: <Widget>[
                _MapControlButton(
                  icon: Icons.add,
                  iconSize: 26,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.remove,
                  iconSize: 26,
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    this.icon,
    this.label,
    this.iconSize = 22,
    this.onTap,
  });

  final IconData? icon;
  final String? label;
  final double iconSize;
  final VoidCallback? onTap;

  static const Color _brown = MapPage._brown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: _brown, width: 4),
        ),
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: label != null
                ? Text(
                    label!,
                    style: const TextStyle(
                      color: _brown,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Icon(icon, color: _brown, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class _SpotMarker extends StatelessWidget {
  const _SpotMarker({required this.spot});

  final TouristSpot spot;

  @override
  Widget build(BuildContext context) {
    final visited = spot.visited;
    final color = visited ? spot.markerColor : const Color(0xFF3F3D3A);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 40,
          child: CustomPaint(
            size: const Size(8, 14),
            painter: _MarkerTailPainter(color: color),
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            visited ? spot.markerIcon : Icons.help_outline,
            color: Colors.white,
            size: 24,
          ),
        ),
        if (visited)
          Positioned(
            top: 34,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check, color: Colors.white, size: 11),
            ),
          ),
      ],
    );
  }
}

class _CapsuleMarker extends StatelessWidget {
  const _CapsuleMarker({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color = locked ? const Color(0xFFA14040) : const Color(0xFF1FAA8C);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        locked ? Icons.lock_outline : Icons.lock_open_outlined,
        color: color,
        size: 18,
      ),
    );
  }
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

class _MarkerTailPainter extends CustomPainter {
  _MarkerTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkerTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MissingTokenView extends StatelessWidget {
  const _MissingTokenView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MapPage._backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.vpn_key_off_outlined, size: 48, color: MapPage._brown),
          SizedBox(height: 12),
          Text(
            'Mapbox 토큰이 설정되지 않았어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: MapPage._brown,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '앱 실행 시 --dart-define=MAPBOX_TOKEN=pk.xxx 옵션을 전달해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: MapPage._mutedText),
          ),
        ],
      ),
    );
  }
}

class _MapboxAttribution extends StatelessWidget {
  const _MapboxAttribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '© Mapbox © OpenStreetMap',
            style: TextStyle(fontSize: 10, color: MapPage._brown),
          ),
        ),
      ),
    );
  }
}
