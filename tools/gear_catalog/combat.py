"""Derived fighting numbers: the game's armor rule, gun firing modes and melee hits. Plain functions of plain values."""
from __future__ import annotations

# Used when a dump predates these constants. All three are read from the compiled game when it has them.
ARMOR_WEAKENED_MULTIPLIER = 2
ARMOR_MAX_BLOCK = 90
CLICK_CD_MELEE = 8

# The armored target for melee numbers, as the plan states it. The real vest's melee armor is in the vest row itself.
MELEE_TARGET_ARMOR = 30

GUN_FORMULAS = {
    'damage_per_shot': 'casing.pellets * projectile.damage * gun.projectile_damage_multiplier, when projectile.damage_type is not stamina',
    'stamina_per_shot': 'casing.pellets * (projectile.stamina + projectile.damage if damage_type is stamina) * multiplier',
    'cycle_ds': 'deciseconds per trigger cycle. Automatic: max(autofire_shot_delay, fire_delay). Otherwise max(fire_delay, burst_delay * (burst_size - 1) + click cooldown), because every shot of a burst restarts the click cooldown (fire_casing); click cooldown = casing.click_cooldown_override or CLICK_CD_RANGE. Manual action guns (semi_auto false) need a rack per shot and racks are rack_delay apart, so rack_delay is also a floor. Reload time and the extra keypress are ignored',
    'shots_per_second': 'burst_size * 10 / cycle_ds',
    'dps': 'damage_per_shot * shots_per_second. Every shot hits, no armor, no falloff',
    'stamina_dps': 'stamina_per_shot * shots_per_second',
    'capacity': 'ballistic: magazine.max_ammo; energy: floor(cell maxcharge / e_cost); magic: max_charges',
    'damage_per_magazine': 'capacity * damage_per_shot',
    'target.bare': 'no armor: the same numbers as above',
    'target.vest': 'an armor vest, with armor = the vest row\'s rating for projectile.armor_flag. blocked = run_armor_check(armor, projectile.armour_penetration, projectile.weak_against_armour), capped at ARMOR_MAX_BLOCK; damage * (100 - blocked) / 100',
    'run_armor_check': 'armor <= 0: armor. weak_against_armour: armor * ARMOR_WEAKENED_MULTIPLIER. penetration: max(0, PENETRATE_ARMOUR(armor, penetration)), where PENETRATE_ARMOUR = 0 at 100 penetration, else 100 * (armor - penetration) / (100 - penetration)',
    'reload': 'magazine guns swap with one click and no timer when tac_reloads is set (item_interaction, eject_magazine); internal magazines load one click per box, or one click per round when the box has no multiload (load_gun). The code gives no reload timer for either, only rack_delay after it',
}
MELEE_FORMULAS = {
    'states': 'default is the item as created. wielded: two_handed force_multiplier * force when the multiplier is not 1, else force_wielded when it differs from force_unwielded. active: transforming force_on, with sharpness_on and throwforce_on',
    'damage_per_hit': 'force in that state, when damtype is not stamina',
    'stamina_per_hit': 'force in that state, when damtype is stamina',
    'hits_per_second': '10 / attack_speed, the click cooldown after a hit (item_attack.dm)',
    'dps': 'damage_per_hit * hits_per_second. Every hit lands, no block',
    'target.bare': 'no armor: the same numbers as above',
    'target.armored': f'{MELEE_TARGET_ARMOR} melee armor. blocked = min(ARMOR_MAX_BLOCK, run_armor_check({MELEE_TARGET_ARMOR}, armour_penetration)); damage * (100 - blocked) / 100 (attacked_by, apply_damage)',
}


def num(value):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) else None


def clean(value):
    """Round off float noise so output is stable and readable."""
    if isinstance(value, float):
        rounded = round(value, 4)
        return int(rounded) if rounded == int(rounded) else rounded
    return value


def penetrate_armour(armour, penetration):
    """PENETRATE_ARMOUR, code/__DEFINES/combat.dm."""
    return 0 if penetration == 100 else 100 * (armour - penetration) / (100 - penetration)


def blocked_percent(armor, penetration=0, weak=False, weakened_multiplier=ARMOR_WEAKENED_MULTIPLIER, max_block=ARMOR_MAX_BLOCK):
    """run_armor_check() and the cap both attack paths put on it. The percent of damage armor stops."""
    if armor <= 0:
        return armor
    if weak:
        armor *= weakened_multiplier
    if penetration:
        armor = max(penetrate_armour(armor, penetration), 0)
    return min(armor, max_block)


