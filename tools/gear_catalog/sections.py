"""The stats each category's rows carry, built from one dump row. No file access: everything comes in through `raw` and `ctx`."""
from __future__ import annotations

import json

from .categories import MELEE_FORCE_MIN, WORN_CATEGORIES
from .combat import GUN_FORMULAS, MELEE_FORMULAS, clean, gun_modes, melee_state, num, reload_facts

# check_armor (human_defense.dm) asks whether a worn item covers the hit bodypart's body_part, and a bodypart is one of these. Groin, hands, feet and neck never match.
ARMOR_ZONES = {'HEAD', 'CHEST', 'ARM_LEFT', 'ARM_RIGHT', 'LEG_LEFT', 'LEG_RIGHT'}
WORN_FORMULAS = {
    'coverage': 'how many of the six zones armor can apply to body_parts_covered names: head, chest, each arm and each leg, out of 6. Groin, hands, feet and neck add no armor',
    'parts_covered': 'every body part body_parts_covered names, counting each arm, hand, leg and foot on its own, out of 12',
    'armor_sum': 'melee + bullet + laser + energy: the plain sum of the four ratings a fight tests',
    'armor_sum_all': 'every rating added together, including bomb, bio, fire, acid, wound and consume',
}
MECH_FORMULAS = {
    'damage_per_volley': 'projectiles_per_shot * projectile damage',
    'volleys_per_second': '10 / max(equip_cooldown, click cooldown): the weapon fires once per cooldown',
    'dps': 'damage_per_volley * volleys_per_second. Every shot hits, no armor',
}
AMMO_FORMULAS = {
    'damage_per_round': 'casing.pellets * projectile damage',
    'price_per_round': 'cheapest shop credits / rounds in the box (1 for a loose casing)',
    'accepted_by': 'guns whose accepted_magazine_type covers this magazine. A loose round or a box of them counts for every gun of the same caliber',
}
FORMULAS = {'guns': GUN_FORMULAS, 'melee': MELEE_FORMULAS, 'shields': MELEE_FORMULAS, 'mech': MECH_FORMULAS, 'ammo': AMMO_FORMULAS}
FORMULAS.update({category: WORN_FORMULAS for category in WORN_CATEGORIES})

COMBAT_ARMOR = ['melee', 'bullet', 'laser', 'energy']


def decode_flags(value, table):
    """Names of the bits set in value, sorted. An empty table or a non-number decodes to nothing."""
    if not isinstance(value, (int, float)) or not table:
        return []
    return sorted(name for name, bit in table.items() if isinstance(bit, (int, float)) and int(value) & int(bit))


class ItemView:
    """One dump row, reading a var the way the game would: its own value if the dump kept it, else the plain item's."""

    def __init__(self, raw, meta):
        self.raw = raw
        self.meta = meta
        self.vars = raw.get('vars') or {}
        self.refs = raw.get('refs') or {}
        self.base = meta.get('item_base') or {}

    def get(self, name, default=None):
        if name in self.vars:
            return self.vars[name]
        if name in self.refs:
            return self.refs[name]
        text = self.base.get(name)
        if text is not None:
            value = json.loads(text)[0]
            return default if value is None else value
        return default

    def number(self, name, default=0):
        value = num(self.get(name))
        return default if value is None else value

    def bits(self, name):
        return decode_flags(self.get(name), (self.meta.get('bitfields') or {}).get(name))

    def table_bits(self, name, table):
        return decode_flags(self.get(name), self.meta.get(table))

    def component(self, part):
        for component in self.raw.get('components') or []:
            if component['type'] == part:
                return component.get('vars') or {}
        return None

    @property
    def slots(self):
        return self.table_bits('slot_flags', 'slot_flags')


def armor_block(view):
    armor = {k: v for k, v in (view.raw.get('armor') or {}).items() if k != 'type'}
    return dict(
        armor=armor or None,
        armor_type=(view.raw.get('armor') or {}).get('type'),
        armor_sum=sum(num(armor.get(k)) or 0 for k in COMBAT_ARMOR),
        armor_sum_all=sum(num(v) or 0 for v in armor.values()),
    )


