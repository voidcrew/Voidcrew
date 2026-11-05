"""One compact text table per category, so a reader can hold every peer in view at once.

One row per obtainable, non-abstract, non-cosmetic item, sorted by path so families sit together: short path, name, the stats that matter for the
category, how players get it, and any note. A second list names what was left out and why. Reads items/<category>.json and notes/, writes sheets/<category>.txt.

Notes are any .json or .jsonl file under notes/ but the batch-*.json work lists: rows of {"path": ..., "note": ...}, where path is the item or the type that owns the behaviour.
"""
from __future__ import annotations

import json
from pathlib import Path

from .categories import WORN_CATEGORIES
from .notes import load_notes
from .scoring import score_gun, tier_line

ZONE_LETTER = {'green': 'G', 'yellow': 'Y', 'red': 'R'}
REP_SHORT = {'public': 'pub', 'yellow': 'yel', 'advanced': 'adv', 'elite': 'eli'}
ARMOR_SHORT = [('melee', 'm'), ('bullet', 'b'), ('laser', 'l'), ('energy', 'e'), ('bomb', 'x'), ('bio', 'bio'), ('fire', 'f'), ('acid', 'a'), ('wound', 'w')]
PASS_SHORT = {'PASSTABLE': 'table', 'PASSGLASS': 'glass', 'PASSGRILLE': 'grille', 'PASSCLOSEDTURF': 'WALLS', 'PASSMACHINE': 'machines', 'PASSSTRUCTURE': 'structures', 'PASSDOORS': 'doors', 'PASSMOB': 'mobs'}
COVER_SHORT = {'HEADCOVERSEYES': 'eyes', 'MASKCOVERSEYES': 'eyes', 'GLASSESCOVERSEYES': 'eyes', 'HEADCOVERSMOUTH': 'mouth', 'MASKCOVERSMOUTH': 'mouth', 'PEPPERPROOF': 'pepper', 'EARS_COVERED': 'ears'}
CLOTHING_SHORT = {'STOPSPRESSUREDAMAGE': 'press', 'THICKMATERIAL': 'thick', 'BLOCK_GAS_SMOKE_EFFECT': 'smoke', 'MASKINTERNALS': 'internals', 'HEADINTERNALS': 'internals', 'PLASMAMAN_PREVENT_IGNITION': 'plasmasafe', 'LAVAPROTECT': 'lava', 'GAS_FILTERING': 'filter'}
LEGEND = {
    'guns': 'mode: dmg/shot, /s, dps bare > dps vest; st=stamina dps; ap; cap; passes. spread, recoil, w=weight class. score: s=power on a vest and the tier that number alone gives, bare=with no armor',
    'melee': 'state force; as=attack speed (ds); dps bare > dps at 30 armor; ap; sharp E/P; wb=wound bonus; bl=block; th=throw; w=weight class; r=reach',
    'shields': 'bl=block chance; int=integrity; state force; dps bare > dps at 30 armor',
    'ammo': 'cal, cap, dmg per round, ap, flag, stun/para/kd/immob/uncon in seconds, thru=passes through, price per round, how many guns take it',
    'mech': 'cd=cooldown (ds), drain, dps',
    'modsuits': 'control: armor sum, complexity used/max, drain, slowdown, modules, cell charge. module: cx=complexity, idle/active/use power, cd, type',
    'implants': 'uses, activated, what a case or autosurgeon holds',
    'cyberware': 'zone, slot, load, tier, fitted items with force, surgery reachable',
    'organs': 'zone, slot, fitted items with force, surgery reachable',
    'explosives': 'det=fuse (ds), ex=dev/heavy/light/flame, shrapnel, reagents inside',
}
WORN_LEGEND = 'A=armor m,b,l,e,x=bomb,f,a,w; sum of m+b+l+e; cov=armored zones of 6 (head, chest, arms, legs; groin, hands and feet add no armor); slow; temp: c=cold h=heat; flags; hides; covers'
AVAIL_LEGEND = ('how: $=shop (credits, +vouchers, zones, rep), ped=peddler, print=rs, research rep, hack=hacked autolathe, hid=hidden research node (disk, experiment or emag), disk or other; '
                'craft, @machine=made beside it (!=uses it up), craft:empty=the game empties it as it makes it, use:item=made by using that item, cargo, cargo:emag, :contraband or :special=only once a console is unlocked, '
                'console:mining, golem, cook or bitrunning=that order console, blackmarket=uplink, voucher=mining voucher, drone=exploration drone barter, prison=prison vendor, playershop=a player outpost\'s shop, '
                'loot channels, start=on the crew\'s own ship (start:if only under a condition), '
                'vend=vending machine out in the field, map h/m/r/o/n=placements on hulls, modules, ruins, outposts, NPC ships, rnd=placements by random spawner, in=held in a container with a route')
