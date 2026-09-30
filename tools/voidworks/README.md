# Voidworks compatibility

`compatibility.json` tells the Voidworks map editor which version of the editor contract this game code provides. Voidworks checks it when a project loads:

- If the number here is **lower** than the one Voidworks was built for, Voidworks tells the mapper their game code is out of date and to pull the latest master.
- If the number here is **higher**, Voidworks tells them to update Voidworks before saving ships.

Increase `voidworks_api` by one when a change here breaks what Voidworks reads or writes, such as:

- ship, room, crew or theme variables and datums that the Ship Workshop edits
- the files and folders under `voidcrew/mapping/ship_projects/`
- `tools/ship_previews/generate_ship_previews.py` and the preview metadata format
- planet and ruin definitions that the Planet and Ruin Workshops edit

Release a Voidworks version that understands the new number at the same time, so mappers are not left without a working editor.

CI posts a warning (never a failure) on PRs that change the files declaring what Voidworks reads, listed in `tools/ci/check_voidworks_compat.py`, without touching `compatibility.json`. Most such changes are compatible; the warning only asks you to check.
