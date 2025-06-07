
import 'dart:async';

import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:nokubooru/State/settings.dart';

/// Enum for sorting favorite posts.
enum FavoriteSortOption { postId, source, rating, added }

/// Encapsulates the result of a lazy-loading operation.
class FavoriteLoadResult {
    final List<Post> posts;
    final bool hasReachedEnd;
    final int nextOffset;

    FavoriteLoadResult({
        required this.posts,
        required this.hasReachedEnd,
        required this.nextOffset,
    });
}

class Favorites {
    static Database? _db;
    static const int _defaultLimit = 20;

    // Map sort option enum to database column names.
    static const List<String> _sortColumns = [
        "post_id",
        "source",
        "rating",
        "added_timestamp"
    ];

    /// Initializes the SQLite database.
    static void _initDB() {
        if (_db != null) return;


        final dbPath = "${Settings.documentDirectory}/favorites.db";

        _db = sqlite3.open(dbPath);
        _db!.execute('''
            CREATE TABLE IF NOT EXISTS favorites (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                post_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                source TEXT NOT NULL,
                rating INTEGER NOT NULL,
                authors TEXT NOT NULL,
                tags TEXT NOT NULL,
                images TEXT NOT NULL,
                sources TEXT NOT NULL,
                preview TEXT NOT NULL,
                md5 TEXT,
                dimensions TEXT NOT NULL,
                poster TEXT NOT NULL,
                poster_id INTEGER,
                headers TEXT,
                added_timestamp INTEGER NOT NULL
            );
        ''');

        _db!.execute('''
            CREATE TABLE IF NOT EXISTS favorites_metadata (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                modified_timestamp INTEGER NOT NULL,
                sync_status TEXT
            );
        ''');

        _db!.execute('CREATE INDEX IF NOT EXISTS idx_post_id ON favorites(post_id);');
        _db!.execute('CREATE INDEX IF NOT EXISTS idx_title ON favorites(title);');
        _db!.execute('CREATE INDEX IF NOT EXISTS idx_source ON favorites(source);');
        _db!.execute('CREATE INDEX IF NOT EXISTS idx_added_timestamp ON favorites(added_timestamp);');

        final result = _db!.select('SELECT COUNT(*) as count FROM favorites_metadata');
        if ((result.first['count'] as int) == 0) {
            _db!.execute(
                'INSERT INTO favorites_metadata (id, modified_timestamp, sync_status) VALUES (1, ?, ?)',
                [DateTime.now().millisecondsSinceEpoch, "unsynced"]
            );
        }
    }

    static void _updateMetadata({int? modifiedTimestamp, String? syncStatus}) {
        _initDB();

        final params = [];
        var setClause = "";
        
        if (modifiedTimestamp != null) {
            setClause += "modified_timestamp = ?";
            params.add(modifiedTimestamp);
        }

        if (syncStatus != null) {
            if (setClause.isNotEmpty) setClause += ", ";
            setClause += "sync_status = ?";
            params.add(syncStatus);
        }

        if (setClause.isEmpty) return;

        params.add(1);

        _db!.execute(
            'UPDATE favorites_metadata SET $setClause WHERE id = ?',
            params
        );
    }

    /// Returns a map containing some metadata stored in the database.
    static Map<String, dynamic> getMetadata() {
        _initDB();

        final result = _db!.select('SELECT * FROM favorites_metadata WHERE id = 1');
        
        if (result.isNotEmpty) {
            return {
                'modified_timestamp': result.first['modified_timestamp'],
                'sync_status': result.first['sync_status'],
            };
        }
        
        return {};
    }

    /// Helper function to encode a list of strings into a delimited string (default: ',').
    static String _encodeList(List<String> list, [String delimiter = ',']) => list.join(delimiter);

    /// Decodes a delimited string into a list.
    static List<String> _decodeList(String string, [String delimiter = ',']) {
        if (string.isEmpty) return [];

        return string.split(delimiter).where((e) => e.isNotEmpty).toList();
    }

    /// Encodes [Tag] objects in a "original|translated|type" format, delimted by semicolons.
    static String _encodeTags(List<Tag> tags) => tags.map(
        (tag) => "${tag.original}|${tag.translated}|${tag.type.index}"
    ).join(";");

