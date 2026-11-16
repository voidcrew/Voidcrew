/**
 * Sound for the dock terminal, played in the page so a sound never costs a round trip.
 *
 * Web Audio: each clip is fetched from the terminal's assets and decoded once, and every play
 * starts a fresh source, so plays never cut each other off or get dropped. Clips are named by
 * their asset name (lobby_assets.dm), e.g. 'lt_key1.ogg'.
 *
 *   preload(['lt_boot_seq.ogg', ...])        fetch and decode ahead of time
 *   play('lt_press.ogg', { gain: 0.3 })      now
 *   play('lt_boot_tick.ogg', { when: 0.25, rate: 1.2 })   a quarter second from now, pitched up
 *
 * Everything here is a quiet no-op when sound is not available: no Web Audio, a clip that did
 * not arrive, or a browser that will not start audio before the player has pressed something
 * (`audioState()` says which). Nothing throws. A clip that is not loaded yet is dropped and
 * starts loading, so `preload` whatever a screen is about to need.
 */
import { resolveAsset } from 'tgui/assets';

export type PlayOpts = {
  /** Seconds from now to start. Default: now. */
  when?: number;
  /** Playback rate, which also shifts the pitch. Default 1. */
  rate?: number;
  /** Linear volume. Default 1. */
  gain?: number;
  /** Seconds into the clip to start from. Default 0. */
  offset?: number;
  /** Stop earlier plays of this clip first, like restarting it. */
  solo?: boolean;
};

export type AudioState = 'running' | 'suspended' | 'none';

/** A clip is tried this many times, this far apart: asset URLs can arrive after the first render. */
const LOAD_TRIES = 14;
const LOAD_RETRY_MS = 700;
/** A play asked for while a key or click is still starting the audio is kept this long, then dropped as stale. */
const RESUME_GRACE_MS = 200;

type AudioCtor = typeof AudioContext;

let ctx: AudioContext | null | undefined;
/** Every sound passes through this on its way out. */
let master: GainNode | null = null;
let masterGain = 1;
/** The last attempt to start a suspended context, and when it was made. */
let waking: Promise<unknown> | null = null;
let wokeAt = 0;
const buffers = new Map<string, AudioBuffer>();
const loads = new Map<string, Promise<boolean>>();
const live = new Map<AudioBufferSourceNode, string>();

const noop = () => undefined;

function context(): AudioContext | null {
  if (ctx !== undefined) {
    return ctx;
  }
  ctx = null;
  try {
    const Ctor: AudioCtor | undefined =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext?: AudioCtor })
        .webkitAudioContext;
    if (Ctor) {
      ctx = new Ctor();
      master = ctx.createGain();
      master.gain.value = masterGain;
      master.connect(ctx.destination);
    }
  } catch {
    ctx = null;
    master = null;
  }
  return ctx;
}

/** Scales every sound, playing or still to come. 1 leaves each clip at the level it was made for. */
export function setMasterGain(gain: number) {
  masterGain = Math.max(0, gain);
  if (master) {
    master.gain.value = masterGain;
  }
}

/** Asks a suspended context to start. Browsers only allow it after a key or click. */
function wake() {
  const c = ctx;
  if (c && c.state === 'suspended') {
    wokeAt = Date.now();
    waking = c.resume().catch(noop);
  }
}

if (typeof window !== 'undefined') {
  window.addEventListener('pointerdown', wake, true);
  window.addEventListener('keydown', wake, true);
}

/** running: sound plays. suspended: waiting for the player's first key or click. none: no sound. */
export function audioState(): AudioState {
  const c = context();
  if (!c || c.state === 'closed') {
    return 'none';
  }
  return c.state === 'running' ? 'running' : 'suspended';
}

function fetchClip(
  id: string,
  c: AudioContext,
  left: number,
): Promise<boolean> {
  return fetch(resolveAsset(id))
    .then((response) => {
      if (!response.ok) {
        throw new Error(`${id}: ${response.status}`);
      }
      return response.arrayBuffer();
    })
    .then((bytes) => c.decodeAudioData(bytes))
    .then((buffer) => {
      buffers.set(id, buffer);
      return true;
    })
    .catch(() =>
      left > 1
        ? new Promise<boolean>((resolve) =>
            setTimeout(
              () => resolve(fetchClip(id, c, left - 1)),
              LOAD_RETRY_MS,
            ),
          )
        : false,
    );
}

function load(id: string): Promise<boolean> {
  if (buffers.has(id)) {
    return Promise.resolve(true);
  }
  const c = context();
  if (!c) {
    return Promise.resolve(false);
  }
  let pending = loads.get(id);
  if (!pending) {
    pending = fetchClip(id, c, LOAD_TRIES).then((ok) => {
      loads.delete(id); // a failed clip is tried again the next time it is wanted
      return ok;
    });
    loads.set(id, pending);
  }
  return pending;
}

/** Fetches and decodes clips ahead of time. Resolves TRUE when every one is ready to play. */
export function preload(ids: readonly string[]): Promise<boolean> {
  wake();
  return Promise.all(ids.map(load)).then((all) => all.every(Boolean));
}

export function isLoaded(id: string): boolean {
  return buffers.has(id);
}

/** Drops decoded clips that will not be played again (the start-up sounds). */
export function unload(ids: readonly string[]) {
  for (const id of ids) {
    buffers.delete(id);
  }
}

function start(
  c: AudioContext,
  id: string,
  buffer: AudioBuffer,
  opts: PlayOpts,
) {
  if (opts.solo) {
    stop(id);
  }
  const source = c.createBufferSource();
  const gain = c.createGain();
  source.buffer = buffer;
  source.playbackRate.value = opts.rate || 1;
  gain.gain.value = opts.gain ?? 1;
  source.connect(gain);
  gain.connect(master || c.destination);
  live.set(source, id);
  source.onended = () => {
    live.delete(source);
    source.disconnect();
    gain.disconnect();
  };
  source.start(
    c.currentTime + Math.max(0, opts.when || 0),
    Math.max(0, opts.offset || 0),
  );
}

/**
 * Plays a clip. Returns TRUE when it was started or scheduled, FALSE when it was dropped
 * (not loaded yet, in which case it starts loading for next time; or no sound available).
 */
export function play(id: string, opts: PlayOpts = {}): boolean {
  try {
    const c = context();
    if (!c) {
      return false;
    }
    const buffer = buffers.get(id);
    if (!buffer) {
      load(id).catch(noop);
      return false;
    }
    if (c.state === 'running') {
      start(c, id, buffer, opts);
      return true;
    }
    // Suspended. Scheduling on a stopped clock would play the sound whenever the clock starts,
    // so the sound is dropped, unless a key or click is starting the audio this very moment.
    const asked = Date.now();
    if (waking && asked - wokeAt < RESUME_GRACE_MS) {
      waking
        .then(() => {
          if (c.state === 'running' && Date.now() - asked < RESUME_GRACE_MS) {
            start(c, id, buffer, opts);
          }
        })
        .catch(noop);
    }
    return false;
  } catch {
    return false;
  }
}

/** Stops every sound still playing or scheduled; with an id, only that clip. */
export function stop(id?: string) {
  for (const [source, name] of Array.from(live)) {
    if (id !== undefined && name !== id) {
      continue;
    }
    live.delete(source);
    try {
      source.onended = null;
      source.stop();
      source.disconnect();
    } catch {
      // Already stopped.
    }
  }
}
