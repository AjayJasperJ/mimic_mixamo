import 'pose_math.dart';

/// Mapping for the approved development asset only, not an arbitrary Mixamo rig.
class DevelopmentRig {
  static const id='mimic-block-humanoid-v1';
  static const parents=<String,String?>{
    'Hips':null,'Chest':'Hips','LeftUpperArm':'Chest','LeftForeArm':'LeftUpperArm',
    'RightUpperArm':'Chest','RightForeArm':'RightUpperArm',
    'LeftThigh':'Hips','LeftShin':'LeftThigh','RightThigh':'Hips','RightShin':'RightThigh',
  };
  static const segments=<String,(int,int,V3)>{
    'LeftUpperArm':(11,13,V3(1,0,0)),'LeftForeArm':(13,15,V3(1,0,0)),
    'RightUpperArm':(12,14,V3(-1,0,0)),'RightForeArm':(14,16,V3(-1,0,0)),
    'LeftThigh':(23,25,V3(0,-1,0)),'LeftShin':(25,27,V3(0,-1,0)),
    'RightThigh':(24,26,V3(0,-1,0)),'RightShin':(26,28,V3(0,-1,0)),
  };
  static List<String> bones(bool fullBody)=>parents.keys.where((b)=>fullBody||!b.contains('Thigh')&&!b.contains('Shin')).toList();
}
