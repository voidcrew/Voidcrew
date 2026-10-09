/**
 * Who turns up to sing against a lone challenger: the song's own opponent, matched as closely as
 * the station gets to their Funkin' sprite. Skin, hair and eyes are coloured to the sprite, and
 * the outfit is recoloured to match (most station clothes can take any colour). Unknown
 * characters (and the song that ships with the game) get Experiment Dearest.
 *
 * Everyone summoned holds a battle microphone (Pico and Tankman a gun as well), moves in their own
 * style (see fnf_apply_style) and is rigged like a roundstart species even if they aren't one.
 *
 * Each entry, by character (as Funkin' names them, without variants):
 * - "name", "species"
 * - "skin": a colour for the skin, or "tone": one of the human skin tones
 * - "female": TRUE for a woman's body
 * - "hair", "hair_colour", "eyes"
 * - "outfit": list(list(item type, greyscale colours or null), ...)
 * - "mutant_colour", "ethereal_colour": for lizards and ethereals
 * - "gun": TRUE to hold a gun as well as the mic, or the prop gun's type
 * - "size": how big they're drawn, for the ones who tower over (or come up short of) Boyfriend
 * - "socks": which socks they wear; "hair_gradient": list(gradient style, colour) for their hair
 * - "face_eyes": the eyes their face has in a battle (see faces.dm), if not solid black: "white" for
 *   the ones Funkin' draws with white eyes, "demon" for Daddy and Mommy Dearest's red glare
 */
