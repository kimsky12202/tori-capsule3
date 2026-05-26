import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import '../services/capsule_notification_service.dart';
import '../services/push_notification_service.dart';
import '../services/settings_preferences.dart';
import 'friends_page.dart';
import 'login/login_page.dart';

enum _SettingsDetail { profile, friends, notifications, privacy, appInfo, help }

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  static const Color _backgroundColor = Color(0xFFFFF6E6);
  static const Color _brown = Color(0xFF765142);
  static const Color _darkText = Color(0xFF2E2B2A);
  static const Color _mutedText = Color(0xFF9A786A);
  static const Color _avatarFill = Color(0xFFFFC989);
  static const Color _chevronColor = Color(0xFFB7A59C);

  final AuthApi _authApi = AuthApi();
  String? _profileDisplayName;
  String _profileStatusMessage =
      SettingsPreferences.defaultProfileStatusMessage;
  NotificationSettings _notificationSettings = const NotificationSettings(
    pushEnabled: true,
    capsuleOpenEnabled: true,
    eventEnabled: false,
  );
  _SettingsDetail? _activeDetail;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _profileDisplayName = AuthApi.currentUsername;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final String statusMessage =
        await SettingsPreferences.getProfileStatusMessage();
    final NotificationSettings notificationSettings =
        await SettingsPreferences.getNotificationSettings();
    final String? displayName =
        AuthApi.currentUsername ?? await _authApi.refreshCurrentUsername();
    if (!mounted) {
      return;
    }

    setState(() {
      _profileStatusMessage = statusMessage;
      _notificationSettings = notificationSettings;
      if (displayName != null && displayName.isNotEmpty) {
        _profileDisplayName = displayName;
      }
    });
  }

  Future<void> _saveProfile({
    required String displayName,
    required String statusMessage,
  }) async {
    final String normalizedName = displayName.trim();
    final String normalizedStatus = statusMessage.trim();
    if (normalizedName.isEmpty) {
      _showSnackBar('닉네임을 입력해주세요.');
      return;
    }

    try {
      final String savedName = await _authApi.updateCurrentUserProfile(
        username: normalizedName,
      );
      await SettingsPreferences.setProfileStatusMessage(normalizedStatus);
      if (!mounted) {
        return;
      }

      setState(() {
        _profileDisplayName = savedName;
        _profileStatusMessage = normalizedStatus.isEmpty
            ? SettingsPreferences.defaultProfileStatusMessage
            : normalizedStatus;
      });
      _showSnackBar('프로필을 저장했습니다.');
    } on AuthApiException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('프로필 저장 중 오류가 발생했습니다.');
    }
  }

  Future<void> _togglePushNotification(bool enabled) async {
    await SettingsPreferences.setPushEnabled(enabled);
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationSettings = _notificationSettings.copyWith(
        pushEnabled: enabled,
      );
    });

    if (enabled) {
      await PushNotificationService.instance.syncTokenWithServer();
    } else {
      await PushNotificationService.instance.deactivateCurrentDeviceToken();
    }
  }

  Future<void> _toggleCapsuleOpenNotification(bool enabled) async {
    await SettingsPreferences.setCapsuleOpenAlertEnabled(enabled);
    if (!enabled) {
      await CapsuleNotificationService.cancelAllAlerts();
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationSettings = _notificationSettings.copyWith(
        capsuleOpenEnabled: enabled,
      );
    });
  }

  Future<void> _toggleEventNotification(bool enabled) async {
    await SettingsPreferences.setEventAlertEnabled(enabled);
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationSettings = _notificationSettings.copyWith(
        eventEnabled: enabled,
      );
    });
  }

  void _showDetail(_SettingsDetail detail) {
    setState(() {
      _activeDetail = detail;
    });
  }

  void _hideDetail() {
    setState(() {
      _activeDetail = null;
    });
  }

  void _showUnavailable(String featureName) {
    _showSnackBar('$featureName 기능은 아직 준비 중입니다.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) {
      return;
    }

    final bool shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('로그아웃'),
              content: const Text('이 기기에서 로그아웃할까요?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('로그아웃'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    await PushNotificationService.instance.deactivateCurrentDeviceToken();
    await AuthApi.clearSessionAndStorage();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (BuildContext context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _SettingsDetail? activeDetail = _activeDetail;
    if (activeDetail != null) {
      return _buildDetail(activeDetail);
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: ColoredBox(
        color: _backgroundColor,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: <Widget>[
            const _RoofAsset(),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 30, 34, 36),
              child: Column(
                children: <Widget>[
                  _ProfilePanel(
                    displayName:
                        _profileDisplayName ?? AuthApi.currentUsername ?? '사용자',
                    statusMessage: _profileStatusMessage,
                    onTap: () => _showDetail(_SettingsDetail.profile),
                  ),
                  const SizedBox(height: 36),
                  _SettingsMenu(
                    onFriendsTap: () => _showDetail(_SettingsDetail.friends),
                    onNotificationsTap: () =>
                        _showDetail(_SettingsDetail.notifications),
                    onPrivacyTap: () => _showDetail(_SettingsDetail.privacy),
                    onAppInfoTap: () => _showDetail(_SettingsDetail.appInfo),
                    onHelpTap: () => _showDetail(_SettingsDetail.help),
                  ),
                  const SizedBox(height: 38),
                  _LogoutPanel(
                    isLoggingOut: _isLoggingOut,
                    onTap: _isLoggingOut ? null : _handleLogout,
                  ),
                  const SizedBox(height: 44),
                  const Center(
                    child: Text(
                      'TORI CAPSULE v1.0.0',
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(_SettingsDetail detail) {
    switch (detail) {
      case _SettingsDetail.profile:
        return _ProfileSettingsDetail(
          displayName: _profileDisplayName ?? AuthApi.currentUsername ?? '',
          statusMessage: _profileStatusMessage,
          onBack: _hideDetail,
          onSave: _saveProfile,
          onImageTap: () => _showUnavailable('프로필 이미지 변경'),
        );
      case _SettingsDetail.friends:
        return FriendsPage(onBack: _hideDetail);
      case _SettingsDetail.notifications:
        return _NotificationSettingsDetail(
          settings: _notificationSettings,
          onBack: _hideDetail,
          onPushChanged: _togglePushNotification,
          onCapsuleOpenChanged: _toggleCapsuleOpenNotification,
          onEventChanged: _toggleEventNotification,
        );
      case _SettingsDetail.privacy:
        return _PrivacySettingsDetail(
          onBack: _hideDetail,
          onPasswordTap: () => _showUnavailable('비밀번호 변경'),
          onBlockedUsersTap: () => _showUnavailable('차단된 사용자 관리'),
          onDeleteAccountTap: () => _showUnavailable('회원 탈퇴'),
        );
      case _SettingsDetail.appInfo:
        return _AppInfoSettingsDetail(
          onBack: _hideDetail,
          onTermsTap: () => _showUnavailable('이용약관'),
          onPrivacyPolicyTap: () => _showUnavailable('개인정보 처리방침'),
        );
      case _SettingsDetail.help:
        return _HelpSettingsDetail(
          onBack: _hideDetail,
          onFaqTap: () => _showUnavailable('자주 묻는 질문'),
          onContactTap: () => _showUnavailable('1:1 문의하기'),
        );
    }
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.displayName,
    required this.statusMessage,
    required this.onTap,
  });

  final String displayName;
  final String statusMessage;
  final VoidCallback onTap;

  static const Color _brown = _SettingPageState._brown;
  static const Color _darkText = _SettingPageState._darkText;
  static const Color _mutedText = _SettingPageState._mutedText;
  static const Color _avatarFill = _SettingPageState._avatarFill;
  static const Color _chevronColor = _SettingPageState._chevronColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 126,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(color: Color(0x1A765142), offset: Offset(5, 5)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Row(
              children: <Widget>[
                Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    color: _avatarFill,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Color(0xFFFFD9A8),
                        offset: Offset(-5, -5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: _brown,
                    size: 44,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _darkText,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statusMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _mutedText,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _chevronColor, size: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu({
    required this.onFriendsTap,
    required this.onNotificationsTap,
    required this.onPrivacyTap,
    required this.onAppInfoTap,
    required this.onHelpTap,
  });

  final VoidCallback onFriendsTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onAppInfoTap;
  final VoidCallback onHelpTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          _SettingsMenuRow(
            icon: Icons.diversity_3_outlined,
            label: '친구 관리',
            onTap: onFriendsTap,
          ),
          const _SettingsDivider(),
          _SettingsMenuRow(
            icon: Icons.notifications_none,
            label: '알림 설정',
            onTap: onNotificationsTap,
          ),
          const _SettingsDivider(),
          _SettingsMenuRow(
            icon: Icons.lock_outline,
            label: '개인정보 설정',
            onTap: onPrivacyTap,
          ),
          const _SettingsDivider(),
          _SettingsMenuRow(
            icon: Icons.info_outline,
            label: '앱 정보',
            onTap: onAppInfoTap,
          ),
          const _SettingsDivider(),
          _SettingsMenuRow(
            icon: Icons.help_outline,
            label: '도움말',
            onTap: onHelpTap,
          ),
        ],
      ),
    );
  }
}

class _SettingsMenuRow extends StatelessWidget {
  const _SettingsMenuRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  static const Color _brown = _SettingPageState._brown;
  static const Color _darkText = _SettingPageState._darkText;
  static const Color _chevronColor = _SettingPageState._chevronColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: <Widget>[
                Icon(icon, color: _brown, size: 32),
                const SizedBox(width: 22),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: _chevronColor, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 4,
      child: ColoredBox(color: _SettingPageState._brown),
    );
  }
}

class _LogoutPanel extends StatelessWidget {
  const _LogoutPanel({required this.isLoggingOut, required this.onTap});

  final bool isLoggingOut;
  final VoidCallback? onTap;

  static const Color _brown = _SettingPageState._brown;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 70,
          child: Center(
            child: isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _brown,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.logout_rounded, color: _brown, size: 30),
                      SizedBox(width: 14),
                      Text(
                        '로그아웃',
                        style: TextStyle(
                          color: _brown,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDetailShell extends StatelessWidget {
  const _SettingsDetailShell({
    required this.onBack,
    required this.child,
    this.contentTopGap = 34,
  });

  final VoidCallback onBack;
  final Widget child;
  final double contentTopGap;

  static const Color _backgroundColor = _SettingPageState._backgroundColor;
  static const Color _darkText = _SettingPageState._darkText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: ColoredBox(
        color: _backgroundColor,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: <Widget>[
            const _RoofAsset(),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBack,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.chevron_left, color: _darkText, size: 32),
                        SizedBox(width: 2),
                        Text(
                          '뒤로',
                          style: TextStyle(
                            color: _darkText,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: contentTopGap),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoofAsset extends StatelessWidget {
  const _RoofAsset();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Image.asset(
        'assets/images/auth/asset.png',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    );
  }
}

class _SettingsDetailPanel extends StatelessWidget {
  const _SettingsDetailPanel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0x1A765142), offset: Offset(5, 5)),
        ],
      ),
      padding: padding ?? const EdgeInsets.fromLTRB(28, 30, 28, 30),
      child: child,
    );
  }
}

class _ProfileSettingsDetail extends StatefulWidget {
  const _ProfileSettingsDetail({
    required this.displayName,
    required this.statusMessage,
    required this.onBack,
    required this.onSave,
    required this.onImageTap,
  });

  final String displayName;
  final String statusMessage;
  final VoidCallback onBack;
  final Future<void> Function({
    required String displayName,
    required String statusMessage,
  })
  onSave;
  final VoidCallback onImageTap;

  @override
  State<_ProfileSettingsDetail> createState() => _ProfileSettingsDetailState();
}

class _ProfileSettingsDetailState extends State<_ProfileSettingsDetail> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _statusMessageController;
  bool _isSaving = false;

  static const Color _brown = _SettingPageState._brown;
  static const Color _avatarFill = _SettingPageState._avatarFill;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.displayName);
    _statusMessageController = TextEditingController(
      text: widget.statusMessage,
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _statusMessageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    await widget.onSave(
      displayName: _displayNameController.text,
      statusMessage: _statusMessageController.text,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: widget.onBack,
      contentTopGap: 32,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(32, 34, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('프로필 설정'),
            const SizedBox(height: 34),
            Center(
              child: Column(
                children: <Widget>[
                  Container(
                    width: 102,
                    height: 102,
                    decoration: const BoxDecoration(
                      color: _avatarFill,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0xFFFFD9A8),
                          offset: Offset(-5, -5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: _brown,
                      size: 58,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onImageTap,
                    child: const Text(
                      '이미지 변경',
                      style: TextStyle(
                        color: _brown,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            const _FieldLabel('닉네임'),
            const SizedBox(height: 12),
            _PixelTextField(controller: _displayNameController),
            const SizedBox(height: 28),
            const _FieldLabel('상태 메시지'),
            const SizedBox(height: 12),
            _PixelTextField(controller: _statusMessageController),
            const SizedBox(height: 42),
            _PixelActionButton(
              label: '저장하기',
              isLoading: _isSaving,
              onTap: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSettingsDetail extends StatelessWidget {
  const _NotificationSettingsDetail({
    required this.settings,
    required this.onBack,
    required this.onPushChanged,
    required this.onCapsuleOpenChanged,
    required this.onEventChanged,
  });

  final NotificationSettings settings;
  final VoidCallback onBack;
  final Future<void> Function(bool enabled) onPushChanged;
  final Future<void> Function(bool enabled) onCapsuleOpenChanged;
  final Future<void> Function(bool enabled) onEventChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: onBack,
      contentTopGap: 30,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('알림 설정'),
            const SizedBox(height: 22),
            _PixelCheckboxRow(
              label: '푸시 알림',
              value: settings.pushEnabled,
              onChanged: onPushChanged,
            ),
            const _ThickDivider(),
            _PixelCheckboxRow(
              label: '캡슐 개봉 알림',
              value: settings.capsuleOpenEnabled,
              onChanged: onCapsuleOpenChanged,
            ),
            const _ThickDivider(),
            _PixelCheckboxRow(
              label: '이벤트 알림',
              value: settings.eventEnabled,
              onChanged: onEventChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySettingsDetail extends StatelessWidget {
  const _PrivacySettingsDetail({
    required this.onBack,
    required this.onPasswordTap,
    required this.onBlockedUsersTap,
    required this.onDeleteAccountTap,
  });

  final VoidCallback onBack;
  final VoidCallback onPasswordTap;
  final VoidCallback onBlockedUsersTap;
  final VoidCallback onDeleteAccountTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: onBack,
      contentTopGap: 30,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('개인정보 설정'),
            const SizedBox(height: 24),
            _ThinSettingsRow(label: '비밀번호 변경', onTap: onPasswordTap),
            _ThinSettingsRow(label: '차단된 사용자 관리', onTap: onBlockedUsersTap),
            _ThinSettingsRow(
              label: '회원 탈퇴',
              onTap: onDeleteAccountTap,
              textColor: const Color(0xFF8E5555),
              showBottomLine: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppInfoSettingsDetail extends StatelessWidget {
  const _AppInfoSettingsDetail({
    required this.onBack,
    required this.onTermsTap,
    required this.onPrivacyPolicyTap,
  });

  final VoidCallback onBack;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyPolicyTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: onBack,
      contentTopGap: 30,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('앱 정보'),
            const SizedBox(height: 20),
            const _AppVersionRow(),
            const _ThickDivider(),
            _ChevronSettingsRow(label: '이용약관', onTap: onTermsTap),
            const _ThickDivider(),
            _ChevronSettingsRow(label: '개인정보 처리방침', onTap: onPrivacyPolicyTap),
          ],
        ),
      ),
    );
  }
}

class _HelpSettingsDetail extends StatelessWidget {
  const _HelpSettingsDetail({
    required this.onBack,
    required this.onFaqTap,
    required this.onContactTap,
  });

  final VoidCallback onBack;
  final VoidCallback onFaqTap;
  final VoidCallback onContactTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailShell(
      onBack: onBack,
      contentTopGap: 30,
      child: _SettingsDetailPanel(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DetailTitle('도움말'),
            const SizedBox(height: 20),
            _ThinSettingsRow(label: '자주 묻는 질문 (FAQ)', onTap: onFaqTap),
            _ThinSettingsRow(
              label: '1:1 문의하기',
              onTap: onContactTap,
              showBottomLine: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTitle extends StatelessWidget {
  const _DetailTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _SettingPageState._darkText,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PixelTextField extends StatelessWidget {
  const _PixelTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFD7C8BF), width: 1)),
      ),
      padding: const EdgeInsets.only(left: 16),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        maxLines: 1,
        style: const TextStyle(
          color: _SettingPageState._darkText,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

class _PixelActionButton extends StatelessWidget {
  const _PixelActionButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  static const Color _brown = _SettingPageState._brown;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          color: _brown,
          boxShadow: <BoxShadow>[
            BoxShadow(color: Color(0xFF5A372B), offset: Offset(5, 5)),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _PixelCheckboxRow extends StatelessWidget {
  const _PixelCheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Future<void> Function(bool enabled) onChanged;

  static const Color _brown = _SettingPageState._brown;
  static const Color _darkText = _SettingPageState._darkText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: SizedBox(
        height: 76,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _darkText,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: value ? _brown : Colors.white,
                border: Border.all(
                  color: value ? _brown : const Color(0xFF777777),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, color: Colors.white, size: 24)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinSettingsRow extends StatelessWidget {
  const _ThinSettingsRow({
    required this.label,
    required this.onTap,
    this.textColor = _SettingPageState._darkText,
    this.showBottomLine = true,
  });

  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final bool showBottomLine;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          border: showBottomLine
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFD7C8BF), width: 1),
                )
              : null,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ChevronSettingsRow extends StatelessWidget {
  const _ChevronSettingsRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9AA3AF), size: 30),
          ],
        ),
      ),
    );
  }
}

class _AppVersionRow extends StatelessWidget {
  const _AppVersionRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 58,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '버전',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            'v1.0.0 (최신)',
            style: TextStyle(
              color: _SettingPageState._darkText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThickDivider extends StatelessWidget {
  const _ThickDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 4,
      child: ColoredBox(color: _SettingPageState._brown),
    );
  }
}
