"""Checks bind/skin invariants independently of the Android renderer."""
import math
import struct
import unittest
from generate_dev_rig import BONES, generate
from inspect_glb import inspect
from pathlib import Path


class AssetContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.gltf, cls.glb = generate()
        json_length = struct.unpack_from('<I', cls.glb, 12)[0]
        cls.binary = cls.glb[28+json_length:]

    def values(self, accessor_index, fmt):
        acc=self.gltf['accessors'][accessor_index]
        view=self.gltf['bufferViews'][acc['bufferView']]
        offset=view.get('byteOffset',0)+acc.get('byteOffset',0)
        stride=struct.calcsize('<'+fmt)
        return [struct.unpack_from('<'+fmt,self.binary,offset+i*stride) for i in range(acc['count'])]

    def test_weights_are_normalized_and_joint_indices_valid(self):
        primitive=self.gltf['meshes'][0]['primitives'][0]
        weights=self.values(primitive['attributes']['WEIGHTS_0'],'ffff')
        joints=self.values(primitive['attributes']['JOINTS_0'],'HHHH')
        self.assertEqual(len(weights),len(joints))
        for weight,joint in zip(weights,joints):
            self.assertAlmostEqual(sum(weight),1)
            self.assertTrue(all(math.isfinite(x) and x>=0 for x in weight))
            self.assertTrue(all(0<=x<len(BONES) for x in joint))

    def test_inverse_bind_cancels_hierarchy_translation(self):
        matrices=self.values(self.gltf['skins'][0]['inverseBindMatrices'],'f'*16)
        for index,(_,parent,_) in enumerate(BONES):
            chain=[]
            current=index
            while current is not None:
                chain.append(BONES[current][2])
                current=BONES[current][1]
            for axis in range(3):
                self.assertAlmostEqual(sum(t[axis] for t in chain)+matrices[index][12+axis],0,places=6)
            self.assertEqual(matrices[index][15],1)

    def test_indices_and_bounds(self):
        primitive=self.gltf['meshes'][0]['primitives'][0]
        positions=self.values(primitive['attributes']['POSITION'],'fff')
        indices=self.values(primitive['indices'],'H')
        self.assertEqual(len(indices)%3,0)
        self.assertTrue(all(i[0]<len(positions) for i in indices))
        self.assertTrue(all(math.isfinite(c) for p in positions for c in p))
        self.assertGreater(max(p[1] for p in positions),1.7)
        self.assertGreaterEqual(min(p[1] for p in positions),0)

    def test_generated_asset_has_skin_without_animation_and_is_deterministic(self):
        self.assertEqual(generate()[1],self.glb)
        root=Path(__file__).resolve().parents[2]
        report=inspect(root/'app/assets/characters/development_humanoid.glb')
        self.assertEqual(report['skins'],1)
        self.assertEqual(report['animations'],0)
        self.assertEqual(len(report['joints']),10)
        self.assertEqual(report['joints'][3]['parent'],2)


if __name__=='__main__':
    unittest.main()
