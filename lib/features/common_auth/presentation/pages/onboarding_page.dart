import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'package:agapecares/app/routes/app_routes.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;
  final List<_OnboardItem> _items = const [
    _OnboardItem(
      title: 'Reliable Home Services',
      body: 'Book trusted professionals for cleaning, repairs and more.',
      asset: 'assets/images/Home_C.png',
    ),
    _OnboardItem(
      title: 'Easy Scheduling',
      body: 'Choose a convenient time and pay securely from the app.',
      asset: 'assets/images/Office_C.png',
    ),
    _OnboardItem(
      title: 'Quality Guaranteed',
      body: 'We ensure satisfaction with every service.',
      asset: 'assets/logos/app_logo.png',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    GoRouter.of(context).go(AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _items.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 220,
                          child: Image.asset(item.asset, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 24),
                        Text(item.title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(item.body, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _page == _items.length - 1 ? _finish : () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('seen_onboarding', true);
                      if (!mounted) return;
                      GoRouter.of(context).go(AppRoutes.login);
                    },
                    child: const Text('Skip'),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(_items.length, (i) => _buildDot(i == _page)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_page == _items.length - 1) {
                        _finish();
                      } else {
                        _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      }
                    },
                    child: Text(_page == _items.length - 1 ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 12 : 8,
      height: active ? 12 : 8,
      decoration: BoxDecoration(
        color: active ? Theme.of(context).colorScheme.primary : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _OnboardItem {
  final String title;
  final String body;
  final String asset;
  const _OnboardItem({required this.title, required this.body, required this.asset});
}

