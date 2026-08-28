import math
from pathlib import Path

import bpy
from mathutils import Vector


OUTPUT_PATH = Path("/Users/Kanato.Matsui/Desktop/熱気球/ bottle_anime2.blend")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def make_material(name, color, roughness=0.7, alpha=1.0, transmission=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    material.blend_method = "BLEND" if alpha < 1 else "OPAQUE"
    material.use_screen_refraction = alpha < 1

    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Alpha"].default_value = alpha
        bsdf.inputs["Roughness"].default_value = roughness
        if "Transmission Weight" in bsdf.inputs:
            bsdf.inputs["Transmission Weight"].default_value = transmission
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = 0

    return material


def make_emission_material(name, color, strength=0.65, alpha=1.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    material.blend_method = "BLEND" if alpha < 1 else "OPAQUE"

    nodes = material.node_tree.nodes
    for node in nodes:
        nodes.remove(node)

    output = nodes.new(type="ShaderNodeOutputMaterial")
    emission = nodes.new(type="ShaderNodeEmission")
    transparent = nodes.new(type="ShaderNodeBsdfTransparent")
    mix = nodes.new(type="ShaderNodeMixShader")

    emission.inputs["Color"].default_value = color
    emission.inputs["Strength"].default_value = strength
    mix.inputs[0].default_value = 1 - alpha

    links = material.node_tree.links
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs[0])

    return material


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_ocean(material):
    width = 7.4
    depth = 18.0
    steps_x = 42
    steps_y = 92
    verts = []
    faces = []

    for y in range(steps_y + 1):
        for x in range(steps_x + 1):
            px = (x / steps_x - 0.5) * width
            py = (y / steps_y - 0.5) * depth + 1.8
            pz = (
                0.055 * math.sin(px * 2.1 + py * 0.45)
                + 0.032 * math.sin((px * 0.8 + py) * 1.35)
            )
            verts.append((px, py, pz))

    for y in range(steps_y):
        for x in range(steps_x):
            i = y * (steps_x + 1) + x
            faces.append((i, i + 1, i + steps_x + 2, i + steps_x + 1))

    mesh = bpy.data.meshes.new("Soft ocean mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()

    ocean = bpy.data.objects.new("やわらかな海", mesh)
    bpy.context.collection.objects.link(ocean)
    ocean.data.materials.append(material)

    bpy.ops.object.select_all(action="DESELECT")
    ocean.select_set(True)
    bpy.context.view_layer.objects.active = ocean
    bpy.ops.object.shade_smooth()

    return ocean


def add_water_veil(material):
    bpy.ops.mesh.primitive_plane_add(size=6.6, location=(0.0, -1.2, 0.13))
    veil = bpy.context.object
    veil.name = "ボトルにかかる薄い水面"
    veil.scale.y = 1.1
    veil.rotation_euler[0] = math.radians(0)
    veil.data.materials.append(material)
    return veil


def add_sky(sky_material, horizon_material, sun_material):
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0.0, 8.4, 2.45), rotation=(math.radians(90), 0, 0))
    sky = bpy.context.object
    sky.name = "遠くの淡い空"
    sky.scale = (7.0, 1.6, 1.0)
    sky.data.materials.append(sky_material)

    bpy.ops.mesh.primitive_plane_add(size=1, location=(0.0, 6.1, 0.62), rotation=(math.radians(90), 0, 0))
    horizon = bpy.context.object
    horizon.name = "水平線の淡いにじみ"
    horizon.scale = (6.8, 0.12, 1.0)
    horizon.data.materials.append(horizon_material)

    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=16, radius=0.18, location=(-1.25, 7.6, 2.75))
    sun = bpy.context.object
    sun.name = "遠くの小さな光"
    sun.scale.y = 0.08
    sun.data.materials.append(sun_material)
    bpy.ops.object.shade_smooth()

    return sky


