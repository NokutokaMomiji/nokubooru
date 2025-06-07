import 'dart:collection';

import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';
import 'package:sqlite3/sqlite3.dart';

/// A simple, record-like class holding a search query and a list of matching tags.
class TagSearch {
    final String query;
    final List<Tag> tags;
    
    TagSearch(this.query, this.tags);

    @override
    String toString() => 'TagSearch(query: $query, tags: $tags)';
}

/// Class that manages the Tags SQLite database.
///
/// The Tags database stores all tags found from posts. This allows us to display search suggestions.
/// It also stores the user's favorited tags and keeps track of frequency of searched tags.
class Tags {
    static Database? _db;
    static final HashSet<String> _favoriteTags = HashSet<String>();

    /// Initializes the Tags class.
    static Future<bool> init() async {
        try {
            dispose();

            final a = _loadFavoriteTags();

            final specialTags = await fetchSpecial();
            
            specialTags.removeWhere((tag) => tag.original == "bow");

            Post.specialTags.addAll({for (final tag in specialTags) tag.original: tag});

            await a;

            Nokulog.d("Tags initialized!");
            
            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Tags class initialization failed.", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Adds tags to the database.
    static Future<bool> add(Iterable<Tag> tags) async {
        Nokulog.i("IN ADD!");

        try {
            if (_db == null) _initDB();

            int getPriority(Tag tag) {
                if (tag.type != TagType.general && tag.translated.isNotEmpty) {
                    return 1;
                }
                if (tag.type != TagType.general) {
                    return 2;
                }
                if (tag.type == TagType.general && tag.translated.isNotEmpty) {
                    return 3;
                }
                return 4;
            }

            final Map<String, Tag> uniqueTags = {};
            for (final tag in tags) {
                final key = tag.original.toLowerCase();
                if (uniqueTags.containsKey(key)) {
                    final existing = uniqueTags[key]!;
                    if (getPriority(tag) < getPriority(existing)) {
                        uniqueTags[key] = tag;
                    }
                } else {
                    uniqueTags[key] = tag;
                }
            }

            _db!.execute("BEGIN TRANSACTION;");
            final stmtSelect = _db!.prepare(
                "SELECT id, type, translated FROM tags WHERE original = ? AND translated = ?;"
            );
            final stmtUpdate = _db!.prepare(
                "UPDATE tags SET type = ?, translated = ? WHERE id = ?;"
            );
            final stmtInsert = _db!.prepare(
                "INSERT INTO tags (original, translated, type) VALUES (?, ?, ?);"
            );

            for (final tag in uniqueTags.values) {
                final result = stmtSelect.select([tag.original, tag.translated]);
                if (result.isNotEmpty) {
                    final existingType = result.first["type"];
                    final existingTranslated = result.first["translated"] as String? ?? "";
                    final Tag storedTag = Tag(
                        tag.original,
                        translated: existingTranslated,
                        type: TagType.values[existingType],
                    );
                    if (getPriority(tag) < getPriority(storedTag)) {
                        stmtUpdate.execute([tag.type.index, tag.translated, result.first["id"]]);
                    }
                } else {
                    stmtInsert.execute([tag.original, tag.translated, tag.type.index]);
                }
            }

            stmtSelect.dispose();
            stmtUpdate.dispose();
            stmtInsert.dispose();
            _db!.execute("COMMIT;");

            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to add ${tags.length} tags to the tag database.", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Deletes all stored tags from the database. Returns a boolean value that indicates whether
    /// the deletion was successful.
    static Future<bool> deleteAllTags() async {
        try {
            if (_db == null) _initDB();

            // Remove all tags
            _db!.execute("DELETE FROM tags;");

            Post.specialTags.clear();

            Nokulog.i("All tags have been deleted.");
            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to delete all tags.", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Searches tags with fuzzy matching and pagination.
    static Future<List<Tag>> search(String query, int maxMatches, int offset) async {
        try {
            _initDB();

            final limit = maxMatches * 5;
            final realOffset = offset ~/ 5;

            final ResultSet result = _db!.select(
                "SELECT original, translated, type FROM tags WHERE original LIKE ? OR translated LIKE ? LIMIT ? OFFSET ?",
                ["%$query%", "%$query%", limit, (realOffset * limit)]
            );

            final List<Tag> potentialMatches = result.map(
                (row) => Tag(
                    row["original"] as String,
                    translated: row["translated"] as String,
                    type: TagType.values[row["type"] as int]
                )
            ).toList();

            final List<Tag> matchingTags = potentialMatches.where(
                (tag) => fuzzyMatch(tag.original, query) || fuzzyMatch(tag.translated, query)
            ).toList();

            matchingTags.sort((first, second) {
                final bool firstExact = (first.original == query || first.translated == query);
                final bool secondExact = (second.original == query || second.translated == query);
                
                if (firstExact && !secondExact) return -1;
                if (secondExact && !firstExact) return 1;

                final bool firstStarts = (first.original.startsWith(query) || first.translated.startsWith(query));
                final bool secondStarts = (second.original.startsWith(query) || second.translated.startsWith(query));
                
                if (firstStarts && !secondStarts) return -1;
                if (secondStarts && !firstStarts) return 1;

                final double scoreFirst = bestSimilarity(first, query);
                final double scoreSecond = bestSimilarity(second, query);
                
                return scoreSecond.compareTo(scoreFirst);
            });
            
            if (matchingTags.length < limit) return matchingTags;

            final startIndex = (offset % 5) * maxMatches;
            final endIndex = startIndex + maxMatches;

            final list = matchingTags.sublist(startIndex, endIndex);

            return list;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to search tags for query \"$query\".", error: e, stackTrace: stackTrace);
            return [];
        }
    }

    /// Fetches special tags.
    static Future<List<Tag>> fetchSpecial() async {
        if (_db == null) _initDB();

        final rows = _db!.select(
            "SELECT * FROM tags WHERE type > ${TagType.general.index}"
        );

        return rows.map((row) => Tag(
                row["original"],
                translated: row["translated"] ?? "",
                type: TagType.values[row["type"]],
            )).toList();
    }

    /// Returns the total number of rows in the tags table.
    static int countRows() {
        if (_db == null) _initDB();

        final result = _db!.select("SELECT COUNT(*) AS count FROM tags;");
        if (result.isNotEmpty) {
            return result.first["count"] as int;
        }
        return 0;
    }

    /// Adds a search query to the search_queries table.
    /// The query is trimmed; if it already exists, the old one is removed.
    /// Newer queries appear first.
    static Future<bool> addSearchQuery(String query) async {
        try {
            if (_db == null) _initDB();

            final String cleanedQuery = query.trim();

            if (cleanedQuery.isEmpty) return false;

            _db!.execute("DELETE FROM search_queries WHERE query = ?;", [cleanedQuery]);

            final int timestamp = DateTime.now().millisecondsSinceEpoch;
            _db!.execute("INSERT INTO search_queries (query, timestamp) VALUES (?, ?);", [cleanedQuery, timestamp]);

            updateSearchTagFrequency(cleanedQuery);

            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to add search query: $query", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Lazy-loads search queries.
    /// For each stored query, finds tags from the tags table that are contained within the query string.
    /// Returns a list of TagSearch records.
    static Future<List<TagSearch>> loadSearchQueries(int maxMatches, int offset, {bool withTags = false}) async {
        try {
            if (_db == null) _initDB();

            final ResultSet queryRows = _db!.select(
                "SELECT query FROM search_queries ORDER BY timestamp DESC LIMIT ? OFFSET ?",
                [maxMatches, (offset * maxMatches)]
            );

            //Nokulog.d("queryRows: ${queryRows.length}");

            final List<TagSearch> results = [];
            for (final row in queryRows) {
                final String storedQuery = row["query"] as String;
                Nokulog.d("Stored Query: $storedQuery");

                if (!withTags) {
                    //Nokulog.d("storedQuery: $storedQuery | (skipped tags)");
                    results.add(TagSearch(storedQuery, []));
                    continue;
                }

                final tokenSet = splitRespectingQuotes(storedQuery).toSet();

                final List<Tag> foundTags = [];
                for (final token in tokenSet) {
                    //Nokulog.d("Token: $token");

                    final ResultSet tagRows = _db!.select(
                        "SELECT original, translated, type FROM tags WHERE original LIKE '%' || ? || '%' OR translated LIKE '%' || ? || '%'",
                        [token, token]
                    );

                    for (final tagRow in tagRows) {
                        final Tag tag = Tag(
                            tagRow["original"] as String,
                            translated: tagRow["translated"] as String,
                            type: TagType.values[tagRow["type"] as int]
                        );

                        // Add tag only if it hasn't been added already.
                        if (!foundTags.contains(tag)) {
                            foundTags.add(tag);
                        }
                    }
                }

                //Nokulog.d("storedQuery: $storedQuery | foundTags: ${foundTags.length}");
                results.add(TagSearch(storedQuery, foundTags));
            }

            return results;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to load search queries.", error: e, stackTrace: stackTrace);
            return [];
        }
    }

    /// Updates the frequency count for tags found in the provided query string.
    static void updateSearchTagFrequency(String query) {
        // The expletive might seem like too much, but I literally froze the app because it tried writing over 9000 rows in one go.
        if (query.isEmpty) {
            Nokulog.w("Search tag frequency was attempted to be updated with an empty string, which is very fucking dangerous.");
            return;
        }

        final List<String> queryTags = splitRespectingQuotes(query);

        for (final tag in queryTags) {
            if (tag.isEmpty) continue;

            final ResultSet tagExists = _db!.select(
                "SELECT 1 FROM tags WHERE original = ? OR translated = ? LIMIT 1;", 
                [tag, tag]
            );

            //Nokulog.d("tag ($tag) exists: ${tagExists.length}");

            if (tagExists.isNotEmpty) {
                final ResultSet exists = _db!.select("SELECT frequency FROM search_tag_frequency WHERE tag = ?;", [tag]);

                if (exists.isNotEmpty) {
                    _db!.execute("UPDATE search_tag_frequency SET frequency = frequency + 1 WHERE tag = ?;", [tag]);
                } else {
                    _db!.execute("INSERT INTO search_tag_frequency (tag, frequency) VALUES (?, 1);", [tag]);
                }
            }
        }
    }

    /// Retrieves a frequency map of tags from the search_tag_frequency table.
    static Map<String, int> getTagFrequencyMap() {
        final ResultSet result = _db!.select("SELECT tag, frequency FROM search_tag_frequency ORDER BY frequency DESC;");
        final Map<String, int> frequencyMap = {};

        for (final row in result) {
            frequencyMap[row["tag"] as String] = row["frequency"] as int;
        }
        
        return frequencyMap;
    }

    // Clears all records from the search_queries and search_tag_frequency tables.
    static Future<bool> clearSearchHistory() async {
        try {
            if (_db == null) _initDB();

            _db!.execute("BEGIN TRANSACTION;");
            _db!.execute("DELETE FROM search_queries;");
            _db!.execute("DELETE FROM search_tag_frequency;");
            _db!.execute("COMMIT;");

            Nokulog.i("Successfully cleared search history and tag frequencies.");
            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to clear search history and tag frequencies.", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Adds a tag to the favorites list in the database.
    static bool addToFavorites(Tag tag) {
        try {
            if (_db == null) _initDB();

            final ResultSet exists = _db!.select(
                "SELECT 1 FROM favorites WHERE original = ? LIMIT 1;",
                [tag.original]
            );

            if (exists.isNotEmpty) {
                return true;
            }

            _db!.execute(
                "INSERT INTO favorites (original, translated, type) VALUES (?, ?, ?);",
                [tag.original, tag.translated, tag.type.index]
            );

            _favoriteTags.add(tag.original);

            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to add tag to favorites: ${tag.original}", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Removes the specified tag from the favorites list, if it exists.
    static Future<bool> removeFromFavorites(Tag tag) async {
        try {
            if (_db == null) _initDB();

            _db!.execute(
                "DELETE FROM favorites WHERE original = ?;",
                [tag.original]
            );

            _favoriteTags.remove(tag.original);

            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to remove tag from favorites: ${tag.original}", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Checks if a tag is in the favorites list.
    static bool isFavorite(Tag tag) => _favoriteTags.contains(tag.original);

    static List<String> getFavoriteTags() {
        return _favoriteTags.toList();
    }

    /// Disposes the database connection.
    static void dispose() {
        _db?.dispose();
        _db = null;
    }

    /// Initializes the database and creates required tables.
    static void _initDB() {
        if (_db != null) return;

        final dbPath = "${Settings.documentDirectory}/tags.db";
        _db = sqlite3.open(dbPath);

        _db!.execute("""
            CREATE TABLE IF NOT EXISTS tags (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                original TEXT NOT NULL,
                translated TEXT,
                type INTEGER NOT NULL,
                UNIQUE(original, translated)
            );
        """);

        _db!.execute("CREATE INDEX IF NOT EXISTS idx_tags_original ON tags(original);");
        _db!.execute("CREATE INDEX IF NOT EXISTS idx_tags_translated ON tags(translated);");
        
        _db!.execute("""
            CREATE TABLE IF NOT EXISTS search_queries (
                query TEXT PRIMARY KEY,
                timestamp INTEGER NOT NULL
            );
        """);

        _db!.execute("""
            CREATE TABLE IF NOT EXISTS search_tag_frequency (
                tag TEXT PRIMARY KEY,
                frequency INTEGER NOT NULL
            );
        """);

        _db!.execute("""
            CREATE TABLE IF NOT EXISTS favorites (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                original TEXT NOT NULL UNIQUE,
                translated TEXT,
                type INTEGER NOT NULL
            );
        """);
    }

    static Future<void> _loadFavoriteTags() async {
        try {
            if (_db == null) _initDB();

            final ResultSet results = _db!.select("SELECT original FROM favorites;");
            
            for (final row in results) {
                _favoriteTags.add(row["original"] as String);
            }
        } catch (e, stackTrace) {
            Nokulog.e("Failed to load favorite tags into a set.", error: e, stackTrace: stackTrace);
        }
    }
}