def generic_stats(view, ctx):
    """What every row gets. A category's own section adds to this."""
    weight = view.get('w_class')
    stats = dict(
        w_class=weight, weight_class=(view.meta.get('weight_class') or {}).get(str(weight)), slot_flags=view.slots,
        force=view.get('force'), throwforce=view.get('throwforce'), damtype=view.get('damtype'), sharpness=view.bits('sharpness'),
        slowdown=view.get('slowdown'), toolspeed=view.get('toolspeed'), tool_behaviour=view.get('tool_behaviour'),
        storage=view.raw.get('storage'), reagents=view.raw.get('reagents'), inner_reagents=view.raw.get('inner_reagents'), cell=view.raw.get('cell'),
        transfer_amount=view.get('amount_per_transfer_from_this'), transfer_amounts=view.get('possible_transfer_amounts'),
        actions=view.raw.get('actions') or [], action_types=view.raw.get('action_types') or [],
        contents=view.raw.get('contents'), spawned=view.raw.get('spawned'),
        components=[c['type'] for c in view.raw.get('components') or []],
        elements=[e['type'] for e in view.raw.get('elements') or []],
    )
    if view.raw.get('armor'):
        stats.update(armor_block(view))
    return {k: v for k, v in stats.items() if v not in (None, [], {})}


def melee_applies(view, category):
    if category in ('melee', 'shields'):
        return True
    if (view.number('force') or 0) >= MELEE_FORCE_MIN:
        return True
    two_handed = view.component('/datum/component/two_handed') or {}
    transforming = view.component('/datum/component/transforming') or {}
    return max(num(two_handed.get('force_wielded')) or 0, num(transforming.get('force_on')) or 0) >= MELEE_FORCE_MIN


def melee_stats(view, ctx):
    rule = ctx.armor_rule
    speed = view.number('attack_speed', ctx.click_cd_melee)
    ap = view.number('armour_penetration')
    damtype = view.get('damtype', 'brute')
    force = view.number('force')
    states = [melee_state('default', force, speed, ap, damtype, rule)]
    two_handed = view.component('/datum/component/two_handed')
    transforming = view.component('/datum/component/transforming')

    def wielded_force(start):
        multiplier = num(two_handed.get('force_multiplier')) or 1
        if multiplier != 1:
            return start * multiplier
        wielded, unwielded = num(two_handed.get('force_wielded')) or 0, num(two_handed.get('force_unwielded')) or 0
        return wielded if wielded != unwielded else start

    if two_handed is not None:
        unwielded = num(two_handed.get('force_unwielded')) or 0
        multiplier = num(two_handed.get('force_multiplier')) or 1
        wielded = num(two_handed.get('force_wielded')) or 0
        if multiplier == 1 and wielded != unwielded:
            states[0] = melee_state('unwielded', unwielded, speed, ap, damtype, rule)
        else:
            states[0]['state'] = 'unwielded'
        states.append(melee_state('wielded', wielded_force(force), speed, ap, damtype, rule))
    if transforming is not None:
        on_force = num(transforming.get('force_on')) or force
        sharp = decode_flags(transforming.get('sharpness_on'), (view.meta.get('bitfields') or {}).get('sharpness')) or None
        states.append(melee_state('active', on_force, speed, ap, damtype, rule, sharpness=sharp, throwforce=transforming.get('throwforce_on')))
        if two_handed is not None:
            states.append(melee_state('active wielded', wielded_force(on_force), speed, ap, damtype, rule, sharpness=sharp))
    stats = dict(
        throwforce=view.get('throwforce'), armour_penetration=ap, sharpness=view.bits('sharpness'), wound_bonus=view.get('wound_bonus'),
        exposed_wound_bonus=view.get('exposed_wound_bonus'), attack_speed=speed, secondary_attack_speed=view.get('secondary_attack_speed'),
        block_chance=view.get('block_chance'), demolition_mod=view.get('demolition_mod'), w_class=view.get('w_class'), slot_flags=view.slots,
        reach=view.get('reach'), damtype=damtype, embed=view.raw.get('embed'), states=states,
        two_handed=bool(two_handed is not None), require_twohands=bool((two_handed or {}).get('require_twohands')),
        transforming=bool(transforming is not None),
    )
    if 'stamina_damage' in view.vars or 'stun_armour_penetration' in view.vars:
        stats['baton'] = dict(
            stamina_damage=view.get('stamina_damage'), cooldown_ds=view.get('cooldown'), knockdown_ds=view.get('knockdown_time'),
            stun_armour_penetration=view.get('stun_armour_penetration'), armour_type_against_stun=view.get('armour_type_against_stun'),
            seconds_between_stuns=clean(view.number('cooldown') / 10),
            cell_hit_cost=view.get('cell_hit_cost'),
        )
    return stats


