import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/friend_api.dart';

const String kCapsuleOpenOptionAnytime = 'anytime';
const String kCapsuleOpenOptionDaysLater = 'days_later';
const String kCapsuleOpenOptionNextYearSameTime = 'next_year_same_time';

class CapsuleData {
  final String? memo;
  final String? emotion;
  final List<XFile> photos;
  final List<XFile> videos;
  final String? musicTitle;
  final String? musicArtist;
  final XFile? musicFile;
  final List<String> friendIds;
  final String openOption;
  final int? openAfterDays;

  const CapsuleData({
    this.memo,
    this.emotion,
    this.photos = const [],
    this.videos = const [],
    this.musicTitle,
    this.musicArtist,
    this.musicFile,
    this.friendIds = const [],
    this.openOption = kCapsuleOpenOptionAnytime,
    this.openAfterDays,
  });

  DateTime? calculateOpenAtUtc({DateTime? now}) {
    final baseNow = (now ?? DateTime.now()).toUtc();
    switch (openOption) {
      case kCapsuleOpenOptionDaysLater:
        final days = openAfterDays ?? 0;
        if (days <= 0) return null;
        return baseNow.add(Duration(days: days));
      case kCapsuleOpenOptionNextYearSameTime:
        return DateTime.utc(
          baseNow.year + 1,
          baseNow.month,
          baseNow.day,
          baseNow.hour,
          baseNow.minute,
          baseNow.second,
          baseNow.millisecond,
          baseNow.microsecond,
        );
      case kCapsuleOpenOptionAnytime:
      default:
        return null;
    }
  }

  bool get shouldScheduleOpenAlert => openOption != kCapsuleOpenOptionAnytime;
}

class CapsuleTypeSelectionSheet extends StatelessWidget {
  const CapsuleTypeSelectionSheet({super.key});

  static const Color _brown = Color(0xFF765142);
  static const Color _cream = Color(0xFFFFF6E6);
  static const Color _groupFill = Color(0xFFD9F7E0);
  static const Color _darkText = Color(0xFF2E2B2A);
  static const Color _bodyText = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 1,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: const Color(0x99000000),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _brown, width: 4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: 82,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: _brown, width: 4),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Spacer(),
                          const Text(
                            '새 캡슐',
                            style: TextStyle(
                              color: _darkText,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(right: 22),
                            child: _PixelCloseButton(
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(34, 34, 34, 36),
                    child: Column(
                      children: <Widget>[
                        _CapsuleTypeCard(
                          icon: Icons.person_outline,
                          iconColor: Color(0xFF0B73D9),
                          title: '일반 캡슐',
                          subtitle: '혼자서 소중한 추억을',
                          backgroundColor: _cream,
                          onTap: () => Navigator.pop(context, false),
                        ),
                        const SizedBox(height: 24),
                        _CapsuleTypeCard(
                          icon: Icons.diversity_3_outlined,
                          iconColor: Color(0xFF93612F),
                          title: '그룹 캡슐',
                          subtitle: '친구들과 함께 추억을',
                          backgroundColor: _groupFill,
                          onTap: () => Navigator.pop(context, true),
                        ),
                      ],
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

class _PixelCloseButton extends StatelessWidget {
  const _PixelCloseButton({required this.onTap});

  final VoidCallback onTap;

  static const Color _brown = CapsuleTypeSelectionSheet._brown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: _brown, width: 3),
        ),
        child: InkWell(
          onTap: onTap,
          child: const Icon(Icons.close, color: Color(0xFF4B5563), size: 25),
        ),
      ),
    );
  }
}

class _CapsuleTypeCard extends StatelessWidget {
  const _CapsuleTypeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final VoidCallback onTap;

  static const Color _brown = CapsuleTypeSelectionSheet._brown;
  static const Color _darkText = CapsuleTypeSelectionSheet._darkText;
  static const Color _bodyText = CapsuleTypeSelectionSheet._bodyText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 210,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: _brown, width: 4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _brown, width: 4),
                ),
                child: Icon(icon, color: iconColor, size: 50),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: _darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _bodyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CapsuleContentSheet extends StatefulWidget {
  final void Function(CapsuleData data) onConfirm;
  final bool isGroupCapsule;

  const CapsuleContentSheet({
    super.key,
    required this.onConfirm,
    this.isGroupCapsule = false,
  });

  @override
  State<CapsuleContentSheet> createState() => _CapsuleContentSheetState();
}

