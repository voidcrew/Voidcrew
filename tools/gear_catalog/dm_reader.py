"""A small reader for DM source. No BYOND, compiler or running world needed.

Follows #include lines from tgstation.dme in include order, merges repeated type declarations, follows parent_type
and path ancestors, and resolves each var to its last declaration. Defines, time units, arithmetic, strings, type paths
and lists are evaluated. It doesn't run proc bodies or preprocessor branches: anything decided at runtime stays an
expression (an Expr), never a guessed number.
"""
from __future__ import annotations

import ast
import collections
import functools
import json
import re
from dataclasses import dataclass
from pathlib import Path

@dataclass
class Decl:
    raw: str
    source: str

class Expr(str):
    pass

@functools.lru_cache(None)
def clean_comments(text):
    # Preserve offsets/newlines, quoted strings, and nested block comments.
    out = []; i = 0; block = 0; quote = None
    while i < len(text):
        c = text[i]; pair = text[i:i+2]
        if block:
            if pair == '/*': block += 1; out.extend('  '); i += 2; continue
            if pair == '*/': block -= 1; out.extend('  '); i += 2; continue
            out.append('\n' if c == '\n' else ' '); i += 1; continue
        if quote:
            out.append(c)
            if c == '\\' and i+1 < len(text): out.append(text[i+1]); i += 2; continue
            if c == quote: quote = None
            i += 1; continue
        if pair == '/*': block = 1; out.extend('  '); i += 2; continue
        if pair == '//':
            j = text.find('\n', i)
            if j < 0: j = len(text)
            out.extend(' ' * (j-i)); i = j; continue
        if c in '\"\'': quote = c
        out.append(c); i += 1
    return ''.join(out)

def split_top(s, sep=','):
    result = []; start = 0; depth = 0; quote = None; escaped = False
    for i,c in enumerate(s):
        if quote:
            if escaped: escaped = False
            elif c == '\\': escaped = True
            elif c == quote: quote = None
        elif c in '\"\'': quote = c
        elif c in '([{': depth += 1
        elif c in ')]}': depth -= 1
        elif c == sep and depth == 0:
            result.append(s[start:i].strip()); start = i+1
    if s[start:].strip(): result.append(s[start:].strip())
    return result

def balance(s):
    depth = 0; quote = None; escaped = False
    for c in s:
        if quote:
            if escaped: escaped = False
            elif c == '\\': escaped = True
            elif c == quote: quote = None
        elif c in '\"\'': quote = c
        elif c in '({': depth += 1
        elif c in ')}': depth -= 1
    return depth > 0 or quote is not None

