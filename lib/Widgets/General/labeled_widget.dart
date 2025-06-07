import 'package:flutter/material.dart';
import 'package:nokubooru/Widgets/General/padded_widget.dart';

// A simple Widget that shows a label on the left and an item on the right, evenly spaced out.
class LabeledWidget extends StatelessWidget {
    final Widget label;
    final Widget child;
    final bool padded;

    const LabeledWidget({required this.label, required this.child, this.padded = false, super.key});

    @override
    Widget build(BuildContext context) {
        final Widget label = (padded) ? PaddedWidget(child: this.label) : this.label;
        final Widget child = (padded) ? PaddedWidget(child: this.child) : this.child;

        return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                label,
                child
            ],
        );
    }
}