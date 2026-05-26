import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../game/timecapsule_game.dart';
import 'capsule_list.dart';

class TimecapsulePage extends StatefulWidget {
  const TimecapsulePage({super.key});

  @override
  State<TimecapsulePage> createState() => _TimecapsulePageState();
}

class _TimecapsulePageState extends State<TimecapsulePage> {
  late final TimecapsuleGame _game;

  @override
  void initState() {
    super.initState();
    _game = TimecapsuleGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: 96,
                child: Image.asset(
                  'assets/images/auth/asset.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
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
