import 'dart:async';
import 'package:flutter/material.dart';

enum TooltipPosition {
    above,
    below,
    left,
    right,
}

class CustomTooltip extends StatefulWidget {
    final Widget child;
    final Widget tooltip;
    final TooltipPosition position;
    final Duration showDuration;
    final Duration waitDuration;
    final Duration fadeDuration;

    const CustomTooltip({
        super.key,
        required this.child,
        required this.tooltip,
        this.position = TooltipPosition.above,
        this.showDuration = const Duration(seconds: 2),
        this.waitDuration = const Duration(milliseconds: 500),
        this.fadeDuration = Durations.short4
    });

    @override
    CustomTooltipState createState() => CustomTooltipState();
}

class CustomTooltipState extends State<CustomTooltip> with TickerProviderStateMixin {
    final LayerLink layerLink = LayerLink();
    OverlayEntry? overlayEntry;
    Timer? showTimer;
    Timer? hideTimer;
    bool isVisible = false;

    // For positioning calculations.
    Rect? targetRect;
    Size? tooltipSize;

    // Animation controller for fading.
    late AnimationController fadeController;
    late Animation<double> fadeAnimation;

    @override
    void initState() {
        super.initState();
        fadeController = AnimationController(
            vsync: this,
            duration: widget.fadeDuration
        );
        fadeAnimation = CurvedAnimation(
            parent: fadeController,
            curve: Curves.easeInOut,
        );
    }

    void showTooltip() {
        if (isVisible) return;
        showTimer?.cancel();
        hideTimer?.cancel();

        // Capture the global position & size of the target.
        final RenderBox targetBox = context.findRenderObject() as RenderBox;
        targetRect = targetBox.localToGlobal(Offset.zero) & targetBox.size;

        showTimer = Timer(widget.waitDuration, () {
            overlayEntry = createOverlayEntry();
            Overlay.of(context).insert(overlayEntry!);
            isVisible = true;
            // Fade in.
            fadeController.forward();
            hideTimer = Timer(widget.showDuration, () {
                removeTooltip();
            });
        });
    }

    void removeTooltip() {
        showTimer?.cancel();
        hideTimer?.cancel();
        if (isVisible) {
            // Fade out, then remove overlay.
            fadeController.reverse().then((_) {
                overlayEntry?.remove();
                overlayEntry = null;
                isVisible = false;
            });
        }
    }

    OverlayEntry createOverlayEntry() => OverlayEntry(
            builder: (context) => Align(
                alignment: Alignment.topLeft,
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: CompositedTransformFollower(
                    link: layerLink,
                    showWhenUnlinked: false,
                    offset: calculateOffset(context),
                    child: FadeTransition(
                        opacity: fadeAnimation,
                        child: IgnorePointer(
                            ignoring: true,
                            child: buildTooltipContent(),
                        ),
                    ),
                ),
            ),
        );

    Offset calculateOffset(BuildContext context) {
        const double gap = 8.0;
        if (targetRect == null || tooltipSize == null) return Offset.zero;
        final screenSize = MediaQuery.of(context).size;
        TooltipPosition finalPosition = widget.position;

        if (widget.position == TooltipPosition.above ||
            widget.position == TooltipPosition.below) {
            if (widget.position == TooltipPosition.above) {
                if (tooltipSize!.height + gap > targetRect!.top) {
                    finalPosition = TooltipPosition.below;
                }
            } else {
                final availableBelow = screenSize.height - targetRect!.bottom;
                if (tooltipSize!.height + gap > availableBelow) {
                    finalPosition = TooltipPosition.above;
                }
            }
        } else {
            if (widget.position == TooltipPosition.left) {
                if (tooltipSize!.width + gap > targetRect!.left) {
                    finalPosition = TooltipPosition.right;
                }
            } else {
                final availableRight = screenSize.width - targetRect!.right;
                if (tooltipSize!.width + gap > availableRight) {
                    finalPosition = TooltipPosition.left;
                }
            }
        }

        if (finalPosition == TooltipPosition.above) {
            final dx = (targetRect!.width - tooltipSize!.width) / 2;
            final dy = -tooltipSize!.height - gap;
            return Offset(dx, dy);
        } else if (finalPosition == TooltipPosition.below) {
            final dx = (targetRect!.width - tooltipSize!.width) / 2;
            final dy = targetRect!.height + gap;
            return Offset(dx, dy);
        } else if (finalPosition == TooltipPosition.left) {
            final dx = -tooltipSize!.width - gap;
            final dy = (targetRect!.height - tooltipSize!.height) / 2;
            return Offset(dx, dy);
        } else if (finalPosition == TooltipPosition.right) {
            final dx = targetRect!.width + gap;
            final dy = (targetRect!.height - tooltipSize!.height) / 2;
            return Offset(dx, dy);
        }
        return Offset.zero;
    }

    Widget buildTooltipContent() => MeasureSize(
            onChange: (size) {
                if (tooltipSize != size) {
                    tooltipSize = size;
                    overlayEntry?.markNeedsBuild();
                    setState(() {});
                }
            },
            child: Material(
                color: Colors.transparent,
                child: widget.tooltip,
            ),
        );

    @override
    void dispose() {
        fadeController.dispose();
        removeTooltip();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) => CompositedTransformTarget(
            link: layerLink,
            child: MouseRegion(
                onEnter: (_) => showTooltip(),
                onExit: (_) => removeTooltip(),
                child: GestureDetector(
                    onLongPress: showTooltip,
                    onLongPressEnd: (_) => removeTooltip(),
                    child: widget.child,
                ),
            ),
        );
}

typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSize extends StatefulWidget {
    final Widget child;
    final OnWidgetSizeChange onChange;

    const MeasureSize({
        super.key,
        required this.onChange,
        required this.child,
    });

    @override
    MeasureSizeState createState() => MeasureSizeState();
}

class MeasureSizeState extends State<MeasureSize> {
    Size? oldSize;

    @override
    Widget build(BuildContext context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
            final Size? newSize = context.size;
            if (newSize != null && oldSize != newSize) {
                oldSize = newSize;
                widget.onChange(newSize);
            }
        });
        return widget.child;
    }
}