EFFECT_SHORT = [('stun', 'stun'), ('paralyze', 'para'), ('knockdown', 'kd'), ('immobilize', 'immob'), ('unconscious', 'uncon')]
KIND_LETTER = {'hull': 'h', 'module': 'm', 'ruin': 'r', 'outpost': 'o', 'npc_ship': 'n', 'event': 'e', 'planet': 'p', 'shuttle': 's'}


# How much of a note a row shows, so the whole category still fits in view.
NOTE_LIMIT = 150
# Numbers that say nothing to someone comparing peers.
GENERIC_SKIP = {'volume', 'max_integrity', 'force', 'throwforce', 'demolition_mod', 'wound_bonus', 'exposed_wound_bonus', 'attack_speed', 'block_chance', 'armour_penetration', 'w_class', 'siemens_coefficient', 'resistance_flags', 'sharpness', 'pickup_flags', 'embed_data'}


def clip(text, limit):
    text = str(text)
    return text if len(text) <= limit else text[:limit - 1] + '~'


def short(path):
    return path.replace('/obj/item/', '') if isinstance(path, str) else path


def fmt(value):
    """A number without noise."""
    if isinstance(value, float):
        return f'{value:.1f}'.rstrip('0').rstrip('.')
    return str(value)


def join(*tokens):
    return ' '.join(str(t) for t in tokens if t not in (None, '', [], {}))


def passes_token(flags):
    """What a shot goes through, past the tables nearly all of them pass."""
    through = sorted({PASS_SHORT[flag] for flag in flags if flag in PASS_SHORT} - {'table'})
    return 'thru:' + ','.join(through) if through else None


def effect_tokens(source):
    """Seconds of what a hit does besides damage. The dump keeps them in deciseconds."""
    return [f'{short}{fmt(source[name] / 10)}s' for name, short in EFFECT_SHORT if source.get(name)]


def names(paths, limit=2):
    shown = ','.join(short(path) for path in paths[:limit])
    return shown + (f',+{len(paths) - limit}' if len(paths) > limit else '')


def beside_text(a):
    """The machines a recipe is made beside, and which it uses up."""
    uses_up = a.get('crafted_uses_up') or []
    return ''.join(f"@{path.replace('/obj/machinery/', '').replace('/obj/structure/', '')}{'!' if path in uses_up else ''}" for path in a.get('crafted_beside') or [])


