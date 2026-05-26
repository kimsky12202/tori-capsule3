import 'package:flutter/material.dart';

import 'ar/ar_screen.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  static const Color _backgroundColor = Color(0xFFFFF6E6);
  static const Color _brown = Color(0xFF6F4135);
  static const Color _mutedText = Color(0xFFCDBBA8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: ColoredBox(color: _backgroundColor)),
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
            top: 118,
            left: 16,
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
                    );
                  },
                ),
                const SizedBox(height: 12),
                const _MapControlButton(icon: Icons.near_me_outlined),
              ],
            ),
          ),
          const Center(
            child: Text(
              '지도 영역\n여기에 지도가\n표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mutedText,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Positioned(
            right: 24,
            bottom: 24,
            child: Column(
              children: <Widget>[
                _MapControlButton(icon: Icons.add, iconSize: 26),
                SizedBox(height: 8),
                _MapControlButton(icon: Icons.remove, iconSize: 26),
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
