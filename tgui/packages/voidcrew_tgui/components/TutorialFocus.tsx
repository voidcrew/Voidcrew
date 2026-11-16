/**
 * Pulses a gold outline around one element while the tutorial checklist points at it.
 *
 * The window's ui_data sends `tutorial_focus` from `tutorial_ui_focus(user, "<window id>")`
 * (voidcrew/modules/tutorials/tutorial_highlights.dm). Wrap each element a step can point
 * at, giving it the focus key from that step's `ui_focus`:
 *
 *   <TutorialFocus id="helm_dock"><button ...>Dock</button></TutorialFocus>
 *
 * It adds the `TutorialFocus` class to its one child and renders nothing of its own, so
 * layout never changes. The child must pass `className` through to its DOM element: plain
 * elements, tgui Button, Tabs.Tab, Table.Row and Box all do; a custom component needs a
 * `className` prop. The outline is drawn inside the element, so a clipping parent can't
 * hide it.
 */
import { Children, cloneElement, isValidElement, type ReactNode } from 'react';

import { useBackend } from '../backend';

type FocusData = { tutorial_focus?: string | null };

type Props = {
  /** The focus key (or keys) this element answers to, e.g. "helm_dock". */
  id: string | string[];
  /** Overrides the window's `tutorial_focus`, for windows that send it under another name. */
  focus?: string | null;
  children: ReactNode;
};

export const TutorialFocus = (props: Props) => {
  const { id, children } = props;
  const { data } = useBackend<FocusData>();
  const focus = props.focus === undefined ? data?.tutorial_focus : props.focus;
  const matches = Array.isArray(id) ? id.includes(focus || '') : focus === id;
  if (!focus || !matches) return <>{children}</>;
  const child = Children.only(children);
  if (!isValidElement<{ className?: string }>(child)) return <>{children}</>;
  const existing = child.props.className;
  return cloneElement(child, {
    className: existing ? `${existing} TutorialFocus` : 'TutorialFocus',
  });
};
