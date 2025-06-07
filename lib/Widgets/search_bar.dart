import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:nokubooru/Pages/log_page.dart';
import 'package:nokubooru/Pages/mobile_tab_page.dart';
import 'package:nokubooru/State/download_manager.dart';
import 'package:nokubooru/State/favorites.dart';
import 'package:nokubooru/State/notify.dart';
import 'package:nokubooru/State/searcher.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tab_manager.dart';
import 'package:nokubooru/State/tags.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/download_card.dart';
import 'package:nokubooru/Widgets/General/menu_item.dart';
import 'package:nokubooru/Widgets/General/options_button.dart';
import 'package:nokubooru/Widgets/General/padded_widget.dart';
import 'package:nokubooru/Widgets/General/rounded_box_button.dart';
import 'package:nokubooru/Widgets/search_bar_controller.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';

class NBSearchBar extends StatefulWidget {
    final TabManager manager;
    final NBSearchBarController controller;

    const NBSearchBar({required this.manager, required this.controller, super.key});

    @override
    State<NBSearchBar> createState() => _NBSearchBarState();
}

class _NBSearchBarState extends State<NBSearchBar> {
    @override
    void initState() {
        super.initState();
        // Listen to controller changes.
        widget.controller.addListener(_onControllerUpdate);
    }

    @override
    void dispose() {
        widget.controller.removeListener(_onControllerUpdate);
        super.dispose();
    }

    void _onControllerUpdate() {
        if (!widget.controller.isVisible) {
            FocusScope.of(context).unfocus();
        }

        if (mounted) setState(() {});
    }

    @override
    Widget build(BuildContext context) {
        final manager = widget.manager;

        final mainContainer = Container(
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0),
                ),
                boxShadow: const [
                    BoxShadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 32.0,
                    )
                ],
                color: Theme.of(context).cardColor,
            ),
            child: SafeArea(
                minimum: (!isDesktop) ? const EdgeInsets.only(top: 22.0) : EdgeInsets.zero,
                child: PaddedWidget(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 32),
                        child: Row(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: (isDesktop)
                                        ? SearchBarNavigation(manager: manager)
                                        : const SizedBox.shrink(),
                                ),
                                Expanded(
                                    flex: 2,
                                    child: StreamBuilder(
                                        stream: manager.stream,
                                        builder: (context, snapshot) => SearchTagBar(
                                                controller: manager.active.searchBarInput,
                                                trailing: [
                                                    RoundedBoxButton(
                                                        onTap: () {
                                                            final query = manager.active.searchBarInput.text.trim();
                                                            final lowerQuery = query.toLowerCase();

                                                            if (lowerQuery.startsWith("https") || lowerQuery.startsWith("http") || lowerQuery.startsWith("nokubooru")) {
                                                                manager.active.handleURL(Uri.parse(query));
                                                                return;
                                                            }

                                                            manager.active.search(manager.active.searchBarInput.text);
                                                        },
                                                        icon: const Icon(Icons.search),
                                                    ),
                                                    const Padding(padding: EdgeInsets.symmetric(horizontal: 2.0)),
                                                    SearchFavoriteButton(
                                                        manager: manager,
                                                        asBox: true,
                                                    )
                                                ],
                                                leading: SafeArea(
                                                    child: MenuAnchor(
                                                        menuChildren: [
                                                            MenuItemButton(
                                                                onPressed: () {
                                                                    setState(() {
                                                                        widget.manager.active.client = null;
                                                                    });
                                                                },
                                                                child: const Align(
                                                                    alignment: Alignment.center,
                                                                    child: CircleAvatar(
                                                                        radius: 12.0,
                                                                        child: Icon(Icons.search),
                                                                    ),
                                                                ),
                                                            ),
                                                            for (final client in Searcher.enabledSubfinders)
                                                                MenuItemButton(
                                                                    onPressed: () {
                                                                        setState(() {
                                                                            widget.manager.active.client = client;
                                                                        });
                                                                    },
                                                                    child: Align(
                                                                        alignment: Alignment.center,
                                                                        child: CircleAvatar(
                                                                            radius: 12.0,
                                                                            backgroundImage: Image.asset("assets/$client.png").image,
                                                                            backgroundColor: Colors.transparent,
                                                                        ),
                                                                    ),
                                                                )
                                                        ],
                                                        builder: (context, controller, child) => Material(
                                                                type: MaterialType.transparency,
                                                                child: InkWell(
                                                                    radius: 64,
                                                                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                                                                    onTap: () {
                                                                        final func = (controller.isOpen) ? controller.close : controller.open;
                                                                        func();
                                                                    },
                                                                    child: CircleAvatar(
                                                                        radius: 12.0,
                                                                        backgroundImage: (widget.manager.active.client != null)
                                                                            ? Image.asset("assets/${widget.manager.active.client}.png").image
                                                                            : null,
                                                                        backgroundColor: Colors.transparent,
                                                                        child: (widget.manager.active.client == null)
                                                                            ? const Icon(
                                                                                Icons.search,
                                                                                color: Themes.white,
                                                                            )
                                                                            : null,
                                                                    ),
                                                                ),
                                                            ),
                                                    ),
                                                ),
                                                onSubmitted: (query) {
                                                    final lowerQuery = query.toLowerCase();

                                                    if (lowerQuery.startsWith("https") || lowerQuery.startsWith("http") || lowerQuery.startsWith("nokubooru")) {
                                                        manager.active.handleURL(Uri.parse(query));
                                                        return;
                                                    }
                                                    
                                                    manager.active.search(query);
                                                },
                                            ),
                                    ),
                                ),
                                Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: SearchBarTools(manager: manager),
                                )
                            ],
                        ),
                    ),
                ),
            ),
        );

        return (widget.controller.isFixed) ? mainContainer : ClipRect(
            clipBehavior: (widget.controller.isVisible) ? Clip.none : Clip.hardEdge,
            child: AnimatedSize(
                duration: const Duration(milliseconds: 500),
                curve: Curves.fastEaseInToSlowEaseOut,
                child: SizedBox(
                    height: widget.controller.isVisible ? null : 0.0,
                    child: AnimatedSlide(
                        offset: widget.controller.isVisible ? Offset.zero : const Offset(0, -1),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.fastEaseInToSlowEaseOut,
                        child: mainContainer
                    ),
                ),
            ),
        );
    }
}