class DM:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.node_ops = collections.defaultdict(list)  # research node design_ids updates, replayed by node_designs
        self.types = collections.defaultdict(dict)
        self.headers = collections.defaultdict(list)
        self.procs = collections.defaultdict(list)
        self.defines = {'TRUE':'1','FALSE':'0','INFINITY':'1e31','SECONDS':'10','MINUTES':'600','HOURS':'36000'}
        self.texts = {}; self.files = []; self._cache = {}
        self.scan_includes(self.root / 'tgstation.dme', set())

    def scan_includes(self, path, seen):
        if not path.exists() or path in seen: return
        seen.add(path)
        text = path.read_text(encoding='utf-8-sig', errors='replace')
        rel = path.relative_to(self.root).as_posix()
        self.texts[rel] = text
        if path.suffix == '.dm':
            self.files.append(rel); self.parse(rel, text); self.parse_node_ops(rel, text)
        for m in re.finditer(r'^\s*#include\s+"([^"]+)"', text, re.M):
            child = path.parent / m[1].replace('\\','/')
            if child.suffix in ('.dm','.dme'): self.scan_includes(child.resolve(), seen)

    def parse(self, file, text):
        lines = clean_comments(text).splitlines()
        context = []; proc = None; proc_lines = []; proc_source = None
        def save_proc():
            if proc: self.procs[proc].append((proc_source, '\n'.join(proc_lines)))
        i = 0
        while i < len(lines):
            number = i+1; line = lines[i]; i += 1
            stripped = line.strip()
            if not stripped: continue
            if stripped.startswith('#'):
                m = re.match(r'#define\s+(\w+)\s+(.+)', stripped)
                if m: self.defines[m[1]] = m[2].strip()
                continue
            indent = len(line) - len(line.lstrip('\t')) if line.startswith('\t') else (len(line)-len(line.lstrip()))//4
            if proc and (indent > 0 or not stripped.startswith('/')):
                proc_lines.append(line); continue
            if proc: save_proc(); proc = None; proc_lines = []
            # Full proc declarations, including inherited proc overrides.
            if indent == 0 and stripped.startswith('/') and '(' in stripped.split('=')[0]:
                proc = stripped.split('(',1)[0].replace('/proc/','/'); proc_source = f'{file}:{number}'
                proc_lines = [line]; context = []; continue
            if indent == 0 and stripped.startswith('/'):
                context = []
            while context and context[-1][0] >= indent: context.pop()
            # A declaration/override, including var/list/ and typed vars.
            assignment = re.match(r'(.+?)\s*(?<![!<>=])=(?!=)\s*(.*)$', stripped)
            if assignment:
                lhs, raw = assignment.groups()
                while balance(raw) and i < len(lines): raw += '\n' + lines[i].strip(); i += 1
                if lhs.startswith('/'):
                    path, key = lhs.rsplit('/',1)
                elif context:
                    path = context[-1][1]; key = lhs.split('/')[-1]
                else: continue
                if not re.fullmatch(r'\w+', key): continue
                self.types[path][key] = Decl(raw.strip(), f'{file}:{number}')
                continue
            if '(' in stripped or stripped.startswith(('return','set ','if','else')): continue
            if stripped.startswith(('var/','var ')): continue
            if re.fullmatch(r'/?[\w/]+', stripped):
                if stripped.startswith('/'): path = stripped.rstrip('/')
                elif context: path = context[-1][1] + '/' + stripped
                else: continue
                context.append((indent,path)); self.headers[path].append(f'{file}:{number}')
        save_proc()

    def parent(self,path):
        explicit = self.types.get(path,{}).get('parent_type')
        return explicit.raw if explicit else path.rsplit('/',1)[0]

    def field(self,path,key):
        visited = set()
        while path and path not in visited:
            visited.add(path)
            if key in self.types.get(path,{}): return self.types[path][key]
            path = self.parent(path)
        return Decl('null','')

    def val(self,path,key): return self.eval(self.field(path,key).raw)

    def is_a(self,path,base):
        seen = set()
        while path and path not in seen:
            if path == base: return True
            seen.add(path); path = self.parent(path)
        return False

    def eval(self,s,seen=frozenset()):
        s = s.strip().rstrip(';').strip()
        if s in ('SECONDS','MINUTES','HOURS'): return {'SECONDS':10,'MINUTES':600,'HOURS':36000}[s]
        if s in ('null',''): return None
        if s.startswith('"') and s.endswith('"'):
            return re.sub(r'\\(improper |proper )','',s[1:-1]).replace('\\"','"').replace('\\n','\n')
        if re.fullmatch(r'/[\w/]+',s): return s
        if s.startswith('list(') and s.endswith(')'):
            out = []
            for part in split_top(s[5:-1]):
                sides = split_top(part,'=')
                if len(sides)==2: out.append((self.eval(sides[0],seen),self.eval(sides[1],seen)))
                else: out.append(self.eval(part,seen))
            return out
        if s in self.defines and s not in seen: return self.eval(self.defines[s],seen|{s})
        try:
            # DM postfix time units and numeric define arithmetic.
            sub = re.sub(r'(\d|\))\s+(SECONDS|MINUTES|HOURS)\b',r'\1 * \2',s)
            for token in set(re.findall(r'\b[A-Z][A-Z_0-9]*\b',sub)):
                v = self.eval(token,seen|{s}) if token != s else None
                if isinstance(v,(int,float)): sub = re.sub(r'\b'+token+r'\b',repr(v),sub)
            node = ast.parse(sub,mode='eval')
            if all(isinstance(n,(ast.Expression,ast.Constant,ast.BinOp,ast.UnaryOp,ast.Add,ast.Sub,ast.Mult,ast.Div,ast.FloorDiv,ast.Mod,ast.Pow,ast.USub,ast.UAdd,ast.BitOr,ast.BitAnd,ast.LShift,ast.RShift)) for n in ast.walk(node)):
                value = eval(compile(node,'<DM constant>','eval'),{'__builtins__':{}},{})
                return int(value) if isinstance(value,float) and value.is_integer() else value
        except (SyntaxError,NameError,ValueError,TypeError,ZeroDivisionError,OverflowError): pass
        return Expr(s)

    def paths(self,base,fixtures=False):
        return sorted(p for p in self.headers if self.is_a(p,base) and (fixtures or '/unit_tests/' not in self.loc(p)))
    def loc(self,path): return self.headers.get(path,[''])[0]
    def cite(self,file,needle):
        lines = self.texts.get(file)
        if lines is None: lines = (self.root/file).read_text(encoding='utf-8',errors='replace')
        for i,line in enumerate(lines.splitlines(),1):
            if needle in line: return f'{file}:{i}'
        raise ValueError((file,needle))
    def proc(self,path): return '\n'.join(t for _,t in self.procs.get(path.replace('/proc/','/'),[]))

    def parse_node_ops(self, file, text):
        """List updates to design_ids, which research node patches rely on."""
        if '/datum/techweb_node' not in text:
            return
        lines = clean_comments(text).splitlines()
        owner = None
        i = 0
        while i < len(lines):
            line = lines[i]
            line_no = i + 1
            i += 1
            if line.startswith('/'):
                m = re.fullmatch(r'(/datum/techweb_node[\w/]*?)(?:/(?:New|Initialize)\([^)]*\))?', line.strip())
                owner = m[1] if m else None
            if not owner:
                continue
            m = re.match(r'\s+design_ids\s*(\+=|-=|\|=|=)\s*(.+)', line)
            if not m:
                continue
            raw = m[2]
            while balance(raw) and i < len(lines):
                raw += '\n' + lines[i].strip()
                i += 1
            self.node_ops[owner].append((m[1], raw, f'{file}:{line_no}'))

    @functools.lru_cache(None)
    def node_designs(self, path):
        inherited = list(self.node_designs(self.parent(path))) if path and path != '/datum/techweb_node' else []
        for op, raw, source in self.node_ops.get(path, []):
            v = self.eval(raw)
            values = v if isinstance(v, list) else [v]
            if op == '=':
                inherited = list(values)
            elif op in ('+=', '|='):
                inherited += [x for x in values if x not in inherited]
            elif op == '-=':
                inherited = [x for x in inherited if x not in values]
        return tuple(inherited)


