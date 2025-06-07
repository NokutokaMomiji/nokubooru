import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nokubooru/State/download_manager.dart';
import 'package:nokubooru/State/downloads.dart';
import 'package:nokubooru/State/favorites.dart';
import 'package:nokubooru/State/history.dart';
import 'package:nokubooru/State/post_resolver.dart';
import 'package:nokubooru/State/searcher.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/tags.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';
import 'package:synchronized/synchronized.dart';

/// Enum that holds all of the possible views in the app.
enum ViewType {
    home,
    search,
    post,
    viewer,
    settings,
    favorites,
    downloads,
    history,
    error
}

/// Abstract base class that represents the data required to both build and restore a view.
/// Views represent a "page" of sorts inside a tab, which becomes its parent.
/// 
/// Every view must implement [exportHistory] and [export] in order to be able to recreate the view.
abstract interface class ViewData {
    TabData? tab;

    bool _unloaded = false;

    /// Creates a [ViewData] from the [Map] data returned by [export].
    /// 
    /// To create a [ViewData] from the data created via [exportHistory], it must be 
    /// done manually or via [fromURL].
    static ViewData fromMap({required ViewType type, required Map<String, dynamic> data, bool unload = true}) {
        switch (type) {
            case ViewType.home:
                return ViewHome();

            case ViewType.search:
                return ViewSearch.fromMap(data: data, unload: unload);

            case ViewType.post:
                return ViewPost.fromMap(data: data, unload: unload);

            case ViewType.viewer:
                return ViewViewer.fromMap(data: data, unload: unload);

            case ViewType.history:
                return ViewHistory();

            case ViewType.error:
                return ViewError(errorCode: data["errorCode"] as int);

            case ViewType.downloads:
                return ViewDownloads();

            case ViewType.favorites:
                return ViewFavorites();

            case ViewType.settings:
                return ViewSettings();
        }
    }

    /// Creates a [ViewData] instance given a deep link [url] and an optional [tab].
    /// 
    /// If the URL points to a supported booru URL, we attempt to either extract the 
    /// source and post ID, or query.
    ///
    /// Otherwise, we check if it is a valid Nokubooru URL and reconstruct the view. 
    /// If something fails (due to missing parameters, etc...), we return a [ViewError].
    static Future<ViewData> fromURL({required Uri url, TabData? tab}) async {
        if (url.scheme.toLowerCase() == "https") {
            final result = PostResolver.resolve(url);

            Nokulog.i(result);

            if (result.post == null && result.query.isEmpty) {
                return ViewError(errorCode: 400);
            }

            if (result.post != null) {
                final post = await (result.post!);

                if (post == null) return ViewError(errorCode: 404);

                if (result.query.isNotEmpty && tab != null) {
                    tab.searchBarInput.text = result.query.trim();
                }

                return ViewPost(post: post);
            }

            if (tab != null) {
                tab.searchBarInput.text = result.query.trim();
            }

            return ViewSearch(
                searchFuture: Searcher.searchPosts(
                    result.query,
                    client: result.source
                ),
                query: result.query,
                page: 0,
                client: result.source
            );
        }

        Nokulog.d(url.toString());

        if (url.scheme.toLowerCase() != "nokubooru") {
            return ViewError(errorCode: 400);
        }

        final viewType = ViewType.values.firstWhereOrNull((element) => element.name == url.host.toLowerCase());

        if (viewType == null) {
            return ViewError();
        }

        switch (viewType) {
            case ViewType.home:
                return ViewHome();

            case ViewType.search:
                final data = url.queryParameters;

                Nokulog.d("queryParameters: ${url.queryParameters}");
                return ViewSearch.fromMap(data: data, unload: false);

            case ViewType.post:
                final data = url.queryParameters;

                if (!data.containsKey("id")) {
                    return ViewError(errorCode: 400);
                }

                return (await ViewPost.fromMapHistory(data: data)) ?? ViewError();

            case ViewType.viewer:
                final data = url.queryParameters;

                if (!data.containsKey("id")) {
                    return ViewError(errorCode: 400);
                }

                return (await ViewViewer.fromMapHistory(data: data)) ?? ViewError();

            case ViewType.history:
                return ViewHistory();

            case ViewType.error:
                final data = url.queryParameters;

                if (!data.containsKey("errorCode")) {
                    return ViewError(errorCode: 400);
                }

                return ViewError(errorCode: data["errorCode"] as int);

            case ViewType.downloads:
                return ViewDownloads();

            case ViewType.favorites:
                return ViewFavorites();

            case ViewType.settings:
                return ViewSettings();
        }
    }

