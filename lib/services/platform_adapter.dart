import 'package:flutter/material.dart';

import 'platform_detection_service.dart';

class PlatformAdapter {
  final PlatformDetectionService platformService;

  PlatformAdapter(this.platformService);

  Widget buildButton({
    required VoidCallback? onPressed,
    required Widget child,
    bool isPrimary = true,
  }) {
    if (isPrimary) {
      return ElevatedButton(onPressed: onPressed, child: child);
    }
    return TextButton(onPressed: onPressed, child: child);
  }

  Widget buildProgressIndicator({double? value, Color? color}) {
    return CircularProgressIndicator(value: value, color: color);
  }

  Widget buildBackButton(BuildContext context, {VoidCallback? onPressed}) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }

  Widget buildCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) {
    return Card(
      margin: margin,
      child: padding != null ? Padding(padding: padding, child: child) : child,
    );
  }

  Widget buildLoadingIndicator({double? size, Color? color}) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        valueColor: color != null ? AlwaysStoppedAnimation<Color>(color) : null,
        strokeWidth: size != null ? size / 12 : 4.0,
      ),
    );
  }
}
