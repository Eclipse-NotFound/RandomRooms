# RandomRooms

Procedurally generated building interiors for **Fallout Equestria: REMAINS** — replaces the fixed vanilla room layouts with generated spaces that expand infinitely under the same seed.

English (this page) · [简体中文](README.zh-CN.md)

## Highlights (v13)

- **v13** adds per-area and per-room danger/value planning to the existing v12.3 architecture. **v12.2** and **v12.3** remain selectable for comparison.
- Danger affects main encounter frequency, size and placement; value affects extra reward opportunities. Native ecology, enemy strength and loot rules remain in control. Mines, spider mines and drones use separate placement rules, including low-danger/high-value areas and blind corners.
- Ground and ceiling turrets guard useful connections. Some turret areas receive a security terminal with a supported, covered operating position; it controls the whole native Location.
- **Shift+F3** shows room purposes, D/V, planned spawn points, current units, turret guard targets and live weapon-facing rays. Rays are diagnostic directions, not hit predictions.
- Four themed scene types with distinct layouts, materials, furniture and hazards: **factory**, **abandoned stable**, **sewers**, and **city ruins** (plus "random").
- Same-seed infinite expansion: new columns/rows generate as you approach the map edges; existing rooms, looted containers and connections are preserved.
- Full vanilla exploration content wired in since v10: enemy packs, turrets, robot pods, mines/traps/laser tripwires, usable terminals (robot control, safe-unlock, lore), reward containers, workbenches, chem stations, occasional merchants and doctors — all following vanilla drop and hack rules.
- Vanilla doors, trapdoors, glass windows, furniture, combat and destruction behaviour; every open edge is actually traversable, and generation checks clearance, ladder footholds and returnability.

## Requirements

- Fallout Equestria: REMAINS (1.02).
- The one-time **ModLoader** game patch — see
  [ModLoader Releases](https://github.com/Eclipse-NotFound/ModLoader/releases) → `Remains-GamePatch`.

## Install

1. Download a published package from [Releases](../../releases). The source tree may be ahead of published packages; local v13 deployment details are in the [validation record](design/v13-content-runtime/validation.md).
2. Copy the zip's `mods` folder into your game root (next to `pfe.swf`).
3. Restart the game, return to town, then enter a new random area.

## Usage (hotkeys)

| Key | Action |
|---|---|
| **F1** | Pick version (v13/v12.2/v12.3), confirm the seed, then choose a scene: factory / abandoned stable / sewers / city ruins / random. Starts from floor 1 with a 5×5 grid. |
| **F2** | Return to town. |
| **F4** | Next floor — keeps your chosen algorithm, seed and scene. |
| **F5** | Enter a safely furnished showcase gallery for the selected algorithm/scene. |
| **Shift+F3** | Toggle the in-game diagnostic overlay; preference is saved. |

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
