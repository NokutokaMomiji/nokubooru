import 'package:flutter/material.dart';

/// Widget with a default padding of 8.0 around all edges.
class PaddedWidget extends StatelessWidget {
    final Widget child;
    final EdgeInsetsGeometry? padding;
    const PaddedWidget({super.key, required this.child, this.padding});

    @override
    Widget build(BuildContext context) => Padding(
            padding: padding ?? const EdgeInsets.all(8.0),
            child: child,
        );
}