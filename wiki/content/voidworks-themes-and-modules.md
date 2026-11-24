---
title: Making Ship Themes & Modules
category: Mapping
order: 1
blurb: How to add modules, module options and themes to a ship with the Voidworks map editor.
---

Voidworks is Voidcrew's map editor. Its **Ship Workshop** shows a ship assembled the way the game builds it, and adds the things players pick between in the [shipyard](ship-upgrades.md): modules, the options inside each module, and themes. You map with the normal editor tools. The workshop splits the work into the right files and registers it with the game.

## What you need

- **Voidworks.** Download the Windows installer from the [Voidworks releases page](https://github.com/voidcrew/Voidworks/releases). It keeps itself up to date.
- **A copy of the Voidcrew game code**, on a branch you can change.

Start Voidworks, choose **Open Project...** and pick the `tgstation.dme` in your copy of the game. Then open **Ship Workshop** from the project page or the **Voidcrew** menu.

If Voidworks says your game code is older or newer than it expects, fix that before you save a ship: pull the latest game code, or update Voidworks, whichever it asks for.

## How a ship is put together

| Piece | What it is | In the shipyard |
|---|---|---|
| Hull | The permanent ship: floors, walls, doors, wiring, pipes and everything every version of the ship has. | A hull |
| Module | A patch of the hull that can be fitted out in more than one way. | A slot |
| Module option | One way to fit out a module, such as a galley or a hydroponics bay. Every module has a default option. | A module |
| Theme | A version of the whole ship with its own hull map. It decides which modules and options it offers, and can have its own crew and price. | A finish |

## Open a ship

1. Under **Choose a ship**, find the ship and press **Open**. **Create a new ship** starts an empty hull instead.
2. You are now in **Build**. The left panel lists the ship's **Modules** and **Themes**, and the map shows the hull with one option fitted in each module.
3. Click **Hull** or a module in the Modules list to choose where your edits go.

The line above the map names the part you are editing. Read it before you place anything. Pointing at a different module on the map offers a button to edit that one instead.

![The Build screen with a module's options listed on the left](assets/images/voidworks/workshop-build.png){: .screenshot }

## Make a module

Build and furnish the room as part of the hull first. Then:

1. Click **+ Make an upgrade module** at the bottom of the Modules list.
2. Mark the module's tiles on the map. Click or drag to add tiles, click a tile again to remove it, Shift+drag to add a box and Alt+drag to remove one. A module can be any shape, but it cannot overlap another module.
3. Type a **Module name** and press **Create module**.

![Marking a module's tiles](assets/images/voidworks/workshop-make-module.png){: .screenshot }

The room's contents leave the hull and become the module's first option, which is its default. Floors, walls, areas, doors, pipes and vents, cables, power machines, lights, air and fire alarms, cryopods and the docking port stay in the hull, so every option you add later sits in the same shell. Ctrl+Z undoes the whole step.

A ship with no modules is listed under **Fixed layout** in the ship library. Making its first module turns it into a modular ship, and Voidworks asks you to confirm first.

The **Module...** button under an open module has **Rename module...**, **Change shape...**, **Show none (hull only)** and **Delete module...**. Deleting a module puts its default option's contents back in the hull and deletes its other options. Tiles you cut out of a module with **Change shape...** must be empty in every option.

## Add options to a module

1. Click the module to open its list, then **+ Add option**.
2. Enter a **Module option name** and a **Description**. Players read the description in the shipyard.
3. Leave **Start with an empty module** unticked to begin from a copy of the option on screen, or tick it to start bare.
4. Open **Part costs** if the option should cost something, then press **Create module option**. An option is free until you price it.

The new option is on the map and ready to edit. The round button beside each option puts that option on the map and makes it the part you are editing. The **...** beside it has **Rename & describe**, **Set price**, **Crew**, **Make default** and **Delete option...**.

## Make a theme

1. In the Themes list, click the theme you want to start from. The new theme begins as a copy of that theme's hull.
2. Click **+ Add a theme**. Enter a **Theme name** and a **Description**.
3. Under **Modules**, choose one:
    - **Share with the ship** uses the ship's existing module options. An edit to a shared option shows in every theme that shares it. This is the usual choice.
    - **Copy every module** gives the theme its own copy of every option, which you can change without touching the other themes.
4. Open **Part costs** if the theme should cost something, then press **Create ship theme**.

![The form for a new theme](assets/images/voidworks/workshop-new-theme.png){: .screenshot }

You are now editing the new theme. Click **Hull** in the Modules list and restyle it: walls, floors, lighting, fittings.

A ship that has never had a theme keeps its current hull as its first one, and that theme becomes the default. Add a second theme to get a new hull to work on.

### What a theme offers

Click a theme to switch to it. The open theme lists the ship's modules and their options:

![The Themes list with one theme open](assets/images/voidworks/workshop-themes.png){: .screenshot }

- The tick beside a **module** decides whether this theme has it at all.
- The tick beside an **option** decides whether this theme offers it.
- The word under each option says whether the theme uses the **Shared** option or its **Own copy**. In an option's **...**, **Make theme-specific** gives this theme its own copy to edit, and **Use shared module** throws that copy away.

While you edit an option, the line above the map ends in **(shared)** or **(this theme)**. An edit to a shared option changes every theme that uses it.

The **Theme...** button has **Rename & describe**, **Set price**, **Crew**, **Make default** and **Delete theme...**.

## Prices and crew

**Ship & upgrade prices**, under Configuration, lists the hull, every theme and every option in one place. Prices are in [ship parts](ship-parts.md): Combat, Science, Trade and Misc. Pick a component, enter its costs and press **Apply costs**. Leave the default theme and each module's default option free. An option costs the same in every theme that offers it.

**Crew & equipment** sets the jobs. The ship has a base crew. A theme can replace it with its own roster, and a theme with an empty roster uses the ship's. A module option adds its jobs when a player fits it.

## Save and test

1. Go to **Review & save**. Read **Map checks**, look through **Changes to save**, then press **Save all changes**.
2. The shipyard's pictures of the ship redraw in the background after a save. The left panel shows the progress. Wait for it to finish.
3. Commit every file the save listed, along with the new pictures.
4. Compile the game and start a local server. The stock local config unlocks every ship, theme and option. Open the **SHIPYARD** tab on the dock terminal in the lobby, build the ship with your theme and each new option, and walk through it.

The map checks cover the combination on screen and nothing else. Test every new option in every theme that offers it.

## Rules of thumb

- A ship with every module on its default must fly. Keep the helm, engines, power, air, airlocks and a cryopod in the hull.
- If a module holds a machine the ship depends on, every option for that module needs one.
- Keep doorways and the cryopod's exit clear in every option. Check each option against the hull's doors, not only the one you built first.
- Do not add cryopods to options, and keep armory lockers out of the rooms a ship starts with.
- An option can add a job. Give that job somewhere to work and the gear to do it.

## If something looks wrong

| Problem | Try this |
|---|---|
| Your edits land in the wrong place | Read the line above the map, then pick the right part in the Modules list. |
| A change shows up in every theme | The option is shared. Use **Make theme-specific** on it in that theme, then edit. |
| A name is refused | Names must be different from the ship's other modules, options and themes. Capitals and extra spaces do not count as a difference. |
| A tile will not join a module | It is outside the hull, or it already belongs to another module. |
| Modules can only be rectangles | Your game code is too old for shaped modules. Pull the latest. |
| Something is in both the hull and an option | Under Configuration, open **Advanced view** and tick **Show only the part being edited** to see which part owns it. |
