import 'dart:math' as math;

/// Immutable vectors/quaternions. Active rotations, column vectors, parent-first composition.
class V3 {
  const V3(this.x,this.y,this.z);
  final double x,y,z;
  static const zero=V3(0,0,0), up=V3(0,1,0), right=V3(1,0,0);
  V3 operator +(V3 b)=>V3(x+b.x,y+b.y,z+b.z);
  V3 operator -(V3 b)=>V3(x-b.x,y-b.y,z-b.z);
  V3 operator *(double k)=>V3(x*k,y*k,z*k);
  double dot(V3 b)=>x*b.x+y*b.y+z*b.z;
  V3 cross(V3 b)=>V3(y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x);
  double get length=>math.sqrt(dot(this));
  bool get finite=>x.isFinite&&y.isFinite&&z.isFinite;
  V3 unit() { final n=length; if(!finite||n<1e-7) throw const FormatException('Degenerate body direction'); return this*(1/n); }
}
class Rotation {
  const Rotation(this.x,this.y,this.z,this.w);
  final double x,y,z,w;
  static const identity=Rotation(0,0,0,1);
  double get norm=>math.sqrt(x*x+y*y+z*z+w*w);
  Rotation normalized() {
    final n=norm;
    if(!n.isFinite||n<1e-9) throw const FormatException('Invalid joint rotation');
    return Rotation(x/n,y/n,z/n,w/n);
  }
  Rotation get inverse=>Rotation(-x,-y,-z,w).normalized();
  Rotation operator *(Rotation b)=>Rotation(
    w*b.x+x*b.w+y*b.z-z*b.y,
    w*b.y-x*b.z+y*b.w+z*b.x,
    w*b.z+x*b.y-y*b.x+z*b.w,
    w*b.w-x*b.x-y*b.y-z*b.z).normalized();
  V3 rotate(V3 p) { final u=V3(x,y,z); return p+u.cross(p)*(2*w)+u.cross(u.cross(p))*2; }
  static Rotation axis(V3 axis,double radians) {
    final u=axis.unit(),s=math.sin(radians/2);
    return Rotation(u.x*s,u.y*s,u.z*s,math.cos(radians/2)).normalized();
  }
  static Rotation fromTo(V3 from,V3 to) {
    final a=from.unit(),b=to.unit(),d=a.dot(b).clamp(-1.0,1.0).toDouble();
    if(d>1-1e-8) return identity;
    if(d< -1+1e-7) {
      final other=a.x.abs()<.8?V3.right:V3.up;
      return axis(a.cross(other),math.pi);
    }
    final c=a.cross(b);
    return Rotation(c.x,c.y,c.z,1+d).normalized();
  }
  /// x/y/z are orthonormal basis columns, not rows.
  static Rotation basis(V3 x,V3 y,V3 z) {
    final trace=x.x+y.y+z.z;
    if(trace>0) {
      final s=math.sqrt(trace+1)*2;
      return Rotation((y.z-z.y)/s,(z.x-x.z)/s,(x.y-y.x)/s,s/4).normalized();
    }
    if(x.x>y.y&&x.x>z.z) {
      final s=math.sqrt(1+x.x-y.y-z.z)*2;
      return Rotation(s/4,(y.x+x.y)/s,(z.x+x.z)/s,(y.z-z.y)/s).normalized();
    }
    if(y.y>z.z) {
      final s=math.sqrt(1+y.y-x.x-z.z)*2;
      return Rotation((y.x+x.y)/s,s/4,(z.y+y.z)/s,(z.x-x.z)/s).normalized();
    }
    final s=math.sqrt(1+z.z-x.x-y.y)*2;
    return Rotation((z.x+x.z)/s,(z.y+y.z)/s,s/4,(x.y-y.x)/s).normalized();
  }
  Rotation slerp(Rotation other,double fraction) {
    final t=fraction.clamp(0.0,1.0).toDouble();
    final a=normalized(); var b=other.normalized();
    var dot=a.x*b.x+a.y*b.y+a.z*b.z+a.w*b.w;
    if(dot<0) { b=Rotation(-b.x,-b.y,-b.z,-b.w);dot= -dot; }
    if(dot>.9995) return Rotation(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,a.z+(b.z-a.z)*t,a.w+(b.w-a.w)*t).normalized();
    final theta=math.acos(dot.clamp(-1.0,1.0)),den=math.sin(theta);
    final p=math.sin((1-t)*theta)/den,q=math.sin(t*theta)/den;
    return Rotation(a.x*p+b.x*q,a.y*p+b.y*q,a.z*p+b.z*q,a.w*p+b.w*q).normalized();
  }
  double angleTo(Rotation b) {
    final a=normalized(),q=b.normalized();
    return 2*math.acos((a.x*q.x+a.y*q.y+a.z*q.z+a.w*q.w).abs().clamp(0.0,1.0));
  }
}