    /// Assigns this view to a parent [tab] if not already assigned.
    /// 
    /// Returns ``true`` if the view had no parent and now has been attached to [tab], or ``false`` 
    /// if it was already assigned. This helps avoid multiple parent assignments since a 
    /// view should only belong to a single tab.
    bool parent(TabData tab) {
        if (this.tab != null) return false;

        this.tab = tab;
        return true;
    }

    /// Reloads the View's data.
    ///
    /// By default, it marks the view as "loaded". Any extra functionality must be implemented
    /// per View type.
    @mustCallSuper
    void reload() {
        _unloaded = false;
    }

    /// Unloads the View's data.
    ///
    /// By default, it marks the view as "unloaded". Any extra functionality must be implemented
    /// per View type.
    @mustCallSuper
    void unload() {
        _unloaded = true;
    }

    /// Disposes the view. By default, it is equivalent to calling [unload].
    void dispose() {
        unload();
    }

    /// Called when the view is activated and on display.
    /// 
    /// By default, it reloads the view data if it was previously unloaded.
    void onActive() {
        if (_unloaded) reload();
    }

    /// Produces a map containing the data to be stored in the search history.
    /// 
    /// The data returned is meant to be as bare as possible in order to occupy as little storage
    /// space as possible. 
    Map<String, dynamic> exportHistory();

    /// Produces a map containing the data for the view to be created on a session restore.
    /// 
    /// Keep in mind that this function exports **all the necessary data** to synchronously create
    /// a new [ViewData] instance, and should not be used to store data en masse. 
    /// 
    /// If you do not care for synchronicity and is on a file size budget, use [exportHistory] instead.
    Map<String, dynamic> export();

    ViewType get type;
    String get title;
    Uint8List? get thumb;
    Widget? get favicon;    // I called it favicon, but it's not reaaaaaaaally a favicon.

    @override
    String toString() => url;

    /// Builds a Nokubooru URL encoding this view’s history data.
    /// 
    /// We use a custom `nokubooru://` scheme so that deep links inside the
    /// app can point back to this state. If there’s no data, we omit the query params.
    String get url {
        // In case you haven't noticed, this app is heavily inspired on webbrowsers.
        // A custom protocol is just so cool!
        
        final data = exportHistory();
        final entries = data.entries.where((element) => element.value.toString().isNotEmpty);
        final dataParts = [for (final record in entries) "${record.key}=${record.value}"];
        final queryParameters = "?${dataParts.join("&")}";

        return "nokubooru://${type.name}${(dataParts.isEmpty) ? "" : queryParameters}";
    }
}

/// View page that represents a search.
/// 
/// This class fetches a list of [Post] objects asynchronously and stores
/// them in [queryResults]. You can check [isComplete] to know if the search
/// finished.
///
/// Query information, page index, and the currently used client are also stored.
class ViewSearch extends ViewData {
    final String query;
    final String optionalTags;
    final String blacklist;
    final int page;
    final String? client;

    Future<List<Post>> searchFuture;
    List<Post> queryResults = [];

    //final List<Tag> _tags = [];
    bool _isComplete = false;
    Uint8List? _favicon;
    final Stopwatch _stopwatch = Stopwatch();

    /// Constructs a [ViewSearch] with a [searchFuture] that fetches posts.
    ViewSearch({required this.searchFuture, this.query = "", this.optionalTags = "", this.blacklist = "", this.page = 0, this.client}) {
        _stopwatch.start();
        searchFuture.whenComplete(() async {
            _stopwatch.stop();
            _isComplete = true;
            queryResults = await searchFuture;
        });
    }

    /// Creates a [ViewSearch] from the stored [data] created from [export].
    /// 
    /// If [unload] is true, data will be immediately unloaded and must be reloaded.
    factory ViewSearch.fromMap({required Map<String, dynamic> data, bool unload = true}) {
        final String query = data["query"] ?? "";
        final String optionalTags = data["optionalTags"] ?? data["optionaltags"] ?? "";
        final String blacklist = data["blacklist"] ?? "";
        final int page = data["page"] ?? 0;
        final String? client = data["client"];

        Nokulog.d("data: $data");

        final search = ViewSearch(
            searchFuture: (unload) ? Future.value([]) : Searcher.searchPosts(
                query,
                optionalTags: optionalTags,
                blacklist: blacklist,
                page: page,
                client: client
            ),
            query: query,
            optionalTags: optionalTags,
            blacklist: blacklist,
            page: page,
            client: client
        );

        if (unload) {
            search.unload();
        }

        return search;
    }