def worn_stats(view, ctx):
    clothing = view.raw.get('clothing') or {}
    meta = view.meta
    fields = meta.get('bitfields') or {}
    covered = decode_flags(clothing.get('body_parts_covered', view.get('body_parts_covered')), meta.get('body_parts'))
    allowed = view.get('allowed') or []
    armor = armor_block(view)
    storage = view.raw.get('storage') or {}
    return dict(
        armor=armor['armor'], armor_type=armor['armor_type'], armor_sum=armor['armor_sum'], armor_sum_all=armor['armor_sum_all'],
        body_parts_covered=covered, coverage=len(ARMOR_ZONES.intersection(covered)), parts_covered=len(covered),
        cold_protection=decode_flags(clothing.get('cold_protection'), meta.get('body_parts')),
        heat_protection=decode_flags(clothing.get('heat_protection'), meta.get('body_parts')),
        min_cold_protection_temperature=clothing.get('min_cold_protection_temperature'),
        max_heat_protection_temperature=clothing.get('max_heat_protection_temperature'),
        clothing_flags=decode_flags(clothing.get('clothing_flags'), fields.get('clothing_flags')),
        slowdown=clothing.get('slowdown', view.get('slowdown')),
        flags_inv=view.bits('flags_inv'), flags_cover=view.table_bits('flags_cover', 'flags_cover'), slot_flags=view.slots,
        equip_delay_self=view.get('equip_delay_self'), max_integrity=view.get('max_integrity'), limb_integrity=clothing.get('limb_integrity'),
        resistance_flags=view.bits('resistance_flags'), siemens_coefficient=view.get('siemens_coefficient'),
        allowed_count=len(allowed) if isinstance(allowed, list) else None, allowed=allowed[:6] if isinstance(allowed, list) else allowed,
        clothing_traits=clothing.get('clothing_traits') or [],
        flash_protect=clothing.get('flash_protect'), tint=clothing.get('tint'),
        # bang_protect is an ear organ var; worn gear guards ears through this component instead.
        ear_protection=bool(view.component('/datum/component/wearertargeting/earprotection')),
        storage_slots=storage.get('max_slots'), storage=storage or None,
    )


def eyewear_stats(view, ctx):
    clothing = view.raw.get('clothing') or {}
    sight = view.meta.get('sight_flags') or {}
    vision = num(clothing.get('vision_flags')) or 0
    traits = clothing.get('clothing_traits') or []
    return dict(
        vision_flags=vision, sight=sorted(name for name, bit in sight.items() if vision & bit),
        invis_view=clothing.get('invis_view'), invis_override=clothing.get('invis_override'),
        see_invisible_living=view.meta.get('see_invisible_living'),
        lighting_cutoff=clothing.get('lighting_cutoff'), color_cutoffs=clothing.get('color_cutoffs'),
        hud_traits=sorted(t for t in traits if isinstance(t, str) and 'hud' in t.lower()), glass_colour=clothing.get('glass_colour_type'),
    )


