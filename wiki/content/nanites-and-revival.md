---
title: Nanites & Revival
category: Your Ship
order: 6
blurb: Nanite research, shared implant capacity, armour upkeep and the limits of automatic revival.
---

Nanites are programmable swarms carried inside a body. They can monitor, heal and protect their host, but their programs share capacity with implants and cyberware. Automatic revival still needs a body that can be revived and medical care afterwards.

## Research and backups

**Basic Nanite Programming** costs **120 research points** and unlocks the basic machinery and programs. Link the machinery to your ship's R&D server with a multitool. Further branches unlock stronger healing, neural and military programs. Military Nanite Programming also requires elite [zone reputation](zone-reputation.md).

Nanite cloud backups belong to the local research setup. Restoring a backup requires every program in it to be researched on the receiving ship. A backup cannot supply programs that ship has not unlocked. Nanite program disks have no cargo export value.

## Shared capacity

A body normally has **20 capacity** for all installed upgrades. [Chrome](cyberware.md), ordinary implants, robotic organs, surgical enhancements and installed nanite programs all use it. Prosthetic limbs cost nothing; implants inside them still count.

Programs count even while switched off. Remove programs to free capacity. Stronger programs generally cost more:

| Program or group | Load |
|---|---|
| Advanced Regeneration or Defibrillation | 6 each |
| Regeneration, mechanical repair, either armour program, Nerve Support or Adrenaline Burst | 3 each |
| Purging, advanced brain healing, Rapid Coagulation or access programs | 2 each |
| Basic brain healing, blood restoration, temperature control and several utility programs | 1 each |
| Sensors and Monitoring | 0 |

Infective Exo-Locomotion costs 2; Nanite Sting costs 1. Other programs have their own costs.

If the body exceeds capacity, its chrome goes offline and beneficial nanite programs pause. Hostile payloads are not disabled by overload. Turning a program off does not clear its load.

## Armour and monitoring

**Dermal Hardening** adds 30 melee and bullet armour. **Dermal Refractive Surface** adds 30 laser and energy armour. Both spend nanites on upkeep and on the damage their added protection absorbs: one nanite per point absorbed.

The programs share the swarm's reserve. Reaching the safety threshold disables both armour effects until the swarm recovers. Armour does not give unlimited protection just because its upkeep is affordable.

**Monitoring** makes the host visible to the crew monitor within its normal scope. **Infective Exo-Locomotion** spreads the swarm to nearby eligible bodies. **Nanite Sting** transfers it to an adjacent eligible target when triggered. Those transfers still obey capacity limits.

## Defibrillation

Nanite **Defibrillation** follows the same eligibility rules as ordinary defibrillator paddles. Missing or badly damaged vital organs, an unsuitable corpse or an unavailable patient can prevent revival. The program rechecks the body after its wind-up.

A successful shock brings the patient back at **-50 health**, like paddles. It does not fully heal them or repair unrelated injuries. Keep treating the patient immediately after revival; the success sound means the revival actually happened.

## The reviver implant

The **reviver implant** heals an unconscious owner over time. It waits until a dead owner is above the hard-critical threshold and eligible for defibrillation before trying to revive them.

A successful revival starts a cooldown of **ten minutes plus the healing cost already accumulated**. The implant does not repeatedly revive someone into hard critical condition. It is still an implant, not a substitute for replacing organs, stopping bleeding or treating severe damage.

## Chrome during failure

EMP, organ failure or capacity overload can take chrome offline. Implant actions and arm weapons stay unavailable while it is down. A powered **voltaic combat cyberheart** can absorb an EMP pulse. An EMP interrupting a Lazarus node's charge does not spend its revival charge. See [Cyberware](cyberware.md) for the catalogue and repairs.
