# rahe-slipstream — Slipstream/Drafting System for rahe-racing

A standalone FiveM resource that adds **slipstream (drafting)** mechanics to [rahe-racing](https://rahe.tebex.io/) races. When you drive behind another car during a race, you progressively gain a speed boost — just like in GTA Online.

**The effect only activates during races.** Outside of a race, the system is completely idle (0% CPU usage).

---

## How It Works

1. The script listens to events fired by rahe-racing (`raceStarted`, `raceFinished`, `playerJoinedRace`)
2. When a race starts, the server registers which players are participating
3. On the client side, the script checks if you're inside the **drafting cone** behind another racer
4. If you are, a progressive forward force is applied to your vehicle
5. The longer you stay in the draft, the stronger the boost becomes (charge system)
6. When you leave the slipstream, you receive a **residual boost** for a short period — enabling the overtake

---

## Installation

1. Place the `rahe-slipstream` folder in your `resources` directory
2. Add to your `server.cfg`:
   ```
   ensure rahe-racing
   ensure rahe-slipstream
   ```
   > **Important:** `rahe-slipstream` MUST start AFTER `rahe-racing`

3. Done! No database required, no framework required.

---

## Configuration

All parameters are in `config.lua`. Here are the main ones:

### Detection
| Parameter | Default | Description |
|-----------|---------|-------------|
| `maxDistance` | 22.0 | Maximum distance (m) to detect the slipstream |
| `minDistance` | 3.0 | Minimum distance (prevents boost when too close) |
| `coneAngle` | 25.0 | Angle of the cone behind the leading car (degrees) |

### Boost
| Parameter | Default | Description |
|-----------|---------|-------------|
| `boostForce` | 0.35 | Base boost force |
| `maxBoostForce` | 0.55 | Maximum force (when fully charged) |
| `chargeTime` | 2.5 | Seconds to charge boost to maximum |
| `residualDuration` | 1.2 | Duration of residual boost after leaving the draft |
| `minSpeed` | 60.0 | Minimum speed (km/h) for the effect to activate |

### Visuals
| Parameter | Default | Description |
|-----------|---------|-------------|
| `enableVisualEffect` | true | "RaceTurbo" screen effect |
| `enableHUD` | true | Charge level bar on screen |
| `enableSound` | true | Sound when entering the draft |
| `debug` | false | Show debug lines and values for testing |

---

## Debug Mode

Set `debug = true` in `config.lua` to see:
- Green lines for valid slipstream connections
- Red lines for vehicles outside the cone
- Distance and charge percentage on screen
- Detection cone visualization

---

## FAQ

**Does it require a framework (QBCore, ESX)?**
No. The script is 100% standalone. It only depends on `rahe-racing` being active.

**Does it work with any version of rahe-racing?**
Yes, as long as rahe-racing fires the events documented in `public/resource/events/`. The events used are:
- `rahe-racing:server:raceStarted`
- `rahe-racing:server:raceFinished`
- `rahe-racing:server:playerJoinedRace`
- `rahe-racing:client:checkpointPassed`

**What if I want it to work outside of races too?**
In `client.lua`, set the `isInRace` variable to always be `true`. Not recommended though.

**The boost is too strong / too weak?**
Adjust `boostForce` and `maxBoostForce` in the config. Values between 0.2–0.4 are subtle/realistic; above 0.6 feels very arcade.

**Any conflicts with other scripts?**
Shouldn't be. The script doesn't modify vehicle handling, doesn't use decorators, and doesn't permanently alter anything on the vehicle. It only calls `ApplyForceToEntity` per frame while the draft is active.

---

## Exported Events (for other scripts)

If you want to integrate with other scripts, the following events are fired:

**Client:**
- `rahe-slipstream:client:raceStateChanged` (bool isRacing) — fired when race state changes
- `rahe-slipstream:client:updateRacers` (table participantServerIds) — updated list of racers

---

## Compatibility

- ✅ QBCore
- ✅ QBox
- ✅ ESX
- ✅ Standalone
- ✅ OneSync (required — already a rahe-racing requirement)

---

## License

MIT — Feel free to use, modify and distribute.