def availability_text(entry):
    a = entry['availability']
    sources = entry['sources']
    tokens = []
    if a['cheapest_credits'] is not None or a['voucher_only_shops']:
        zones = ''.join(ZONE_LETTER.get(z, '?') for z in a['shop_zones'])
        price = f"{a['cheapest_credits']}cr" if a['cheapest_credits'] is not None else 'vouchers'
        vouchers = f"+{a['cheapest_credits_with_vouchers']}v" if a['cheapest_credits_with_vouchers'] else ''
        tokens.append(f"${price}{vouchers} {zones} {REP_SHORT.get(a['lowest_rep_step'], '')}".strip())
    if a['peddler_zones']:
        tokens.append(f"ped {''.join(ZONE_LETTER.get(z, '?') for z in a['peddler_zones'])} {a['peddler_cheapest_credits']}cr")
    ways = []
    if a['printable_roundstart']:
        ways.append('rs')
    elif a['printable_by_research']:
        steps = [node.get('rep_step_with_prereqs') for design in sources.get('printing') or [] for node in design.get('nodes') or [] if not node.get('hidden_with_prereqs')]
        steps = [s for s in steps if s in REP_SHORT]
        lowest = min(steps, key=list(REP_SHORT).index) if steps else None
        ways.append(REP_SHORT.get(lowest, 'res'))
    if a['printable_hacked']:
        ways.append('hack')
    if a['printable_hidden']:
        ways.append('hid')
    if a['printable_from_disk']:
        ways.append('disk')
    if sources.get('printing') and not ways:
        ways.append('other')
    if ways:
        tokens.append('print:' + ','.join(ways))
    if a['crafted']:
        tokens.append('craft' + ('(book)' if a['learned_from'] else '') + beside_text(a))
    elif a['crafted_kit_missing']:
        tokens.append('craft:nokit' + beside_text(a))
    elif a['crafted_empty']:
        tokens.append('craft:empty')
    if a['made_by_use']:
        tokens.append('use:' + names(a.get('used_from') or []))
    cargo = a.get('cargo_words') or []
    tokens += ['cargo'] * ('plain' in cargo) + [f'cargo:{word}' for word in cargo if word != 'plain']
    if a.get('console_words'):
        tokens.append('console:' + ','.join(a['console_words']))
    tokens += a.get('seller_words') or []
    channels = sorted({row.get('channel') for row in sources.get('loot') or [] if not row.get('literal')})
    if channels:
        tokens.append('loot:' + ','.join(str(c) for c in channels))
    if sources.get('starting'):
        if a['starting_outfits'] or a['starting_vendors']:
            tokens.append(f"start:{a['starting_outfits']}o{a['starting_vendors']}v")
        else:
            tokens.append('start:if' if a['starting_conditional'] else 'start')
    if a['field_vendor_kinds']:
        tokens.append('vend:' + ''.join(KIND_LETTER[kind] for kind in a['field_vendor_kinds']))
    placed = [('h', a['placed_on_hulls']), ('m', a['placed_on_modules']), ('r', a['placed_in_ruins']), ('o', a['placed_at_outposts']), ('n', a['placed_on_npc_ships'])]
    placed = ''.join(f'{letter}{count}' for letter, count in placed if count)
    if placed:
        tokens.append('map:' + placed)
    spawned = ''.join(f'{KIND_LETTER[kind]}{count}' for kind, count in a['spawner_placements'].items())
    if spawned:
        tokens.append('rnd:' + spawned)
    if sources.get('in_containers'):
        tokens.append(f"in:{len(sources['in_containers'])}")
    return ' '.join(tokens)


def worn_text(entry):
    armor = entry.get('armor') or {}
    tokens = []
    rated = [f'{letter}{armor[name]}' for name, letter in ARMOR_SHORT if armor.get(name)]
    if rated:
        tokens.append('A ' + ' '.join(rated) + f" sum{entry.get('armor_sum', 0)}")
    if entry.get('coverage'):
        tokens.append(f"cov{entry['coverage']}")
    if entry.get('slowdown'):
        tokens.append(f"slow{fmt(entry['slowdown'])}")
    temps = []
    if entry.get('cold_protection') or entry.get('min_cold_protection_temperature'):
        temps.append(f"c{fmt(entry.get('min_cold_protection_temperature') or 0)}")
    if entry.get('heat_protection') or entry.get('max_heat_protection_temperature'):
        temps.append(f"h{fmt(entry.get('max_heat_protection_temperature') or 0)}")
    if temps:
        tokens.append('temp:' + ','.join(temps))
    flags = sorted({CLOTHING_SHORT[f] for f in entry.get('clothing_flags') or [] if f in CLOTHING_SHORT})
    if flags:
        tokens.append('/'.join(flags))
    hides = [f.replace('HIDE', '').lower() for f in entry.get('flags_inv') or [] if f in ('HIDEFACE', 'HIDEJUMPSUIT', 'HIDEMASK', 'HIDEEYES')]
    if hides:
        tokens.append('hides:' + ','.join(hides))
    covers = sorted({COVER_SHORT[f] for f in entry.get('flags_cover') or [] if f in COVER_SHORT})
    if covers:
        tokens.append('covers:' + ','.join(covers))
    if entry.get('flash_protect'):
        tokens.append(f"flash{entry['flash_protect']}")
    if entry.get('tint'):
        tokens.append(f"tint{entry['tint']}")
    if entry.get('ear_protection'):
        tokens.append('ears')
    if entry.get('allowed_count'):
        tokens.append(f"holds{entry['allowed_count']}")
    if entry.get('storage_slots'):
        tokens.append(f"slots{entry['storage_slots']}")
    traits = [str(t).replace('TRAIT_', '').lower() for t in entry.get('clothing_traits') or []]
    if traits:
        tokens.append('tr:' + ','.join(clip(t, 14) for t in traits[:3]))
    if entry.get('siemens_coefficient') == 0 and 'siemens_coefficient' not in (entry.get('randomised') or {}):
        tokens.append('insul')
    return ' '.join(tokens)


