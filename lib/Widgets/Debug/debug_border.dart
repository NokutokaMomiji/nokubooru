import 'package:flutter/material.dart';

class DebugBorder extends StatelessWidget {
    static int level = 0;
    static List<Color> colors = [
        Colors.red,
        Colors.green,
        Colors.blue,
        Colors.yellow
    ];

    final Widget child;

    const DebugBorder({required this.child, super.key});

    @override
    Widget build(BuildContext context) {
        level++;

        return Container(
            decoration: BoxDecoration(
                border: Border.all(
                    color: colors[level % 4]
                )
            ),
            child: child,
        );
    }
}