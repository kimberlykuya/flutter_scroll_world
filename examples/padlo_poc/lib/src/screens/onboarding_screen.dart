import 'package:flutter/material.dart';

import '../theme/padlo_theme.dart';

/// Legacy route child retained for compatibility with callers that imported
/// the original screen. The active router now renders PadloWorldScreen, so the
/// Padlo pilot never initializes the old video-based onboarding view.
final class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: PadloTokens.darkSurface,
    child: Center(
      child: Text(
        'Padlo real-time world',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}
