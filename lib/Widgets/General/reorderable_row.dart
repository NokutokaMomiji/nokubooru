import 'package:flutter/material.dart';

class ReorderableRow extends StatefulWidget {
    final List<Widget> children;
    final void Function(int oldIndex, int newIndex) onReorder;
    final EdgeInsetsGeometry? padding;
    final MainAxisAlignment mainAxisAlignment;
    final CrossAxisAlignment crossAxisAlignment;

    const ReorderableRow({
        required this.children, 
        required this.onReorder, 
        this.padding, 
        this.mainAxisAlignment = MainAxisAlignment.start,
        this.crossAxisAlignment = CrossAxisAlignment.center,
        super.key
    });

    @override
    State<ReorderableRow> createState() => _ReorderableRowState();
}

class _ReorderableRowState extends State<ReorderableRow> {
    List<Widget> items = [];

    @override
    void initState() {
        super.initState();
        items = widget.children.asMap().entries.map((entry) => wrapDraggable(entry.key, entry.value)).toList();
    }

    @override
    void didUpdateWidget(covariant ReorderableRow oldWidget) {
        super.didUpdateWidget(oldWidget);
        if (oldWidget.children != widget.children) {
            items = widget.children.asMap().entries.map(
                (element) => wrapDraggable(element.key, element.value)
            ).toList();
        }
    }

    Widget wrapDraggable(int index, Widget child) => Flexible(
            child: Draggable(
                axis: Axis.horizontal,
                feedback: Material(
                    elevation: 4,
                    child: child,
                ),
                data: index,
                childWhenDragging: Opacity(opacity: 0.3, child: child),
                child: DragTarget<int>(
                    onAcceptWithDetails: (details) {
                        setState(() {
                            final item = items.removeAt(details.data);
                            items.insert(index, item);
                            widget.onReorder(details.data, index);
                        });
                    },
                    builder: (context, candidateData, rejectedData) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: child,
                        ),
                ),
            ),
        );

    @override
    Widget build(BuildContext context) => Padding(
            padding: widget.padding ?? EdgeInsets.zero,
            child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: widget.mainAxisAlignment,
                crossAxisAlignment: widget.crossAxisAlignment,
                children: items,
            ),
        );
}