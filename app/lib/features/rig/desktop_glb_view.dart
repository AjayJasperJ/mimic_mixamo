import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'glb_mesh.dart';
import 'rig_pose.dart';

class DesktopGlbView extends StatefulWidget {
  const DesktopGlbView({super.key, required this.pose});
  final RigPose pose;
  @override
  State<DesktopGlbView> createState() => _DesktopGlbViewState();
}
class _DesktopGlbViewState extends State<DesktopGlbView> {
  late Future<GlbMesh> _asset = _load();
  double _yaw = .3;
  Future<GlbMesh> _load() async {
    final bytes = await rootBundle.load('assets/characters/development_humanoid.glb');
    return GlbMesh.parse(bytes.buffer.asUint8List(bytes.offsetInBytes,bytes.lengthInBytes));
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<GlbMesh>(future:_asset,builder:(context,snapshot) {
    if (snapshot.hasError) return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      SelectableText('GLB load failed: ${snapshot.error}'),
      OutlinedButton(onPressed:()=>setState(()=>_asset=_load()),child:const Text('Reload model')),
    ]));
    if (!snapshot.hasData) return const Center(child:CircularProgressIndicator());
    return GestureDetector(onPanUpdate:(details)=>setState(()=>_yaw+=details.delta.dx*.01),
      child:CustomPaint(painter:SkinnedGlbPainter(snapshot.data!,widget.pose,_yaw),child:const SizedBox.expand()));
  });
}
class SkinnedGlbPainter extends CustomPainter {
  SkinnedGlbPainter(this.mesh,this.pose,this.yaw);
  final GlbMesh mesh;
  final RigPose pose;
  final double yaw;
  @override
  void paint(Canvas canvas,Size size) {
    canvas.drawRect(Offset.zero & size,Paint()..color=const Color(0xff171f2b));
    final posed=mesh.posedVertices(pose);
    final rotated=posed.map((p)=>v.Vector3(p.x*math.cos(yaw)+p.z*math.sin(yaw),p.y-.9,-p.x*math.sin(yaw)+p.z*math.cos(yaw))).toList();
    final scale=math.min(size.width/2.2,size.height/2.0);
    Offset project(v.Vector3 p)=>Offset(size.width/2+p.x*scale,size.height/2-p.y*scale);
    final faces=List<int>.generate(mesh.indices.length~/3,(i)=>i*3);
    faces.sort((a,b) {
      double depth(int i)=>(rotated[mesh.indices[i]].z+rotated[mesh.indices[i+1]].z+rotated[mesh.indices[i+2]].z)/3;
      return depth(a).compareTo(depth(b));
    });
    canvas.save();canvas.clipRect(Offset.zero & size);
    for(final face in faces) {
      final a=rotated[mesh.indices[face]],b=rotated[mesh.indices[face+1]],c=rotated[mesh.indices[face+2]];
      final normal=(b-a).cross(c-a);
      final shade=normal.length<1e-9 ? .7 : (.45+.55*(normal.normalized().dot(v.Vector3(.2,.7,.6).normalized())).abs()).clamp(.3,1.0).toDouble();
      final path=Path()..moveTo(project(a).dx,project(a).dy)..lineTo(project(b).dx,project(b).dy)..lineTo(project(c).dx,project(c).dy)..close();
      canvas.drawPath(path,Paint()..color=Color.fromRGBO((70*shade).round(),(225*shade).round(),(180*shade).round(),1));
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant SkinnedGlbPainter oldDelegate)=>oldDelegate.pose!=pose || oldDelegate.yaw!=yaw || oldDelegate.mesh!=mesh;
}
