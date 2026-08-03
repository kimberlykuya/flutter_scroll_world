"""Generate the deterministic low-poly Kenya in Motion world in Blender.

Run through Blender, not the system Python:

  blender --background --factory-startup --python generate_kenya_world.py -- \
    --profile landscape --mode preview --output build/blender

The scene is built entirely from Blender primitives. No external models, fonts,
textures, or network resources are required.
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


SEED = 254
FPS = 24
FINAL_FRAME = 284
SEGMENTS = {
    "nairobi": (1, 72),
    "nairobi-highlands": (72, 107),
    "highlands": (107, 178),
    "highlands-coast": (178, 213),
    "coast": (213, 284),
}
FOCAL_FRAMES = {"nairobi": 36, "highlands": 142, "coast": 248}


def hex_color(value: str) -> tuple[float, float, float, float]:
    value = value.lstrip("#")
    return tuple(int(value[index : index + 2], 16) / 255 for index in (0, 2, 4)) + (1.0,)


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=("landscape", "portrait"), default="landscape")
    parser.add_argument("--mode", choices=("validate", "preview", "render"), default="validate")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--frames", default="36,142,248")
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name: str, color: str, *, roughness: float = 0.72, metallic: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    rgba = hex_color(color)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def assign(obj: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    if hasattr(obj.data, "materials"):
        obj.data.materials.append(mat)
    return obj


def smooth(obj: bpy.types.Object) -> None:
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True


def box(name: str, location, scale, mat, *, bevel: float = 0.0, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, mat)
    if bevel > 0:
        modifier = obj.modifiers.new("Soft edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    return obj


def cylinder(name: str, location, radius: float, depth: float, mat, *, vertices=24, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    assign(obj, mat)
    return obj


def sphere(name: str, location, scale, mat, *, segments=20, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, mat)
    smooth(obj)
    return obj


def cone(name: str, location, radius1: float, radius2: float, depth: float, mat, *, vertices=20, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    assign(obj, mat)
    return obj


def mesh_object(name: str, vertices, faces, mat):
    mesh = bpy.data.meshes.new(f"{name}_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    return obj


def curve_tube(name: str, points, radius: float, mat, *, cyclic=False, resolution=2):
    curve_data = bpy.data.curves.new(name=f"{name}_curve", type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = resolution
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 1
    spline = curve_data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for control, point in zip(spline.bezier_points, points):
        control.co = point
        control.handle_left_type = "AUTO"
        control.handle_right_type = "AUTO"
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    return obj


def ribbon(name: str, points, widths, z: float, mat):
    vertices = []
    for index, (x, y) in enumerate(points):
        previous = Vector(points[max(0, index - 1)])
        following = Vector(points[min(len(points) - 1, index + 1)])
        direction = (following - previous).normalized()
        normal = Vector((-direction.y, direction.x))
        half = widths[index] / 2
        vertices.extend(((x + normal.x * half, y + normal.y * half, z), (x - normal.x * half, y - normal.y * half, z)))
    faces = [(index * 2, index * 2 + 1, index * 2 + 3, index * 2 + 2) for index in range(len(points) - 1)]
    return mesh_object(name, vertices, faces, mat)


def tree(prefix: str, x: float, y: float, z: float, trunk, leaf, *, scale=1.0, acacia=False):
    cylinder(f"{prefix}_trunk", (x, y, z + 1.2 * scale), 0.18 * scale, 2.4 * scale, trunk, vertices=10)
    if acacia:
        sphere(f"{prefix}_canopy_a", (x - 0.45 * scale, y, z + 2.65 * scale), (1.25 * scale, 0.72 * scale, 0.32 * scale), leaf, segments=14, rings=7)
        sphere(f"{prefix}_canopy_b", (x + 0.55 * scale, y, z + 2.7 * scale), (1.15 * scale, 0.65 * scale, 0.3 * scale), leaf, segments=14, rings=7)
    else:
        for index, offset in enumerate(((-0.45, 0.0, 0.0), (0.4, 0.12, 0.15), (0.0, -0.25, 0.55))):
            sphere(f"{prefix}_canopy_{index}", (x + offset[0] * scale, y + offset[1] * scale, z + (2.55 + offset[2]) * scale), (0.78 * scale, 0.7 * scale, 0.65 * scale), leaf, segments=14, rings=7)


def palm(prefix: str, x: float, y: float, z: float, trunk, leaf, *, scale=1.0):
    cylinder(f"{prefix}_trunk", (x, y, z + 1.8 * scale), 0.16 * scale, 3.6 * scale, trunk, vertices=10, rotation=(0.08, -0.06, 0.0))
    crown_z = z + 3.65 * scale
    for index in range(7):
        angle = index * math.tau / 7
        direction = Vector((math.cos(angle), math.sin(angle), -0.22))
        perpendicular = Vector((-math.sin(angle), math.cos(angle), 0.0))
        center = Vector((x, y, crown_z))
        tip = center + direction * (2.0 * scale)
        left = center + direction * (0.85 * scale) + perpendicular * (0.32 * scale)
        right = center + direction * (0.85 * scale) - perpendicular * (0.32 * scale)
        mesh_object(f"{prefix}_frond_{index}", [center, left, tip, right], [(0, 1, 2, 3)], leaf)


def build_nairobi(m):
    box("Nairobi_base", (0, -21, -0.45), (10.5, 10.2, 0.55), m["earth"], bevel=1.0)

    road_points = [(0.0, -35), (-1.0, -29), (0.8, -23), (-0.2, -16), (1.0, -9), (0.0, -3), (-0.4, 5)]
    ribbon("Journey_road", road_points, [3.2, 3.0, 2.8, 2.5, 2.2, 1.8, 1.5], 0.18, m["road"])
    for y in (-31, -27.5, -24, -20.5, -17):
        box(f"Nairobi_lane_{y}", (0.0, y, 0.23), (0.08, 0.65, 0.035), m["gold"], bevel=0.03)

    # KICC-inspired cylindrical landmark.
    cylinder("Nairobi_KICC_tower", (0.2, -20.8, 3.6), 1.25, 6.5, m["terracotta"], vertices=28)
    for level in range(5):
        cylinder(f"Nairobi_KICC_band_{level}", (0.2, -20.8, 1.2 + level * 1.15), 1.29, 0.12, m["gold"], vertices=28)
    cylinder("Nairobi_KICC_crown", (0.2, -20.8, 7.1), 1.75, 0.38, m["cream"], vertices=28)
    cylinder("Nairobi_KICC_roof", (0.2, -20.8, 7.5), 1.1, 0.48, m["gold"], vertices=24)

    buildings = [
        (-5.8, -20.0, 1.8, 1.5, 1.6, 3.6, "teal"),
        (-3.8, -16.8, 1.6, 1.35, 1.3, 3.2, "cream"),
        (4.3, -19.0, 2.4, 1.5, 1.6, 4.8, "clay"),
        (6.2, -23.4, 1.6, 1.25, 1.25, 3.2, "gold"),
        (-5.4, -25.2, 1.25, 1.5, 1.2, 2.5, "coral"),
        (4.4, -26.2, 1.35, 1.8, 1.3, 2.7, "teal"),
        (7.0, -17.0, 1.1, 1.35, 1.1, 2.2, "cream"),
    ]
    for index, (x, y, half_z, sx, sy, height, color) in enumerate(buildings):
        box(f"Nairobi_building_{index}", (x, y, height / 2), (sx / 2, sy / 2, height / 2), m[color], bevel=0.18)
        for row in range(max(1, int(height))):
            box(f"Nairobi_window_{index}_{row}", (x, y - sy / 2 - 0.015, 0.65 + row * 0.75), (sx * 0.28, 0.035, 0.12), m["window"], bevel=0.02)

    # A bright, generic matatu with no brand marks.
    box("Nairobi_matatu_body", (-1.15, -27.1, 0.85), (0.75, 1.25, 0.62), m["matatu"], bevel=0.22)
    box("Nairobi_matatu_roof", (-1.15, -27.1, 1.52), (0.7, 1.1, 0.14), m["cream"], bevel=0.1)
    box("Nairobi_matatu_windshield", (-1.15, -28.36, 1.05), (0.5, 0.03, 0.28), m["window"], bevel=0.03)
    for dx in (-0.72, 0.72):
        for dy in (-0.72, 0.72):
            cylinder(f"Nairobi_matatu_wheel_{dx}_{dy}", (-1.15 + dx, -27.1 + dy, 0.45), 0.26, 0.16, m["charcoal"], vertices=14, rotation=(0.0, math.pi / 2, 0.0))

    for index, (x, y) in enumerate(((-7.8, -27.0), (7.7, -27.0), (-7.5, -14.5), (7.3, -14.2))):
        cylinder(f"Nairobi_light_pole_{index}", (x, y, 1.5), 0.08, 3.0, m["charcoal"], vertices=10)
        sphere(f"Nairobi_light_{index}", (x, y, 3.05), (0.22, 0.22, 0.22), m["gold"], segments=12, rings=6)
    tree("Nairobi_acacia_west", -8.2, -22.8, 0.1, m["trunk"], m["leaf_dark"], scale=0.9, acacia=True)
    tree("Nairobi_acacia_east", 8.1, -20.6, 0.1, m["trunk"], m["leaf"], scale=0.8, acacia=True)


def hill_height(x: float, y: float) -> float:
    return 0.55 + 1.25 * math.exp(-((x / 8.5) ** 2 + ((y - 0.5) / 7.5) ** 2))


def build_highlands(m):
    sphere("Highlands_hill_west", (-5.2, -0.5, -1.7), (8.8, 7.3, 3.0), m["highland_dark"], segments=28, rings=14)
    sphere("Highlands_hill_east", (5.7, 2.0, -1.5), (8.5, 7.0, 2.7), m["highland"], segments=28, rings=14)
    sphere("Highlands_hill_far", (0.0, 7.8, -1.8), (10.0, 5.4, 3.0), m["highland_light"], segments=28, rings=14)

    for row, y in enumerate([value * 0.75 - 4.0 for value in range(12)]):
        points = []
        for step in range(15):
            x = -8.0 + step * (16.0 / 14)
            points.append((x, y + math.sin(x * 0.35 + row) * 0.18, hill_height(x, y) + 0.28))
        curve_tube(f"Highlands_tea_row_{row:02d}", points, 0.11, m["tea"] if row % 2 else m["tea_light"])

    # Farmhouse and gable.
    box("Highlands_farmhouse", (-5.7, 4.9, 1.45), (1.7, 1.35, 1.25), m["cream"], bevel=0.12)
    roof_vertices = [(-7.6, 3.35, 2.6), (-3.8, 3.35, 2.6), (-5.7, 3.35, 4.0), (-7.6, 6.45, 2.6), (-3.8, 6.45, 2.6), (-5.7, 6.45, 4.0)]
    roof_faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    mesh_object("Highlands_farmhouse_roof", roof_vertices, roof_faces, m["terracotta"])
    box("Highlands_door", (-5.7, 3.53, 1.2), (0.42, 0.04, 0.75), m["clay"], bevel=0.03)

    # A faceted Mount Kenya-inspired horizon silhouette.
    mountain_vertices = [
        (-8.5, 12.5, 0.0), (-4.2, 12.5, 3.9), (-1.5, 12.5, 1.8), (1.6, 12.5, 5.4),
        (4.0, 12.5, 2.6), (8.5, 12.5, 0.0), (-8.5, 13.2, 0.0), (-4.2, 13.2, 3.9),
        (-1.5, 13.2, 1.8), (1.6, 13.2, 5.4), (4.0, 13.2, 2.6), (8.5, 13.2, 0.0),
    ]
    mountain_faces = [(0, 1, 2, 3, 4, 5), (6, 11, 10, 9, 8, 7), (0, 6, 7, 1), (1, 7, 8, 2), (2, 8, 9, 3), (3, 9, 10, 4), (4, 10, 11, 5)]
    mesh_object("Highlands_Mount_Kenya", mountain_vertices, mountain_faces, m["mountain"])
    mesh_object("Highlands_Mount_Kenya_snow", [(0.1, 12.42, 4.2), (1.6, 12.42, 5.4), (2.55, 12.42, 3.8)], [(0, 1, 2)], m["cream"])

    for index, (x, y, scale) in enumerate(((-8.0, 4.8, 0.7), (7.6, -1.8, 0.78), (6.8, 6.7, 0.62), (-7.0, -4.0, 0.58))):
        tree(f"Highlands_tree_{index}", x, y, hill_height(x, y), m["trunk"], m["leaf_dark"], scale=scale)


def build_coast(m):
    # The river begins in the tea country and widens into the ocean.
    river_points = [(-0.4, 4.5), (1.0, 8.0), (-1.0, 12.0), (0.8, 16.0), (0.0, 20.0), (0.0, 24.0)]
    ribbon("Journey_river", river_points, [0.65, 0.8, 1.0, 1.4, 2.2, 4.2], 0.37, m["water_light"])
    box("Coast_ocean", (0.0, 29.0, -0.15), (13.5, 12.0, 0.35), m["ocean"], bevel=0.8)
    cylinder("Coast_sand_island", (-5.2, 23.8, 0.05), 7.7, 0.65, m["sand"], vertices=36)
    cylinder("Coast_coral_base", (-6.0, 24.0, 0.48), 5.7, 0.55, m["sand_light"], vertices=32)

    # Swahili-inspired coral-stone gateway.
    box("Coast_arch_left", (-7.9, 24.5, 2.0), (0.65, 0.7, 1.7), m["coral_stone"], bevel=0.14)
    box("Coast_arch_right", (-4.1, 24.5, 2.0), (0.65, 0.7, 1.7), m["coral_stone"], bevel=0.14)
    box("Coast_arch_lintel", (-6.0, 24.5, 4.1), (2.55, 0.7, 0.48), m["coral_stone"], bevel=0.14)
    arch_points = []
    for index in range(13):
        angle = math.pi - index * math.pi / 12
        arch_points.append((-6.0 + math.cos(angle) * 1.9, 23.77, 2.65 + math.sin(angle) * 1.9))
    curve_tube("Coast_Swahili_arch", arch_points, 0.28, m["terracotta"])
    for index, x in enumerate((-8.65, -3.35)):
        sphere(f"Coast_arch_dome_{index}", (x, 24.5, 4.55), (0.55, 0.55, 0.42), m["coral_stone"], segments=16, rings=8)

    # Original low-poly dhow.
    hull_vertices = [(-1.7, 27.0, 0.45), (1.7, 27.0, 0.45), (0.95, 30.5, 0.65), (-0.9, 30.2, 0.65), (-1.0, 27.4, 1.05), (1.0, 27.4, 1.05), (0.55, 29.8, 1.05), (-0.55, 29.7, 1.05)]
    hull_faces = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7), (0, 3, 2, 1)]
    mesh_object("Coast_dhow_hull", hull_vertices, hull_faces, m["dhow"])
    cylinder("Coast_dhow_mast", (0.0, 28.5, 3.25), 0.09, 4.9, m["trunk"], vertices=10)
    mesh_object("Coast_dhow_sail", [(0.05, 28.45, 5.55), (0.05, 28.45, 1.55), (2.8, 28.45, 2.0)], [(0, 1, 2)], m["cream"])

    for index, (x, y, scale) in enumerate(((-9.0, 22.0, 0.82), (-2.5, 21.8, 0.72), (-8.2, 27.0, 0.66))):
        palm(f"Coast_palm_{index}", x, y, 0.55, m["trunk"], m["palm"], scale=scale)

    for index, y in enumerate((22.0, 25.0, 28.0, 31.0, 34.0, 37.0)):
        points = [(-10.5, y, 0.25), (-5.0, y + 0.25, 0.26), (0.0, y, 0.25), (5.0, y - 0.25, 0.26), (10.5, y, 0.25)]
        curve_tube(f"Coast_wave_{index}", points, 0.055, m["foam"])


def build_clouds(m):
    clouds = [(-9.5, -11.0, 11.0, 1.0), (8.5, 9.0, 12.5, 0.9), (-8.0, 29.0, 10.0, 0.75)]
    for index, (x, y, z, scale) in enumerate(clouds):
        for part, offset in enumerate(((-0.9, 0.0, 0.0), (0.0, 0.0, 0.35), (0.9, 0.0, 0.05))):
            sphere(f"Cloud_{index}_{part}", (x + offset[0] * scale, y, z + offset[2] * scale), (1.25 * scale, 0.55 * scale, 0.55 * scale), m["cloud"], segments=14, rings=7)


def setup_camera(profile: str):
    camera_data = bpy.data.cameras.new("JourneyCamera")
    camera = bpy.data.objects.new("JourneyCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    camera_data.lens = 45
    # Preserve the designed world width in both orientations. Portrait gains
    # vertical context instead of cropping the landmarks horizontally.
    camera_data.sensor_fit = "HORIZONTAL"
    camera_data.dof.use_dof = False

    target = bpy.data.objects.new("JourneyTarget", None)
    bpy.context.collection.objects.link(target)
    constraint = camera.constraints.new(type="TRACK_TO")
    constraint.target = target
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"

    landscape_positions = [
        (1, (0.0, -50.0, 24.0), (0.0, -23.0, 2.2)),
        (36, (12.0, -37.0, 18.0), (0.0, -22.0, 2.5)),
        (72, (7.0, -25.0, 15.0), (0.0, -12.0, 1.5)),
        (107, (11.0, -13.0, 18.0), (0.0, 0.0, 1.5)),
        (142, (0.0, -13.0, 21.0), (0.0, 3.0, 1.5)),
        (178, (8.0, 4.0, 17.0), (0.0, 11.0, 1.5)),
        (213, (-11.0, 10.0, 18.0), (-1.0, 23.0, 1.5)),
        (248, (12.0, 15.0, 18.0), (-2.0, 26.0, 1.5)),
        (284, (0.0, 41.0, 18.0), (0.0, 27.0, 1.5)),
    ]
    if profile == "portrait":
        positions = [(frame, (location[0] * 0.82, location[1], location[2] + 1.5), (focus[0] * 0.82, focus[1], focus[2] + 0.25)) for frame, location, focus in landscape_positions]
    else:
        positions = landscape_positions

    for frame, location, focus in positions:
        camera.location = location
        target.location = focus
        camera.keyframe_insert(data_path="location", frame=frame)
        target.keyframe_insert(data_path="location", frame=frame)
    # Blender 5.2 stores newly inserted keyframes in layered actions. Their
    # default Bezier interpolation supplies the smooth, interruptible camera
    # path we want without relying on the legacy Action.fcurves API.
    return camera


def configure_scene(profile: str, output: Path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = ((960, 540) if profile == "landscape" else (540, 960))
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False
    scene.frame_start = 1
    scene.frame_end = FINAL_FRAME
    if hasattr(scene.render, "use_motion_blur"):
        scene.render.use_motion_blur = False
    scene.render.filepath = str(output / profile / "frames" / "frame_")
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 35
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = hex_color("#8CB8C7")
    background.inputs["Strength"].default_value = 0.42
    scene.view_settings.look = "AgX - Medium High Contrast"

    light_data = bpy.data.lights.new(name="KenyanSun", type="SUN")
    light_data.energy = 3.2
    light_data.color = (1.0, 0.72, 0.46)
    light_data.angle = math.radians(18)
    light = bpy.data.objects.new(name="KenyanSun", object_data=light_data)
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (math.radians(34), math.radians(-22), math.radians(-28))


def build_world(profile: str, output: Path):
    random.seed(SEED)
    clear_scene()
    mats = {
        "earth": material("Earth", "#49362D"),
        "road": material("Road", "#202B2D", roughness=0.85),
        "charcoal": material("Charcoal", "#152326"),
        "window": material("Windows", "#7ED4D6", roughness=0.28, metallic=0.12),
        "gold": material("Sun Gold", "#F3B83F"),
        "terracotta": material("Terracotta", "#C85A46"),
        "coral": material("Coral", "#EF7666"),
        "clay": material("Clay", "#8E4B3A"),
        "cream": material("Warm Cream", "#F7E8C6"),
        "teal": material("Nairobi Teal", "#1E6970"),
        "matatu": material("Matatu", "#E13D63", roughness=0.38, metallic=0.08),
        "trunk": material("Wood", "#754831"),
        "leaf": material("City Green", "#3F8457"),
        "leaf_dark": material("Dark Green", "#24533F"),
        "highland": material("Highland Green", "#4B8C50"),
        "highland_dark": material("Highland Shadow", "#2D6544"),
        "highland_light": material("Highland Light", "#73A85B"),
        "tea": material("Tea", "#174C35"),
        "tea_light": material("Tea Light", "#2F7045"),
        "mountain": material("Mountain", "#536B68"),
        "water_light": material("River", "#36AFC2", roughness=0.32),
        "ocean": material("Indian Ocean", "#087F9A", roughness=0.28),
        "foam": material("Ocean Foam", "#D7F6EF"),
        "sand": material("Coastal Sand", "#E3BE73"),
        "sand_light": material("Sunlit Sand", "#F3D991"),
        "coral_stone": material("Coral Stone", "#D7A477"),
        "dhow": material("Dhow Wood", "#693F2C"),
        "palm": material("Palm", "#2B7552"),
        "cloud": material("Cloud", "#EDF5ED", roughness=1.0),
    }
    build_nairobi(mats)
    build_highlands(mats)
    build_coast(mats)
    build_clouds(mats)
    setup_camera(profile)
    configure_scene(profile, output)


def validate(profile: str, output: Path) -> dict:
    scene = bpy.context.scene
    polygon_count = sum(len(obj.data.polygons) for obj in scene.objects if obj.type == "MESH")
    expected = ["Nairobi_KICC_tower", "Nairobi_matatu_body", "Journey_road", "Highlands_Mount_Kenya", "Highlands_tea_row_00", "Journey_river", "Coast_Swahili_arch", "Coast_dhow_hull"]
    missing = [name for name in expected if name not in scene.objects]
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
        "mesh_polygons": polygon_count,
        "missing_required_objects": missing,
    }
    if missing:
        raise RuntimeError(f"Missing required scene objects: {missing}")
    if polygon_count >= 50000:
        raise RuntimeError(f"Polygon budget exceeded: {polygon_count}")
    profile_dir = output / profile
    profile_dir.mkdir(parents=True, exist_ok=True)
    (profile_dir / "scene_metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print("KENYA_WORLD_VALIDATION=" + json.dumps(metadata, sort_keys=True))
    return metadata


def render_preview(profile: str, output: Path, frames: list[int]) -> None:
    preview_dir = output / profile / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    for frame in frames:
        scene.frame_set(frame)
        scene.render.filepath = str(preview_dir / f"frame_{frame:04d}.png")
        bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / profile / f"kenya-world-{profile}.blend"))


def render_animation(profile: str, output: Path) -> None:
    frame_dir = output / profile / "frames"
    frame_dir.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.filepath = str(frame_dir / "frame_")
    bpy.ops.wm.save_as_mainfile(filepath=str(output / profile / f"kenya-world-{profile}.blend"))
    bpy.ops.render.render(animation=True)


def main() -> None:
    args = parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    build_world(args.profile, output)
    validate(args.profile, output)
    if args.mode == "preview":
        frames = [int(value) for value in args.frames.split(",") if value.strip()]
        render_preview(args.profile, output, frames)
    elif args.mode == "render":
        render_animation(args.profile, output)


if __name__ == "__main__":
    main()