class SearchBarNavigation extends StatelessWidget {
    final TabManager manager;
    final MainAxisAlignment? alignment;
    
    const SearchBarNavigation({required this.manager, this.alignment, super.key});

    @override
    Widget build(BuildContext context) {
        return Material(
            type: MaterialType.transparency,
            child: InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(4.0)),
                hoverColor: Themes.accent.withAlpha(128),
                onTap: () {},
                child: Row(
                    spacing: 4.0,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: alignment ?? MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                        RoundedBoxButton(
                            padding: const EdgeInsets.all(2.0),
                            backgroundColor: Colors.transparent,
                            icon: Icon(
                                Icons.chevron_left,
                                color: (manager.active.canBacktrack) ? null : Theme.of(context).disabledColor,
                            ),
                            onTap: () {
                                manager.active.backtrack();
                            },
                        ),
                        RoundedBoxButton(
                            padding: const EdgeInsets.all(2.0),
                            backgroundColor: Colors.transparent,
                            icon: Icon(
                                Icons.chevron_right,
                                color: (manager.active.canAdvance) ? null : Theme.of(context).disabledColor,
                            ),
                            onTap: () {
                                manager.active.advance();
                            },
                        ),
                        RoundedBoxButton(
                            padding: const EdgeInsets.all(2.0),
                            backgroundColor: Colors.transparent,
                            icon: const Icon(Icons.refresh),
                            onTap: () {
                                manager.active.reload();
                            },
                        ),
                        if (!isDesktop) Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: SearchFavoriteButton(
                                manager: manager,
                                asBox: true,
                            ),
                        ),
                        if (!isDesktop) Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: ActualDownloadButton(
                                current: manager.active.current,
                                onTap: (){},
                            ),
                        )
                    ],
                ),
            ),
        );
    }
}

class SearchBarTools extends StatefulWidget {
    final TabManager manager;
    
    const SearchBarTools({required this.manager, super.key});

    @override
    State<SearchBarTools> createState() => _SearchBarToolsState();
}