def eyewear_text(entry):
    tokens = [worn_text(entry)]
    if entry.get('sight'):
        tokens.append('sees:' + ','.join(s.replace('SEE_', '').lower() for s in entry['sight']))
    if entry.get('lighting_cutoff'):
        tokens.append(f"light{fmt(entry['lighting_cutoff'])}")
    if entry.get('hud_traits'):
        tokens.append('hud:' + ','.join(t.replace('TRAIT_', '').replace('_HUD', '').lower() for t in entry['hud_traits']))
    return join(*tokens)


def mode_text(mode):
    projectile = mode.get('projectile') or {}
    target = (mode.get('target') or {}).get('vest') or {}
    tokens = [clip(mode.get('label') or '', 10), f"{fmt(mode['damage_per_shot'])}/shot"]
    if mode.get('pellets', 1) > 1:
        tokens.append(f"({mode['pellets']}p)")
    tokens.append(f"{fmt(mode['shots_per_second'] or 0)}/s")
    tokens.append(f"{fmt(mode['dps'] or 0)}>{fmt(target.get('dps') or 0)}")
    if mode.get('stamina_dps'):
        tokens.append(f"st{fmt(mode['stamina_dps'])}")
    tokens += effect_tokens(projectile)
    if projectile.get('armour_penetration'):
        tokens.append(f"ap{projectile['armour_penetration']}")
    if projectile.get('weak_against_armour'):
        tokens.append('weakAP')
    if projectile.get('armor_flag') and projectile['armor_flag'] != 'bullet':
        tokens.append(projectile['armor_flag'][:3])
    if mode.get('capacity'):
        tokens.append(f"cap{mode['capacity']}")
    through = passes_token([flag for name in ('pass_flags_decoded', 'projectile_phasing_decoded') for flag in projectile.get(name) or []])
    if through:
        tokens.append(through)
    return ' '.join(tokens)


def gun_text(entry):
    modes = entry.get('modes') or []
    kinds = {'ballistic': 'B', 'energy': 'E', 'magic': 'M', 'other': 'O'}
    tokens = [kinds.get(entry.get('kind'), '-'), f"w{entry.get('w_class')}"]
    if entry.get('spread'):
        tokens.append(f"sprd{fmt(entry['spread'])}")
    if entry.get('recoil'):
        tokens.append(f"rec{fmt(entry['recoil'])}")
    if (entry.get('two_handed') or {}).get('require_twohands'):
        tokens.append('2H')
    elif entry.get('weapon_weight_name') == 'WEAPON_HEAVY':
        tokens.append('heavy')
    cell = entry.get('cell') or {}
    if cell.get('self_recharge'):
        tokens.append('selfchg')
    reload = entry.get('reload') or {}
    if reload.get('by_the_round'):
        tokens.append('byround')
    if entry.get('semi_auto') == 0:
        tokens.append(f"rack{fmt(entry.get('rack_delay_ds') or 0)}")
    return ' '.join(tokens) + ' | ' + ' ; '.join(mode_text(m) for m in modes[:3]) + (f' ;+{len(modes) - 3}' if len(modes) > 3 else '')


