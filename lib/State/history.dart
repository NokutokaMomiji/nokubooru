import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/utils.dart';
import 'package:sqlite3/sqlite3.dart';

class HistoryData {
    final ViewType type;
    final Map<String, dynamic> data;
    final String title;
    final String? thumb;
    final Map<String, String>? headers;
    final DateTime timestamp;

    HistoryData({required this.type, required this.data, required this.title, this.thumb, this.headers, required this.timestamp});

    String get url {
        final dataParts = [for (final record in data.entries) "${record.key}=${record.value}"];

        return "nokubooru://${type.name}?${dataParts.join("&")}";
    }
}

class DayHistory {
    final DateTime day;
    final List<HistoryData> entries;
    final bool isEndOfHistory;

    DayHistory({required this.day, required this.entries, required this.isEndOfHistory});
}

class HistorySearch {
    final List<DayHistory> days;
    final int nextDayOffset;
    final bool hasReachedEnd;

    HistorySearch({required this.days, required this.nextDayOffset, required this.hasReachedEnd});
}

class History {
    static final List<HistoryData> _history = [];
    static const Set<ViewType> _acceptedTypes = {ViewType.search, ViewType.post, ViewType.viewer};
    static Database? _db;

    static Future<(String, Map<String, String>)?> _getThumbFromData(ViewData data) async {
        if (data is ViewSearch) {
            var results = data.queryResults;

            if (results.isEmpty) {
                results = await data.searchFuture;
            }

            if (results.isEmpty) return null;

            final result = randomWhereOrNull(results, (_) => true)!;

            return (result.preview, result.headers);
        }

        if (data is ViewPost) {
            return (data.post.preview, data.post.headers);
        }

        return null;
    }