    @override
    bool parent(TabData tab) {
        tab.onUpdate(() {
            if (tab.current != this) return; 

            _favicon = randomWhereOrNull<Post>(
                queryResults, 
                (element) => element.data.first.data != null && !(element.isVideo || element.isZip)
            )?.data.first.data;
        });

        return super.parent(tab);
    }

    @override
    void reload() {
        if (!_isComplete) return;

        _isComplete = false;

        _stopwatch..stop()..reset()..start();

        queryResults.clear();

        searchFuture = Searcher.searchPostsActive(
            query, 
            optionalTags: optionalTags, 
            blacklist: blacklist, 
            page: page, 
            client: client
        );
        searchFuture.whenComplete(() async {
            _stopwatch.stop();

            _isComplete = true;
            queryResults = await searchFuture;
        });

        super.reload();
    }

    @override
    void unload() {
        //Nokulog.i("Unloaded $query");
        queryResults.clear();
        
        super.unload();
    }

    @override
    Map<String, dynamic> exportHistory() => {
            "query": query,
            "optionalTags": optionalTags,
            "blacklist": blacklist,
            "page": page,
            "client": client
        };

    // The cool thing about ViewSearch is that it is fully asynchronously designed.
    // We can just reuse the data from exportHistory.
    @override
    Map<String, dynamic> export() => exportHistory();

    /// Indicates whether the search has completed.
    bool get isComplete => _isComplete;

    /// The **unmodifiable** list of tags.
    List<Tag> get tags => List.unmodifiable(queryResults.map((element) => element.tags).fold<List<Tag>>([], (tagList, element) => tagList + element).toSet());
    
    /// How long the search has been going on for.
    Duration get elapsed => _stopwatch.elapsed;

    /// The stopwatch instance being used to keep track of the search time.
    Stopwatch get stopwatch => _stopwatch;

    @override
    ViewType get type => ViewType.search;

    @override
    String get title {
        final tags = query.split(" ");

        if (optionalTags.isNotEmpty) {
            tags.addAll(optionalTags.split(" ").map((element) => "~$element"));
        }
        
        if (blacklist.isNotEmpty) {
            tags.addAll(blacklist.split(" ").map((element) => "-"));
        }

        return languageText(
            "app_search_title", [
                (query.isEmpty && optionalTags.isEmpty && blacklist.isEmpty) ? 
                    languageText("app_no_tags") : 
                    tags.join(" ")
            ]
        );
    }

    @override
    Uint8List? get thumb => (_favicon != null) ? _favicon : null;

    @override
    Widget? get favicon => (_favicon != null) ? Image.memory(_favicon!) : null;
}

/// View data for displaying a single post’s details and managing its files.
class ViewPost extends ViewData {
    late List<PostFile> data;
    late Post _post;

    List<Comment>? comments;
    List<Post>? children;
    Post? postParent;
    bool hasCheckedParent = false;

    Description? description;
    bool hasCheckedDescription = false;

    bool _isComplete = true;
    Completer<Post> _completer = Completer();

    /// Constructs a [ViewPost] around an existing [post].
    /// 
    /// If [loadFirst] is true, we begin downloading its first file immediately.
    ViewPost({required Post post, bool loadFirst = true}) {
        _post = post;
        _completer.complete(_post);

        if (loadFirst) {
            DownloadManager.fetch(post.postFiles.first);
        }

        data = post.data;
    }

    /// Creates a [ViewPost] from the [data] created via [export]. 
    /// 
    /// If [unload] is true, we immediately unload all data.
    factory ViewPost.fromMap({required Map<String, dynamic> data, bool unload = true}) {
        final rawPost = Post.importPostFromMap(data);

        // Hitomi file URLs change every single hour, meaning that stored data will be obsolete.
        // Therefore, we reload to fetch the new file URLs.
        final isHitomi = (rawPost.source == "hitomi");
        final post = ViewPost(post: rawPost, loadFirst: (!unload && !isHitomi));

        if (unload) {
            post.unload();
        }

        if (isHitomi && !unload) {
            post.reload();
        }
        
        return post;
    }

