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
  static const double _initialZoom = 13;
  // 마커 클러스터링 임계값(픽셀). 화면상 이 픽셀 이내에 있는 마커들을 하나로 묶음.
  static const double _clusterPixelRadius = 60;

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
  double _currentZoom = _initialZoom;
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
                name: '',
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
        initialZoom: _initialZoom,
        minZoom: 5,
        maxZoom: 20,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(-85.0, -180.0),
            const LatLng(85.0, 180.0),
          ),
        ),
        onMapEvent: _onMapEvent,
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

  /// 줌 변화에 따라 마커 클러스터링이 갱신되도록 setState 트리거.
  void _onMapEvent(MapEvent event) {
    final double zoom = event.camera.zoom;
    if ((zoom - _currentZoom).abs() >= 0.25) {
      if (!mounted) return;
      setState(() => _currentZoom = zoom);
    }
  }

  /// 줌 레벨에서 1 픽셀이 차지하는 미터.
  /// 웹 메르카토르: equator 156543.034 m/px ÷ 2^zoom, 위도 보정 cos(lat).
  double _metersPerPixel(double zoom, double lat) {
    return 156543.034 *
        math.cos(lat * math.pi / 180) /
        math.pow(2, zoom);
  }

  /// 현재 줌에서의 클러스터 거리 임계값(미터).
  double _clusterThresholdMeters(double zoom) {
    final LatLng anchor =
        _userLatLng ?? _mapController.camera.center;
    return _metersPerPixel(zoom, anchor.latitude) * _clusterPixelRadius;
  }

  /// 관광지/캡슐 마커들을 가까운 것끼리 묶어서 클러스터로 만든다.
  List<_MarkerCluster> _buildClusters(List<_MapItem> items, double zoom) {
    if (items.isEmpty) return const <_MarkerCluster>[];
    final double threshold = _clusterThresholdMeters(zoom);
    final clusters = <_MarkerCluster>[];

    for (final item in items) {
      _MarkerCluster? best;
      double bestDist = double.infinity;
      for (final c in clusters) {
        final double d = _distanceMeters(item.point, c.center);
        if (d <= threshold && d < bestDist) {
          best = c;
          bestDist = d;
        }
      }
      if (best != null) {
        best.items.add(item);
        // 클러스터 중심을 멤버 평균으로 갱신
        double lat = 0;
        double lng = 0;
        for (final m in best.items) {
          lat += m.point.latitude;
          lng += m.point.longitude;
        }
        final int n = best.items.length;
        best.center = LatLng(lat / n, lng / n);
      } else {
        clusters.add(_MarkerCluster(<_MapItem>[item], item.point));
      }
    }

    return clusters;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // 관광지는 클러스터링하지 않고 항상 개별 마커로 표시한다.
    for (final spot in _visibleSpots) {
      final point = _safeLatLng(spot.latitude, spot.longitude);
      if (point == null) continue;
      markers.add(_buildSpotMarker(spot, point));
    }

    // 캡슐만 가까운 것끼리 클러스터링.
    if (_showCapsules) {
      final capsuleItems = <_MapItem>[];
      for (final capsule in _capsules) {
        if (!capsule.isBuried) continue;
        final point = _safeLatLng(capsule.latitude, capsule.longitude);
        if (point == null) continue;
        capsuleItems.add(_MapItem.capsule(capsule, point));
      }

      final clusters = _buildClusters(capsuleItems, _currentZoom);
      for (final cluster in clusters) {
        if (cluster.items.length == 1) {
          final capsule = cluster.items.first.capsule!;
          markers.add(_buildCapsuleMarker(capsule, cluster.items.first.point));
        } else {
          markers.add(_buildClusterMarker(cluster));
        }
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

  /// 핀 그림은 180x220 이지만 실제 클릭 인식은 핀 모양(상단 70x100)만 받도록 분리.
  /// (마커 아래 빈 픽셀까지 탭 판정되어 잘못된 캡슐/관광지가 눌리는 문제 방지)
  /// _ScaledPinImage 가 4배 확대 + ClipRect 로 핀을 박스 중앙에 그리지만 실제로
  /// 보이는 핀 본체는 박스의 위쪽 절반쯤이므로 hit area 를 위로 올려 정렬.
  Marker _buildSpotMarker(TouristSpot spot, LatLng point) {
    return Marker(
      point: point,
      width: 180,
      height: 220,
      alignment: Alignment.center,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(child: _SpotMarker(spot: spot)),
          ),
          Positioned(
            left: 55,
            top: 20,
            width: 70,
            height: 100,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openSpotSheet(spot),
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildCapsuleMarker(CapsuleMapMarker capsule, LatLng point) {
    return Marker(
      point: point,
      width: 180,
      height: 220,
      alignment: Alignment.center,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: _CapsuleMarker(
                locked: capsule.isLocked,
                design: capsule.design,
              ),
            ),
          ),
          Positioned(
            left: 55,
            top: 20,
            width: 70,
            height: 100,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openCapsuleSheet(capsule),
            ),
          ),
        ],
      ),
    );
  }

  /// 캡슐 클러스터 마커: 단일 캡슐 마커와 동일한 모양.
  /// 겹친 캡슐을 누르면 _openClusterSheet 가 캡슐 목록 바텀시트를 띄움.
  Marker _buildClusterMarker(_MarkerCluster cluster) {
    final CapsuleMapMarker representative = cluster.items.first.capsule!;
    return Marker(
      point: cluster.center,
      width: 180,
      height: 220,
      alignment: Alignment.center,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: _CapsuleMarker(
                locked: representative.isLocked,
                design: representative.design,
              ),
            ),
          ),
          Positioned(
            left: 55,
            top: 20,
            width: 70,
            height: 100,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openClusterSheet(cluster),
            ),
          ),
        ],
      ),
    );
  }

  void _openClusterSheet(_MarkerCluster cluster) {
    final LatLng center = cluster.center;
    _flyTo(center, zoom: math.min(_currentZoom + 2, 19));

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetCtx) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDBBA8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    '이 위치의 캡슐 (${cluster.items.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: MapPage._brown,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: cluster.items.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: Color(0xFFEEE7DC),
                    ),
                    itemBuilder: (_, int i) =>
                        _buildClusterRow(cluster.items[i], sheetCtx),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClusterRow(_MapItem item, BuildContext sheetCtx) {
    if (item.spot != null) {
      final spot = item.spot!;
      return ListTile(
        leading: Icon(spot.markerIcon, color: MapPage._brown),
        title: Text(
          spot.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: MapPage._brown,
          ),
        ),
        subtitle: Text(
          '${spot.categoryLabel} · ${spot.visited ? '발견 완료' : '미발견'}',
          style: const TextStyle(
            color: MapPage._mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFFB7A59C),
        ),
        onTap: () {
          Navigator.of(sheetCtx).pop();
          _openSpotSheet(spot);
        },
      );
    }
    final capsule = item.capsule!;
    final String designLabel = _capsuleDesignLabel(capsule.design);
    return ListTile(
      leading: Icon(
        capsule.isLocked
            ? Icons.lock_outline
            : Icons.inventory_2_outlined,
        color: MapPage._brown,
      ),
      title: Text(
        '$designLabel 캡슐',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: MapPage._brown,
        ),
      ),
      subtitle: Text(
        capsule.isLocked ? '아직 잠긴 캡슐' : '지금 열 수 있어요',
        style: const TextStyle(
          color: MapPage._mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xFFB7A59C),
      ),
      onTap: () {
        Navigator.of(sheetCtx).pop();
        _openCapsuleSheet(capsule);
      },
    );
  }

  static String _capsuleDesignLabel(String design) {
    switch (design) {
      case 'seoul':
        return '경복궁';
      case 'gyeongju':
        return '경주';
      default:
        return '기본';
    }
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

/// 클러스터링 대상 한 건(관광지 혹은 캡슐).
class _MapItem {
  const _MapItem._({required this.point, this.spot, this.capsule});

  factory _MapItem.spot(TouristSpot spot, LatLng point) =>
      _MapItem._(point: point, spot: spot);

  factory _MapItem.capsule(CapsuleMapMarker capsule, LatLng point) =>
      _MapItem._(point: point, capsule: capsule);

  final LatLng point;
  final TouristSpot? spot;
  final CapsuleMapMarker? capsule;
}

class _MarkerCluster {
  _MarkerCluster(this.items, this.center);

  final List<_MapItem> items;
  LatLng center;
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
/// scale 값은 핀이 캔버스의 ~25% 영역에 그려져있다고 가정한 값.
class _ScaledPinImage extends StatelessWidget {
  const _ScaledPinImage({required this.asset, required this.fallback});

  final String asset;
  final Widget fallback;

  static const double _scale = 4.0;

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