def through_armor(damage, blocked):
    return damage * (100 - blocked) / 100


def projectile_facts(projectile, decode_pass=None):
    keep = ['type', 'damage', 'damage_type', 'stamina', 'armor_flag', 'armour_penetration', 'weak_against_armour', 'wound_bonus',
            'exposed_wound_bonus', 'sharpness', 'range', 'maximum_range', 'speed', 'projectile_piercing', 'projectile_phasing', 'max_pierces',
            'ricochets_max', 'ricochet_chance', 'stun', 'knockdown', 'paralyze', 'immobilize', 'unconscious', 'eyeblur', 'drowsy', 'jitter',
            'stutter', 'slur', 'dismemberment', 'embed_type', 'shrapnel_type', 'damage_falloff_tile', 'stamina_falloff_tile',
            'wound_falloff_tile', 'embed_falloff_tile', 'accuracy_falloff', 'accurate_range', 'hitscan', 'reflectable', 'demolition_mod']
    facts = {k: projectile.get(k) for k in keep if k in projectile}
    if decode_pass:
        for name in ['pass_flags', 'projectile_phasing', 'projectile_piercing']:
            decoded = decode_pass(projectile.get(name))
            if decoded:
                facts[name + '_decoded'] = decoded
    return facts


def fire_mode(gun, casing, label, click_cd, capacity, fire_delay=None, burst_size=None, autofire=True, vest=None, decode_pass=None, armor_rule=None):
    projectile = (casing or {}).get('projectile') or {}
    pellets = num((casing or {}).get('pellets')) or 1
    multiplier = num(gun.get('projectile_damage_multiplier'))
    multiplier = 1 if multiplier is None else multiplier
    damage = num(projectile.get('damage')) or 0
    stamina = num(projectile.get('stamina')) or 0
    is_stamina = projectile.get('damage_type') == 'stamina'
    per_shot = 0 if is_stamina else pellets * damage * multiplier
    stamina_shot = pellets * (stamina + (damage if is_stamina else 0)) * multiplier
    delay = num(fire_delay if fire_delay is not None else gun.get('fire_delay')) or 0
    burst = num(burst_size if burst_size is not None else gun.get('burst_size')) or 1
    burst = max(1, burst)
    burst_delay = num(gun.get('burst_delay')) or 0
    auto_delay = num(gun.get('autofire_shot_delay')) if autofire else None
    if auto_delay:
        cycle = max(auto_delay, delay)
    else:
        cooldown = num((casing or {}).get('click_cooldown_override')) or click_cd
        cycle = max(delay, burst_delay * (burst - 1) + cooldown)
        if gun.get('semi_auto') == 0:
            cycle = max(cycle, num(gun.get('rack_delay')) or 0)
    rate = burst * 10 / cycle if cycle else None
    mode = dict(
        label=label,
        fire_delay_ds=delay,
        burst_size=burst,
        burst_delay_ds=burst_delay if burst > 1 else None,
        automatic=bool(auto_delay),
        casing=(casing or {}).get('type'),
        pellets=pellets,
        variance=(casing or {}).get('variance'),
        harmful=(casing or {}).get('harmful'),
        projectile=projectile_facts(projectile, decode_pass),
        cycle_ds=clean(cycle),
        shots_per_second=clean(rate),
        damage_per_shot=clean(per_shot),
        stamina_per_shot=clean(stamina_shot),
        dps=clean(per_shot * rate) if rate else None,
        stamina_dps=clean(stamina_shot * rate) if rate else None,
        capacity=capacity,
        damage_per_magazine=clean(capacity * per_shot) if capacity else None,
    )
    if 'e_cost' in (casing or {}):
        mode['energy_cost'] = casing['e_cost']
        mode['shots_per_cell'] = casing.get('shots_per_cell')
    if vest is not None:
        rule = armor_rule or {}
        armor = num(vest.get(projectile.get('armor_flag'))) or 0
        blocked = blocked_percent(armor, num(projectile.get('armour_penetration')) or 0, bool(projectile.get('weak_against_armour')), **rule)
        mode['target'] = dict(
            bare=dict(armor=0, blocked=0, damage_per_shot=mode['damage_per_shot'], dps=mode['dps'], stamina_per_shot=mode['stamina_per_shot'], stamina_dps=mode['stamina_dps']),
            vest=dict(armor=armor, blocked=clean(float(blocked)), damage_per_shot=clean(through_armor(per_shot, blocked)),
                      dps=clean(through_armor(per_shot, blocked) * rate) if rate else None,
                      stamina_per_shot=clean(through_armor(stamina_shot, blocked)),
                      stamina_dps=clean(through_armor(stamina_shot, blocked) * rate) if rate else None),
        )
    return mode