def proc_chain(dm,path,method):
    result=[]; seen=set()
    while path and path not in seen:
        seen.add(path)
        result.extend(dm.procs.get(path+'/'+method,[]))
        path=dm.parent(path)
    return result


def inherited_proc(dm,path,method):
    seen=set()
    while path and path not in seen:
        seen.add(path)
        if path+'/'+method in dm.procs: return dm.procs[path+'/'+method]
        path=dm.parent(path)
    return []

def paths_in(s): return re.findall(r'/(?:obj|mob|datum)/[\w/]+',s)


def decode(s):
    try:
        return json.loads(s)
    except (TypeError, ValueError):
        return s


def number(x):
    v = decode(x) if isinstance(x, str) else x
    return v if isinstance(v, (int, float)) else None


def assoc(v):
    if isinstance(v, dict):
        return v
    if not isinstance(v, list):
        return {}
    return {x[0]: x[1] for x in v if isinstance(x, (tuple, list)) and len(x) == 2}


def paths(v):
    if isinstance(v, str):
        return re.findall(r'/(?:obj|mob|datum)/[\w/]+', v)
    if isinstance(v, dict):
        return [p for k, val in v.items() for p in paths(k) + paths(val)]
    if isinstance(v, (list, tuple)):
        return [p for x in v for p in paths(x)]
    return []


def rounded(v):
    return round(v, 6) if isinstance(v, float) else v
