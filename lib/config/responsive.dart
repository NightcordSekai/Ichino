import 'package:flutter/material.dart';

/// Breakpoints: phone < 600, tablet 600–900, desktop > 900
const double _breakpointTablet = 600;
const double _breakpointDesktop = 900;

/// Returns a responsive max width for content containers.
/// - Phone: 500
/// - Tablet: 700
/// - Desktop: 900
double responsiveMaxWidth(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width >= _breakpointDesktop) return 900;
  if (width >= _breakpointTablet) return 700;
  return 500;
}

/// Whether the screen is tablet-sized or wider.
bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.width >= _breakpointTablet;

/// Whether the screen is desktop-sized or wider.
bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= _breakpointDesktop;

/// 把页面内容限制在响应式宽度内，并在宽窗口（桌面/横屏）下水平居中。
/// 之前各页只有 ConstrainedBox 限宽，没有居中容器，1440 宽的窗口里内容
/// 会贴左、右侧留出大片空白。
Widget responsiveBody(BuildContext context, {required Widget child}) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: responsiveMaxWidth(context)),
      child: child,
    ),
  );
}

/// Build columns for tablet/desktop — on phone, each item is full-width;
/// on tablet+ they are laid out in [columns] columns.
List<Widget> responsiveGrid({
  required BuildContext context,
  required List<Widget> children,
  int columns = 2,
  double spacing = 12,
}) {
  final tablet = isTablet(context);
  if (!tablet) return children;

  final rows = <Widget>[];
  final padded = <Widget>[];
  for (int i = 0; i < children.length; i++) {
    padded.add(children[i]);
    if ((i + 1) % columns == 0 || i == children.length - 1) {
      final cols = <Widget>[];
      for (int j = 0; j < padded.length; j++) {
        cols.add(Expanded(child: padded[j]));
      }
      // pad incomplete last row with empty expanded widgets
      while (cols.length < columns) {
        cols.add(const Expanded(child: SizedBox.shrink()));
      }
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: rows.isEmpty ? 0 : spacing),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int j = 0; j < cols.length; j++) ...[
              if (j > 0) SizedBox(width: spacing),
              cols[j],
            ],
          ],
        ),
      ));
      padded.clear();
    }
  }
  return rows;
}
