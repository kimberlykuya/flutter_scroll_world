import 'package:flutter/material.dart';
import 'package:scroll_world/scroll_world.dart';

void main() => runApp(const KenyaInMotionApp());

final _scenes = <ScrollWorldScene>[
  ScrollWorldScene(
    id: 'nairobi',
    title: 'The city starts the journey',
    description:
        'A matatu threads past a rising skyline as the road begins to climb.',
    poster: const AssetImage('assets/posters/nairobi.webp'),
    reducedMotionImage: const AssetImage('assets/posters/nairobi.webp'),
    sources: const ScrollWorldSources(
      mobilePortrait: ScrollWorldSource.asset(
        'assets/videos/nairobi-portrait.mp4',
      ),
      mobileLandscape: ScrollWorldSource.asset(
        'assets/videos/nairobi-landscape.mp4',
      ),
      webStandard: ScrollWorldSource.asset(
        'assets/videos/nairobi-landscape.mp4',
      ),
      webHigh: ScrollWorldSource.asset('assets/videos/nairobi-landscape.mp4'),
    ),
    connectorToNext: const ScrollWorldSources(
      mobilePortrait: ScrollWorldSource.asset(
        'assets/videos/nairobi-highlands-portrait.mp4',
      ),
      webStandard: ScrollWorldSource.asset(
        'assets/videos/nairobi-highlands-landscape.mp4',
      ),
    ),
    scrollExtent: 2,
    transitionExtent: 1,
    linger: 0.45,
  ),
  ScrollWorldScene(
    id: 'highlands',
    title: 'The road climbs into green',
    description:
        'Tea rows follow the contours beneath Mount Kenya and carry the journey onward.',
    poster: const AssetImage('assets/posters/highlands.webp'),
    reducedMotionImage: const AssetImage('assets/posters/highlands.webp'),
    sources: const ScrollWorldSources(
      mobilePortrait: ScrollWorldSource.asset(
        'assets/videos/highlands-portrait.mp4',
      ),
      mobileLandscape: ScrollWorldSource.asset(
        'assets/videos/highlands-landscape.mp4',
      ),
      webStandard: ScrollWorldSource.asset(
        'assets/videos/highlands-landscape.mp4',
      ),
      webHigh: ScrollWorldSource.asset('assets/videos/highlands-landscape.mp4'),
    ),
    connectorToNext: const ScrollWorldSources(
      mobilePortrait: ScrollWorldSource.asset(
        'assets/videos/highlands-coast-portrait.mp4',
      ),
      webStandard: ScrollWorldSource.asset(
        'assets/videos/highlands-coast-landscape.mp4',
      ),
    ),
    scrollExtent: 2,
    transitionExtent: 1,
    linger: 0.45,
  ),
  ScrollWorldScene(
    id: 'coast',
    title: 'The river meets the ocean',
    description:
        'Swahili arches, palms, and a dhow open the final view towards the Indian Ocean.',
    poster: const AssetImage('assets/posters/coast.webp'),
    reducedMotionImage: const AssetImage('assets/posters/coast.webp'),
    sources: const ScrollWorldSources(
      mobilePortrait: ScrollWorldSource.asset(
        'assets/videos/coast-portrait.mp4',
      ),
      mobileLandscape: ScrollWorldSource.asset(
        'assets/videos/coast-landscape.mp4',
      ),
      webStandard: ScrollWorldSource.asset('assets/videos/coast-landscape.mp4'),
      webHigh: ScrollWorldSource.asset('assets/videos/coast-landscape.mp4'),
    ),
    scrollExtent: 2.2,
    transitionExtent: 0,
    linger: 0.45,
    actions: <ScrollWorldAction>[
      ScrollWorldAction.replayReverse(
        id: 'replay-journey',
        label: 'Replay the journey',
        semanticLabel: 'Replay the Kenya journey backwards to Nairobi',
      ),
    ],
  ),
];

