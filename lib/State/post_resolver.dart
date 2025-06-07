import 'dart:async';
import 'package:nokubooru/State/searcher.dart';
import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';

class PostResult {
    final Future<Post?>? post;
    final String query;
    final String source;

    const PostResult({
        this.post,
        this.query = "",
        this.source = "",
    });

    @override
    String toString() => "post: ${post?.toString() ?? '(none)'} | query: ${query.isEmpty ? '(empty)' : query}";
}

class PostResolver {
    static final Map<Pattern, PostResult Function(Uri)> _handlers = {};
    static final RegExp _md5Regex = RegExp(r"[a-fA-F0-9]{32}");
    static const _defaultResult = PostResult();

    static void registerHandler(Pattern pattern, PostResult Function(Uri) handler) {
        _handlers[pattern] = handler;
    }

    static PostResult resolve(Uri url) {
        final host = url.host.replaceFirst("www.", "");
        
        for (final pattern in _handlers.keys) {
            if (host.contains(pattern)) {
                try {
                    final result = _handlers[pattern]!(url);
                    if (result.post != null || result.query.isNotEmpty) return result;
                } catch (e, stackTrace) {
                    Nokulog.e("Handler error for $pattern", error: e, stackTrace: stackTrace);
                }
            }
        }

        return _defaultResult;
    }

    /// Initializes the resolver, registering handlers for different types of URLs.
    static void initialize() {
        registerHandler("danbooru.donmai.us", _handleDanbooru);
        registerHandler(RegExp(r"^(rule34\.xxx|gelbooru\.com|safebooru\.org)$"), _handleGelbooruFamily);
        registerHandler(RegExp(r"^(konachan\.com|yande\.re)$"), _handleMoebooru);
        registerHandler(RegExp(r"^(nhentai\.net|i\.nhentai\.net)$"), _handleNHentai);
        registerHandler("nozomi.la", _handleNozomi);
        registerHandler("pixiv.net", _handlePixiv);
        registerHandler("i.pximg.net", _handlePximg);
        registerHandler("files.yande.re", _handleYandeFiles);
        registerHandler(RegExp(r"^(cdn\.donmai\.us|api-cdn\.rule34\.xxx|img3\.gelbooru\.com)$"), _handleCdnHosts);
    }

    /// Handles a Danbooru URL.
    static PostResult _handleDanbooru(Uri url) {
        Nokulog.w("We are in danbooru: ${url.pathSegments}");

        if (url.pathSegments.isEmpty || url.pathSegments[0] != "posts") {
            return _defaultResult;
        }

        final query = url.queryParameters["tags"] ?? url.queryParameters["q"] ?? "";

        Nokulog.i("query: $query");

        if (url.pathSegments.length >= 2) {
            final postID = _tryParseInt(url.pathSegments[1]);

            if (postID != null) {
                return PostResult(
                    post: _getPost(postID, client: "danbooru"),
                    query: query,
                    source: "danbooru",
                );
            }
        }

        return PostResult(query: query, source: "danbooru");
    }

    /// Handles the Gelbooru / Safebooru / Rule34 URL style.
    static PostResult _handleGelbooruFamily(Uri url) {
        final source = switch (url.host) {
            "safebooru.org" => "safebooru",
            "gelbooru.com" => "gelbooru",
            "rule34.xxx" => "rule34",
            _ => ""
        };

        if (url.pathSegments.isEmpty) return _defaultResult;

        if (source == "safebooru" && url.pathSegments.last.isEmpty) {
            final md5 = _md5Regex.firstMatch(url.pathSegments.last)?.group(0);
            if (md5 == null) return _defaultResult;
            final post = _searchMD5(md5, source);
            return PostResult(post: post, source: source);
        }

        if (url.pathSegments.first != "index.php" || url.queryParameters["page"] != "post") {
            return _defaultResult;
        }

        String possibleQuery = url.queryParameters["tags"] ?? "";
        possibleQuery = possibleQuery == "all" ? "" : possibleQuery;

        final postID = _tryParseInt(url.queryParameters["id"]);
        if (postID == null) {
            return PostResult(query: possibleQuery, source: source);
        }

        return PostResult(
            post: _getPost(postID, client: source),
            query: possibleQuery,
            source: source,
        );
    }

    /// Handles Moebooru (Yande.re / Konachan) URLs.
    static PostResult _handleMoebooru(Uri url) {
        final source = url.host == "yande.re" ? "yande.re" : "konachan";
        
        if (source == "konachan" && url.pathSegments.firstOrNull == "image") {
            final filename = url.pathSegments.last;
            if (filename.startsWith("Konachan.com")) {
                try {
                    final postID = _tryParseInt(filename.split(" ")[2]);
                    if (postID != null) {
                        return PostResult(
                            post: _getPost(postID, client: source),
                            source: source,
                        );
                    }
                } catch (e, stackTrace) {
                    Nokulog.e("Konachan image ID parse error", error: e, stackTrace: stackTrace);
                }
            }
            return _defaultResult;
        }

        if (url.pathSegments.isEmpty || url.pathSegments.first != "post") {
            return _defaultResult;
        }

        if (url.hasQuery) {
            return PostResult(
                query: url.queryParameters["tags"] ?? "",
                source: source,
            );
        }

        try {
            final stringID = url.pathSegments.last.isNumeric ? 
                url.pathSegments.last : 
                url.pathSegments[url.pathSegments.length - 2];
            final postID = _tryParseInt(stringID);
            
            return postID != null ? 
                PostResult(
                    post: _getPost(postID, client: source),
                    source: source,
                ) : 
                _defaultResult;
        } catch (e, stackTrace) {
            Nokulog.e("Moebooru ID parse error", error: e, stackTrace: stackTrace);
            return _defaultResult;
        }
    }

