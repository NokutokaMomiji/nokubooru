import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';

final class NokuMenuItem<T> extends ContextMenuItem<T> {
    final String label;
    final IconData? icon;
    final BoxConstraints? constraints;

    const NokuMenuItem({
        required this.label,
        this.icon,
        super.value,
        super.onSelected,
        this.constraints,
    });

    const NokuMenuItem.submenu({
        required this.label,
        required List<ContextMenuEntry> items,
        this.icon,
        super.onSelected,
        this.constraints,
    }) : super.submenu(items: items);

    @override
    Widget builder(BuildContext context, ContextMenuState menuState, [FocusNode? focusNode]) {
        final bool isFocused = menuState.focusedEntry == this;

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        final background = colorScheme.surface;
        final normalTextColor = Color.alphaBlend(
            colorScheme.onSurface.withAlpha((255 * 0.7).round()),
            background,
        );
        final focusedTextColor = colorScheme.onSurface;
        final foregroundColor = isFocused ? focusedTextColor : normalTextColor;
        final textStyle = TextStyle(color: foregroundColor, height: 1.0);

        // ~~~~~~~~~~ //

        return ConstrainedBox(
            constraints: constraints ?? const BoxConstraints.expand(height: 32.0),
            child: Material(
                color: isFocused ? theme.focusColor.withAlpha(20) : background,
                borderRadius: BorderRadius.circular(4.0),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: () => handleItemSelection(context),
                    canRequestFocus: false,
                    child: DefaultTextStyle.merge(
                        style: textStyle,
                        child: Row(
                            children: [
                                SizedBox.square(
                                dimension: 32.0,
                                    child: Icon(
                                        icon,
                                        size: 16.0,
                                        color: foregroundColor,
                                    ),
                                ),
                                const SizedBox(width: 4.0),
                                Expanded(
                                    child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                    ),
                                ),
                                const SizedBox(width: 8.0),
                                SizedBox.square(
                                    dimension: 32.0,
                                    child: Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: Icon(
                                            isSubmenuItem ? Icons.arrow_right : null,
                                            size: 16.0,
                                            color: foregroundColor,
                                        ),
                                    ),
                                )
                            ],
                        ),
                    ),
                ),
            ),
        );
    }

  @override
  String get debugLabel => "[${hashCode.toString().substring(0, 5)}] $label";
}

final class NokuMenuChild<T> extends ContextMenuItem<T> {
    final Widget child;
    final BoxConstraints? constraints;
    final bool selectable;

    const NokuMenuChild({
        required this.child,
        super.value,
        super.onSelected,
        this.constraints,
        this.selectable = false
    });

    @override
    Widget builder(BuildContext context, ContextMenuState menuState, [FocusNode? focusNode]) {
        final bool isFocused = menuState.focusedEntry == this;

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        final background = colorScheme.surface;
        final normalTextColor = Color.alphaBlend(
            colorScheme.onSurface.withAlpha((255 * 0.7).round()),
            background,
        );
        final focusedTextColor = colorScheme.onSurface;
        final foregroundColor = isFocused ? focusedTextColor : normalTextColor;
        final textStyle = TextStyle(color: foregroundColor, height: 1.0);

        // ~~~~~~~~~~ //

        if (!selectable) {
            return ConstrainedBox(
                constraints: constraints ?? const BoxConstraints.expand(height: 32.0),
                child: child,
            );
        }

        return ConstrainedBox(
            constraints: constraints ?? const BoxConstraints.expand(height: 32.0),
            child: Material(
                color: isFocused ? theme.focusColor.withAlpha(20) : background,
                borderRadius: BorderRadius.circular(4.0),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: () => handleItemSelection(context),
                    canRequestFocus: false,
                    child: DefaultTextStyle.merge(
                        style: textStyle,
                        child: child
                    ),
                ),
            ),
        );
    }

    @override
    String get debugLabel => "[${hashCode.toString().substring(0, 5)}] $child";
}