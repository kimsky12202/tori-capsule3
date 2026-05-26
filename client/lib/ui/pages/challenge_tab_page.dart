import 'package:flutter/material.dart';

import '../services/challenge_api.dart';

enum _ChallengeFilter { all, inProgress, completed }

class ChallengeTabPage extends StatefulWidget {
  const ChallengeTabPage({super.key});

  @override
  State<ChallengeTabPage> createState() => _ChallengeTabPageState();
}

class _ChallengeTabPageState extends State<ChallengeTabPage> {
  static const Color _backgroundColor = Color(0xFFFFF6E6);
  static const Color _darkTextColor = Color(0xFF2E2B2A);
  static const Color _bodyTextColor = Color(0xFF334155);
  static const Color _cardColor = Colors.white;
  static const Color _accentColor = Color(0xFFFFB36B);
  static const Color _completedColor = Color(0xFF7EA9D6);
  static const Color _lockedColor = Color(0xFFC8B7D5);
  static const Color _progressBorderColor = Color(0xFF9AA3B1);
  static const Color _progressBackgroundColor = Color(0xFFF7F7F2);

  final ChallengeApi _challengeApi = ChallengeApi();
  final Set<String> _claimingIds = <String>{};
  late Future<List<ChallengeItem>> _futureChallenges;
  _ChallengeFilter _selectedFilter = _ChallengeFilter.inProgress;

  @override
  void initState() {
    super.initState();
    _futureChallenges = _challengeApi.listMyChallenges();
  }

  Future<void> _refreshChallenges() async {
    final Future<List<ChallengeItem>> future = _challengeApi.listMyChallenges();
    setState(() {
      _futureChallenges = future;
    });
    await future;
  }

  Future<void> _claimChallenge(ChallengeItem item) async {
    if (!item.canClaim || _claimingIds.contains(item.id)) {
      return;
    }

    setState(() {
      _claimingIds.add(item.id);
    });

    try {
      await _challengeApi.claimChallenge(challengeId: item.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('보상을 받았습니다.')));
      await _refreshChallenges();
    } on ChallengeApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('보상 수령 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          _claimingIds.remove(item.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: ColoredBox(
        color: _backgroundColor,
        child: FutureBuilder<List<ChallengeItem>>(
          future: _futureChallenges,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<ChallengeItem>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error);
                }

                final List<ChallengeItem> challenges =
                    snapshot.data ?? <ChallengeItem>[];
                return _buildChallengeList(challenges);
              },
        ),
      ),
    );
  }

  Widget _buildChallengeList(List<ChallengeItem> challenges) {
    final List<ChallengeItem> filteredChallenges = _filteredChallenges(
      challenges,
    );
    final int completedCount = challenges.where(_isCompleted).length;
    final int achievementRate = challenges.isEmpty
        ? 0
        : ((completedCount / challenges.length) * 100).round();

    return RefreshIndicator(
      onRefresh: _refreshChallenges,
      color: _accentColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: <Widget>[
          const _RoofAsset(),
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 30, 34, 36),
            child: Column(
              children: <Widget>[
                _ChallengeFilterTabs(
                  selectedFilter: _selectedFilter,
                  totalCount: challenges.length,
                  inProgressCount: challenges
                      .where((item) => !_isCompleted(item))
                      .length,
                  completedCount: completedCount,
                  onChanged: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
                const SizedBox(height: 26),
                _AchievementSummary(rate: achievementRate),
                const SizedBox(height: 26),
                if (filteredChallenges.isEmpty)
                  const _EmptyChallenges()
                else
                  ...filteredChallenges.map(
                    (ChallengeItem challenge) => Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: _ChallengeCard(
                        challenge: challenge,
                        isClaiming: _claimingIds.contains(challenge.id),
                        onClaimPressed: () => _claimChallenge(challenge),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: const <Widget>[
        _RoofAsset(),
        SizedBox(height: 96),
        Center(child: CircularProgressIndicator(color: _accentColor)),
      ],
    );
  }

  Widget _buildErrorState(Object? error) {
    final String message = error is ChallengeApiException
        ? error.message
        : '업적을 불러오지 못했습니다.';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: <Widget>[
        const _RoofAsset(),
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 64, 34, 36),
          child: Column(
            children: <Widget>[
              const Icon(Icons.error_outline, color: _bodyTextColor, size: 36),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _bodyTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _PixelButton(label: '다시 시도', onTap: _refreshChallenges),
            ],
          ),
        ),
      ],
    );
  }

  List<ChallengeItem> _filteredChallenges(List<ChallengeItem> challenges) {
    switch (_selectedFilter) {
      case _ChallengeFilter.all:
        return challenges;
      case _ChallengeFilter.inProgress:
        return challenges.where((item) => !_isCompleted(item)).toList();
      case _ChallengeFilter.completed:
        return challenges.where(_isCompleted).toList();
    }
  }

  static bool _isCompleted(ChallengeItem item) {
    return item.status == 'completed' || item.status == 'claimed';
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

class _ChallengeFilterTabs extends StatelessWidget {
  const _ChallengeFilterTabs({
    required this.selectedFilter,
    required this.totalCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.onChanged,
  });

  final _ChallengeFilter selectedFilter;
  final int totalCount;
  final int inProgressCount;
  final int completedCount;
  final ValueChanged<_ChallengeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _ChallengeFilterButton(
          label: '전체',
          count: totalCount,
          isSelected: selectedFilter == _ChallengeFilter.all,
          onTap: () => onChanged(_ChallengeFilter.all),
        ),
        const SizedBox(width: 14),
        _ChallengeFilterButton(
          label: '진행중',
          count: inProgressCount,
          isSelected: selectedFilter == _ChallengeFilter.inProgress,
          onTap: () => onChanged(_ChallengeFilter.inProgress),
        ),
        const SizedBox(width: 14),
        _ChallengeFilterButton(
          label: '완료',
          count: completedCount,
          isSelected: selectedFilter == _ChallengeFilter.completed,
          selectedColor: _ChallengeTabPageState._completedColor,
          onTap: () => onChanged(_ChallengeFilter.completed),
        ),
      ],
    );
  }
}

