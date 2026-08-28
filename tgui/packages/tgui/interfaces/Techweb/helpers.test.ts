/**
 * Pins the shape of the R&D console's `ui_static_data` payload against the remapper that
 * consumes it.
 *
 * ## Why this file exists
 *
 * The 2026-08 upstream catch-up merge left a fork fossil in the tree:
 * `tgui/packages/voidcrew_tgui/interfaces/Techweb.jsx`, a 768-line pre-2025 monolith that the
 * interface router probed and preferred over upstream's rewritten `Techweb/` directory. Its
 * remapper destructured a design_cache row as two elements:
 *
 *     const [name, classes] = data.static_data.design_cache[id];
 *     ...
 *     class: classes.startsWith('design') ? classes : `design32x32 ${classes}`
 *
 * The DM side (`code/modules/research/rdconsole.dm`, `ui_static_data`) sends **five** elements:
 *
 *     design_cache[compressed_id] = list(
 *         design.name,              // 1
 *         cost,                     // 2  assoc list of material name -> amount
 *         design.build_type,        // 3
 *         design.departmental_flags,// 4
 *         "<size >asset_id"         // 5  the spritesheet class the UI actually wanted
 *     )
 *
 * so `classes` was bound to slot 2 - the material cost **object** - and `classes.startsWith(...)`
 * threw `TypeError: classes.startsWith is not a function` on the first TechNode render. The R&D
 * console UI came up blank for every crew in the fleet.
 *
 * Nothing caught it. `tsc` could not: the fossil was `.jsx` and `checkJs` is off, so its
 * destructure was never type-checked against `StaticData` in `./types.ts`. There was no test
 * anywhere under `interfaces/Techweb/`.
 *
 * ## The causal chain, and why this test would have failed against the fossil
 *
 * The fossil is deleted, so this file cannot import it. What it does instead is pin the contract
 * from both ends against the code that survived:
 *
 * 1. The fixture below is a faithful miniature of what the CURRENT DM emits - five-element
 *    design_cache rows with the cost object in slot 2, path-keyed nodes carrying
 *    `prerequisite_nodes` / `unlocked_designs` / `unlocked_nodes` as compressed ids, and a
 *    survey-gated node carrying `required_surveyed_objects`.
 * 2. `useRemappedBackend()` (the survivor) is asserted to consume that fixture without throwing
 *    and to produce a design entry whose `class` came from **slot 5** and whose `cost` is the
 *    object from **slot 2**. A remapper that read slot 2 as the class string cannot satisfy both.
 * 3. The last test in this file re-runs the fossil's exact `[name, classes]` destructure over the
 *    same fixture and asserts that it throws. That is the fossil's crash, reproduced from its
 *    source pattern rather than from the deleted file - so if anyone ever "simplifies" the DM row
 *    back down to two elements, that test starts failing too and the direction of the break is
 *    unambiguous.
 *
 * The node keys are also part of the contract: the fossil read `prereq_ids` / `design_ids` /
 * `unlock_ids`, the pre-#97223 names. Upstream now sends `prerequisite_nodes` /
 * `unlocked_designs` / `unlocked_nodes`, and those come through empty rather than throwing - a
 * silent break, which is why they get their own assertions here.
 */

import { describe, expect, it } from 'bun:test';

import { gameDataAtom, store } from '../../events/store';
import { useRemappedBackend } from './helpers';

/**
 * `compress_id()` hands out 1-based sequential integers and ships the reverse table as a flat
 * array, so entry N of this array decompresses to the string id `N + 1`.
 */
const ID_CACHE = [
  /* 1 */ '/datum/techweb_node/fundamental_sci',
  /* 2 */ '/datum/techweb_node/basic_shuttle_tech',
  /* 3 */ '/datum/techweb_node/transporter',
  /* 4 */ '/datum/design/board/rdconsole',
  /* 5 */ '/datum/design/board/shuttle/shuttle_helm',
  /* 6 */ 'General Research',
];

