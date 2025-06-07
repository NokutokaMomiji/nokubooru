import 'package:faded_scrollable/faded_scrollable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:nokubooru/State/history.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/custom_container.dart';
import 'package:nokubooru/Widgets/General/menu_item.dart';
import 'package:nokubooru/Widgets/General/options_button.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';

class TabViewHistory extends StatefulWidget {
    final ViewHistory data;

    const TabViewHistory({required this.data, super.key});

    @override
    State<TabViewHistory> createState() => _TabViewHistoryState();
}

class _TabViewHistoryState extends State<TabViewHistory> {
    final ScrollController controller = ScrollController();
    bool shouldBlock = false;

    @override
    void initState() {
        super.initState();

        loadNextRegularDay();
        controller.addListener(onScroll);
    }

    @override
    void dispose() {
        controller.dispose();
        super.dispose();
    }

    void onScroll() {
        if (controller.position.pixels < controller.position.maxScrollExtent - 200) {
            return;
        }

        final ViewHistory data = widget.data;

        if (data.query.isEmpty) {
            if (!data.regularIsLoading && !data.regularhasReachedEnd) {
                loadNextRegularDay();
            }
        } else {
            if (!data.searchIsLoading && !data.searchHasReachedEnd) {
                loadNextSearchBatch();
            }
        }
    }

    Future<void> loadNextRegularDay() async {
        final ViewHistory data = widget.data;

        setState(() {
            data.regularIsLoading = true;
        });

        final dayHistory = await History.loadDayHistory(data.regularDayOffset);

        setState(() {
            data.addDayHistory(dayHistory);
        });
    
        if (!dayHistory.isEndOfHistory) {
            if (data.daysToShow.map((element) => element.entries.length).fold<int>(0, (current, element) => current + element) < 20) {
                loadNextRegularDay();
            }
        }
    }

    Future<void> loadNextSearchBatch() async {
        final ViewHistory data = widget.data;

        setState(() {
            data.searchIsLoading = true;
        });

        final result = await History.search(
            data.query,
            startingDayOffset: data.searchDayOffset
        );

        setState(() {
            data.setSearchState(result);
        });
    }

    void onQueryChanged(String query) {
        final ViewHistory data = widget.data;

        setState(() {
            data.query = query;
            data.clearSearch();
        });

        if (data.query.isNotEmpty) {
            loadNextSearchBatch();
        }
    }

    void onUpdate(shouldBlock) {
        if (!mounted) return;

        setState(() {
            this.shouldBlock = shouldBlock;
        });
    }

    @override
    Widget build(BuildContext context) {
        final ViewHistory data = widget.data;

        Widget actualHistoryTab = TabViewHistoryDesktop(
            data: data, 
            onQueryChanged: onQueryChanged, 
            controller: controller, 
            updateCallback: onUpdate
        );

        if (!isDesktop) {
            actualHistoryTab = TabViewHistoryMobile(
                data: data, 
                onQueryChanged: onQueryChanged, 
                controller: controller, 
                updateCallback: onUpdate
            );
        }

        return IgnorePointer(
            ignoring: shouldBlock,
            child: Stack(
                children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                        child: actualHistoryTab
                    ),
                    if (shouldBlock) Container(
                        constraints: BoxConstraints.tight(
                            MediaQuery.sizeOf(context)
                        ),
                        decoration: BoxDecoration(
                            color: Colors.black.withAlpha(128)
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                    )
                ],
            )
        );
    }
}

class TabViewHistoryDesktop extends StatelessWidget {
    final ViewHistory data;
    final void Function(String query) onQueryChanged;
    final void Function(bool shouldBlock) updateCallback;
    final ScrollController controller;

    const TabViewHistoryDesktop({
        required this.data, 
        required this.onQueryChanged, 
        required this.controller, 
        required this.updateCallback, 
        super.key
    });