def melee_text(entry):
    tokens = []
    for state in entry.get('states') or []:
        armored = (state.get('target') or {}).get('armored') or {}
        label = {'default': '', 'unwielded': 'one:', 'wielded': 'two:', 'active': 'on:', 'active wielded': 'on2:'}.get(state['state'], state['state'] + ':')
        hit = fmt(state.get('stamina_per_hit') or state.get('force') or 0)
        tokens.append(f"{label}{hit}{'st' if state.get('stamina_per_hit') else ''} {fmt(state.get('dps') or 0)}>{fmt(armored.get('dps') or 0)}")
    extra = []
    if entry.get('attack_speed') not in (None, 8):
        extra.append(f"as{entry['attack_speed']}")
    if entry.get('armour_penetration'):
        extra.append(f"ap{entry['armour_penetration']}")
    sharp = ''.join(s[6] for s in entry.get('sharpness') or [] if len(s) > 6)
    if sharp:
        extra.append(f'sharp{sharp}')
    if entry.get('wound_bonus'):
        extra.append(f"wb{entry['wound_bonus']}")
    if entry.get('block_chance'):
        extra.append(f"bl{entry['block_chance']}")
    if entry.get('throwforce'):
        extra.append(f"th{entry['throwforce']}")
    if entry.get('embed'):
        extra.append('embed')
    if entry.get('reach', 1) != 1:
        extra.append(f"r{entry['reach']}")
    if entry.get('w_class') is not None:
        extra.append(f"w{entry['w_class']}")
    baton = entry.get('baton')
    if baton:
        extra.append(f"baton st{baton.get('stamina_damage')} cd{baton.get('cooldown_ds')} kd{baton.get('knockdown_ds')}")
    return ' ; '.join(tokens) + ' | ' + ' '.join(extra)


def shield_text(entry):
    tokens = [f"bl{entry.get('block_chance') or 0}", f"int{entry.get('max_integrity')}"]
    if entry.get('slowdown'):
        tokens.append(f"slow{entry['slowdown']}")
    if entry.get('transparent'):
        tokens.append('transparent')
    if entry.get('melee'):
        tokens.append(melee_text(entry['melee']))
    return ' '.join(tokens)


def ammo_text(entry):
    return join(entry.get('caliber'), f"cap{entry['capacity']}" if entry.get('capacity') else None,
                f"{fmt(entry.get('damage_per_round') or 0)}dmg", f"({entry['pellets']}p)" if entry.get('pellets', 1) > 1 else None,
                f"st{entry['stamina']}" if entry.get('stamina') else None, *effect_tokens(entry), f"ap{entry['armour_penetration']}" if entry.get('armour_penetration') else None,
                'weakAP' if entry.get('weak_against_armour') else None, (entry.get('armor_flag') or '')[:3] if entry.get('armor_flag') != 'bullet' else None,
                passes_token(entry.get('passes') or []),
                f"{fmt(entry['price_per_round'])}cr/rd" if entry.get('price_per_round') is not None else None, f"guns{entry.get('accepted_by_count', 0)}")


def modsuit_text(entry):
    if 'theme' in entry:
        theme = entry.get('theme') or {}
        return join(f"A{theme.get('armor_sum', 0)}", f"cx{entry.get('complexity_used', 0)}/{theme.get('complexity_max')}", f"drain{theme.get('charge_drain')}", f"slow{fmt(theme.get('slowdown_deployed') or 0)}",
                    f"mods{len(entry.get('applied_modules') or [])}", f"cell{fmt(entry.get('applied_cell_charge') or 0)}")
    if 'complexity' in entry:
        return join(f"cx{entry['complexity']}", f"idle{fmt(entry['idle_power_cost'])}", f"act{fmt(entry['active_power_cost'])}", f"use{fmt(entry['use_energy_cost'])}",
                    f"cd{entry['cooldown_time']}" if entry.get('cooldown_time') else None, entry.get('module_type'), short(entry.get('device')) if entry.get('device') else None)
    return generic_text(entry)