class _SearchBarToolsState extends State<SearchBarTools> {
    @override
    Widget build(BuildContext context) {
        final menu = <ContextMenuEntry>[
            if (!isDesktop) ...[
                NokuMenuChild(
                    child: StreamBuilder(
                        stream: widget.manager.stream,
                        builder: (context, snapshot) => SearchBarNavigation(
                                manager: widget.manager,
                            )
                    )
                ),
                MenuDivider(
                    color: Theme.of(context).disabledColor
                )
            ],
            NokuMenuItem(
                label: languageText("app_settings"),
                icon: Icons.settings,
                onSelected: () {
                    // Open settings page
                    widget.manager.setTabAsActive(widget.manager.createNew(view: ViewSettings()));
                },
            ),
            NokuMenuItem(
                label: languageText("app_downloads"),
                icon: Icons.download,
                onSelected: () {
                    // Open downloads page
                    widget.manager.setTabAsActive(widget.manager.createNew(view: ViewDownloads()));
                },
            ),
            NokuMenuItem(
                label: languageText("app_history"),
                icon: Icons.history,
                onSelected: () {
                    widget.manager.setTabAsActive(widget.manager.createNew(view: ViewHistory()));
                },
            ),
            NokuMenuItem(
                label: languageText("app_favorites"),
                icon: Icons.star,
                onSelected: () {
                    widget.manager.setTabAsActive(widget.manager.createNew(view: ViewFavorites()));
                }
            ),
            NokuMenuItem(
                label: "Debug",
                icon: Icons.bug_report,
                onSelected: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LogPage()));
                }
            )
        ];

        return Material(
            type: MaterialType.transparency,
            child: InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(4.0)),
                hoverColor: Themes.accent.withAlpha(128),
                onTap: () {},
                child: Row(
                    spacing: 4.0,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                        /*RoundedBoxButton(
                            padding: const EdgeInsets.all(2.0),
                            backgroundColor: Colors.transparent,
                            icon: const Icon(
                                Icons.bug_report,
                            ),
                            onTap: () async {
                                var value = await getClearanceCookie(context);

                                Nokulog.i(value);
                            
                                if (value != null) {
                                    Searcher.configureNHentaiClearance(value);
                                }
                            },
                        ),*/
                        if (!isDesktop) RoundedBoxButton(
                            padding: const EdgeInsets.all(2.0),
                            backgroundColor: Colors.transparent,
                            icon: const Icon(
                                Icons.add,
                            ),
                            onTap: () async {
                                widget.manager.setTabAsActive(widget.manager.createNew(
                                    view: ViewHome()
                                ));
                            },
                        ),
                        if (!isDesktop) RoundedBoxButton(
                            padding: const EdgeInsets.all(2.0),
                            backgroundColor: Colors.transparent,
                            icon: const Icon(
                                Icons.tab_rounded,
                            ),
                            onTap: () async {
                                final screenshot = await widget.manager.screenshotController.capture();

                                setState(() {
                                    widget.manager.active.thumb = screenshot;
                                    widget.manager.showThumb.value = true;
                                });

                                if (context.mounted) {
                                    await Navigator.of(context).push(
                                        MaterialPageRoute(builder: (context) => MobileTabPage(manager: widget.manager))
                                    );
                                }
                            },
                        ),
                        if (isDesktop) DownloadPopupButton(
                            current: widget.manager.active.current
                        ),
                        OptionsButton(entries: menu)
                    ],
                ),
            ),
        );
    }
}

class SearchTagBar extends StatefulWidget {
    final Iterable<Widget>? trailing;
    final Widget? leading;
    final void Function(String query)? onSubmitted;
    final void Function(String query)? onChanged;
    final TextEditingController? controller;
    final bool useSearchHistory;

    const SearchTagBar({super.key, this.trailing, this.leading, this.onSubmitted, this.controller, this.onChanged, this.useSearchHistory = true});

    @override
    State<SearchTagBar> createState() => _SearchTagBarState();
}

class _SearchTagBarState extends State<SearchTagBar> {
    late final ScrollController scrollController;
    late final SuggestionsController<dynamic> suggestionsController;
    final FocusNode searchFocusNode = FocusNode();
    final HashSet<LogicalKeyboardKey> keys = HashSet.from([
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end
    ]);

    late TextEditingController textController;

