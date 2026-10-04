"""Lecteur minimal de FBX binaire (7.x) : arbre de noeuds + objets/connexions. Sans dépendance (zlib, struct, numpy)."""
import struct, zlib
import numpy as np

class Node:
    __slots__ = ("name", "props", "children")
    def __init__(self, name): self.name = name; self.props = []; self.children = []
    def get(self, n):
        for c in self.children:
            if c.name == n: return c
        return None
    def all(self, n): return [c for c in self.children if c.name == n]

_ARR = {b'f': 'f4', b'd': 'f8', b'l': 'i8', b'i': 'i4', b'b': 'u1'}

def parse(path):
    d = open(path, 'rb').read()
    assert d[:20] == b'Kaydara FBX Binary  ', "pas un FBX binaire"
    ver, = struct.unpack('<I', d[23:27])
    big = ver >= 7500
    hdr = 25 if big else 13
    root = Node('root')
    def read_node(pos):
        if big: end, npr, plen, nlen = struct.unpack('<QQQB', d[pos:pos+25]); p = pos + 25
        else: end, npr, plen, nlen = struct.unpack('<IIIB', d[pos:pos+13]); p = pos + 13
        if end == 0: return None, pos + hdr
        n = Node(d[p:p+nlen].decode('latin1')); p += nlen
        for _ in range(npr):
            t = d[p:p+1]; p += 1
            if t == b'Y': v, = struct.unpack('<h', d[p:p+2]); p += 2
            elif t == b'C': v = d[p]; p += 1
            elif t == b'I': v, = struct.unpack('<i', d[p:p+4]); p += 4
            elif t == b'F': v, = struct.unpack('<f', d[p:p+4]); p += 4
            elif t == b'D': v, = struct.unpack('<d', d[p:p+8]); p += 8
            elif t == b'L': v, = struct.unpack('<q', d[p:p+8]); p += 8
            elif t in _ARR:
                al, enc, cl = struct.unpack('<III', d[p:p+12]); p += 12
                raw = d[p:p+cl]; p += cl
                if enc == 1: raw = zlib.decompress(raw)
                v = np.frombuffer(raw, dtype=_ARR[t])[:al]
            elif t == b'S':
                l, = struct.unpack('<I', d[p:p+4]); p += 4; v = d[p:p+l]; p += l
                v = v.decode('utf8', 'replace')
            elif t == b'R':
                l, = struct.unpack('<I', d[p:p+4]); p += 4; v = bytes(d[p:p+l]); p += l
            else: raise ValueError("type %r" % t)
            n.props.append(v)
        while p < end:
            c, p = read_node(p)
            if c is None: break
            n.children.append(c)
        return n, end
    pos = 27
    while pos < len(d) - hdr:
        n, pos = read_node(pos)
        if n is None: break
        root.children.append(n)
    return root

def clean(name):  # "Model::mixamorig:Hips" ou "mixamorig:Hips\x00\x01Model"
    return name.split('\x00')[0]

class Scene:
    def __init__(self, path):
        self.root = parse(path)
        obj = self.root.get('Objects')
        self.objs = {}      # id -> (cls, name, node)
        for n in obj.children:
            if not n.props: continue
            self.objs[n.props[0]] = (n.name, clean(n.props[1]) if len(n.props) > 1 else '', n)
        self.conn = []      # (type, child, parent, prop)
        for c in self.root.get('Connections').children:
            self.conn.append((c.props[0], c.props[1], c.props[2], c.props[3] if len(c.props) > 3 else None))
        self.parents = {}; self.kids = {}
        for t, ch, pa, pr in self.conn:
            self.parents.setdefault(ch, []).append((pa, pr)); self.kids.setdefault(pa, []).append((ch, pr))
        gs = self.root.get('GlobalSettings')
        self.unit_scale = 1.0
        if gs:
            for p in gs.get('Properties70').children:
                if p.props and p.props[0] == 'UnitScaleFactor': self.unit_scale = float(p.props[4])
    def of(self, cls): return [(i, v[1], v[2]) for i, v in self.objs.items() if v[0] == cls]