def gun_stats(row, view, ctx):
    gun = view.raw.get('gun')
    if not gun:
        return {}
    rows, meta = ctx.rows, view.meta
    actions = view.raw.get('actions') or []
    spare = []
    for magazine_type in gun.get('spare_magazines') or []:
        facts = (rows.get(magazine_type, {}).get('facts') or {}).get('ammo_box') or {}
        spare.append(dict(type=magazine_type, capacity=facts.get('max_ammo'), caliber=facts.get('caliber'), ammo_type=facts.get('ammo_type'),
                          firm_sources=rows.get(magazine_type, {}).get('firm_sources')))
    gun = dict(gun, spare_magazines=spare)
    caliber = (gun.get('magazine') or {}).get('caliber')
    loose = None
    if gun.get('internal_magazine') and caliber:
        loose = ctx.loose_boxes.get(caliber, [])
    modes = gun_modes(gun, actions, ctx.click_cd, vest=ctx.vest, decode_pass=ctx.decode_pass, armor_rule=ctx.armor_rule)
    magazine = gun.get('magazine') or {}
    stats = dict(
        kind=gun.get('kind'), w_class=gun.get('w_class'), weight_class=(meta.get('weight_class') or {}).get(str(gun.get('w_class'))),
        weapon_weight=gun.get('weapon_weight'), weapon_weight_name=next((k for k, v in (meta.get('weapon_weight') or {}).items() if v == gun.get('weapon_weight')), None),
        two_handed=gun.get('two_handed'), fire_delay_ds=gun.get('fire_delay'), burst_size=gun.get('burst_size'), burst_delay_ds=gun.get('burst_delay'),
        autofire_shot_delay_ds=gun.get('autofire_shot_delay'), autofire_windup=gun.get('autofire_windup'), spread=gun.get('spread'), recoil=gun.get('recoil'),
        dual_wield_spread=gun.get('dual_wield_spread'), suppressible=gun.get('can_suppress'), suppressed=gun.get('suppressed'), pin=gun.get('pin'),
        melee_force=gun.get('force'), damage_multiplier=gun.get('projectile_damage_multiplier'), wound_bonus_added=gun.get('projectile_wound_bonus'),
        speed_multiplier=gun.get('projectile_speed_multiplier'), slot_flags=view.slots,
        magazine=dict(type=magazine.get('type'), caliber=magazine.get('caliber'), capacity=magazine.get('max_ammo'), ammo_type=magazine.get('ammo_type')) if magazine else None,
        internal_magazine=gun.get('internal_magazine'), accepted_magazine=gun.get('accepted_magazine_type'), spare_magazines=gun.get('spare_magazines'),
        loose_ammo=loose,
        bolt_type=gun.get('bolt_type'), semi_auto=gun.get('semi_auto'), rack_delay_ds=gun.get('rack_delay'), can_be_sawn_off=gun.get('can_be_sawn_off'),
        can_misfire=gun.get('can_misfire'), misfire_probability=gun.get('misfire_probability'),
        reload=reload_facts(gun, ctx.default_rack_ds),
        cell=dict(type=gun.get('cell_type'), maxcharge=gun.get('cell_maxcharge'), self_recharge=gun.get('selfcharge'), self_charge_amount=gun.get('self_charge_amount'),
                  charge_delay=gun.get('charge_delay'), rechargeable=gun.get('can_charge')) if gun.get('kind') == 'energy' else None,
        charges=dict(max=gun.get('max_charges'), recharge_rate=gun.get('recharge_rate')) if gun.get('kind') == 'magic' else None,
        modes=modes, actions=actions, comes_with=view.raw.get('spawned'),
        components=[c['type'] for c in view.raw.get('components') or []],
        elements=[e['type'] for e in view.raw.get('elements') or []],
    )
    return stats


def shield_stats(view, ctx):
    armor = armor_block(view)
    return dict(
        block_chance=view.get('block_chance'), transparent=view.get('transparent'), breakable_by_damage=view.get('breakable_by_damage'),
        is_bashable=view.get('is_bashable'), shield_break_leftover=view.get('shield_break_leftover'), max_integrity=view.get('max_integrity'),
        slowdown=view.get('slowdown'), armor=armor['armor'], resistance_flags=view.bits('resistance_flags'),
    )


def mod_control_stats(view, ctx):
    theme = dict(view.raw.get('mod_theme') or {})
    fields = view.meta.get('bitfields') or {}
    if theme:
        theme['resistance_flags'] = decode_flags(theme.get('resistance_flags'), fields.get('resistance_flags'))
        theme['atom_flags'] = decode_flags(theme.get('atom_flags'), fields.get('flags_1'))
        theme['slot_flags'] = decode_flags(theme.get('slot_flags'), view.meta.get('slot_flags'))
        theme['armor_sum'] = sum(num((theme.get('armor') or {}).get(k)) or 0 for k in COMBAT_ARMOR)
    modules = view.get('applied_modules') or []
    used = sum(ctx.number_var(module, 'complexity') for module in modules)
    cell = view.get('applied_cell')
    return dict(
        theme=theme or None, applied_modules=modules, applied_core=view.get('applied_core'), applied_cell=cell,
        applied_cell_charge=ctx.number_var(cell, 'maxcharge') if isinstance(cell, str) else None, req_access=view.get('req_access'),
        complexity_used=used, complexity_max=view.get('complexity_max'), charge_drain=view.get('charge_drain'), slowdown_deployed=view.get('slowdown_deployed'),
        core=view.get('core'),
    )