    LinkedHashSet<dynamic> currentTags = LinkedHashSet();
    int lastTagOffset = 0;
    String previousQuery = "";
    String previousFullQuery = "";
    bool isLoading = false;
    bool reachedEnd = false;

    int lastCursorPosition = 0;
    String lastCursorText = "";

    @override
    void initState() {
        super.initState();

        scrollController = ScrollController();
        suggestionsController = SuggestionsController();
        textController = widget.controller ?? TextEditingController();

        lastCursorPosition = textController.selection.isValid ? textController.selection.baseOffset : 0;

        scrollController.addListener(() async {
            if (scrollController.position.pixels < scrollController.position.maxScrollExtent - 200) {
                return;
            }

            setState(() {
                isLoading = true;
                suggestionsController.refresh();
            });

            List<dynamic> data = [];

            if (previousFullQuery.trim().isEmpty) {
                //data = (await Tags.loadSearchQueries(30, ++lastTagOffset)).map((element) => element.tags).reduce((first, second) => first + second);
                data = (await Tags.loadSearchQueries(30, ++lastTagOffset)).map((element) => element.query).toList();
            } else {
                data = await Tags.search(previousQuery, 30, ++lastTagOffset);
            }

            setState(() {
                isLoading = false;
                currentTags.addAll(data);

                if (data.isEmpty) {
                    reachedEnd = true;
                }

                suggestionsController.refresh();
            });
        });
    }

    @override
    void dispose() {
        // Clean up resources
        searchFocusNode.dispose();
        scrollController.dispose();
        suggestionsController.dispose();
        
        // Only dispose the text controller if we created it internally
        if (widget.controller == null) {
            textController.dispose();
        }
        
        super.dispose();
    }

    void reset() {
        currentTags.clear();
        isLoading = false;
        reachedEnd = false;
        previousQuery = "";
        //previousFullQuery = "";
        
        // Safely reset scroll position
        if (scrollController.hasClients) {
            scrollController.jumpTo(0);
        }
    }

    @override
    void didUpdateWidget(covariant SearchTagBar oldWidget) {
        super.didUpdateWidget(oldWidget);

        if (oldWidget.controller != widget.controller) {
            textController = widget.controller ?? TextEditingController();
        }
    }

    void onMoved() {
        // Get the current cursor position safely
        if (!textController.selection.isValid) return;
        
        final current = textController.selection.start;
        // Prevent index out of bounds
        if (current <= 0 || previousFullQuery.isEmpty) return;
        
        final currentText = getWordAtIndex(previousFullQuery, current - 1);

        if (lastCursorPosition != current && currentText != lastCursorText) {
            setState(() {
                lastCursorPosition = textController.selection.baseOffset;
                lastCursorText = currentText;
                suggestionsController.refresh();
            });
        }
    }

    Future<List<Tag>> generateTagTiles(String query, {int limit = 30}) async => Tags.search(query, limit, 0);

