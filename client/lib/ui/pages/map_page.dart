import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'ar/ar_screen.dart';
import '../services/capsule_api.dart';
import 'capsule_detail_page.dart';
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
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> with TickerProviderStateMixin {
  static const _defaultCenter = LatLng(37.5665, 126.9780);

  final _spotApi = TouristSpotApi();
  final _mapController = MapController();

  List<TouristSpot> _spots = const [];
  List<CapsuleMapMarker> _capsules = const [];
  SpotFilter _filter = SpotFilter.all;
  final Set<String> _selectedCategories = <String>{};
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

  /// 외부에서 호출 가능한 공개 새로고침 메서드.
  /// 캡슐 생성 직후 등 GlobalKey 로 호출.
  Future<void> refresh() => _refresh();

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

  /// 현재 로드된 관광지에서 등장하는 카테고리 목록(중복 제거, 정렬).
  List<String> get _availableCategories {
    final set = <String>{};
    for (final s in _spots) {
      final c = (s.category ?? '').trim();
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return list;
  }

  Iterable<TouristSpot> get _visibleSpots {
    Iterable<TouristSpot> result = _spots;
    if (_filter == SpotFilter.undiscovered) {
      result = result.where((s) => !s.visited);
    } else if (_filter == SpotFilter.completed) {
      result = result.where((s) => s.visited);
    }
    if (_selectedCategories.isNotEmpty) {
      result = result.where(
        (s) => _selectedCategories.contains((s.category ?? '').trim()),
      );
    }
    return result;
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

    // 캡슐이 열려 있으면(잠금 해제) 상세 페이지로 이동해 내용물(글/사진/음악) 보여줌.
    if (capsule.canOpenNow) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(
            builder: (_) => CapsuleDetailPage(
              capsule: CapsuleListItem(
                id: capsule.id,
                status: capsule.status,
                design: capsule.design,
                emotion: capsule.emotion ?? '',
                created: capsule.createdAt?.toIso8601String() ?? '',
                buriedAt: capsule.buriedAt?.toIso8601String() ?? '',
                isGroupCapsule: false, // 마커엔 정보 없음. 상세 페이지에서 서버 응답으로 보정.
                openOption: capsule.openOption ?? 'anytime',
                openAt: capsule.openAt?.toIso8601String() ?? '',
                canOpenNow: capsule.canOpenNow,
              ),
            ),
          ))
          .then((_) => _refresh());
      return;
    }

    // 잠긴 캡슐은 잠금 시트(개봉 시점/잔여 시간) 표시.
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
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final categories = _availableCategories;
            return SafeArea(
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
                      '발견 상태',
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
                              selectedColor:
                                  MapPage._brown.withValues(alpha: 0.2),
                              onSelected: (_) {
                                setState(() => _filter = f);
                                setModalState(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                    if (categories.isNotEmpty) ...[
                      const Divider(height: 32),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '카테고리',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: MapPage._brown,
                              ),
                            ),
                          ),
                          if (_selectedCategories.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() => _selectedCategories.clear());
                                setModalState(() {});
                              },
                              child: const Text(
                                '전체 해제',
                                style: TextStyle(color: MapPage._brown),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: categories.map((c) {
                          final selected = _selectedCategories.contains(c);
                          return FilterChip(
                            label: Text(touristCategoryLabel(c)),
                            selected: selected,
                            selectedColor:
                                MapPage._brown.withValues(alpha: 0.2),
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedCategories.add(c);
                                } else {
                                  _selectedCategories.remove(c);
                                }
                              });
                              setModalState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ],
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
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
          width: 110,
          height: 130,
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
            width: 110,
            height: 130,
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () => _openCapsuleSheet(capsule),
              child: _CapsuleMarker(
                locked: capsule.isLocked,
                design: capsule.design,
              ),
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
            right: 16,
            bottom: 24,
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

  // category 값(소문자) → 마커 파일명. 매칭 안되는 카테고리는 visited_default 폴백.
  static const Map<String, String> _categoryImage = {
    'palace': 'palace.png',
    'tower': 'tower.png',
    'pagoda': 'pagoda.png',
    'museum': 'museum.png',
  };

  @override
  Widget build(BuildContext context) {
    final String fileName;
    if (!spot.visited) {
      fileName = 'unknown.png';
    } else {
      final String cat = (spot.category ?? '').toLowerCase().trim();
      fileName = _categoryImage[cat] ?? 'visited_default.png';
    }
    return _ScaledPinImage(
      asset: 'assets/images/markers/$fileName',
      fallback: _MarkerFallback(
        label: spot.visited ? '!' : '?',
        color: spot.visited
            ? const Color(0xFFA14040)
            : const Color(0xFF6B6862),
      ),
    );
  }
}

class _CapsuleMarker extends StatelessWidget {
  const _CapsuleMarker({required this.locked, this.design = 'base'});

  final bool locked;
  final String design;

  // 서버 design 값과 일치하는 마커 자산 키. 미지의 값은 base 로 폴백.
  static const Set<String> _knownDesigns = {'base', 'gyeongju', 'seoul'};

  @override
  Widget build(BuildContext context) {
    final String designKey = _knownDesigns.contains(design) ? design : 'base';
    final String suffix = locked ? '_locked' : '';
    return _ScaledPinImage(
      asset: 'assets/images/markers/capsule_$designKey$suffix.png',
      fallback: _MarkerFallback(
        label: locked ? '🔒' : '📦',
        color: locked
            ? const Color(0xFFA14040)
            : const Color(0xFF1FAA8C),
      ),
    );
  }
}

/// PNG 가운데에 핀이 작게 박혀있는 경우 여백을 크롭해서 핀만 크게 보이도록.
/// scale 값은 핀이 캔버스의 ~33% 영역에 그려져있다고 가정한 값.
class _ScaledPinImage extends StatelessWidget {
  const _ScaledPinImage({required this.asset, required this.fallback});

  final String asset;
  final Widget fallback;

  static const double _scale = 3.0;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Transform.scale(
        scale: _scale,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

class _MarkerFallback extends StatelessWidget {
  const _MarkerFallback({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
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

  // Mapbox·OSM 라이선스상 표기는 필수이므로 제거하지 않고
  // 글자/배경/패딩을 최소화해 화면을 가리지 않도록 한다.
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text(
            '© Mapbox © OSM',
            style: TextStyle(
              fontSize: 8,
              color: MapPage._brown,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
