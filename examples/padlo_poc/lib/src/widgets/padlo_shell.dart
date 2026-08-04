import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/padlo_theme.dart';
import 'padlo_primitives.dart';

final class PadloShell extends StatelessWidget {
  const PadloShell({
    required this.currentLocation,
    required this.child,
    super.key,
  });

  final String currentLocation;
  final Widget child;

  static const _destinations = <_ShellDestination>[
    _ShellDestination('Home', Icons.home_outlined, '/app/home'),
    _ShellDestination('Analyze', Icons.videocam_outlined, '/app/record'),
    _ShellDestination('Reports', Icons.insights_outlined, '/app/reports'),
    _ShellDestination('Profile', Icons.person_outline, '/app/profile'),
  ];

  int get _selectedIndex {
    if (currentLocation.startsWith('/app/record')) return 1;
    if (currentLocation.startsWith('/app/reports')) return 2;
    if (currentLocation.startsWith('/app/profile')) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    final path = _destinations[index].path;
    if (currentLocation != path) context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 720) return _buildCompact(context);
    return _buildRail(context, extended: width >= 1100);
  }

  Widget _buildCompact(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const PadloLogo(height: 27),
      centerTitle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      actions: <Widget>[
        IconButton(
          tooltip: 'Open profile',
          onPressed: () => context.go('/app/profile'),
          icon: const CircleAvatar(
            radius: 17,
            child: Icon(Icons.person_outline, size: PadloTokens.space20),
          ),
        ),
        const SizedBox(width: PadloTokens.space8),
      ],
    ),
    body: Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          color: context.padlo.tint,
          padding: const EdgeInsets.symmetric(
            horizontal: PadloTokens.space16,
            vertical: PadloTokens.space8,
          ),
          child: const Center(child: ProofOfConceptBadge()),
        ),
        Expanded(child: child),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => _navigate(context, index),
      destinations: _destinations
          .map(
            (destination) => NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(_selectedIcon(destination.icon)),
              label: destination.label,
              tooltip: destination.label,
            ),
          )
          .toList(growable: false),
    ),
  );

  Widget _buildRail(BuildContext context, {required bool extended}) => Scaffold(
    body: Row(
      children: <Widget>[
        NavigationRail(
          extended: extended,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => _navigate(context, index),
          minExtendedWidth: 236,
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(
              PadloTokens.space16,
              PadloTokens.space32,
              PadloTokens.space16,
              PadloTokens.space40,
            ),
            child: PadloLogo(height: extended ? 32 : 28),
          ),
          trailing: Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: PadloTokens.space24),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: extended
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: PadloTokens.space12,
                        ),
                        child: ProofOfConceptBadge(),
                      )
                    : Tooltip(
                        message: 'Proof of concept — simulated data',
                        child: Icon(
                          Icons.science_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            ),
          ),
          destinations: _destinations
              .map(
                (destination) => NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(_selectedIcon(destination.icon)),
                  label: Text(destination.label),
                ),
              )
              .toList(growable: false),
        ),
        VerticalDivider(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Expanded(child: child),
      ],
    ),
  );
}

IconData _selectedIcon(IconData icon) => switch (icon) {
  Icons.home_outlined => Icons.home,
  Icons.videocam_outlined => Icons.videocam,
  Icons.insights_outlined => Icons.insights,
  Icons.person_outline => Icons.person,
  _ => icon,
};

final class _ShellDestination {
  const _ShellDestination(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}
