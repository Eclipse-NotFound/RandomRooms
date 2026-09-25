# RandomRooms

Procedurally generated building interiors for **Fallout Equestria: REMAINS** — replaces the fixed vanilla room layouts with generated spaces that expand infinitely under the same seed.

English (this page) · [简体中文](README.zh-CN.md)

## Highlights (v12)

- Two selectable partition algorithms, **v12.2** and **v12.3**, switchable in game to compare results with the same seed and scene.
- Four themed scene types with distinct layouts, materials, furniture and hazards: **factory**, **abandoned stable**, **sewers**, and **city ruins** (plus "random").
- Same-seed infinite expansion: new columns/rows generate as you approach the map edges; existing rooms, looted containers and connections are preserved.
- Full vanilla exploration content wired in since v10: enemy packs, turrets, robot pods, mines/traps/laser tripwires, usable terminals (robot control, safe-unlock, lore), reward containers, workbenches, chem stations, occasional merchants and doctors — all following vanilla drop and hack rules.
- Vanilla doors, trapdoors, glass windows, furniture, combat and destruction behaviour; every open edge is actually traversable, and generation checks clearance, ladder footholds and returnability.

## Requirements

- Fallout Equestria: REMAINS (1.02).
- The one-time **ModLoader** game patch — see
  [ModLoader Releases](https://github.com/Eclipse-NotFound/ModLoader/releases) → `Remains-GamePatch`.

## Install

1. Download `RandomRooms_v12.zip` from [Releases](../../releases).
2. Copy the zip's `mods` folder into your game root (next to `pfe.swf`).
3. Restart the game, return to town, then enter a new random area.

## Usage (hotkeys)

| Key | Action |
|---|---|
| **F1** | Pick algorithm (v12.2/v12.3), confirm the seed, then choose a scene: factory / abandoned stable / sewers / city ruins / random. Starts from floor 1 with a 5×5 grid. |
| **F2** | Return to town. |
| **F4** | Next floor — keeps your chosen algorithm, seed and scene. |
| **F5** | Enter a safely furnished showcase gallery for the selected algorithm/scene. |

To A/B the two algorithms: play one, press F2, then F1 and switch while keeping the same seed and scene. Menus are mouse-driven (scenes also via number keys 1–5, Esc cancels). Old maps already loaded keep their version until you start a new area.

## v12.2 vs v12.3 in one line

v12.2 assigns rectangular rooms by purpose with varied count/size/height and some aligned storeys; v12.3 reduces partition counts and adds thick walls, plinths and copings, merging mostly horizontally into larger multi-rectangle spaces.

## Disable / uninstall

Set the mod's switches to `0` in `mods/loader-manifest.txt` (vanilla rooms return on restart), or delete `mods/RandomRooms`.

## Design documentation

The repo keeps interactive design previews (`design/partition-preview-*/index.html`, self-contained HTML), generation evidence and experiment records (Chinese) under `design/` and `knowledge/`.

## Related mods

[ModLoader](https://github.com/Eclipse-NotFound/ModLoader) ·
[Sandevistan](https://github.com/Eclipse-NotFound/Sandevistan) ·
[MoreSkillsAndWeapons](https://github.com/Eclipse-NotFound/MoreSkillsAndWeapons) ·
[TDFC](https://github.com/Eclipse-NotFound/TDFC) ·
[RealisticVision](https://github.com/Eclipse-NotFound/RealisticVision) ·
[RConnect](https://github.com/Eclipse-NotFound/RConnect)

> Fan mod project; not affiliated with the game's authors.