    @override
    Widget build(BuildContext context) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4.0,
            children: [
                Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                        spacing: 16.0,
                        children: [
                            SearchBar(
                                controller: data.controller,
                                constraints: const BoxConstraints(
                                    minHeight: 48,
                                    maxWidth: 256
                                ),
                                trailing: [
                                    IconButton(
                                        onPressed: () => onQueryChanged(data.controller.text),
                                        icon: const Icon(Icons.search)
                                    )
                                ],
                                onSubmitted: onQueryChanged,
                            ),
                            OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        width: 2.0,
                                        color: Themes.accent,
                                    ),
                                    iconColor: Themes.accent
                                ),
                                onPressed: () {
                                    History.delete(null);
                                    data.clearRegular();
                                    data.clearSearch();
                                }, 
                                label: Text(
                                    languageText("app_delete_history"),
                                    style: TextStyle(color: Themes.accent),
                                ),
                                icon: const Icon(Icons.delete_forever),
                            )
                        ],
                    ),
                ),
                Expanded(
                    child: DayHistoryList(
                        data: data, 
                        controller: controller,
                        updateCallback: updateCallback,
                    )
                )
            ],
        );
}

class TabViewHistoryMobile extends StatelessWidget {
    final ViewHistory data;
    final void Function(String query) onQueryChanged;
    final void Function(bool shouldBlock) updateCallback;
    final ScrollController controller;

    const TabViewHistoryMobile({required this.data, required this.onQueryChanged, required this.controller, required this.updateCallback, super.key});

    @override
    Widget build(BuildContext context) => Column(
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 4.0,
            children: [
                Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                        spacing: 16.0,
                        children: [
                            Expanded(
                                child: SearchBar(
                                    controller: data.controller,
                                    constraints: const BoxConstraints(
                                        minHeight: 48,
                                        maxWidth: 256
                                    ),
                                    trailing: [
                                        IconButton(
                                            onPressed: () => onQueryChanged(data.controller.text),
                                            icon: const Icon(Icons.search)
                                        )
                                    ],
                                    onSubmitted: onQueryChanged,
                                ),
                            ),
                            OptionsButton(
                                entries: [
                                    NokuMenuItem(
                                        onSelected: () {
                                            History.delete(null);
                                            data.clearRegular();
                                            data.clearSearch();
                                        }, 
                                        label: languageText("app_delete_history"),
                                        icon: Icons.delete_forever
                                    )
                                ]
                            )
                        ],
                    ),
                ),
                Expanded(
                    child: FadedScrollable(
                        child: DayHistoryList(
                            data: data, 
                            controller: controller,
                            updateCallback: updateCallback,
                        ),
                    )
                )
            ],
        );
}

class DayHistoryList extends StatelessWidget {
    final ViewHistory data;
    final ScrollController controller;
    final void Function(bool) updateCallback;

    const DayHistoryList({required this.data, required this.controller, required this.updateCallback, super.key});

    @override
    Widget build(BuildContext context) => ListView.builder(
            controller: controller,
            itemCount: data.daysToShow.length + 1,
            itemBuilder: (context, index) {
                if (index < data.daysToShow.length) {
                    final current = data.daysToShow[index];

                    if (current.entries.isEmpty) {
                        return const SizedBox.shrink();
                    }

                    return DayHistoryWidget(
                        dayHistory: current,
                        data: data,
                        updateCallback: updateCallback,
                        parent: context,
                    );
                }

                if (data.hasReachedEnd) {
                    return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(child: Text(languageText("app_reached_end"))),
                    );
                }

                if (data.isLoading) {
                    return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                    );
                }

                return const SizedBox.shrink();
            }
        );
}

class DayHistoryWidget extends StatefulWidget {
    final DayHistory dayHistory;
    final ViewHistory data;
    final void Function(bool shouldBlock) updateCallback;
    final BuildContext parent;

    const DayHistoryWidget({required this.dayHistory, required this.data, required this.updateCallback, required this.parent, super.key});

    @override
    State<DayHistoryWidget> createState() => _DayHistoryWidgetState();
}

