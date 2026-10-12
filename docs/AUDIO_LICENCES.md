# Audio licences

Every music or sound file shipped in the game needs a line here: file, artist, where it came
from, and the licence or written permission (keep a copy of the email or licence page).

| File | Artist / source | Licence / permission | Date |
| --- | --- | --- | --- |
| `assets/audio/sfx/*.ogg` (37 sounds) | Synthesized by `tools/make_sounds.py` (Claude, for the owner) | Owned by the owner: no samples or third-party audio | 2026-10-12 |
| `assets/audio/music/menu_theme.ogg`, `battle_theme.ogg` | Synthesized by `tools/make_sounds.py` | Owned by the owner | 2026-10-12 |
| `assets/audio/start_theme.ogg` (start-menu music) | “Bersærkere” by RAVNIR, album *Gudlaus* (2026), composer Michael Hinterberger, ISRC GXJBY2606992. Converted from the owner's purchased FLAC to OGG Vorbis. | Purchased by the owner; the artist gave permission to use it in the game **on condition that RAVNIR is credited**. Credit shown on the start screen (`GameAudio.MENU_THEME_CREDIT`) and must also go in the Play Store listing / in-game credits. Keep the artist's message as proof. **Not stored in GitHub** (the repos are public; permission covers the game, not giving the song away): put the file in `game/assets/audio/start_theme.ogg` before building. Make it from the FLAC with `ffmpeg -i "07 Bersærkere.flac" -map 0:a -ar 44100 -c:a libvorbis -q:a 5 -map_metadata -1 start_theme.ogg`. | 2026-10-12 |