    @override
    Widget build(BuildContext context) => TypeAheadField(
            controller: textController,
            suggestionsController: suggestionsController,
            listBuilder: (context, children) => SafeArea(
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: min(MediaQuery.sizeOf(context).height, 256)
                    ),
                    child: ListView.builder(
                        controller: scrollController,
                        shrinkWrap: true,
                        itemCount: children.length + 1,
                        itemBuilder: (context, index) {
                            if (index < children.length) {
                                return children[index];
                            }

                            if (isLoading) {
                                return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(child: CircularProgressIndicator()),
                                );
                            }

                            return const SizedBox.shrink();
                        },
                    ),
                ),
            ),
            itemBuilder: (context, value) {
                final Color disabledColor = Theme.of(context).disabledColor;

                if (value is Tag) {
                    return ListTile(
                        title: Text(value.original), 
                        subtitle: (value.translated.isNotEmpty) ? Text(value.translated, style: TextStyle(color: disabledColor)) : null
                    );
                }

                return ListTile(
                    title: Text(value.toString()),
                );
            },
            builder: (context, controller, focusNode) {
                /*
                    child: KeyboardListener(
                        focusNode: searchFocusNode,
                        onKeyEvent: (event) {
                            if (!keys.contains(event.logicalKey)) return;

                            onMoved();
                        },
                        child: SearchBar(
			                focusNode: focusNode,
                            controller: controller,
                            trailing: widget.trailing,
                            leading: widget.leading,
                            onSubmitted: widget.onSubmitted,
                            onChanged: widget.onChanged,
                            onTap: () {
                                onMoved();
                            },
                        ),
                    ),
                */
                return Container(
                    decoration: const BoxDecoration(
                        boxShadow: [
                            BoxShadow(
                                offset: Offset(4.0, 4.0),
                                blurRadius: 23.0,
                            )
                        ]
                    ),
                    child: SearchBar(
                        focusNode: focusNode,
                        controller: controller,
                        trailing: widget.trailing,
                        leading: widget.leading,
                        onSubmitted: widget.onSubmitted,
                        onChanged: widget.onChanged,
                        onTap: () {
                            onMoved();
                        },
                    ),
                );
            },
            onSelected: (value) {
                searchFocusNode.requestFocus();

                // Handle suggestion selection
                if (value is String) {
                    textController.text = value;
                    return;
                }

                if (previousFullQuery.trim().isEmpty) {
                    textController.text = "${value.original} ";
                    return;
                }

                // Safely replace word at cursor position
                if (textController.selection.isValid && textController.selection.baseOffset > 0) {
                    textController.text = replaceWordAtIndex(
                        previousFullQuery, 
                        value.original, 
                        textController.selection.baseOffset - 1
                    );
                } else {
                    // Fallback if cursor position is invalid
                    textController.text = "${value.original} ";
                }
            },
            suggestionsCallback: (search) async {
                previousFullQuery = search;
                
                String searchWord;
                
                // Safely get the word at cursor position
                if (search.length == 1) {
                    searchWord = search;
                } else if (textController.selection.isValid && textController.selection.baseOffset > 0) {
                    searchWord = getWordAtIndex(search, textController.selection.baseOffset - 1);
                } else {
                    // Fallback if cursor position is invalid
                    searchWord = search.split(' ').lastOrNull ?? search;
                }

                if (searchWord != previousQuery) {
                    setState(() {
                        reset();
                        isLoading = true;
                    });

                    lastTagOffset = 0;
                    List<dynamic> value = [];

                    try {
                        if (searchWord.trim().isEmpty) {
                            final searchQueries = await Tags.loadSearchQueries(30, 0);
                            if (searchQueries.isNotEmpty) {
                                //value = searchQueries.map((element) => element.tags).reduce((first, second) => first + second);
                                value = searchQueries.map((element) => element.query).toList();
                            }
                        } else {
                            value = await Tags.search(searchWord, 30, 0);
                        }
                    } catch (e) {
                        // Handle errors in tag search
                        Notify.showMessage(
                            title: "Search Error",
                            message: "Failed to load suggestions: ${e.toString()}",
                            icon: const Icon(Icons.error_outline)
                        );
                    }

                    setState(() {
                        currentTags.addAll(value);
                        previousQuery = searchWord;
                        isLoading = false;
                    });
                }

                return currentTags.toList();
            }
        );
}

class SearchFavoriteButton extends StatefulWidget {
    final TabManager manager;
    final bool asBox;

    const SearchFavoriteButton({required this.manager, this.asBox = false, super.key});

    @override
    State<SearchFavoriteButton> createState() => _SearchFavoriteButtonState();
}

class _SearchFavoriteButtonState extends State<SearchFavoriteButton> {
    void onPressed(bool isFavorite, Post post) {
        if (isFavorite) {
            setState((){
                Favorites.deleteFavorite(post);
            });

            return;
        }

        setState(() {
            Favorites.addFavorite(post);
        });
    }

    @override
    Widget build(BuildContext context) {
        final manager = widget.manager;
        final view = manager.active.current;
        Post post;
        
        if (view is ViewPost) {
            post = view.post;
        } else if (view is ViewViewer) {
            post = view.post;
        } else {
            return const SizedBox.shrink();
        }

        final isFavorite = Favorites.isFavorite(post);
        final icon = Icon(
            (isFavorite) ? Icons.star : Icons.star_border,
            color: Themes.accent,
        );

        if (widget.asBox) {
            return RoundedBoxButton(
                onTap: () => onPressed(isFavorite, post),
                icon: icon
            );
        }

        return IconButton(
            onPressed: () => onPressed(isFavorite, post),
            icon: icon,
        );
    }
}

