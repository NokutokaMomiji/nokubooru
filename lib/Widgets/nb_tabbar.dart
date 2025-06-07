import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:nokubooru/State/tab_manager.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/menu_item.dart';
import 'package:nokubooru/Widgets/General/reorderable_row.dart';
import 'package:nokubooru/Widgets/nb_tab.dart';
import 'package:nokubooru/Widgets/General/rounded_box_button.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';

class NBTabBar extends StatefulWidget {
    final TabManager tabManager;

    const NBTabBar({super.key, required this.tabManager});

    @override
    State<NBTabBar> createState() => _NBTabBarState();
}

class _NBTabBarState extends State<NBTabBar> {
    late final ScrollController scrollController;

    @override
    void initState() {
        super.initState();
        scrollController = ScrollController();

        widget.tabManager.onActiveChange((_) {
            if (mounted) setState(() {});
        });

        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            scrollController.jumpTo((128 * widget.tabManager.index).clamp(0, scrollController.position.maxScrollExtent).toDouble());
        });
    }

    @override
    void dispose() {
        scrollController.dispose();
        super.dispose();
    }

    void scrollTabs(int direction) {
        final newOffset = scrollController.offset + (200 * direction);
        scrollController.animateTo(
            newOffset.clamp(0, scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
        );
    }

    @override
    Widget build(BuildContext context) => Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 0.0),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Expanded(
                        child: LayoutBuilder(
                            builder: (context, constraints) {
                                final tabCount = widget.tabManager.tabs.length;
                                final maxTabWidth = (256 - (tabCount * 128 / 9)).clamp(128, 256).toDouble();
                                final totalTabWidth = tabCount * maxTabWidth;
                                final canScroll = (maxTabWidth == 128 && totalTabWidth > constraints.maxWidth);

                                return Stack(
                                    children: [
                                        Listener(
                                            onPointerSignal: (event) {
                                                if (event is! PointerScrollEvent) return;

                                                final offset = event.scrollDelta.dy;
                                                final position = (scrollController.offset + offset).clamp(
                                                    0, 
                                                    scrollController.position.maxScrollExtent
                                                ).toDouble();
                                                scrollController.jumpTo(position);
                                            },
                                            child: FadingEdgeScrollView.fromSingleChildScrollView(
                                                child: SingleChildScrollView(
                                                    controller: scrollController,
                                                    scrollDirection: Axis.horizontal,
                                                    child: SizedBox(
                                                        width: totalTabWidth,
                                                        child: ReorderableRow(
                                                            onReorder: (oldIndex, newIndex) {
                                                                setState(() {
                                                                    widget.tabManager.swapTabs(oldIndex, newIndex);
                                                                });
                                                            },
                                                            children: widget.tabManager.tabs.asMap().entries.map<Widget>((entry) {
                                                                final index = entry.key;
                                                                final element = entry.value;
                                                                return ContextMenuRegion(
                                                                    key: ValueKey(element),
                                                                    contextMenu: ContextMenu(
                                                                        padding: const EdgeInsets.all(8.0),
                                                                        entries: <ContextMenuEntry>[
                                                                            MenuHeader(text: element.current.title),
                                                                            const MenuDivider(),
                                                                            NokuMenuItem(
                                                                                onSelected: () {
                                                                                    final newTab = widget.tabManager.duplicateTab(element);
                                                                                    widget.tabManager.setTabAsActive(newTab);
                                                                                },
                                                                                icon: Icons.open_in_new,
                                                                                label: languageText("app_tab_duplicate"),
                                                                            )
                                                                        ],
                                                                    ),
                                                                    child: ConstrainedBox(
                                                                        constraints: BoxConstraints(
                                                                            minWidth: 128,
                                                                            maxWidth: maxTabWidth,
                                                                        ),
                                                                        child: ReorderableDragStartListener(
                                                                            index: index,
                                                                            child: NBTabWidget(
                                                                                onTap: () => widget.tabManager.setTabAsActive(element),
                                                                                tabData: element,
                                                                            ),
                                                                        ),
                                                                    ),
                                                                );
                                                            }).toList() + [
                                                                const SizedBox(width: 1.0, height: 4.0)
                                                            ],
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                        if (canScroll) ...[
                                            Positioned(
                                                left: 0,
                                                top: 0,
                                                bottom: 0,
                                                child: Padding(
                                                    padding: const EdgeInsets.only(left: 6.0),
                                                    child: Center(
                                                        child: RoundedBoxButton(
                                                            backgroundColor: Themes.accent.withAlpha(128),
                                                            icon: const Icon(Icons.chevron_left),
                                                            onTap: () => scrollTabs(-1),
                                                        ),
                                                    ),
                                                ),
                                            ),
                                            Positioned(
                                                right: 0,
                                                top: 0,
                                                bottom: 0,
                                                child: Padding(
                                                    padding: const EdgeInsets.only(right: 6.0),
                                                    child: Center(
                                                        child: RoundedBoxButton(
                                                            backgroundColor: Themes.accent.withAlpha(128),
                                                            icon: const Icon(Icons.chevron_right),
                                                            onTap: () => scrollTabs(1),
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ]
                                    ],
                                );
                            },
                        ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.0),
                        child: RoundedBoxButton(
                            icon: const Icon(Icons.add),
                            onTap: () {
                                final newTab = widget.tabManager.createNew(
                                    view: ViewHome()
                                );
                                widget.tabManager.setTabAsActive(newTab);
                            },
                        ),
                    )
                ],
            ),
        );
}