/**
 * Owner shop stock unit: the staff window (outpost_shop_stock.dm).
 *
 * Selection: click selects one row and sets the anchor, Ctrl+click toggles,
 * Shift+click selects the displayed range from the anchor, Ctrl+A selects
 * every visible row, Escape clears. Drag selected rows onto a category to
 * move them. Every action sends explicit id lists; the server re-checks all.
 */
import {
  type PointerEvent as ReactPointerEvent,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  Box,
  Button,
  DmIcon,
  Icon,
  Input,
  KeyListener,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import type { KeyEvent } from 'tgui-core/events';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Category = { id: string; name: string };

type Listing = {
  id: string;
  name: string;
  category: string;
  icon: string;
  icon_state: string;
  count: number;
  units: number;
  per_unit: BooleanLike;
  price: number;
};

type Sale = {
  when: string;
  buyer: string;
  name: string;
  qty: number;
  total: number;
  taken: BooleanLike;
};

type Data = {
  shop_name: string;
  open: BooleanLike;
  can_stock: BooleanLike;
  can_price: BooleanLike;
  category_limit: number;
  max_price: number;
  categories: Category[];
  listings: Listing[];
  sales: Sale[];
};

const ALL = '__all__';
const DRAG_THRESHOLD = 4;
const KEY_A = 65;
const KEY_ESCAPE = 27;

type Drag = {
  pointerId: number;
  startX: number;
  startY: number;
  active: boolean;
  ids: string[];
};

/** Row selection over the displayed order, pruned when rows vanish. */
const useSelection = (visibleIds: string[], allIds: string[]) => {
  const [selected, setSelected] = useState<string[]>([]);
  const [anchor, setAnchor] = useState<string | null>(null);

  // Drop ids the server no longer sends
  useEffect(() => {
    const known = new Set(allIds);
    const kept = selected.filter((id) => known.has(id));
    if (kept.length !== selected.length) {
      setSelected(kept);
    }
    if (anchor !== null && !known.has(anchor)) {
      setAnchor(null);
    }
  }, [allIds.join(',')]);

  const onRowClick = (id: string, ctrl: boolean, shift: boolean) => {
    if (shift && anchor !== null) {
      const from = visibleIds.indexOf(anchor);
      const to = visibleIds.indexOf(id);
      if (from !== -1 && to !== -1) {
        const range = visibleIds.slice(
          Math.min(from, to),
          Math.max(from, to) + 1,
        );
        setSelected(
          ctrl ? Array.from(new Set([...selected, ...range])) : range,
        );
        return;
      }
    }
    if (ctrl) {
      setSelected(
        selected.includes(id)
          ? selected.filter((other) => other !== id)
          : [...selected, id],
      );
      setAnchor(id);
      return;
    }
    setSelected([id]);
    setAnchor(id);
  };

  const selectAll = () => setSelected([...visibleIds]);
  const clear = () => {
    setSelected([]);
    setAnchor(null);
  };
  const selectOnly = (id: string) => {
    setSelected([id]);
    setAnchor(id);
  };

  return { selected, onRowClick, selectAll, clear, selectOnly };
};

export const OutpostShopStock = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    shop_name,
    open,
    can_stock,
    can_price,
    category_limit,
    max_price,
    categories = [],
    listings = [],
    sales = [],
  } = data;

  const [tab, setTab] = useState<'stock' | 'sales'>('stock');
  const [category, setCategory] = useState<string>(ALL);
  const [search, setSearch] = useState('');
  const [price, setPrice] = useState(100);
  const [newCategory, setNewCategory] = useState('');
  const [renaming, setRenaming] = useState<string | null>(null);
  const [renameText, setRenameText] = useState('');
  const [dragOver, setDragOver] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const dragRef = useRef<Drag | null>(null);

  const knownCategory = categories.some((cat) => cat.id === category);
  const shownCategory = category === ALL || knownCategory ? category : ALL;

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();
    return listings.filter(
      (listing) =>
        (shownCategory === ALL || listing.category === shownCategory) &&
        (!needle || listing.name.toLowerCase().includes(needle)),
    );
  }, [listings, shownCategory, search]);

  const visibleIds = visible.map((listing) => listing.id);
  const allIds = listings.map((listing) => listing.id);
  const selection = useSelection(visibleIds, allIds);
  const selected = selection.selected;
  const selectedSet = new Set(selected);
  const selectedEmpty = listings.filter(
    (listing) => selectedSet.has(listing.id) && listing.count === 0,
  ).length;

  // KeyListener binds its handler once; read the current render through a ref
  const keyRef = useRef<(key: KeyEvent) => void>(() => {});
  useLayoutEffect(() => {
    keyRef.current = (key: KeyEvent) => {
      if (key.code === KEY_A && key.ctrl) {
        key.event.preventDefault();
        selection.selectAll();
      } else if (key.code === KEY_ESCAPE) {
        selection.clear();
      }
    };
  });

  const onRowPointerDown = (
    event: ReactPointerEvent<HTMLDivElement>,
    id: string,
  ) => {
    if (
      event.button !== 0 ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey ||
      !can_price
    ) {
      return;
    }
    const ids = selectedSet.has(id) ? selected : [id];
    dragRef.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      active: false,
      ids,
    };
  };

  const categoryUnder = (x: number, y: number): string | null => {
    const element = document.elementFromPoint(x, y) as HTMLElement | null;
    const target = element?.closest('[data-category]') as HTMLElement | null;
    return target?.dataset.category ?? null;
  };

  const onListPointerMove = (event: ReactPointerEvent<HTMLDivElement>) => {
    const drag = dragRef.current;
    if (!drag || drag.pointerId !== event.pointerId) {
      return;
    }
    if (!drag.active) {
      const moved = Math.hypot(
        event.clientX - drag.startX,
        event.clientY - drag.startY,
      );
      if (moved < DRAG_THRESHOLD) {
        return;
      }
      drag.active = true;
      setDragging(true);
      event.currentTarget.setPointerCapture(event.pointerId);
    }
    setDragOver(categoryUnder(event.clientX, event.clientY));
  };

  const endDrag = (event: ReactPointerEvent<HTMLDivElement>, drop: boolean) => {
    const drag = dragRef.current;
    if (!drag || drag.pointerId !== event.pointerId) {
      return;
    }
    dragRef.current = null;
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    if (drag.active && drop) {
      const target = categoryUnder(event.clientX, event.clientY);
      if (target && target !== ALL) {
        act('move', { ids: drag.ids, category: target });
      }
    }
    setDragging(false);
    setDragOver(null);
  };

  const ownCategories = categories.filter((cat) => cat.id !== '0');

  return (
    <Window width={820} height={640} title={shop_name}>
      <KeyListener onKeyDown={(key) => keyRef.current(key)} />
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Stack align="center">
              <Stack.Item grow>
                <Tabs>
                  <Tabs.Tab
                    icon="boxes-stacked"
                    selected={tab === 'stock'}
                    onClick={() => setTab('stock')}
                  >
                    Stock
                  </Tabs.Tab>
                  <Tabs.Tab
                    icon="receipt"
                    selected={tab === 'sales'}
                    onClick={() => setTab('sales')}
                  >
                    Sales
                  </Tabs.Tab>
                </Tabs>
              </Stack.Item>
              {can_stock ? (
                <Stack.Item>
                  <Button icon="box-open" onClick={() => act('insert_held')}>
                    Stock held item
                  </Button>
                </Stack.Item>
              ) : null}
              <Stack.Item>
                <Button
                  icon={open ? 'door-open' : 'door-closed'}
                  color={open ? 'good' : 'bad'}
                  onClick={() => act('toggle_open')}
                >
                  {open ? 'Open' : 'Closed'}
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          {tab === 'sales' ? (
            <Stack.Item grow>
              <SalesList sales={sales} />
            </Stack.Item>
          ) : (
            <Stack.Item grow>
              <Stack fill>
                <Stack.Item width="220px">
                  <Section fill scrollable>
                    <CategoryRow
                      id={ALL}
                      name="All"
                      active={shownCategory === ALL}
                      hovered={false}
                      onClick={() => setCategory(ALL)}
                    />
                    {categories.map((cat) => (
                      <CategoryRow
                        key={cat.id}
                        id={cat.id}
                        name={cat.name}
                        active={shownCategory === cat.id}
                        hovered={dragging && dragOver === cat.id}
                        onClick={() => setCategory(cat.id)}
                      />
                    ))}
                    {can_price ? (
                      <Box mt={1}>
                        {shownCategory !== ALL && shownCategory !== '0' ? (
                          <CategoryTools
                            id={shownCategory}
                            index={
                              ownCategories.findIndex(
                                (cat) => cat.id === shownCategory,
                              ) + 1
                            }
                            renaming={renaming === shownCategory}
                            renameText={renameText}
                            setRenameText={setRenameText}
                            startRename={() => {
                              setRenaming(shownCategory);
                              setRenameText(
                                categories.find(
                                  (cat) => cat.id === shownCategory,
                                )?.name || '',
                              );
                            }}
                            stopRename={() => setRenaming(null)}
                          />
                        ) : null}
                        <Stack mt={1}>
                          <Stack.Item grow>
                            <Input
                              fluid
                              placeholder="New category"
                              maxLength={23}
                              value={newCategory}
                              onChange={setNewCategory}
                            />
                          </Stack.Item>
                          <Stack.Item>
                            <Button
                              icon="plus"
                              disabled={
                                !newCategory.trim() ||
                                ownCategories.length >= category_limit
                              }
                              tooltip="Add category"
                              onClick={() => {
                                act('add_category', { name: newCategory });
                                setNewCategory('');
                              }}
                            />
                          </Stack.Item>
                        </Stack>
                      </Box>
                    ) : null}
                  </Section>
                </Stack.Item>
                <Stack.Item grow>
                  <Section
                    fill
                    scrollable
                    title={selected.length ? `${selected.length} selected` : undefined}
                    buttons={
                      <Input
                        placeholder="Search"
                        value={search}
                        onChange={setSearch}
                      />
                    }
                  >
                    {can_price ? (
                      <Stack mb={1} wrap>
                        <Stack.Item>
                          <NumberInput
                            value={price}
                            minValue={1}
                            maxValue={max_price}
                            step={1}
                            unit="cr"
                            width="90px"
                            onChange={(value) => setPrice(Math.round(value))}
                          />
                        </Stack.Item>
                        <Stack.Item>
                          <Button
                            icon="tag"
                            disabled={!selected.length}
                            onClick={() =>
                              act('set_price', { ids: selected, price })
                            }
                          >
                            Set price
                          </Button>
                        </Stack.Item>
                        <Stack.Item>
                          <Button
                            icon="ban"
                            disabled={!selected.length}
                            onClick={() => act('unlist', { ids: selected })}
                          >
                            Unlist
                          </Button>
                        </Stack.Item>
                        <Stack.Item>
                          <Button
                            icon="eject"
                            disabled={!selected.length}
                            onClick={() => act('eject', { ids: selected })}
                          >
                            Take out
                          </Button>
                        </Stack.Item>
                        <Stack.Item>
                          <Button
                            icon="trash"
                            disabled={!selectedEmpty}
                            onClick={() => act('forget', { ids: selected })}
                          >
                            Forget empty
                          </Button>
                        </Stack.Item>
                      </Stack>
                    ) : null}
                    <div
                      style={{ userSelect: 'none' }}
                      onPointerMove={onListPointerMove}
                      onPointerUp={(event) => endDrag(event, true)}
                      onPointerCancel={(event) => endDrag(event, false)}
                      onLostPointerCapture={(event) => endDrag(event, false)}
                    >
                      {visible.length === 0 ? (
                        <NoticeBox>
                          {listings.length ? 'Nothing matches.' : 'No stock.'}
                        </NoticeBox>
                      ) : null}
                      {visible.map((listing) => (
                        <StockRow
                          key={listing.id}
                          listing={listing}
                          selected={selectedSet.has(listing.id)}
                          onPointerDown={(event) =>
                            onRowPointerDown(event, listing.id)
                          }
                          onClick={(ctrl, shift) =>
                            selection.onRowClick(listing.id, ctrl, shift)
                          }
                        />
                      ))}
                    </div>
                  </Section>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};

type CategoryRowProps = {
  id: string;
  name: string;
  active: boolean;
  hovered: boolean;
  onClick: () => void;
};

const CategoryRow = (props: CategoryRowProps) => {
  const { id, name, active, hovered, onClick } = props;
  return (
    <div data-category={id}>
      <Button
        fluid
        selected={active}
        color={hovered ? 'good' : undefined}
        onClick={onClick}
      >
        {name}
      </Button>
    </div>
  );
};

type CategoryToolsProps = {
  id: string;
  index: number;
  renaming: boolean;
  renameText: string;
  setRenameText: (text: string) => void;
  startRename: () => void;
  stopRename: () => void;
};

const CategoryTools = (props: CategoryToolsProps) => {
  const { act } = useBackend<Data>();
  const {
    id,
    index,
    renaming,
    renameText,
    setRenameText,
    startRename,
    stopRename,
  } = props;
  if (renaming) {
    return (
      <Stack>
        <Stack.Item grow>
          <Input
            fluid
            autoFocus
            maxLength={23}
            value={renameText}
            onChange={setRenameText}
            onEnter={() => {
              act('rename_category', { id, name: renameText });
              stopRename();
            }}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="check"
            onClick={() => {
              act('rename_category', { id, name: renameText });
              stopRename();
            }}
          />
        </Stack.Item>
      </Stack>
    );
  }
  return (
    <Stack>
      <Stack.Item>
        <Button icon="pen" tooltip="Rename" onClick={startRename} />
      </Stack.Item>
      <Stack.Item>
        <Button
          icon="arrow-up"
          tooltip="Move up"
          disabled={index <= 1}
          onClick={() => act('move_category', { id, index: index - 1 })}
        />
      </Stack.Item>
      <Stack.Item>
        <Button
          icon="arrow-down"
          tooltip="Move down"
          onClick={() => act('move_category', { id, index: index + 1 })}
        />
      </Stack.Item>
      <Stack.Item>
        <Button.Confirm
          icon="trash"
          tooltip="Delete"
          onClick={() => act('delete_category', { id })}
        />
      </Stack.Item>
    </Stack>
  );
};

type StockRowProps = {
  listing: Listing;
  selected: boolean;
  onPointerDown: (event: ReactPointerEvent<HTMLDivElement>) => void;
  onClick: (ctrl: boolean, shift: boolean) => void;
};

const StockRow = (props: StockRowProps) => {
  const { listing, selected, onPointerDown, onClick } = props;
  const empty = listing.count === 0;
  return (
    <div
      onPointerDown={onPointerDown}
      onClick={(event) => onClick(event.ctrlKey, event.shiftKey)}
      style={{
        cursor: 'pointer',
        padding: '2px 4px',
        marginBottom: '2px',
        borderRadius: '2px',
        background: selected
          ? 'rgba(80, 140, 220, 0.35)'
          : 'rgba(255, 255, 255, 0.04)',
        opacity: empty ? 0.55 : 1,
      }}
    >
      <Stack align="center">
        <Stack.Item>
          <DmIcon
            icon={listing.icon}
            icon_state={listing.icon_state}
            width="32px"
            height="32px"
            fallback={<Icon name="box" size={1.5} />}
          />
        </Stack.Item>
        <Stack.Item grow>{listing.name}</Stack.Item>
        <Stack.Item width="110px" color="label">
          {empty ? 'Empty' : listing.units}
        </Stack.Item>
        <Stack.Item width="120px" textAlign="right">
          {listing.price > 0 ? (
            <Box color="good">
              {listing.price} cr{listing.per_unit ? ' each' : ''}
            </Box>
          ) : (
            <Box color="average">Not for sale</Box>
          )}
        </Stack.Item>
      </Stack>
    </div>
  );
};

const SalesList = (props: { sales: Sale[] }) => {
  const { sales } = props;
  return (
    <Section fill scrollable>
      {sales.length === 0 ? <NoticeBox>No sales yet.</NoticeBox> : null}
      {sales.map((sale, index) => (
        <Stack key={index} mb={0.5}>
          <Stack.Item width="50px" color="label">
            {sale.when}
          </Stack.Item>
          <Stack.Item grow>
            {sale.buyer}: {sale.qty}x {sale.name}
          </Stack.Item>
          <Stack.Item textAlign="right">
            {sale.taken ? (
              <Box color="average">Taken</Box>
            ) : (
              <Box color="good">{sale.total} cr</Box>
            )}
          </Stack.Item>
        </Stack>
      ))}
    </Section>
  );
};