class _DayHistoryWidgetState extends State<DayHistoryWidget> {
    @override
    Widget build(BuildContext context) {
        final isToday = widget.dayHistory.day.isToday;
        final isYesterday = widget.dayHistory.day.isYesterday;

        return CustomContainer(
            padding: const EdgeInsets.all(8.0),
            itemPadding: const EdgeInsets.all(16.0),
            borderRadius: const BorderRadius.all(Radius.circular(16.0)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text.rich(
                        TextSpan(
                            children: [
                                if (isYesterday || isToday) TextSpan(
                                    text: "${languageText((isToday) ? "app_today" : "app_yesterday")} - "
                                ),
                                TextSpan(
                                    text: languageText("app_weekday_${widget.dayHistory.day.weekday}")
                                ),
                                const TextSpan(
                                    text: ", "
                                ),
                                TextSpan(
                                    text: languageText("app_date_format").replaceAll(
                                        "[month]",
                                        languageText("app_month_${widget.dayHistory.day.month}")
                                    ).replaceAll(
                                        "[day]", 
                                        widget.dayHistory.day.day.toString().padLeft(2, '0')
                                    ).replaceAll(
                                        "[year]",
                                        widget.dayHistory.day.year.toString()
                                    )
                                )
                            ]
                        ),
                        style: TextStyle(
                            fontSize: 21,
                            color: Themes.accent   
                        ),
                    ),
                    if (widget.dayHistory.entries.isEmpty) Center(child: Text(languageText("app_no_history"))),
                    ...widget.dayHistory.entries.map(
                        (entry) => Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ContextMenuRegion(
                                    contextMenu: ContextMenu(
                                        padding: const EdgeInsets.all(8.0),
                                        entries: <ContextMenuEntry>[
                                            MenuHeader(text: entry.title),
                                            const MenuDivider(),
                                            NokuMenuItem(
                                                label: "Copy URL",
                                                icon: Icons.link,
                                                onSelected: () {
                                                    Clipboard.setData(ClipboardData(text: entry.url));
                                                }
                                            ),
                                            NokuMenuItem(
                                                label: "Delete.",
                                                icon: Icons.delete_forever,
                                                onSelected: () {
                                                    setState(() {
                                                        History.deleteEntry(entry);
                                                    });
                                                }
                                            )
                                        ]
                                    ),
                                    child: Material(
                                        type: MaterialType.transparency,
                                        borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                                        clipBehavior: Clip.antiAlias,
                                        child: ListTile(
                                            onTap: () async {
                                                switch (entry.type) {
                                                    case ViewType.search:
                                                        widget.data.tab!.push(
                                                            ViewSearch.fromMap(data: entry.data)
                                                        );
                                                        break;
                                        
                                                    case ViewType.post:
                                                        widget.updateCallback(true);
                                                        final post = await ViewPost.fromMapHistory(data: entry.data) ?? ViewError();
                                                        if (widget.data.tab!.manager.tabs.contains(widget.data.tab!) == true) {
                                                            widget.data.tab!.push(post);
                                                        }
                                                        widget.updateCallback(false);
                                                        break;
                                        
                                                    case ViewType.viewer:
                                                        widget.updateCallback(true);
                                                        final post = await ViewViewer.fromMapHistory(data: entry.data) ?? ViewError();
                                                        if (widget.data.tab!.manager.tabs.contains(widget.data.tab!)) {
                                                            widget.data.tab!.push(post);
                                                        }
                                                        widget.updateCallback(false);
                                                        break;
                                                
                                                    default:
                                                        return;
                                                }
                                            },
                                            leading: CircleAvatar(
                                                backgroundImage: (entry.thumb != null) ? () {
                                                    try {
                                                        return Image.network(
                                                            entry.thumb!,
                                                            headers: entry.headers,
                                                            alignment: imageAlignment,
                                                        ).image;
                                                    } catch (e) {
                                                        return null;
                                                    }
                                                }() : null
                                            ),
                                            title: Text(
                                                entry.title
                                            ),
                                            subtitle: Text(
                                                entry.url,
                                                style: TextStyle(
                                                    color: Theme.of(context).secondaryHeaderColor
                                                ),
                                            ),
                                            trailing: Text("${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}"),
                                        ),
                                    ),
                                )
                            )
                    ),
                ],
            ),
        );
    }
}
