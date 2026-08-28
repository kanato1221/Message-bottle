from pathlib import Path
import os

import bpy


OUTPUT_PATH = Path("/tmp/nagarebin_bottle_preview.png")


def main():
    scene = bpy.context.scene
    scene.frame_set(int(os.environ.get("PREVIEW_FRAME", "85")))
    scene.render.resolution_x = 886
    scene.render.resolution_y = 1920
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(OUTPUT_PATH)
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
