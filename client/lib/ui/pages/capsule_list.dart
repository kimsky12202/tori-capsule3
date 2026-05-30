import 'package:flutter/material.dart';

import '../services/capsule_api.dart';
import 'capsule_detail_page.dart';

enum _CapsuleListFilter { all, normal, group }

class CapsuleListPage extends StatefulWidget {
  const CapsuleListPage({super.key});

  @override
  State<CapsuleListPage> createState() => _CapsuleListPageState();
}

class _CapsuleListPageState extends State<CapsuleListPage> {
  static const Color _backgroundColor = Color(0xFFFFF6E6);
  static const Color _brown = Color(0xFF765142);
  static const Color _darkText = Color(0xFF2E2B2A);
  static const Color _mutedText = Color(0xFF9A786A);
  static const Color _accentColor = Color(0xFFFFB36B);
  static const Color _groupColor = Color(0xFF7EA9D6);
  static const Color _panelShadowColor = Color(0x1A765142);

  final CapsuleApi _capsuleApi = CapsuleApi();
  late Future<List<CapsuleListItem>> _futureCapsules;
  _CapsuleListFilter _selectedFilter = _CapsuleListFilter.all;

  @override
  void initState() {
    super.initState();
    _futureCapsules = _capsuleApi.listCapsules();
  }

