---
title: Bounty Hunting
category: Economy
order: 2.5
blurb: Hunt wanted criminals from your mission board, bring them to your mission pad alive for full pay, and send them on to outpost prisons.
---

Wanted criminals hide out on planets, in ruins, aboard pirate ships and among the patrons of trader outposts. Take a bounty from your ship's mission board, find the criminal, subdue them and bring them to your ship's mission pad. They pay the most when they arrive stunned or cuffed and were never downed. Pay works like [missions](missions.md): credits go to the ship account and vouchers appear on the pad. A criminal caught alive goes on to serve time in a player outpost's [prison wing](prison-wing.md).

## The bounty board

The **Wanted** section is at the top of the **Bounties** tab on your ship's mission board. Each [trader outpost](trader-outposts.md) also has a locked **wanted board** on its concourse. It lists the public bounties, but you take a hunt from your own ship's board.

- **Public bounties** are Wanted or Most Wanted criminals, open to every crew. The board holds one, plus one for every four active ships, up to four. A new one goes up at most every 10 minutes.
- **Private offers** are Petty criminals offered to your ship alone. Looking at the board fills your ship up to two offers. When one ends, the next comes 5 minutes later. A ship that hasn't researched Shuttle Warfare Systems mostly gets offers in the Neutral Zone.
- **Special bounties**: the [kingpin](#the-kingpin), and kill-only bounties marked **WANTED: DEAD** ([lairs and the lich](#lairs-and-kill-only-bounties)). They don't take up a public slot.

### Reading a card

Each card is a wanted poster:

- **WANTED** or **MOST WANTED**, and **Private offer** on one made to your ship alone;
- the mugshot, name, species, sex and alias. "Old photo" under the mugshot means it shows how they used to look (a trader-outpost fugitive);
- how they're wanted and what for: **Wanted alive**, **Wanted dead or alive** (the kingpin) or **Wanted dead** (lairs and the lich);
- where they were last seen, and the zone;
- the reward: the full pay, in credits and vouchers. The card doesn't show what a downed or dead catch pays; see [the pad and turning in](#the-pad-and-turning-in);
- the time left.

The card doesn't say what kind of criminal it is, or how they fight. [The three kinds of criminal](#the-three-kinds-of-criminal) below does. A private offer shows no mugshot until you accept it.

The wanted board on a trader outpost's concourse shows the same posters without the buttons or the clock, and says "Seen on this concourse" for a fugitive hiding among the patrons there.

### Rewards

The reward is fixed when the bounty is posted. It depends on the tier and the zone the criminal is in.

| Tier | Neutral Zone | Contested Zone | Lawless Zone |
|---|---|---|---|
| Petty (private offers) | 1,100–1,500 cr | 1,870–2,550 cr | 2,860–3,900 cr |
| Wanted | 1,200–1,600 cr + 1 voucher | 2,040–2,720 cr + 1 voucher | 3,120–4,160 cr + 2 vouchers |
| Most Wanted | 3,000–3,800 cr + 2 vouchers | 5,100–6,460 cr + 2 vouchers | 7,800–9,880 cr + 3 vouchers |

### Time limits

| Listing | Time |
|---|---|
| Public bounty | 45 minutes. The clock stops while a crew hunts it, for up to 30 minutes of each crew's hunt. |
| Private offer | 20 minutes to accept it, then 30 minutes to bring them in. |

## Taking a bounty

Press **Hunt** on a public bounty, or **Accept Offer** on a private offer. This puts a waypoint on your helm chart (for a pirate ship, the waypoint follows the ship), lets you link GPS units to the criminal's last sighting, and sends your ship notices when anything changes. It doesn't use a mission slot.

- Your ship can hunt **one** public bounty at a time. The kingpin and kill-only bounties count as that one. Private offers don't.
- **Abandon** frees your hunt, but your ship can never hunt that bounty again. **Drop Offer** closes a private offer.
- Any crew that gets a public bounty's criminal onto its own pad gets paid, whether it was hunting or not. A private offer only pays the ship it was offered to.
- **Warrant** prints a warrant on your mission pad: the mugshot, the listing, the reward, and all but one of their distinguishing features. The printer needs 30 seconds between warrants, and each ship gets three per bounty.

## Finding them

A criminal appears once their site is loaded, away from any players. What they're doing depends on where they are.

| Where | What they're doing |
|---|---|
| Planets | Exploring near a ruin, or camping in the open |
| Ruins | Going through a crate or a closet |
| Pirate ships | Chatting with the pirate crew, or going through its lockers |
| Trader outposts | Blending in with the patrons |

Tap a handheld GPS on the mission board, or press **Link Mission Beacons** while wearing a MODsuit with a GPS module. This links the sighting beacon (tagged WANTED) of every bounty your ship hunts. The beacon moves every 2 minutes to a spot within 5 tiles of the criminal, and stays put while they are hiding. There's no beacon at trader outposts.

If you leave and the site unloads, the criminal goes with it. They're back the next time it loads, fully healed and out of any cuffs. They still count as the worst state they ever reached, so one you downed never pays full afterwards.

Meek and normal criminals notice anyone within 6 tiles holding a weapon, cuffs or a warrant, and a meek one also notices anyone running at them. Walk up with empty hands. Mini-bosses go for any hunter they see.

## The three kinds of criminal

### Meek

About 70% of Petty criminals and 30% of Wanted ones are meek. They never start a fight.

- They sprint faster than you can run, and duck about half the shots fired at them while sprinting. After about 8 seconds of sprinting they're winded and slow down.
- They hide in a locker or crate, pose as a potted plant, or stand still on a dark tile. Opening the locker, bumping into them, examining them from the next tile, hurting them, or lighting up their dark spot finds them. They shove you back a tile and run again.
- After a minute and a half in hiding they start to fidget: a rustle or a shake every 20 seconds. If nobody is around for a few minutes, they come out.
- Cornered, they shout and aim a small pistol for half a second, then fire eight quick shots. A stamina hit during the aim makes them fumble it.
- 120 health. Three disabler shots stun one.

**Bring:** a disabler or other ranged stun, a flashlight, cuffs, and someone to block the exits.

!!! tip "Bring a light for runners"
    A meek criminal hiding in the dark gives up as soon as the tile is lit. A flashlight finds them faster than walking into every corner.

### Normal

About 70% of Wanted criminals and 30% of Petty ones are normal. A Wanted criminal on a pirate ship is always normal.

- They notice anyone holding a weapon, cuffs or a warrant within 6 tiles. Cuffs or a warrant and they stop and watch you. A weapon out and they fight.
- Each has one fighting style: fists (tougher, and harder to stun), a knife (cuts that bleed), a pistol (keeps its distance and empties a 15-round magazine before reloading), a shotgun loaded with buckshot (close range, reloads after four shells), a baseball bat (knocks you back) or thrown bottles. Wanted criminals carry a combat knife, a metal bat or a combat shotgun instead. Their weapons hit like the real thing.
- They may have up to two companions who fight beside them. Companions pay nothing. They may run when badly hurt or when their criminal goes down, and give up for good once stunned.
- Below 40% health, with two hunters nearby who can see them, they may give up and put their hands up. Someone who has given up counts as stunned: cuff them for full pay. Stop hitting them, because they can still be downed.
- Badly hurt with nobody around, they break off and retreat. They never heal.

**Bring:** a partner, stun weapons, armour and cuffs.

### Mini-bosses

Every Most Wanted criminal is a mini-boss with one of five kits.

- Their health grows with the number of hunters who can see them when the fight starts, and with anyone who hurts them later.
- Every ability winds up first, with a sound and a mark on the floor. Move out of the mark.
- They break tables, chairs, windows and grilles, and up to two interior walls or doors in a fight.
- While fresh they ignore stuns and stamina damage completely.
- Below 40% health they are **worn out**: "breathing hard and slowing down". They move slower, use their abilities less often, and stun weapons work on them. About five disabler shots stun one (six for the Heavy).
- They go down at 25% health. Between 40% and 25% is your window to stun and cuff them for full pay.
- After getting up from being downed, they shrug off stamina damage for 20 seconds.

| Kit | Looks like | What it does | How to handle it |
|---|---|---|---|
| Juggernaut | An armoured criminal in riot plates | Charges along a line after a roar, smashing what's in the way. Slams the floor around it when you're close. Resists damage. | Step off the charge line. If it charges into something it can't break, it reels for 2 seconds and takes extra damage. |
| Pyromaniac | A scorched criminal in a fire suit | Sweeps a cone of fire 3 tiles long and throws molotovs that leave burning floor. Fire can't hurt it. | Stay more than 3 tiles away and off burning floor. Use lasers or bullets, not fire. |
| Demolitionist | A criminal in a hard hat with a grenade bandolier | Keeps 4 to 6 tiles away and throws grenades with a blinking fuse. Blows holes in interior walls and doors to reach you behind cover. | Close the distance, and move off the blinking ring. |
| Ghost | A hooded criminal with a long knife | Fast. Dashes in with cuts that bleed, cloaks into a shimmer, dodges shots while moving, and backs off after two cuts. | A flash or a hit breaks the cloak. Shoot it when it stops moving. |
| Heavy | A heavily armed criminal with a belt-fed gun | Heavy armour, slow. Shows a laser sight and a red cone, then fires a burst into it. Drops a barricade that stops half your shots. | Get out of the red cone before it fires. Go around the barricade. |

!!! warning "Worn out means switch to stuns"
    Once a mini-boss is worn out, stop using lethal weapons. A few more hits put it under 25%, and a downed criminal only pays 60%.

## Taking them alive

- **Downed.** At 25% health a criminal collapses. A hit on one still standing can't take them past that line, so one shot never kills them. A downed criminal can still be killed.
- **They get back up.** Meek criminals after 60 seconds, normal ones after 75, mini-bosses after 45. They groan and try to rise for the last 10 seconds. Cuffed, they stay down. A stamina hit on a downed criminal starts their clock over.
- **Cuffs** only go on a criminal who is downed, stunned or has given up, and take 2 seconds. Reaching for a free one's wrists sets them off: a meek one runs and a normal one fights.
- **Restraints.** Handcuffs hold for good. Cable restraints slip after 3 minutes and zipties after 5, with a visible struggle for the last 20 seconds. Mini-bosses snap them in half the time.
- **Dragging.** You can pull a criminal who is downed, stunned, cuffed or dead. A free one pulls away.
- **Carrying.** A criminal lying on the floor who could be dragged can also be carried over your shoulders: grab them aggressively, then drag them onto yourself. They squirm off once they come round or get up.
- **No shortcuts.** Criminals can't be teleported. Transporters won't beam a locker, crate or bag with one inside, fultons won't attach to them, and a bluespace body bag won't fold with a live one in it. Carry them to your ship.
- Turrets, traps, fire and wildlife on their site can't take a criminal below 40% health.

!!! tip "Bring cuffs"
    A stun wears off about 10 seconds after the last stamina hit (12 for a meek criminal). Cuffing takes 2. Have the cuffs in hand before you stun them.

## The pad and turning in

- Put the criminal, or their evidence tag or trophy, on the mission pad's own tile. Not in a locker or a bag, and not next to the pad.
- The pad must be bolted down and aboard your ship.
- The pad says who is on it and what state they're in ("On the pad: Tess Harlow, restrained."), and why it won't take them if it won't. It never says what they'll pay.
- Press **Turn In** on their card. If it's greyed out, its tooltip says why.
- The pad beams them away over 3 seconds. Credits go to the ship account. Vouchers appear on the pad. Your ship's notice says what state they were in and what was paid.

Pay follows the **worst** state the criminal ever reached:

| State | Pays |
|---|---|
| Stunned, given up or cuffed, and never downed | The full reward, with vouchers |
| Downed at any point, even if cuffed or back on their feet since | 60% |
| Dead, or their evidence tag | 25% |
| Standing and free | Refused |

Below full pay you get no vouchers. Instead, each voucher counts as 1,200 cr before the percentage is taken, and it's all paid in credits. For example, a Wanted criminal worth 1,400 cr and a voucher pays 1,560 cr downed and 650 cr dead.

A dead criminal can't be revived. If the body is destroyed (gibbed, dusted, or lost in lava or a chasm), an **evidence tag** turns up nearby. It pays the dead share. If nothing at all is left, the bounty lists again somewhere else 5 minutes later.

## Trader outposts

Petty and Wanted criminals can hide among the patrons at a trader outpost. Most Wanted never do. There's no GPS beacon here. You have to work out which patron it is.

- The fugitive and three **look-alikes** wear the same clothes and go by the same name: "patron" at Waystation Halcyon, "dockhand" at Quartermain Depot and "spacer" at the Undertow Exchange. They have the same species, sex, skin and eyes.
- The mugshot on the card is old. Their hair has changed since, and the old hair doesn't match anyone there now.
- Examine a patron to see their distinguishing features: hair, a scar, a tattoo, a scarf, a limp, glasses, a missing ear. Each look-alike shares one or two of the fugitive's features, never all of them. The warrant lists all of them but one.
- **Ask the traders.** While your ship hunts the bounty, every trader, the barkeep included, has an **Ask about the wanted person** option. Each gives your ship one clue, and each trader a different one: where the fugitive was seen, how their hair looks now, one of their features, or one patron who isn't them.
- **Show the warrant** to the one you think it is. The right person drops the act: a meek one runs, a normal one fights. Anyone else protests and shows you a docking pass. Your ship can show a warrant once every 30 seconds.
- **The alert.** Showing the warrant to the wrong patron raises the alert. So does hitting a look-alike on purpose: a punch, a shove, a baton, a thrown item, a shot aimed at them, or reaching for their wrists with cuffs. Hitting a look-alike is also an outpost strike. At two alerts, the fugitive and the look-alikes walk out to the hangar and leave, and the bounty lists at a different trader outpost 5 minutes later.
- Hitting the right patron on purpose exposes them, the same as the warrant.
- While they blend in, nobody can pull them, and shots aimed at someone else pass through them. The outpost's turrets leave them alone. An exposed fugitive only fights the people who came for it. If it hurts a bystander, the turrets can fire on it.

## Pirate ships

- Wanted and Most Wanted criminals can hide aboard a pirate ship, one per ship. They're never meek there.
- The card says "Somewhere aboard the" ship, and your helm waypoint follows the ship.
- They keep away from the helm, chatting with the crew or going through lockers. The pirates treat them as one of their own.
- This is separate from the pirate captain's own bounty (see [Pirates & NPC Ships](pirates-and-npc-ships.md)). You can collect both.
- If the ship is destroyed with the criminal still alive aboard, they're lost with it, and the bounty lists somewhere else 5 minutes later.

## The kingpin

A crime boss holds court in the lounge at the Undertow Exchange from the start of the round, on the sofa behind a low table, with six armed goons around the room. There is only one each round.

**Talking.** Click him with an empty hand from across the table. You can say "We're here for you.", "Got any work?" or "Walk away."

**Work.** Ask him for work and he offers your crew a [Drug Run](missions.md#street-chemistry). Say "I'll take it." within 3 minutes to sign on. Only one crew can run it at a time, and he won't hire drifters or anyone whose crew has shot at his people. Once your crew works for him, nobody on your crew, and nobody aboard your ship at the time, can hunt him or turn him in for the rest of the round, at any pad. His goons treat you as guests.

**Wanted.** Later in the round he goes on the board, **wanted dead or alive**, and every crew is told.

- The first posting comes at least 45 minutes into the round, with three or more active crews. The next comes 60 to 90 minutes after the last one ends.
- He can only be turned in while he's on the board, wherever he is when it goes up. Kill him before that and there's nothing to claim.
- He stays on the board for 60 minutes, and the clock stops during a shootout. If time runs out while he's in his lounge, he stays there.
- Alive, he pays 6,500–9,100 cr and 2 vouchers, and downed counts as alive. Dead, he pays 80%, all in credits.
- Once he's turned in or killed, he's gone for the rest of the round.

**The shootout.** "We're here for you.", or any attack on him or a goon, starts it.

- The goons reach for their guns for about half a second before anyone fires. No more than two of them draw on one hunter at once. Three carry pistols, two shotguns and one an SMG. They stay near the sofa, and never shoot anyone who is down.
- He never leaves the sofa. Before each shot he aims his .357 revolver at someone with a red line for half a second. He reloads after seven shots.
- Once his goons are down and he's below 40% health, he may give up. He goes down at 25% and gets up after 60 seconds unless cuffed. Five disabler hits in quick succession stun him.
- When he falls, half the goons left run for it.
- The outpost's turrets stay out of it. Fighting his crew earns no outpost strikes, but hitting other players still does.

Once he's down or cuffed, unbuckle him from the sofa and drag him to your ship's pad in the Undertow's hangar.

## Lairs and kill-only bounties

A kill-only bounty is marked **WANTED: DEAD** and pays nothing for a capture. Kill the boss, take the trophy it drops, and turn the trophy in at your pad for the whole reward, vouchers included. Any crew can turn it in. If the trophy is destroyed, the bounty ends. Every crew is told when one goes up.

### Club Volga

A mob nightclub run by Arkady Sokolov, placed in the Contested or Lawless Zone for its bounty.

- The first appears 45 to 60 minutes into the round, once three or more crews are out. The next comes 60 to 90 minutes after the last one closes. It stays up for 60 minutes, and the clock stops while anyone is inside or a crew hunts it.
- It pays 8,160–9,520 cr and 3 vouchers in the Contested Zone, or 12,480–14,560 cr and 4 vouchers in the Lawless Zone.
- You clear it room by room: foyer, cloakroom, casino, main floor, kitchen, VIP lounge, counting room and back office. About two dozen goons keep to their own rooms. The walls can't be broken, and teleporters don't work inside.
- The staff room off the main floor has two rechargers, a first aid locker and no goons. The counting room's vault has a loot cache.
- Two lieutenants hold the back office: **Tommy** with a Tommy gun, and **Brute**, whose punches can knock you down. Kill both and the garage door opens.
- The don waits in the garage in his Mauler. Its health grows with the number of hunters. Its rocket volley marks the floor under each hunter it can see, then fires one rocket at each mark, so get behind a pillar. Its machine gun shows a red cone first. Up close it stomps, throwing you back. An EMP stalls it for 2 seconds. It comes after anyone who hurts it, so you can't pick it off from out of its sight. If nobody fights it for a minute, it goes back to full health.
- When the mech breaks, the don climbs out and fights on foot with his gold Desert Eagle from behind the wreck. He can't be cuffed. His **gold signet ring** is the trophy.
- Nobody in the club shoots a hunter who is down.

### The lich

When Ilthuun's lair surfaces (see [Hostile Fauna & Elites](threats-and-elites.md)), a kill-only bounty goes up on him. His card recommends a crew of 4 or more. He pays 7,650–9,690 cr and 2 vouchers in the Contested Zone, or 11,700–14,820 cr and 3 vouchers in the Lawless Zone. His clock doesn't run while he's alive. When he dies, a **cracked crown shard** drops by his body, and you have 45 minutes to get it to a pad.

## After the catch: prison wings

A criminal turned in alive joins the **prisoner transfer pool**, and player outposts' [prison wings](prison-wing.md) take them from there. The pad pays whether or not anyone has a prison.

- If your crew runs an outpost with a working prison wing, it gets first claim for 10 minutes. The turn-in notice tells you.
- A prisoner no wing takes within 45 minutes is sent somewhere else.
- They keep their name and crime and arrive in a plain prison jumpsuit with no gear. They're as hurt as when they were caught, but never below half health.

Bounty prisoners earn the outpost more than ordinary prisoners, and they're harder to keep:

| Tier | Earns | Health | Punches | Shiv blows |
|---|---|---|---|---|
| Petty | ×1.5 | 100 | Normal | Normal |
| Wanted | ×2 | 120 | ×1.25 | ×1.15 |
| Most Wanted | ×2.5 | 150 | ×1.5 | ×1.3 |

- Wanted and Most Wanted prisoners get unhappy faster, join riots sooner, and break through the wing's exits faster in a riot. Those who weren't meek hit back more often.
- A Most Wanted prisoner awake and uncuffed in the yard stirs up the others, and is first to shout when a riot starts.
- Meek bounty prisoners are twice as likely to back off when hit. They also go over open serving hatches sooner and faster, hang around the staff door to slip through it when it opens, and run faster when loose.
- Kessler won't take a bounty prisoner for his experiments.
- Bounty prisoners fill at most half of a wing's cells. A wing takes one Most Wanted at a time, plus one more for each cell block extension.

The warden's console has a **Bounty prisoners** setting: **All**, **No Most Wanted** or **None**. Only managers can change it. The console names the next bounty arrival beside the intake switch shortly before they beam in, and a Most Wanted transfer is announced to the crew.

## Rules between crews

- Nobody owns a catch. Whoever gets the criminal onto their own ship's pad and presses Turn In is paid. Cuffing them first gives no claim, and anyone can take the cuffs off with an empty hand.
- When a bounty is turned in, every other crew hunting it is told who claimed it.
- Normal PvP rules apply. At trader outposts, strikes work as usual.

## FAQ

**Why is Turn In greyed out?** The criminal has to be on the pad's own tile, not in a locker or bag. The pad has to be bolted down and aboard your ship. A criminal standing free is refused.

**Why did we only get 60%?** They were downed at some point. Pay follows the worst state they ever reached.

**They got up and ran off.** Downed criminals recover unless cuffed. Cuff them as soon as they're down, or stun them before they go down.

**They vanished when we left the planet.** The site unloaded. They'll be back, fully healed, the next time it loads.

**We abandoned a bounty. Can we still turn them in?** Yes, if it's still up and you bring them to your pad. You just can't hunt it again.

**Can we use a transporter, a fulton or a player bounty to move them?** No. Criminals can't be teleported, and player bounty offers won't take living cargo. Carry them.
