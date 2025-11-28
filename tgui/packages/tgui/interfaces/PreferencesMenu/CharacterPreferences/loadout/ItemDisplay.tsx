import { useBackend } from 'tgui/backend';
import {
  DmIcon,
  Icon,
  ImageButton,
  NoticeBox,
  Stack,
  Tooltip,
} from 'tgui-core/components';
import { createSearch } from 'tgui-core/string';

import type { LoadoutCategory, LoadoutItem, LoadoutManagerData } from './base';

type Props = {
  item: LoadoutItem;
  scale?: number;
};

export function ItemIcon(props: Props) {
  const { item, scale = 3 } = props;
  const icon_to_use = item.icon;
  const icon_state_to_use = item.icon_state;

  if (!icon_to_use || !icon_state_to_use) {
    return (
      <Icon
        name="question"
        size={Math.round(scale * 2.5)}
        color="red"
        style={{
          transform: `translateX(${scale * 2}px) translateY(${scale * 2}px)`,
        }}
      />
    );
  }

  return (
    <DmIcon
      fallback={<Icon name="spinner" spin color="gray" />}
      icon={icon_to_use}
      icon_state={icon_state_to_use}
      style={{
        transform: `scale(${scale}) translateX(${scale * 3}px) translateY(${
          scale * 3
        }px)`,
      }}
    />
  );
}

type DisplayProps = {
  active: boolean;
  item: LoadoutItem;
  scale?: number;
  owned?: boolean;
  canAfford?: boolean;
};

export function ItemDisplay(props: DisplayProps) {
  const { act } = useBackend();
  const { active, item, scale = 3, owned = true, canAfford = true } = props;

  // Determine if this item requires purchase and isn't owned
  const needsPurchase = item.requires_purchase && !owned;
  const purchaseCost = item.purchase_cost || 0;

  // Color logic: green if selected, orange if needs purchase and can afford, red if can't afford, default otherwise
  let buttonColor = 'default';
  if (active) {
    buttonColor = 'green';
  } else if (needsPurchase) {
    buttonColor = canAfford ? 'orange' : 'red';
  }

  const handleClick = () => {
    if (needsPurchase) {
      // Purchase the item instead of selecting
      act('purchase_loadout_item', { path: item.path });
    } else {
      // Normal select/deselect
      act('select_item', {
        path: item.path,
        deselect: active,
      });
    }
  };

  // Build tooltip
  let tooltipText = item.name;
  if (needsPurchase) {
    tooltipText = canAfford
      ? `${item.name} - Click to purchase (${purchaseCost} credits)`
      : `${item.name} - Not enough credits (${purchaseCost} required)`;
  }

  return (
    <div style={{ position: 'relative' }}>
      <ImageButton
        imageSize={scale * 32}
        color={buttonColor}
        style={{
          textTransform: 'capitalize',
          zIndex: '1',
          opacity: needsPurchase && !canAfford ? 0.6 : 1,
        }}
        tooltip={tooltipText}
        tooltipPosition={'bottom'}
        dmIcon={item.icon}
        dmIconState={item.icon_state}
        onClick={handleClick}
      />
      <div
        style={{ position: 'absolute', top: '8px', right: '8px', zIndex: '2' }}
      >
        {item.information.length > 0 && (
          <Stack vertical>
            {item.information.map((info) => (
              <Stack.Item
                key={info.icon}
                fontSize="14px"
                textColor={'darkgray'}
                bold
              >
                <Tooltip position="right" content={info.tooltip}>
                  <Icon name={info.icon} />
                </Tooltip>
              </Stack.Item>
            ))}
          </Stack>
        )}
      </div>
      {needsPurchase && (
        <div
          style={{
            position: 'absolute',
            bottom: '4px',
            left: '50%',
            transform: 'translateX(-50%)',
            zIndex: '3',
          }}
        >
          <Icon
            name="lock"
            size={1.2}
            color={canAfford ? 'orange' : 'red'}
          />
        </div>
      )}
    </div>
  );
}

type ListProps = {
  items: LoadoutItem[];
};

type LoadoutGroup = {
  items: LoadoutItem[];
  title: string;
};

function sortByGroup(items: LoadoutItem[]): LoadoutGroup[] {
  const groups: LoadoutGroup[] = [];

  for (let i = 0; i < items.length; i++) {
    const item: LoadoutItem = items[i];
    let usedGroup: LoadoutGroup | undefined = groups.find(
      (group) => group.title === item.group,
    );
    if (usedGroup === undefined) {
      usedGroup = { items: [], title: item.group };
      groups.push(usedGroup);
    }
    usedGroup.items.push(item);
  }

  return groups;
}

export function ItemListDisplay(props: ListProps) {
  const { data } = useBackend<LoadoutManagerData>();
  const { loadout_list } = data.character_preferences.misc;
  const itemGroups = sortByGroup(props.items);

  // Voidcrew purchase system data
  const shipCredits = data.ship_credits || 0;
  const ownedItems = data.owned_loadout_items || [];

  // Helper to check if an item is owned
  const isOwned = (item: LoadoutItem) => {
    if (!item.requires_purchase) return true;
    return ownedItems.includes(item.path);
  };

  // Helper to check if player can afford an item
  const canAfford = (item: LoadoutItem) => {
    return shipCredits >= (item.purchase_cost || 0);
  };

  return (
    <Stack vertical>
      {itemGroups.length > 1 && <Stack.Item />}
      {itemGroups.map((group) => (
        <Stack.Item key={group.title}>
          <Stack vertical>
            {itemGroups.length > 1 && (
              <>
                <Stack.Item mt={-1.5} mb={-0.8} ml={1.5}>
                  <h3 color="grey">{group.title}</h3>
                </Stack.Item>
                <Stack.Divider />
              </>
            )}
            <Stack.Item>
              <Stack wrap g={0.5}>
                {group.items.map((item) => (
                  <Stack.Item key={item.name}>
                    <ItemDisplay
                      item={item}
                      active={
                        loadout_list && loadout_list[item.path] !== undefined
                      }
                      owned={isOwned(item)}
                      canAfford={canAfford(item)}
                    />
                  </Stack.Item>
                ))}
              </Stack>
            </Stack.Item>
          </Stack>
        </Stack.Item>
      ))}
    </Stack>
  );
}

type TabProps = {
  category: LoadoutCategory | undefined;
};

export function LoadoutTabDisplay(props: TabProps) {
  const { category } = props;
  if (!category) {
    return (
      <NoticeBox>
        Erroneous category detected! This is a bug, please report it.
      </NoticeBox>
    );
  }

  return <ItemListDisplay items={category.contents} />;
}

type SearchProps = {
  loadout_tabs: LoadoutCategory[];
  currentSearch: string;
};

export function SearchDisplay(props: SearchProps) {
  const { loadout_tabs, currentSearch } = props;

  const search = createSearch(
    currentSearch,
    (loadout_item: LoadoutItem) => loadout_item.name,
  );

  const validLoadoutItems = loadout_tabs
    .flatMap((tab) => tab.contents)
    .filter(search)
    .sort((a, b) => (a.name > b.name ? 1 : -1));

  if (validLoadoutItems.length === 0) {
    return <NoticeBox>No items found!</NoticeBox>;
  }

  return <ItemListDisplay items={validLoadoutItems} />;
}
