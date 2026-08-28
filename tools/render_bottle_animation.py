from pathlib import Path

import bpy


OUTPUT_PATH = Path("/Users/Kanato.Matsui/Desktop/熱気球/nagarebin_drift_animation.mp4")


def main():
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 90
    scene.frame_set(1)
    scene.render.fps = 30
    scene.render.resolution_x = 886
    scene.render.resolution_y = 1920
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False

    scene.render.filepath = str(OUTPUT_PATH)
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "MEDIUM"
    scene.render.ffmpeg.ffmpeg_preset = "GOOD"
    scene.render.ffmpeg.audio_codec = "NONE"

    bpy.ops.render.render(animation=True)


if __name__ == "__main__":
    main()