def add_wave_line(name, y, scale, material, frame_offset):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 18
    curve.bevel_depth = 0.012 * scale
    curve.bevel_resolution = 3

    points_count = 9
    polyline = curve.splines.new("POLY")
    polyline.points.add(points_count - 1)

    width = 6.4
    for index, point in enumerate(polyline.points):
        x = (index / (points_count - 1) - 0.5) * width
        z = 0.025 * math.sin(index * 1.4)
        point.co = (x, y, z + 0.035, 1)

    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)

    for frame, offset in [(1, -0.18), (45, 0.12), (90, -0.18)]:
        bpy.context.scene.frame_set(frame + frame_offset)
        obj.location.x = offset
        obj.keyframe_insert(data_path="location", frame=frame + frame_offset)

    return obj


def add_wave_highlight(name, y, material, frame_offset, width=5.6, tilt=-2, z=0.09):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 24
    curve.bevel_depth = 0.006
    curve.bevel_resolution = 2

    points_count = 32
    polyline = curve.splines.new("POLY")
    polyline.points.add(points_count - 1)

    for index, point in enumerate(polyline.points):
        progress = index / (points_count - 1)
        x = (progress - 0.5) * width
        wave_z = z + 0.018 * math.sin(progress * math.pi * 4)
        point.co = (x, y + 0.08 * math.sin(progress * math.pi * 2), wave_z, 1)

    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.rotation_euler[2] = math.radians(tilt)

    for frame, offset, z_offset in [(1, -0.08, 0), (24, 0.03, 0.018), (48, 0.1, -0.012), (72, -0.02, 0.014), (90, -0.08, 0)]:
        bpy.context.scene.frame_set(frame + frame_offset)
        obj.location.x = offset
        obj.location.z = z_offset
        obj.keyframe_insert(data_path="location", frame=frame + frame_offset)

    return obj


def add_depth_wave(name, x, y, length, material, frame_offset):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 20
    curve.bevel_depth = 0.004
    curve.bevel_resolution = 2

    points_count = 18
    polyline = curve.splines.new("POLY")
    polyline.points.add(points_count - 1)

    for index, point in enumerate(polyline.points):
        progress = index / (points_count - 1)
        px = x + 0.08 * math.sin(progress * math.pi * 2)
        py = y + progress * length
        pz = 0.105 + 0.012 * math.sin(progress * math.pi * 3)
        point.co = (px, py, pz, 1)

    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)

    for frame, offset in [(1, -0.16), (45, 0.18), (90, -0.16)]:
        bpy.context.scene.frame_set(frame + frame_offset)
        obj.location.y = offset
        obj.keyframe_insert(data_path="location", frame=frame + frame_offset)

    return obj


def add_rolled_letter(paper_material):
    turns = 1.45
    points = 120
    inner_radius = 0.055
    outer_radius = 0.18
    paper_height = 0.92

    vertices = []
    faces = []

    for index in range(points):
        progress = index / (points - 1)
        angle = progress * turns * 2 * math.pi
        radius = inner_radius + (outer_radius - inner_radius) * progress
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)

        vertices.append((x, y, -paper_height / 2))
        vertices.append((x, y, paper_height / 2))

    for index in range(points - 1):
        a = index * 2
        faces.append((a, a + 1, a + 3, a + 2))

    mesh = bpy.data.meshes.new("巻いた手紙メッシュ")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()

    letter = bpy.data.objects.new("瓶の中の巻いた手紙", mesh)
    bpy.context.collection.objects.link(letter)
    letter.location = (0.02, -0.03, 0.86)
    letter.rotation_euler = (0, 0, math.radians(18))
    letter.data.materials.append(paper_material)

    solidify = letter.modifiers.new(name="紙の薄い厚み", type="SOLIDIFY")
    solidify.thickness = 0.008
    solidify.offset = 0.0

    return letter


