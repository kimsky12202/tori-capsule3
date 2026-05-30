import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/capsule_api.dart';

class CapsuleDetailPage extends StatefulWidget {
  const CapsuleDetailPage({super.key, required this.capsule});

  final CapsuleListItem capsule;

  @override
  State<CapsuleDetailPage> createState() => _CapsuleDetailPageState();
}

class _CapsuleDetailPageState extends State<CapsuleDetailPage> {
  static const Color _backgroundColor = Color(0xFFFFF6E6);
  static const Color _brown = Color(0xFF765142);
  static const Color _darkText = Color(0xFF2E2B2A);
  static const Color _bodyText = Color(0xFF334155);
  static const Color _mutedText = Color(0xFF9A786A);
  static const Color _accentColor = Color(0xFFFFB36B);
  static const Color _groupColor = Color(0xFF7EA9D6);
  static const Color _panelShadowColor = Color(0x1A765142);
  static const Color _deleteColor = Color(0xFFB23A3A);

  final CapsuleApi _capsuleApi = CapsuleApi();
  late Future<CapsuleDetail> _futureCapsule;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _futureCapsule = _capsuleApi.getCapsule(capsuleId: widget.capsule.id);
  }

  Future<void> _refreshCapsule() async {
    final future = _capsuleApi.getCapsule(capsuleId: widget.capsule.id);
    setState(() {
      _futureCapsule = future;
    });
    await future;
  }

  Future<void> _confirmAndDelete() async {
    if (_isDeleting) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('캡슐 삭제'),
        content: const Text('이 캡슐을 정말 삭제하시겠어요? 사진, 영상, 음악이 모두 사라지고 되돌릴 수 없어요.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: _deleteColor),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final bool ok = await _capsuleApi.deleteCapsule(capsuleId: widget.capsule.id);
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('캡슐을 삭제하지 못했어요.')));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('캡슐을 삭제했어요.')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: ColoredBox(
        color: _backgroundColor,
        child: FutureBuilder<CapsuleDetail>(
          future: _futureCapsule,
          builder:
              (BuildContext context, AsyncSnapshot<CapsuleDetail> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return _buildErrorState(snapshot.error);
                }

                return _buildDetail(snapshot.data!);
              },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: EdgeInsets.zero,
      children: const <Widget>[
        _RoofAsset(),
        SizedBox(height: 130),
        Center(child: CircularProgressIndicator(color: _brown)),
      ],
    );
  }

  Widget _buildErrorState(Object? error) {
    final message = error is CapsuleApiException
        ? error.message
        : '캡슐 내용을 불러올 수 없습니다.';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: <Widget>[
        const _RoofAsset(),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 30, 30, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildBackButton(),
              const SizedBox(height: 30),
              _PixelPanel(
                child: Column(
                  children: <Widget>[
                    const Icon(Icons.lock_outline, color: _brown, size: 46),
                    const SizedBox(height: 18),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _darkText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _PixelActionButton(
                      label: '다시 불러오기',
                      onTap: _refreshCapsule,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetail(CapsuleDetail capsule) {
    return RefreshIndicator(
      onRefresh: _refreshCapsule,
      color: _brown,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: <Widget>[
          const _RoofAsset(),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildBackButton(),
                const SizedBox(height: 30),
                _PixelPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _CapsuleHeader(capsule: capsule),
                      const SizedBox(height: 26),
                      _MemoSection(memo: capsule.memo),
                      const SizedBox(height: 24),
                      _PhotoSection(photoUrls: capsule.photoUrls),
                      const SizedBox(height: 24),
                      _FileSection(
                        icon: Icons.movie_outlined,
                        title: '동영상',
                        emptyText: '담긴 동영상이 없습니다.',
                        urls: capsule.videoUrls,
                        buttonLabel: '영상 열기',
                      ),
                      const SizedBox(height: 24),
                      _MusicSection(capsule: capsule),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Row(
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
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
        const Spacer(),
        _DeleteButton(
          onTap: _confirmAndDelete,
          isLoading: _isDeleting,
        ),
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap, required this.isLoading});

  final VoidCallback onTap;
  final bool isLoading;

  static const Color _deleteColor = _CapsuleDetailPageState._deleteColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _deleteColor, width: 2),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _deleteColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Icon(Icons.delete_outline, color: _deleteColor, size: 18),
                  SizedBox(width: 6),
                  Text(
                    '삭제',
                    style: TextStyle(
                      color: _deleteColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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

class _PixelPanel extends StatelessWidget {
  const _PixelPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _CapsuleDetailPageState._panelShadowColor,
            offset: Offset(5, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
      child: child,
    );
  }
}

class _CapsuleHeader extends StatelessWidget {
  const _CapsuleHeader({required this.capsule});

  final CapsuleDetail capsule;

  static const Color _darkText = _CapsuleDetailPageState._darkText;
  static const Color _bodyText = _CapsuleDetailPageState._bodyText;
  static const Color _accentColor = _CapsuleDetailPageState._accentColor;
  static const Color _groupColor = _CapsuleDetailPageState._groupColor;

  @override
  Widget build(BuildContext context) {
    final Color color = capsule.isGroupCapsule ? _groupColor : _accentColor;
    final String title = capsule.isGroupCapsule ? '그룹 캡슐' : '일반 캡슐';
    final String emotion = capsule.emotion.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          color: color.withValues(alpha: 0.2),
          child: Icon(
            capsule.isGroupCapsule
                ? Icons.diversity_3_outlined
                : Icons.inventory_2_outlined,
            color: color,
            size: 38,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _darkText,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    color: color.withValues(alpha: 0.16),
                    child: Text(
                      '열림',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '작성일 ${_formatDate(capsule.created)}',
                style: const TextStyle(
                  color: _bodyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (emotion.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _MiniChip(label: emotion),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MemoSection extends StatelessWidget {
  const _MemoSection({required this.memo});

  final String memo;

  static const Color _brown = _CapsuleDetailPageState._brown;
  static const Color _bodyText = _CapsuleDetailPageState._bodyText;
  static const Color _mutedText = _CapsuleDetailPageState._mutedText;

  @override
  Widget build(BuildContext context) {
    final String content = memo.trim();

    return _SectionBlock(
      icon: Icons.chat_bubble_outline,
      title: '코멘트',
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 116),
        decoration: BoxDecoration(
          color: const Color(0xFFF4FAFF),
          border: Border.all(color: _brown, width: 3),
        ),
        padding: const EdgeInsets.all(18),
        child: Text(
          content.isEmpty ? '남겨진 코멘트가 없습니다.' : content,
          style: TextStyle(
            color: content.isEmpty ? _mutedText : _bodyText,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.photoUrls});

  final List<String> photoUrls;

  static const Color _mutedText = _CapsuleDetailPageState._mutedText;

  @override
  Widget build(BuildContext context) {
    return _SectionBlock(
      icon: Icons.photo_outlined,
      title: '사진',
      child: photoUrls.isEmpty
          ? const _EmptySectionText('담긴 사진이 없습니다.')
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photoUrls.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (BuildContext context, int index) {
                final String url = photoUrls[index];

                return GestureDetector(
                  onTap: () => _openUrl(url),
                  child: Container(
                    color: const Color(0xFFF4FAFF),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: _mutedText,
                              size: 34,
                            ),
                          ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _FileSection extends StatelessWidget {
  const _FileSection({
    required this.icon,
    required this.title,
    required this.emptyText,
    required this.urls,
    required this.buttonLabel,
  });

  final IconData icon;
  final String title;
  final String emptyText;
  final List<String> urls;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return _SectionBlock(
      icon: icon,
      title: title,
      child: urls.isEmpty
          ? _EmptySectionText(emptyText)
          : Column(
              children: <Widget>[
                for (int index = 0; index < urls.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == urls.length - 1 ? 0 : 10,
                    ),
                    child: _FileRow(
                      title: '$title ${index + 1}',
                      buttonLabel: buttonLabel,
                      url: urls[index],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MusicSection extends StatelessWidget {
  const _MusicSection({required this.capsule});

  final CapsuleDetail capsule;

  @override
  Widget build(BuildContext context) {
    final String? musicUrl = capsule.musicUrl;
    final String title = capsule.musicTitle.trim().isEmpty
        ? '음악 파일'
        : capsule.musicTitle.trim();
    final String artist = capsule.musicArtist.trim();

    return _SectionBlock(
      icon: Icons.music_note_outlined,
      title: '음악',
      child: musicUrl == null
          ? const _EmptySectionText('담긴 음악이 없습니다.')
          : _FileRow(
              title: artist.isEmpty ? title : '$title - $artist',
              buttonLabel: '음악 열기',
              url: musicUrl,
            ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  static const Color _brown = _CapsuleDetailPageState._brown;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, color: _brown, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: _brown,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.title,
    required this.buttonLabel,
    required this.url,
  });

  final String title;
  final String buttonLabel;
  final String url;

  static const Color _darkText = _CapsuleDetailPageState._darkText;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFCF6),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _darkText,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _PixelActionButton(label: buttonLabel, onTap: () => _openUrl(url)),
        ],
      ),
    );
  }
}

class _PixelActionButton extends StatelessWidget {
  const _PixelActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const Color _brown = _CapsuleDetailPageState._brown;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: _brown,
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFFF7F1E8),
      child: Text(
        label,
        style: const TextStyle(
          color: _CapsuleDetailPageState._brown,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptySectionText extends StatelessWidget {
  const _EmptySectionText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _CapsuleDetailPageState._mutedText,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return '날짜 없음';
  }

  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day';
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }

  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