    /// Decodes the encoded [Tag] string back into a List<Tag>.
    static List<Tag> _decodeTags(String string) {
        if (string.isEmpty) return [];

        return string.split(";").map((tagStr) {
            final parts = tagStr.split("|");
            final original = parts.isNotEmpty ? parts[0] : "";
            final translated = parts.length > 1 ? parts[1] : "";
            final typeIndex = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
        
            return Tag(original, translated: translated, type: TagType.values[typeIndex]);
        }).toList();
    }

    /// Encodes [Dimensions] in an "x,y" format, with multiple values delimited by semicolons.
    static String _encodeDimensions(List<Dimensions> dims) => dims.map((d) => "${d.x},${d.y}").join(";");

    /// Decode [Dimensions] from the stored string.
    static List<Dimensions> _decodeDimensions(String s) {
        if (s.isEmpty) return [];
        return s.split(";").map((dimStr) {
            final parts = dimStr.split(",");
            final x = int.tryParse(parts[0]) ?? 0;
            final y = int.tryParse(parts[1]) ?? 0;
            return Dimensions(x, y);
        }).toList();
    }

    /// Encodes HTTP request headers following a "key=value" format, separated via semicolons.
    static String _encodeHeaders(Map<String, String> headers) => headers.entries.map(
        (element) => "${element.key}=${element.value}"
    ).join(";");

    /// Decodes HTTP headers from the encoded string.
    static Map<String, String> _decodeHeaders(String string) {
        final map = <String, String>{};

        if (string.isEmpty) return map;

        final pairs = string.split(";");

        for (final pair in pairs) {
            final keyValue = pair.split("=");

            if (keyValue.length == 2) {
                map[keyValue[0]] = keyValue[1];
            }
        }

        return map;
    }

