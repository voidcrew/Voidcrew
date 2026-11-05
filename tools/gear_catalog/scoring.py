"""A gun's power score: one number to compare peers with, from the catalog's row and whatever its rating adds.

    score = D x L x H x E + 0.2 x (the same sum for a different load, if it has one) + points

Scored against a man in a plain armor vest (30 armor) at 5 tiles. The same sum with no armor is the bare number; the tier lines stay on the vest number.
    D = (damage through armor + 0.6 x stamina through armor) x shots per second x hit chance
        Armor is the game's PENETRATE_ARMOUR, doubled for weak_against_armour. Shots per second is the catalog's, x0.8 for semi-auto (clicking at the
        limit), x0.6 for manual action (the rack keypress). Hit chance is min(1, 11.4 / spread), x0.75 for pellets.
    L = damage through armor in one load / 200, floor 0.5, cap 1, and 1.25 at 800 or more
    H = 0.85 for WEAPON_HEAVY, else 1
    E = 1.25 for an energy gun, because it never costs ammo

Not modeled: akimbo, reload time, ammo price, recoil, projectile speed, wounds, range past 5 tiles, non-human armor.

A rating's score_inputs say what the catalog's row can't. Each is optional, and each but extra_mode has a value and a why:
    rate            true shots per second, where the catalog ignores a reload, draw or recharge. Or {"listed": true, "why": ...}: its rate is already true, no discount
    damage          damage per shot in place of the catalog's
    armorless_damage    damage per shot on top, that armor doesn't touch
    armorless_stamina   stamina per shot in place of the catalog's, that armor doesn't touch, with its own "rate"
    hit             hit chance in place of the spread rule
    cell_fed        false for an energy gun that refills by itself or by hand, so E doesn't apply
    extra_mode      a second load worth scoring: {"label", "why"} and either {"damage", "pellets", "armour_penetration", "weak"} or {"armorless_stamina", "rate"}
    points          points added for what no stat shows, can be negative
    judged          no stat can speak: this is the score, and there is no bare number
"""
from __future__ import annotations

VEST_ARMOR = 30
HIT_SPREAD = 11.4
STAMINA_WEIGHT = 0.6
GREEN_BELOW = 40
RED_FROM = 110
SCORE_INPUTS = ('rate', 'damage', 'armorless_damage', 'armorless_stamina', 'hit', 'cell_fed', 'extra_mode', 'points', 'judged')


def penetrate(armor, penetration):
    return 0.0 if penetration == 100 else max(0.0, 100.0 * (armor - penetration) / (100.0 - penetration))


def through_armor(amount, armor, penetration, weak):
    armor *= 2 if weak else 1
    blocked = penetrate(armor, penetration) if penetration else armor
    return amount * (1 - min(100.0, blocked) / 100.0)


def spread_hit(spread, pellets):
    return (1.0 if not spread else min(1.0, HIT_SPREAD / spread)) * (0.75 if (pellets or 1) > 1 else 1.0)


def firing_rate(entry, mode, inputs):
    rate = inputs.get('rate') or {}
    if 'value' in rate:
        return rate['value']
    listed = mode.get('shots_per_second') or 0
    if rate.get('listed') or mode.get('automatic') or (mode.get('burst_size') or 1) > 1:
        return listed
    return listed * (0.6 if entry.get('semi_auto') == 0 else 0.8)


def mode_sum(entry, mode, inputs, armor):
    """One way of firing, as a sum and the load it used, against this much armor."""
    projectile = mode.get('projectile') or {}
    penetration = projectile.get('armour_penetration') or 0
    weak = projectile.get('weak_against_armour') or 0
    damage = (inputs['damage']['value'] if 'damage' in inputs else mode.get('damage_per_shot')) or 0
    damage = through_armor(damage, armor, penetration, weak) + (inputs.get('armorless_damage') or {}).get('value', 0)
    stamina = through_armor(mode.get('stamina_per_shot') or 0, armor, penetration, weak)
    rate = firing_rate(entry, mode, inputs)
    if 'armorless_stamina' in inputs:
        stamina = inputs['armorless_stamina']['value']
        rate = inputs['armorless_stamina'].get('rate', rate)
    per_shot = damage + STAMINA_WEIGHT * stamina
    hit = inputs['hit']['value'] if 'hit' in inputs else spread_hit(entry.get('spread') or 0, mode.get('pellets'))
    capacity = mode.get('capacity')
    load = 1.0
    if capacity is not None:
        total = capacity * per_shot
        load = 1.25 if total >= 800 else max(0.5, min(1.0, total / 200.0))
    heavy = 0.85 if entry.get('weapon_weight_name') == 'WEAPON_HEAVY' else 1.0
    cell_fed = entry.get('kind') == 'energy' and (inputs.get('cell_fed') or {}).get('value', True)
    return dict(label=mode.get('label'), casing=mode.get('casing'), sum=per_shot * rate * hit * load * heavy * (1.25 if cell_fed else 1.0))


def extra_mode_sum(entry, spec, inputs, armor):
    if 'armorless_stamina' in spec:
        return dict(label=spec['label'], casing=spec['label'], sum=STAMINA_WEIGHT * spec['armorless_stamina'] * spec['rate'] * 1.25)
    first = (entry.get('modes') or [{}])[0]
    mode = dict(label=spec['label'], casing=spec['label'], damage_per_shot=spec['damage'], stamina_per_shot=0, pellets=spec.get('pellets', 1), capacity=first.get('capacity'),
                shots_per_second=first.get('shots_per_second'), automatic=first.get('automatic'), burst_size=first.get('burst_size'),
                projectile=dict(armour_penetration=spec.get('armour_penetration', 0), weak_against_armour=spec.get('weak', 0)))
    return mode_sum(entry, mode, inputs, armor)


def total_against(entry, inputs, armor):
    """The best way of firing, plus a fifth of the next one that uses a different load, plus any points. None for a gun that doesn't fire."""
    modes = [mode_sum(entry, mode, inputs, armor) for mode in entry.get('modes') or []]
    if inputs.get('extra_mode'):
        modes.append(extra_mode_sum(entry, inputs['extra_mode'], inputs, armor))
    if not modes:
        return None
    modes.sort(key=lambda mode: -mode['sum'])
    best = modes[0]
    # A fire selector is the same round; only a different load earns the second-mode credit.
    other = [mode for mode in modes[1:] if mode['casing'] != best['casing']]
    return best['sum'] + 0.2 * (other[0]['sum'] if other else 0) + (inputs.get('points') or {}).get('value', 0)


def score_gun(entry, inputs=None):
    """{'score': vest number, 'bare': no armor, 'basis': formula, formula+hand or judged}, or None when a gun has nothing to score."""
    inputs = inputs or {}
    if 'judged' in inputs:
        return dict(score=inputs['judged']['value'], bare=None, basis='judged')
    vest = total_against(entry, inputs, VEST_ARMOR)
    if vest is None:
        return None
    return dict(score=vest, bare=total_against(entry, inputs, 0), basis='formula+hand' if inputs.get('points') else 'formula')


def tier_line(score):
    """The tier the vest number alone would give."""
    if score < GREEN_BELOW:
        return 'green'
    return 'yellow' if score < RED_FROM else 'red'