const NODE_FUNDAMENTAL = '/datum/techweb_node/fundamental_sci';
const NODE_SHUTTLE = '/datum/techweb_node/basic_shuttle_tech';
const NODE_TRANSPORTER = '/datum/techweb_node/transporter';
const DESIGN_CONSOLE = '/datum/design/board/rdconsole';
const DESIGN_HELM = '/datum/design/board/shuttle/shuttle_helm';

/**
 * A miniature of the real payload. Everything here is shaped the way the DM serialises it:
 * node_cache and design_cache are keyed by stringified compressed ids, node cross-references are
 * bare compressed integers, `costs` is keyed by a compressed point-type id, and each design row
 * is the five-element positional list quoted in the header comment.
 */
function makeGameData() {
  return {
    stored_research: 1,
    locked: 0,
    sec_protocols: 0,
    nodes: [],
    queue_nodes: [],
    researched_designs: {},
    points: { 'General Research': 5000 },
    points_last_tick: {},
    point_types_abbreviations: { 'General Research': 'Gen. Res.' },
    experiments: {},
    d_disk: null,
    t_disk: null,
    // voidcrew edit - the ship's charted-object tally, from the fork's ui_data override.
    surveyed_objects: { planets: 1 },
    static_data: {
      node_cache: {
        '1': {
          name: 'Fundamental Science',
          description: 'The bedrock of scientific understanding.',
          unlocked_designs: [4],
          unlocked_nodes: [2],
        },
        '2': {
          name: 'Basic Shuttle Research',
          description: 'Technology required to create and pilot basic shuttles.',
          costs: { '6': 40 },
          prerequisite_nodes: [1],
          unlocked_designs: [5],
          unlocked_nodes: [3],
        },
        '3': {
          name: 'Transporter',
          description: 'Matter transmission.',
          costs: { '6': 160 },
          prerequisite_nodes: [2],
          // voidcrew edit - survey gating. The DM builds this with `+=` of single-pair lists,
          // which in DM merges key/value pairs, so it serialises as an object.
          required_surveyed_objects: { planets: 3 },
        },
      },
      design_cache: {
        // 32x32 sprite: the DM sends the bare asset id and the remapper prefixes the sheet class.
        '4': [
          'Computer Design (R&D Console)',
          { Glass: 0.5, Iron: 1 },
          4,
          128,
          'rdconsole',
        ],
        // Non-32x32 sprite: the DM already prefixed the sheet class, so it passes through whole.
        '5': [
          'Computer Design (Shuttle Helm Console)',
          { Glass: 0.5 },
          4,
          96,
          'design64x64 shuttle_helm',
        ],
      },
      id_cache: ID_CACHE,
      SHEET_MATERIAL_AMOUNT: 2000,
      build_types: { '4': 'Imprinter' },
      department_flags: { '128': 'Science' },
    },
  };
}

// `useBackend()` reads the Jotai store directly rather than through a React hook, so the remapper
// can be driven outside a render. `useRemappedBackend` memoises its remap in a module-level
// variable, so the store is seeded once, up front, and every test below reads the same result.
store.set(gameDataAtom, makeGameData());

const remapped = useRemappedBackend();

