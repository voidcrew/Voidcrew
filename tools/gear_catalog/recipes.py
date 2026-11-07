"""Which recipes a crew can make, given what it can already get. The catalog build and the PR check both ask this.

A recipe counts only when a crew knows it and can get every ingredient, tool and machine it asks for, and a crafted item can be the
ingredient of another recipe, so the answer grows from the items with a route of their own until nothing changes. Steps are numbers,
lower is easier. The catalog passes 0 for anything it can route at all, so a step there only means "reachable".
"""
from __future__ import annotations

import collections


def item_needs(entry):
    """The items a recipe uses up or has to have to hand, or the stack it's built from. Reagents and the like come with whatever holds them."""
    needs = {*(entry.get('ingredients') or {}), *(entry.get('tool_paths') or []), *(entry.get('input_stacks') or [])}
    return sorted(need for need in needs if need.startswith('/obj/item'))


def use_recipe(use):
    """Using one item to get another reads as a recipe with one ingredient. Other parts the step asks for aren't in the row."""
    return dict(recipe=use['from_item'], ingredients={use['from_item']: 1}, source=use.get('source'))


def fixture_needs(entry):
    """The machines and structures a recipe has to be made beside."""
    return sorted({*(entry.get('machinery') or []), *(entry.get('structures') or [])})


def is_ordinary(path, ordinary):
    """Whether a path is on the policy's ordinary_ingredients list: the named type or anything below it."""
    return any(path == base or path.startswith(base + '/') for base in ordinary)


def is_basic_material(path):
    return path.startswith('/obj/item/stack')


def covering_types(paths, needed, parent):
    """For each needed type, every path that counts as it: a recipe takes a subtype of what it names."""
    covers = collections.defaultdict(list)
    for path in paths:
        walker, seen = path, set()
        while walker and walker not in seen:
            seen.add(walker)
            if walker in needed:
                covers[walker].append(path)
            walker = parent(walker)
    return covers


def recipe_step(entry, steps, covers):
    """The lowest step that makes this recipe: the highest, across its ingredients, of that ingredient's lowest step. None if it can't be made.

    A stack recipe's sheets are its only input: it needs a way to any stack that has it, and no step. A basic material with any route counts as no step
    at all. A recipe that must be learned also needs a way to the thing that teaches it. A machine counts like an ingredient. The game empties a storage
    item as it makes it, so a recipe for a filled one doesn't make that item.
    """
    if entry.get('made_empty'):
        return None
    if 'recipe' not in entry:
        stacks = entry.get('input_stacks')
        if stacks and not any(path in steps for need in stacks for path in covers.get(need, ())):
            return None
        return 0
    if entry.get('non_craftable'):
        return None
    step = 0
    if not entry.get('always_available', True):
        taught = [steps[teacher] for teacher in entry.get('learned_from') or [] if teacher in steps]
        if not taught:
            return None
        step = min(taught)
    for need in item_needs(entry) + fixture_needs(entry):
        found = [steps[path] for path in covers.get(need, ()) if path in steps]
        if not found:
            return None
        if not is_basic_material(need):
            step = max(step, min(found))
    return step


def settle(start, recipes, covers, held_in=None):
    """start: path -> lowest step of its own routes. recipes: path -> crafting entries. held_in: path -> containers that hold it.

    Returns the lowest step for everything reachable. Anything not in the result can't be had this way, however many recipes name it.
    """
    steps = dict(start)
    held_in = held_in or {}
    candidates = sorted(set(recipes) | set(held_in))
    changed = True
    while changed:
        changed = False
        for path in candidates:
            options = [recipe_step(entry, steps, covers) for entry in recipes.get(path) or ()]
            options += [steps[container] for container in held_in.get(path, ()) if container in steps]
            options = [step for step in options if step is not None]
            if options and (path not in steps or min(options) < steps[path]):
                steps[path] = min(options)
                changed = True
    return steps
