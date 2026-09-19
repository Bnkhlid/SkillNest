import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../core/services/share_service.dart';
import '../main.dart';
import '../vault.dart';
import 'add_resource.dart';
import 'onboarding.dart';
import 'root_shell.dart';

/// A short branded hand-off from the native launch screen to the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static bool _shownInCurrentProcess = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..forward();
    final alreadyShown = _shownInCurrentProcess;
    _shownInCurrentProcess = true;
    _continueToApp(skipAnimation: alreadyShown);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continueToApp({required bool skipAnimation}) async {
    final sharedUrl = await ShareService.instance.checkInitialShare();
    if (!skipAnimation) {
      await Future.delayed(const Duration(milliseconds: 1450));
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            Vault.I.firstRunDone ? const RootShell() : const OnboardingScreen(),
      ),
    );
    if (sharedUrl != null &&
        sharedUrl.isNotEmpty &&
        appNavigatorKey.currentState != null) {
      appNavigatorKey.currentState!.pushNamed(
        RoutePaths.add,
        arguments: AddArgs(initialUrl: sharedUrl),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD0F4F0),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          final t = Curves.easeInOutCubic.transform(_controller.value);
          final titleOpacity = Curves.easeOut.transform(
            ((t - .52) / .48).clamp(0.0, 1.0),
          );
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OpeningBook(progress: t),
                const SizedBox(height: 28),
                Opacity(
                  opacity: titleOpacity,
                  child: const Text(
                    'SkillNest',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                      color: NotedColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Opacity(
                  opacity: titleOpacity,
                  child: const Text(
                    'Learn, finish, grow.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF286B69),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A tiny book-opening animation using SkillNest's mint and coral palette.
class _OpeningBook extends StatelessWidget {
  const _OpeningBook({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final open = Curves.easeOutBack.transform((progress / .74).clamp(0.0, 1.0));
    final coverWidth = 76.0 * open;
    return SizedBox(
      width: 196,
      height: 156,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 142 * open + 20,
            height: 104,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EE),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: NotedColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33242424),
                  offset: Offset(0, 7),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          Positioned(
            left: 22,
            child: Transform.translate(
              offset: Offset(-16 * (1 - open), 0),
              child: _Cover(width: coverWidth, left: true),
            ),
          ),
          Positioned(
            right: 22,
            child: Transform.translate(
              offset: Offset(16 * (1 - open), 0),
              child: _Cover(width: coverWidth, left: false),
            ),
          ),
          Container(width: 4, height: 108, color: const Color(0xFF286B69)),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.width, required this.left});
  final double width;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width.clamp(4.0, 76.0),
      height: 118,
      decoration: BoxDecoration(
        color: left ? const Color(0xFF8CD4CB) : const Color(0xFFF6A89E),
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(left ? 17 : 4),
          right: Radius.circular(left ? 4 : 17),
        ),
        border: Border.all(color: NotedColors.ink, width: 2),
      ),
    );
  }
}
