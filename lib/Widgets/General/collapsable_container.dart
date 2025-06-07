import 'package:flutter/material.dart';
import 'package:nokubooru/Widgets/General/custom_container.dart';

class CollapsableContainer extends StatefulWidget {
    final Widget child;

    const CollapsableContainer({required this.child, super.key});

    @override
    State<CollapsableContainer> createState() => _CollapsableContainerState();
}

class _CollapsableContainerState extends State<CollapsableContainer> {
    @override
    Widget build(BuildContext context) => CustomContainer(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            itemPadding: const EdgeInsets.all(8.0),
            borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16.0),
                bottomRight: Radius.circular(16.0)
            ),
            constraints: const BoxConstraints(
                maxWidth: 256
            ),
            child: widget.child
        );
}