    /// Creates a [ViewPost] from [data] exported via [exportHistory].
    ///
    /// Since a post might not exist anymore, this function can return ``null`` if the post cannot be fetched.
    static Future<ViewPost?> fromMapHistory({required Map<String, dynamic> data}) async {
        /* 
            Going to be honest, I would have rather preferred that this was a factory instead of
            an async function. However, I neglected to consider the asynchronicity of fetching a post.
            I tried turning it async-friendly, but the app is just so deeply designed around the expectation
            that ViewPost will have all the necessary post data, that trying to make it async breaks many systems.
        */
        final int? id = (data["id"] is int) ? data["id"] : int.tryParse(data["id"].toString());

        assert(id != null);

        if (id == null) return null;

        final List<Post> post = await Searcher.getPost(id, client: data["source"]);

        if (post.isEmpty) return null;

        return ViewPost(
            post: post.first
        );
    }

    @override
    void reload() {
        if (!_isComplete) return;

        for (final file in _post.data) {
            DownloadManager.dispose(file);
        }

        comments = null;
        children = null;
        postParent = null;
        hasCheckedParent = false;

        description = null;
        hasCheckedDescription = false;

        _completer = Completer();
        _isComplete = false;

        Searcher.getPost(_post.postID, client: _post.source).then((result) {
            _isComplete = true;

            if (result.isEmpty) {
                _completer.completeError(Exception(languageText("app_post_not_found")));
                return;
            }

            _post = result.first;
            data = _post.data;

            Favorites.updateFavorite(_post);

            _completer.complete(_post);
        });

        super.reload();
    }

    @override
    void unload() {
        for (final file in _post.data) {
            DownloadManager.dispose(file);
        }

        super.unload();
    }

    /// Returns the current [Post] object.
    Post get post => _post;

    /// Indicates whether the post’s data has finished loading.
    bool get isComplete => _isComplete;

    /// Future that completes with the [Post], or errors if not found.
    Future<Post> get future => _completer.future;

    @override
    ViewType get type => ViewType.post;

    @override
    String get title => "${post.title} | ${post.source.capitalize()}";

    @override
    Uint8List? get thumb => (post.isVideo) ? null : data.first.data;

    @override
    Widget? get favicon => (post.isVideo || data.first.data == null) ? Image.network(post.preview, errorBuilder: (context, error, stackTrace) => const Icon(Icons.post_add),) : Image.memory(data.first.data!);
    
    @override
    Map<String, dynamic> exportHistory() => {
            "id": post.postID,
            "source": post.source
        };

    @override
    Map<String, dynamic> export() => post.toJson();
}

/// View data for displaying a zoomable image viewer of a post’s images.
class ViewViewer extends ViewData {
    late Post _post;

    int _current = 0;
    bool _isComplete = true;
    Completer<Post> _completer = Completer();

    /// Constructs a [ViewViewer] around an existing [post].
    ViewViewer({required Post post, int page = 0}) {
        _post = post;
        _completer.complete(_post);
    }

    /// Creates a [ViewViewer] from [data] generated by [export].
    factory ViewViewer.fromMap({required Map<String, dynamic> data, bool unload = true}) {
        final item = ViewViewer(
            post: Post.importPostFromMap(data["post"]),
            page: data["page"] as int,
        );

        if (unload) {
            item.unload();
        }

        return item;
    }

    /// Reconstructs a [ViewViewer] from the [data] generated by [exportHistory].
    /// 
    /// Returns ``null`` if the request post doesn't exist.
    static Future<ViewViewer?> fromMapHistory({required Map<String, dynamic> data}) async {
        final id = (data["id"] is String) ? int.parse(data["id"]) : data["id"] as int;
        
        assert(data["id"] != null);

        final post = await Searcher.getPost(id, client: data["source"]);

        if (post.isEmpty) return null;

        return ViewViewer(
            post: post.first,
            page: data["page"] ?? 0
        );
    }

    void notify() {
        tab!.update();
    }

    @override
    void reload() {
        if (!_isComplete) return;

        _completer = Completer();
        _isComplete = false;

        Searcher.getPost(_post.postID, client: _post.source).then((result) {
            _isComplete = true;

            if (result.isEmpty) {
                _completer.completeError(Exception(languageText("app_post_not_found")));
                return;
            }

            _post = result.first;
            _completer.complete(_post);
        });

        super.reload();
    }

