# logic-whip

A realistic braided bullwhip for FiveM. Standalone: no framework, no dependencies.

## Features

- **Custom whip model:** braided leather handle with gold fittings and a 2 m tapered lash ending in a popper.
- **Physical lash:** follows your hand, drags on the ground, and flicks when you strike. It sleeps when idle, so it costs nothing while you stand still.
- **Hand attach:** the handle is attached to the hand bone, so it costs nothing to keep it in your fist.
- **Strike system:**
  - Left click to crack the whip.
  - A player or NPC in front of you gets hit: a hit reaction from the direction of the strike, a light screen shake for players, and lash marks that build up with each hit.
- **3D sound:** whip crack and hit sounds, positioned in the world, heard by everyone nearby.
- **Server-validated:** strikes are rate-limited and distance-checked on the server.

## Install

1. Download `logic-whip.zip` from the [latest release](https://github.com/i-StarKK/logic-whip/releases/latest).
2. Extract the `logic-whip` folder into your `resources` folder.
3. Add `ensure logic-whip` to your `server.cfg`.

The server console tells you when a new version is available. Set `checkUpdates = false` in `shared/config.lua` to turn that off.

### Updating

Replace the folder with the new release. Keep your own `shared/config.lua` if you changed it, and check the changelog for new options.

## Usage

| Action | Default |
|---|---|
| Take out or put away the whip | `/whip` |
| Crack or strike | Left mouse button (rebindable in GTA settings) |

## Configuration

Everything is in `shared/config.lua`.

### Permissions

`ace = false` lets everyone use the whip. To restrict it, set `ace = 'whip.use'` and add this to `server.cfg`:

```
add_ace group.admin whip.use allow
```

### Hits

- `hit.damage`: health damage per hit. The default is `0` (cosmetic only).
- `hit.bloodPack`: the lash-mark damage pack. Set it to `false` to disable the marks.
- `hit.reach`: the strike distance in metres.

### Attach

- `attach.offset`: handle position in the hand.
- `attach.rotation`: handle rotation in the hand.

### Lash

- `lash.iterations`: higher values give a stiffer lash.
- `lash.stiffness`: the leather stiffness.
- `lash.damping`: how quickly the lash calms down.
- `lash.wakeDistance`: how far the hand must move before a resting lash simulates again.

## Performance

- The lash simulates only while it moves. Standing still with the whip in hand drops to near 0 ms after half a second, even while the idle animation moves the hand.
- Whips of other players are simulated only within `syncDistance`.

## Project structure

```
logic-whip/
├── fxmanifest.lua
├── shared/config.lua     all settings
├── client/main.lua       lash physics, grip, strikes, sound
├── server/main.lua       command, validation, update check
├── html/                 NUI 3D audio and sounds
└── stream/               whip models, textures and archetypes
```

## Credits

- **StarK (Moayed) - logic:** script, models, braided-leather texture and sounds.
- **Poly Haven:** popper fibre texture (CC0).