def implant_text(entry):
    if 'holds' in entry:
        return join('holds', entry.get('holds_name') or short(entry.get('holds')))
    if 'starting_organ' in entry:
        return join(f"uses{entry.get('uses')}", entry.get('starting_organ_name') or short(entry.get('starting_organ')))
    if 'activated' in entry:
        return join(f"uses{entry.get('uses')}", 'activated' if entry.get('activated') else 'passive')
    return join(f"cx{entry.get('complexity')}" if entry.get('complexity') else None, f"slot{entry.get('slot_use')}" if entry.get('slot_use') else None)


def organ_text(entry):
    fitted = [join(item.get('name'), f"f{item['force']}" if item.get('force') else None, 'gun' if item.get('gun') else None) for item in entry.get('items_to_create') or []]
    fitting = entry.get('fitting') or {}
    return join(entry.get('zone'), entry.get('slot'), f"load{entry['chrome_load']}" if entry.get('chrome_load') else None, f"t{entry['tier']}" if entry.get('tier') else None,
                'surgery' if fitting.get('by_surgery') else 'nosurgery', f"has:{clip(','.join(fitted), 70)}" if fitted else None)


def explosive_text(entry):
    held = entry.get('reagents_inside') or {}
    ex = '/'.join(fmt(entry.get(k) or 0) for k in ['ex_dev', 'ex_heavy', 'ex_light', 'ex_flame'])
    bomb = '/'.join(fmt(entry.get(k) or 0) for k in ['range_heavy', 'range_medium', 'range_light', 'range_flame']) if entry.get('range_heavy') else None
    return join(f"det{entry['det_time']}" if entry.get('det_time') else None, f'ex{ex}' if ex != '0/0/0/0' else None, f'core{bomb}' if bomb else None,
                f"shrap{entry.get('shrapnel_radius')}" if entry.get('shrapnel_type') else None, 'sticky' if entry.get('sticky') else None, f"holds:{clip(','.join(k.rsplit('/', 1)[-1] + '=' + fmt(v) for k, v in sorted(held.items())), 60)}" if held else None)


def mech_text(entry):
    return join(f"cd{entry['equip_cooldown']}" if entry.get('equip_cooldown') else None, f"drain{fmt(entry['energy_drain'])}" if entry.get('energy_drain') else None,
                f"{fmt(entry['damage'])}dmg" if entry.get('damage') is not None else None, f"dps{fmt(entry['dps'])}" if entry.get('dps') else None,
                f"ap{entry['armour_penetration']}" if entry.get('armour_penetration') else None, f"rounds{entry['projectiles']}" if entry.get('projectiles') else None,
                f"rounds{entry['rounds']}" if entry.get('rounds') else None)


def generic_text(entry):
    reagents = (entry.get('reagents') or {}).get('held') or {}
    tokens = [f"w{entry.get('w_class')}" if entry.get('w_class') is not None else None]
    if entry.get('tool_behaviour'):
        tokens.append(f"{entry['tool_behaviour']} x{fmt(entry.get('toolspeed') or 1)}")
    if entry.get('storage'):
        storage = entry['storage']
        tokens.append(f"slots{storage.get('max_slots')} max{storage.get('max_total_storage')}")
    if reagents:
        tokens.append(f"holds:{clip(','.join(k.rsplit('/', 1)[-1] + '=' + fmt(v) for k, v in sorted(reagents.items())), 50)}")
    elif (entry.get('reagents') or {}).get('maximum_volume'):
        tokens.append(f"vol{entry['reagents']['maximum_volume']}")
    if entry.get('cell'):
        tokens.append(f"cell{fmt(entry['cell'].get('maxcharge') or 0)}")
    if entry.get('slowdown'):
        tokens.append(f"slow{entry['slowdown']}")
    # A rolled var's number is one roll in the dump. randomised_text says what it really rolls.
    numbers = [f'{name}={fmt(value)}' for name, value in (entry.get('other_vars') or {}).items() if isinstance(value, (int, float)) and name not in GENERIC_SKIP and name not in (entry.get('randomised') or {})]
    if numbers:
        tokens.append(clip(' '.join(numbers[:5]), 70))
    if entry.get('melee'):
        tokens.append(melee_text(entry['melee']))
    return join(*tokens)


