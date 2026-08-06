"""Generate the deterministic Padlo spatial game world in Blender 5.2.

The scene uses only Blender primitives and procedural materials. It contains a
single continuous 480-frame, forward-only journey through one nighttime Padlo
facility. The ten runtime clips are cut from this one camera film.

Example:
  blender --background --factory-startup --python generate_padlo_world.py -- \
    --profile landscape --mode render --output build/padlo_blender
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


SEED = 386
FPS = 24
FINAL_FRAME = 471
SEGMENTS = {
    "first-serve": (1, 48),
    "positioning-lab": (48, 95),
    "decision-gate": (95, 142),
    "player-tunnel": (142, 189),
    "player-setup": (189, 236),
    "clubhouse": (236, 283),
    "analysis-court": (283, 330),
    "report-vault": (330, 377),
    "replay-arena": (377, 424),
    "profile-locker": (424, 471),
}
FOCAL_FRAMES = {
    "first-serve": 30,
    "positioning-lab": 77,
    "decision-gate": 124,
    "player-tunnel": 171,
    "player-setup": 218,
    "clubhouse": 265,
    "analysis-court": 312,
    "report-vault": 359,
    "replay-arena": 406,
    "profile-locker": 453,
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=("landscape", "portrait"), default="landscape")
    parser.add_argument(
        "--mode",
        choices=("validate", "preview", "render", "export"),
        default="validate",
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--frames", default=",".join(str(frame) for frame in FOCAL_FRAMES.values()))
    return parser.parse_args(argv)


def rgba(value: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    value = value.lstrip("#")
    return tuple(int(value[index : index + 2], 16) / 255 for index in (0, 2, 4)) + (alpha,)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)


def material(
    name: str,
    color: str,
    *,
    roughness: float = 0.65,
    metallic: float = 0.0,
    alpha: float = 1.0,
    emission: float = 0.0,
) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    color_value = rgba(color, alpha)
    result.diffuse_color = color_value
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color_value
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Alpha"].default_value = alpha
    # flutter_scene renders glTF transparency in a depth-sorted pass. Keep
    # translucent enclosure panels single-sided to avoid stacking the front
    # and back faces of every thin glass box into an opaque slab.
    result.use_backface_culling = alpha < 1
    if emission > 0:
        emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
        if emission_input:
            emission_input.default_value = color_value
        strength_input = shader.inputs.get("Emission Strength")
        if strength_input:
            strength_input.default_value = emission
    if alpha < 1:
        if hasattr(result, "surface_render_method"):
            result.surface_render_method = "DITHERED"
        elif hasattr(result, "blend_method"):
            result.blend_method = "BLEND"
        if hasattr(result, "use_transparency_overlap"):
            result.use_transparency_overlap = False
    return result


def assign(obj: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    if hasattr(obj.data, "materials"):
        obj.data.materials.append(mat)
    return obj


def box(name: str, location, scale, mat, *, bevel: float = 0.0, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, mat)
    if bevel:
        modifier = obj.modifiers.new("Padlo bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
    return obj


def cylinder(name: str, location, radius: float, depth: float, mat, *, vertices=20, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    return assign(obj, mat)


def sphere(name: str, location, scale, mat, *, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments,
        ring_count=rings,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def cone(name: str, location, radius1: float, radius2: float, depth: float, mat, *, vertices=18):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    return assign(obj, mat)


def mesh(name: str, vertices, faces, mat):
    data = bpy.data.meshes.new(f"{name}_mesh")
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return assign(obj, mat)


def tube(name: str, points, radius: float, mat):
    data = bpy.data.curves.new(name=f"{name}_curve", type="CURVE")
    data.dimensions = "3D"
    data.resolution_u = 3
    data.bevel_depth = radius
    data.bevel_resolution = 2
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for control, point in zip(spline.bezier_points, points):
        control.co = point
        control.handle_left_type = "AUTO"
        control.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return assign(obj, mat)


def parent(child: bpy.types.Object, root: bpy.types.Object) -> None:
    child.parent = root


def show_between(obj: bpy.types.Object, start: int, end: int) -> None:
    base = obj.scale.copy()
    before = max(1, start - 2)
    after = min(FINAL_FRAME, end + 2)
    obj.scale = (0.001, 0.001, 0.001)
    obj.keyframe_insert(data_path="scale", frame=before)
    obj.scale = base
    obj.keyframe_insert(data_path="scale", frame=start)
    obj.keyframe_insert(data_path="scale", frame=end)
    obj.scale = (0.001, 0.001, 0.001)
    obj.keyframe_insert(data_path="scale", frame=after)


def animate_location(obj: bpy.types.Object, points) -> None:
    for frame, location in points:
        obj.location = location
        obj.keyframe_insert(data_path="location", frame=frame)


def build_court(m) -> None:
    box("Ground", (0, 0, -0.55), (16.5, 22.0, 0.5), m["land"], bevel=1.2)
    box("Court_platform", (0, 0, -0.12), (6.4, 11.4, 0.18), m["platform"], bevel=0.35)
    box("Court_surface", (0, 0, 0.08), (5.0, 10.0, 0.08), m["court"], bevel=0.05)

    line_z = 0.18
    box("Court_outer_left", (-4.94, 0, line_z), (0.045, 9.92, 0.018), m["white"])
    box("Court_outer_right", (4.94, 0, line_z), (0.045, 9.92, 0.018), m["white"])
    box("Court_outer_top", (0, 9.92, line_z), (4.98, 0.045, 0.018), m["white"])
    box("Court_outer_bottom", (0, -9.92, line_z), (4.98, 0.045, 0.018), m["white"])
    for y in (-6.95, 6.95):
        box(f"Service_line_{y}", (0, y, line_z), (4.95, 0.035, 0.018), m["white"])
        box(f"Service_center_{y}", (0, (y + (9.9 if y > 0 else -9.9)) / 2, line_z), (0.035, 1.48, 0.018), m["white"])

    # A real open net avoids the opaque wall effect that a single translucent
    # rectangle creates when the camera moves through a low tactical angle.
    net = bpy.data.objects.new("Net", None)
    bpy.context.collection.objects.link(net)
    for index, z in enumerate((0.18, 0.34, 0.50, 0.66, 0.82, 0.98)):
        line = box(f"Net_horizontal_{index}", (0, 0, z), (5.22, 0.018, 0.012), m["net"])
        parent(line, net)
    for index, x in enumerate(value * 0.5 - 5.0 for value in range(21)):
        line = box(f"Net_vertical_{index}", (x, 0, 0.58), (0.012, 0.018, 0.4), m["net"])
        parent(line, net)
    box("Net_band", (0, 0, 1.08), (5.25, 0.05, 0.04), m["white"])
    for x in (-5.15, 5.15):
        cylinder(f"Net_post_{x}", (x, 0, 0.58), 0.09, 1.16, m["ink"], vertices=14)

    # Open blue steel outlines suggest the glass enclosure. Solid translucent
    # boxes are intentionally avoided: on a real-time alpha-sorted renderer,
    # their overlapping front/back faces can become opaque and cover the court.
    for y in (-10.05, 10.05):
        for x in (-3.75, -1.25, 1.25, 3.75):
            box(f"Glass_back_top_{y}_{x}", (x, y, 3.2), (1.22, 0.025, 0.025), m["frame"])
            box(f"Glass_back_mid_{y}_{x}", (x, y, 1.65), (1.22, 0.018, 0.018), m["frame"])
        for x in (-5.05, 5.05):
            cylinder(f"Back_post_{y}_{x}", (x, y, 2.0), 0.055, 4.0, m["frame"], vertices=12)
    for x in (-5.05, 5.05):
        for y in (-7.5, -2.5, 2.5, 7.5):
            box(f"Glass_side_top_{x}_{y}", (x, y, 2.8), (0.025, 2.42, 0.025), m["frame"])
            box(f"Glass_side_mid_{x}_{y}", (x, y, 1.45), (0.018, 2.42, 0.018), m["frame"])
            cylinder(f"Side_post_{x}_{y}", (x, y - 2.45, 2.0), 0.055, 4.0, m["frame"], vertices=12)

    # Court lights frame the night-session atmosphere.
    for index, (x, y) in enumerate(((-8.5, 11.5), (8.5, 11.5))):
        cylinder(f"Light_pole_{index}", (x, y, 3.6), 0.09, 7.2, m["ink"], vertices=12)
        box(f"Light_panel_{index}", (x, y, 7.25), (0.7, 0.15, 0.24), m["light"], bevel=0.08)


def build_slovenian_horizon(m) -> None:
    # Faceted Alpine outline and restrained urban forms. These are abstract
    # regional cues, not replicas of real landmarks or clubs.
    mountains = [
        (-15.5, 15.5, 0.0, 6.0),
        (-10.0, 17.5, 1.0, 8.2),
        (-3.5, 18.0, 0.5, 10.5),
        (3.5, 18.5, 0.6, 8.8),
        (10.0, 17.0, 0.2, 7.2),
        (15.0, 16.0, 0.0, 5.8),
    ]
    for index, (x, y, z, height) in enumerate(mountains):
        y += 24.0
        vertices = [
            (x - 5.2, y + 1.8, z),
            (x + 5.2, y + 1.8, z),
            (x, y, z + height),
            (x - 2.0, y - 0.6, z + height * 0.42),
            (x + 2.4, y - 0.5, z + height * 0.34),
        ]
        faces = [(0, 1, 2), (0, 2, 3), (1, 4, 2)]
        mesh(f"Alpine_peak_{index}", vertices, faces, m["mountain"] if index % 2 else m["mountain_light"])

    buildings = (
        (-12.5, 10.5, 2.4, 2.2, 2.0),
        (-9.0, 12.0, 1.7, 1.8, 3.4),
        (10.0, 11.5, 2.2, 1.8, 2.8),
        (13.0, 9.7, 1.5, 2.0, 3.0),
    )
    for index, (x, y, sx, sy, height) in enumerate(buildings):
        box(f"Ljubljana_form_{index}", (x, y, height / 2), (sx / 2, sy / 2, height / 2), m["building"], bevel=0.18)
        for row in range(2):
            box(f"Ljubljana_window_{index}_{row}", (x, y - sy / 2 - 0.02, 0.8 + row * 1.1), (sx * 0.28, 0.03, 0.15), m["window"], bevel=0.02)

    for index, (x, y, scale) in enumerate(((-13, -8, 1.2), (13, -7, 1.0), (-11.5, 5.0, 0.9), (12.5, 5.5, 1.1))):
        cylinder(f"Tree_trunk_{index}", (x, y, 1.0 * scale), 0.16 * scale, 2.0 * scale, m["wood"], vertices=10)
        cone(f"Tree_crown_{index}_0", (x, y, 2.5 * scale), 1.35 * scale, 0.15, 2.8 * scale, m["pine"])
        cone(f"Tree_crown_{index}_1", (x, y, 3.35 * scale), 1.0 * scale, 0.1, 2.2 * scale, m["pine_light"])


def build_player(name: str, skin, shirt, shorts, position) -> bpy.types.Object:
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    root.location = position

    body = sphere(f"{name}_torso", (0, 0, 1.45), (0.42, 0.3, 0.62), shirt, segments=18, rings=10)
    head = sphere(f"{name}_head", (0, 0, 2.3), (0.3, 0.3, 0.34), skin, segments=18, rings=10)
    hips = sphere(f"{name}_shorts", (0, 0, 0.95), (0.38, 0.3, 0.32), shorts, segments=16, rings=8)
    hair = sphere(f"{name}_hair", (0, 0.02, 2.48), (0.31, 0.29, 0.14), bpy.data.materials["Hair"], segments=16, rings=8)
    for obj in (body, head, hips, hair):
        parent(obj, root)

    for side, x in (("left", -0.2), ("right", 0.2)):
        upper = cylinder(f"{name}_{side}_leg_upper", (x, 0, 0.56), 0.11, 0.65, skin, vertices=12)
        lower = cylinder(f"{name}_{side}_leg_lower", (x, -0.04, 0.18), 0.095, 0.55, skin, vertices=12)
        shoe = sphere(f"{name}_{side}_shoe", (x, -0.13, -0.08), (0.15, 0.25, 0.1), bpy.data.materials["White"], segments=12, rings=6)
        for obj in (upper, lower, shoe):
            parent(obj, root)
    for side, x, angle in (("left", -0.48, -0.28), ("right", 0.48, 0.28)):
        arm = cylinder(
            f"{name}_{side}_arm",
            (x, -0.02, 1.55),
            0.095,
            0.75,
            skin,
            vertices=12,
            rotation=(0, angle, 0),
        )
        parent(arm, root)

    racket = cylinder(f"{name}_racket", (0.74, -0.02, 1.12), 0.27, 0.06, bpy.data.materials["Coral"], vertices=24, rotation=(math.pi / 2, 0, 0))
    handle = cylinder(f"{name}_racket_handle", (0.61, -0.01, 0.82), 0.045, 0.46, bpy.data.materials["Ink"], vertices=10, rotation=(0, 0.38, 0))
    parent(racket, root)
    parent(handle, root)
    return root


def build_players(m) -> list[bpy.types.Object]:
    players = [
        build_player("Luka", m["skin_light"], m["shirt_blue"], m["shorts_dark"], (-2.3, -6.8, 0.28)),
        build_player("Nika", m["skin_warm"], m["shirt_coral"], m["shorts_light"], (2.4, -6.3, 0.28)),
        build_player("Zan", m["skin_deep"], m["shirt_mint"], m["shorts_dark"], (-2.2, 5.8, 0.28)),
        build_player("Maja", m["skin_medium"], m["shirt_white"], m["shorts_blue"], (2.5, 6.2, 0.28)),
    ]
    # The same fictional Slovenian quartet remains present through the court
    # chapters; movement is deterministic and never resets at a clip boundary.
    paths = [
        [(1, (-2.5, -7.2, 0.28)), (48, (-1.8, -4.8, 0.28)), (96, (-2.1, -3.1, 0.28)), (144, (-2.9, -5.8, 0.28)), (240, (-2.0, -4.5, 0.28)), (336, (-1.6, -3.4, 0.28)), (432, (-2.4, -4.8, 0.28)), (480, (-1.8, -3.7, 0.28))],
        [(1, (2.6, -6.3, 0.28)), (48, (2.0, -4.4, 0.28)), (96, (2.3, -3.4, 0.28)), (144, (3.1, -5.6, 0.28)), (240, (2.3, -4.3, 0.28)), (336, (1.9, -3.5, 0.28)), (432, (2.6, -4.6, 0.28)), (480, (2.0, -3.8, 0.28))],
        [(1, (-2.2, 6.0, 0.28)), (96, (-2.0, 4.8, 0.28)), (240, (-2.4, 5.6, 0.28)), (336, (-2.0, 4.2, 0.28)), (480, (-2.5, 4.0, 0.28))],
        [(1, (2.4, 6.4, 0.28)), (96, (2.2, 5.1, 0.28)), (240, (2.5, 5.8, 0.28)), (336, (2.2, 4.4, 0.28)), (480, (2.4, 4.2, 0.28))],
    ]
    for player, path in zip(players, paths):
        animate_location(player, path)
    return players


def build_spatial_facility(m) -> None:
    """Build one connected court, tunnel, hub, vault, arena and locker."""
    # A luminous spine makes the direction of travel legible at every cut.
    box("Facility_spine", (0, 31, -0.02), (7.2, 31.0, 0.14), m["facility"], bevel=0.5)
    for y in range(12, 63, 4):
        box(f"Spine_light_{y}", (0, y, 0.18), (0.07, 1.45, 0.025), m["blue_glow"], bevel=0.03)
    # Glass tunnel ribs physically connect the court to every product location.
    for y in range(12, 61, 4):
        for x in (-6.6, 6.6):
            cylinder(f"Tunnel_post_{x}_{y}", (x, y, 2.5), 0.07, 5.0, m["frame"], vertices=10)
        box(f"Tunnel_arch_{y}", (0, y, 5.0), (6.65, 0.07, 0.08), m["frame"], bevel=0.03)

    # Player setup terminal: the blank surface is reserved for live Flutter UI.
    box("Setup_terminal_body", (-3.2, 16.7, 2.35), (3.0, 0.42, 2.45), m["ink"], bevel=0.35)
    box("Setup_terminal_screen", (-3.2, 16.22, 2.55), (2.6, 0.04, 1.85), m["screen"], bevel=0.22)
    box("Setup_terminal_plinth", (-3.2, 17.1, 0.42), (3.5, 1.2, 0.35), m["platform"], bevel=0.25)

    # Clubhouse portals are physical doors, never dashboard cards.
    for index, (x, label_color) in enumerate(((-4.8, m["blue_glow"]), (-1.6, m["coral_glow"]), (1.6, m["gold_glow"]), (4.8, m["blue_glow"]))):
        box(f"Portal_frame_{index}", (x, 25.5, 2.2), (1.35, 0.25, 2.2), m["frame"], bevel=0.2)
        box(f"Portal_light_{index}", (x, 25.18, 2.2), (1.05, 0.04, 1.78), label_color, bevel=0.16)
    box("Clubhouse_scoreboard", (0, 22.5, 4.8), (4.1, 0.18, 0.8), m["screen"], bevel=0.18)

    # Analysis scanner court and live path rails.
    box("Analysis_court", (0, 32.0, 0.18), (5.0, 5.0, 0.08), m["court"], bevel=0.08)
    for x in (-4.6, -1.5, 1.5, 4.6):
        tube(f"Scanner_beam_{x}", [(x, 28.0, 0.3), (x * 0.55, 32.0, 1.2), (x, 36.0, 0.3)], 0.07, m["blue_glow"])
    box("Analysis_score_surface", (-4.0, 36.8, 3.2), (2.3, 0.12, 1.55), m["screen"], bevel=0.24)

    # Trophy wall with three selectable city tokens.
    box("Vault_wall", (-3.5, 41.5, 2.8), (2.6, 0.35, 2.8), m["ink"], bevel=0.3)
    for index, x in enumerate((-3.5, 0, 3.5)):
        cylinder(f"Match_token_{index}", (x, 41.05, 2.65), 1.05, 0.18, m["gold_glow"] if index == 0 else m["blue_glow"], vertices=32, rotation=(math.pi / 2, 0, 0))
        box(f"Match_token_slot_{index}", (x, 41.2, 0.72), (1.25, 0.3, 0.22), m["platform"], bevel=0.15)

    # Replay arena: a miniature court suspended inside the same building.
    box("Replay_plinth", (0, 49.0, 1.05), (5.8, 5.0, 0.8), m["platform"], bevel=0.45)
    box("Replay_court", (0, 49.0, 1.9), (4.5, 4.1, 0.06), m["court"], bevel=0.08)
    for x, y in ((-2.4, 47.0), (2.1, 47.4), (-2.0, 51.0), (2.5, 51.4)):
        sphere(f"Replay_marker_{x}_{y}", (x, y, 2.15), (0.25, 0.25, 0.25), m["coral_glow"] if y > 50 else m["blue_glow"], segments=12, rings=6)
    tube("Replay_heat_path", [(-3.5, 46.2, 2.12), (-1.5, 48.5, 2.3), (0.2, 50.0, 2.15), (3.4, 52.0, 2.18)], 0.12, m["coral_glow"])

    # Locker wall closes the journey and hosts live profile controls.
    box("Locker_room_wall", (0, 59.0, 3.0), (6.3, 0.4, 3.0), m["ink"], bevel=0.3)
    for index, x in enumerate((-4.5, -2.25, 0, 2.25, 4.5)):
        box(f"Locker_{index}", (x, 58.5, 2.7), (0.92, 0.08, 2.2), m["frame"], bevel=0.12)
        box(f"Locker_signal_{index}", (x, 58.38, 3.7), (0.42, 0.025, 0.08), m["coral_glow"] if index == 2 else m["blue_glow"], bevel=0.03)


def build_analytics(m) -> None:
    coral_zone = box("Net_depth_error_zone", (0, -5.9, 0.24), (4.65, 1.25, 0.035), m["coral_transparent"], bevel=0.18)
    blue_zone = box("Net_depth_pressure_zone", (0, -3.05, 0.25), (4.65, 1.15, 0.04), m["blue_glow"], bevel=0.18)
    show_between(coral_zone, 35, 108)
    show_between(blue_zone, 48, 118)
    late_path = tube("Late_recovery_path", [(-2.1, -3.0, 0.35), (-3.4, -4.6, 0.45), (-3.0, -6.5, 0.35)], 0.11, m["coral_glow"])
    correct_path = tube("Correct_recovery_path", [(-2.0, -3.0, 0.38), (-2.25, -4.0, 0.48), (-2.0, -4.8, 0.38)], 0.11, m["blue_glow"])
    show_between(late_path, 55, 126)
    show_between(correct_path, 72, 144)
    gap_good = tube("Spacing_gap_good", [(-2.1, -4.65, 1.15), (2.2, -4.65, 1.15)], 0.09, m["blue_glow"])
    show_between(gap_good, 72, 150)
    attack = tube("Decision_attack", [(-3.8, -7.2, 0.4), (-3.1, -5.0, 0.5), (-2.0, -3.6, 0.4)], 0.1, m["blue_glow"])
    hold = tube("Decision_hold", [(0.0, -7.2, 0.42), (0.0, -5.6, 0.48), (0.0, -4.5, 0.42)], 0.1, m["gold_glow"])
    recover = tube("Decision_recover", [(3.8, -4.0, 0.4), (3.2, -5.3, 0.5), (2.3, -6.7, 0.4)], 0.1, m["coral_glow"])
    for obj in (attack, hold, recover):
        show_between(obj, 95, 155)

    ball = sphere("Padel_ball", (0, 0, 1.5), (0.105, 0.105, 0.105), m["ball"], segments=18, rings=10)
    animate_location(ball, [(1, (-3.2, -6.0, 1.1)), (48, (2.4, -2, 4.4)), (95, (-2.5, 2, 1.2)), (142, (2.3, 8, 2.8)), (189, (-2.4, 14, 3.0)), (236, (2.5, 22, 3.0)), (283, (-2.5, 30, 3.0)), (330, (2.4, 39, 3.2)), (377, (-2.5, 47, 3.0)), (424, (2.4, 55, 3.0)), (471, (-2.0, 59, 4.4))])


def setup_camera(profile: str) -> None:
    data = bpy.data.cameras.new("Padlo_camera")
    camera = bpy.data.objects.new("Padlo_camera", data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    data.lens = 48 if profile == "landscape" else 42

    target = bpy.data.objects.new("Camera_target", None)
    bpy.context.collection.objects.link(target)
    constraint = camera.constraints.new(type="TRACK_TO")
    constraint.target = target
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"

    # Every key advances along +Y. Small lateral arcs add drama without ever
    # reversing the journey or breaking spatial continuity.
    landscape = [
        (1, (7.5, -24.0, 9.5), (0.0, -12.0, 1.2)),
        (30, (5.8, -18.0, 7.1), (0.0, -7.0, 1.0)),
        (48, (4.5, -14.0, 6.2), (0.0, -4.0, 1.1)),
        (77, (-4.2, -9.0, 5.4), (0.0, -1.0, 1.0)),
        (95, (-4.0, -6.0, 5.1), (0.0, 2.0, 1.0)),
        (124, (3.8, -2.0, 4.8), (0.0, 5.0, 1.2)),
        (142, (4.8, 1.0, 4.7), (0.0, 9.0, 1.4)),
        (160, (6.0, 8.5, 4.4), (0.0, 15.0, 2.4)),
        (171, (3.8, 10.5, 4.2), (-3.2, 16.5, 2.5)),
        (189, (3.6, 11.5, 4.1), (-3.2, 16.5, 2.5)),
        (218, (3.4, 12.2, 3.8), (-3.2, 16.5, 2.5)),
        (236, (5.6, 14.0, 4.0), (0.0, 20.0, 2.4)),
        (250, (6.1, 19.0, 4.2), (0.0, 25.0, 2.3)),
        (265, (4.5, 20.2, 4.3), (0.0, 25.5, 2.2)),
        (283, (5.8, 24.0, 4.5), (0.0, 30.0, 1.8)),
        (312, (6.0, 27.0, 5.4), (0.0, 32.0, 1.3)),
        (330, (5.8, 32.0, 4.5), (0.0, 38.0, 2.2)),
        (359, (5.5, 34.5, 4.5), (0.0, 41.5, 2.6)),
        (377, (6.0, 39.0, 4.8), (0.0, 46.0, 2.2)),
        (406, (6.0, 43.0, 6.4), (0.0, 49.0, 1.9)),
        (424, (6.0, 47.0, 5.4), (0.0, 54.0, 2.4)),
        (453, (5.5, 52.0, 4.5), (0.0, 59.0, 2.8)),
        (471, (5.4, 54.0, 4.2), (0.0, 59.0, 2.8)),
    ]
    positions = []
    for frame, location, focus in landscape:
        if profile == "portrait":
            positions.append((frame, (location[0] * 0.42, location[1] - 1.8, location[2] + 2.8), (focus[0] * 0.55, focus[1], focus[2] + 0.45)))
        else:
            positions.append((frame, location, focus))
    for frame, location, focus in positions:
        camera.location = location
        target.location = focus
        camera.keyframe_insert(data_path="location", frame=frame)
        target.keyframe_insert(data_path="location", frame=frame)


def configure_scene(profile: str, output: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = ((960, 540) if profile == "landscape" else (540, 960))
    # Runtime portrait media is 405x720; rendering that composition directly
    # avoids spending minutes compressing pixels that the encoder discards.
    scene.render.resolution_percentage = 100 if profile == "landscape" else 75
    scene.render.fps = FPS
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 0
    scene.render.film_transparent = False
    scene.frame_start = 1
    scene.frame_end = FINAL_FRAME
    if hasattr(scene.render, "use_motion_blur"):
        scene.render.use_motion_blur = False
    scene.render.filepath = str(output / profile / "frames" / "frame_")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = rgba("#050713")
    background.inputs["Strength"].default_value = 0.12
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass

    sun_data = bpy.data.lights.new(name="Adriatic_sun", type="SUN")
    sun_data.energy = 1.2
    sun_data.color = rgba("#6E8CFF")[:3]
    sun_data.angle = math.radians(14)
    sun = bpy.data.objects.new(name="Adriatic_sun", object_data=sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(33), math.radians(-18), math.radians(-28))

    area_data = bpy.data.lights.new(name="Court_fill", type="AREA")
    area_data.energy = 1250
    area_data.shape = "RECTANGLE"
    area_data.size = 16
    area_data.color = rgba("#BBC3F3")[:3]
    area = bpy.data.objects.new(name="Court_fill", object_data=area_data)
    bpy.context.collection.objects.link(area)
    area.location = (0, 18, 13)
    area.rotation_euler = (0, 0, 0)


def build_world(profile: str, output: Path) -> None:
    random.seed(SEED)
    clear_scene()
    mats = {
        "court": material("Court blue", "#162D91", roughness=0.62, emission=0.08),
        "platform": material("Court surround", "#202A43", roughness=0.72, metallic=0.12),
        "facility": material("Facility floor", "#090D18", roughness=0.5, metallic=0.25),
        "screen": material("Blank live surface", "#111A33", roughness=0.35, metallic=0.18, emission=0.12),
        "land": material("Slovenian night green", "#152D2A", roughness=0.9),
        "white": material("White", "#F8FAFF"),
        "ink": material("Ink", "#14181B"),
        "net": material("Net", "#252B38", roughness=0.8, alpha=0.78),
        "frame": material("Padlo frame", "#2139C5", metallic=0.25),
        # Court glass should read as a faint blue reflection, never as a wall.
        # Several panels overlap along the camera path, so a deliberately low
        # source alpha is required for the real-time renderer.
        "glass": material("Glass", "#A7D6E8", roughness=0.12, alpha=0.035),
        "light": material("Court light", "#FFF3D7", emission=2.2),
        "mountain": material("Alpine deep", "#101B2A"),
        "mountain_light": material("Alpine light", "#172C3C"),
        "building": material("Ljubljana stone", "#192337"),
        "window": material("Window", "#6E8CFF", metallic=0.08, emission=0.35),
        "wood": material("Tree wood", "#6D4D3C"),
        "pine": material("Pine", "#295F4A"),
        "pine_light": material("Pine light", "#477B58"),
        "skin_light": material("Skin light", "#E8B894"),
        "skin_warm": material("Skin warm", "#C8875F"),
        "skin_medium": material("Skin medium", "#A9684B"),
        "skin_deep": material("Skin deep", "#70462F"),
        "shirt_blue": material("Shirt blue", "#466AED"),
        "shirt_coral": material("Shirt coral", "#EE8B60"),
        "shirt_mint": material("Shirt mint", "#75BDA7"),
        "shirt_white": material("Shirt white", "#F2F2F2"),
        "shorts_dark": material("Shorts dark", "#202634"),
        "shorts_light": material("Shorts light", "#E4E7ED"),
        "shorts_blue": material("Shorts blue", "#2139C5"),
        "ball": material("Padel ball", "#D6E948", emission=0.35),
        "coral_transparent": material("Coral zone", "#EE8B60", alpha=0.55, emission=0.25),
        "coral_glow": material("Coral", "#EE8B60", emission=0.9),
        "blue_glow": material("Blue", "#6E8CFF", emission=1.1),
        "gold_glow": material("Gold", "#F3C85D", emission=0.8),
    }
    # Named material lookups used by the player helper.
    for name, mat in (("Hair", material("Hair", "#332921")), ("Coral", mats["coral_glow"]), ("Ink", mats["ink"]), ("White", mats["white"])):
        if bpy.data.materials.get(name) is None:
            mat.name = name
    build_court(mats)
    build_slovenian_horizon(mats)
    build_players(mats)
    build_spatial_facility(mats)
    build_analytics(mats)
    setup_camera(profile)
    configure_scene(profile, output)


def validate(profile: str, output: Path) -> dict:
    scene = bpy.context.scene
    required = [
        "Court_surface",
        "Net",
        "Luka",
        "Nika",
        "Zan",
        "Maja",
        "Net_depth_pressure_zone",
        "Late_recovery_path",
        "Spacing_gap_good",
        "Decision_attack",
        "Setup_terminal_screen",
        "Clubhouse_scoreboard",
        "Analysis_court",
        "Vault_wall",
        "Replay_court",
        "Locker_room_wall",
    ]
    missing = [name for name in required if name not in scene.objects]
    polygons = sum(len(obj.data.polygons) for obj in scene.objects if obj.type == "MESH")
    metadata = {
        "blender": bpy.app.version_string,
        "seed": SEED,
        "profile": profile,
        "resolution": [scene.render.resolution_x, scene.render.resolution_y],
        "fps": scene.render.fps,
        "frame_range": [scene.frame_start, scene.frame_end],
        "segments": {name: list(value) for name, value in SEGMENTS.items()},
        "focal_frames": FOCAL_FRAMES,
        "objects": len(scene.objects),
        "materials": len(bpy.data.materials),
        "mesh_polygons": polygons,
        "missing_required_objects": missing,
    }
    if missing:
        raise RuntimeError(f"Missing required objects: {missing}")
    if polygons >= 45000:
        raise RuntimeError(f"Polygon budget exceeded: {polygons}")
    directory = output / profile
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "scene_metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print("PADLO_WORLD_VALIDATION=" + json.dumps(metadata, sort_keys=True))
    return metadata


def render_preview(profile: str, output: Path, frames: list[int]) -> None:
    directory = output / profile / "preview"
    directory.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    for frame in frames:
        scene.frame_set(frame)
        scene.render.filepath = str(directory / f"frame_{frame:04d}.png")
        bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / profile / f"padlo-world-{profile}.blend"))


def render_animation(profile: str, output: Path) -> None:
    directory = output / profile / "frames"
    directory.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.filepath = str(directory / "frame_")
    bpy.ops.wm.save_as_mainfile(filepath=str(output / profile / f"padlo-world-{profile}.blend"))
    bpy.ops.render.render(animation=True)


def export_scene(profile: str, output: Path) -> None:
    """Export the authored connected world for the real-time pilot."""
    directory = output / profile
    directory.mkdir(parents=True, exist_ok=True)
    filepath = directory / f"padlo-pilot-{profile}.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(directory / f"padlo-world-{profile}.blend"))
    bpy.ops.export_scene.gltf(
        filepath=str(filepath),
        export_format="GLB",
        export_animations=True,
        export_cameras=True,
        # Eevee and flutter_scene do not share the same physical light-energy
        # scale. Exporting the Blender sun clips the blue court to white in
        # WebGL, so runtime lighting is controlled by flutter_scene instead.
        export_lights=False,
        export_materials="EXPORT",
        export_apply=True,
    )
    print(f"PADLO_SCENE_EXPORT={filepath}")


def main() -> None:
    args = parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    build_world(args.profile, output)
    validate(args.profile, output)
    if args.mode == "preview":
        render_preview(args.profile, output, [int(value) for value in args.frames.split(",") if value.strip()])
    elif args.mode == "render":
        render_animation(args.profile, output)
    elif args.mode == "export":
        export_scene(args.profile, output)


if __name__ == "__main__":
    main()
