#!/usr/bin/env python3
"""Download and bake every sound of the game into assets/audio/.

Each output comes from a public source listed in SOURCES (its URL, author
and licence), so the whole soundtrack can be rebuilt, and audited, from
scratch. The music is cut into seamless loops (the track's end crossfades
into its start), everything is levelled to a common loudness and encoded
as MP3, the one format Android, iOS and the browsers all play.

Needs ffmpeg on the PATH. Downloads are cached in build/audio_src/.

Run from the repository root:  python tools/build_audio.py
"""
from __future__ import annotations

import os
import re
import subprocess
import zipfile

CACHE = os.path.join("build", "audio_src")
OUTPUT = os.path.join("assets", "audio")

INCOMPETECH = "https://incompetech.com/music/royalty-free/mp3-royaltyfree/"
SOUNDIMAGE = "https://soundimage.org/wp-content/uploads/"
OGA = "https://opengameart.org/sites/default/files/"
KENNEY = "https://kenney.nl/media/pages/assets/"

# name -> (url, title, author, licence). Zip archives are unpacked next to
# themselves; an effect names a file inside one by its path in the zip.
SOURCES = {
    "darkest_child": (INCOMPETECH + "Darkest%20Child.mp3", "Darkest Child",
                      "Kevin MacLeod (incompetech.com)", "CC BY 4.0"),
    "gathering_darkness": (INCOMPETECH + "Gathering%20Darkness.mp3",
                           "Gathering Darkness",
                           "Kevin MacLeod (incompetech.com)", "CC BY 4.0"),
    "oppressive_gloom": (INCOMPETECH + "Oppressive%20Gloom.mp3",
                         "Oppressive Gloom",
                         "Kevin MacLeod (incompetech.com)", "CC BY 4.0"),
    "lurking": (SOUNDIMAGE + "2014/03/Lurking-in-the-Shadows.mp3",
                "Lurking in the Shadows", "Eric Matyas (soundimage.org)",
                "Free with attribution"),
    "closing_in": (SOUNDIMAGE + "2015/07/Closing-In.mp3", "Closing In",
                   "Eric Matyas (soundimage.org)", "Free with attribution"),
    "horrible_realization": (SOUNDIMAGE + "2014/02/Horrible-Realization.mp3",
                             "Horrible Realization",
                             "Eric Matyas (soundimage.org)",
                             "Free with attribution"),
    "wind": (OGA + "wind%20woosh%20loop.ogg", "Wind Woosh Loop",
             "OpenGameArt.org", "CC0"),
    "dungeon": (OGA + "dungeon_ambient_1.ogg", "Loopable Dungeon Ambience",
                "OpenGameArt.org", "CC0"),
    "fireplace": (OGA + "fire.wav", "Fireplace Sound Loop",
                  "OpenGameArt.org", "CC0"),
    "pistol": (OGA + "22%20Pistol.wav", "Gunshots", "OpenGameArt.org",
               "CC0"),
    "moans": (OGA + "darsycho__zombie-moans.ogg", "Zombie Moans",
              "OpenGameArt.org", "CC0"),
    "ghoul": (OGA + "hungry-ghoul.ogg", "Hungry Ghoul", "OpenGameArt.org",
              "CC0"),
    "undead1": (OGA + "undead-1.ogg", "Undead Moans", "OpenGameArt.org",
                "CC0"),
    "undead3": (OGA + "undead-3.ogg", "Undead Moans", "OpenGameArt.org",
                "CC0"),
    "undead4": (OGA + "undead-4.ogg", "Undead Moans", "OpenGameArt.org",
                "CC0"),
    "impact": (KENNEY + "impact-sounds/87b4ddecda-1677589768/"
               "kenney_impact-sounds.zip", "Impact Sounds", "Kenney.nl",
               "CC0"),
    "rpg": (KENNEY + "rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip",
            "RPG Audio", "Kenney.nl", "CC0"),
    "ui": (KENNEY + "ui-audio/490d233f68-1677590494/kenney_ui-audio.zip",
           "UI Audio", "Kenney.nl", "CC0"),
}

# Loops: (output, source, start s, end s, crossfade s, loudness LUFS).
# The end of a Kevin MacLeod piece is a slow decay, so it is cut a few
# seconds before the silence and crossfaded into the opening.
MUSIC = [
    ("music/menu.mp3", "darkest_child", 0.0, 228.0, 6.0, -20),
    ("music/story.mp3", "gathering_darkness", 0.55, 254.0, 6.0, -20),
    ("music/street.mp3", "oppressive_gloom", 0.0, 190.0, 6.0, -21),
    ("music/barracks.mp3", "lurking", 1.37, 91.2, 0.6, -22),
    ("music/danger.mp3", "closing_in", 1.38, 78.15, 0.6, -19),
]

AMBIENCE = [
    ("ambience/wind.mp3", "wind", 0.0, None, 1.0, -26, "lowpass=f=2400"),
    ("ambience/indoor.mp3", "dungeon", 0.0, None, 2.0, -27, None),
    ("ambience/fire.mp3", "fireplace", 0.0, None, 1.5, -24, None),
]

