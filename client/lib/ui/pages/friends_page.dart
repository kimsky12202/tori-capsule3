import 'dart:async';

import 'package:flutter/material.dart';

import '../services/friend_api.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  static const Color _backgroundColor = Color(0xFFFFF6E6);
  static const Color _titleColor = Color(0xFF2E2B2A);
  static const Color _brown = Color(0xFF765142);
  static const Color _mutedTextColor = Color(0xFF9A786A);
  static const Color _searchFillColor = Color(0xFFF1F8FE);
  static const Color _requestFillColor = Color(0xFFFFF6E6);
  static const Color _avatarPeachColor = Color(0xFFFFC989);
  static const Color _avatarBlueColor = Color(0xFFB8D4F0);
  static const Color _dangerColor = Color(0xFF8E5555);

  final FriendApi _friendApi = FriendApi();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _requestingUserIds = <String>{};
  final Set<String> _acceptingRequestIds = <String>{};
  final Set<String> _rejectingRequestIds = <String>{};
  final Set<String> _deletingFriendIds = <String>{};
  Timer? _searchDebounce;

  List<FriendSearchUser> _searchResults = const <FriendSearchUser>[];
  List<FriendRequestItem> _incomingRequests = const <FriendRequestItem>[];
  List<FriendListItem> _friends = const <FriendListItem>[];

  bool _isLoadingSearch = false;
  bool _isLoadingIncoming = true;
  bool _isLoadingFriends = true;
  String? _searchError;
  String? _incomingError;
  String? _friendsError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait(<Future<void>>[
      _loadIncomingRequests(showLoading: true),
      _loadFriends(showLoading: true),
    ]);
  }

  Future<void> _refreshAll() async {
    await Future.wait(<Future<void>>[
      _loadIncomingRequests(showLoading: false),
      _loadFriends(showLoading: false),
    ]);

    if (_searchController.text.trim().isNotEmpty) {
      await _searchUsers(showLoading: false);
    }
  }

  Future<void> _loadIncomingRequests({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoadingIncoming = true;
        _incomingError = null;
      });
    } else if (mounted) {
      setState(() {
        _incomingError = null;
      });
    }

    try {
      final List<FriendRequestItem> requests = await _friendApi
          .listIncomingRequests(status: 'pending');
      if (!mounted) {
        return;
      }
      setState(() {
        _incomingRequests = requests;
        _isLoadingIncoming = false;
      });
    } on FriendApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _incomingError = e.message;
        _isLoadingIncoming = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _incomingError = '받은 친구 요청을 불러오지 못했습니다.';
        _isLoadingIncoming = false;
      });
    }
  }

  Future<void> _loadFriends({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoadingFriends = true;
        _friendsError = null;
      });
    } else if (mounted) {
      setState(() {
        _friendsError = null;
      });
    }

    try {
      final List<FriendListItem> friends = await _friendApi.listFriends();
      if (!mounted) {
        return;
      }
      setState(() {
        _friends = friends;
        _isLoadingFriends = false;
      });
    } on FriendApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _friendsError = e.message;
        _isLoadingFriends = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _friendsError = '친구 목록을 불러오지 못했습니다.';
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _searchUsers({bool showLoading = true}) async {
    final String query = _searchController.text.trim();
    if (query.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = const <FriendSearchUser>[];
        _searchError = null;
        _isLoadingSearch = false;
      });
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _isLoadingSearch = true;
        _searchError = null;
      });
    } else if (mounted) {
      setState(() {
        _searchError = null;
      });
    }

    try {
      final List<FriendSearchUser> users = await _friendApi.searchUsers(
        query: query,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = users;
        _isLoadingSearch = false;
      });
    } on FriendApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchError = e.message;
        _isLoadingSearch = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchError = '유저 검색에 실패했습니다.';
        _isLoadingSearch = false;
      });
    }
  }

  Future<void> _sendFriendRequest(FriendSearchUser user) async {
    if (_requestingUserIds.contains(user.id)) {
      return;
    }

    setState(() {
      _requestingUserIds.add(user.id);
    });

    try {
      final bool acceptedAutomatically = await _friendApi.sendFriendRequest(
        receiverId: user.id,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(
        acceptedAutomatically ? '상대의 요청을 바로 수락했습니다.' : '친구 요청을 보냈습니다.',
      );
      await _refreshAll();
    } on FriendApiException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('친구 요청 처리 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _requestingUserIds.remove(user.id);
        });
      }
    }
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    if (_acceptingRequestIds.contains(requestId)) {
      return;
    }

    setState(() {
      _acceptingRequestIds.add(requestId);
    });

    try {
      await _friendApi.acceptFriendRequest(requestId: requestId);
      _showSnackBar('친구 요청을 수락했습니다.');
      await _refreshAll();
    } on FriendApiException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('요청 수락 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _acceptingRequestIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    if (_rejectingRequestIds.contains(requestId)) {
      return;
    }

    setState(() {
      _rejectingRequestIds.add(requestId);
    });

    try {
      await _friendApi.rejectFriendRequest(requestId: requestId);
      _showSnackBar('친구 요청을 거절했습니다.');
      await _refreshAll();
    } on FriendApiException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('요청 거절 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _rejectingRequestIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _deleteFriend(FriendListItem friend) async {
    if (_deletingFriendIds.contains(friend.id)) {
      return;
    }

    final bool shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('친구 삭제'),
              content: Text('${friend.displayName}님을 친구 목록에서 삭제할까요?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('삭제'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete || !mounted) {
      return;
    }

    setState(() {
      _deletingFriendIds.add(friend.id);
    });

    try {
      await _friendApi.deleteFriend(friendId: friend.id);
      _showSnackBar('친구를 삭제했습니다.');
      await _refreshAll();
    } on FriendApiException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('친구 삭제 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingFriendIds.remove(friend.id);
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: ColoredBox(
        color: _backgroundColor,
        child: RefreshIndicator(
          onRefresh: _refreshAll,
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
                    _buildMainPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleBack,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.chevron_left, color: _titleColor, size: 32),
          SizedBox(width: 2),
          Text(
            '뒤로',
            style: TextStyle(
              color: _titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _handleBack() {
    final VoidCallback? onBack = widget.onBack;
    if (onBack != null) {
      onBack();
      return;
    }

    Navigator.of(context).maybePop();
  }

  Widget _buildMainPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0x1A765142), offset: Offset(5, 5)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '친구 관리',
            style: TextStyle(
              color: _brown,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 26),
          _buildSearchBox(),
          _buildSearchResults(),
          const SizedBox(height: 30),
          _buildIncomingRequestsSection(),
          const SizedBox(height: 32),
          _buildFriendsSection(),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    final bool hasQuery = _searchController.text.trim().isNotEmpty;

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: _searchFillColor,
        border: Border(top: BorderSide(color: Color(0xFFD7C8BF), width: 1)),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (String value) {
          _searchDebounce?.cancel();
          if (value.trim().isEmpty) {
            setState(() {
              _searchResults = const <FriendSearchUser>[];
              _searchError = null;
              _isLoadingSearch = false;
            });
            return;
          }

          setState(() {});
          _searchDebounce = Timer(
            const Duration(milliseconds: 450),
            () => _searchUsers(),
          );
        },
        onSubmitted: (_) {
          _searchDebounce?.cancel();
          _searchUsers();
        },
        style: const TextStyle(
          color: _titleColor,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
        decoration: InputDecoration(
          hintText: '유저 검색',
          hintStyle: const TextStyle(
            color: Color(0xFFC8BDB7),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: _brown, size: 30),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = const <FriendSearchUser>[];
                      _searchError = null;
                      _isLoadingSearch = false;
                    });
                  },
                  icon: const Icon(Icons.close, color: _brown),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final bool hasQuery = _searchController.text.trim().isNotEmpty;
    final bool hasContent =
        hasQuery || _searchError != null || _searchResults.isNotEmpty;
    if (!hasContent) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionTitle(
            icon: Icons.person_search_outlined,
            label: '검색 결과 (${_searchResults.length})',
          ),
          const SizedBox(height: 12),
          if (_searchError != null)
            _StatusText(_searchError!, color: _dangerColor)
          else if (_isLoadingSearch)
            const _LoadingStrip()
          else if (_searchResults.isEmpty)
            const _StatusText('검색 결과가 없습니다.')
          else
            Column(children: _searchResults.map(_buildSearchUserRow).toList()),
        ],
      ),
    );
  }

  Widget _buildSearchUserRow(FriendSearchUser user) {
    return _PixelListRow(
      fillColor: _requestFillColor,
      avatarColor: _avatarPeachColor,
      title: user.displayName,
      subtitle: '@${user.username}',
      trailing: _buildSearchAction(user),
    );
  }

  Widget _buildSearchAction(FriendSearchUser user) {
    if (_requestingUserIds.contains(user.id)) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: _brown),
      );
    }

    if (user.canSendRequest) {
      return _PixelSmallButton(
        label: '요청',
        filled: true,
        onTap: () => _sendFriendRequest(user),
      );
    }

    if (user.isOutgoingPending) {
      return const _PixelSmallButton(label: '요청중', filled: false);
    }

    if (user.isIncomingPending) {
      final bool isAccepting = _acceptingRequestIds.contains(
        user.pendingRequestId,
      );
      final bool isRejecting = _rejectingRequestIds.contains(
        user.pendingRequestId,
      );
      final bool isBusy = isAccepting || isRejecting;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PixelSmallButton(
            label: isAccepting ? '' : '수락',
            filled: true,
            isLoading: isAccepting,
            onTap: isBusy
                ? null
                : () => _acceptFriendRequest(user.pendingRequestId),
          ),
          const SizedBox(width: 8),
          _PixelSmallButton(
            label: isRejecting ? '' : '거절',
            filled: false,
            isLoading: isRejecting,
            onTap: isBusy
                ? null
                : () => _rejectFriendRequest(user.pendingRequestId),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildIncomingRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionTitle(
          icon: Icons.person_add_alt_1_outlined,
          label: '친구 요청 (${_incomingRequests.length})',
        ),
        const SizedBox(height: 14),
        if (_isLoadingIncoming)
          const _LoadingStrip()
        else if (_incomingError != null)
          _StatusText(_incomingError!, color: _dangerColor)
        else if (_incomingRequests.isEmpty)
          const _StatusText('받은 친구 요청이 없습니다.')
        else
          Column(
            children: _incomingRequests.map(_buildIncomingRequestRow).toList(),
          ),
      ],
    );
  }

  Widget _buildIncomingRequestRow(FriendRequestItem request) {
    final bool isAccepting = _acceptingRequestIds.contains(request.id);
    final bool isRejecting = _rejectingRequestIds.contains(request.id);
    final bool isBusy = isAccepting || isRejecting;

    return _PixelListRow(
      fillColor: _requestFillColor,
      avatarColor: _avatarPeachColor,
      title: request.peerUser.displayName,
      subtitle: '캡슐을 파묻고 싶어요?',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PixelSmallButton(
            label: isAccepting ? '' : '수락',
            filled: true,
            isLoading: isAccepting,
            onTap: isBusy ? null : () => _acceptFriendRequest(request.id),
          ),
          const SizedBox(width: 8),
          _PixelSmallButton(
            label: isRejecting ? '' : '거절',
            filled: false,
            isLoading: isRejecting,
            onTap: isBusy ? null : () => _rejectFriendRequest(request.id),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionTitle(
          icon: Icons.person_add_disabled_outlined,
          label: '친구 목록 (${_friends.length})',
        ),
        const SizedBox(height: 14),
        if (_isLoadingFriends)
          const _LoadingStrip()
        else if (_friendsError != null)
          _StatusText(_friendsError!, color: _dangerColor)
        else if (_friends.isEmpty)
          const _StatusText('아직 친구가 없습니다.')
        else
          Column(children: _friends.map(_buildFriendRow).toList()),
      ],
    );
  }

  Widget _buildFriendRow(FriendListItem friend) {
    final bool isDeleting = _deletingFriendIds.contains(friend.id);

    return _PixelListRow(
      avatarColor: _avatarBlueColor,
      title: friend.displayName,
      subtitle: '@${friend.username}',
      showLeftRule: true,
      trailing: isDeleting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _dangerColor,
              ),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _deleteFriend(friend),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  '삭제',
                  style: TextStyle(
                    color: _mutedTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: _FriendsPageState._brown, size: 25),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _FriendsPageState._brown,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PixelListRow extends StatelessWidget {
  const _PixelListRow({
    required this.avatarColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.fillColor = Colors.white,
    this.showLeftRule = false,
  });

  final Color avatarColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Color fillColor;
  final bool showLeftRule;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: fillColor,
        border: showLeftRule
            ? const Border(left: BorderSide(color: Color(0xFFD7C8BF), width: 1))
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
      child: Row(
        children: <Widget>[
          _PixelAvatar(color: avatarColor),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _FriendsPageState._brown,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _FriendsPageState._mutedTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

class _PixelAvatar extends StatelessWidget {
  const _PixelAvatar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.55),
            offset: Offset(-5, -5),
          ),
        ],
      ),
      child: const Icon(
        Icons.person_outline,
        color: _FriendsPageState._brown,
        size: 31,
      ),
    );
  }
}

class _PixelSmallButton extends StatelessWidget {
  const _PixelSmallButton({
    required this.label,
    required this.filled,
    this.isLoading = false,
    this.onTap,
  });

  final String label;
  final bool filled;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = filled
        ? _FriendsPageState._brown
        : Colors.white;
    final Color foregroundColor = filled
        ? Colors.white
        : _FriendsPageState._brown;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 54,
        height: 36,
        color: backgroundColor,
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(
    this.label, {
    this.color = _FriendsPageState._mutedTextColor,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: LinearProgressIndicator(
        minHeight: 4,
        color: _FriendsPageState._brown,
        backgroundColor: Color(0xFFE8DED6),
      ),
    );
  }
}
