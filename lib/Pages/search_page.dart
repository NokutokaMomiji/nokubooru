import 'package:collection/collection.dart';
import 'package:faded_scrollable/faded_scrollable.dart';
import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:nokubooru/State/searcher.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/tags.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/collapsable_container.dart';
import 'package:nokubooru/Widgets/General/custom_container.dart';
import 'package:nokubooru/Widgets/General/menu_item.dart';
import 'package:nokubooru/Widgets/General/rounded_box_button.dart';
import 'package:nokubooru/Widgets/General/stopwatch_builder.dart';
import 'package:nokubooru/Widgets/Post/tag_button.dart';
import 'package:nokubooru/Widgets/General/post_grid.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';

enum SearchSortMode {
    bySource,
    byID,
    byFavorites,
    byRating
}

Map<SearchSortMode, String> sortLabels = {
    SearchSortMode.bySource: "By Source",
    SearchSortMode.byID: "By ID",
    SearchSortMode.byFavorites: "By Favorite Tags",
    SearchSortMode.byRating: "By Rating",
};

SearchSortMode mode = SearchSortMode.bySource;
bool ascending = false;

class TabViewSearch extends StatefulWidget {
    final ViewSearch data;

    const TabViewSearch({super.key, required this.data});

    @override
    State<TabViewSearch> createState() => _TabViewSearchState();
}

class _TabViewSearchState extends State<TabViewSearch> {
    Widget result = const Placeholder();

    late ViewSearch data;
    late ScrollController controller;

    @override
    void initState() {
        super.initState();
        data = widget.data;

        controller = ScrollController();
    }

    @override
    void didUpdateWidget(covariant TabViewSearch oldWidget) {
        super.didUpdateWidget(oldWidget);

        if (oldWidget.data != widget.data) {
            data = widget.data;
        }
    }

    @override
    void dispose() {
        controller.dispose();
        super.dispose();
    }

    void sortResults(List<Post> posts) {
        switch (mode) {
            case SearchSortMode.bySource:
                return;

            case SearchSortMode.byID:
                posts.sort((first, second) {
                    return first.postID.compareTo(second.postID);
                });
                break;

            case SearchSortMode.byRating:
                posts.sort((first, second) {
                    return first.rating.index.compareTo(second.rating.index);
                });
                break;

            case SearchSortMode.byFavorites:
                posts.sort((first, second) {
                    final firstCommon = first.tags.where((tag) => Tags.isFavorite(tag));
                    final secondCommon = second.tags.where((tag) => Tags.isFavorite(tag));

                    return secondCommon.length - firstCommon.length;
                });
                break;
        }
    }