def mod_module_stats(view, ctx):
    slots = view.get('required_slots') or []
    return dict(
        complexity=view.number('complexity'), idle_power_cost=view.number('idle_power_cost'), active_power_cost=view.number('active_power_cost'),
        use_energy_cost=view.number('use_energy_cost'), cooldown_time=view.number('cooldown_time'),
        module_type=(view.meta.get('mod_module_type') or {}).get(str(view.number('module_type'))), incompatible_modules=view.get('incompatible_modules') or [],
        required_slots=[decode_flags(slot, view.meta.get('slot_flags')) for slot in slots] if isinstance(slots, list) else slots,
        allow_flags=view.table_bits('allow_flags', 'mod_allow_flags'), device=view.get('device'), removable=view.get('removable'),
    )


def modsuit_stats(path, view, ctx):
    if path == '/obj/item/mod/control' or path.startswith('/obj/item/mod/control/'):
        return mod_control_stats(view, ctx)
    if path == '/obj/item/mod/module' or path.startswith('/obj/item/mod/module/'):
        return mod_module_stats(view, ctx)
    return {}


def implant_stats(path, view, ctx):
    if path.startswith(('/obj/item/implantcase', '/obj/item/implanter')):
        held = view.get('imp_type') or view.get('imp')
        return dict(holds=held, holds_name=ctx.name_of(held), holds_uses=ctx.number_var(held, 'uses', None) if held else None,
                    holds_actions=ctx.actions_of(held) if held else None)
    if path.startswith('/obj/item/autosurgeon'):
        organ = view.get('starting_organ')
        return dict(uses=view.get('uses'), starting_organ=organ, starting_organ_name=ctx.name_of(organ), organ_whitelist=view.get('organ_whitelist'),
                    surgery_speed=view.get('surgery_speed'))
    if path.startswith('/obj/item/skillchip'):
        return dict(auto_traits=view.get('auto_traits'), complexity=view.get('complexity'), slot_use=view.get('slot_use'), chip_category=view.get('chip_category'),
                    cooldown=view.get('cooldown'), skillchip_flags=view.get('skillchip_flags'))
    if path.startswith('/obj/item/implant/') or path == '/obj/item/implant':
        actions = view.raw.get('actions') or []
        return dict(uses=view.get('uses', -1), activated=bool(actions or view.raw.get('action_types')), actions=actions, implant_flags=view.get('implant_flags'),
                    allow_multiple=view.get('allow_multiple'), emp_act_from=ctx.proc_owner(path, 'emp_act'), fitting='implanter or implant case, no surgery')
    return {}


def organ_stats(path, view, ctx):
    zone = view.get('zone')
    surgeries = ctx.surgeries.get(zone) or []
    created = []
    for made in view.get('items_to_create') or []:
        created.append(ctx.fitted_item(made))
    return dict(
        zone=zone, slot=view.get('slot'), organ_flags=view.bits('organ_flags'), max_health=view.get('maxHealth'), decay_factor=view.get('decay_factor'),
        items_to_create=created or None, action_types=view.raw.get('action_types') or [], actions=view.raw.get('actions') or [],
        emp_act_from=ctx.proc_owner(path, 'emp_act'), chrome_load=view.get('chrome_load'), tier=view.get('tier'), chrome_capacity_bonus=view.get('chrome_capacity_bonus'),
        fitting=dict(by_surgery=bool(surgeries), surgeries=surgeries),
    )


def explosive_stats(view, ctx):
    held = {}
    holders = list(view.raw.get('inner_reagents') or [])
    if (view.raw.get('reagents') or {}).get('held'):
        holders.append(view.raw['reagents'])
    for holder in holders:
        for reagent, volume in (holder.get('held') or {}).items():
            held[reagent] = clean(held.get(reagent, 0) + volume)
    return dict(
        det_time=view.get('det_time'), ex_dev=view.number('ex_dev'), ex_heavy=view.number('ex_heavy'), ex_light=view.number('ex_light'), ex_flame=view.number('ex_flame'),
        shrapnel_type=view.get('shrapnel_type'), shrapnel_radius=view.get('shrapnel_radius'), sticky=view.get('sticky'), type_cluster=view.get('type_cluster'),
        range_heavy=view.get('range_heavy'), range_medium=view.get('range_medium'), range_light=view.get('range_light'), range_flame=view.get('range_flame'),
        reagents_inside=held or None,
    )