    /// Adds a [Post] to the favorites database.
    static Future<bool> addFavorite(Post post) async {
        try {
            _initDB();

            // Prepare each field, so much fun.
            final postId = post.postID;
            final title = post.title;
            final source = post.source;
            final rating = post.rating.index;
            final authors = _encodeList(post.authors);
            final tags = _encodeTags(post.tags);
            final images = _encodeList(post.images);
            final sources = _encodeList(post.sources);
            final preview = post.preview;
            final md5 = _encodeList(post.md5);
            final dimensions = _encodeDimensions(post.dimensions);
            final poster = post.poster;
            final posterId = post.posterID;
            final headers = post.headers.isNotEmpty ? _encodeHeaders(post.headers) : "";
            final addedTimestamp = DateTime.now().millisecondsSinceEpoch;

            _db!.execute(
                "INSERT INTO favorites (post_id, title, source, rating, authors, tags, images, sources, preview, md5, dimensions, poster, poster_id, headers, added_timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    postId,
                    title,
                    source,
                    rating,
                    authors,
                    tags,
                    images,
                    sources,
                    preview,
                    md5,
                    dimensions,
                    poster,
                    posterId,
                    headers,
                    addedTimestamp
                ],
            );

            _updateMetadata(modifiedTimestamp: DateTime.now().millisecondsSinceEpoch);

            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to add favorite.", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Adds multiple posts in bulks.
    /// 
    /// This function should be used instead of [addFavorite] to avoid freezing the main app thread.
    static Future<bool> addFavoritesBulk(List<Post> posts) async {
        try {
            _initDB();

            // Begin a transaction
            _db!.execute("BEGIN TRANSACTION");
            
            // Prepare the insert statement once
            final stmt = _db!.prepare(
                "INSERT INTO favorites (post_id, title, source, rating, authors, tags, images, sources, preview, md5, dimensions, poster, poster_id, headers, added_timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            );
            
            for (final post in posts) {
                final postId = post.postID;
                final title = post.title;
                final source = post.source;
                final rating = post.rating.index;
                final authors = _encodeList(post.authors);
                final tags = _encodeTags(post.tags);
                final images = _encodeList(post.images);
                final sources = _encodeList(post.sources);
                final preview = post.preview;
                final md5 = _encodeList(post.md5);
                final dimensions = _encodeDimensions(post.dimensions);
                final poster = post.poster;
                final posterId = post.posterID;
                final headers = post.headers.isNotEmpty ? _encodeHeaders(post.headers) : "";
                final addedTimestamp = DateTime.now().millisecondsSinceEpoch;
                
                // Execute the statement for this post
                stmt.execute([
                    postId,
                    title,
                    source,
                    rating,
                    authors,
                    tags,
                    images,
                    sources,
                    preview,
                    md5,
                    dimensions,
                    poster,
                    posterId,
                    headers,
                    addedTimestamp
                ]);
            }
            
            stmt.dispose();
            
            _db!.execute("COMMIT TRANSACTION");
            
            // Update metadata after the bulk insertion
            _updateMetadata(modifiedTimestamp: DateTime.now().millisecondsSinceEpoch);
            return true;
        } catch (e, stackTrace) {
            _db!.execute("ROLLBACK TRANSACTION");

            Nokulog.e("Bulk insertion of posts failed.", error: e, stackTrace: stackTrace);

            return false;
        }
    }

    // Helper to create a Post from a database row.
    static Post _postFromRow(Row row) {
        final postId = row["post_id"] as int;
        final title = row["title"] as String;
        final source = row["source"] as String;
        final ratingInt = row["rating"] as int;
        final rating = Rating.values[ratingInt];
        final authors = _decodeList(row["authors"] as String);
        final tags = _decodeTags(row["tags"] as String);
        final images = _decodeList(row["images"] as String);
        final sources = _decodeList(row["sources"] as String);
        final preview = row["preview"] as String;
        final md5 = _decodeList(row["md5"] as String);
        final dimensions = _decodeDimensions(row["dimensions"] as String);
        final poster = row["poster"] as String;
        final posterId = row["poster_id"] as int?;
        
        var headers = <String, String>{};

        if (row["headers"] != null && (row["headers"] as String).isNotEmpty) {
            headers = _decodeHeaders(row["headers"] as String);
        }

        // parentID is set to null because we don't store it.
        return Post(
            postID: postId,
            tags: tags,
            sources: sources,
            images: images,
            authors: authors,
            source: source,
            preview: preview,
            md5: md5,
            rating: rating,
            parentID: null,
            dimensions: dimensions,
            poster: poster,
            posterID: posterId,
            title: title,
        )..setHeaders(headers);
    }

    /// Lazy-loads favorites with sorting.
    /// 
    /// [sortOption] determines the column to sort by.
    static Future<FavoriteLoadResult> loadFavorites({
        int offset = 0,
        int limit = _defaultLimit,
        FavoriteSortOption sortOption = FavoriteSortOption.added,
        bool ascending = false,
    }) async {
        try {
            _initDB();

            final orderColumn = _sortColumns[sortOption.index];
            final orderDir = ascending ? "ASC" : "DESC";
            final statement = _db!.prepare(
                "SELECT * FROM favorites ORDER BY $orderColumn $orderDir LIMIT ? OFFSET ?"
            );
            final resultSet = statement.select([limit, offset]);
            
            statement.dispose();

            final posts = resultSet.map((row) => _postFromRow(row)).toList(growable: false);
            final hasReachedEnd = posts.length < limit;
            final nextOffset = offset + posts.length;
            
            return FavoriteLoadResult(
                posts: posts, 
                hasReachedEnd: hasReachedEnd, 
                nextOffset: nextOffset
            ); 
        } catch (e, stackTrace) {
            Nokulog.e("Failed to load favorites.", error: e, stackTrace: stackTrace);

            return FavoriteLoadResult(
                posts: [], 
                hasReachedEnd: true, 
                nextOffset: offset
            );
        }
    }

    /// Lazy-loads favorites that match a search query.
    /// 
    /// For multiple-tag queries, each token is required to match (via fuzzy matching) against the tags.
    /// 
    /// For single-tag queries, the search is performed on title, post_id, source, authors, and tags.
    static Future<FavoriteLoadResult> searchFavorites(
        String query, {
        int offset = 0,
        int limit = _defaultLimit,
        FavoriteSortOption sortOption = FavoriteSortOption.added,
        bool ascending = false,
    }) async {
        try {
            _initDB();
            final orderColumn = _sortColumns[sortOption.index];
            final orderDir = ascending ? "ASC" : "DESC";

            final tokens = query.trim().split(RegExp(r'\s+'));
            
            ResultSet result;

            if (tokens.length > 1) {
                final tagCondition = tokens.map((_) => "tags LIKE ?").join(" AND ");

                final statement = _db!.prepare(
                    "SELECT * FROM favorites WHERE $tagCondition ORDER BY $orderColumn $orderDir LIMIT ? OFFSET ?"
                );
                
                final params = tokens.map<dynamic>((token) => '%$token%').toList();
                
                params.add(limit);
                params.add(offset);

                result = statement.select(params);
                
                statement.dispose();
            } else {
                final likeQuery = '%$query%';
                final statement = _db!.prepare(
                    '''
                    SELECT * FROM favorites 
                    WHERE title LIKE ? OR CAST(post_id AS TEXT) LIKE ? OR source LIKE ? OR authors LIKE ? OR tags LIKE ?
                    ORDER BY $orderColumn $orderDir 
                    LIMIT ? OFFSET ?
                    '''
                );

                result = statement.select(
                    [likeQuery, likeQuery, likeQuery, likeQuery, likeQuery, limit, offset]
                );
                
                statement.dispose();
            }

            final posts = result.map((row) => _postFromRow(row)).toList(growable: false);
            final hasReachedEnd = posts.length < limit;
            final nextOffset = offset + posts.length;
            
            return FavoriteLoadResult(
                posts: posts,
                hasReachedEnd: hasReachedEnd, 
                nextOffset: nextOffset
            );
        } catch (e, stackTrace) {
            Nokulog.e("Failed to search favorites.", error: e, stackTrace: stackTrace);

            return FavoriteLoadResult(
                posts: [], 
                hasReachedEnd: true, 
                nextOffset: offset
            );
        }
    }

    static Future<bool> updateFavorite(Post post) async {
        try {
            _initDB();

            final postId = post.postID;
            final title = post.title;
            final source = post.source;
            final rating = post.rating.index;
            final authors = _encodeList(post.authors);
            final tags = _encodeTags(post.tags);
            final images = _encodeList(post.images);
            final sources = _encodeList(post.sources);
            final preview = post.preview;
            final md5 = _encodeList(post.md5);
            final dimensions = _encodeDimensions(post.dimensions);
            final poster = post.poster;
            final posterId = post.posterID;
            final headers = post.headers.isNotEmpty ? _encodeHeaders(post.headers) : "";

            final statement = _db!.prepare(
                "UPDATE favorites SET title = ?, rating = ?, authors = ?, tags = ?, images = ?, sources = ?, preview = ?, md5 = ?, dimensions = ?, poster = ?, poster_id = ?, headers = ? WHERE post_id = ? AND source = ?"
            );

            statement.execute([
                title,
                rating,
                authors,
                tags,
                images,
                sources,
                preview,
                md5,
                dimensions,
                poster,
                posterId,
                headers,
                postId,
                source
            ]);
            
            statement.dispose();

            _updateMetadata(modifiedTimestamp: DateTime.now().millisecondsSinceEpoch);

            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to update favorite for post: ${post.identifier}", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Deletes a specific favorite post from the database.
    static Future<bool> deleteFavorite(Post post) async {
        try {
            _initDB();
            
            // We use the ID and the source to identify a post.
            _db!.execute("DELETE FROM favorites WHERE post_id = ? AND source = ?", [post.postID, post.source]);
            
            _updateMetadata(modifiedTimestamp: DateTime.now().millisecondsSinceEpoch);

            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to delete favorite.", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Returns whether a post is a favorite post.
    static bool isFavorite(Post post) {
        try {
            _initDB();

            final statement = _db!.prepare(
                "SELECT COUNT(*) as count FROM favorites WHERE post_id = ? AND source = ?"
            );
            final result = statement.select([post.postID, post.source]);
            
            statement.dispose();
            
            if (result.isNotEmpty) {
                final count = result.first["count"] as int;
                return count > 0;
            }

            return false;
        } catch (e, stackTrace) {
            Nokulog.e(
                "Error checking existence of favorite for post: ${post.identifier}",
                error: e,
                stackTrace: stackTrace
            );

            return false;
        }
    }

    /// Dispose of the database connection.
    static void dispose() {
        _db?.dispose();
        _db = null;
    }
}