GLOBAL_LIST_INIT(fnf_opponents, list(
	"dad" = list(
		"face_eyes" = "demon",
		"name" = "Daddy Dearest",
		"species" = /datum/species/human,
		"size" = 1.35,
		"skin" = "#c9a2dc",
		"hair" = "Swept Back Hair",
		"hair_colour" = "#5b6187",
		"eyes" = "#6b2f8c",
		"outfit" = list(
			list(/obj/item/clothing/under/suit/black, null),
			list(/obj/item/clothing/shoes/laceup, null),
		),
	),
	"mom" = list(
		"face_eyes" = "demon",
		"name" = "Mommy Mearest",
		"species" = /datum/species/human,
		"size" = 1.3,
		"female" = TRUE,
		"skin" = "#e2c4ee",
		"hair" = "Very Long Hair",
		"hair_colour" = "#6e1510",
		"eyes" = "#7a2a9c",
		"outfit" = list(
			list(/obj/item/clothing/under/dress/eveninggown, "#d0102c"),
			list(/obj/item/clothing/shoes/jackboots, null),
		),
	),
	"pico" = list(
		"face_eyes" = "white",
		"name" = "Pico",
		"species" = /datum/species/human,
		"tone" = "caucasian1",
		"hair" = "Spiky",
		"hair_colour" = "#ff7a2a",
		"eyes" = "#3fbf4f",
		"gun" = TRUE,
		"outfit" = list(
			// Green shirt, tan trousers (the colours are shirt, buckle, belt, trousers).
			list(/obj/item/clothing/under/costume/buttondown/slacks, "#3fa34d#c0c0c0#5a3a22#c89a64"),
			list(/obj/item/clothing/shoes/sneakers, "#8a1f2a#f2e6d8"),
		),
	),
	"darnell" = list(
		"face_eyes" = "white",
		// Red-brown skin, a huge purple flat-top, purple hoodie, near-black grey-green trousers, and
		// big white sneakers with orange flames.
		"name" = "Darnell",
		"species" = /datum/species/human,
		"skin" = "#a83838",
		"hair" = "Flat Top (Big)",
		"hair_colour" = "#4a3c78",
		"eyes" = "#1a1a1a",
		"outfit" = list(
			list(/obj/item/clothing/under/color, "#283028"),
			list(/obj/item/clothing/suit/jacket/oversized, "#803888"),
			list(/obj/item/clothing/shoes/sneakers, "#f8f4f8#e8952a"),
		),
	),
	"nene" = list(
		"face_eyes" = "white",
		"name" = "Nene",
		"species" = /datum/species/human,
		"female" = TRUE,
		"tone" = "caucasian1",
		"hair" = "Messy",
		"hair_colour" = "#2b2e55",
		"eyes" = "#d02030",
		"outfit" = list(
			list(/obj/item/clothing/under/dress/skirt, "#d83a52#f28cb0"),
			list(/obj/item/clothing/shoes/sneakers, "#f28cb0#ffffff"),
		),
	),
	"gf" = list(
		"name" = "Girlfriend",
		"species" = /datum/species/human,
		"female" = TRUE,
		"tone" = "caucasian1",
		"hair" = "Very Long Hair",
		"hair_colour" = "#7a1a14",
		"eyes" = "#35b7c7",
		"outfit" = list(
			list(/obj/item/clothing/under/dress/eveninggown, "#e0203a"),
			list(/obj/item/clothing/shoes/sneakers, "#d01a2a#d01a2a"),
		),
	),
	"senpai" = list(
		// Orange hair, a pale blue-lavender shirt with a pink tie, dark grey trousers, black shoes.
		"name" = "Senpai",
		"species" = /datum/species/human,
		"tone" = "caucasian1",
		"hair" = "Long Fringe",
		"hair_colour" = "#f2a65a",
		"eyes" = "#3a3a5a",
		"outfit" = list(
			list(/obj/item/clothing/under/costume/buttondown/slacks, "#9aa0f0#c0c0c8#2a2a30#3a3a46"),
			list(/obj/item/clothing/neck/tie, "#e0507a"),
			list(/obj/item/clothing/shoes/laceup, null),
		),
	),
	"tankman" = list(
		"name" = "Tankman",
		"species" = /datum/species/human,
		"size" = 1.1,
		"tone" = "caucasian2",
		"hair" = "Crewcut",
		"hair_colour" = "#1a1410",
		"eyes" = "#1a1a1a",
		"gun" = TRUE,
		"outfit" = list(
			// All in black, as he's drawn.
			list(/obj/item/clothing/under/color, "#1c1c1c"),
			list(/obj/item/clothing/head/helmet, null),
			list(/obj/item/clothing/mask/bandana/black, null),
			list(/obj/item/clothing/shoes/jackboots, null),
		),
	),
	"bf" = list(
		"name" = "Boyfriend",
		"species" = /datum/species/human,
		"tone" = "caucasian1",
		"hair" = "Spiky",
		"hair_colour" = "#35c6ff",
		"eyes" = "#1a1a2a",
		"outfit" = list(
			// White shirt, blue shorts, red cap and sneakers.
			list(/obj/item/clothing/under/costume/buttondown/shorts, "#f4f4f4#d02030#2d5bc8#2d2d33"),
			list(/obj/item/clothing/head/soft/red, null),
			list(/obj/item/clothing/shoes/sneakers, "#d02030#ffffff"),
		),
	),
	"monster" = list(
		// A black body with a lemon for a head.
		"name" = "Monster",
		"species" = /datum/species/lizard,
		"size" = 1.4,
		"mutant_colour" = "#f0dc3a",
		"eyes" = "#1a1a1a",
		"outfit" = list(
			list(/obj/item/clothing/under/color, "#141414"),
			list(/obj/item/clothing/shoes/sneakers, "#141414#141414"),
		),
	),
	"spooky" = list(
		// Skid in his skeleton costume, Pump's pumpkin on his head.
		"name" = "Skid & Pump",
		"species" = /datum/species/skeleton,
		"size" = 0.85,
		"outfit" = list(
			list(/obj/item/clothing/under/costume/skeleton, null),
			list(/obj/item/clothing/head/utility/hardhat/pumpkinhead, null),
		),
	),
	"henchman" = list(
		// Mommy Mearest's limo dancers: pink skin, spiky black hair, black shades, a purple suit
		// jacket over a pink shirt and red tie, baggy grey-green trousers and dark green shoes.
		"name" = "Mommy's henchman",
		"species" = /datum/species/human,
		"skin" = "#f07ab4",
		"hair" = "Spiky",
		"hair_colour" = "#241826",
		"eyes" = "#1a1a1a",
		"outfit" = list(
			list(/obj/item/clothing/under/costume/buttondown/slacks, "#f08ab8#c0283a#5c6e5a#2a3a2a"),
			list(/obj/item/clothing/suit/jacket/oversized, "#5a3a8a"),
			list(/obj/item/clothing/glasses/sunglasses, null),
			list(/obj/item/clothing/shoes/sneakers, "#3a5a44#2a3a30"),
		),
	),
	"otis" = list(
		"face_eyes" = "white",
		// Darnell's mate, up on the speaker in the Pico mix of Stress with his rifle: pale, messy black
		// hair, a purple-indigo jacket, grey trousers, orange and white sneakers.
		"name" = "Otis",
		"species" = /datum/species/human,
		"tone" = "caucasian1",
		"hair" = "Messy",
		"hair_colour" = "#141418",
		"eyes" = "#2a1a10",
		"gun" = /obj/item/toy/fnf_gun/rifle,
		"outfit" = list(
			list(/obj/item/clothing/under/costume/buttondown/slacks, "#4a3aa0#2a2266#6a6a72#2a2a2a"),
			list(/obj/item/clothing/suit/jacket/oversized, "#3e2e8e"),
			list(/obj/item/clothing/shoes/sneakers, "#f0a020#f4f4f4"),
		),
	),
	"spirit" = list(
		"name" = "Spirit",
		"species" = /datum/species/ethereal,
		"ethereal_colour" = "#ff3a3a",
	),
	// Corruption+'s (see corruption.dm), as their sprites have them.
	"kapi" = list(
		// PaperKitty's arcade cat: grey fur and hair, a blue jacket, dark grey trousers, blue sneakers.
		"name" = "Kapi",
		"species" = /datum/species/human/felinid,
		"skin" = "#b8b8c4",
		"hair" = "Messy",
		"hair_colour" = "#848484",
		"eyes" = "#1a1a24",
		"outfit" = list(
			list(/obj/item/clothing/under/color, "#3c3c48"),
			list(/obj/item/clothing/suit/jacket/oversized, "#4860c0"),
			list(/obj/item/clothing/shoes/sneakers, "#4860c0#f4f4f4"),
		),
	),
	"skarlet" = list(
		// Rechi's Skarlet Bunny: pink-white fur, hot pink hair, bunny ears, a blue jacket over white,
		// black boots.
		"name" = "Skarlet",
		"species" = /datum/species/human,
		"female" = TRUE,
		"skin" = "#f8d4e8",
		"hair" = "Long Fringe",
		"hair_colour" = "#fc006c",
		"eyes" = "#78006c",
		"outfit" = list(
			list(/obj/item/clothing/under/costume/buttondown/shorts, "#fce4f0#fc006c#b4a8fc#303048"),
			list(/obj/item/clothing/suit/jacket/oversized, "#0c609c"),
			list(/obj/item/clothing/head/costume/rabbitears, null),
			list(/obj/item/clothing/shoes/jackboots, null),
		),
	),
	"carol" = list(
		// bb-panzu's Carol: brown skin, a big black afro, a maroon turtleneck over a black skirt,
		// striped knee socks and light brown boots.
		"name" = "Carol",
		"species" = /datum/species/human,
		"female" = TRUE,
		"skin" = "#6e4424",
		"hair" = "Afro (Large)",
		"hair_colour" = "#161214",
		"eyes" = "#1a1a1a",
		"socks" = "Knee-high (Striped)",
		"outfit" = list(
			list(/obj/item/clothing/under/dress/skirt/turtleskirt, "#6e1e3c#1a1a1e"),
			list(/obj/item/clothing/shoes/winterboots, null),
		),
	),
	"mora" = list(
		// Broken Wires' last surprise: pale, black hair going purple, a purple top, black cargo
		// trousers, white sneakers.
		"name" = "Mora",
		"species" = /datum/species/human,
		"female" = TRUE,
		"skin" = "#f0f0fc",
		"hair" = "Messy",
		"hair_colour" = "#24243c",
		"hair_gradient" = list("Fade Down", "#543ca8"),
		"eyes" = "#301890",
		"outfit" = list(
			list(/obj/item/clothing/under/costume/buttondown/slacks, "#543ca8#c0c0c8#24243c#24243c"),
			list(/obj/item/clothing/shoes/sneakers, "#f0f0fc#f0f0fc"),
		),
	),
	"marble" = list(
		// A cat girl behind the speaker, only ever seen long corrupted: dark all over.
		"name" = "Marble",
		"species" = /datum/species/human/felinid,
		"female" = TRUE,
		"skin" = "#3c3c48",
		"hair" = "Long Fringe",
		"hair_colour" = "#242424",
		"eyes" = "#1a1a1a",
		"outfit" = list(
			list(/obj/item/clothing/under/color, "#242424"),
			list(/obj/item/clothing/shoes/jackboots, null),
		),
	),
))

