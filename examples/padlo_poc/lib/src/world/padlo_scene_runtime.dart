import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../theme/padlo_theme.dart';

typedef PadloChoiceCallback = void Function(String choice);

final class PadloSceneRuntime {
  PadloSceneRuntime({this.onChoice}) : _scene = _tryCreateScene();

  @visibleForTesting
  PadloSceneRuntime.withoutRenderer({this.onChoice}) : _scene = null;

  static const _assetPath = 'assets/scene/padlo-pilot.glb';
  static const _pilotEndFrame = 155.0;
  static const _sourceEndFrame = 471.0;

  final PadloChoiceCallback? onChoice;
  final Scene? _scene;
  final List<_BoundClip> _clips = <_BoundClip>[];
  final List<_CameraKeyframe> _cameraKeyframes = <_CameraKeyframe>[
    _CameraKeyframe(
      frame: 1,
      position: _fromBlender(7.5, -24, 9.5),
      target: _fromBlender(0, -12, 1.2),
    ),
    _CameraKeyframe(
      frame: 30,
      position: _fromBlender(5.8, -18, 7.1),
      target: _fromBlender(0, -7, 1),
    ),
    _CameraKeyframe(
      frame: 48,
      position: _fromBlender(4.5, -14, 6.2),
      target: _fromBlender(0, -4, 1.1),
    ),
    _CameraKeyframe(
      frame: 77,
      position: _fromBlender(-4.2, -9, 5.4),
      target: _fromBlender(0, -1, 1),
    ),
    _CameraKeyframe(
      frame: 95,
      position: _fromBlender(-4, -6, 5.1),
      target: _fromBlender(0, 2, 1),
    ),
    _CameraKeyframe(
      frame: 124,
      position: _fromBlender(3.8, -2, 4.8),
      target: _fromBlender(0, 5, 1.2),
    ),
    _CameraKeyframe(
      frame: 142,
      position: _fromBlender(4.8, 1, 4.7),
      target: _fromBlender(0, 9, 1.4),
    ),
    _CameraKeyframe(
      frame: 155,
      position: _fromBlender(6, 5, 4.5),
      target: _fromBlender(0, 12, 1.8),
    ),
  ];

  Node? _root;
  Size _viewportSize = Size.zero;
  bool _loaded = false;
  bool _failed = false;
  bool _reducedMotion = false;

  bool get isLoaded => _loaded;
  bool get hasFailed => _failed;
  bool get canRender => _scene != null;
  Scene get scene => _scene!;
  Node? get root => _root;
  Size get viewportSize => _viewportSize;

  void resize(Size size) {
    _viewportSize = size;
  }

  Future<void> load() async {
    if (_loaded || _failed) return;
    if (_scene == null) {
      _failed = true;
      throw StateError('WebGL2/Impeller is unavailable for the Padlo scene.');
    }
    try {
      final root = await Node.fromGlbAsset(_assetPath);
      root.name = 'PadloPilotWorld';
      _root = root;
      _scene.add(root);
      for (final animation in root.parsedAnimations) {
        final clip = root.createAnimationClip(animation)..pause();
        _clips.add(_BoundClip(clip: clip, endTime: animation.endTime));
      }
      _addAccessibilitySemantics();
      _loaded = true;
    } on Object {
      _failed = true;
      rethrow;
    }
  }

  Future<void> recover() async {
    if (_loaded) return;
    _scene?.removeAll();
    _root = null;
    _clips.clear();
    _failed = false;
    await load();
  }

  void setReducedMotion(bool value) {
    _reducedMotion = value;
  }

  void seek(double normalizedProgress) {
    final value = normalizedProgress.clamp(0.0, 1.0).toDouble();
    final authored = _reducedMotion ? _reducedCameraProgress(value) : value;
    final sourceProgress = authored * _pilotEndFrame / _sourceEndFrame;
    for (final bound in _clips) {
      bound.clip.pause();
      bound.clip.seek(bound.endTime * sourceProgress);
    }
  }

  PerspectiveCamera cameraFor(double normalizedProgress) {
    final value = normalizedProgress.clamp(0.0, 1.0).toDouble();
    final authored = _reducedMotion ? _reducedCameraProgress(value) : value;
    final frame = 1 + authored * (_pilotEndFrame - 1);
    for (var index = 0; index < _cameraKeyframes.length - 1; index++) {
      final left = _cameraKeyframes[index];
      final right = _cameraKeyframes[index + 1];
      if (frame <= right.frame) {
        final amount = ((frame - left.frame) / (right.frame - left.frame))
            .clamp(0.0, 1.0)
            .toDouble();
        return PerspectiveCamera(
          position: _lerp(left.position, right.position, amount),
          target: _lerp(left.target, right.target, amount),
          fovRadiansY: _blenderVerticalFieldOfView,
        );
      }
    }
    final last = _cameraKeyframes.last;
    return PerspectiveCamera(
      position: last.position.clone(),
      target: last.target.clone(),
      fovRadiansY: _blenderVerticalFieldOfView,
    );
  }

