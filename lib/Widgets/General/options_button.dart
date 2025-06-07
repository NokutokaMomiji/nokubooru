import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:nokubooru/Widgets/General/rounded_box_button.dart';

class OptionsButton extends StatefulWidget {
    final List<ContextMenuEntry> entries;
    final Icon? icon;

    const OptionsButton({required this.entries, this.icon, super.key});

    @override
    State<OptionsButton> createState() => _OptionsButtonState();
}

class _OptionsButtonState extends State<OptionsButton> {
    Offset mousePosition = Offset.zero;

    @override
    Widget build(BuildContext context) {
        final menu = ContextMenu(
            padding: const EdgeInsets.all(8.0),
            entries: widget.entries
        );

        return Listener(
            onPointerDown: (event) {
                mousePosition = event.position;
            },
            child: RoundedBoxButton(
                icon: widget.icon ?? const Icon(Icons.more_vert),
                onTap: () async {
                    final menuInstance = menu.copyWith(position: mousePosition);
                    await menuInstance.show(context);
                },
            )
        );
    }
}