class KenyaInMotionApp extends StatelessWidget {
  const KenyaInMotionApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Kenya in Motion',
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFF2B134),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF07130F),
      useMaterial3: true,
    ),
    home: const KenyaInMotionPage(),
  );
}

class KenyaInMotionPage extends StatefulWidget {
  const KenyaInMotionPage({super.key});

  @override
  State<KenyaInMotionPage> createState() => _KenyaInMotionPageState();
}

class _KenyaInMotionPageState extends State<KenyaInMotionPage> {
  String _activeScene = 'nairobi';
  final ScrollWorldController _journeyController = ScrollWorldController();

  @override
  void dispose() {
    _journeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: <Widget>[
        ScrollWorldView(
          scenes: _scenes,
          controller: _journeyController,
          configuration: const ScrollWorldConfiguration(preloadRadius: 1),
          theme: const ScrollWorldTheme(
            backgroundColor: Color(0xFF07130F),
            progressActiveColor: Color(0xFFF2B134),
            overlayPadding: EdgeInsets.fromLTRB(24, 88, 56, 54),
            overlayMaxWidth: 600,
          ),
          overlayBuilder: (context, scene, progress, visibility) =>
              _KenyaSceneOverlay(scene: scene, progress: progress),
          onSceneChanged: (scene, index) {
            if (_activeScene != scene.id) {
              setState(() => _activeScene = scene.id);
            }
          },
          onError: (error) => debugPrint(error.toString()),
          onAction: (scene, action) {
            debugPrint('Scroll World action: ${scene.id}/${action.id}');
          },
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(24, 18, 72, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: Semantics(
              label: 'Kenya in Motion. Active scene: $_activeScene',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'KENYA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      width: 28,
                      child: Divider(color: Color(0xFFF2B134), thickness: 2),
                    ),
                  ),
                  Text(
                    _activeScene.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFDDE6E1),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

final class _SceneDetails {
  const _SceneDetails(this.number, this.location);

  final String number;
  final String location;
}

const _details = <String, _SceneDetails>{
  'nairobi': _SceneDetails('01', 'NAIROBI'),
  'highlands': _SceneDetails('02', 'CENTRAL HIGHLANDS'),
  'coast': _SceneDetails('03', 'KENYAN COAST'),
};

final class _KenyaSceneOverlay extends StatelessWidget {
  const _KenyaSceneOverlay({required this.scene, required this.progress});

  final ScrollWorldScene scene;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final details = _details[scene.id]!;
    final portrait = MediaQuery.sizeOf(context).width < 600;
    final cueOpacity = scene.id == 'nairobi'
        ? ((0.42 - progress) / 0.18).clamp(0.0, 1.0)
        : 0.0;
    final closingOpacity = scene.id == 'coast'
        ? ((progress - 0.62) / 0.18).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      container: true,
      header: true,
      label: '${details.location}. ${scene.title}. ${scene.description}',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: portrait ? 430 : 590),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  details.number,
                  style: const TextStyle(
                    color: Color(0xFFF2B134),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(width: 12),
                const SizedBox(
                  width: 36,
                  child: Divider(color: Color(0xFFF2B134), thickness: 1.5),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    details.location,
                    style: const TextStyle(
                      color: Color(0xFFF1F5F2),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              scene.title!,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontSize: portrait ? 34 : 48,
                fontWeight: FontWeight.w800,
                height: 0.98,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              scene.description!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFE1E8E4),
                fontSize: portrait ? 15 : 17,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
            if (scene.id == 'nairobi') ...<Widget>[
              const SizedBox(height: 24),
              Opacity(
                opacity: cueOpacity,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.south_rounded,
                      color: Color(0xFFF2B134),
                      size: 19,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'SCROLL TO JOURNEY THROUGH KENYA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (scene.id == 'coast') ...<Widget>[
              const SizedBox(height: 24),
              Opacity(
                opacity: closingOpacity,
                child: const Text(
                  'THREE WORLDS  ·  ONE CONTINUOUS SCROLL',
                  style: TextStyle(
                    color: Color(0xFFF2B134),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