class _ChallengeFilterButton extends StatelessWidget {
  const _ChallengeFilterButton({
    required this.label,
    required this.count,
    required this.isSelected,
    this.selectedColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final Color? selectedColor;
  final VoidCallback onTap;

  static const Color _darkTextColor = _ChallengeTabPageState._darkTextColor;
  static const Color _mutedTextColor = Color(0xFF7A756D);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected && selectedColor != null
            ? selectedColor!.withValues(alpha: 0.16)
            : Colors.white,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                '$label ($count)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? (selectedColor ?? _darkTextColor)
                      : _mutedTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementSummary extends StatelessWidget {
  const _AchievementSummary({required this.rate});

  final int rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      color: Colors.white,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(
        '달성률: $rate%',
        style: const TextStyle(
          color: _ChallengeTabPageState._darkTextColor,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.isClaiming,
    required this.onClaimPressed,
  });

  final ChallengeItem challenge;
  final bool isClaiming;
  final VoidCallback onClaimPressed;

  static const Color _darkTextColor = _ChallengeTabPageState._darkTextColor;
  static const Color _bodyTextColor = _ChallengeTabPageState._bodyTextColor;
  static const Color _cardColor = _ChallengeTabPageState._cardColor;
  static const Color _accentColor = _ChallengeTabPageState._accentColor;
  static const Color _completedColor = _ChallengeTabPageState._completedColor;
  static const Color _lockedColor = _ChallengeTabPageState._lockedColor;
  static const Color _progressBorderColor =
      _ChallengeTabPageState._progressBorderColor;
  static const Color _progressBackgroundColor =
      _ChallengeTabPageState._progressBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(challenge.status);
    final String statusLabel = _statusLabel(challenge.status);
    final bool isCompleted = _isCompletedStatus(challenge.status);
    final double progressValue = _progressValue(challenge, isCompleted);

    return Material(
      color: _cardColor,
      child: InkWell(
        onTap: challenge.canClaim && !isClaiming ? onClaimPressed : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 160),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isCompleted
                    ? const Color(0xFFD8E7F5)
                    : const Color(0xFFFFE4BA),
                width: isCompleted ? 2 : 1,
              ),
              left: BorderSide(
                color: isCompleted
                    ? const Color(0xFFD8E7F5)
                    : const Color(0xFFFFE4BA),
                width: isCompleted ? 2 : 1,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.flag_outlined, color: statusColor, size: 34),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      challenge.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _darkTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  isClaiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _accentColor,
                          ),
                        )
                      : Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Text(
                  challenge.description,
                  style: const TextStyle(
                    color: _bodyTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: _PixelProgressBar(
                  value: progressValue,
                  fillColor: isCompleted
                      ? const Color(0xFF6F9FD0)
                      : _progressFillColor(challenge.status),
                  borderColor: isCompleted
                      ? _completedColor
                      : _progressBorderColor,
                  backgroundColor: isCompleted
                      ? const Color(0xFFDDECF8)
                      : _progressBackgroundColor,
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Text(
                  '${challenge.progressValue} / ${challenge.conditionValue}',
                  style: const TextStyle(
                    color: _bodyTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'locked':
        return _lockedColor;
      case 'claimed':
      case 'completed':
        return _completedColor;
      default:
        return _accentColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'locked':
        return '잠김';
      case 'claimed':
        return '완료';
      case 'completed':
        return '달성';
      default:
        return '진행중';
    }
  }

  Color _progressFillColor(String status) {
    switch (status) {
      case 'locked':
        return const Color(0xFFC5CAD2);
      case 'claimed':
      case 'completed':
        return _completedColor;
      default:
        return _accentColor;
    }
  }

  double _progressValue(ChallengeItem challenge, bool isCompleted) {
    if (isCompleted) {
      return 1;
    }
    if (challenge.status == 'locked') {
      return 0;
    }
    return challenge.progressRate;
  }

  bool _isCompletedStatus(String status) {
    return status == 'completed' || status == 'claimed';
  }
}

class _PixelProgressBar extends StatelessWidget {
  const _PixelProgressBar({
    required this.value,
    required this.fillColor,
    required this.borderColor,
    required this.backgroundColor,
  });

  final double value;
  final Color fillColor;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final double clampedValue = value.clamp(0, 1);

    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 3),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double fillWidth = constraints.maxWidth * clampedValue;

          return Stack(
            children: <Widget>[
              Positioned.fill(child: ColoredBox(color: backgroundColor)),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: fillWidth,
                child: ColoredBox(color: fillColor),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyChallenges extends StatelessWidget {
  const _EmptyChallenges();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(
        child: Text(
          '표시할 챌린지가 없습니다.',
          style: TextStyle(
            color: _ChallengeTabPageState._bodyTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PixelButton extends StatelessWidget {
  const _PixelButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: _ChallengeTabPageState._accentColor,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: _ChallengeTabPageState._darkTextColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
