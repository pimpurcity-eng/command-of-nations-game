#!/usr/bin/env python3
"""Convert the owner's two 30-second MP4s to Godot's native Theora format.

Usage: python3 tools/prepare_training_videos.py --opening opening.mp4 --supplies supplies.mp4
Either argument can be supplied independently. Original files are never changed.
"""
import argparse
import json
import pathlib
import subprocess


def prepare(source: pathlib.Path, target: pathlib.Path) -> dict:
    metadata = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(source)
    ]))
    duration = float(metadata["format"]["duration"])
    if not 29.5 <= duration <= 30.5:
        raise ValueError(f"{source.name}: expected a 30-second film; found {duration:.2f}s")
    if not any(stream["codec_type"] == "video" for stream in metadata["streams"]):
        raise ValueError(f"{source.name}: no video stream")
    target.parent.mkdir(parents=True, exist_ok=True)
    # Hidden work file: Godot must not import/export an incomplete conversion.
    temporary = target.with_name("." + target.stem + ".part.ogv")
    subprocess.run([
        "ffmpeg", "-v", "error", "-xerror", "-y", "-i", str(source), "-map", "0:v:0", "-map", "0:a?",
        "-vf", "scale=960:540:force_original_aspect_ratio=decrease,pad=960:540:(ow-iw)/2:(oh-ih)/2,setsar=1",
        "-r", "30", "-c:v", "libtheora", "-q:v", "6", "-pix_fmt", "yuv420p",
        "-c:a", "libvorbis", "-q:a", "4", "-ac", "2", "-threads", "2", str(temporary)
    ], check=True)
    output = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(temporary)
    ]))
    if not 29.5 <= float(output["format"]["duration"]) <= 30.5:
        temporary.unlink(missing_ok=True)
        raise ValueError("Converted film is incomplete; original output was preserved")
    if any(s["codec_type"] == "audio" for s in metadata["streams"]) and not any(s["codec_type"] == "audio" for s in output["streams"]):
        temporary.unlink(missing_ok=True)
        raise ValueError("Converted film is missing its original audio")
    temporary.replace(target)
    return {"source": source.name, "duration_seconds": duration, "output": target.name, "size_bytes": target.stat().st_size}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--opening", type=pathlib.Path)
    parser.add_argument("--supplies", type=pathlib.Path)
    args = parser.parse_args()
    if not args.opening and not args.supplies:
        parser.error("provide --opening and/or --supplies")
    destination = pathlib.Path(__file__).resolve().parents[1] / "game/assets/cinematics"
    for source, filename in [(args.opening, "training_opening.ogv"), (args.supplies, "training_supply.ogv")]:
        if source is not None:
            print(json.dumps(prepare(source, destination / filename)))


if __name__ == "__main__":
    main()
