import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../game/billiards_game.dart';
import 'game_screen.dart';
import 'settings_page.dart';
import 'theory_lab_page.dart';
import 'tutorial_page.dart';

const _gold = Color(0xFFD2B57B);
const _ivory = Color(0xFFF5F1E7);

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Image.asset(
              'assets/images/billiards-room.png',
              fit: BoxFit.cover,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xD9081110),
                  Color(0x99091110),
                  Color(0xD9081110),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape = constraints.maxWidth > constraints.maxHeight;
                final compact = constraints.maxHeight < 500;
                final brand = _brand(compact);
                final menu = _menu(context, compact);
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: landscape ? 56 : 28,
                    vertical: compact ? 18 : 36,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Text(
                            '专注每一次出杆',
                            style: TextStyle(
                              fontSize: 15,
                              letterSpacing: 2,
                              color: Colors.white60,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('设置'),
                            style: TextButton.styleFrom(
                              foregroundColor: _ivory,
                              textStyle: const TextStyle(fontSize: 17),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: landscape
                            ? Row(
                                children: [
                                  Expanded(child: brand),
                                  SizedBox(width: compact ? 36 : 72),
                                  Expanded(child: menu),
                                ],
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  children: [
                                    const SizedBox(height: 30),
                                    brand,
                                    const SizedBox(height: 28),
                                    menu,
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '中八解球',
                            style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 2,
                              color: Colors.white38,
                            ),
                          ),
                          Text(
                            '练球，从这里开始',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand(bool compact) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: compact ? 54 : 74,
        height: compact ? 54 : 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _gold.withValues(alpha: .5)),
          gradient: const RadialGradient(
            center: Alignment(-.4, -.5),
            colors: [Color(0xFF515651), Color(0xFF101613), Color(0xFF050807)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 30,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: compact ? 28 : 38,
            height: compact ? 28 : 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _ivory,
            ),
            child: Center(
              child: Text(
                '8',
                style: TextStyle(
                  color: const Color(0xFF161D18),
                  fontSize: compact ? 23 : 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
      SizedBox(height: compact ? 18 : 28),
      Text(
        '中八解球',
        style: TextStyle(
          fontSize: compact ? 48 : 68,
          fontWeight: FontWeight.w500,
          letterSpacing: 5,
          color: _ivory,
        ),
      ),
      SizedBox(height: compact ? 20 : 34),
      Container(width: 40, height: 1, color: _gold),
      const SizedBox(height: 14),
      const Text(
        '一张球台，无限可能。',
        style: TextStyle(fontSize: 19, letterSpacing: 2, color: Colors.white70),
      ),
      const SizedBox(height: 8),
      const Text(
        '瞄准 · 控杆 · 走位',
        style: TextStyle(fontSize: 16, letterSpacing: 2, color: Colors.white60),
      ),
    ],
  );

  Widget _menu(BuildContext context, bool compact) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 440),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MenuEntry(
          title: '自由练习',
          subtitle: '自由摆球 · 专注每一杆',
          icon: Icons.sports_golf_rounded,
          primary: true,
          compact: compact,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GameScreen(gameMode: GameMode.practice),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MenuEntry(
          title: '标准开局',
          subtitle: '完整中式八球规则',
          icon: Icons.play_circle_outline_rounded,
          compact: compact,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GameScreen(gameMode: GameMode.standard),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SmallEntry(
                title: '桌球教程',
                icon: Icons.menu_book_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TutorialPage()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallEntry(
                title: '理论实验室',
                icon: Icons.science_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TheoryLabPage()),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MenuEntry extends StatelessWidget {
  const _MenuEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.primary = false,
    required this.compact,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary, compact;
  @override
  Widget build(BuildContext context) => Material(
    color: primary ? _gold : const Color(0xAA16231E),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 22,
          vertical: compact ? 16 : 25,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary ? const Color(0xFFE1CA9D) : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: primary ? const Color(0xFF263128) : _gold,
              size: 28,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: primary ? const Color(0xFF16231C) : _ivory,
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: primary ? const Color(0xFF596044) : Colors.white54,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: primary ? const Color(0xFF263128) : Colors.white38,
              size: 21,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SmallEntry extends StatelessWidget {
  const _SmallEntry({
    required this.title,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xAA16231E),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _gold, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(color: _ivory, fontSize: 17),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
