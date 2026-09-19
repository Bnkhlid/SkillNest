import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../main.dart';
import '../vault.dart';

class OnboardingPageData {
  const OnboardingPageData(
    this.icon,
    this.title,
    this.body,
    this.badges,
    this.noteColor,
  );

  final IconData icon;
  final String title;
  final String body;
  final List<(IconData, String)> badges;
  final Color noteColor;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  int _page = 0;

  static const _featurePages = [
    OnboardingPageData(
      Icons.edit_note_rounded,
      'Smart Notes & Todos',
      'Organize your thoughts, daily plans, and tasks into charming pastel sticky notes.',
      [
        (Icons.check_box_rounded, 'Interactive Todos'),
        (Icons.edit_rounded, 'Rich Notes'),
        (Icons.auto_awesome_rounded, 'Pastel Vibes'),
      ],
      NotedColors.yellow,
    ),
    OnboardingPageData(
      Icons.bookmark_add_rounded,
      'Save Everything',
      'Collect links, articles, documents, and references with instant auto-tagging.',
      [
        (Icons.inbox_rounded, 'Inbox first'),
        (Icons.link_rounded, 'Web Links'),
        (Icons.cloud_done_rounded, 'Fast Save'),
      ],
      NotedColors.mint,
    ),
    OnboardingPageData(
      Icons.collections_bookmark_rounded,
      'Custom Collections',
      'Group your knowledge by projects or categories and keep essentials starred.',
      [
        (Icons.folder_rounded, 'Categories'),
        (Icons.sell_outlined, 'Tags'),
        (Icons.star_rounded, 'Favorites'),
      ],
      NotedColors.pink,
    ),
    OnboardingPageData(
      Icons.insights_rounded,
      'Track Your Growth',
      'Monitor your progress streaks, reading stats, and completion rate seamlessly.',
      [
        (Icons.trending_up_rounded, 'Streak Analytics'),
        (Icons.task_alt_rounded, 'Daily Goals'),
      ],
      NotedColors.yellow,
    ),
  ];

  int get _totalPages => _featurePages.length + 1;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: Vault.I.userName);
    _emailController = TextEditingController(text: Vault.I.userEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await Vault.I.setProfile(name, _emailController.text.trim());
    }
    if (!mounted) return;
    await Vault.I.completeFirstRun();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, RoutePaths.root);
  }

  Future<void> _next() async {
    if (_page == _totalPages - 1) {
      await _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _totalPages - 1;

    return Scaffold(
      backgroundColor: NotedColors.canvasLight,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: Back + Skip
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  if (_page > 0)
                    IconButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: NotedColors.ink,
                      ),
                      tooltip: 'Back',
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _finish,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: NotedColors.border,
                              width: 1.6,
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: NotedColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _totalPages,
                itemBuilder: (context, i) {
                  if (i < _featurePages.length) {
                    final p = _featurePages[i];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.l),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _Illustration(
                            page: i,
                            icon: p.icon,
                            color: p.noteColor,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            p.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: NotedColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            p.body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: NotedColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: p.badges
                                .map(
                                  (b) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: NotedColors.border,
                                        width: 1.6,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: NotedColors.shadow,
                                          offset: Offset(1.5, 2),
                                          blurRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          b.$1,
                                          size: 15,
                                          color: NotedColors.ink,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          b.$2,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: NotedColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  }

                  // Profile details step
                  final enteredName = _nameController.text.trim();
                  final initialLetter = enteredName.isNotEmpty
                      ? enteredName[0].toUpperCase()
                      : 'M';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.l),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Avatar preview card
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            color: NotedColors.yellow,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: NotedColors.border,
                              width: 2.6,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: NotedColors.shadow,
                                offset: Offset(3.5, 4.5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initialLetter,
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: NotedColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'What should we call you?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: NotedColors.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Enter your details to personalize SkillNest.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: NotedColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: NotedColors.border,
                              width: 2.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: NotedColors.shadow,
                                offset: Offset(2.5, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: TextField(
                            controller: _nameController,
                            onChanged: (_) => setState(() {}),
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: NotedColors.ink,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter your name...',
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                color: NotedColors.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: NotedColors.border,
                              width: 2.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: NotedColors.shadow,
                                offset: Offset(2.5, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: NotedColors.ink,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter your email...',
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: NotedColors.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots + Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.l,
                8,
                Insets.l,
                Insets.l,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 28 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: active ? NotedColors.ink : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: NotedColors.border,
                            width: 1.8,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLast
                            ? NotedColors.mint
                            : NotedColors.yellow,
                        foregroundColor: NotedColors.ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(
                            color: NotedColors.border,
                            width: 2.2,
                          ),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      onPressed: _next,
                      child: Text(
                        isLast ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.page,
    required this.icon,
    required this.color,
  });

  final int page;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Note Shadow
          Transform.translate(
            offset: const Offset(-10, 8),
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: page % 2 == 0 ? NotedColors.pink : NotedColors.mint,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: NotedColors.border, width: 2.2),
                  boxShadow: const [
                    BoxShadow(
                      color: NotedColors.shadow,
                      offset: Offset(3, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Main Note
          Transform.translate(
            offset: const Offset(8, -6),
            child: Transform.rotate(
              angle: 0.08,
              child: Container(
                width: 146,
                height: 146,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: NotedColors.border, width: 2.4),
                  boxShadow: const [
                    BoxShadow(
                      color: NotedColors.shadow,
                      offset: Offset(3.5, 4.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 58, color: NotedColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
