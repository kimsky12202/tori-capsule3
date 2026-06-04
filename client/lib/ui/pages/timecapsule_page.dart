import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../game/timecapsule_game.dart';
import 'capsule_list.dart';

class TimecapsulePage extends StatefulWidget {
  const TimecapsulePage({super.key});

  @override
  State<TimecapsulePage> createState() => TimecapsulePageState();
}

class TimecapsulePageState extends State<TimecapsulePage>
    with AutomaticKeepAliveClientMixin {
  late final TimecapsuleGame _game;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _game = TimecapsuleGame();
  }

  Future<void> playRegisterAnimation({
    String design = 'base',
    String? capsuleId,
  }) async {
    await _game.loaded;
    await _game.onCapsuleRegistered(design: design, capsuleId: capsuleId);
  }

  /// 다른 탭에서 캡슐을 등록한 뒤 캡슐 탭으로 진입했을 때 호출되는 훅.
  /// main_tab_page 에서 _capsulePageKey.currentState?.onTabSelected() 로 부른다.
  /// 현재는 playRegisterAnimation 으로 직접 트리거하므로 별도 처리는 없다.
  Future<void> onTabSelected() async {
    await _game.loaded;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          // 테스트용 버튼 (나중에 제거)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: () => _game.onCapsuleRegistered(),
                child: const Text('캡슐 보관하기'),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: _CapsuleListButton(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const CapsuleListPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleListButton extends StatelessWidget {
  const _CapsuleListButton({required this.onTap});

  final VoidCallback onTap;

  static const Color _brown = Color(0xFF765142);
  static const Color _shadowColor = Color(0xFF5A372B);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '캡슐 목록',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(color: _shadowColor, offset: Offset(5, 5)),
            ],
          ),
          child: const Icon(Icons.list_alt_outlined, color: _brown, size: 34),
        ),
      ),
    );
  }
}
