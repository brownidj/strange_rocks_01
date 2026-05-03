part of 'field_pack_tile_preview_screen.dart';

class _SelectedBboxTilePainter extends CustomPainter {
  const _SelectedBboxTilePainter({required this.normalizedRect});

  final Rect normalizedRect;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      normalizedRect.left * size.width,
      normalizedRect.top * size.height,
      normalizedRect.right * size.width,
      normalizedRect.bottom * size.height,
    );
    final fill = Paint()
      ..color = const Color(0x2EFFE066)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFFFFE066)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _SelectedBboxTilePainter oldDelegate) {
    return oldDelegate.normalizedRect != normalizedRect;
  }
}
