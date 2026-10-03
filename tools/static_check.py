#!/usr/bin/env python3
"""Contrôle STATIQUE (pas une compilation GDScript) : tabulations, parenthèses, méthodes d'autoloads et de classes appelées.
Usage : python3 tools/static_check.py   (depuis la racine du projet)"""
import re, glob
root = 'godot_project/'
files = glob.glob(root + 'scripts/**/*.gd', recursive=True)
auto = {}
for l in open(root + 'project.godot'):
    m = re.match(r'(\w+)="\*res://(.+)"', l.strip())
    if m: auto[m.group(1)] = root + m.group(2)
def members(t):
    return (set(re.findall(r'^(?:static )?func (\w+)', t, re.M)) | set(re.findall(r'^(?:@export )?var (\w+)', t, re.M)) |
            set(re.findall(r'^signal (\w+)', t, re.M)) | set(re.findall(r'^const (\w+)', t, re.M)))
am = {n: members(open(f).read()) for n, f in auto.items()}
cm = {}
for f in files:
    t = open(f).read(); m = re.search(r'^class_name (\w+)', t, re.M)
    if m: cm[m.group(1)] = members(t)
bad = 0
for f in files:
    t = open(f).read()
    for i, l in enumerate(t.split('\n'), 1):
        if l.startswith('    '): print('ESPACES', f, i); bad += 1
    for a, b in ['()', '[]', '{}']:
        if t.count(a) != t.count(b): print('ÉQUILIBRE', f, a, t.count(a), t.count(b)); bad += 1
    for m in re.finditer(r'\b(\w+Manager)\.(\w+)', t):
        n, mem = m.groups()
        if n in am and mem not in am[n]: print('AUTOLOAD', f, n + '.' + mem); bad += 1
    for m in re.finditer(r'\b([A-Z]\w+)\.(\w+)\(', t):
        n, mem = m.groups()
        if n in cm and mem not in cm[n] and mem != 'new': print('CLASSE', f, n + '.' + mem); bad += 1
    # v12 : variables qui masquent des fonctions natives (len, tr, ...)
    for i, l in enumerate(t.split('\n'), 1):
        code = l.split('#')[0]
        if re.search(r'\bvar (len|tr|print|str|range|abs|min|max)\b\s*(:=|=|:)', code): print('MASQUE', f, i, code.strip()); bad += 1
        if re.search(r'\bnull\s*\.\s*\w+\(', code): print('NULL', f, i); bad += 1
print('problèmes :', bad, '| fichiers :', len(files))
