import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../models/demo_models.dart';
import '../theme/padlo_theme.dart';
import '../widgets/padlo_primitives.dart';

final class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({this.returnPath, super.key});

  final String? returnPath;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

final class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController(text: 'Luka');
  final _lastName = TextEditingController(text: 'Novak');
  final _email = TextEditingController(text: 'luka.novak@example.com');
  PlayerLevel _level = PlayerLevel.intermediate;
  CourtSide _side = CourtSide.right;
  PositioningFocus _focus = PositioningFocus.recoveryTiming;
  bool _submitting = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await PadloScope.of(context).register(
      DemoPlayerProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        level: _level,
        preferredSide: _side,
        focus: _focus,
      ),
    );
    if (!mounted) return;
    final target = widget.returnPath?.startsWith('/app/') == true
        ? widget.returnPath!
        : '/app/home';
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: <Widget>[
            if (wide) const Expanded(flex: 5, child: _RegistrationVisual()),
            Expanded(
              flex: wide ? 6 : 1,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(PadloTokens.space24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const PadloLogo(height: 32),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => context.go('/onboarding'),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Back to tour'),
                              ),
                            ],
                          ),
                          const SizedBox(height: PadloTokens.space48),
                          const SectionHeading(
                            eyebrow: 'Local demo profile',
                            title: 'Set up your court view',
                            description:
                                'This information stays on this device and personalizes the simulated reports.',
                          ),
                          const SizedBox(height: PadloTokens.space32),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stacked = constraints.maxWidth < 520;
                              final first = TextFormField(
                                key: const Key('first-name-field'),
                                controller: _firstName,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'First name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: _requiredName,
                              );
                              final last = TextFormField(
                                key: const Key('last-name-field'),
                                controller: _lastName,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Last name',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: _requiredName,
                              );
                              if (stacked) {
                                return Column(
                                  children: <Widget>[
                                    first,
                                    const SizedBox(height: PadloTokens.space16),
                                    last,
                                  ],
                                );
                              }
                              return Row(
                                children: <Widget>[
                                  Expanded(child: first),
                                  const SizedBox(width: PadloTokens.space16),
                                  Expanded(child: last),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: PadloTokens.space16),
                          TextFormField(
                            key: const Key('email-field'),
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: PadloTokens.space20),
                          _EnumDropdown<PlayerLevel>(
                            label: 'Playing level',
                            value: _level,
                            values: PlayerLevel.values,
                            onChanged: (value) =>
                                setState(() => _level = value),
                          ),
                          const SizedBox(height: PadloTokens.space16),
                          _EnumDropdown<CourtSide>(
                            label: 'Preferred court side',
                            value: _side,
                            values: CourtSide.values,
                            onChanged: (value) => setState(() => _side = value),
                          ),
                          const SizedBox(height: PadloTokens.space24),
                          Text(
                            'What do you want to improve first?',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: PadloTokens.space12),
                          Wrap(
                            spacing: PadloTokens.space8,
                            runSpacing: PadloTokens.space8,
                            children: PositioningFocus.values
                                .map(
                                  (focus) => ChoiceChip(
                                    label: Text(enumLabel(focus)),
                                    selected: _focus == focus,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _focus = focus);
                                      }
                                    },
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: PadloTokens.space32),
                          PadloButton(
                            key: const Key('create-demo-account'),
                            label: 'Create demo account',
                            icon: Icons.arrow_forward_rounded,
                            loading: _submitting,
                            expand: true,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: PadloTokens.space16),
                          Text(
                            'No password. No upload. No data leaves this browser or device.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _requiredName(String? value) {
  if (value == null || value.trim().length < 2) {
    return 'Enter at least 2 characters.';
  }
  return null;
}

String? _validateEmail(String? value) {
  final candidate = value?.trim() ?? '';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(candidate)) {
    return 'Enter a valid email address.';
  }
  return null;
}

final class _EnumDropdown<T extends Enum> extends StatelessWidget {
  const _EnumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: values
        .map(
          (entry) =>
              DropdownMenuItem<T>(value: entry, child: Text(enumLabel(entry))),
        )
        .toList(growable: false),
    onChanged: (entry) {
      if (entry != null) onChanged(entry);
    },
  );
}

final class _RegistrationVisual extends StatelessWidget {
  const _RegistrationVisual();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(PadloTokens.space16),
    decoration: BoxDecoration(
      color: PadloTokens.primary,
      borderRadius: BorderRadius.circular(PadloTokens.radiusLarge),
      image: const DecorationImage(
        image: AssetImage('assets/posters/transition.webp'),
        fit: BoxFit.cover,
        opacity: 0.72,
      ),
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PadloTokens.radiusLarge),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x22101835), Color(0xE4101835)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PadloTokens.space48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: PadloTokens.accent,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(PadloTokens.space16),
                child: Icon(Icons.track_changes, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: PadloTokens.space24),
            Text(
              'Your next match starts with where you stand.',
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: PadloTokens.space16),
            Text(
              'A fictional Slovenian player profile unlocks the complete product demonstration.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFE9ECFB)),
            ),
          ],
        ),
      ),
    ),
  );
}
