#!/usr/bin/env python3
"""
Downloads Friday Night Funkin' songs for the battle microphone into data/fnf/songs/.

The songs belong to The Funkin' Crew and can't be shipped with the game, so this pulls them for
a local server straight from their public assets repository (github.com/FunkinCrew/funkin.assets).
data/ is gitignored, so nothing downloaded here ends up in a commit.

Each song comes with its mixes (Erect, Pico): charts, metadata, instrumentals, the singers' Voices
files, and lyrics where there are any. The week lists come too, so songs can be picked by week, and Week 6's dialogue.
That's a few hundred MB for the lot.

    python3 tools/fnf/fetch_funkin.py                  every song
    python3 tools/fnf/fetch_funkin.py bopeebo fresh    just these

If GitHub won't load for you, get the repository some other way (a zip of it from anywhere, or a
clone made on another machine), unpack it, and point this at the folder instead of downloading:

    python3 tools/fnf/fetch_funkin.py --from path/to/funkin.assets

Modded songs don't need this script. Put each one in its own folder under data/fnf/songs/, named
after the song, with its chart JSON files, Inst.ogg and its Voices files together. A Psych Engine
mod keeps charts in mods/data/<song>/ and audio in mods/songs/<song>/: copy both into one folder.
"""

import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

REPO = "https://github.com/FunkinCrew/funkin.assets"
ROOT = pathlib.Path(__file__).resolve().parents[2]
DEST = ROOT / "data" / "fnf" / "songs"


def git(*args, cwd):
    subprocess.run(["git", *args], cwd=cwd, check=True)


def voice_names(metadata, variation=None):
    """Every Voices-<name> a song's singers might use. Metadata names variants ("bf-car", "mom-car")
    while the files are just Voices-bf and Voices-mom, so the part before a hyphen counts too. A
    mix's own recordings end in its name: Voices-pico-pico."""
    characters = metadata.get("playData", {}).get("characters", {})
    names = []
    for key, fallback in (("playerVocals", "player"), ("opponentVocals", "opponent")):
        vocals = characters.get(key) or ([characters[fallback]] if characters.get(fallback) else [])
        for vocal in vocals[:1]:
            names.append(vocal)
            if "-" in vocal:
                names.append(vocal.split("-")[0])
    if variation:
        names += [f"{name}-{variation}" for name in names]
    return names


def audio_names(metadata, variation=None):
    """The audio files one version of a song uses."""
    instrumental = metadata.get("playData", {}).get("characters", {}).get("instrumental") or variation
    files = [f"Inst-{instrumental}.ogg" if instrumental else "Inst.ogg"]
    if variation:
        files.append("Inst.ogg")
    return files + [f"Voices-{voice}.ogg" for voice in voice_names(metadata, variation)]


def main():
    args = sys.argv[1:]
    local = None
    if "--from" in args:
        at = args.index("--from")
        local = pathlib.Path(args[at + 1]).expanduser().resolve()
        del args[at:at + 2]
    wanted = set(args)
    with tempfile.TemporaryDirectory() as tmp:
        if local:
            clone = local
            if not (clone / "preload" / "data" / "songs").is_dir():
                sys.exit(f"{clone} doesn't look like funkin.assets: no preload/data/songs in it.")
        else:
            clone = pathlib.Path(tmp) / "assets"
            print("Fetching the song list...")
            git("clone", "--depth", "1", "--filter=blob:none", "--sparse", REPO, str(clone), cwd=tmp)
            git("sparse-checkout", "set", "--no-cone", "/preload/data/songs/", "/preload/data/levels/", "/preload/data/dialogue/", cwd=clone)

        songs = {}
        for song_dir in sorted((clone / "preload" / "data" / "songs").iterdir()):
            song_id = song_dir.name
            chart = song_dir / f"{song_id}-chart.json"
            meta = song_dir / f"{song_id}-metadata.json"
            if not chart.exists() or not meta.exists() or (wanted and song_id not in wanted):
                continue
            metadata = json.loads(meta.read_text(encoding="utf-8"))
            audio = audio_names(metadata)
            for variation in metadata.get("playData", {}).get("songVariations", []):
                variation_meta = song_dir / f"{song_id}-metadata-{variation}.json"
                if variation_meta.exists():
                    audio += audio_names(json.loads(variation_meta.read_text(encoding="utf-8")), variation)
            songs[song_id] = (song_dir, sorted(set(audio)))
        if not songs:
            print("No songs matched.")
            return

        if not local:
            patterns = ["/preload/data/songs/"]
            patterns.append("/preload/data/levels/")
            patterns.append("/preload/data/dialogue/")
            for song_id, (_, audio) in songs.items():
                patterns.extend(f"/songs/{song_id}/{name}" for name in audio)
            print(f"Fetching audio for {len(songs)} songs...")
            git("sparse-checkout", "set", "--no-cone", *patterns, cwd=clone)

        for song_id, (song_dir, audio_files) in songs.items():
            audio = clone / "songs" / song_id
            if not (audio / "Inst.ogg").exists():
                print(f"  {song_id}: no Inst.ogg, skipped")
                continue
            out = DEST / song_id
            out.mkdir(parents=True, exist_ok=True)
            for data in song_dir.glob("*.json"):
                shutil.copy2(data, out / data.name)
            if (song_dir / "subtitles").is_dir():
                shutil.copytree(song_dir / "subtitles", out / "subtitles", dirs_exist_ok=True)
            for name in audio_files:
                if (audio / name).exists():
                    shutil.copy2(audio / name, out / name)
            print(f"  {song_id}")

        levels = clone / "preload" / "data" / "levels"
        if levels.is_dir():
            weeks = ROOT / "data" / "fnf" / "weeks"
            weeks.mkdir(parents=True, exist_ok=True)
            for week in levels.glob("*.json"):
                shutil.copy2(week, weeks / week.name)

        conversations = clone / "preload" / "data" / "dialogue" / "conversations"
        if conversations.is_dir():
            dialogue = ROOT / "data" / "fnf" / "dialogue"
            dialogue.mkdir(parents=True, exist_ok=True)
            for conversation in conversations.glob("*.json"):
                shutil.copy2(conversation, dialogue / conversation.name)
    print(f"Done. Songs are in {DEST}.")


if __name__ == "__main__":
    main()
