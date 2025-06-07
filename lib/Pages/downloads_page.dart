import 'package:faded_scrollable/faded_scrollable.dart';
import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:nokubooru/State/download_manager.dart';
import 'package:nokubooru/State/downloads.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/custom_container.dart';
import 'package:nokubooru/Widgets/General/download_card.dart';
import 'package:nokubooru/Widgets/General/menu_item.dart';
import 'package:nokubooru/Widgets/General/options_button.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';
import 'package:url_launcher/url_launcher.dart';

class TabViewDownloads extends StatefulWidget {
    final ViewDownloads data;

    const TabViewDownloads({required this.data, super.key});

    @override
    State<TabViewDownloads> createState() => _TabViewDownloadsState();
}

class _TabViewDownloadsState extends State<TabViewDownloads> {
    final ScrollController controller = ScrollController();
    bool shouldBlock = false;

    @override
    void initState() {
        super.initState();
        _loadNextRegularDay();
        controller.addListener(_onScroll);
    }

    @override
    void dispose() {
        controller.dispose();
        super.dispose();
    }

    void _onScroll() {
        if (controller.position.pixels < controller.position.maxScrollExtent - 200) {
            return;
        }

        final data = widget.data;
        if (data.query.isEmpty) {
            if (!data.regularIsLoading && !data.regularHasReachedEnd) {
                _loadNextRegularDay();
            }
        } else {
            if (!data.searchIsLoading && !data.searchHasReachedEnd) {
                _loadNextSearchBatch();
            }
        }
    }

    Future<void> _loadNextRegularDay() async {
        final data = widget.data;
        setState(() {
            data.regularIsLoading = true;
        });

        final DayDownloads dayDownloads =
            await Downloads.loadDayDownloads(data.regularDayOffset);

        setState(() {
            data.addDayDownloads(dayDownloads);
        });

        if (!dayDownloads.isEndOfHistory) {
            final totalEntriesSoFar = data.daysToShow
                .map((d) => d.entries.length)
                .fold<int>(0, (a, b) => a + b);
            if (totalEntriesSoFar < 20) {
                _loadNextRegularDay();
            }
        }
    }

    Future<void> _loadNextSearchBatch() async {
        final data = widget.data;
        setState(() {
            data.searchIsLoading = true;
        });

        final DownloadSearch result = await Downloads.search(
            data.query,
            startingDayOffset: data.searchDayOffset,
        );

        setState(() {
            data.addSearchResult(result);
        });
    }

    void _onQueryChanged(String query) {
        final data = widget.data;
        setState(() {
            data.query = query;
            data.clearSearch();
        });

        if (query.isNotEmpty) {
            _loadNextSearchBatch();
        }
    }

    void _onUpdate(bool block) {
        if (!mounted) return;
        setState(() {
            shouldBlock = block;
        });
    }

    List<DownloadRecord> get _sessionDownloads =>
        DownloadManager.history;

    @override
    Widget build(BuildContext context) {
        final data = widget.data;

        Widget actualTab = TabViewDownloadsDesktop(
            data: data,
            onQueryChanged: _onQueryChanged,
            controller: controller,
            updateCallback: _onUpdate,
            sessionDownloads: _sessionDownloads,
        );

        if (!isDesktop) {
            actualTab = TabViewDownloadsMobile(
                data: data,
                onQueryChanged: _onQueryChanged,
                controller: controller,
                updateCallback: _onUpdate,
                sessionDownloads: _sessionDownloads,
            );
        }

        return IgnorePointer(
            ignoring: shouldBlock,
            child: Stack(
                children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                        child: actualTab,
                    ),
                    if (shouldBlock) Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black.withAlpha(128),
                        child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
            ),
        );
    }
}

class TabViewDownloadsDesktop extends StatelessWidget {
    final ViewDownloads data;
    final void Function(String query) onQueryChanged;
    final void Function(bool) updateCallback;
    final ScrollController controller;
    final List<DownloadRecord> sessionDownloads;

    const TabViewDownloadsDesktop({
        required this.data,
        required this.onQueryChanged,
        required this.controller,
        required this.updateCallback,
        required this.sessionDownloads,
        super.key,
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
                                    Downloads.delete(null);
                                    data.clearRegular();
                                    data.clearSearch();
                                },
                                icon: const Icon(Icons.delete_forever),
                                label: Text(
                                    languageText("app_delete_downloads"),
                                    style: TextStyle(color: Themes.accent),
                                ),
                            )
                        ],
                    ),
                ),
                Expanded(
                    child: _CombinedDownloadsList(
                        data: data,
                        controller: controller,
                        updateCallback: updateCallback,
                        sessionDownloads: sessionDownloads,
                    ),
                )
            ],
        );
}

class TabViewDownloadsMobile extends StatelessWidget {
    final ViewDownloads data;
    final void Function(String query) onQueryChanged;
    final void Function(bool) updateCallback;
    final ScrollController controller;
    final List<DownloadRecord> sessionDownloads;

    const TabViewDownloadsMobile({
        required this.data,
        required this.onQueryChanged,
        required this.controller,
        required this.updateCallback,
        required this.sessionDownloads,
        super.key,
    });

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
                                            Downloads.delete(null);
                                            data.clearRegular();
                                            data.clearSearch();
                                        },
                                        label: languageText("app_delete_downloads"),
                                        icon: Icons.delete_forever
                                    )
                                ]
                            )
                        ],
                    ),
                ),
                Expanded(
                    child: FadedScrollable(
                        child: _CombinedDownloadsList(
                            data: data,
                            controller: controller,
                            updateCallback: updateCallback,
                            sessionDownloads: sessionDownloads,
                        ),
                    ),
                )
            ],
        );
}

