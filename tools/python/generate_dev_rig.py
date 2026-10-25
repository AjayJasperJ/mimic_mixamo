"""Generate the original Mimic block humanoid (CC0), with genuine glTF skinning.
No third-party model, texture, or animation is used. Standard library only.
"""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BONES = [
    ('Hips', None, (0, .9, 0)),
    ('Chest', 0, (0, .35, 0)),
    ('LeftUpperArm', 1, (.20, .20, 0)),
    ('LeftForeArm', 2, (.40, 0, 0)),
    ('RightUpperArm', 1, (-.20, .20, 0)),
    ('RightForeArm', 4, (-.40, 0, 0)),
    ('LeftThigh', 0, (.12, -.05, 0)),
    ('LeftShin', 6, (0, -.42, 0)),
    ('RightThigh', 0, (-.12, -.05, 0)),
    ('RightShin', 8, (0, -.42, 0)),
]
HAND_START = len(BONES)
for side, forearm, sign in [('Left', 3, 1), ('Right', 5, -1)]:
    hand = len(BONES)
    BONES.append((side+'Hand', forearm, (sign*.20, 0, 0)))
    for finger, spread in [('Thumb',-.10), ('Index',-.065), ('Middle',-.02), ('Ring',.025), ('Pinky',.07)]:
        parent = hand
        for segment in range(1, 4):
            name = f'{side}{finger}{segment}'
            # Finger chains extend from the palm along the forearm's local X axis.
            t = (sign*(.045 if segment == 1 else .055), spread if segment == 1 else 0, 0)
            BONES.append((name, parent, t))
            parent = len(BONES)-1


def generate():
    data = bytearray()
    views, accessors = [], []

    def accessor(values, fmt, component, shape, bounds=False):
        while len(data) % 4:
            data.append(0)
        start = len(data)
        for row in values:
            data.extend(struct.pack('<' + fmt, *row))
        views.append({'buffer': 0, 'byteOffset': start, 'byteLength': len(data) - start})
        record = {'bufferView': len(views)-1, 'componentType': component,
                  'count': len(values), 'type': shape}
        if bounds:
            record['min'] = [min(v[i] for v in values) for i in range(len(values[0]))]
            record['max'] = [max(v[i] for v in values) for i in range(len(values[0]))]
        accessors.append(record)
        return len(accessors)-1

    positions, joints, weights, indices = [], [], [], []

    def box(center, extent, bone):
        base = len(positions)
        for x, y, z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                        (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]:
            positions.append(tuple(c + e*s/2 for c,e,s in zip(center,extent,(x,y,z))))
            joints.append((bone,0,0,0))
            weights.append((1,0,0,0))
        for a,b,c in [(0,2,1),(0,3,2),(4,5,6),(4,6,7),(0,1,5),(0,5,4),
                      (3,7,6),(3,6,2),(0,4,7),(0,7,3),(1,2,6),(1,6,5)]:
            indices.extend([(base+a,), (base+b,), (base+c,)])

    box((0,1.20,0), (.36,.48,.20), 1)
    box((0,1.66,0), (.25,.28,.24), 1)
    box((0,.88,0), (.34,.18,.22), 0)
    for sign,upper,fore,thigh,shin in [(1,2,3,6,7),(-1,4,5,8,9)]:
        box((sign*.40,1.45,0), (.39,.12,.12), upper)
        box((sign*.78,1.45,0), (.35,.10,.10), fore)
        box((sign*.12,.64,0), (.14,.40,.16), thigh)
        box((sign*.12,.22,0), (.12,.40,.14), shin)
        box((sign*.12,.035,.06), (.15,.07,.27), shin)
    for side, sign, hand in [('Left',1,HAND_START),('Right',-1,HAND_START+16)]:
        box((sign*.87,1.45,0),(.18,.105,.11),hand)
        for f,spread in enumerate([-.10,-.065,-.02,.025,.07]):
            root=hand+1+f*3
            length=.12 if f==0 else .145-(f-2).__abs__()*.012
            for seg in range(3):
                center_x=sign*(.845+seg*.055+length/6)
                box((center_x,1.45+spread,0),(length/3,.026,.026),root+seg)
    p=accessor(positions,'fff',5126,'VEC3',True)
    j=accessor(joints,'HHHH',5123,'VEC4')
    w=accessor(weights,'ffff',5126,'VEC4')
    ix=accessor(indices,'H',5123,'SCALAR')
    worlds=[]
    nodes=[]
    for name,parent,t in BONES:
        world=tuple(t[i]+(worlds[parent][i] if parent is not None else 0) for i in range(3))
        worlds.append(world)
        nodes.append({'name':name,'translation':list(t)})
    for i,(_,parent,_) in enumerate(BONES):
        if parent is not None:
            nodes[parent].setdefault('children',[]).append(i)
    matrices=[(1,0,0,0, 0,1,0,0, 0,0,1,0, -x,-y,-z,1) for x,y,z in worlds]
    ibm=accessor(matrices,'f'*16,5126,'MAT4')
    nodes.append({'name':'DevelopmentMesh','mesh':0,'skin':0})
    gltf={'asset':{'version':'2.0','generator':'Mimic original CC0 development rig'},
          'scene':0,'scenes':[{'nodes':[0,len(nodes)-1]}], 'nodes':nodes,
          'skins':[{'name':'MimicDevelopmentSkin','joints':list(range(len(BONES))),
                    'skeleton':0,'inverseBindMatrices':ibm}],
          'meshes':[{'primitives':[{'attributes':{'POSITION':p,'JOINTS_0':j,'WEIGHTS_0':w},
                                    'indices':ix,'material':0}]}],
          'materials':[{'name':'Mint','doubleSided':True,
                        'pbrMetallicRoughness':{'baseColorFactor':[.18,.83,.67,1]},
                        'extensions':{'KHR_materials_unlit':{}}}],
          'extensionsUsed':['KHR_materials_unlit'],
          'buffers':[{'byteLength':len(data)}],'bufferViews':views,'accessors':accessors}
    raw=json.dumps(gltf,separators=(',',':')).encode()
    raw+=b' '*((-len(raw))%4)
    data+=b'\0'*((-len(data))%4)
    glb=(struct.pack('<4sII',b'glTF',2,28+len(raw)+len(data))+
         struct.pack('<II',len(raw),0x4e4f534a)+raw+
         struct.pack('<II',len(data),0x004e4942)+data)
    target=ROOT/'app/assets/characters/development_humanoid.glb'
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(glb)
    manifest={'id':'mimic-block-humanoid-v1','kind':'original development placeholder; not Mixamo',
              'source':'tools/python/generate_dev_rig.py','license':'CC0-1.0',
              'sha256':hashlib.sha256(glb).hexdigest(),'triangles':len(indices)//3,
              'units':'meters','up':'+Y','forward':'+Z','restPose':'T-pose',
              'skinCount':1,'animationCount':0,
              'joints':[{'index':i,'name':name,'parent':parent,'translation':t,
                         'rotation':[0,0,0,1],'scale':[1,1,1]}
                        for i,(name,parent,t) in enumerate(BONES)]}
    (ROOT/'docs/asset_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'Generated {target.name}: {len(glb)} bytes, {len(BONES)} joints')
    return gltf, glb


if __name__=='__main__':
    generate()
