import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:sliver_tools/sliver_tools.dart';

var zeroBlur = ImageFilter.blur();
var actualBlur = ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0);

class CustomContainer extends StatefulWidget {
    final Widget child;
    final EdgeInsets padding;
    final EdgeInsets itemPadding;
    final BorderRadius borderRadius;
    final BoxConstraints? constraints;
    final Color? color;

    const CustomContainer({
        required this.child,
        this.padding = const EdgeInsets.only(top: 8.0, bottom: 8.0),
        this.itemPadding = const EdgeInsets.all(8.0),
        this.borderRadius = const BorderRadius.only(
            topRight: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0)
        ),
        this.constraints,
        this.color,
        super.key
    });

    @override
    State<CustomContainer> createState() => _CustomContainerState();
}

class _CustomContainerState extends State<CustomContainer> {
    @override
    Widget build(BuildContext context) {
        var containerColor = widget.color ?? Theme.of(context).cardColor;

        if (Settings.backgroundImage != null) {
            containerColor = containerColor.withAlpha((255 * 0.75).round());
        }

        return Padding(
            padding: widget.padding,
            child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: BackdropFilter(
                    filter: (Settings.backgroundImage == null) ? zeroBlur : actualBlur,
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        padding: widget.itemPadding,
                        decoration: BoxDecoration(
                            borderRadius: widget.borderRadius,
                            boxShadow: (Settings.backgroundImage == null) ? const [
                                BoxShadow(
                                    offset: Offset(4.0, 4.0),
                                    blurRadius: 32.0
                                )
                            ] : null,
                            color: containerColor
                        ),
                        constraints: widget.constraints,
                        child: widget.child
                    ),
                ),
            ),
        );
    }
}

class CustomSliverContainer extends StatelessWidget {
    final Widget sliver;

    const CustomSliverContainer({required this.sliver, super.key});

    @override
    Widget build(BuildContext context) {
        const borderRadius = BorderRadius.all(Radius.circular(16.0));
        var containerColor = Theme.of(context).cardColor;

        if (Settings.backgroundImage != null) {
            containerColor = containerColor.withAlpha((255 * 0.75).round());
        }

        return BackdropGroup(
            child: SliverStack(
                children: [
                    SliverPositioned.fill(
                        child: ClipRRect(
                            borderRadius: borderRadius,
                            child: BackdropFilter(
                                filter: (Settings.backgroundImage == null) ? zeroBlur : actualBlur,
                                child: Container(
                                    decoration: BoxDecoration(
                                        borderRadius: borderRadius,
                                        boxShadow: (Settings.backgroundImage == null) ? const [
                                            BoxShadow(
                                                offset: Offset(4.0, 4.0),
                                                blurRadius: 32.0
                                            )
                                        ] : null,
                                        color: containerColor
                                    ),
                                ),
                            )
                        )
                    ),
                    sliver
                ]
            ),
        );
    }
}