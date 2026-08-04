import 'package:flutter/material.dart';

enum NavIconType {
  home,
  workout,
  food,
  progress,
  chat,
  dashboard,
  members,
  messages,
  profile,
}

class NavIcon extends StatelessWidget {
  final NavIconType type;
  final bool isActive;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  const NavIcon({
    super.key,
    required this.type,
    required this.isActive,
    this.size = 24,
    this.activeColor = const Color(0xFF7C3AED),
    this.inactiveColor = const Color(0xFF9CA3AF),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _painter,
    );
  }

  CustomPainter get _painter {
    final color = isActive ? activeColor : inactiveColor;
    switch (type) {
      case NavIconType.home:
        return _HomePainter(color);
      case NavIconType.workout:
        return _WorkoutPainter(color);
      case NavIconType.food:
        return _FoodPainter(color);
      case NavIconType.progress:
        return _ProgressPainter(color);
      case NavIconType.chat:
        return _ChatPainter(color);
      case NavIconType.dashboard:
        return _DashboardPainter(color);
      case NavIconType.members:
        return _MembersPainter(color);
      case NavIconType.messages:
        return _MessagesPainter(color);
      case NavIconType.profile:
        return _ProfilePainter(color);
    }
  }
}

void _stroke(Canvas canvas, Path path, Paint paint, {double width = 2.5}) {
  paint
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(path, paint);
}

class _HomePainter extends CustomPainter {
  final Color color;
  _HomePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final s = size.width;
    final roof = Path()
      ..moveTo(s * 0.15, s * 0.55)
      ..lineTo(s * 0.5, s * 0.2)
      ..lineTo(s * 0.85, s * 0.55);
    _stroke(canvas, roof, p, width: 2.8);
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.22, s * 0.52, s * 0.56, s * 0.38),
        const Radius.circular(2),
      ));
    _stroke(canvas, body, p);
  }
  @override
  bool shouldRepaint(covariant _HomePainter old) => old.color != color;
}

class _WorkoutPainter extends CustomPainter {
  final Color color;
  _WorkoutPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.25, s * 0.5)
      ..lineTo(s * 0.35, s * 0.5)
      ..moveTo(s * 0.4, s * 0.3)
      ..lineTo(s * 0.4, s * 0.7)
      ..moveTo(s * 0.4, s * 0.3)
      ..lineTo(s * 0.35, s * 0.35)
      ..moveTo(s * 0.4, s * 0.3)
      ..lineTo(s * 0.45, s * 0.35)
      ..moveTo(s * 0.4, s * 0.7)
      ..lineTo(s * 0.35, s * 0.65)
      ..moveTo(s * 0.4, s * 0.7)
      ..lineTo(s * 0.45, s * 0.65)
      ..moveTo(s * 0.65, s * 0.5)
      ..lineTo(s * 0.75, s * 0.5);
    _stroke(canvas, path, p);
  }
  @override
  bool shouldRepaint(covariant _WorkoutPainter old) => old.color != color;
}

class _FoodPainter extends CustomPainter {
  final Color color;
  _FoodPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final s = size.width;
    final bowl = Path()
      ..moveTo(s * 0.15, s * 0.3)
      ..quadraticBezierTo(s * 0.15, s * 0.78, s * 0.5, s * 0.78)
      ..quadraticBezierTo(s * 0.85, s * 0.78, s * 0.85, s * 0.3)
      ..close();
    _stroke(canvas, bowl, p);
    final steam1 = Path()..moveTo(s * 0.38, s * 0.22)..lineTo(s * 0.38, s * 0.1);
    final steam2 = Path()..moveTo(s * 0.5, s * 0.25)..lineTo(s * 0.5, s * 0.12);
    final steam3 = Path()..moveTo(s * 0.62, s * 0.22)..lineTo(s * 0.62, s * 0.1);
    _stroke(canvas, steam1, p, width: 2);
    _stroke(canvas, steam2, p, width: 2);
    _stroke(canvas, steam3, p, width: 2);
  }
  @override
  bool shouldRepaint(covariant _FoodPainter old) => old.color != color;
}

