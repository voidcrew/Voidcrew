---
title: Ship Hacking
category: Danger
order: 1.5
blurb: The electronic warfare suite and its exploit cartridges, attacking a locked ship's lights, doors, air and engines instead of its hull, and what happens when they trace you.
---

Ship hacking is the quiet half of [ship combat](ship-combat.md). Instead of punching holes in a locked ship's hull, an **electronic warfare suite** attacks its onboard systems, killing the lights, bolting the doors, venting the air, freezing the guns. Every effect is temporary and cleans up after itself; the point is to open a window for the guns or the boarding party that follows. The suite is player-built from a circuit board, and the **exploit cartridges** it runs come almost exclusively from the Undertow Exchange.

## The suite

The **Electronic Warfare Systems** research node (160 points, behind Shuttle Warfare Systems) unlocks the machine board and the three tier-1 cartridges. If your crew does not do research, Vex at the [Undertow Exchange](trader-outposts.md) sells the board for 3,200 credits or 3 vouchers, one per round. Build it with two capacitors, a micro-laser and a servo, wrench it down anywhere on your ship, and link it to your weapons system console with a multitool, a freshly built suite also links itself to a free console automatically. One suite per console.

The suite draws about 2 kW while an exploit is warming up or live, and losing power aborts whatever it was doing. Better parts matter: capacitors cut the signature each execution costs (down to a quarter of base), micro-lasers cut the power draw, and servos cut warmup time. Examining the suite shows its current signature, its loaded cartridges and all three reductions.

## Cartridges

Exploits come on physical **cartridges**, inserted into the suite by hand and fired from the console's **Exploits** tab. Each cartridge holds a few charges and burns one per execution; at zero it is a burned-out cartridge, and there are no refills. After any execution, that exploit goes on a 60-second recompile cooldown, and the suite runs one execution at a time.

Research only ever prints the three tier-1 cartridges. Tier 2 and up are sold nowhere but Vex's **Exploit Software** shelf: tier 3 stock is zero-to-one per round, and the tier-4 exotics sit on the rotating shelf and take vouchers only. A cartridge's examine text names its exploit, tier, target subsystem and remaining charges, so looted or traded software is never a mystery.

## Running a hack

Everything hangs off a weapons lock, so the rules are the same as shooting: the target must be a ship (never an outpost), within two overmap tiles, and neither of you in the Neutral Zone. The lock takes five seconds to acquire and **the target is warned the moment you start**, so a hack is never a surprise attack.

With the lock held, the Exploits tab lists your loaded cartridges with an Execute button. Clicking starts a warmup (four to twelve seconds depending on the exploit) with a progress bar and an Abort. If the lock, the range, the power or the cartridge is lost mid-warmup, the execution aborts harmlessly. When it completes, the payload lands for its listed duration and then reverts, undoing only the state it imposed. Bolt Override is the one with a choice: it executes as either **Bolt** or **Release**.

## Signature and the trace

Every execution adds **signature** to your suite: more for nastier exploits, less with good capacitors. Signature bleeds off at 1.5 points a second while idle, but if it reaches 100 you are **traced**: the suite locks itself out for three minutes, and the target is flatly told which ship attacked them. The console's signature meter flashes TRACE IMMINENT from 75 up. In practice you get a couple of cheap harassments or one heavy assault per window before the suite has to cool, so pacing executions is the whole skill of the thing.

## The exploits

All durations revert on their own, every exploit goes on a 60-second cooldown after firing, and prices are Vex's. "Printable" means the [research node](research.md) also covers it.

| Exploit | Tier | What it does to the target | Duration | Signature | Charges | Price |
|---|---|---|---|---|---|---|
| Blackout | 1 | Every light that was on goes out, shipwide | 45s | 10 | 5 | 500 cr, printable |
| Phantom Klaxons | 1 | Trips every fire alarm, dropping all firelocks | 30s | 10 | 5 | 550 cr, printable |
| Bolt Override | 1 | Bolt every powered airlock, or unbolt them all | 30s | 15 | 5 | 700 cr, printable |
| Overvolt | 2 | Electrifies every powered airlock | 30s | 20 | 4 | 900 cr |
| Comms Blackout | 2 | Jams their internal ship channel, both directions | 60s | 20 | 4 | 1,000 cr |
| Ghost Contacts | 2 | Paints three phantom unknown contacts on their helm | 120s | 15 | 4 | 950 cr |
| Scrambler | 2 | Cancels a running interdiction, decloaks them, and blocks both from restarting | 45s | 25 | 4 | 1,300 cr |
| Vent Purge | 2 | Flips every air alarm to panic siphon: vents the atmosphere | 45s | 25 | 4 | 1,400 cr |
| Breaker Trip | 3 | Equipment and lighting channels off at every APC | 30s | 30 | 3 | 1,800 cr |
| Drive Lockout | 3 | All thrust cut: helm, autopilot and engines refuse | 25s | 35 | 3 | 2,200 cr |
| Fire-Control Freeze | 3 | Missile launchers and laser turrets refuse to fire | 20s | 35 | 3 | 2,400 cr |
| Shield Collapse | 3 | Forces a full shield break and blocks reactivation | 30s | 35 | 3 | 2,600 cr |
| Runaway Burn | 4 | Throttle pinned at full burn on the current heading; autopilot disengaged | 15s | 45 | 2 | 3 vouchers |
| Poltergeist | 4 | The ship is shoved onto a random heading every 3 seconds | 20s | 40 | 2 | 2 vouchers |

Comms Blackout and Ghost Contacts only work on player ships. NPC crews have no ship channel to jam and no helm to fool. Shield Collapse and Scrambler require the target to actually have the systems they attack, and Runaway Burn and Poltergeist require the target to be flying.

!!! tip "What a hack window looks like"
    Drive Lockout so they cannot run, Fire-Control Freeze so they cannot shoot back, then close and board while the cooldowns tick. Two tier-3 executions cost 70 signature. One more cheap exploit and you are risking the trace.

## Being hacked

You get warning. A weapons lock announces itself to your whole crew with a combat alarm before any hack can start, the first payload to land names the subsystem it hit, and each additional one escalates to a red alert. Every payload also has a tell you can act on: lights snapping back for a moment before they die, doors bolting, the shipwide venting warning, radio static, engines and weapon mounts sparking. Expired payloads send a "restored" notice.

The hard answer is on your own weapons console: the **Defense** tab's **PURGE INTRUSION** button instantly ends every active payload and hardens your firewalls for two minutes, during which no new connections can be made at all. It is free and always available, but somebody has to be at the console to press it, and it does nothing about the guns that are already coming. Breaking the lock works too: get more than two tiles away, reach the Neutral Zone, or go dark in a nebula.

Physically, the attacker's suite aborts on power loss and cannot be unwrenched mid-execution, so if it comes to boarding, the rack of intrusion hardware is a legitimate target.

## NPC ships

Almost every payload works on NPC ships too, but they are poor victims: their crews automatically purge all intrusions after 45 seconds, and a hostile NPC hull treats a hack exactly like an act of war. Intruding mid-negotiation turns pirates hostile, and idle patrol ships will acquire you and engage.