describe('Techweb static data remapper', () => {
  it('ingests the current DM payload without throwing', () => {
    expect(() => useRemappedBackend()).not.toThrow();
  });

  it('decompresses every node id into a path key', () => {
    const { node_cache } = remapped.data;

    expect(Object.keys(node_cache).sort()).toEqual(
      [NODE_FUNDAMENTAL, NODE_SHUTTLE, NODE_TRANSPORTER].sort(),
    );
    expect(node_cache[NODE_SHUTTLE].name).toBe('Basic Shuttle Research');
    expect(node_cache[NODE_SHUTTLE].id).toBe(NODE_SHUTTLE);
  });

  it('decompresses node cross-references, not just the keys', () => {
    const shuttle = remapped.data.node_cache[NODE_SHUTTLE];

    // These are the three keys the deleted fossil read under their pre-#97223 names
    // (prereq_ids / design_ids / unlock_ids). Under those names they come back empty - a silent
    // break rather than a crash - so they are asserted populated here.
    expect(shuttle.prerequisite_nodes).toEqual([NODE_FUNDAMENTAL]);
    expect(shuttle.unlocked_designs).toEqual([DESIGN_HELM]);
    expect(shuttle.unlocked_nodes).toEqual([NODE_TRANSPORTER]);
  });

  it('turns the compressed cost map into typed cost entries', () => {
    const shuttle = remapped.data.node_cache[NODE_SHUTTLE];

    expect(shuttle.costs).toEqual([{ type: 'General Research', value: 40 }]);
  });

  it('fills in the optional node fields the DM omits', () => {
    const fundamental = remapped.data.node_cache[NODE_FUNDAMENTAL];

    // The DM only sends these keys when they are non-empty. TechNode.tsx calls .filter() and
    // .reduce() on them unconditionally, so the remapper has to default them.
    expect(fundamental.costs).toEqual([]);
    expect(fundamental.prerequisite_nodes).toEqual([]);
    expect(fundamental.required_experiments).toEqual([]);
    expect(fundamental.discount_experiments).toEqual([]);
    expect(fundamental.discount_boosts).toEqual([]);
    expect(fundamental.required_surveyed_objects).toEqual({});
  });

  it('carries survey gating through to the node cache', () => {
    // voidcrew edit - added by the ui_static_data override in
    // voidcrew/modules/research/edits/_rd_consoles.dm. TechNode.tsx runs Object.entries() over
    // this to draw the "Required Surveys" collapsible and its progress bar.
    const transporter = remapped.data.node_cache[NODE_TRANSPORTER];

    expect(transporter.required_surveyed_objects).toEqual({ planets: 3 });
    expect(Object.entries(transporter.required_surveyed_objects ?? {})).toEqual([
      ['planets', 3],
    ]);
  });

  it('reads the design row positionally, with the sprite class in slot 5', () => {
    const { design_cache } = remapped.data;

    expect(Object.keys(design_cache).sort()).toEqual(
      [DESIGN_CONSOLE, DESIGN_HELM].sort(),
    );

    const console_design = design_cache[DESIGN_CONSOLE];
    expect(console_design.name).toBe('Computer Design (R&D Console)');
    // Slot 2 is the material cost object. This is the assertion the fossil could not have passed:
    // it bound slot 2 to `classes` and never produced a `cost` at all.
    expect(console_design.cost).toEqual({ Glass: 0.5, Iron: 1 });
    expect(console_design.build_types).toBe(4);
    expect(console_design.department_flags).toBe(128);
    // Slot 5, prefixed because it is not already a sheet class.
    expect(console_design.class).toBe('design32x32 rdconsole');
  });

  it('passes an already-prefixed sprite class through unchanged', () => {
    expect(remapped.data.design_cache[DESIGN_HELM].class).toBe(
      'design64x64 shuttle_helm',
    );
  });

  it('forwards the scalar static fields the fabricator views need', () => {
    expect(remapped.data.SHEET_MATERIAL_AMOUNT).toBe(2000);
    expect(remapped.data.build_types).toEqual({ '4': 'Imprinter' });
    expect(remapped.data.department_flags).toEqual({ '128': 'Science' });
    // The raw compressed payload must not survive into the view data.
    expect(remapped.data.static_data).toBeUndefined();
  });

  it('leaves the non-static payload alone', () => {
    expect(remapped.data.points).toEqual({ 'General Research': 5000 });
    expect(remapped.data.surveyed_objects).toEqual({ planets: 1 });
  });
});

describe('the deleted Techweb.jsx fossil', () => {
  it('crashes on a five-element design row, which is why the console UI never rendered', () => {
    // Verbatim reproduction of voidcrew_tgui/interfaces/Techweb.jsx:57-61 (git HEAD before the
    // fossil was deleted). `classes` binds to slot 2 - the material cost object - and objects
    // have no .startsWith. This is the TypeError that took the R&D console down.
    const row = makeGameData().static_data.design_cache['4'];
    const fossilRemap = () => {
      const [, classes] = row as unknown as [string, string];
      return classes.startsWith('design') ? classes : `design32x32 ${classes}`;
    };

    expect(fossilRemap).toThrow();
  });
});