    /// Handles NHentai URLs.
    static PostResult _handleNHentai(Uri url) {
        if (url.hasQuery) {
            return PostResult(
                query: url.queryParameters["q"] ?? "",
                source: "nhentai",
            );
        }

        if (url.pathSegments.length < 2) return _defaultResult;
        
        final postID = _tryParseInt(url.pathSegments[1]);
        return postID != null ?
            PostResult(
                post: _getPost(postID, client: "nhentai"),
                source: "nhentai",
            ) :
            _defaultResult;
    }

    /// Handles Nozomi URLs.
    static PostResult _handleNozomi(Uri url) {
        if (url.hasQuery) {
            return PostResult(
                query: url.queryParameters["q"] ?? "",
                source: "nozomi",
            );
        }

        if (url.pathSegments.length < 2) return _defaultResult;
        
        final postID = _tryParseInt(url.pathSegments[1].replaceAll(".html", ""));
        return postID != null ?
            PostResult(
                post: _getPost(postID, client: "nozomi"),
                query: url.fragment,
                source: "nozomi",
            ) :
            _defaultResult;
    }

    /// Handles Pixiv URLs.
    static PostResult _handlePixiv(Uri url) {
        final hasArtwork = url.pathSegments.contains("artworks");
        final hasUsers = url.pathSegments.contains("users");
        final hasTags = url.pathSegments.contains("tags");

        if (!hasArtwork && !hasUsers && !hasTags) return _defaultResult;

        if (hasTags) {
            final query = _getPathSegmentAfter(url.pathSegments, "tags");
            return query != null ?
                PostResult(query: query, source: "pixiv") :
                _defaultResult;
        }

        if (hasArtwork) {
            final postID = _tryParseInt(_getPathSegmentAfter(url.pathSegments, "artworks"));
            return postID != null ?
                PostResult(
                    post: _getPost(postID, client: "pixiv"),
                    source: "pixiv",
                ) :
                _defaultResult;
        }

        if (hasUsers) {
            final artistID = _tryParseInt(_getPathSegmentAfter(url.pathSegments, "users"));
            return artistID != null ?
                PostResult(query: "artist:$artistID", source: "pixiv") :
                _defaultResult;
        }

        return _defaultResult;
    }

    /// Handles a Pixiv image URL.
    static PostResult _handlePximg(Uri url) {
        try {
            final filename = url.pathSegments.last;
            final postID = _tryParseInt(filename.split("_p").first);
            return postID != null ?
                PostResult(
                    post: _getPost(postID, client: "pixiv"),
                    source: "pixiv",
                ) :
                _defaultResult;
        } catch (e, stackTrace) {
            Nokulog.e("Pximg parse error", error: e, stackTrace: stackTrace);
            return _defaultResult;
        }
    }

    /// Handles a Yande.re image URL.
    static PostResult _handleYandeFiles(Uri url) {
        final filename = url.pathSegments.last;
        if (!filename.startsWith("yande.re")) return _defaultResult;
        
        final postID = _tryParseInt(filename.split(" ")[1]);
        return postID != null ?
            PostResult(
                post: _getPost(postID, client: "yande.re"),
            ) :
            _defaultResult;
    }

    /// Handles image posts for Danbooru / Gelbooru / Rule34 CDNs.
    static PostResult _handleCdnHosts(Uri url) {
        final source = switch (url.host) {
            "cdn.donmai.us" => "danbooru",
            "img3.gelbooru.com" => "gelbooru",
            "api-cdn.rule34.xxx" => "rule34",
            _ => ""
        };

        final filename = url.pathSegments.last;
        final md5Match = _md5Regex.firstMatch(filename)?.group(0);
        if (md5Match == null) return _defaultResult;

        final post = _searchMD5(md5Match, source);
        return PostResult(post: post, source: source);
    }

    /// Returns the segment that comes after the given segment.
    static String? _getPathSegmentAfter(Iterable<String> segments, Pattern match) {
        bool found = false;
        for (final segment in segments) {
            if (found) return segment;
            if (segment == match) found = true;
        }
        return null;
    }

    /// Searches for a post via an MD5 hash.
    static Future<Post?> _searchMD5(String query, String source) async {
        final posts = await Searcher.searchPosts("md5:$query", client: source);
        return posts.firstOrNull;
    }

    /// Fetches a post via it's ID.
    static Future<Post?> _getPost(int postID, {String? client}) async => (await Searcher.getPost(postID, client: client)).firstOrNull;

    
    static int? _tryParseInt(String? input) => int.tryParse(input ?? '');
}

extension _StringParsing on String {
    bool get isNumeric => int.tryParse(this) != null;
}
