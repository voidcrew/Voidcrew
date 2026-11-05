"""Facts about every /obj/item type: what it does, its stats, what it costs and how players get it. Ratings sit on top of them, in tracked files.

    python -m tools.gear_catalog dump    the running-world step, Windows only. Only needed when item stats change
    python -m tools.gear_catalog build   rebuild the facts from the dump plus the source
    python -m tools.gear_catalog sheet   a compact table of one category for a reader
    python -m tools.gear_catalog notes   the work lists of owner types that still need a written note
    python -m tools.gear_catalog stale   gear with no rating, ratings whose facts changed, and ratings of paths that are gone
    python -m tools.gear_catalog merge   apply a rater's output to a ratings file
    python -m tools.gear_catalog sync    fill in why paths in gear categories have no rating

Importing this package runs nothing. tools.gear_catalog.static_sources.load_static(root) gives the DM reader, shops, cargo, printing and
crafting with no dump and no world. Output goes to data/gear_catalog/ under the checkout, which isn't tracked; ratings/, policy.json and
exceptions.json in this folder are. python -m tools.ci.check_gear_ratings holds pull requests to them.
"""
