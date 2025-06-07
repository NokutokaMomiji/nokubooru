import 'package:flutter/material.dart';
import 'package:nokubooru/themes.dart';

/// Two visual styles for a settings option:
/// - card: a compact card with icon above title/description
/// - chip: a horizontal chip with icon on the left and text on the right
enum SettingsOptionStyle { card, chip }

/// A single setting option that can show an icon, title, optional subtitle,
/// and a trailing widget (e.g., a Switch or a chevron). It delegates
/// to either _CardStyleSettingsOption or _ChipStyleSettingsOption.
class SettingsOption extends StatelessWidget {
    final String title;
    final String? subtitle;
    final IconData? icon;
    final Widget? trailing;
    final VoidCallback? onTap;
    final SettingsOptionStyle style;
    final bool shrinkWrap;

    const SettingsOption({
        required this.title,
        required this.icon,
        this.subtitle,
        this.trailing,
        this.onTap,
        this.style = SettingsOptionStyle.card,
        this.shrinkWrap = false,
        super.key,
    });

    @override
    Widget build(BuildContext context) => style == SettingsOptionStyle.chip
            ? _ChipStyleSettingsOption(
                title: title,
                subtitle: subtitle,
                icon: icon,
                trailing: trailing,
                onTap: onTap,
                shrinkWrap: shrinkWrap
            )
            : _CardStyleSettingsOption(
                title: title,
                subtitle: subtitle,
                icon: icon!,
                trailing: trailing,
                onTap: onTap,
                shrinkWrap: shrinkWrap
            );
}

class _CardStyleSettingsOption extends StatelessWidget {
    final String title;
    final String? subtitle;
    final IconData icon;
    final Widget? trailing;
    final VoidCallback? onTap;
    final bool shrinkWrap;

    const _CardStyleSettingsOption({
        required this.title,
        this.subtitle,
        required this.icon,
        this.trailing,
        this.onTap,
        this.shrinkWrap = false
    });

    @override
    Widget build(BuildContext context) {
        final theme = Theme.of(context);
        return SizedBox(
            width: 256,
            child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 8.0,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: onTap,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                Icon(icon, size: 32, color: Themes.accent),
                                const SizedBox(height: 12.0),
                                Text(
                                    title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: (shrinkWrap) ? 2 : null,
                                    overflow: TextOverflow.fade,
                                    softWrap: (shrinkWrap) ? false : null,
                                ),
                                if (subtitle != null) ...[
                                    const SizedBox(height: 4.0),
                                    Text(
                                        subtitle!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.hintColor,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: (shrinkWrap) ? 2 : null,
                                        overflow: TextOverflow.fade,
                                        softWrap: (shrinkWrap) ? false : null,
                                    ),
                                ],
                                if (trailing != null) ...[
                                    const SizedBox(height: 12.0),
                                    Align(
                                        alignment: Alignment.centerRight,
                                        child: trailing!,
                                    ),
                                ],
                            ],
                        ),
                    ),
                ),
            ),
        );
    }
}

class _ChipStyleSettingsOption extends StatelessWidget {
    final String title;
    final String? subtitle;
    final IconData? icon;
    final Widget? trailing;
    final VoidCallback? onTap;
    final bool shrinkWrap;

    const _ChipStyleSettingsOption({
        required this.title,
        this.subtitle,
        required this.icon,
        this.trailing,
        this.onTap,
        this.shrinkWrap = false,
    });

    @override
    Widget build(BuildContext context) => Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
            ),
            elevation: 8.0,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        minHeight: 64
                    ),
                    child: IntrinsicHeight(
                        child: Row(
                            children: [
                                Container(
                                    width: (icon != null) ? 64.0 : 8.0,
                                    color: Themes.accent.withAlpha((255 * 0.1).floor()),
                                    child: Center(
                                        child: Icon(
                                            icon, 
                                            size: 24, 
                                            color: Themes.accent
                                        ),
                                    ),
                                ),
                                Expanded(
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                        child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(
                                                    title,
                                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: (shrinkWrap) ? 1 : null,
                                                    overflow: TextOverflow.fade,
                                                    softWrap: (shrinkWrap) ? false : null,
                                                ),
                                                if (subtitle != null) Padding(
                                                    padding: const EdgeInsets.only(top: 2.0),
                                                    child: Text(
                                                        subtitle!,
                                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: Theme.of(context).hintColor,
                                                        ),
                                                        maxLines: (shrinkWrap) ? 1 : null,
                                                        overflow: TextOverflow.fade,
                                                        softWrap: (shrinkWrap) ? false : null,
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),
                                ),
                                if (trailing != null) Expanded(
                                    child: Padding(
                                        padding: const EdgeInsets.only(left: 8.0, right: 16.0),
                                        child: trailing!,
                                    ),
                                ),
                            ],
                        ),
                    ),
                ),
            ),
        );
}