    @override
    void unload() {
        for (final file in _post.data) {
            file.clear();
        }

        super.unload();
    }

    /// The current [Post]
    Post get post => _post;

    /// Future that completes when the post has loaded.
    Future<Post> get future => _completer.future;

    /// Whether the post is currently being loaded.
    bool get loading => _isComplete;

    /// Index of the currently displayed page.
    int get current => _current;
    set current (int value) {
        _current = value;
        notify();
    }

    @override
    Map<String, dynamic> exportHistory() => {
            "page": current,
            "id": post.postID,
            "source": post.source
        };

    @override
    Map<String, dynamic> export() => {
        "post": post.toJson(),
        "page": current
    };

    @override
    ViewType get type => ViewType.viewer;

    @override
    String get title => "${languageText("app_viewer_page")} ${(current + 1).toString().padLeft(2, '0')} | ${post.title}";

    @override
    Widget? get favicon {
        if (post.data[current].completed || post.data[current].data != null) {
            return Image.memory(
                post.data[current].data!,
            );
        }

        if (post.data[current].inProgress) {
            return const Center(child: CircularProgressIndicator());
        }

        return null;
    }

    @override
    Uint8List? get thumb => post.data[current].data;   
}

/// View data for browsing history entries of past searches or viewed posts.
class ViewHistory extends ViewData {
    final List<DayHistory> regularDays = [];
    final List<DayHistory> searchDays = [];
    final TextEditingController controller = TextEditingController();

    String query = "";
    bool setLoadState = false;

    int regularDayOffset = 0;
    bool regularIsLoading = false;
    bool regularhasReachedEnd = false;

    int searchDayOffset = 0;
    bool searchIsLoading = false;
    bool searchHasReachedEnd = false;

    /// Adds a [DayHistory] to the regular history list.
    /// 
    /// If [dayHistory.isEndOfHistory] is true, we mark that we’ve reached the end.
    /// If not, we append it, increment [regularDayOffset], and turn off loading.
    void addDayHistory(DayHistory dayHistory) {
        if (dayHistory.isEndOfHistory) {
            regularhasReachedEnd = true;
        } else {
            regularDays.add(dayHistory);
            regularDayOffset++;
        }
        regularIsLoading = false;
    }

    void setSearchState(HistorySearch result) {
        searchDays.addAll(result.days);
        searchDayOffset = result.nextDayOffset;
        searchHasReachedEnd = result.hasReachedEnd;
        searchIsLoading = false;
    }

    void clearSearch() {
        searchDays.clear();
        searchDayOffset = 0;
        searchHasReachedEnd = false;
    }

    void clearRegular() {
        regularDays.clear();
        regularDayOffset = 0;
        searchHasReachedEnd = false;
    }

    void updateFirstDay() {
        final firstDay = regularDays.firstOrNull;

        if (firstDay == null) return;

        History.loadDayHistory(0).then((day) {
            searchDays[0] = day;
        });
    }

    @override
    void reload() {
        clearSearch();
        clearRegular();
        updateFirstDay();

        tab!.notify();
        super.reload();
    }

    @override
    Map<String, dynamic> exportHistory() => {};

    @override
    Map<String, dynamic> export() => exportHistory();

    bool get isSearchMode => query.isNotEmpty;
    List<DayHistory> get daysToShow => (isSearchMode) ? searchDays : regularDays;
    bool get isLoading => (isSearchMode) ? searchIsLoading : regularIsLoading;
    bool get hasReachedEnd=> (isSearchMode) ? searchHasReachedEnd : regularhasReachedEnd;

    @override
    ViewType get type => ViewType.history;

    @override
    String get title => languageText("app_history");

    @override
    Widget? get favicon => const Icon(Icons.history);

    @override
    Uint8List? get thumb => null;
}

/// Simple view data representing an error state with a code.
/// 
/// Used when something goes wrong. Codes are standard HTTP error codes.
// (Because yes.)
class ViewError extends ViewData {
    final int errorCode;

    ViewError({this.errorCode = 404});

    @override
    Map<String, dynamic> exportHistory() => {
            "errorCode": errorCode
        };

    @override
    Map<String, dynamic> export() => exportHistory();

    @override
    Widget? get favicon => const Icon(Icons.error);

    @override
    Uint8List? get thumb => null;