def add_bottle(glass_material, cork_material, paper_material):
    parent = bpy.data.objects.new("流れるボトル", None)
    bpy.context.collection.objects.link(parent)
    center_offset = -1.25

    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.32, depth=1.55, location=(0, 0, 0.78 + center_offset))
    body = bpy.context.object
    body.name = "長めのボトル本体"
    body.scale.x = 0.86
    body.data.materials.append(glass_material)
    body.parent = parent
    bpy.ops.object.shade_smooth()

    bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=0.27, radius2=0.16, depth=0.28, location=(0, 0, 1.68 + center_offset))
    shoulder = bpy.context.object
    shoulder.name = "なだらかな肩"
    shoulder.scale.x = 0.86
    shoulder.data.materials.append(glass_material)
    shoulder.parent = parent
    bpy.ops.object.shade_smooth()

    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.15, depth=0.62, location=(0, 0, 2.13 + center_offset))
    neck = bpy.context.object
    neck.name = "ボトルの首"
    neck.scale.x = 0.9
    neck.data.materials.append(glass_material)
    neck.parent = parent
    bpy.ops.object.shade_smooth()

    bpy.ops.mesh.primitive_torus_add(major_radius=0.27, minor_radius=0.028, major_segments=64, minor_segments=8, location=(0, 0, -0.01 + center_offset))
    bottom_rim = bpy.context.object
    bottom_rim.name = "底の厚み"
    bottom_rim.scale.x = 0.86
    bottom_rim.data.materials.append(glass_material)
    bottom_rim.parent = parent
    bpy.ops.object.shade_smooth()

    bpy.ops.mesh.primitive_torus_add(major_radius=0.14, minor_radius=0.025, major_segments=64, minor_segments=8, location=(0, 0, 2.46 + center_offset))
    mouth_rim = bpy.context.object
    mouth_rim.name = "口の厚み"
    mouth_rim.scale.x = 0.9
    mouth_rim.data.materials.append(glass_material)
    mouth_rim.parent = parent
    bpy.ops.object.shade_smooth()

    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.16, depth=0.14, location=(0, 0, 2.53 + center_offset))
    cork = bpy.context.object
    cork.name = "小さな栓"
    cork.scale.x = 0.9
    cork.data.materials.append(cork_material)
    cork.parent = parent
    bpy.ops.object.shade_smooth()

    letter = add_rolled_letter(paper_material)
    letter.location.z += center_offset
    letter.parent = parent

    parent.location = (0.0, -4.8, 0.18)
    parent.rotation_euler = (math.radians(4), math.radians(88), math.radians(-5))
    parent.scale = (0.96, 0.96, 0.96)

    keyframes = [
        (1, (-0.05, -4.8, 0.22), (4, 88, -6), 1.05),
        (18, (-0.02, -3.55, 0.17), (7, 86, -3), 0.98),
        (36, (0.02, -2.15, 0.21), (3, 89, 0), 0.88),
        (54, (0.04, -0.75, 0.16), (6, 87, 3), 0.76),
        (72, (0.06, 0.75, 0.20), (2, 90, 6), 0.66),
        (90, (0.08, 1.75, 0.16), (5, 88, 8), 0.58),
    ]

    for frame, location, rotation, scale in keyframes:
        bpy.context.scene.frame_set(frame)
        parent.location = location
        parent.rotation_euler = tuple(math.radians(value) for value in rotation)
        parent.scale = (0.96 * scale, 0.96 * scale, 0.96 * scale)
        parent.keyframe_insert(data_path="location", frame=frame)
        parent.keyframe_insert(data_path="rotation_euler", frame=frame)
        parent.keyframe_insert(data_path="scale", frame=frame)

    if parent.animation_data and parent.animation_data.action:
        for fcurve in parent.animation_data.action.fcurves:
            for keyframe in fcurve.keyframe_points:
                keyframe.interpolation = "BEZIER"
                keyframe.handle_left_type = "AUTO_CLAMPED"
                keyframe.handle_right_type = "AUTO_CLAMPED"

    return parent


