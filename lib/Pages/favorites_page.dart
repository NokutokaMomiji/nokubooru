
import 'package:faded_scrollable/faded_scrollable.dart';
import 'package:flutter/material.dart';
import 'package:nokubooru/State/favorites.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/post_card.dart';
import 'package:nokubooru/utilities.dart';

/// Mapping of sort options to display labels.
const Map<FavoriteSortOption, String> favoriteSortLabels = {
    FavoriteSortOption.postId: "Post ID",
    FavoriteSortOption.source: "Source",
    FavoriteSortOption.rating: "Rating",
    FavoriteSortOption.added: "Added",
};

class TabViewFavorites extends StatefulWidget {
    final ViewFavorites data;

    const TabViewFavorites({required this.data, super.key});

    @override
    State<TabViewFavorites> createState() => _TabViewFavoritesState();
}

class _TabViewFavoritesState extends State<TabViewFavorites> {
    final ScrollController _scrollController = ScrollController();
    FavoriteSortOption _currentSort = FavoriteSortOption.added;
    bool _ascending = false;

    @override
    void initState() {
        super.initState();
        loadNextFavorites();
        _scrollController.addListener(onScroll);
        widget.data.registerOnActiveCallback(updateFirstFavorites);
    }

    @override
    void dispose() {
        _scrollController.dispose(); 
        super.dispose();
    }

    void onScroll() {
        if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 200) return;
        if (widget.data.isLoading || widget.data.hasReachedEnd) return;

        loadNextFavorites();
    }

    Future<void> loadNextFavorites() async {
        setState(() {
            widget.data.isLoading = true;
        });

        FavoriteLoadResult result;
        
        if (widget.data.query.isEmpty) {
            result = await Favorites.loadFavorites(
                offset: widget.data.offset,
                sortOption: _currentSort,
                ascending: _ascending,
                limit: 100
            );
        } else {
            result = await Favorites.searchFavorites(
                widget.data.query,
                offset: widget.data.offset,
                sortOption: _currentSort,
                ascending: _ascending,
                limit: 100
            );
        }

        for (final item in result.posts) {
            item.recheckTags();
        }

        setState(() {
            widget.data.favorites.add(result);
            widget.data.offset = result.nextOffset;
            widget.data.hasReachedEnd = result.hasReachedEnd;
            widget.data.isLoading = false;
        });
    }

    Future<void> updateFirstFavorites() async {
        FavoriteLoadResult result;
        
        if (widget.data.query.isEmpty) {
            result = await Favorites.loadFavorites(
                offset: 0,
                sortOption: _currentSort,
                ascending: _ascending,
                limit: 100
            );
        } else {
            result = await Favorites.searchFavorites(
                widget.data.query,
                offset: 0,
                sortOption: _currentSort,
                ascending: _ascending,
                limit: 100
            );
        }

        if (widget.data.favorites.isNotEmpty) {
            final resultIdentifiers = result.posts.map(
                (element) => element.identifier
            ).toList();
            final currentIdentifiers = widget.data.favorites.first.posts.map(
                (element) => element.identifier
            ).toList();

            if (eq(resultIdentifiers, currentIdentifiers)) {
                return;
            }
        }

        for (final item in result.posts) {
            item.recheckTags();
        }

        if (mounted) {
            setState(() {
                if (widget.data.favorites.isEmpty) {
                    widget.data.favorites.add(result);
                } else {
                    widget.data.favorites[0] = result;
                }
                widget.data.offset = result.nextOffset;
                widget.data.hasReachedEnd = result.hasReachedEnd;
                widget.data.isLoading = false;
            });
        }
    }

    void onSortChanged(FavoriteSortOption? newSort) {
        if (newSort == null) return;

        setState(() {
            _currentSort = newSort;
            widget.data.sortOption = newSort;
            widget.data.clearFavorites();
        });
        
        loadNextFavorites();
    }

    void onQueryChanged(String query) {
        setState(() {
            widget.data.query = query;
            widget.data.clearFavorites();
        });

        loadNextFavorites();
    }

    @override
    Widget build(BuildContext context) {
        final posts = widget.data.favorites.map((item) => item.posts).fold([], (first, second) => first + second);

        return Column(
            children: [
                Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                        spacing: 8.0,
                        children: [
                            Expanded(
                                child: SearchBar(
                                    controller: widget.data.controller,
                                    constraints: const BoxConstraints(
                                        minHeight: 48,
                                        maxWidth: 256
                                    ),
                                    trailing: [
                                        IconButton(
                                            onPressed: () => onQueryChanged(widget.data.controller.text),
                                            icon: const Icon(Icons.search)
                                        )
                                    ],
                                    onSubmitted: onQueryChanged,
                                ),
                            ),
                            const SizedBox(width: 16),
                            SafeArea(
                                child: DropdownButton<FavoriteSortOption>(
                                    borderRadius: BorderRadius.circular(16.0),
                                    value: _currentSort,
                                    items: favoriteSortLabels.entries
                                        .map((entry) => DropdownMenuItem<FavoriteSortOption>(
                                            value: entry.key,
                                            child: Text(entry.value),
                                        ))
                                        .toList(),
                                    onChanged: onSortChanged,
                                ),
                            ),
                            SafeArea(
                                child: DropdownButton<bool>(
                                    value: _ascending,
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
                                        _ascending = value ?? _ascending;
                                        onSortChanged(_currentSort);
                                    },
                                )
                            ),
                            SafeArea(
                                child: IconButton.outlined(
                                    onPressed: () {
                                        
                                    }, 
                                    icon: const Icon(Icons.sync_alt)
                                )
                            ),
                        ],
                    ),
                ),
                Expanded(
                    child: FadedScrollable(
                        child: GridView.builder(
                            key: PageStorageKey<String>("favoriteController${widget.data.favorites.hashCode}"),
                            controller: _scrollController,
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 128,
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                            ),
                            itemCount: posts.length + 1,
                            itemBuilder: (context, index) {
                                if (index < posts.length) {
                                    final post = posts[index];
                        
                                    return PostCard(
                                        key: ValueKey(post),
                                        post: post,
                                        data: widget.data.tab!,
                                        animated: true,
                                    );
                                }
                        
                                if (widget.data.hasReachedEnd) {
                                    return Center(
                                        child: Text(
                                            languageText("app_reached_end"),
                                            style: TextStyle(color: Theme.of(context).disabledColor),
                                        ),
                                    );
                                }
                                
                                if (widget.data.isLoading) {
                                    return const Center(child: CircularProgressIndicator());
                                }
                                
                                return const SizedBox.shrink();
                            }
                        ),
                    ),
                ),
            ],
        );
    }
}
