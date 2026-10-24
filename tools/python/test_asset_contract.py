"""Checks bind/skin invariants independently of the Android renderer."""
import math
import sys
import struct
import unittest
from pathlib import Path
from types import SimpleNamespace
from generate_dev_rig import BONES, generate
from inspect_glb import inspect
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'linux'))
from mimic_tracker import hand_points


class WorkerHandAssociation(unittest.TestCase):
    def test_hand_landmarks_are_attached_to_nearest_pose_wrist(self):
        def landmark(x, y, z=0, visibility=1):
            return SimpleNamespace(x=x, y=y, z=z, visibility=visibility)
        pose=[landmark(.5,.5) for _ in range(33)]
        pose[15]=landmark(.25,.5)
        pose[16]=landmark(.75,.5)
        left=[landmark(.25+i*.001,.5) for i in range(21)]
        right=[landmark(.75-i*.001,.5) for i in range(21)]
        result=SimpleNamespace(
            hand_landmarks=[right,left],
            hand_world_landmarks=[[landmark(-i*.01,0,0) for i in range(21)],
                                  [landmark(i*.01,0,0) for i in range(21)]],
        )
        hands=hand_points(result,pose)
        self.assertEqual(len(hands['leftHandWorld']),21)
        self.assertEqual(len(hands['rightHandWorld']),21)
        self.assertGreater(hands['leftHandWorld'][1]['x'],0)
        self.assertLess(hands['rightHandWorld'][1]['x'],0)


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
        self.assertEqual(len(report['joints']),42)
        self.assertEqual(report['joints'][3]['parent'],2)
        self.assertIn('LeftIndex3',[joint['name'] for joint in report['joints']])


if __name__=='__main__':
    unittest.main()