def ammo_stats(row, view, ctx):
    box = view.raw.get('ammo_box')
    casing = (box or {}).get('casing') or view.raw.get('casing') or {}
    projectile = casing.get('projectile') or {}
    pellets = num(casing.get('pellets')) or 1
    rounds = num((box or {}).get('max_ammo')) or 1
    guns = ctx.guns_for_ammo(row['path'], box, casing)
    credits = [s['credits'] for s in row['sources'].get('shops') or [] if isinstance(s.get('credits'), (int, float)) and s['credits'] > 0]
    passes = sorted({flag for name in ('pass_flags', 'projectile_phasing') for flag in (ctx.decode_pass(projectile.get(name)) if ctx.decode_pass else [])})
    return dict(
        caliber=(box or {}).get('caliber') or casing.get('caliber'), capacity=(box or {}).get('max_ammo'), round_type=(box or {}).get('ammo_type') or casing.get('type'),
        start_empty=(box or {}).get('start_empty'), multiload=(box or {}).get('multiload'), pellets=pellets, projectile=projectile.get('type'),
        damage=projectile.get('damage'), damage_type=projectile.get('damage_type'), stamina=projectile.get('stamina'), armor_flag=projectile.get('armor_flag'),
        armour_penetration=projectile.get('armour_penetration'), weak_against_armour=projectile.get('weak_against_armour'), wound_bonus=projectile.get('wound_bonus'),
        stun=projectile.get('stun'), knockdown=projectile.get('knockdown'), paralyze=projectile.get('paralyze'), immobilize=projectile.get('immobilize'), unconscious=projectile.get('unconscious'),
        passes=passes, through_walls='PASSCLOSEDTURF' in passes,
        damage_per_round=clean(pellets * (num(projectile.get('damage')) or 0)), accepted_by_count=len(guns), accepted_by=guns[:12],
        price_per_round=clean(min(credits) / rounds) if credits else None,
    )


def mech_stats(view, ctx):
    projectile = view.raw.get('mech_projectile') or {}
    cooldown = view.number('equip_cooldown')
    per_shot = view.number('projectiles_per_shot', 1) or 1
    damage = num(projectile.get('damage')) or 0
    rate = 10 / max(cooldown, ctx.click_cd) if projectile else None
    stats = dict(
        energy_drain=view.number('energy_drain'), equip_cooldown=cooldown, range=view.get('range'), harmful=view.get('harmful'), equipment_slot=view.get('equipment_slot'),
        mech_flags=view.get('mech_flags'), projectiles=view.get('projectiles'), projectiles_cache=view.get('projectiles_cache'), projectiles_cache_max=view.get('projectiles_cache_max'),
        ammo_type=view.get('ammo_type'), projectiles_per_shot=per_shot, variance=view.get('variance'), projectile_delay=view.get('projectile_delay'),
        rounds=view.get('rounds'), actions=view.raw.get('actions') or [],
    )
    if projectile:
        stats.update(projectile=projectile.get('type'), damage=projectile.get('damage'), damage_type=projectile.get('damage_type'), armor_flag=projectile.get('armor_flag'),
                     armour_penetration=projectile.get('armour_penetration'), damage_per_volley=clean(per_shot * damage), volleys_per_second=clean(rate),
                     dps=clean(per_shot * damage * rate) if rate else None)
    return stats


def category_stats(row, raw, ctx):
    """generic stats, then the category's own. A later section wins over an earlier one for the same field."""
    category, path = row['category'], row['path']
    view = ItemView(raw, ctx.meta)
    stats = generic_stats(view, ctx)
    if category == 'guns':
        stats.update(gun_stats(row, view, ctx))
    elif category == 'eyewear':
        stats.update(worn_stats(view, ctx))
        stats.update(eyewear_stats(view, ctx))
    elif category in WORN_CATEGORIES:
        stats.update(worn_stats(view, ctx))
    elif category == 'melee':
        stats.update(melee_stats(view, ctx))
    elif category == 'shields':
        stats.update(shield_stats(view, ctx))
        stats['melee'] = melee_stats(view, ctx)
    elif category == 'modsuits':
        stats.update(modsuit_stats(path, view, ctx))
    elif category == 'implants':
        stats.update(implant_stats(path, view, ctx))
    elif category in ('cyberware', 'organs'):
        stats.update(organ_stats(path, view, ctx))
    elif category == 'explosives':
        stats.update(explosive_stats(view, ctx))
    elif category == 'ammo':
        stats.update(ammo_stats(row, view, ctx))
    elif category == 'mech':
        stats.update(mech_stats(view, ctx))
    if category not in ('melee', 'shields', 'guns') and melee_applies(view, category):
        stats['melee'] = melee_stats(view, ctx)
    return stats