    static Future<void> add(ViewData data) async {
        if (!_acceptedTypes.contains(data.type)) return;

        final Map<String, dynamic> export = data.exportHistory();

        if (_history.lastOrNull?.type == data.type && mapEquals(_history.lastOrNull?.data, export)) {
            return;
        }

        final items = await _getThumbFromData(data);

        final newEntry = HistoryData(
            type: data.type,
            data: data.exportHistory(),
            title: data.title,
            thumb: items?.$1,
            headers: items?.$2,
            timestamp: DateTime.now(),
        );

        _history.add(newEntry);
        await save(newEntry);
    }

    
    static Future<bool> save(HistoryData entry) async {
        try {
            _initDB();

            final data = jsonEncode(entry.data);
            final headers = (entry.headers != null) ? jsonEncode(entry.headers) : entry.headers;
            final timestamp = entry.timestamp.millisecondsSinceEpoch;

            _db!.execute(
                "INSERT INTO history (type, data, title, thumb, headers, timestamp) VALUES (?, ?, ?, ?, ?, ?)",
                [entry.type.index, data, entry.title, entry.thumb, headers, timestamp]
            );

            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to save History database.", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    static Future<DayHistory> loadDayHistory(int dayOffset) async {
        try {
            _initDB();

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final targetDay = today.subtract(Duration(days: dayOffset));

            final startTimestamp = targetDay.millisecondsSinceEpoch;
            final endTimestamp = targetDay.add(const Duration(days: 1)).millisecondsSinceEpoch;

            final ResultSet result = _db!.select(
                "SELECT type, data, title, thumb, headers, timestamp FROM history WHERE timestamp >= ? AND timestamp < ? ORDER BY timestamp DESC",
                [startTimestamp, endTimestamp]
            );

            final entries = result.map(
                (row) => HistoryData(
                    type: ViewType.values[row["type"] as int], 
                    data: Map<String, dynamic>.from(jsonDecode(row["data"] as String)),
                    title: row["title"] as String,
                    thumb: row["thumb"] as String?,
                    headers: (row["headers"] != null) ? Map<String, String>.from(jsonDecode(row["headers"])) : null,
                    timestamp: DateTime.fromMillisecondsSinceEpoch(row["timestamp"] as int)
                )
            ).toList();

            var isEndOfHistory = false;
            final ResultSet minResult = _db!.select("SELECT MIN(timestamp) as min_ts FROM history");

            if (minResult.isNotEmpty && minResult.first["min_ts"] != null) {
                final minTs = minResult.first["min_ts"] as int;
                final earliest = DateTime.fromMillisecondsSinceEpoch(minTs);
                final earliestDay = DateTime(earliest.year, earliest.month, earliest.day);

                if (targetDay.isBefore(earliestDay)) {
                    isEndOfHistory = true;
                }
            } else {
                isEndOfHistory = true;
            }

            return DayHistory(
                day: targetDay, 
                entries: entries, 
                isEndOfHistory: isEndOfHistory
            );
        } catch (e, stackTrace) {
            Nokulog.e("Failed to load day history at offset $dayOffset.", error: e, stackTrace: stackTrace);
            return DayHistory(
                day: DateTime.now(), 
                entries: [],
                isEndOfHistory: false
            );
        }
    }

    static Future<DayHistory> searchDayHistory(int dayOffset, String query) async {
        try {
            _initDB();

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            
            final targetDay = today.subtract(Duration(days: dayOffset));
            final startTimestamp = targetDay.millisecondsSinceEpoch;
            final endTimestamp = targetDay.add(const Duration(days: 1)).millisecondsSinceEpoch;
            
            final ResultSet result = _db!.select(
                "SELECT type, data, title, thumb, headers, timestamp FROM history WHERE timestamp >= ? AND timestamp < ? ORDER BY timestamp DESC",
                [startTimestamp, endTimestamp],
            );

            final List<HistoryData> allEntries = result.map(
                (row) => HistoryData(
                    type: ViewType.values[row["type"] as int],
                    data: Map<String, dynamic>.from(jsonDecode(row["data"] as String)),
                    title: row["title"] as String,
                    thumb: row["thumb"] as String?,
                    headers: (row["headers"] != null) ? Map<String, String>.from(jsonDecode(row["headers"])) : null,
                    timestamp: DateTime.fromMillisecondsSinceEpoch(row["timestamp"] as int),
                )
            ).toList();

            final List<HistoryData> matchingEntries = allEntries.where((entry) => fuzzyMatch(entry.title, query)).toList();
            bool isEndOfHistory = false;
            final ResultSet minResult = _db!.select("SELECT MIN(timestamp) as min_ts FROM history");

            if (minResult.isNotEmpty && minResult.first["min_ts"] != null) {
                final minTs = minResult.first["min_ts"] as int;
                final earliest = DateTime.fromMillisecondsSinceEpoch(minTs);
                final earliestDay = DateTime(earliest.year, earliest.month, earliest.day);

                if (targetDay.isBefore(earliestDay)) {
                    isEndOfHistory = true;
                }
            } else {
                isEndOfHistory = true;
            }

            return DayHistory(day: targetDay, entries: matchingEntries, isEndOfHistory: isEndOfHistory);
        } catch (e, stackTrace) {
            Nokulog.e("Failed to fetch day history at offset $dayOffset for query \"$query\".", error: e, stackTrace: stackTrace);
            return DayHistory(day: DateTime.now(), entries: [], isEndOfHistory: false);
        }
    }

    static Future<HistorySearch> search(String query, {int startingDayOffset = 0}) async {
        final List<DayHistory> days = [];
        int dayOffset = startingDayOffset;
        int totalMatches = 0;
        bool reachedEnd = false;

        while (totalMatches < 20 && !reachedEnd) {
            final dayHistory = await searchDayHistory(dayOffset, query);
            if (dayHistory.entries.isNotEmpty) {
                days.add(dayHistory);
                totalMatches += dayHistory.entries.length;
            }

            if (dayHistory.isEndOfHistory) {
                reachedEnd = true;
            }
            dayOffset++;
        }

        return HistorySearch(
            days: days, 
            nextDayOffset: dayOffset, 
            hasReachedEnd: reachedEnd
        );
    }

    static Future<bool> delete(Duration? duration) async {
        try {
            _initDB();

            if (duration == null) {
                _db!.execute("DELETE FROM history");
            } else {
                final cutoffTime = DateTime.now().subtract(duration).millisecondsSinceEpoch;
                _db!.execute("DELETE FROM history WHERE timestamp >= ?", [cutoffTime]);
            }

            _history.clear();
            return true;
        } catch (e, stackTrace) {
            Nokulog.e("An error occurred whilst clearing the history.", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    static Future<bool> deleteEntry(HistoryData entry) async {
        try {
            _initDB();
            final int type = entry.type.index;
            final String dataJson = jsonEncode(entry.data);
            final String? thumb = entry.thumb;
            final int timestamp = entry.timestamp.millisecondsSinceEpoch;
            
            if (thumb == null) {
                _db!.execute(
                    'DELETE FROM history WHERE type = ? AND data = ? AND title = ? AND thumb IS NULL AND timestamp = ?',
                    [type, dataJson, entry.title, timestamp],
                );
            } else {
                _db!.execute(
                    'DELETE FROM history WHERE type = ? AND data = ? AND title = ? AND thumb = ? AND timestamp = ?',
                    [type, dataJson, entry.title, thumb, timestamp],
                );
            }
            return true;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to delete history entry.", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    static void dispose() {
        _db?.dispose();
        _db = null;
    }

    static void _initDB() {
        if (_db != null) return;

        final dbPath = "${Settings.documentDirectory}/history.db";

        _db = sqlite3.open(dbPath);
        _db!.execute("""
            CREATE TABLE IF NOT EXISTS history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type INTEGER NOT NULL,
                data TEXT NOT NULL,
                title TEXT NOT NULL,
                thumb TEXT,
                headers TEXT,
                timestamp INTEGER NOT NULL
            );
        """);
    }

    static List<HistoryData> get history => List.unmodifiable(_history);
}
