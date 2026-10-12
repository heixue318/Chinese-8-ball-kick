import 'package:flame/extensions.dart';

import '../table_constants.dart';

/// The rubber-nose segments shared by live play and shot previews.
class TableGeometry {
  const TableGeometry._();

  static List<(Vector2, Vector2)> cushionSegments() {
    const hw = TableConstants.cushionNoseHalfLength;
    const top = TableConstants.cushionNoseTop;
    const bottom = TableConstants.cushionNoseBottom;
    const cornerGap = 6.1;
    const sideGap = 5.6;
    final segments = <(Vector2, Vector2)>[
      (Vector2(-hw + cornerGap, top), Vector2(-sideGap, top)),
      (Vector2(sideGap, top), Vector2(hw - cornerGap, top)),
      (Vector2(-hw + cornerGap, bottom), Vector2(-sideGap, bottom)),
      (Vector2(sideGap, bottom), Vector2(hw - cornerGap, bottom)),
      (Vector2(-hw, top + cornerGap), Vector2(-hw, bottom - cornerGap)),
      (Vector2(hw, top + cornerGap), Vector2(hw, bottom - cornerGap)),
    ];

    void corner(double cx, double cy, double sx, double sy) {
      const len = 3.5;
      const inset = 4.5;
      segments.add((
        Vector2(cx + sx * inset, cy),
        Vector2(cx + sx * (inset + len), cy + sy * len * .35),
      ));
      segments.add((
        Vector2(cx, cy + sy * inset),
        Vector2(cx + sx * len * .35, cy + sy * (inset + len)),
      ));
    }

    void side(double y, double sy) {
      const len = 3.0;
      const inset = 4.0;
      segments.add((
        Vector2(-inset, y),
        Vector2(-(inset + len), y + sy * len * .3),
      ));
      segments.add((
        Vector2(inset, y),
        Vector2(inset + len, y + sy * len * .3),
      ));
    }

    corner(-hw, top, 1, 1);
    corner(hw, top, -1, 1);
    corner(-hw, bottom, 1, -1);
    corner(hw, bottom, -1, -1);
    side(top, -1);
    side(bottom, 1);
    return segments;
  }
}
