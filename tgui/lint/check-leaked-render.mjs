/**
 * Catches values leaking into JSX output through a bare `&&`.
 *
 * tgui interfaces get their data from DM, which has no booleans - `ui_data()`
 * sends 0 and 1, typed on the TS side as `BooleanLike`. React renders 0 as the
 * text "0", so:
 *
 *     {padLinked && diagnosticsUnlocked && <IntegrityBox />}
 *
 * prints a stray 0 on screen whenever the last operand is 0, instead of
 * rendering nothing. It only shows up in the states where the flag is off, so it
 * reliably survives review and lands in the round.
 *
 * Safe forms, all of which produce a real boolean:
 *     {!!value && <X />}        {!value && <X />}
 *     {count > 0 && <X />}      {value === 'x' && <X />}
 *     {value ? <X /> : null}
 *
 * Usage:  bun tgui/lint/check-leaked-render.mjs [files...]
 * With no arguments it scans every .tsx/.jsx file under tgui/packages.
 * Exits 1 if anything is found.
 */

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const ROOT = new URL('../..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const SCAN_ROOT = join(ROOT, 'tgui', 'packages');

/** Splits on top-level `||` / `&&`, ignoring anything inside brackets. */
function splitTopLevel(text) {
  const parts = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === '(' || char === '[' || char === '{') depth++;
    else if (char === ')' || char === ']' || char === '}') depth--;
    else if (
      depth === 0 &&
      (char === '|' || char === '&') &&
      text[i + 1] === char
    ) {
      parts.push(text.slice(start, i));
      i++;
      start = i + 1;
    }
  }
  parts.push(text.slice(start));
  return parts;
}

/** An operand is safe when it is already a genuine boolean. */
function isSafeOperand(text) {
  let operand = text.trim();
  if (!operand) return true;

  // Unwrap balanced surrounding parens: `(!!a || !!b)` is as safe as its parts.
  while (operand.startsWith('(') && operand.endsWith(')')) {
    const inner = operand.slice(1, -1);
    let depth = 0;
    let balanced = true;
    for (const char of inner) {
      if (char === '(') depth++;
      else if (char === ')' && --depth < 0) { balanced = false; break; }
    }
    if (!balanced || depth !== 0) break;
    operand = inner.trim();
  }

  // A compound expression is safe only if every branch of it is.
  const parts = splitTopLevel(operand);
  if (parts.length > 1) return parts.every((part) => isSafeOperand(part));

  // Negation and double-negation.
  if (/^!/.test(operand)) return true;
  // Any comparison or equality.
  if (/(===|!==|==|!=|>=|<=|>|<)/.test(operand)) return true;
  // Explicit Boolean() coercion.
  if (/^Boolean\s*\(/.test(operand)) return true;
  // A literal true/false, or a call that reads as a predicate.
  if (/^(true|false)$/.test(operand)) return true;
  // `.length` is a number, so a bare `.length` is genuinely unsafe and
  // deliberately not treated as safe here - `x.length > 0` is caught above.
  return false;
}

/**
 * Grabs the operand immediately left of an `&&`, walking backwards with bracket
 * depth so a call like `Boolean(a)` comes back whole instead of as `a)`.
 */
function extractOperand(before) {
  let depth = 0;
  for (let i = before.length - 1; i >= 0; i--) {
    const char = before[i];
    if (char === ')' || char === ']') {
      depth++;
    } else if (char === '(' || char === '[' || char === '{') {
      if (depth === 0) return before.slice(i + 1);
      depth--;
    } else if (char === '&' && before[i - 1] === '&' && depth === 0) {
      return before.slice(i + 1);
    }
  }
  return before;
}

function collect(dir, out = []) {
  for (const entry of readdirSync(dir)) {
    if (entry === 'node_modules' || entry.startsWith('.')) continue;
    const full = join(dir, entry);
    const info = statSync(full);
    if (info.isDirectory()) collect(full, out);
    else if (/\.(tsx|jsx)$/.test(entry)) out.push(full);
  }
  return out;
}

/**
 * Finds `<operand> && <` where the whole thing sits inside a JSX expression
 * container. Anchoring on `&& <` is what keeps this to render position - a
 * plain `if (a && b)` never has a JSX tag on the right.
 */
function findLeaks(source) {
  const hits = [];
  const lines = source.split(/\r?\n/);

  lines.forEach((line, index) => {
    // Skip comment lines so the examples in this file's own docs don't trip it.
    const trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/*')) {
      return;
    }

    // `&&` immediately followed by a JSX tag, or opening a parenthesised JSX
    // block at end of line. Anchoring on what follows is what keeps this to
    // render position - a plain `if (a && b)` has no JSX tag after the `&&`.
    const pattern = /&&\s*(?:\(\s*)?$|&&\s*(?:\(\s*)?</g;
    let match;
    while ((match = pattern.exec(line)) !== null) {
      const before = line.slice(0, match.index);
      // Require a JSX expression container on this line. Without it this is
      // ordinary boolean logic, not something being rendered.
      if (!before.includes('{')) continue;
      const operand = extractOperand(before);
      if (isSafeOperand(operand)) continue;
      hits.push({ line: index + 1, text: trimmed, operand: operand.trim() });
    }
  });

  return hits;
}

const args = process.argv.slice(2);
const files = args.length ? args : collect(SCAN_ROOT);

let total = 0;
for (const file of files) {
  let source;
  try {
    source = readFileSync(file, 'utf8');
  } catch {
    continue;
  }
  const hits = findLeaks(source);
  if (!hits.length) continue;
  const shown = relative(ROOT, file).replace(/\\/g, '/');
  for (const hit of hits) {
    console.error(`${shown}:${hit.line}  value leaks into render: \`${hit.operand} && <...>\``);
    console.error(`    ${hit.text}`);
    total++;
  }
}

if (total) {
  console.error(
    `\n${total} leaked render${total === 1 ? '' : 's'}. ` +
      'DM sends 0/1, and React prints 0 as text. ' +
      'Wrap the operand in `!!`, compare it, or use a ternary.',
  );
  process.exit(1);
}
console.log(`check-leaked-render: ${files.length} file(s) clean`);