def add_camera_and_light():
    bpy.ops.object.light_add(type="AREA", location=(-2.7, -3.8, 5.0))
    key = bpy.context.object
    key.name = "やわらかい光"
    key.data.energy = 95
    key.data.size = 5.8

    bpy.ops.object.light_add(type="POINT", location=(2.2, -1.2, 2.0))
    fill = bpy.context.object
    fill.name = "水面の小さな光"
    fill.data.energy = 8
    fill.data.shadow_soft_size = 4

    bpy.ops.object.camera_add(location=(0, -8.2, 2.85))
    camera = bpy.context.object
    camera.name = "アプリ用カメラ"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 5.15
    look_at(camera, (0, -0.85, 0.25))
    bpy.context.scene.camera = camera


def setup_scene():
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 90
    scene.frame_set(1)
    scene.render.fps = 30
    scene.render.resolution_x = 1180
    scene.render.resolution_y = 2556
    scene.render.film_transparent = False
    scene.render.use_freestyle = True

    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1

    if scene.view_layers:
        freestyle = scene.view_layers[0].freestyle_settings
        if freestyle.linesets:
            line_style = freestyle.linesets[0].linestyle
            line_style.thickness = 1.15
            line_style.color = (0.02, 0.12, 0.13)

    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 64

    scene.world = bpy.data.worlds.new("淡い空")
    scene.world.color = (0.07, 0.21, 0.26)


def add_caption():
    bpy.ops.object.text_add(location=(0, 1.75, 0.26), rotation=(math.radians(72), 0, 0))
    text = bpy.context.object
    text.name = "演出メモ"
    text.data.body = "bottle drifting animation base"
    text.data.align_x = "CENTER"
    text.data.size = 0.09
    text.data.materials.append(make_material("薄い文字", (0.35, 0.48, 0.48, 1), roughness=1))


def main():
    clear_scene()
    setup_scene()

    ocean_material = make_material("淡い青緑の海", (0.03, 0.24, 0.31, 1), roughness=0.95)
    sky_material = make_emission_material("夕方前の淡い空", (0.10, 0.29, 0.38, 1), strength=0.22)
    horizon_material = make_emission_material("水平線の淡いにじみ", (0.12, 0.36, 0.42, 0.14), strength=0.18, alpha=0.14)
    sun_material = make_emission_material("遠い日の光", (0.62, 0.42, 0.23, 0.34), strength=0.38, alpha=0.34)
    wave_material = make_material("薄い波の光", (0.32, 0.66, 0.68, 0.42), roughness=0.85, alpha=0.42)
    glass_material = make_material("海緑の透明ボトル", (0.04, 0.22, 0.22, 1), roughness=0.5, alpha=1.0, transmission=0.0)
    cork_material = make_material("素朴な栓", (0.42, 0.25, 0.16, 1), roughness=0.8)
    paper_material = make_material("中の淡い紙", (0.92, 0.84, 0.62, 1), roughness=0.9)

    add_sky(sky_material, horizon_material, sun_material)
    add_ocean(ocean_material)
    add_wave_highlight("奥の水面の光", 1.35, wave_material, 0, width=4.2, tilt=-4, z=0.08)
    add_wave_highlight("中央の水面の光", -0.65, wave_material, 5, width=5.4, tilt=-2, z=0.095)
    add_wave_highlight("手前の水面の光", -3.0, wave_material, 10, width=6.6, tilt=1, z=0.105)
    add_depth_wave("奥へ流れる細い波 1", -1.45, -4.2, 4.2, wave_material, 0)
    add_depth_wave("奥へ流れる細い波 2", 1.35, -3.4, 3.7, wave_material, 8)
    add_bottle(glass_material, cork_material, paper_material)
    add_camera_and_light()

    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_PATH))


if __name__ == "__main__":
    main()
