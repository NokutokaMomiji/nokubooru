import 'package:nokubooru/State/download_manager.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/utils.dart';
import 'package:sqlite3/sqlite3.dart';

/// Stores the [DownloadRecord] entries of a give [day].
class DayDownloads {
    final DateTime day;
    final List<DownloadRecord> entries;
    final bool isEndOfHistory;

    DayDownloads({
        required this.day,
        required this.entries,
        required this.isEndOfHistory,
    });
}

class DownloadSearch {
    final List<DayDownloads> days;
    final int nextDayOffset;
    final bool hasReachedEnd;

    DownloadSearch({
        required this.days,
        required this.nextDayOffset,
        required this.hasReachedEnd,
    });
}

/// Static class that handles an SQLite database that keeps track of records of downloads.
class Downloads {
    static final List<DownloadRecord> _downloads = [];
    static Database? _db;

    /// Initializes the database and table.
    static void _initDB() {
        if (_db != null) return;

        final dbPath = "${Settings.documentDirectory}/downloads.db";

        _db = sqlite3.open(dbPath);

        _db!.execute('''
            CREATE TABLE IF NOT EXISTS downloads (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                path TEXT,
                file_count INTEGER NOT NULL,
                timestamp INTEGER NOT NULL
            );
        ''');
    }

    // Technically not necessary since all functions will try to initialize the database if it hasn't yet.
    // But for peace of mind, I prefer to explicitly initialize it on main.
    static Future<void> init() async {
        _initDB();
    }

    /// Saves the data of a download record.
    static Future<bool> save(DownloadRecord entry) async {
        try {
            _initDB();

            final timeStamp = entry.timestamp.millisecondsSinceEpoch;
            
            _db!.execute(
                'INSERT INTO downloads (title, path, file_count, timestamp) VALUES (?, ?, ?, ?)',
                [entry.title, entry.path, entry.files.length, timeStamp]
            );
            
            _downloads.add(entry);
            return true;
        } catch (e, stackTrace) {
            Nokulog.e('Failed to save download record.', error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Loads the entries for a specific day offset.
    static Future<DayDownloads> loadDayDownloads(int dayOffset) async {
        try {
            _initDB();

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final target = today.subtract(Duration(days: dayOffset));
            final start = target.millisecondsSinceEpoch;
            final end = target.add(const Duration(days: 1)).millisecondsSinceEpoch;

            final resultSet = _db!.select(
                'SELECT title, path, file_count, timestamp FROM downloads WHERE timestamp >= ? AND timestamp < ? ORDER BY timestamp DESC',
                [start, end]
            );

            final entries = resultSet.map((row) => DownloadRecord(
                title: row['title'] as String,
                path: row['path'] as String?,
                files: [],
                fileCount: row['file_count'] as int,
                timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
            )).toList();

            var isEnd = false;
            final minResultSet = _db!.select('SELECT MIN(timestamp) AS min_ts FROM downloads');

            if (minResultSet.isNotEmpty && minResultSet.first['min_ts'] != null) {
                final minTimestamp = minResultSet.first['min_ts'] as int;
                final earliest = DateTime.fromMillisecondsSinceEpoch(minTimestamp);
                final earliestDay = DateTime(earliest.year, earliest.month, earliest.day);

                if (target.isBefore(earliestDay)) isEnd = true;
            } else {
                isEnd = true;
            }

            return DayDownloads(
                day: target, 
                entries: entries, 
                isEndOfHistory: isEnd
            );
        } catch (e, stackTrace) {
            Nokulog.e('Failed to load day downloads offset $dayOffset.', error: e, stackTrace: stackTrace);
            
            return DayDownloads(
                day: DateTime.now(), 
                entries: [], 
                isEndOfHistory: false
            );
        }
    }

    /// Searches for entries by title within a day offset.
    static Future<DayDownloads> searchDayDownloads(int dayOffset, String query) async {
        final dayData = await loadDayDownloads(dayOffset);
        final filtered = dayData.entries.where((element) => fuzzyMatch(element.title, query)).toList();

        return DayDownloads(
            day: dayData.day,
            entries: filtered,
            isEndOfHistory: dayData.isEndOfHistory,
        );
    }

    /// General search across days.
    static Future<DownloadSearch> search(String query, {int startingDayOffset = 0}) async {
        final days = <DayDownloads>[];

        var offset = startingDayOffset;
        var total = 0;
        var ended = false;
        
        while (total < 20 && !ended) {
            final day = await searchDayDownloads(offset, query);

            if (day.entries.isNotEmpty) {
                days.add(day);
                total += day.entries.length;
            }
            
            if (day.isEndOfHistory) ended = true;
            offset++;
        }
        return DownloadSearch(days: days, nextDayOffset: offset, hasReachedEnd: ended);
    }

    /// Delete records older than [duration]. If duration is null, all records are deleted.
    static Future<bool> delete(Duration? duration) async {
        try {
            _initDB();

            if (duration == null) {
                _db!.execute('DELETE FROM downloads');
                _downloads.clear();
                
                return true;
            }
            
            final cutoff = DateTime.now().subtract(duration).millisecondsSinceEpoch;

            _db!.execute('DELETE FROM downloads WHERE timestamp < ?', [cutoff]);
            _downloads.removeWhere((element) => element.timestamp.millisecondsSinceEpoch < cutoff);

            return true;
        } catch (e, stackTrace) {
            Nokulog.e('Failed to delete downloads.', error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Delete a single entry matching all fields
    static Future<bool> deleteEntry(DownloadRecord entry) async {
        try {
            _initDB();

            final timeStamp = entry.timestamp.millisecondsSinceEpoch;
            
            _db!.execute(
                'DELETE FROM downloads WHERE title = ? AND path IS ? AND file_count = ? AND timestamp = ?',
                [entry.title, entry.path, entry.fileCount, timeStamp]
            );
            
            _downloads.removeWhere((element) =>
                element.title == entry.title &&
                element.path == entry.path &&
                element.fileCount == entry.fileCount &&
                element.timestamp == entry.timestamp
            );
            return true;
        } catch (e, stackTrace) {
            Nokulog.e('Failed to delete download entry.', error: e, stackTrace: stackTrace);
            return false;
        }
    }

    /// Disposes of the database.
    static void dispose() {
        _db?.dispose();
        _db = null;
    }
}
