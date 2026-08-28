import bpy
import math
import os
from mathutils import Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
BLEND_OUT = os.path.join(OUT_DIR, "message_bottle_ocean.blend")
VIDEO_OUT = os.path.join(OUT_DIR, "message_bottle_ocean.mp4")


def mat_principled(name, base, metallic=0.0, roughness=0.45, transmission=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*base, alpha)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*base, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Transmission Weight"].default_value = transmission
    bsdf.inputs["Alpha"].default_value = alpha
    if alpha < 1:
        m.surface_render_method = 'DITHERED'
    return m


def add_uv(name, loc, scale, mat, segments=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o


def add_cylinder(name, radius, depth, loc, rot, mat, vertices=48, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    if bevel:
        mod = o.modifiers.new("Soft edges", 'BEVEL')
        mod.width = bevel
        mod.segments = 3
    bpy.ops.object.shade_smooth()
    return o


def look_at(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat('-Z', 'Y').to_euler()


# Reset
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.materials, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
    pass

scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = 192
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 640
scene.render.resolution_y = 360
scene.render.resolution_percentage = 100
scene.render.fps = 24
scene.render.image_settings.file_format = 'FFMPEG'
scene.render.ffmpeg.format = 'MPEG4'
scene.render.ffmpeg.codec = 'H264'
scene.render.ffmpeg.constant_rate_factor = 'MEDIUM'
scene.render.filepath = VIDEO_OUT
scene.render.film_transparent = False
scene.render.image_settings.color_mode = 'RGB'
scene.view_settings.look = 'AgX - Medium High Contrast'

# World / sunrise sky
world = bpy.data.worlds.new("Ocean Sky") if not bpy.data.worlds else bpy.data.worlds[0]
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes['Background']
bg.inputs['Color'].default_value = (0.055, 0.13, 0.24, 1)
bg.inputs['Strength'].default_value = 0.35

glass = mat_principled("Sea Glass", (0.12, 0.48, 0.34), roughness=0.18, transmission=0.78, alpha=0.58)
glass.diffuse_color = (0.08, 0.42, 0.28, 0.58)
cork = mat_principled("Cork", (0.42, 0.19, 0.07), roughness=0.9)
paper = mat_principled("Aged Letter", (0.88, 0.69, 0.39), roughness=0.82)
ink = mat_principled("Ink", (0.08, 0.035, 0.02), roughness=0.8)
rope = mat_principled("Twine", (0.30, 0.13, 0.04), roughness=0.95)

# Bottle rig; bottle's long axis follows local/global X before rig animation.
rig = bpy.data.objects.new("Bottle_Rig", None)
bpy.context.collection.objects.link(rig)
rig.rotation_mode = 'XYZ'

parts = []
body = add_cylinder("Bottle_Body", .62, 2.65, (0, 0, 0), (0, math.pi/2, 0), glass, bevel=.17)
parts.append(body)
bottom = add_uv("Bottle_Base", (-1.30, 0, 0), (.22, .61, .61), glass)
parts.append(bottom)
shoulder = add_uv("Bottle_Shoulder", (1.26, 0, 0), (.52, .61, .61), glass)
parts.append(shoulder)
neck = add_cylinder("Bottle_Neck", .28, 1.08, (1.76, 0, 0), (0, math.pi/2, 0), glass, bevel=.06)
parts.append(neck)
lip = add_cylinder("Bottle_Lip", .35, .20, (2.28, 0, 0), (0, math.pi/2, 0), glass, bevel=.04)
parts.append(lip)
cork_obj = add_cylinder("Cork_Stopper", .255, .45, (2.25, 0, 0), (0, math.pi/2, 0), cork, bevel=.035)
parts.append(cork_obj)

# Rolled letter visible through the glass.
letter = add_cylinder("Rolled_Letter", .31, 1.75, (-.15, 0, -.03), (0, math.pi/2, 0), paper, vertices=64, bevel=.025)
parts.append(letter)
for x in (-.72, .43):
    band = add_cylinder("Twine_Band", .324, .035, (x, 0, -.03), (0, math.pi/2, 0), rope, vertices=48)
    parts.append(band)

# A small handwritten heart mark on the visible end.
bpy.ops.object.text_add(location=(-1.04, -.318, -.02), rotation=(math.pi/2, 0, 0))
mark = bpy.context.object
mark.name = "Letter_Mark"
mark.data.body = "❤"
mark.data.align_x = 'CENTER'
mark.data.align_y = 'CENTER'
mark.data.size = .27
mark.data.extrude = .003
mark.data.materials.append(ink)
parts.append(mark)

for o in parts:
    o.parent = rig

# Ocean mesh with procedural displacement and animated wave modifier.
water_mat = bpy.data.materials.new("Deep Blue Water")
water_mat.use_nodes = True
n = water_mat.node_tree.nodes
l = water_mat.node_tree.links
for node in list(n):
    n.remove(node)
out = n.new('ShaderNodeOutputMaterial')
bsdf = n.new('ShaderNodeBsdfPrincipled')
bsdf.inputs['Base Color'].default_value = (0.015, .16, .28, 1)
bsdf.inputs['Metallic'].default_value = .12
bsdf.inputs['Roughness'].default_value = .22
bsdf.inputs['Transmission Weight'].default_value = .18
noise = n.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value = 2.7
noise.inputs['Detail'].default_value = 5.0
noise.inputs['Roughness'].default_value = .7
bump = n.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .35
bump.inputs['Distance'].default_value = .28
l.new(noise.outputs['Fac'], bump.inputs['Height'])
l.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
l.new(bsdf.outputs['BSDF'], out.inputs['Surface'])

bpy.ops.mesh.primitive_grid_add(x_subdivisions=110, y_subdivisions=110, size=44, location=(3, 5, -.43))
ocean = bpy.context.object
ocean.name = "Animated_Ocean"
ocean.data.materials.append(water_mat)
wave = ocean.modifiers.new("Rolling Waves", 'WAVE')
wave.height = .24
wave.width = 2.7
wave.speed = .22
wave.narrowness = 2.0
wave.use_cyclic = True
wave.use_normal = True
bpy.ops.object.shade_smooth()

# Distant horizon disc / warm sunset.
sunmat = mat_principled("Sun Glow", (1.0, .28, .055), roughness=.1)
sunmat.use_nodes = True
sun_bsdf = sunmat.node_tree.nodes['Principled BSDF']
sun_bsdf.inputs['Emission Color'].default_value = (1.0, .16, .025, 1)
sun_bsdf.inputs['Emission Strength'].default_value = 5.0
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=(9, 17, 4.5), scale=(1.35,1.35,1.35))
sun_disc = bpy.context.object
sun_disc.name = "Setting_Sun"
sun_disc.data.materials.append(sunmat)

# Lighting
bpy.ops.object.light_add(type='SUN', location=(4, -4, 8))
sun_light = bpy.context.object
sun_light.name = "Warm Sunlight"
sun_light.data.energy = 3.0
sun_light.data.color = (1.0, .43, .20)
sun_light.rotation_euler = (math.radians(28), math.radians(-18), math.radians(-28))
bpy.ops.object.light_add(type='AREA', location=(-4, -4, 7))
fill = bpy.context.object
fill.name = "Cool Sky Fill"
fill.data.energy = 850
fill.data.shape = 'DISK'
fill.data.size = 8
fill.data.color = (.18, .42, 1.0)
look_at(fill, (0, 3, 0))

# Bottle motion: drifting away, bobbing, rolling, with a gentle sideways arc.
keys = [
    (1,   (-2.7, -1.6, .25), (math.radians(5), math.radians(-7), math.radians(-8))),
    (32,  (-2.0, -.4, .37),  (math.radians(-4), math.radians(8), math.radians(2))),
    (64,  (-1.15, 1.0, .22), (math.radians(5), math.radians(-8), math.radians(10))),
    (96,  (-.20, 2.7, .39),  (math.radians(-5), math.radians(7), math.radians(17))),
    (128, (.95, 4.7, .23),   (math.radians(4), math.radians(-7), math.radians(25))),
    (160, (2.15, 7.0, .36),  (math.radians(-4), math.radians(6), math.radians(33))),
    (192, (3.25, 9.5, .25),  (math.radians(4), math.radians(-5), math.radians(41))),
]
for frame, loc, rot in keys:
    rig.location = loc
    rig.rotation_euler = rot
    rig.keyframe_insert('location', frame=frame)
    rig.keyframe_insert('rotation_euler', frame=frame)
if rig.animation_data and rig.animation_data.action:
    for fc in rig.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'BEZIER'

# Camera slowly rises and lets the bottle drift toward the horizon.
bpy.ops.object.camera_add(location=(-7.6, -8.7, 5.0))
cam = bpy.context.object
cam.name = "Cinematic Camera"
cam.data.lens = 48
cam.data.dof.use_dof = True
cam.data.dof.focus_object = rig
cam.data.dof.aperture_fstop = 4.0
scene.camera = cam
cam.rotation_mode = 'XYZ'
cam_keys = [
    (1, (-7.6, -8.7, 5.0), (-.8, 1.0, .2)),
    (96, (-6.0, -6.5, 5.8), (0.0, 2.7, .1)),
    (192, (-4.5, -4.5, 7.0), (2.7, 8.2, .2)),
]
for frame, loc, target in cam_keys:
    cam.location = loc
    look_at(cam, target)
    cam.keyframe_insert('location', frame=frame)
    cam.keyframe_insert('rotation_euler', frame=frame)

# Subtle vignette through compositor.
scene.use_nodes = True
nt = scene.node_tree
nt.nodes.clear()
rl = nt.nodes.new('CompositorNodeRLayers')
comp = nt.nodes.new('CompositorNodeComposite')
nt.links.new(rl.outputs['Image'], comp.inputs['Image'])

scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
print(f"SAVED_BLEND={BLEND_OUT}")
print(f"VIDEO_TARGET={VIDEO_OUT}")
