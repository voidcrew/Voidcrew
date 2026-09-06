import { useState } from 'react';
import {
  Box,
  Button,
  Divider,
  Dropdown,
  LabeledList,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import { type BooleanLike, classes } from 'tgui-core/react';
import { capitalizeAll } from 'tgui-core/string';

import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';
import { AirLockMainSection } from '../../tgui/interfaces/AirlockElectronics';

interface MaterialData {
  name: string;
  amount: number;
}

interface TurfTypeData {
  name: string;
  materials: MaterialData[];
}

interface Category {
  cat_name: string;
  designs: Design[];
}

interface Design {
  title: string;
  icon: string;
}

interface Data {
  // Standard RCD data
  matterLeft: number;
  silo_upgraded: BooleanLike;
  silo_enabled: BooleanLike;
  root_categories: string[];
  selected_root: string;
  categories: Category[];
  selected_category: string;
  selected_design: string;
  display_tabs: BooleanLike;
  // Ship RCD additions
  wallTypes: TurfTypeData[];
  floorTypes: TurfTypeData[];
  selectedWallType: string;
  selectedFloorType: string;
  siloMaterials: Record<string, number>;
  usingSilo: BooleanLike;
}

const MatterItem = () => {
  const { data } = useBackend<Data>();
  const { matterLeft } = data;
  return (
    <LabeledList.Item label="Units Left">
      &nbsp;{matterLeft} Units
    </LabeledList.Item>
  );
};

const SiloItem = () => {
  const { act, data } = useBackend<Data>();
  const { silo_enabled } = data;
  return (
    <LabeledList.Item label="Silo Link">
      <Button.Checkbox
        content={silo_enabled ? 'Silo Online' : 'Silo Offline'}
        checked={silo_enabled}
        color="transparent"
        onClick={() => act('toggle_silo')}
      />
    </LabeledList.Item>
  );
};

const CategoryItem = () => {
  const { act, data } = useBackend<Data>();
  const { root_categories = [], selected_root } = data;
  return (
    <LabeledList.Item label="Category">
      {root_categories.map((root) => (
        <Button
          key={root}
          content={root}
          selected={selected_root === root}
          color="transparent"
          onClick={() => act('root_category', { root_category: root })}
        />
      ))}
    </LabeledList.Item>
  );
};

const InfoSection = () => {
  const { data } = useBackend<Data>();
  const { silo_upgraded } = data;

  return (
    <Section>
      <LabeledList>
        <MatterItem />
        {silo_upgraded ? <SiloItem /> : ''}
        <CategoryItem />
      </LabeledList>
    </Section>
  );
};

// Designs whose sprite is a full 32x32 tile (or a grille-backed window), which needs
// scaling down to sit next to the 32x32 item icons in the same list.
const FULL_TILE_DESIGNS = [
  'full tile window',
  'full tile reinforced window',
  'plasma window',
  'reinforced plasma window',
  'shuttle window',
  'plastitanium window',
  'catwalk',
];

const DesignSection = () => {
  const { act, data } = useBackend<Data>();
  const { categories = [], selected_category, selected_design } = data;
  const [categoryName, setCategoryName] = useState(selected_category);
  const shownCategory =
    categories.find((category) => category.cat_name === categoryName) ||
    categories[0];

  return (
    <Section fill scrollable>
      <Tabs>
        {categories.map((category) => (
          <Tabs.Tab
            key={category.cat_name}
            selected={category.cat_name === shownCategory?.cat_name}
            onClick={() => setCategoryName(category.cat_name)}
          >
            {category.cat_name}
          </Tabs.Tab>
        ))}
      </Tabs>
      {shownCategory?.designs.map((design, i) => (
        <Button
          key={i + 1}
          fluid
          height="31px"
          color="transparent"
          selected={
            design.title === selected_design &&
            shownCategory.cat_name === selected_category
          }
          onClick={() =>
            act('design', {
              category: shownCategory.cat_name,
              index: i + 1,
            })
          }
        >
          <Box
            inline
            verticalAlign="middle"
            mr="10px"
            className={classes(['rcd-tgui32x32', design.icon])}
            style={{
              transform: FULL_TILE_DESIGNS.includes(design.title)
                ? 'scale(0.7)'
                : 'scale(1.0)',
            }}
          />
          <span>{capitalizeAll(design.title)}</span>
        </Button>
      ))}
    </Section>
  );
};

const ConfigureSection = () => {
  const { data } = useBackend<Data>();
  const { selected_root } = data;

  return (
    <Stack.Item grow>
      {selected_root === 'Airlock Access' ? (
        <AirLockMainSection />
      ) : (
        <DesignSection />
      )}
    </Stack.Item>
  );
};

const formatMaterials = (materials: MaterialData[]): string => {
  return materials.map((mat) => `${mat.amount} ${mat.name}`).join(', ');
};

const MaterialTypeSection = () => {
  const { act, data } = useBackend<Data>();
  const {
    wallTypes = [],
    floorTypes = [],
    selectedWallType,
    selectedFloorType,
    siloMaterials = {},
    usingSilo,
  } = data;

  const selectedWall = wallTypes.find((w) => w.name === selectedWallType);
  const selectedFloor = floorTypes.find((f) => f.name === selectedFloorType);

  return (
    <Section title="Material Types">
      <LabeledList>
        <LabeledList.Item label="Wall Type">
          <Dropdown
            width="160px"
            selected={selectedWallType}
            options={wallTypes.map((w) => w.name)}
            onSelected={(value) => act('select_wall_type', { type: value })}
          />
          {selectedWall && (
            <Box inline ml={1} color="gray">
              ({formatMaterials(selectedWall.materials)})
            </Box>
          )}
        </LabeledList.Item>
        <LabeledList.Item label="Floor Type">
          <Dropdown
            width="160px"
            selected={selectedFloorType}
            options={floorTypes.map((f) => f.name)}
            onSelected={(value) => act('select_floor_type', { type: value })}
          />
          {selectedFloor && (
            <Box inline ml={1} color="gray">
              ({formatMaterials(selectedFloor.materials)})
            </Box>
          )}
        </LabeledList.Item>
      </LabeledList>
      <Divider />
      <Box color="label" mb={1}>
        Silo Materials:
      </Box>
      {usingSilo ? (
        <LabeledList>
          {Object.entries(siloMaterials).length > 0 ? (
            Object.entries(siloMaterials).map(([name, amount]) => (
              <LabeledList.Item key={name} label={capitalizeAll(name)}>
                {amount}
              </LabeledList.Item>
            ))
          ) : (
            <LabeledList.Item label="Status">
              <Box color="gray">No materials</Box>
            </LabeledList.Item>
          )}
        </LabeledList>
      ) : (
        <Box color="bad">Not linked to ore silo</Box>
      )}
    </Section>
  );
};

export const ShipRCD = () => {
  return (
    <Window width={480} height={680} title="Ship RCD">
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item>
            <InfoSection />
          </Stack.Item>
          <Stack.Item>
            <MaterialTypeSection />
          </Stack.Item>
          <Stack.Item grow>
            <Stack fill>
              <ConfigureSection />
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