    void constructDesktop() {
        Future.wait(data.queryResults.map((element) => element.recheckTags()));

        final tags = List<Tag>.from(data.tags.where((tag) => !Settings.blacklist.value.contains(tag.original)))..sort(compareTags);
        final blacklisted = data.queryResults.where(
            (post) => hasCommonElement(
                post.tags.map((tag) => tag.original).toList(), 
                Settings.blacklist.value
            )
        ).toList();

        final displayResults = Finder.filterByMD5(
            data.queryResults.where((element) => !blacklisted.contains(element)).toList(),
        );

        sortResults(displayResults);

        if (ascending) {
            displayResults.reverseRange(0, displayResults.length);
        }

        result = Row(
            children: [
                CollapsableContainer(
                    child: Column(
                        spacing: 8.0,
                        children: [
                            Text.rich(
                                TextSpan(
                                    children: [
                                        const WidgetSpan(
                                            child: Padding(
                                                padding: EdgeInsets.only(right: 4.0),
                                                child: Icon(Icons.search),
                                            ),
                                            alignment: PlaceholderAlignment.middle
                                        ),
                                        TextSpan(
                                            text: languageText("app_search")
                                        )
                                    ]
                                ),
                                style: const TextStyle(
                                    fontSize: 21.0,
                                    fontWeight: FontWeight.bold
                                )
                            ),
                            SearchInfoNavigation(data: data, blacklisted: blacklisted),
                            Divider(
                                color: Theme.of(context).secondaryHeaderColor,
                            ),
                            Expanded(
                                child: TagList(
                                    tags: tags, 
                                    data: data
                                )
                            )
                        ],
                    ),
                ),
                Padding(
                    padding: const EdgeInsets.only(top: 16.0, left: 8.0, bottom: 16.0),
                    child: VerticalDivider(
                        indent: 4,
                        endIndent: 4,
                        color: Theme.of(context).secondaryHeaderColor,
                    ),
                ),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                spacing: 8.0,
                                children: [
                                    SafeArea(
                                        child: DropdownButton<SearchSortMode>(
                                            value: mode,
                                            items: sortLabels.entries
                                                .map((entry) => DropdownMenuItem<SearchSortMode>(
                                                    value: entry.key,
                                                    child: Text(entry.value),
                                                ))
                                                .toList(),
                                            onChanged: (selected) {
                                                if (selected == mode) return;

                                                setState(() {
                                                    mode = selected ?? mode;
                                                });
                                            },
                                        ),
                                    ),
                                    SafeArea(
                                        child: DropdownButton<bool>(
                                            value: ascending,
                                            items: const [
                                                DropdownMenuItem<bool>(
                                                    value: false,
                                                    child: Text("Descending"),
                                                ),
                                                DropdownMenuItem<bool>(
                                                    value: true,
                                                    child: Text("Ascending"),
                                                ),
                                            ],
                                            onChanged: (value) {
                                                setState(() {
                                                    ascending = value ?? ascending;
                                                });
                                            },
                                        )
                                    ),
                                ]
                            ),
                            Expanded(
                                child: FadedScrollable(
                                    child: PostGrid(
                                        posts: displayResults,
                                        data: data.tab!,
                                        scrollKey: PageStorageKey<String>("gridController${data.queryResults.hashCode}"),
                                    ),
                                ),
                            )
                        ],
                    )
                ),
            ],
        );
    }

    void constructMobile() {
        Future.wait(data.queryResults.map((element) => element.recheckTags()));

        final tags = List<Tag>.from(data.tags.where((tag) => !Settings.blacklist.value.contains(tag.original)))..sort(compareTags);
        final blacklisted = data.queryResults.where(
            (post) => hasCommonElement(
                post.tags.map((tag) => tag.original).toList(), 
                Settings.blacklist.value
            )
        ).toList();

        final displayResults = Finder.filterByMD5(
            data.queryResults.where((element) => !blacklisted.contains(element)).toList(),
        );

        result = FadingEdgeScrollView.fromScrollView(
            child: CustomScrollView(
                key: PageStorageKey<String>("scrollViewController${widget.data.hashCode}"),
                controller: controller,
                slivers: [
                    PostGrid(
                        posts: displayResults,
                        asSliver: true,
                        data: data.tab!,
                        scrollKey: PageStorageKey<String>("gridController${data.queryResults.hashCode}"),
                    ),
                    SliverPadding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        sliver: CustomSliverContainer(
                            sliver: MultiSliver(
                                children: [
                                    SliverPadding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        sliver: SliverToBoxAdapter(
                                            child: SearchInfoNavigation(data: data, blacklisted: blacklisted),
                                        ),
                                    ),
                                    SliverPadding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                        sliver: TagList(
                                            tags: tags,
                                            data: data,
                                            asSliver: true
                                        ),
                                    )
                                ]
                            )
                        ),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 48.0)) // Temporary measure to avoid bottom UI.
                ].map((element) => SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 8.0), sliver: element)).toList(),
            ),
        );
    }

    @override
    Widget build(BuildContext context) {
        if (isDesktop) {
            constructDesktop();
        } else {
            constructMobile();
        }

        if (widget.data.isComplete) {
            return result;
        }

        return FutureBuilder(
            future: widget.data.searchFuture, 
            builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done || (snapshot.connectionState == ConnectionState.none && widget.data.isComplete)) {
                    if (isDesktop) {
                        constructDesktop();
                    } else {
                        constructMobile();
                    }   
                    return result;
                }

                return Center(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 8.0,
                        children: [
                            const CircularProgressIndicator(),
                            StopwatchBuilder(
                                stopwatch: widget.data.stopwatch, 
                                builder: (context, elapsed) => Text.rich(
                                    TextSpan(
                                        text: "${(elapsed.inMilliseconds / 1000).toStringAsFixed(2)}s",
                                        style: const TextStyle(
                                            shadows: [
                                                Shadow(
                                                    offset: Offset(4.0, 4.0),
                                                    blurRadius: 32.0
                                                )
                                            ]
                                        )
                                    ),
                                    textAlign: TextAlign.center,
                                ),
                            )
                        ],
                    ) 
                );
            },
        );
    }
}

