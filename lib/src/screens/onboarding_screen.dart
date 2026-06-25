import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      icon: Icons.favorite_rounded,
      title: 'Gebelik & Bebek Takibi',
      description:
          'Haftalik gelisim, gunluk notlar ve temel saglik verilerini tek bir yerden duzenli takip et.',
      gradient: [Color(0xFF6D5BE3), Color(0xFFB07CFF)],
      accent: Color(0xFFC2B1FF),
    ),
    _OnboardingItem(
      icon: Icons.auto_awesome_rounded,
      title: 'Kişisel Gebelik Rehberi',
      description:
          'Olcumlerine ve sorularina gore kisisellestirilmis yorumlar al, bilincli adimlar at.',
      gradient: [Color(0xFF5B4BE0), Color(0xFF7C6DFF)],
      accent: Color(0xFFB7ABFF),
    ),
    _OnboardingItem(
      icon: Icons.family_restroom_rounded,
      title: 'Aile Odakli Yolculuk',
      description:
          'Anne, baba ve aile bireyleri ayni akista ilerleyip bebegin yolculugunu birlikte planlar.',
      gradient: [Color(0xFF6256C9), Color(0xFFAB7FFF)],
      accent: Color(0xFFC9B8FF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_currentIndex == _items.length - 1) {
      widget.onFinished();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() => widget.onFinished();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _currentIndex == _items.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              _topBar(onSkip: _skip),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _items.length,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (context, i) => _OnboardingPage(
                    item: _items[i],
                    theme: theme,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _items.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    margin:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                    width: _currentIndex == i ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == i
                          ? context.palette.primary
                          : context.palette.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                onPressed: _next,
                label: isLast ? 'Baslayalim' : 'Devam et',
                icon: isLast
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: AppButtonSize.large,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar({required VoidCallback onSkip}) {
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: context.palette.brandGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child:
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          "Gebelik Takip",
          style: TextStyle(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        GhostButton(
          onPressed: onSkip,
          label: "Atla",
          foregroundColor: context.palette.textSecondary,
        ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.item, required this.theme});

  final _OnboardingItem item;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                gradient: LinearGradient(
                  colors: item.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: AppShadows.elevated,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      height: 160,
                      width: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -60,
                    left: -30,
                    child: Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      height: 168,
                      width: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          height: 116,
                          width: 116,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.5),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            item.icon,
                            size: 58,
                            color: item.gradient.first,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            item.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              item.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.palette.textSecondary,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final Color accent;
}