class _CapsuleContentSheetState extends State<CapsuleContentSheet> {
  static const Color _backgroundColor = Color(0xFFFFF6E6);
  static const Color _brown = Color(0xFF765142);
  static const Color _darkText = Color(0xFF2E2B2A);
  static const Color _bodyText = Color(0xFF334155);
  static const Color _mutedText = Color(0xFFB7A59C);
  static const Color _fieldFill = Color(0xFFF2FAFF);
  static const Color _groupFill = Color(0xFFD9F7E0);

  final _memoController = TextEditingController();
  final _picker = ImagePicker();
  final _friendApi = FriendApi();

  String? _selectedEmotion;
  List<XFile> _photos = [];
  bool _isLoadingFriends = false;
  String? _friendsError;
  List<FriendListItem> _friends = const <FriendListItem>[];
  final Set<String> _selectedFriendIds = <String>{};

  // 잠금 설정 (선택). 기본은 잠금 없음(anytime).
  bool _lockEnabled = false;
  final TextEditingController _openDaysController =
      TextEditingController(text: '30');

  static const List<String> _emotions = <String>['😊', '😢', '😍', '😡', '😎'];

  @override
  void initState() {
    super.initState();
    if (widget.isGroupCapsule) {
      _loadFriends();
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    _openDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (_isLoadingFriends) return;
    setState(() {
      _isLoadingFriends = true;
      _friendsError = null;
    });

    try {
      final friends = await _friendApi.listFriends(limit: 100);
      if (!mounted) return;
      setState(() => _friends = friends);
    } on FriendApiException catch (e) {
      if (!mounted) return;
      setState(() => _friendsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _friendsError = '친구 목록을 불러오지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingFriends = false);
      }
    }
  }

  void _toggleFriendSelection(String friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _photos = picked.take(5).toList());
    }
  }

  void _submitCapsule() {
    if (widget.isGroupCapsule && _selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('함께 묻을 친구를 선택해주세요.')));
      return;
    }

    // 잠금 설정 처리: 스위치 켜져있고 일수가 1 이상이면 days_later, 아니면 anytime.
    final int lockDays =
        _lockEnabled ? (int.tryParse(_openDaysController.text.trim()) ?? 0) : 0;
    final String openOption = lockDays > 0
        ? kCapsuleOpenOptionDaysLater
        : kCapsuleOpenOptionAnytime;
    final int? openAfterDays = lockDays > 0 ? lockDays : null;

    Navigator.pop(context);
    widget.onConfirm(
      CapsuleData(
        memo: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
        emotion: _selectedEmotion,
        photos: _photos,
        friendIds: widget.isGroupCapsule
            ? _selectedFriendIds.toList(growable: false)
            : const <String>[],
        openOption: openOption,
        openAfterDays: openAfterDays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: _backgroundColor,
        child: Column(
          children: <Widget>[
            Container(height: 6, color: _brown),
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 14),
                width: 72,
                height: 8,
                color: const Color(0xFFE0D7C9),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildHeader(),
                    const SizedBox(height: 34),
                    _buildFormPanel(),
                    const SizedBox(height: 30),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            widget.isGroupCapsule ? '그룹캡슐 작성' : '타임캡슐 작성',
            style: const TextStyle(
              color: _brown,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {},
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: _brown, width: 3),
              ),
              child: const Text(
                '추억 기록',
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _brown, width: 5),
      ),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildPhotoPicker(),
          const SizedBox(height: 28),
          _buildSectionTitle(Icons.comment_outlined, '코멘트 작성'),
          const SizedBox(height: 18),
          _buildMemoField(),
          const SizedBox(height: 30),
          _buildSectionTitle(Icons.sentiment_satisfied_alt_outlined, '감정상태 등록'),
          const SizedBox(height: 18),
          _buildEmotionSection(),
          const SizedBox(height: 30),
          _buildSectionTitle(Icons.lock_clock_outlined, '잠금 설정 (선택)'),
          const SizedBox(height: 18),
          _buildLockSection(),
          if (widget.isGroupCapsule) ...<Widget>[
            const SizedBox(height: 30),
            _buildSectionTitle(Icons.diversity_3_outlined, '친구 선택'),
            const SizedBox(height: 18),
            _buildFriendSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickPhotos,
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: _brown,
          strokeWidth: 4,
          gap: 8,
        ),
        child: Container(
          height: 176,
          width: double.infinity,
          color: _fieldFill,
          alignment: Alignment.center,
          child: _photos.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _brown, width: 3),
                      ),
                      child: const Icon(Icons.add, color: _brown, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '터치하여 선택',
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  itemCount: _photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return AspectRatio(
                      aspectRatio: 1,
                      child: Image.file(
                        File(_photos[index].path),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String label) {
    return Row(
      children: <Widget>[
        Icon(icon, color: _brown, size: 30),
        const SizedBox(width: 14),
        Text(
          label,
          style: const TextStyle(
            color: _brown,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildMemoField() {
    return TextField(
      controller: _memoController,
      maxLines: 5,
      style: const TextStyle(
        color: _darkText,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: '추억을 남겨주세요...',
        hintStyle: const TextStyle(
          color: _mutedText,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: _fieldFill,
        contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: _brown, width: 4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: _brown, width: 4),
        ),
      ),
    );
  }

  Widget _buildEmotionSection() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _emotions.map((emotion) {
        final isSelected = _selectedEmotion == emotion;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedEmotion = isSelected ? null : emotion;
            });
          },
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFE2B8) : Colors.white,
              border: Border.all(color: _brown, width: isSelected ? 5 : 4),
            ),
            child: Text(emotion, style: const TextStyle(fontSize: 28)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '잠그면 정해진 일수 후에만 캡슐을 열 수 있어요.\n잠그지 않으면 언제든지 열 수 있어요.',
          style: TextStyle(color: _mutedText, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _lockEnabled,
          onChanged: (bool value) => setState(() => _lockEnabled = value),
          activeColor: _brown,
          title: Text(
            _lockEnabled ? '잠금 사용 중' : '잠금 없음 (언제든지 열람)',
            style: const TextStyle(
              color: _darkText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_lockEnabled) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Text(
                '며칠 후 개봉:',
                style: TextStyle(
                  color: _darkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _openDaysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _brown, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _brown, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _brown, width: 3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '일',
                style: TextStyle(
                  color: _darkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '예: 30 -> 30일 뒤에 열림 / 365 -> 1년 뒤에 열림',
            style: TextStyle(color: _mutedText, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildFriendSection() {
    if (_isLoadingFriends) {
      return const Center(child: CircularProgressIndicator(color: _brown));
    }

    if (_friendsError != null) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _friendsError!,
              style: const TextStyle(
                color: _bodyText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(onPressed: _loadFriends, child: const Text('다시 시도')),
        ],
      );
    }

    if (_friends.isEmpty) {
      return const Text(
        '추가된 친구가 없습니다. 친구를 먼저 추가해주세요.',
        style: TextStyle(color: _bodyText, fontWeight: FontWeight.w700),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _friends.map((friend) {
        final isSelected = _selectedFriendIds.contains(friend.id);
        return FilterChip(
          selected: isSelected,
          label: Text(friend.displayName),
          onSelected: (_) => _toggleFriendSelection(friend.id),
          selectedColor: _groupFill,
          backgroundColor: Colors.white,
          checkmarkColor: _brown,
          side: const BorderSide(color: _brown, width: 2),
          labelStyle: const TextStyle(
            color: _brown,
            fontWeight: FontWeight.w800,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 78,
      child: Material(
        color: _brown,
        child: InkWell(
          onTap: _submitCapsule,
          child: const Center(
            child: Text(
              '캡슐 묻기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
  });

  final Color color;
  final double strokeWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()..addRect(Offset.zero & size);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + gap;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += gap * 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        gap != oldDelegate.gap;
  }
}
