import 'pose_math.dart';

class BodyPoint {
  const BodyPoint(this.position,{this.visibility,this.presence});
  final V3 position;
  final double? visibility,presence;
  bool get usable=>position.finite&&position.length<10&&
    (visibility==null||(visibility!.isFinite&&visibility!>=.55))&&
    (presence==null||(presence!.isFinite&&presence!>=.55));
  static BodyPoint? parse(Object? raw) {
    if(raw is! Map<String,Object?>) return null;
    final x=raw['x'],y=raw['y'],z=raw['z'];
    if(x is! num||y is! num||z is! num) return null;
    final p=BodyPoint(V3(x.toDouble(),y.toDouble(),z.toDouble()),
      visibility:(raw['visibility'] as num?)?.toDouble(),presence:(raw['presence'] as num?)?.toDouble());
    return p.position.finite?p:null;
  }
}
class BodyFrame {
  BodyFrame({required this.sessionId,required this.sequence,required this.capturedAtUs,
    required List<BodyPoint?> world,required List<BodyPoint?> image})
    : world=List.unmodifiable(world),image=List.unmodifiable(image);
  final String sessionId;
  final int sequence,capturedAtUs;
  final List<BodyPoint?> world,image;
  factory BodyFrame.parse(Map<String,Object?> event) {
    if(event['schemaVersion']!=2||event['sessionId'] is! String) throw const FormatException('Tracking helper protocol mismatch. Use the newest AppImage.');
    List<BodyPoint?> read(String key) {
      final raw=event[key];
      if(raw is! List<Object?>||(raw.isNotEmpty&&raw.length!=33)) throw FormatException('Invalid $key landmark count');
      return raw.map(BodyPoint.parse).toList();
    }
    final sequence=(event['sequence'] as num).toInt(),time=(event['capturedAtUs'] as num).toInt();
    if(sequence<1||time<1) throw const FormatException('Invalid frame ordering metadata');
    return BodyFrame(sessionId:event['sessionId'] as String,sequence:sequence,capturedAtUs:time,
      world:read('worldPoints'),image:read('points'));
  }
  /// MediaPipe camera estimates -> right-handed solver metres: (x,-y,-z).
  /// Mirror-avatar mode reflects X AND exchanges anatomical sides before solving.
  BodyPoint? solverPoint(int index,{bool mirror=false}) {
    const opposite={11:12,12:11,13:14,14:13,15:16,16:15,23:24,24:23,25:26,26:25,27:28,28:27};
    final mapped=mirror?(opposite[index]??index):index;
    if(mapped>=world.length) return null;
    final raw=world[mapped];
    if(raw==null||!raw.usable) return null;
    final p=raw.position;
    return BodyPoint(V3(mirror? -p.x:p.x,-p.y,-p.z),visibility:raw.visibility,presence:raw.presence);
  }
}