class ActualDownloadButton extends StatelessWidget {
    final ViewData current;
    final VoidCallback onTap;

    const ActualDownloadButton({required this.current, required this.onTap, super.key});

    @override
    Widget build(BuildContext context) => RoundedBoxButton(
            padding: const EdgeInsets.all(2.0),
            backgroundColor: Colors.transparent,
            icon: const Icon(
                Icons.download,
            ),
            onTap: () async {
                switch (current.type) {
                    case ViewType.post:
                        DownloadManager.downloadPost((current as ViewPost).post);
                        break;
                    case ViewType.viewer:
                        DownloadManager.downloadPost((current as ViewViewer).post);
                        break;
                    case ViewType.search:
                        final search = (current as ViewSearch);
                        final query = search.query;
                        final optional = (search.optionalTags.isEmpty) ? "" : "(${search.optionalTags})";
                        
                        DownloadManager.downloadPosts(
                            Finder.filterByMD5(
                                search.queryResults.where(
                                    (post) => !hasCommonElement(
                                        post.tags.map((tag) => tag.original).toList(), 
                                        Settings.blacklist.value
                                    )
                                ).toList()
                            ),
                            "$query$optional"
                        );
                        break;
                    default:
                        return;
                }
                onTap();
            },
        );
}

class DownloadPopupButton extends StatefulWidget {
    final ViewData current;

    const DownloadPopupButton({required this.current, super.key});

    @override
    State<DownloadPopupButton> createState() => _DownloadPopupButtonState();
}

class _DownloadPopupButtonState extends State<DownloadPopupButton> {
    Offset offset = Offset.zero;
    GlobalKey key = GlobalKey();

    @override
    Widget build(BuildContext context) {
        const double width = 256 + 64;

        return Listener(
            onPointerDown: (event) {
                offset = event.position;
            },
            child: RoundedBoxButton(
                key: key,
                padding: const EdgeInsets.all(2.0),
                backgroundColor: Colors.transparent,
                icon: const Icon(
                    Icons.download,
                ),
                onTap: () async {
                    final RenderBox box = key.currentContext!.findRenderObject() as RenderBox;
                    final Offset position = box.localToGlobal(Offset.zero);

                    await Navigator.push(
                        context, 
                        PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => DownloadPopup(
                                    position: position, 
                                    width: width, 
                                    current: widget.current
                                ),
                            fullscreenDialog: true,
                            opaque: false,
                            barrierDismissible: true,
                            maintainState: true,
                            allowSnapshotting: true,
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                        )
                    );
                },
            ),
        );
    }
}

class DownloadPopup extends StatefulWidget {
    final Offset position;
    final double width;
    final ViewData current;

    const DownloadPopup({required this.position, required this.width, required this.current, super.key});

    @override
    State<DownloadPopup> createState() => _DownloadPopupState();
}

class _DownloadPopupState extends State<DownloadPopup> {
    @override
    Widget build(BuildContext context) {
        final position = widget.position;
        final width = widget.width;
        final current = widget.current;

        return Align(
            alignment: Alignment.topLeft,
            child: Transform.translate(
                offset: Offset(
                    position.dx - width,
                    position.dy + 32
                ),
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: width
                    ),
                    child: Card(
                        elevation: 8.0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0)
                        ),
                        child: PaddedWidget(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 8.0,
                                children: [
                                    Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                            Text(
                                                languageText("app_downloads"),
                                                style: const TextStyle(
                                                    fontSize: 21,
                                                    fontWeight: FontWeight.bold
                                                ),
                                            ),
                                            ActualDownloadButton(
                                                current: current, 
                                                onTap: () {
                                                    setState((){});
                                                }
                                            ),
                                        ],
                                    ),
                                    for (var i = DownloadManager.history.length - 1; i >= max(0, DownloadManager.history.length - 5); i--) DownloadCard(
                                        record: DownloadManager.history[i],
                                        style: DownloadCardStyle.chip,
                                    ),
                                    if (DownloadManager.history.isEmpty) const Center(
                                        child: Text(
                                            "No downloads..."
                                        ),
                                    )
                                ],
                            )
                        )
                    ),
                ),
            ),
        );
    }
}