    @override
    String get title => languageText("app_error", [errorCode]);

    @override
    ViewType get type => ViewType.error;
}

/// Packages a Home tag's data, including the currently fetched posts,
/// the last page index, and whether there are more posts to fetch.
class HomePostPack {
    List<Post> posts;
    int page;
    bool hasMore;

    HomePostPack({required this.posts, required this.page, required this.hasMore});
}

/// View data for the home screen, which shows newest posts and curated tag lists.
class ViewHome extends ViewData {
    static const int postLimit = 100;

    static final List<Post> newestPosts = [];
    static bool newestLoaded = false;

    static final List<String> recentTags = [];
    static final List<String> recurringTags = [];
    static final List<String> favoriteTags = [];

    static final Map<String, HomePostPack> posts = {};

    ValueNotifier<int> carouselIndex = ValueNotifier<int>(0);

    static bool _initialized = false;
    static Completer<List<Post>> _completer = Completer();
    static final Lock _lock = Lock();

    /// Initializes data for the home screen if not done already.
    Future<void> initializeIfNeeded() async {
        if (_initialized) return;

        _initialized = true;

        _completer = Completer<List<Post>>();

        final searchFuture = Searcher.searchPosts("", page: 0, limit: 30);
        
        _completer.complete(searchFuture);

        final all = await searchFuture;

        newestPosts.addAll(
            all.where(
                (post) => !post.isVideo && !post.isZip && !hasCommonElement(
                    post.tags.map((tag) => tag.original).toList(), 
                    Settings.blacklist.value
                )
            )
        );
        newestPosts.sort((first, second) {
            final firstCommon = first.tags.where((tag) => Tags.isFavorite(tag));
            final secondCommon = second.tags.where((tag) => Tags.isFavorite(tag));

            return secondCommon.length - firstCommon.length;
        });
        newestLoaded = true;

        final searchQueries = await Tags.loadSearchQueries(5, 0, withTags: true);
        final queryTags = searchQueries.map((element) => element.tags).flattenedToSet;
        
        for (int i = 0; i < 5 && i < queryTags.length; i++) {
            recentTags.add(queryTags.elementAt(i).original);
        }

        final frequencyMap = Tags.getTagFrequencyMap();
        final sortedEntries = frequencyMap.entries.whereNot(
            (element) => recentTags.contains(element.key)
        ).toList()..sort(
            (first, second) => second.value.compareTo(first.value)
        );

        final randomOffset = random.nextInt(6);

        for (int i = randomOffset; i < (randomOffset + 5) && i < sortedEntries.length; i++) {
            recurringTags.add(sortedEntries[i].key);
        }

        final favoritesList = (Tags.getFavoriteTags()..shuffle()).whereNot(
            (element) => recentTags.contains(element) || recurringTags.contains(element)
        ).toList();

        for (int i = 0; i < 5 && i < favoritesList.length; i++) {
            favoriteTags.add(favoritesList[i]);
        }

        final tagSet = {...recentTags, ...recurringTags, ...favoriteTags};
        for (final tag in tagSet) {
            posts[tag] = HomePostPack(
                posts: <Post>[],
                page: 0,
                hasMore: true
            );
        }
    }

    /// Loads the next page of posts for a given [tag], respecting [postLimit].
    Future<void> loadNextPageForTag(String tag) async {
        final pack = posts[tag];

        if (pack == null || pack.hasMore != true) return;

        final results = await _lock.synchronized(() {
            return Searcher.searchPosts(tag, page: pack.page, limit: postLimit);
        });

        pack.hasMore = false;

        if (results.length < postLimit) {
            pack.hasMore = false;
        }

        pack.posts.addAll(
            results.whereNot((post) => hasCommonElement(
                post.tags.map((tag) => tag.original).toList(), 
                Settings.blacklist.value
            ))
        );
        pack.page++;
        
        tab!.notify();
    }

    @override
    void reload() {
        _initialized = false;
        initializeIfNeeded();

        super.reload();
    }

    /// Future that resolves when the initial post fetch completes.
    Future<List<Post>> get newest => _completer.future;

    @override
    Map<String, dynamic> exportHistory() => {};

    @override
    Map<String, dynamic> export() => {};

    @override
    ViewType get type => ViewType.home;

    @override
    String get title => languageText("app_home");

    @override
    Widget? get favicon => const Icon(Icons.home);

