import 'package:flutter/material.dart';

class ProgressCircle extends StatelessWidget {
    final double progress;
    final Axis axis;

    const ProgressCircle({required this.progress, this.axis = Axis.vertical, super.key});

    @override
    Widget build(BuildContext context) {
        final List<Widget> progressElements = [
            Expanded(child: CircularProgressIndicator(value: progress)),
            Expanded(child: Text("${progress.floor()}%"),)
        ];

        return (axis == Axis.vertical) ? Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: progressElements
        ) : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: progressElements
        );
    }
}