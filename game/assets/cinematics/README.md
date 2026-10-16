# Training cinematics

Both films are the owner's existing 30-second videos, with their original sound.
The original Drive files are unchanged. Godot uses Theora/Vorbis copies at 960×540, 30 fps.
The portrait player preserves the full 16:9 frame with letterboxing.

| Slot | Included file | Verified Drive source |
| --- | --- | --- |
| War opening | training_opening.ogv | 20261016_114013284.mp4 · 1Nu_EyqNACTTrhvkOcp_YGyeCGLjsBcG3 · 30.041667s |
| Ship and train arrival | training_supply.ogv | 20261016_122947435.mp4 · 19ySOinuxHPBEL-jWybpPIktAuMnMsV0k · 30.041667s |

Both conversions are 30.033333s and retain an audio stream. The opening is 3,582,696 bytes;
the arrival is 8,008,270 bytes. The arrival contains the European train, loaded ship and port.
Source folder: https://drive.google.com/drive/folders/1Sc--Zmd8wqGzbdAYcXM2iGdLwiJOPHT6
The other tank video, 20261016_111845613.mp4, is only 15 seconds and is not used.

To regenerate from complete originals:

    python3 tools/prepare_training_videos.py --opening /path/opening.mp4 --supplies /path/supplies.mp4

The converter rejects other durations, fails on decode errors, validates the converted duration
and checks that source audio survives. Films pause simulation and background music; the sound
setting is respected. Resume retains film position. Missing films show an explicit Continue fallback
for development, but both films are included in this update.
