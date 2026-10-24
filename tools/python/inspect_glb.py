"""Inspect GLB rig structure without importing Blender or executing asset code."""
import argparse
import json
import struct
from pathlib import Path


def inspect(path):
    data = Path(path).read_bytes()
    if len(data) < 20:
        raise ValueError('Truncated GLB')
    magic, version, length = struct.unpack_from('<4sII', data)
    if magic != b'glTF' or version != 2 or length != len(data):
        raise ValueError('Expected a complete GLB version 2 file')
    offset = 12
    document = None
    while offset < length:
        if offset + 8 > length:
            raise ValueError('Truncated chunk header')
        size, kind = struct.unpack_from('<II', data, offset)
        offset += 8
        if size % 4 or offset + size > length:
            raise ValueError('Invalid chunk size')
        if kind == 0x4E4F534A:
            if document is not None:
                raise ValueError('Duplicate JSON chunk')
            document = json.loads(data[offset:offset + size])
        offset += size
    if document is None:
        raise ValueError('No glTF JSON chunk')
    nodes = document.get('nodes', [])
    parents = {}
    for parent, node in enumerate(nodes):
        for child in node.get('children', []):
            if child < 0 or child >= len(nodes) or child in parents:
                raise ValueError('Invalid node hierarchy')
            parents[child] = parent
    joints = []
    for skin in document.get('skins', []):
        for index in skin.get('joints', []):
            if index < 0 or index >= len(nodes):
                raise ValueError('Invalid skin joint index')
            node = nodes[index]
            joints.append({'index': index, 'name': node.get('name', ''),
                           'parent': parents.get(index),
                           'translation': node.get('translation', [0, 0, 0]),
                           'rotation': node.get('rotation', [0, 0, 0, 1]),
                           'scale': node.get('scale', [1, 1, 1]),
                           'matrix': node.get('matrix')})
    return {'source': str(path), 'skins': len(document.get('skins', [])),
            'animations': len(document.get('animations', [])), 'joints': joints,
            'note': 'Structural inventory only; weights, appearance and renderer behavior require validation.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb')
    args = parser.parse_args()
    print(json.dumps(inspect(args.glb), indent=2))
