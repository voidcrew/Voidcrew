import { afterEach, describe, expect, it, mock, spyOn } from 'bun:test';

mock.module('../../tgui-panel/chat/renderer', () => ({
  chatRenderer: {
    events: { on: () => {} },
    messages: [],
    highlightParsers: [],
  },
}));
mock.module('tgui/logging', () => ({
  createLogger: () => ({ debug: () => {}, error: () => {} }),
}));

const { chatTranslation } = await import('./translation');

function addLine(linkify = true) {
  const line = document.createElement('div');
  line.innerHTML = `<span class="ooc"><em>OOC: Player:</em>
    <span class="message ${linkify ? 'linkify' : ''}">
      <span class="translatable tsl-pending-text" data-tsl-id="tsl-test">Original &amp; text</span><span class="tsl-pending" data-tsl-for="tsl-test"></span>
    </span></span>`;
  document.body.appendChild(line);
  return line;
}

afterEach(() => {
  document.body.replaceChildren();
  mock.restore();
});

describe('OOC translation rendering', () => {
  it('keeps the OOC author and restores clickable URLs after the animation', () => {
    const line = addLine();
    let finishFrame: FrameRequestCallback | undefined;
    spyOn(globalThis, 'requestAnimationFrame').mockImplementation(
      (callback) => {
        finishFrame = callback;
        return 1;
      },
    );

    chatTranslation({
      id: 'tsl-test',
      status: 'done',
      text: 'Read https://example.com/help?a=1&b=2',
      duration: 500,
    });
    finishFrame?.(performance.now() + 1000);

    expect(line.querySelector('em')?.textContent).toBe('OOC: Player:');
    expect(line.querySelector('a')?.getAttribute('href')).toBe(
      'https://example.com/help?a=1&b=2',
    );
    expect(line.querySelector('.tsl-translated')?.getAttribute('title')).toBe(
      'Automatically translated.\nOriginal: Original & text',
    );
    expect(line.querySelector('.tsl-pending')).toBeNull();
  });

  it('linkifies immediate translations and keeps HTML-looking text literal', () => {
    const line = addLine();
    const text = '<img src=x onerror=alert(1)> & "quote" https://example.com';
    chatTranslation({ id: 'tsl-test', status: 'done', text, duration: 0 });

    expect(line.querySelector('.translatable')?.textContent).toBe(text);
    expect(line.querySelector('img')).toBeNull();
    expect(line.querySelector('a')?.textContent).toBe('https://example.com');
    expect(line.querySelector('.tsl-translated')?.getAttribute('title')).toBe(
      'Automatically translated.\nOriginal: Original & text',
    );
  });

  it('does not add links to speech that did not opt into linkification', () => {
    const line = addLine(false);
    chatTranslation({
      id: 'tsl-test',
      status: 'done',
      text: 'https://example.com',
      duration: 0,
    });

    expect(line.querySelector('a')).toBeNull();
  });

  it('leaves the original OOC text visible when translation fails', () => {
    const line = addLine();
    chatTranslation({ id: 'tsl-test', status: 'failed' });

    expect(line.querySelector('.tsl-failed')?.textContent).toBe(
      'Original & text',
    );
    expect(line.querySelector('em')?.textContent).toBe('OOC: Player:');
    expect(line.querySelector('.tsl-pending')).toBeNull();
  });
});

describe('adminhelp translation rendering', () => {
  it('preserves reply, ticket, and original keyword links after translating', () => {
    const line = document.createElement('fieldset');
    line.innerHTML = `<legend><a href="byond://?ahelp=ticket">Ticket #7</a></legend>
      <b><a href="byond://?priv_msg=admin">Administrator</a></b>
      <span class="linkify"><span class="translatable tsl-pending-text" data-tsl-id="ahelp-test">Original report <a href="byond://?adminmoreinfo=player">?</a></span><span class="tsl-pending" data-tsl-for="ahelp-test"></span></span>
      <details><summary>Original</summary>Original report <a href="byond://?adminmoreinfo=player">?</a></details>`;
    document.body.appendChild(line);
    let finishFrame: FrameRequestCallback | undefined;
    spyOn(globalThis, 'requestAnimationFrame').mockImplementation(
      (callback) => {
        finishFrame = callback;
        return 1;
      },
    );

    chatTranslation({
      id: 'ahelp-test',
      status: 'done',
      text: 'Translated report https://example.com/evidence',
      duration: 500,
    });
    finishFrame?.(performance.now() + 1000);

    expect(line.querySelector('legend a')?.getAttribute('href')).toBe(
      'byond://?ahelp=ticket',
    );
    expect(line.querySelector('b a')?.getAttribute('href')).toBe(
      'byond://?priv_msg=admin',
    );
    expect(line.querySelector('details a')?.getAttribute('href')).toBe(
      'byond://?adminmoreinfo=player',
    );
    expect(line.querySelector('details')?.textContent).toBe(
      'OriginalOriginal report ?',
    );
    expect(line.querySelector('.translatable a')?.getAttribute('href')).toBe(
      'https://example.com/evidence',
    );
    expect(line.querySelector('.tsl-pending')).toBeNull();
  });

  it('updates only the addressed reply and leaves failed messages readable', () => {
    const line = document.createElement('div');
    line.innerHTML = `<span class="translatable tsl-pending-text" data-tsl-id="reply-one">First reply</span><span class="tsl-pending" data-tsl-for="reply-one"></span>
      <span class="translatable tsl-pending-text" data-tsl-id="reply-two">Second reply</span><span class="tsl-pending" data-tsl-for="reply-two"></span>`;
    document.body.appendChild(line);

    chatTranslation({
      id: 'reply-one',
      status: 'done',
      text: 'Translated first reply',
      duration: 0,
    });

    expect(line.querySelector('.translatable')?.textContent).toBe(
      'Translated first reply',
    );
    expect(line.querySelector('[data-tsl-id="reply-two"]')?.textContent).toBe(
      'Second reply',
    );

    chatTranslation({ id: 'reply-two', status: 'failed' });

    expect(line.querySelector('.tsl-failed')?.textContent).toBe('Second reply');
    expect(line.querySelector('.tsl-pending')).toBeNull();
  });
});
