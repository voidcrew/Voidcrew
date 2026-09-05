import { afterEach, describe, expect, it, mock, spyOn } from 'bun:test';

mock.module('./renderer', () => ({
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
      'Original & text',
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