class SearchInfoNavigation extends StatefulWidget {
    final ViewSearch data;
    final List<Post> blacklisted;

    const SearchInfoNavigation({required this.data, required this.blacklisted, super.key});

    @override
    State<SearchInfoNavigation> createState() => _SearchInfoNavigationState();
}

class _SearchInfoNavigationState extends State<SearchInfoNavigation> {
    void goToPrevious(TabData? data) {
        if (data != null) {
            data.push(
                ViewSearch(
                    searchFuture: Searcher.searchPosts(
                        widget.data.query,
                        optionalTags: widget.data.optionalTags,
                        blacklist: widget.data.blacklist,
                        page: widget.data.page - 1,
                        client: widget.data.tab!.client
                    ),
                    query: widget.data.query,
                    optionalTags: widget.data.optionalTags,
                    blacklist: widget.data.blacklist,
                    page: widget.data.page - 1,
                )
            );
            return;
        }

        final tab = widget.data.tab!.manager.createNew(
            view: ViewSearch(
                searchFuture: Searcher.searchPosts(
                    widget.data.query,
                    optionalTags: widget.data.optionalTags,
                    blacklist: widget.data.blacklist,
                    page: widget.data.page - 1,
                    client: widget.data.tab!.client
                ),
                query: widget.data.query,
                optionalTags: widget.data.optionalTags,
                blacklist: widget.data.blacklist,
                page: widget.data.page - 1,
            ),
            notify: true,
            after: widget.data.tab!
        );

        if (!isDesktop) {
            widget.data.tab!.manager.setTabAsActive(tab);
        }
    }

    void goToNext(TabData? data) {
        if (data != null) {
            data.push(
                ViewSearch(
                    searchFuture: Searcher.searchPosts(
                        widget.data.query,
                        optionalTags: widget.data.optionalTags,
                        blacklist: widget.data.blacklist,
                        page: widget.data.page + 1,
                        client: widget.data.tab!.client
                    ),
                    query: widget.data.query,
                    optionalTags: widget.data.optionalTags,
                    blacklist: widget.data.blacklist,
                    page: widget.data.page + 1,
                )
            );
            return;
        }

        final tab = widget.data.tab!.manager.createNew(
            view: ViewSearch(
                searchFuture: Searcher.searchPosts(
                    widget.data.query,
                    optionalTags: widget.data.optionalTags,
                    blacklist: widget.data.blacklist,
                    page: widget.data.page + 1,
                    client: widget.data.tab!.client
                ),
                query: widget.data.query,
                optionalTags: widget.data.optionalTags,
                blacklist: widget.data.blacklist,
                page: widget.data.page + 1,
            ),
            notify: true,
            after: widget.data.tab!
        );

        if (!isDesktop) {
            widget.data.tab!.manager.setTabAsActive(tab);
        }
    }
    
