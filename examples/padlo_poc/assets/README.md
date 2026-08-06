# Padlo proof-of-concept assets

- `brand/padlo-logo.png` was retrieved from the official Padlo website for this
  client proof of concept.
- `fonts/Epilogue-VariableFont_wght.ttf` and `fonts/OFL.txt` come from the
  Google Fonts Epilogue family.
- `scene/padlo-pilot.glb` is the committed Blender 5.2 real-time scene produced
  from `tools/blender/generate_padlo_world.py`. It is loaded once by
  `PadloSceneRuntime` and sampled with paused animation clips.

Legacy MP4 and poster directories were removed from the declared asset tree
when the pilot moved to real-time rendering. A local ignored copy is retained
under `build/padlo_legacy_media/` only for rollback comparison; it is never
bundled or deployed.

The Blender world uses no third-party models, photographs, textures, venue
designs, athlete likenesses, or AI-generated assets.
