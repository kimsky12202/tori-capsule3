import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/capsule_api.dart';
import '../services/capsule_notification_service.dart';
import '../services/settings_preferences.dart';
import 'capsule/capsule_content_sheet.dart';
import 'challenge_tab_page.dart';
import 'map_page.dart';
import 'setting_page.dart';
import 'timecapsule_page.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 4;

  static const IconData _mapIcon = Icons.map_outlined;
  static const IconData _timecapsuleIcon = Icons.medication_outlined;
  static const IconData _challengeIcon = Icons.emoji_events_outlined;
  static const IconData _settingsIcon = Icons.settings_outlined;

  static const ScrollPhysics _tabBarPhysics = NeverScrollableScrollPhysics();

  static const Color _pageBackgroundColor = Color(0xFFF4F1EA);
  static const Color _primaryColor = Color(0xFFA14040);
  static const Color _navBarColor = Color(0xFF765142);
  static const Color _navSelectedColor = Color(0xFF9B642D);
  static const Color _navUnselectedColor = Color(0xFFD7C8BF);
  static const Color _navPlusColor = Color(0xFF6F4B3E);

  late final TabController _controller;
  final CapsuleApi _capsuleApi = CapsuleApi();
  // 지도 페이지를 외부에서 새로고침하기 위한 키 (캡슐 생성 후 등)
  final GlobalKey<MapPageState> _mapPageKey = GlobalKey<MapPageState>();
  // 캡슐 탭(2.5D 룸)에서 등록 애니메이션을 외부에서 트리거하기 위한 키
  final GlobalKey<TimecapsulePageState> _capsulePageKey =
      GlobalKey<TimecapsulePageState>();
  int _selectedIndex = 0;
  bool _isCreatingCapsule = false;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: _selectedIndex,
    );
    _controller.addListener(_syncSelectedIndex);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncSelectedIndex);
    _controller.dispose();
    super.dispose();
  }

  void _syncSelectedIndex() {
    if (_selectedIndex == _controller.index) {
      return;
    }
    setState(() {
      _selectedIndex = _controller.index;
    });
  }

  void _selectTab(int index) {
    if (_controller.index == index) {
      return;
    }
    _controller.animateTo(index);
  }

  Future<(double, double)?> _captureGPS() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return (position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _createCapsuleDirectly(CapsuleData data) async {
    if (_isCreatingCapsule) {
      return;
    }
    setState(() {
      _isCreatingCapsule = true;
    });

    final coords = await _captureGPS();
    final double latitude = coords?.$1 ?? 0;
    final double longitude = coords?.$2 ?? 0;

    final String? capsuleId = await _capsuleApi.createCapsule(
      data: data,
      latitude: latitude,
      longitude: longitude,
      design: data.design,
      memberIds: data.friendIds,
    );

    bool isBuried = false;
    if (capsuleId != null) {
      isBuried = await _capsuleApi.buryCapsule(capsuleId: capsuleId);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isCreatingCapsule = false;
    });

    if (capsuleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('캡슐 생성에 실패했습니다.')));
      return;
    }

    if (!isBuried) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('캡슐은 생성됐지만 묻기 처리에 실패했습니다.')));
      return;
    }

    await _scheduleCapsuleOpeningAlertIfNeeded(capsuleId, data);
    if (!mounted) {
      return;
    }

    // 지도에 방금 묻은 캡슐 마커가 바로 보이도록 새로고침
    _mapPageKey.currentState?.refresh();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('캡슐이 추가되었습니다.')));

    // 캡슐 탭(2.5D 룸)으로 이동해서 등록 애니메이션을 보여준다.
    _selectTab(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capsulePageKey.currentState?.playRegisterAnimation(
        capsuleId: capsuleId,
        design: data.design,
      );
    });
  }

  Future<void> _scheduleCapsuleOpeningAlertIfNeeded(
    String capsuleId,
    CapsuleData data,
  ) async {
    final bool alertEnabled =
        await SettingsPreferences.getCapsuleOpenAlertEnabled();
    final DateTime? openAtUtc = data.calculateOpenAtUtc();
    if (!alertEnabled || !data.shouldScheduleOpenAlert || openAtUtc == null) {
      return;
    }

    await CapsuleNotificationService.scheduleCapsuleOpeningAlert(
      capsuleId: capsuleId,
      openAtUtc: openAtUtc,
      isGroupCapsule: data.friendIds.isNotEmpty,
    );
  }

  Future<void> _showCapsuleCreateSheet() async {
    if (_isCreatingCapsule) {
      return;
    }

    final bool? isGroupCapsule = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CapsuleTypeSelectionSheet(),
    );

    if (!mounted || isGroupCapsule == null || _isCreatingCapsule) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, sheetController) => PrimaryScrollController(
          controller: sheetController,
          child: CapsuleContentSheet(
            isGroupCapsule: isGroupCapsule,
            onConfirm: _createCapsuleDirectly,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _pageBackgroundColor,
        body: _buildTabBarView(),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      physics: _tabBarPhysics,
      controller: _controller,
      children: <Widget>[
        MapPage(key: _mapPageKey),
        TimecapsulePage(key: _capsulePageKey),
        const ChallengeTabPage(),
        const SettingPage(),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return ColoredBox(
      color: _pageBackgroundColor,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Container(
          height: 86,
          decoration: BoxDecoration(
            color: _navBarColor,
            border: const Border(
              top: BorderSide(color: Color(0xFF5A372B), width: 3),
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(28),
            ),
          ),
          child: Row(
            children: <Widget>[
              _BottomNavItem(
                icon: _mapIcon,
                label: '지도',
                isSelected: _selectedIndex == 0,
                onTap: () => _selectTab(0),
              ),
              _BottomNavItem(
                icon: _timecapsuleIcon,
                label: '캡슐',
                isSelected: _selectedIndex == 1,
                onTap: () => _selectTab(1),
              ),
              _CapsuleCreateNavButton(
                isLoading: _isCreatingCapsule,
                onTap: _showCapsuleCreateSheet,
              ),
              _BottomNavItem(
                icon: _challengeIcon,
                label: '챌린지',
                isSelected: _selectedIndex == 2,
                onTap: () => _selectTab(2),
              ),
              _BottomNavItem(
                icon: _settingsIcon,
                label: '설정',
                isSelected: _selectedIndex == 3,
                onTap: () => _selectTab(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  static const Color _selectedColor = _MainTabPageState._navSelectedColor;
  static const Color _unselectedColor = _MainTabPageState._navUnselectedColor;

  @override
  Widget build(BuildContext context) {
    final Color contentColor = isSelected ? Colors.white : _unselectedColor;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
        child: Material(
          color: isSelected ? _selectedColor : Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.zero,
            child: SizedBox(
              height: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, color: contentColor, size: 26),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: contentColor,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleCreateNavButton extends StatelessWidget {
  const _CapsuleCreateNavButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  static const Color _plusColor = _MainTabPageState._navPlusColor;
  static const Color _primaryColor = _MainTabPageState._primaryColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Semantics(
          button: true,
          label: '캡슐 만들기',
          child: Transform.translate(
            offset: const Offset(0, -8),
            child: SizedBox(
              width: 62,
              height: 62,
              child: Material(
                color: Colors.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                  side: BorderSide(color: Color(0xFFF4F1EA), width: 2),
                ),
                child: InkWell(
                  onTap: isLoading ? null : onTap,
                  borderRadius: BorderRadius.circular(2),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _primaryColor,
                            ),
                          )
                        : const Icon(Icons.add, color: _plusColor, size: 34),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