def gun_modes(gun, actions, click_cd, vest=None, decode_pass=None, armor_rule=None):
    modes = []
    kind = gun.get('kind')
    extra = dict(vest=vest, decode_pass=decode_pass, armor_rule=armor_rule)
    if kind == 'ballistic':
        magazine = gun.get('magazine') or {}
        casing = magazine.get('casing')
        capacity = num(magazine.get('max_ammo'))
        if 'autofire_shot_delay' in gun:
            modes.append(fire_mode(gun, casing, 'auto', click_cd, capacity, **extra))
        elif (num(gun.get('burst_size')) or 1) > 1:
            modes.append(fire_mode(gun, casing, 'burst', click_cd, capacity, **extra))
            if '/datum/action/item_action/toggle_firemode' in actions:
                modes.append(fire_mode(gun, casing, 'semi', click_cd, capacity, fire_delay=0, burst_size=1, **extra))
        else:
            modes.append(fire_mode(gun, casing, 'semi', click_cd, capacity, **extra))
    elif kind == 'energy':
        for casing in gun.get('modes', []):
            capacity = casing.get('shots_per_cell')
            modes.append(fire_mode(gun, casing, casing.get('select_name') or casing.get('type'), click_cd, capacity,
                                   fire_delay=num(casing.get('delay')) or 0, **extra))
    elif kind == 'magic':
        casing = gun.get('chambered')
        modes.append(fire_mode(gun, casing, 'magic', click_cd, num(gun.get('max_charges')), **extra))
    else:
        casing = gun.get('chambered')
        if casing:
            modes.append(fire_mode(gun, casing, 'other', click_cd, None, **extra))
    return modes


def reload_facts(gun, default_rack_ds=None):
    """What the code gives for reloading. No gun in this tree has a timed reload, so the row says so instead of a number."""
    if gun.get('kind') != 'ballistic':
        return None
    magazine = gun.get('magazine') or {}
    rack = num(gun.get('rack_delay'))
    rack_is_default = rack == default_rack_ds if default_rack_ds is not None else None
    if gun.get('internal_magazine'):
        multiload = bool(magazine.get('multiload'))
        return dict(kind='internal', seconds=None, timed_by_code=False, rack_s=clean(rack / 10) if rack is not None else None, rack_is_default=rack_is_default,
                    clicks=1 if multiload else num(magazine.get('max_ammo')), by_the_round=not multiload,
                    note='no reload timer in the code')
    return dict(kind='magazine', seconds=None, timed_by_code=False, rack_s=clean(rack / 10) if rack is not None else None, rack_is_default=rack_is_default,
                tactical=bool(gun.get('tac_reloads')), clicks=1 if gun.get('tac_reloads') else 2, note='no reload timer in the code')


def melee_state(label, force, attack_speed, armour_penetration, damtype, armor_rule=None, sharpness=None, throwforce=None):
    """One way of holding a weapon, against no armor and against MELEE_TARGET_ARMOR."""
    force = num(force) or 0
    is_stamina = damtype == 'stamina'
    damage = 0 if is_stamina else force
    stamina = force if is_stamina else 0
    rate = 10 / attack_speed if attack_speed else None
    blocked = blocked_percent(MELEE_TARGET_ARMOR, num(armour_penetration) or 0, **(armor_rule or {}))
    state = dict(
        state=label,
        force=clean(force),
        damage_per_hit=clean(damage),
        stamina_per_hit=clean(stamina),
        hits_per_second=clean(rate),
        dps=clean(damage * rate) if rate else None,
        target=dict(
            bare=dict(armor=0, blocked=0, damage_per_hit=clean(damage), dps=clean(damage * rate) if rate else None),
            armored=dict(armor=MELEE_TARGET_ARMOR, blocked=clean(float(blocked)), damage_per_hit=clean(through_armor(damage, blocked)),
                         dps=clean(through_armor(damage, blocked) * rate) if rate else None),
        ),
    )
    if sharpness is not None:
        state['sharpness'] = sharpness
    if throwforce is not None:
        state['throwforce'] = throwforce
    return state