def randomised_text(entry):
    """A var the game rolls when the item is made: the row's number is one roll, so say what it rolls."""
    return ' '.join(f'rolls:{name}={clip(roll, 40)}' for name, roll in sorted((entry.get('randomised') or {}).items()))


def stats_text(category, entry):
    if category == 'guns':
        return gun_text(entry)
    if category == 'eyewear':
        return eyewear_text(entry)
    if category in WORN_CATEGORIES:
        return worn_text(entry)
    return {
        'melee': melee_text, 'shields': shield_text, 'ammo': ammo_text, 'modsuits': modsuit_text, 'implants': implant_text, 'cyberware': organ_text, 'organs': organ_text,
        'explosives': explosive_text, 'mech': mech_text,
    }.get(category, generic_text)(entry)


def score_cell(entry, rating):
    """A gun's score on the vest, the tier that number alone gives, and its bare number. A tier set by rule has no score to show."""
    rating = rating or {}
    if rating.get('tier') in ('above', 'none') and 'score' not in rating:
        return ''
    scored = score_gun(entry, rating.get('score_inputs'))
    if not scored:
        return ''
    head = f"s{round(scored['score'])} {tier_line(scored['score'])}"
    return f'{head} judged' if scored['bare'] is None else f"{head} bare{round(scored['bare'])}"


def note_for(entry, notes):
    found = []
    for owner in [entry['path']] + list(entry.get('note_owners') or []):
        note = notes.get(owner)
        if note and note not in found:
            found.append(note)
    return ' / '.join(found)


def note_cell(note, previous):
    """A note in a row: clipped, because the whole note stays in notes/, and a ditto mark when the row above has the same one."""
    if not note:
        return ''
    return '(same note)' if note == previous else clip(note, NOTE_LIMIT)


def left_out_reason(entry):
    if entry['status'] != 'ok':
        return entry['status']
    if entry['abstract']:
        return 'abstract'
    if entry['cosmetic']:
        return 'cosmetic'
    if not entry['known_sources']:
        return 'no route'
    if not entry['firm_sources']:
        return 'literal only'
    return None


def known_categories(out):
    return sorted(file.stem for file in (Path(out) / 'items').glob('*.json'))


def sheet_text(category, document, notes, ratings=None):
    items = document['items']
    rated = (ratings or {}).get('items') or {}
    rows, left = [], {}
    previous_note = None
    for path in sorted(items):
        entry = items[path]
        reason = left_out_reason(entry)
        if reason:
            left.setdefault(reason, []).append(short(path))
            continue
        note = note_for(entry, notes)
        score = score_cell(entry, rated.get(path)) if category == 'guns' else ''
        row = ' | '.join(part for part in [short(path), clip(entry.get('name') or '', 34), join(stats_text(category, entry), randomised_text(entry)), score, availability_text(entry), note_cell(note, previous_note)] if part)
        previous_note = note
        rows.append(row)
    legend = LEGEND.get(category, WORN_LEGEND if category in WORN_CATEGORIES else 'w=weight class; tool x speed; slots; contents; cell')
    columns = 'path | name | stats | score | how players get it | note' if category == 'guns' else 'path | name | stats | how players get it | note'
    lines = [f'# {category}: {len(rows)} items. {columns}', f'# {legend}', f'# {AVAIL_LEGEND}']
    lines += [f'# upgrade: {line}' for line in document.get('upgrades') or []]
    lines += rows
    lines.append('')
    lines.append(f'# left out: {sum(len(v) for v in left.values())}')
    for reason in sorted(left):
        lines.append(f"{reason} ({len(left[reason])}): {', '.join(left[reason])}")
    return '\n'.join(lines) + '\n'


def write_sheet(out, category, ratings=None):
    out = Path(out)
    source = out / 'items' / f'{category}.json'
    if not source.exists():
        raise SystemExit(f'No items file for {category}. Run build first. Known: {", ".join(known_categories(out))}')
    document = json.loads(source.read_text(encoding='utf-8'))
    target = out / 'sheets' / f'{category}.txt'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(sheet_text(category, document, load_notes(out), ratings), encoding='utf-8', newline='\n')
    return target
