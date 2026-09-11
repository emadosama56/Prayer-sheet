import 'package:flutter/material.dart';

/// A collectable mosaic: one piece is earned for every day whose five prayers
/// were all logged, and a finished mosaic joins the collection.
///
/// The point is to give a completed day something to show for itself beyond a
/// number going up, and to keep the reward changing: every mosaic has its own
/// name and colour, so the next one never looks like the last.
class Mosaic {
  const Mosaic({required this.name, required this.colour, required this.motif});

  final String name;
  final Color colour;
  final MosaicMotif motif;

  /// Pieces in one mosaic. Nine keeps a finish about a week and a half away —
  /// near enough to chase, far enough to be worth finishing.
  static const int pieces = 9;

  /// The mosaics, cycled through in order and then repeated.
  static const List<Mosaic> all = <Mosaic>[
    Mosaic(name: 'نجمة الفجر', colour: Color(0xFF14795A), motif: MosaicMotif.star),
    Mosaic(name: 'قبة النور', colour: Color(0xFF1F6F8B), motif: MosaicMotif.dome),
    Mosaic(name: 'زخرفة الأندلس', colour: Color(0xFF8B5E34), motif: MosaicMotif.lattice),
    Mosaic(name: 'هلال الشوق', colour: Color(0xFF6B4E9B), motif: MosaicMotif.crescent),
    Mosaic(name: 'وردة القيروان', colour: Color(0xFFB03A5B), motif: MosaicMotif.rosette),
    Mosaic(name: 'شمس القرافة', colour: Color(0xFFC77D27), motif: MosaicMotif.sun),
  ];

  static Mosaic byIndex(int index) => all[index % all.length];
}

/// The geometric figure drawn on a mosaic's pieces.
enum MosaicMotif { star, dome, lattice, crescent, rosette, sun }

/// How far along the collection is, derived from the number of complete days.
class MosaicProgress {
  const MosaicProgress({required this.completeDays});

  /// Days on which all five prayers were logged — one piece each.
  final int completeDays;

  int get totalPieces => completeDays;

  /// Mosaics fully assembled and put away.
  int get finishedCount => totalPieces ~/ Mosaic.pieces;

  /// Pieces already placed in the mosaic being worked on.
  int get piecesInCurrent => totalPieces % Mosaic.pieces;

  int get piecesLeft => Mosaic.pieces - piecesInCurrent;

  Mosaic get current => Mosaic.byIndex(finishedCount);

  /// The finished mosaics, oldest first.
  List<Mosaic> get finished => <Mosaic>[
        for (var i = 0; i < finishedCount; i++) Mosaic.byIndex(i),
      ];

  /// True on the day a mosaic was just completed.
  bool get justFinished => totalPieces > 0 && piecesInCurrent == 0;
}