/// Anyone without a look of their own is played by an Experiment (a Milkie, stand_in, in a Pico mix).
/proc/fnf_summon_opponent(character, turf/spot, stand_in = /datum/species/experiment)
	// Week 5's "parents" are Mommy and Daddy together; Daddy comes.
	if(character == "parents")
		character = "dad"
	var/list/look = GLOB.fnf_opponents[character]
	var/mob/living/carbon/human/npc = new(spot)
	if(!look)
		npc.set_species(stand_in)
		npc.fully_replace_character_name(npc.real_name, "[npc.dna.species.name] Dearest")
		npc.put_in_r_hand(new /obj/item/fnf_microphone(npc))
		return npc

	if(look["female"])
		npc.gender = FEMALE
		npc.physique = FEMALE
	if(look["tone"])
		npc.skin_tone = look["tone"]
	if(look["mutant_colour"])
		npc.dna.features[FEATURE_MUTANT_COLOR] = look["mutant_colour"]
	if(look["ethereal_colour"])
		npc.dna.features[FEATURE_ETHEREAL_COLOR] = look["ethereal_colour"]
	npc.set_species(look["species"])
	npc.fully_replace_character_name(npc.real_name, look["name"])
	npc.set_facial_hairstyle("Shaved", update = FALSE)
	if(look["hair"])
		npc.set_hairstyle(look["hair"], update = FALSE)
		npc.set_haircolor(look["hair_colour"], update = FALSE)
	var/list/gradient = look["hair_gradient"]
	if(gradient)
		npc.grad_style[GRADIENT_HAIR_KEY] = gradient[1]
		npc.grad_color[GRADIENT_HAIR_KEY] = gradient[2]
	if(look["socks"])
		npc.socks = look["socks"]
	if(look["eyes"])
		npc.set_eye_color(look["eyes"], look["eyes"])
	// Skin no human skin tone covers (Daddy and Mommy are lavender).
	if(look["skin"])
		for(var/obj/item/bodypart/limb as anything in npc.bodyparts)
			limb.add_color_override(look["skin"], FNF_SKIN_PRIORITY)
	npc.update_body(is_creating = TRUE)

	for(var/list/piece as anything in look["outfit"])
		var/item_type = piece[1]
		var/obj/item/clothing/worn = new item_type(npc)
		if(piece[2])
			worn.set_greyscale(piece[2])
		if(!npc.equip_to_appropriate_slot(worn))
			qdel(worn)

	if(look["size"])
		npc.update_transform(look["size"])
	npc.fnf_face_eyes = look["face_eyes"]
	npc.fnf_look = character
	if(!npc.dna.species.limb_rig_shape?["always"])
		npc.add_quirk(/datum/quirk/overanimated)
	// Everyone faces east, so the right hand is the one the crowd sees. Gunners keep the gun there
	// and the mic in the other.
	if(look["gun"])
		var/gun_type = ispath(look["gun"]) ? look["gun"] : /obj/item/toy/fnf_gun
		npc.put_in_r_hand(new gun_type(npc))
		npc.put_in_l_hand(new /obj/item/fnf_microphone(npc))
	else
		npc.put_in_r_hand(new /obj/item/fnf_microphone(npc))
	return npc