  void addChoicePanels() {
    if (!_loaded || _root == null) return;
    _addChoicePanel(
      id: 'PositioningChoicePanel',
      title: 'Positioning lab',
      subtitle: 'Choose the pressure zone',
      choices: const <String>['Pressure zone', 'Error band'],
      position: vm.Vector3(5.8, -2.4, 2.1),
    );
    _addChoicePanel(
      id: 'DecisionChoicePanel',
      title: 'Decision gate',
      subtitle: 'Read the next ball',
      choices: const <String>['Attack', 'Hold', 'Recover'],
      position: vm.Vector3(5.6, 5.6, 2.2),
    );
  }

  Node? node(String name) => _root?.getChildByName(name);

  void _addAccessibilitySemantics() {
    final zones = <({String node, String label, String choice})>[
      (
        node: 'Net_depth_pressure_zone',
        label: 'Blue pressure zone',
        choice: 'Pressure zone',
      ),
      (
        node: 'Net_depth_error_zone',
        label: 'Coral error band',
        choice: 'Error band',
      ),
      (node: 'Decision_attack', label: 'Attack path', choice: 'Attack'),
      (node: 'Decision_hold', label: 'Hold path', choice: 'Hold'),
      (node: 'Decision_recover', label: 'Recover path', choice: 'Recover'),
    ];
    for (final zone in zones) {
      final target = node(zone.node);
      if (target == null) continue;
      target.addComponent(
        SemanticsComponent(
          label: zone.label,
          hint: 'Activate to choose this coaching response',
          button: true,
          onTap: () => onChoice?.call(zone.choice),
        ),
      );
    }
  }

  void _addChoicePanel({
    required String id,
    required String title,
    required String subtitle,
    required List<String> choices,
    required vm.Vector3 position,
  }) {
    final panel = Node(
      name: id,
      localTransform: vm.Matrix4.translation(
        _fromBlender(position.x, position.y, position.z),
      ),
    );
    panel.addComponent(
      WidgetComponent(
        size: const Size(330, 220),
        worldHeight: 2.25,
        occlusionHiding: true,
        child: _ChoicePanel(
          title: title,
          subtitle: subtitle,
          choices: choices,
          onChoice: onChoice,
        ),
      ),
    );
    _scene!.add(panel);
  }

  double _reducedCameraProgress(double progress) {
    if (progress < 0.32) return 0.14;
    if (progress < 0.68) return 0.5;
    return 0.86;
  }

  static vm.Vector3 _lerp(vm.Vector3 a, vm.Vector3 b, double amount) =>
      vm.Vector3(
        a.x + (b.x - a.x) * amount,
        a.y + (b.y - a.y) * amount,
        a.z + (b.z - a.z) * amount,
      );

  // Blender authors this world with Z-up coordinates. glTF (and
  // flutter_scene) use Y-up coordinates, so Blender's +Y becomes glTF's -Z.
  // Passing the raw Blender vectors places the camera below the facility and
  // makes the Slovenian landscape plane fill the entire viewport.
  static vm.Vector3 _fromBlender(double x, double y, double z) =>
      vm.Vector3(x, z, -y);

  // Blender's 48 mm lens on a 36 mm sensor is roughly a 23.4 degree vertical
  // field of view at 16:9. Matching it keeps the live render composition
  // aligned with the authored camera previews.
  static const double _blenderVerticalFieldOfView = 0.408;

  void dispose() {
    _clips.clear();
    _scene?.removeAll();
    _root = null;
    _loaded = false;
  }

  static Scene? _tryCreateScene() {
    try {
      final scene = Scene()
        // Blender's AgX preview is substantially darker than flutter_scene's
        // default neutral exposure. Match the authored night-session look
        // instead of bleaching the blue court and Alpine geometry.
        ..exposure = 0.52
        ..environmentIntensity = 0.38;
      scene.ambientOcclusion
        ..enabled = true
        ..radius = 0.55
        ..intensity = 1.35;
      return scene;
    } on Object catch (error, stackTrace) {
      debugPrint('Padlo scene backend unavailable: $error\n$stackTrace');
      return null;
    }
  }
}

final class _BoundClip {
  const _BoundClip({required this.clip, required this.endTime});

  final AnimationClip clip;
  final double endTime;
}

final class _CameraKeyframe {
  const _CameraKeyframe({
    required this.frame,
    required this.position,
    required this.target,
  });

  final int frame;
  final vm.Vector3 position;
  final vm.Vector3 target;
}

final class _ChoicePanel extends StatelessWidget {
  const _ChoicePanel({
    required this.title,
    required this.subtitle,
    required this.choices,
    required this.onChoice,
  });

  final String title;
  final String subtitle;
  final List<String> choices;
  final PadloChoiceCallback? onChoice;

  @override
  Widget build(BuildContext context) => Material(
    color: PadloTokens.darkSurface.withValues(alpha: 0.96),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ...choices.map(
            (choice) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                width: double.infinity,
                height: 34,
                child: OutlinedButton(
                  onPressed: () => onChoice?.call(choice),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: PadloTokens.accent.withValues(alpha: 0.75),
                    ),
                  ),
                  child: Text(choice),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
