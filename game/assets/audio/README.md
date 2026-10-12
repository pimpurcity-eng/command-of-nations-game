# Game audio

All sounds (`sfx/`) and music (`music/`) are synthesized from scratch by `tools/make_sounds.py`
(no samples), so the owner holds every right. Regenerate with:

    python3 tools/make_sounds.py game/assets/audio

`scripts/game_audio.gd` plays them: weapons by type (`GameAudio.WEAPON_SOUNDS`), explosions,
events (war, captures, buildings, research, victory/defeat), button clicks, menu and battle
music. Sound and Music switches are on the start screen and in More, remembered in
`user://settings.cfg`.

**Optional licensed menu track:** a file at `start_theme.ogg` (or `.mp3`) replaces the
synthesized menu theme. Only add music the owner has the right to use, and record it in
`docs/AUDIO_LICENCES.md`.
