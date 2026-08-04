import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../models/demo_models.dart';
import '../theme/padlo_theme.dart';
import '../widgets/padlo_primitives.dart';

final class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset this proof of concept?'),
        content: const Text(
          'This clears the local demo profile and returns to the onboarding journey. No external account is affected.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep demo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset demo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await PadloScope.of(context).reset();
    if (context.mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final profile = PadloScope.of(context).profile!;
    return ProductPage(
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(
            eyebrow: 'Demo player',
            title: 'Your positioning profile',
            description:
                'These fictional details are stored locally to make the product walkthrough feel complete.',
          ),
          const SizedBox(height: PadloTokens.space32),
          PadloCard(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                final avatar = CircleAvatar(
                  radius: 52,
                  backgroundColor: context.padlo.tint,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    '${profile.firstName.characters.first}${profile.lastName.characters.first}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                );
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.fullName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: PadloTokens.space4),
                    Text(
                      profile.email,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: PadloTokens.space20),
                    Wrap(
                      spacing: PadloTokens.space8,
                      runSpacing: PadloTokens.space8,
                      children: <Widget>[
                        _ProfileTag(
                          icon: Icons.signal_cellular_alt,
                          text: enumLabel(profile.level),
                        ),
                        _ProfileTag(
                          icon: Icons.sports_tennis,
                          text: '${enumLabel(profile.preferredSide)} side',
                        ),
                        _ProfileTag(
                          icon: Icons.track_changes,
                          text: enumLabel(profile.focus),
                        ),
                      ],
                    ),
                  ],
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      avatar,
                      const SizedBox(height: PadloTokens.space24),
                      details,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    avatar,
                    const SizedBox(width: PadloTokens.space32),
                    Expanded(child: details),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: PadloTokens.space24),
          PadloCard(
            child: Column(
              children: <Widget>[
                _SettingsTile(
                  icon: Icons.replay_rounded,
                  title: 'Replay interactive onboarding',
                  subtitle:
                      'Return to the first court scene without clearing the demo.',
                  onTap: () => context.go('/onboarding'),
                ),
                const Divider(height: PadloTokens.space24),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'About this proof of concept',
                  subtitle:
                      'All players, matches, scores, and analysis are fictional.',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Padlo proof of concept',
                    applicationVersion: '0.1.0',
                    children: const <Widget>[
                      Text(
                        'A local interactive demonstration built with Flutter Scroll World.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PadloTokens.space24),
          PadloCard(
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: PadloTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Reset local demo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Clear the fictional player profile and generated-report state.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PadloTokens.space16),
                OutlinedButton(
                  onPressed: () => _reset(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Reset demo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _ProfileTag extends StatelessWidget {
  const _ProfileTag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: PadloTokens.space16),
    label: Text(text),
    backgroundColor: context.padlo.tint,
    side: BorderSide.none,
  );
}

final class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: context.padlo.tint,
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