  Future<void> _refreshCapsules() async {
    final future = _capsuleApi.listCapsules();
    setState(() {
      _futureCapsules = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: ColoredBox(
        color: _backgroundColor,
        child: FutureBuilder<List<CapsuleListItem>>(
          future: _futureCapsules,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<CapsuleListItem>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                final capsules = snapshot.data ?? const <CapsuleListItem>[];
                return _buildList(capsules);
              },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: const <Widget>[
        _RoofAsset(),
        SizedBox(height: 130),
        Center(child: CircularProgressIndicator(color: _brown)),
      ],
    );
  }

  Widget _buildList(List<CapsuleListItem> capsules) {
    final filteredCapsules = _filteredCapsules(capsules);
    final normalCount = capsules
        .where((CapsuleListItem capsule) => !capsule.isGroupCapsule)
        .length;
    final groupCount = capsules
        .where((CapsuleListItem capsule) => capsule.isGroupCapsule)
        .length;

    return RefreshIndicator(
      onRefresh: _refreshCapsules,
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
                _buildPanel(
                  capsules: filteredCapsules,
                  totalCount: capsules.length,
                  normalCount: normalCount,
                  groupCount: groupCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
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
    );
  }

  Widget _buildPanel({
    required List<CapsuleListItem> capsules,
    required int totalCount,
    required int normalCount,
    required int groupCount,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(color: _panelShadowColor, offset: Offset(5, 5)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '캡슐 목록',
            style: TextStyle(
              color: _brown,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              _FilterButton(
                label: '전체',
                count: totalCount,
                isSelected: _selectedFilter == _CapsuleListFilter.all,
                onTap: () => _setFilter(_CapsuleListFilter.all),
              ),
              const SizedBox(width: 10),
              _FilterButton(
                label: '일반',
                count: normalCount,
                isSelected: _selectedFilter == _CapsuleListFilter.normal,
                onTap: () => _setFilter(_CapsuleListFilter.normal),
              ),
              const SizedBox(width: 10),
              _FilterButton(
                label: '그룹',
                count: groupCount,
                isSelected: _selectedFilter == _CapsuleListFilter.group,
                selectedColor: _groupColor,
                onTap: () => _setFilter(_CapsuleListFilter.group),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (capsules.isEmpty)
            const _EmptyCapsules()
          else
            ...capsules.map(
              (CapsuleListItem capsule) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _CapsuleListCard(
                  capsule: capsule,
                  onTap: () => _openCapsule(capsule),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _setFilter(_CapsuleListFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  Future<void> _openCapsule(CapsuleListItem capsule) async {
    if (!capsule.canOpenNow) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('아직 열 수 없는 캡슐입니다.')));
      return;
    }

    final bool? deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => CapsuleDetailPage(capsule: capsule),
      ),
    );
    if (deleted == true && mounted) {
      await _refreshCapsules();
    }
  }

  List<CapsuleListItem> _filteredCapsules(List<CapsuleListItem> capsules) {
    switch (_selectedFilter) {
      case _CapsuleListFilter.all:
        return capsules;
      case _CapsuleListFilter.normal:
        return capsules
            .where((CapsuleListItem capsule) => !capsule.isGroupCapsule)
            .toList();
      case _CapsuleListFilter.group:
        return capsules
            .where((CapsuleListItem capsule) => capsule.isGroupCapsule)
            .toList();
    }
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.selectedColor = _CapsuleListPageState._accentColor,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          color: isSelected
              ? selectedColor.withValues(alpha: 0.18)
              : const Color(0xFFF7F7F2),
          alignment: Alignment.center,
          child: Text(
            '$label ($count)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected
                  ? selectedColor
                  : _CapsuleListPageState._mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleListCard extends StatelessWidget {
  const _CapsuleListCard({required this.capsule, required this.onTap});

  final CapsuleListItem capsule;
  final VoidCallback onTap;

  static const Color _darkText = _CapsuleListPageState._darkText;
  static const Color _mutedText = _CapsuleListPageState._mutedText;
  static const Color _accentColor = _CapsuleListPageState._accentColor;
  static const Color _groupColor = _CapsuleListPageState._groupColor;

  @override
  Widget build(BuildContext context) {
    final color = capsule.isGroupCapsule ? _groupColor : _accentColor;

    return Material(
      color: const Color(0xFFFFFCF6),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 118),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color.withValues(alpha: 0.35), width: 2),
              left: BorderSide(color: color.withValues(alpha: 0.35), width: 2),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                color: color.withValues(alpha: 0.2),
                child: Icon(
                  capsule.isGroupCapsule
                      ? Icons.diversity_3_outlined
                      : Icons.inventory_2_outlined,
                  color: color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            capsule.isGroupCapsule ? '그룹 캡슐' : '일반 캡슐',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _darkText,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _CapsuleStatusBadge(capsule: capsule),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _capsuleDescription(capsule),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: <Widget>[
                        _MiniMeta(label: _formatDate(capsule.created)),
                        _MiniMeta(label: _openLabel(capsule)),
                        if (capsule.emotion.trim().isNotEmpty)
                          _MiniMeta(label: capsule.emotion),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _capsuleDescription(CapsuleListItem capsule) {
    if (capsule.isGroupCapsule) {
      return capsule.canOpenNow ? '함께 만든 추억을 확인할 수 있어요.' : '친구들과 함께 묻은 캡슐이에요.';
    }
    return capsule.canOpenNow ? '이제 캡슐을 열어볼 수 있어요.' : '혼자 남긴 추억이 기다리고 있어요.';
  }

  static String _openLabel(CapsuleListItem capsule) {
    if (capsule.canOpenNow) {
      return '열람 가능';
    }
    if (capsule.openAt.trim().isNotEmpty) {
      return '${_formatDate(capsule.openAt)} 개봉';
    }
    return '즉시 개봉';
  }

  static String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return '날짜 없음';
    }

    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}.$month.$day';
  }
}

class _CapsuleStatusBadge extends StatelessWidget {
  const _CapsuleStatusBadge({required this.capsule});

  final CapsuleListItem capsule;

  @override
  Widget build(BuildContext context) {
    final Color color = capsule.canOpenNow
        ? _CapsuleListPageState._groupColor
        : _CapsuleListPageState._accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      color: color.withValues(alpha: 0.16),
      child: Text(
        capsule.canOpenNow ? '열림' : '대기',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: const Color(0xFFF7F1E8),
      child: Text(
        label,
        style: const TextStyle(
          color: _CapsuleListPageState._brown,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyCapsules extends StatelessWidget {
  const _EmptyCapsules();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 170,
      child: Center(
        child: Text(
          '아직 표시할 캡슐이 없습니다.',
          style: TextStyle(
            color: _CapsuleListPageState._mutedText,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
