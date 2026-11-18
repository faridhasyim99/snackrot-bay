# SNACKROT BAY — Steal a Snackrot

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![make.fun · rank](https://make.fun/badge/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![make.fun · reward](https://make.fun/badge/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

An original Roblox brainrot game for the [roblox-brainrot-01 bounty](https://make.fun/bounty/roblox-brainrot-01) on make.fun, by [mrsusey](https://github.com/faridhasyim99).

## What is it?

Absurd snack-creatures wash up on a tropical bay's tide conveyor. Buy them, park them on your beach-hut base, and watch the cash tick up — while other players try to steal them from you. A giant wave, the Snackwave, sweeps the map every few minutes and flings anyone caught outside their base back home.

## How to play

- **Buy** — walk up to a snackrot on the central conveyor and hold the prompt to buy it. It flies to a free slot on your base and starts earning $/s.
- **Earn** — every brainrot on your base pays its rate once a second. Rarer snackrots and mutations (Golden, Lava, Diamond, Rainbow, Cosmic) pay more.
- **Steal** — walk to another player's base and hold the prompt on their snackrot (3 seconds). Their loss, your gain — unless their base is locked.
- **Lock** — lock your base for 60 seconds when you smell a thief. It has a 180-second cooldown.
- **Rebirth** — trade your whole base for +25% income per rebirth, stacking forever.
- **Upgrades** — buy walk speed and a flat income bonus.
- **Survive the Snackwave** — a wall of water sweeps the bay every 4 minutes and washes the conveyor clean. Get home, or get flung.

## The cast

Fourteen original snack-creatures across six rarities (Common → Secret): Sir Waddlesworth, Baron von Baguette, Captain Crumb, DJ Nacho Narwhal, Madame Llama Latte, Sir Borks-a-Lot, Professor Wobble, The Forbidden Burrito, Count Spaghetti, Queen Blobert, Grandpa Gnocchi, El Churro Supremo, The Infinite Meatball, and Bananaconda Prime. No copied IP anywhere — every character, name, and quirk line is original.

## Build

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

`main.ts` (Node 22, standard library only) copies `game.rbxl`, `src/`, `screenshots/`, and `PLAY.json` into the output directory and writes `dossier.json` with the vendored make.fun library.

## Layout

- `src/shared/` — `BrainrotData` (rarities, mutations, species, prices) and `Util` (formatting, weighted picks).
- `src/server/` — `GameServer` (the whole loop), `State` (single source of truth for player data), `WorldBuilder` (the bay, the plots, the conveyor), `BrainrotFactory` (character models), `Debug` (reviewer helpers for TOUR.json).
- `src/client/` — `GameClient` (HUD: cash, income, rebirths, wave timer, lock/rebirth/upgrade buttons, banner, toasts, leaderboard).
- `screenshots/` — renders of the game's own world, made for the hand-in (the game's first thumbnail on Roblox must match the cover screenshot).
- `PLAY.json` — the published place's ids, filled in when the place is published on Roblox.
- `TOUR.json` — reviewer keys and Debug functions for each screenshot.

## License

MIT — see [LICENSE](LICENSE).
