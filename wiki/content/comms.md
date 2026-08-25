---
title: Radio & Comms
category: Your Ship
order: 3
blurb: Ship-scoped radio, the galaxy-wide Wideband channel, and holopad calls between ships.
---

There is no telecomms on Voidcrew. No relay to build, no stack to repair, no z-level to be on. Radio just works, everywhere, forever. What changed instead is *who hears you*: every ordinary channel is scoped to a single ship, so your crew chatter reaches your crew and nobody else. The one channel everyone in the galaxy shares is **Wideband**.

## Your ship's channel

Press `;` before a message to talk on your headset's main channel. On a station that would be the common channel; here it is **your ship**. Messages are tagged with the ship's name so you can tell at a glance which hull you are hearing.

Department channels work the same way and are scoped the same way. Your engineering channel reaches the engineers on *your* ship, not the engineers on someone else's.

### Sticky binding

Your headset binds to a ship, and that binding follows you off it. It is set when you spawn in, or the first time you use a radio while physically aboard a ship. Once bound it stays bound, walking onto a planet, into a ruin, or onto someone else's deck does not change it.

This means:

- An away team on a planet still talks to the crew back on the ship.
- A boarding party keeps its own crew channel while standing inside the enemy hull, and can also overhear the local traffic of the ship it is standing in.
- A **stolen headset stays bound to its old ship**. Take one off a body and you are listening to their crew, not yours, until it is re-tuned.

To re-tune a radio, use a **multitool** on it while aboard the ship you want it bound to. It rebinds to whatever hull it is currently sitting in.

!!! warning "Check your headset before you trust it"
    A headset picked up off the deck of a wreck, or handed to you by someone you just met, may still be transmitting to its original crew. Multitool it before you say anything sensitive on it.

## Wideband

**Wideband** is the galaxy-wide hailing channel. Every headset carries it, no research or equipment is needed, and it reaches every radio in the galaxy regardless of distance or z-level.

Speak on it by prefixing your message with `:w` or `.w`.

Use it for the things that need to leave your hull: hailing a ship you can see, arranging a trade or a meeting, calling for help, warning other crews about something dangerous, or negotiating instead of shooting. It is also where a number of galaxy-wide events announce themselves, so expect traffic you did not ask for.

Remember that a Wideband transmission tells everyone that you exist and that you are talking. It says nothing about where you are, but the people who want to find you are listening too.

A few other frequencies are also unscoped and reach the whole galaxy rather than one ship, including the syndicate channel. If you are carrying a headset that has one, assume the wrong people can hear it.

## Ship-to-ship hails from the helm

The helm console's **Comms** tab sends a short transmission from the ship itself. It reaches every vessel within your four-tile view ring (the same distance you can see) and lands on their helm as a logged message with a pulsing marker at your position.

The trade-off is deliberate: **hailing gives you away**. A transmission identifies your ship on the receiver's chart exactly as if they had scanned you, so an anonymous blip that says hello stops being anonymous. Staying quiet is a valid tactic, and a pirate lurking on your tile has a reason not to greet you. See [Piloting Your Ship](piloting.md).

## Holopad calls

Holopads dial by **site**, not by area. Open one and the list shows:

- Rooms on your own ship, by area, like a station intercom.
- Every other ship in the galaxy, as one entry per ship: calling it rings **every pad on that ship at once**.
- Every trader outpost and player-founded outpost, the same way.
- Unregistered pads in ruins and wrecks, but only ones sharing your physical location.

Calls are allowed galaxy-wide, matching Wideband. Answering projects the caller into the room as a hologram that can walk around, look, and talk.

Two rules apply to calls between different ships:

- **Nobody can force their way onto your pad.** Cross-ship calls always ring and always have to be answered. Keycard authorisation cannot auto-connect a call from another vessel.
- **Moving cuts the call.** If either ship docks, undocks or jumps mid-call, the link drops and both pads announce that the carrier was lost. Calls within one ship are unaffected: both ends move together.

The ringing pad also announces where the call is coming from, so you know which ship or outpost is on the line before you pick up.

## Pirate hails

Hostile ships hail before they shoot. When one does, **every holopad on your ship rings** and the helm posts a priority alert.

Answer it from the holopad interface: the incoming hail appears in the pad's call list alongside ordinary holocalls, labelled as a hostile vessel. Answering opens a negotiation with the pirate captain's hologram. You can pay them off, talk your way out, or stall.

You have **twenty seconds** to answer, with a reminder at the halfway mark. Ignore it and they open fire. Lock weapons on them or shoot first, and the hail ends immediately and they engage. See [Ship Combat](ship-combat.md).

## When comms go down

Radios can be knocked out. An EMP silences everything it touches, radio jammers work the way they do on a station, and a **communications blackout** event kills every radio, intercom and holopad aboard one ship for about twenty seconds, including Wideband. Nothing needs repairing afterwards; the radios come back on their own.

The warning you get is the blackout announcing itself over the very radios it is about, degrading into static mid-sentence. If a message cuts out like that, you have a few seconds before the ship goes quiet.