# One-shots: (output, source, start, end, peak dBFS, extra filter).
IMPACT = "Audio/"
RPG = "Audio/"
SFX = [
    ("sfx/game_over.mp3", "horrible_realization", 1.44, 30.9, -3,
     "afade=t=out:st=27:d=2.4"),
    ("sfx/step_1.mp3", "impact", IMPACT + "footstep_concrete_000.ogg", None,
     -16, None),
    ("sfx/step_2.mp3", "impact", IMPACT + "footstep_concrete_001.ogg", None,
     -16, None),
    ("sfx/step_3.mp3", "impact", IMPACT + "footstep_concrete_002.ogg", None,
     -16, None),
    ("sfx/step_4.mp3", "impact", IMPACT + "footstep_concrete_003.ogg", None,
     -16, None),
    ("sfx/gunshot.mp3", "pistol", 0.0, 0.59, -1,
     "bass=g=9:f=110,aecho=0.8:0.5:70|140:0.35|0.2,afade=t=out:st=0.35:d=0.3"),
    ("sfx/dry_fire.mp3", "rpg", RPG + "metalClick.ogg", None, -6, None),
    ("sfx/pickup.mp3", "rpg", RPG + "handleSmallLeather.ogg", None, -4, None),
    ("sfx/pickup_gun.mp3", "rpg", RPG + "metalLatch.ogg", None, -4, None),
    ("sfx/door.mp3", "rpg", RPG + "doorOpen_1.ogg", None, -4, None),
    ("sfx/rest.mp3", "rpg", RPG + "cloth2.ogg", None, -6, None),
    ("sfx/zombie_alert_1.mp3", "moans", 0.18, 3.14, -3, None),
    ("sfx/zombie_alert_2.mp3", "moans", 3.63, 6.29, -3, None),
    ("sfx/zombie_alert_3.mp3", "moans", 6.59, 9.09, -3, None),
    ("sfx/zombie_hurt_1.mp3", "undead1", 0.0, None, -4, None),
    ("sfx/zombie_hurt_2.mp3", "undead3", 0.0, None, -4, None),
    ("sfx/zombie_death.mp3", "undead4", 0.0, None, -3,
     "asetrate=44100*0.82,aresample=44100"),
    ("sfx/zombie_bite.mp3", "ghoul", 0.0, 2.12, -3, None),
    ("sfx/hit_flesh.mp3", "impact", IMPACT + "impactPunch_medium_000.ogg",
     None, -5, None),
    ("sfx/player_hurt.mp3", "impact", IMPACT + "impactPunch_heavy_000.ogg",
     None, -3, None),
    ("sfx/player_fall.mp3", "impact", IMPACT + "impactSoft_heavy_000.ogg",
     None, -3, None),
    ("sfx/ui_click.mp3", "ui", "Audio/click3.ogg", None, -8, None),
    ("sfx/dialogue.mp3", "ui", "Audio/switch2.ogg", None, -14, None),
]


def fetch(name: str) -> str:
    url = SOURCES[name][0]
    extension = os.path.splitext(url)[1]
    path = os.path.join(CACHE, name + extension)
    if not os.path.exists(path):
        os.makedirs(CACHE, exist_ok=True)
        # curl rather than urllib: it uses the system's certificate store,
        # which some of these hosts need.
        subprocess.run(["curl", "-sfL", "-o", path, url], check=True)
    if extension == ".zip":
        folder = os.path.join(CACHE, name)
        if not os.path.isdir(folder):
            with zipfile.ZipFile(path) as archive:
                archive.extractall(folder)
        return CACHE
    return path


def ffmpeg(*args: str) -> str:
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-y", *args],
        capture_output=True, text=True, check=True)
    return result.stderr


def duration(path: str) -> float:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", path], capture_output=True, text=True, check=True)
    return float(result.stdout)


def out_path(name: str) -> str:
    path = os.path.join(OUTPUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def encode_args(stereo: bool) -> list[str]:
    if stereo:
        return ["-ar", "44100", "-ac", "2", "-c:a", "libmp3lame", "-b:a", "112k"]
    return ["-ar", "44100", "-ac", "1", "-c:a", "libmp3lame", "-b:a", "80k"]


def bake_loop(output, source, start, end, fade, lufs, extra=None,
              stereo=True):
    """Cuts [start, end] and crossfades its last [fade] seconds into its
    first ones, so the file ends exactly where it begins."""
    path = fetch(source)
    end = end if end is not None else duration(path)
    pre = f"{extra}," if extra else ""
    graph = (
        f"[0:a]atrim={start}:{end},asetpts=PTS-STARTPTS,{pre}asplit[a][b];"
        f"[a]atrim={fade},asetpts=PTS-STARTPTS[body];"
        f"[b]atrim=0:{fade},asetpts=PTS-STARTPTS[head];"
        f"[body][head]acrossfade=d={fade}:c1=tri:c2=tri,"
        f"loudnorm=I={lufs}:TP=-2:LRA=11[out]"
    )
    ffmpeg("-i", path, "-filter_complex", graph, "-map", "[out]",
           *encode_args(stereo), out_path(output))


def bake_one_shot(output, source, start, end, peak, extra):
    path = fetch(source)
    if isinstance(start, str):
        # A file inside an unpacked archive.
        path, start = os.path.join(path, source, start), 0.0
    trim = f"atrim={start}" + (f":{end}" if end is not None else "")
    chain = f"{trim},asetpts=PTS-STARTPTS"
    if extra:
        chain += "," + extra
    probe = ffmpeg("-i", path, "-af", chain + ",volumedetect", "-f", "null",
                   "-")
    loudest = float(re.search(r"max_volume: (-?[\d.]+) dB", probe).group(1))
    chain += f",volume={peak - loudest:.2f}dB"
    ffmpeg("-i", path, "-af", chain, *encode_args(stereo=False),
           out_path(output))


def main() -> None:
    for output, source, start, end, fade, lufs in MUSIC:
        bake_loop(output, source, start, end, fade, lufs)
        print(output)
    for output, source, start, end, fade, lufs, extra in AMBIENCE:
        bake_loop(output, source, start, end, fade, lufs, extra, stereo=False)
        print(output)
    for output, source, start, end, peak, extra in SFX:
        bake_one_shot(output, source, start, end, peak, extra)
        print(output)


if __name__ == "__main__":
    main()
