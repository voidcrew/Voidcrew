"""Facts about every /obj/item type: what it does, its stats, what it costs and how players get it. No ratings or opinions.

    python -m tools.gear_catalog dump    the running-world step, Windows only. Only needed when item stats change
    python -m tools.gear_catalog build   rebuild the facts from the dump plus the source
    python -m tools.gear_catalog sheet   a compact table of one category for a reader

Importing this package runs nothing. tools.gear_catalog.static_sources.load_static(root) gives the DM reader, shops, cargo, printing and
crafting with no dump and no world. Output goes to data/gear_catalog/ under the checkout; nothing generated is tracked.
"""
