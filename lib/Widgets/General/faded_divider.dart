import 'package:flutter/material.dart';

/// A divider, but faded around the edges.
class FadedDivider extends StatelessWidget {
    /// The divider's total vertical extent. Matches [Divider.height].
    final double height;

    /// The thickness of the divider line itself. Matches [Divider.thickness].
    final double? thickness;

    /// Empty space to the leading edge of the divider. Matches [Divider.indent].
    final double? indent;

    /// Empty space to the trailing edge of the divider. Matches [Divider.endIndent].
    final double? endIndent;

    /// Color of the divider line. Matches [Divider.color].
    final Color? color;

    /// How many pixels at each edge should fade in/out. Defaults to 24.
    final double fadeLength;

    const FadedDivider({
        this.height = 16.0,
        this.thickness,
        this.indent,
        this.endIndent,
        this.color,
        this.fadeLength = 24.0,
        super.key
    });

    @override
    Widget build(BuildContext context) {
        final dividerColor = color ?? Divider.createBorderSide(context).color;

        return ShaderMask(
            shaderCallback: (Rect bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                    dividerColor.withAlpha(0),
                    dividerColor,
                    dividerColor,
                    dividerColor.withAlpha(0),
                ],
                stops: [
                    0,
                    fadeLength / bounds.width,
                    1 - fadeLength / bounds.width,
                    1,
                ],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: Divider(
                height: height,
                thickness: thickness,
                indent: indent,
                endIndent: endIndent,
                color: dividerColor,
            ),
        );
    }
}

/// A vertical divider, but faded around the edges.
class FadedVerticalDivider extends StatelessWidget {
    /// The divider's total horizontal extent. Matches [VerticalDivider.width].
    final double width;

    /// The thickness of the divider line itself (line width). Matches [VerticalDivider.thickness].
    final double? thickness;

    /// Empty space above the divider. Matches [VerticalDivider.indent] but vertical.
    final double? indent;

    /// Empty space below the divider. Matches [VerticalDivider.endIndent] but vertical.
    final double? endIndent;

    /// Color of the divider line. Matches [VerticalDivider.color].
    final Color? color;

    /// How many pixels at each end should fade in/out vertically. Defaults to 24.
    final double fadeLength;

    const FadedVerticalDivider({
        this.width = 16.0,
        this.thickness,
        this.indent,
        this.endIndent,
        this.color,
        this.fadeLength = 24.0,
        super.key
    });

    @override
    Widget build(BuildContext context) {
        final dividerColor = color ?? Divider.createBorderSide(context).color;

        return ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                    dividerColor.withAlpha(0),
                    dividerColor,
                    dividerColor,
                    dividerColor.withAlpha(0),
                ],
                stops: [
                    0,
                    fadeLength / bounds.height,
                    1 - fadeLength / bounds.height,
                    1,
                ],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: VerticalDivider(
                width: width,
                thickness: thickness,
                indent: indent,
                endIndent: endIndent,
                color: dividerColor,
            ),
        );
    }
}