    @override
    Widget build(BuildContext context) {
        ContextMenu getContextMenu(void Function(TabData? data) func, bool enabled) => ContextMenu(
                padding: const EdgeInsets.all(8.0),
                entries: [
                    NokuMenuItem(
                        onSelected: (enabled) ? () => func(null) : null,
                        label: languageText("app_open_on_new_tab"),
                        icon: Icons.open_in_new
                    )
                ]
            );

        final bool couldHaveMorePages = (widget.data.queryResults.length >= Settings.limit.value);

        return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8.0,
            children: [
                Text.rich(
                    TextSpan(
                        children: [
                            TextSpan(
                                text: languageText("app_search_result", [widget.data.queryResults.length, "${widget.data.elapsed.inSeconds}s"])
                            ),
                            if (widget.blacklisted.isNotEmpty) TextSpan(
                                text: "\n${languageText("app_search_blacklisted", [widget.blacklisted.length])}",
                                style: TextStyle(
                                    color: Theme.of(context).secondaryHeaderColor
                                )
                            )
                        ]
                    ),
                    textAlign: TextAlign.center,
                ),
                Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 8.0,
                    children: [
                        ContextMenuRegion(
                            contextMenu: getContextMenu(goToPrevious, (widget.data.page > 0)),
                            child: RoundedBoxButton(
                                padding: const EdgeInsets.all(2.0),
                                backgroundColor: Colors.transparent,
                                onTap: (widget.data.page == 0) ? null : () => goToPrevious(widget.data.tab!), 
                                icon: Icon(
                                    Icons.chevron_left,
                                    color: (widget.data.page > 0) ? null : Theme.of(context).disabledColor,
                                )
                            ),
                        ),
                        Text((widget.data.page + 1).toString()),
                        ContextMenuRegion(
                            contextMenu: getContextMenu(goToPrevious, couldHaveMorePages),
                            child: RoundedBoxButton(
                                padding: const EdgeInsets.all(2.0),
                                backgroundColor: Colors.transparent,
                                onTap: (!couldHaveMorePages) ? null : () => goToNext(widget.data.tab!),
                                icon: Icon(
                                    Icons.chevron_right,
                                    color: (couldHaveMorePages) ? null : Theme.of(context).disabledColor,
                                )
                            ),
                        ),
                        if (widget.blacklisted.isNotEmpty) ConstrainedBox(
                            constraints: BoxConstraints.tight(const Size.square(24.0)),
                            child: const VerticalDivider()
                        ),
                        if (widget.blacklisted.isNotEmpty) RoundedBoxButton(
                            backgroundColor: Colors.transparent,
                            onTap: () {
                                showDialog(
                                    context: context, 
                                    builder: (context) => BlacklistedPostsDialog(blacklisted: widget.blacklisted, data: widget.data.tab!),
                                );
                            },
                            icon: const Icon(Icons.disabled_by_default)
                        )
                    ],
                )
            ],
        );
    }
}

class BlacklistedPostsDialog extends StatelessWidget {
    final TabData data;
    final List<Post> blacklisted;

    const BlacklistedPostsDialog({required this.data, required this.blacklisted, super.key});

    @override
    Widget build(BuildContext context) {
        final blacklistedTags = <Tag>{};
        for (final post in blacklisted) {
            blacklistedTags.addAll(post.tags.where((tag) => Settings.blacklist.value.contains(tag.original)));
        }

        return Dialog(
            backgroundColor: Colors.transparent,
            child: CustomContainer(
                padding: const EdgeInsets.all(8.0),
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                child: LayoutBuilder(
                    builder: (context, constraints) {
                        final firstWidget = Expanded(
                            child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: FadedScrollable(
                                    child: PostGrid(
                                        posts: blacklisted,
                                        data: data,
                                    ),
                                ),
                            ),
                        );
                        
                        final secondWidget = Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: FadedScrollable(
                                child: TagList(
                                    tags: blacklistedTags.toList(),
                                    data: data.current as ViewSearch
                                ),
                            ),
                        );
                         
                         if ((constraints.maxWidth / constraints.maxHeight) < 1) {
                            return Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                spacing: 8.0,
                                children: [
                                    firstWidget,
                                    const Divider(),
                                    ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxHeight: 256
                                        ),
                                        child: secondWidget
                                    )
                                ],
                            );
                        }
                
                        return Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 8.0,
                            children: [
                                firstWidget,
                                const VerticalDivider(),
                                ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxWidth: 256
                                    ),
                                    child: secondWidget
                                )
                            ]
                        );
                    },
                )
            ),
        );
    }
}

class TagList extends StatelessWidget {
    final List<Tag> tags;
    final ViewSearch data;
    final bool asSliver;
    
    const TagList({
        required this.tags,
        required this.data,
        this.asSliver = false,
        super.key
    });

    @override
    Widget build(BuildContext context) {
        if (asSliver) {
            return SliverList.builder(
                itemCount: tags.length,
                itemBuilder: (context, index) => TagButton(
                        tag: tags[index], 
                        tabData: data.tab!
                    ),
            );
        }

        return DynMouseScroll(
            builder: (context, controller, physics) => FadingEdgeScrollView.fromScrollView(
                    child: ListView.builder(
                        controller: controller,
                        physics: physics,
                        itemCount: tags.length,
                        itemBuilder: (context, index) => TagButton(
                                tag: tags[index], 
                                tabData: data.tab!
                            ),
                    ),
                ),
        );
    }
}