    @override
    Uint8List? get thumb => null;
}
/// View data for displaying the user’s favorite posts.
/// 
/// Allows for lazy loading of favorite posts.
class ViewFavorites extends ViewData {
    List<FavoriteLoadResult> favorites = [];
    bool isLoading = false;
    bool hasReachedEnd = false;
    int offset = 0;
    String query = "";
    FavoriteSortOption sortOption = FavoriteSortOption.added;

    final TextEditingController controller = TextEditingController();

    final Map<int, VoidCallback> _onActiveCallbacks = {};

    /// Clears all favorite results and resets pagination state.
    void clearFavorites() {
        favorites.clear();
        offset = 0;
        hasReachedEnd = false;
    }

    /// Registers a callback to run when this view becomes active.
    /// 
    /// The [callback] will be stored in a map keyed by its hash code, so you can
    /// unregister it by using the same function reference later if needed.
    void registerOnActiveCallback(VoidCallback callback) {
        _onActiveCallbacks[callback.hashCode] = callback;
    }

    @override
    void onActive() {
        super.onActive();

        // Run all registered callbacks whenever favorites view is activated.
        for (final item in _onActiveCallbacks.values) {
            item();
        }
    }

    @override
    Map<String, dynamic> export() => {};

    @override
    Map<String, dynamic> exportHistory() => {};

    @override
    ViewType get type => ViewType.favorites;

    @override
    String get title => languageText("app_favorites");

    @override
    Widget? get favicon => null;

    @override
    Uint8List? get thumb => null;
}

/// View data for app settings.
class ViewSettings extends ViewData {
    @override
    Map<String, dynamic> export() => {};

    @override
    Map<String, dynamic> exportHistory() => {};

    @override
    ViewType get type => ViewType.settings;

    @override
    String get title => languageText("app_settings");

    @override
    Widget? get favicon => null;

    @override
    Uint8List? get thumb => null;
}

/// View data for the downloads history, including both regular and search results.
/// 
/// It is similar to [ViewHistory], but for download events.
class ViewDownloads extends ViewData {
    final List<DayDownloads> regularDays = [];
    final List<DayDownloads> searchDays = [];
    final TextEditingController controller = TextEditingController();

    String query = "";
    bool setLoadState = false;

    int regularDayOffset = 0;
    bool regularIsLoading = false;
    bool regularHasReachedEnd = false;

    int searchDayOffset = 0;
    bool searchIsLoading = false;
    bool searchHasReachedEnd = false;

    /// Adds a [DayDownloads] to regular history.
    /// If we have reached the end, we mark it.
    void addDayDownloads(DayDownloads day) {
        if (day.isEndOfHistory) {
            regularHasReachedEnd = true;
        } else {
            regularDays.add(day);
            regularDayOffset++;
        }
        regularIsLoading = false;
    }

    /// Merges a [DownloadSearch] result into the search history list.
    void addSearchResult(DownloadSearch result) {
        searchDays.addAll(result.days);
        searchDayOffset = result.nextDayOffset;
        searchHasReachedEnd = result.hasReachedEnd;
        searchIsLoading = false;
    }

    /// Clears search mode state to start fresh queries.
    void clearSearch() {
        searchDays.clear();
        searchDayOffset = 0;
        searchHasReachedEnd = false;
    }

    /// Clears regular mode state, wiping out all previous days.
    void clearRegular() {
        regularDays.clear();
        regularDayOffset = 0;
        regularHasReachedEnd = false;
    }

    @override
    void reload() {
        clearSearch();
        clearRegular();
        super.reload();
    }

    @override
    Map<String, dynamic> exportHistory() => {};

    @override
    Map<String, dynamic> export() => exportHistory();

    /// Whether we are in search mode (searching via query).
    bool get isSearchMode => query.isNotEmpty;

    /// Returns which list of days to show (search vs. regular).
    List<DayDownloads> get daysToShow => (isSearchMode) ? searchDays : regularDays;

    /// Whether we are currently loading new downloads.
    bool get isLoading => (isSearchMode) ? searchIsLoading : regularIsLoading;

    /// Whether we have reached the end or not.
    bool get hasReachedEnd => (isSearchMode) ? searchHasReachedEnd : regularHasReachedEnd;

    @override
    ViewType get type => ViewType.downloads;

    @override
    String get title => languageText("app_downloads");

    @override
    Widget? get favicon => null;

    @override
    Uint8List? get thumb => null;
}