/// Pico's (and Tankman's) gun: a stage prop, as big and mean-looking as a real submachine gun, that
/// fires nothing. Handed out for a song and taken back after.
/obj/item/toy/fnf_gun
	name = "prop submachine gun"
	desc = "A chunky plastic submachine gun painted up to look like the real thing. The barrel is solid, and it rattles when shaken."
	icon = 'icons/obj/weapons/guns/ballistic.dmi'
	icon_state = "c20r"
	inhand_icon_state = "c20r"
	lefthand_file = 'icons/mob/inhands/weapons/guns_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/guns_righthand.dmi'
	w_class = WEIGHT_CLASS_NORMAL

/// Stress's tankmen, running in to be shot off the stage: security officers in their armour, with
/// prop guns (glued in their hands) and nothing real on them.
/datum/outfit/fnf_soldier
	name = "Rhythm battle soldier"
	uniform = /obj/item/clothing/under/rank/security/officer
	suit = /obj/item/clothing/suit/armor/vest/alt/sec
	head = /obj/item/clothing/head/helmet/sec
	shoes = /obj/item/clothing/shoes/jackboots
	gloves = /obj/item/clothing/gloves/color/black
	r_hand = /obj/item/toy/fnf_gun

/// Otis's rifle, a wooden-stocked prop.
/obj/item/toy/fnf_gun/rifle
	name = "prop rifle"
	desc = "A wooden-stocked plastic rifle, painted up to look like the real thing. The bolt doesn't move."
	icon = 'icons/obj/weapons/guns/wide_guns.dmi'
	icon_state = "sakhno"
	inhand_icon_state = "sakhno"
	w_class = WEIGHT_CLASS_BULKY
