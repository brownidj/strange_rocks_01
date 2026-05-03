part of 'field_area_define_screen.dart';

class _PinOverlayPainter extends CustomPainter {
  const _PinOverlayPainter({required this.pins, required this.bounds});

  final List<_GeoPoint> pins;
  final _RegionBounds bounds;

  @override
  void paint(Canvas canvas, Size size) {
    if (pins.isEmpty) {
      return;
    }
    final linePaint = Paint()
      ..color = const Color(0xCCFFD54F)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = const Color(0x33FFD54F)
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.fill;

    final points = pins
        .map((p) => Offset(_xForLon(p.lon, size), _yForLat(p.lat, size)))
        .toList(growable: false);

    if (points.length >= 3) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, linePaint);
    } else if (points.length >= 2) {
      for (var i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
    }

    for (var i = 0; i < points.length; i++) {
      final pt = points[i];
      canvas.drawCircle(pt, 5, dotPaint);
      final textSpan = TextSpan(
        text: '${i + 1}',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(pt.dx + 6, pt.dy - 6));
    }
  }

  double _xForLon(double lon, Size size) {
    final w = bounds.maxLon - bounds.minLon;
    if (w <= 0) {
      return 0;
    }
    final nx = (lon - bounds.minLon) / w;
    return nx * size.width;
  }

  double _yForLat(double lat, Size size) {
    final h = bounds.maxLat - bounds.minLat;
    if (h <= 0) {
      return 0;
    }
    final ny = (bounds.maxLat - lat) / h;
    return ny * size.height;
  }

  @override
  bool shouldRepaint(covariant _PinOverlayPainter oldDelegate) {
    if (oldDelegate.pins.length != pins.length) {
      return true;
    }
    if (oldDelegate.bounds.minLon != bounds.minLon ||
        oldDelegate.bounds.minLat != bounds.minLat ||
        oldDelegate.bounds.maxLon != bounds.maxLon ||
        oldDelegate.bounds.maxLat != bounds.maxLat) {
      return true;
    }
    for (var i = 0; i < pins.length; i++) {
      if (pins[i].lon != oldDelegate.pins[i].lon ||
          pins[i].lat != oldDelegate.pins[i].lat) {
        return true;
      }
    }
    return false;
  }
}