class _ProgressPainter extends CustomPainter {
  final Color color;
  _ProgressPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final s = size.width;
    final bar1 = Path()..moveTo(s * 0.15, s * 0.78)..lineTo(s * 0.15, s * 0.55);
    final bar2 = Path()..moveTo(s * 0.35, s * 0.78)..lineTo(s * 0.35, s * 0.38);
    final bar3 = Path()..moveTo(s * 0.55, s * 0.78)..lineTo(s * 0.55, s * 0.48);
    final bar4 = Path()..moveTo(s * 0.75, s * 0.78)..lineTo(s * 0.75, s * 0.25);
    final base = Path()..moveTo(s * 0.08, s * 0.78)..lineTo(s * 0.92, s * 0.78);
    _stroke(canvas, bar1, p, width: 4);
    _stroke(canvas, bar2, p, width: 4);
    _stroke(canvas, bar3, p, width: 4);
    _stroke(canvas, bar4, p, width: 4);
    _stroke(canvas, base, p, width: 3);
  }
  @override
  bool shouldRepaint(covariant _ProgressPainter old) => old.color != color;
}

class _ChatPainter extends CustomPainter {
  final Color color;
  _ChatPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final s = size.width;
    final bubble = Path()..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.1, s * 0.18, s * 0.8, s * 0.55),
      const Radius.circular(6),
    ));
    _stroke(canvas, bubble, p);
    final tail = Path()
      ..moveTo(s * 0.3, s * 0.73)
      ..lineTo(s * 0.22, s * 0.9)
      ..lineTo(s * 0.45, s * 0.73);
    _stroke(canvas, tail, p, width: 2.2);
  }
  @override
  bool shouldRepaint(covariant _ChatPainter old) => old.color != color;
}

class _DashboardPainter extends CustomPainter {
  final Color color;
  _DashboardPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final s = size.width;
    final sq1 = Path()..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.08, s * 0.08, s * 0.38, s * 0.38), const Radius.circular(3)));
    final sq2 = Path()..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.54, s * 0.08, s * 0.38, s * 0.38), const Radius.circular(3)));
    final sq3 = Path()..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.08, s * 0.54, s * 0.38, s * 0.38), const Radius.circular(3)));
    final sq4 = Path()..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.54, s * 0.54, s * 0.38, s * 0.38), const Radius.circular(3)));
    _stroke(canvas, sq1, p);
    _stroke(canvas, sq2, p);
    _stroke(canvas, sq3, p);
    _stroke(canvas, sq4, p);
  }
  @override
  bool shouldRepaint(covariant _DashboardPainter old) => old.color != color;
}

class _MembersPainter extends CustomPainter {
  final Color color;
  _MembersPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final s = size.width;
    void _person(double cx) {
      final head = Path()..addOval(Rect.fromCircle(center: Offset(cx, s * 0.3), radius: s * 0.09));
      _stroke(canvas, head, p, width: 2.5);
      final body = Path()..moveTo(cx, s * 0.39)..lineTo(cx, s * 0.65);
      _stroke(canvas, body, p, width: 2.5);
      final armL = Path()..moveTo(cx, s * 0.48)..lineTo(cx - s * 0.12, s * 0.58);
      final armR = Path()..moveTo(cx, s * 0.48)..lineTo(cx + s * 0.12, s * 0.58);
      _stroke(canvas, armL, p, width: 2);
      _stroke(canvas, armR, p, width: 2);
    }
    _person(s * 0.3);
    _person(s * 0.7);
  }
  @override
  bool shouldRepaint(covariant _MembersPainter old) => old.color != color;
}

class _MessagesPainter extends CustomPainter {
  final Color color;
  _MessagesPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final s = size.width;
    final envelope = Path()
      ..moveTo(s * 0.12, s * 0.28)
      ..lineTo(s * 0.5, s * 0.52)
      ..lineTo(s * 0.88, s * 0.28);
    _stroke(canvas, envelope, p);
    final rect = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.12, s * 0.25, s * 0.76, s * 0.5),
        const Radius.circular(4),
      ));
    _stroke(canvas, rect, p);
  }
  @override
  bool shouldRepaint(covariant _MessagesPainter old) => old.color != color;
}

class _ProfilePainter extends CustomPainter {
  final Color color;
  _ProfilePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final s = size.width;
    final head = Path()..addOval(Rect.fromCircle(center: Offset(s * 0.5, s * 0.3), radius: s * 0.15));
    _stroke(canvas, head, p, width: 2.8);
    final body = Path()..moveTo(s * 0.5, s * 0.46)..lineTo(s * 0.5, s * 0.75);
    _stroke(canvas, body, p, width: 2.8);
    final armL = Path()..moveTo(s * 0.5, s * 0.56)..lineTo(s * 0.3, s * 0.7);
    final armR = Path()..moveTo(s * 0.5, s * 0.56)..lineTo(s * 0.7, s * 0.7);
    _stroke(canvas, armL, p, width: 2.2);
    _stroke(canvas, armR, p, width: 2.2);
  }
  @override
  bool shouldRepaint(covariant _ProfilePainter old) => old.color != color;
}
