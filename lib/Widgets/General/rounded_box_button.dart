import 'package:flutter/material.dart';
import 'package:nokubooru/themes.dart';

class RoundedBoxButton extends StatelessWidget {
    final Color? backgroundColor;
    final Color? backgroundHoverColor;
    final Color? color;
    final Color? hoverColor;
    final EdgeInsets padding;
    final BorderRadius radius;
    final Icon icon;
    final VoidCallback? onTap;
    final void Function(bool)? onHover;
    
    const RoundedBoxButton({
        required this.icon, 
        this.radius = const BorderRadius.all(Radius.circular(4.0)),
        this.padding = EdgeInsets.zero,
        this.backgroundColor, 
        this.backgroundHoverColor,
        this.color, 
        this.hoverColor,
        this.onTap,
        this.onHover,
        super.key
    });

    @override
    Widget build(BuildContext context) {
        final blend = Color.alphaBlend(Colors.white, Themes.accent);

        return Padding(
            padding: padding,
            child: Material(
                color: backgroundColor,
                borderRadius: radius,
                type: (backgroundColor == null) ? MaterialType.transparency : MaterialType.canvas,
                child: InkWell(
                    borderRadius: radius,
                    hoverColor: hoverColor ?? blend.withAlpha((255 * 0.45).round()),
                    onTap: onTap,
                    onHover: onHover,
                    child: icon,
                ),
            ),
        );
    }
}