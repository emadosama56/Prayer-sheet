import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mosaic.dart';

/// Draws a mosaic as a grid of pieces, the earned ones filled in.
class MosaicGrid extends StatelessWidget {
  const MosaicGrid({
    super.key,
    required this.mosaic,
    required this.earned,
    this.size = 180,
  });

  final Mosaic mosaic;

  /// How many of [Mosaic.pieces] have been earned.
  final int earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MosaicPainter(
          mosaic: mosaic,
          earned: earned,
          emptyColour: scheme.outlineVariant,
        ),
      ),
    );
  }
}

class _MosaicPainter extends CustomPainter {
  _MosaicPainter({
    required this.mosaic,
    required this.earned,
    required this.emptyColour,
  });

  final Mosaic mosaic;
  final int earned;
  final Color emptyColour;

  static const int _side = 3; // 3x3 makes up the nine pieces

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width * 0.03;
    final tile = (size.width - gap * (_side - 1)) / _side;

    for (var index = 0; index < Mosaic.pieces; index++) {
      final row = index ~/ _side;
      // The rest of the app reads right to left, so pieces fill that way too.
      final column = _side - 1 - (index % _side);
      final rect = Rect.fromLTWH(
        column * (tile + gap),
        row * (tile + gap),
        tile,
        tile,
      );
      final isEarned = index < earned;
      _paintTile(canvas, rect, isEarned);
    }
  }

  void _paintTile(Canvas canvas, Rect rect, bool isEarned) {
    final radius = RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.16));

    canvas.drawRRect(
      radius,
      Paint()
        ..color = isEarned
            ? mosaic.colour.withOpacity(0.16)
            : emptyColour.withOpacity(0.25),
    );

    if (!isEarned) {
      // An empty piece is only outlined, so the gap reads as "not yet".
      canvas.drawRRect(
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = emptyColour,
      );
      return;
    }

    canvas.save();
    canvas.clipRRect(radius);
    _paintMotif(canvas, rect);
    canvas.restore();
  }

  void _paintMotif(Canvas canvas, Rect rect) {
    final centre = rect.center;
    final r = rect.width * 0.32;
    final fill = Paint()..color = mosaic.colour;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.055
      ..strokeCap = StrokeCap.round
      ..color = mosaic.colour;

    switch (mosaic.motif) {
      case MosaicMotif.star:
        canvas.drawPath(_starPath(centre, r, points: 8), fill);
      case MosaicMotif.dome:
        canvas.drawArc(
          Rect.fromCircle(center: centre.translate(0, r * 0.35), radius: r),
          math.pi,
          math.pi,
          true,
          fill,
        );
        canvas.drawLine(
          Offset(centre.dx - r, centre.dy + r * 0.4),
          Offset(centre.dx + r, centre.dy + r * 0.4),
          line,
        );
      case MosaicMotif.lattice:
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(
            Offset(centre.dx + i * r, centre.dy - r),
            Offset(centre.dx + i * r + r, centre.dy + r),
            line,
          );
          canvas.drawLine(
            Offset(centre.dx + i * r, centre.dy - r),
            Offset(centre.dx + i * r - r, centre.dy + r),
            line,
          );
        }
      case MosaicMotif.crescent:
        final outer = Path()
          ..addOval(Rect.fromCircle(center: centre, radius: r));
        final inner = Path()
          ..addOval(Rect.fromCircle(
            center: centre.translate(r * 0.42, -r * 0.12),
            radius: r * 0.82,
          ));
        canvas.drawPath(
          Path.combine(PathOperation.difference, outer, inner),
          fill,
        );
      case MosaicMotif.rosette:
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          canvas.drawCircle(
            centre.translate(math.cos(angle) * r * 0.5, math.sin(angle) * r * 0.5),
            r * 0.42,
            Paint()..color = mosaic.colour.withOpacity(0.55),
          );
        }
      case MosaicMotif.sun:
        canvas.drawCircle(centre, r * 0.5, fill);
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          canvas.drawLine(
            centre.translate(math.cos(angle) * r * 0.7, math.sin(angle) * r * 0.7),
            centre.translate(math.cos(angle) * r, math.sin(angle) * r),
            line,
          );
        }
    }
  }

  Path _starPath(Offset centre, double radius, {required int points}) {
    final path = Path();
    final step = math.pi / points;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = i * step - math.pi / 2;
      final point = centre.translate(math.cos(angle) * r, math.sin(angle) * r);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_MosaicPainter old) =>
      old.earned != earned ||
      old.mosaic != mosaic ||
      old.emptyColour != emptyColour;
}