class _CombinedDownloadsList extends StatelessWidget {
    final ViewDownloads data;
    final ScrollController controller;
    final void Function(bool) updateCallback;
    final List<DownloadRecord> sessionDownloads;

    const _CombinedDownloadsList({
        required this.data,
        required this.controller,
        required this.updateCallback,
        required this.sessionDownloads,
    });

    @override
    Widget build(BuildContext context) {
        final List<Widget> items = [];

        if (sessionDownloads.isNotEmpty) {
            items.add(
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Text(
                        languageText("app_active_downloads"),
                        style: Theme.of(context).textTheme.titleMedium,
                    ),
                ),
            );
            items.add(
                SizedBox(
                    height: 266,
                    child: ListView.separated(
                        reverse: true,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        itemCount: sessionDownloads.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8.0),
                        itemBuilder: (context, i) => SizedBox(
                            child: DownloadCard(
                                record: sessionDownloads[i],
                            ),
                        ),
                    ),
                ),
            );
            items.add(const Divider(height: 24));
        }

        for (final day in data.daysToShow) {
            if (day.entries.isEmpty) continue;
            items.add(
                DayDownloadsWidget(
                    dayDownloads: day,
                    data: data,
                    updateCallback: updateCallback,
                    parentContext: context,
                ),
            );
        }

        if (data.hasReachedEnd) {
            items.add(
                Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: Text(languageText("app_reached_end"))),
                ),
            );
        } else if (data.isLoading) {
            items.add(
                const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                ),
            );
        } else {
            items.add(const SizedBox(height: 16.0));
        }

        return FadingEdgeScrollView.fromScrollView(
            child: ListView(
                controller: controller,
                children: items,
            ),
        );
    }
}

class DayDownloadsWidget extends StatefulWidget {
    final DayDownloads dayDownloads;
    final ViewDownloads data;
    final void Function(bool) updateCallback;
    final BuildContext parentContext;

    const DayDownloadsWidget({
        required this.dayDownloads,
        required this.data,
        required this.updateCallback,
        required this.parentContext,
        super.key,
    });

    @override
    State<DayDownloadsWidget> createState() => _DayDownloadsWidgetState();
}

class _DayDownloadsWidgetState extends State<DayDownloadsWidget> {
    @override
    Widget build(BuildContext context) {
        final day = widget.dayDownloads.day;
        final isToday = day.isToday;
        final isYesterday = day.isYesterday;

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
                                if (isYesterday || isToday)
                                    TextSpan(
                                        text:
                                            "${languageText(isToday ? "app_today" : "app_yesterday")} - ",
                                    ),
                                TextSpan(
                                    text: languageText(
                                        "app_weekday_${widget.dayDownloads.day.weekday}"),
                                ),
                                const TextSpan(text: ", "),
                                TextSpan(
                                    text: languageText("app_date_format")
                                        .replaceAll(
                                            "[month]",
                                            languageText(
                                                "app_month_${widget.dayDownloads.day.month}"),
                                        )
                                        .replaceAll(
                                            "[day]",
                                            widget.dayDownloads.day.day
                                                .toString()
                                                .padLeft(2, '0'),
                                        )
                                        .replaceAll(
                                            "[year]",
                                            widget.dayDownloads.day.year.toString(),
                                        ),
                                ),
                            ],
                        ),
                        style: TextStyle(
                            fontSize: 21,
                            color: Themes.accent,
                        ),
                    ),

                    if (widget.dayDownloads.entries.isEmpty)
                        Center(child: Text(languageText("app_no_downloads"))),

                    ...widget.dayDownloads.entries.map((entry) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ContextMenuRegion(
                                contextMenu: ContextMenu(
                                    padding: const EdgeInsets.all(8.0),
                                    entries: <ContextMenuEntry>[
                                        MenuHeader(text: entry.title),
                                        const MenuDivider(),
                                        NokuMenuItem(
                                            label: "Open in File Manager",
                                            icon: Icons.folder_open,
                                            onSelected: () {
                                                if (entry.path != null) {
                                                    launchUrl(Uri.parse("file:///${entry.path}"));
                                                }
                                            },
                                        ),
                                        NokuMenuItem(
                                            label: "Copy Path",
                                            icon: Icons.copy,
                                            onSelected: () {
                                                if (entry.path != null) {
                                                    Clipboard.setData(ClipboardData(text: entry.path!));
                                                }
                                            },
                                        ),
                                        NokuMenuItem(
                                            label: languageText("app_delete"),
                                            icon: Icons.delete_forever,
                                            onSelected: () {
                                                setState(() {
                                                    Downloads.deleteEntry(entry);
                                                    widget.dayDownloads.entries.remove(entry);
                                                });
                                            },
                                        ),
                                    ],
                                ),
                                child: Material(
                                    color: Colors.transparent,
                                    borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                                    clipBehavior: Clip.antiAlias,
                                    child: DownloadCard(
                                        record: entry,
                                        style: DownloadCardStyle.chip,
                                    ),
                                ),
                            ),
                        )
                    ),
                ],
            ),
        );
    }
}
