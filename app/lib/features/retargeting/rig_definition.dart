import 'pose_math.dart';

/// Mapping for the generated development asset. Imported character rigs need
/// their own explicit bone-name mapping before they can be driven.
class DevelopmentRig {
  static const id = 'mimic-block-humanoid-v1';
  static final parents = <String, String?>{
    'Hips': null,
    'Chest': 'Hips',
    'LeftUpperArm': 'Chest',
    'LeftForeArm': 'LeftUpperArm',
    'RightUpperArm': 'Chest',
    'RightForeArm': 'RightUpperArm',
    'LeftThigh': 'Hips',
    'LeftShin': 'LeftThigh',
    'RightThigh': 'Hips',
    'RightShin': 'RightThigh',
    'LeftHand': 'LeftForeArm',
    'RightHand': 'RightForeArm',
    for (final side in ['Left', 'Right']) ...{
      '${side}Thumb1': '${side}Hand',
      '${side}Thumb2': '${side}Thumb1',
      '${side}Thumb3': '${side}Thumb2',
      '${side}Index1': '${side}Hand',
      '${side}Index2': '${side}Index1',
      '${side}Index3': '${side}Index2',
      '${side}Middle1': '${side}Hand',
      '${side}Middle2': '${side}Middle1',
      '${side}Middle3': '${side}Middle2',
      '${side}Ring1': '${side}Hand',
      '${side}Ring2': '${side}Ring1',
      '${side}Ring3': '${side}Ring2',
      '${side}Pinky1': '${side}Hand',
      '${side}Pinky2': '${side}Pinky1',
      '${side}Pinky3': '${side}Pinky2',
    },
  };

  static final segments = <String, (int, int, V3)>{
    'LeftUpperArm': (11, 13, V3(1, 0, 0)),
    'LeftForeArm': (13, 15, V3(1, 0, 0)),
    'RightUpperArm': (12, 14, V3(-1, 0, 0)),
    'RightForeArm': (14, 16, V3(-1, 0, 0)),
    'LeftThigh': (23, 25, V3(0, -1, 0)),
    'LeftShin': (25, 27, V3(0, -1, 0)),
    'RightThigh': (24, 26, V3(0, -1, 0)),
    'RightShin': (26, 28, V3(0, -1, 0)),
    'LeftHand': (0, 9, V3(1, 0, 0)),
    'RightHand': (0, 9, V3(-1, 0, 0)),
    for (final side in ['Left', 'Right']) ...{
      '${side}Thumb1': (1, 2, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Thumb2': (2, 3, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Thumb3': (3, 4, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Index1': (5, 6, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Index2': (6, 7, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Index3': (7, 8, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Middle1': (9, 10, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Middle2': (10, 11, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Middle3': (11, 12, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Ring1': (13, 14, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Ring2': (14, 15, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Ring3': (15, 16, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Pinky1': (17, 18, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Pinky2': (18, 19, V3(side == 'Left' ? 1 : -1, 0, 0)),
      '${side}Pinky3': (19, 20, V3(side == 'Left' ? 1 : -1, 0, 0)),
    },
  };

  static List<String> bodyBones(bool fullBody) => parents.keys
      .where(
        (name) =>
            (fullBody || (!name.contains('Thigh') && !name.contains('Shin'))) &&
            !name.contains('Hand') &&
            !name.contains('Thumb') &&
            !name.contains('Index') &&
            !name.contains('Middle') &&
            !name.contains('Ring') &&
            !name.contains('Pinky'),
      )
      .toList();

  static List<String> bones(bool fullBody) => parents.keys
      .where(
        (name) =>
            fullBody || (!name.contains('Thigh') && !name.contains('Shin')),
      )
      .toList();
}
