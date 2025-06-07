import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/utils.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sqlite3/sqlite3.dart';

/// Class that manages all open tabs, persists them in SQLite, and handles active tab changes.
/// 
/// It is responsible for creating, deleting, duplicating, and reordering tabs, as well as restoring
/// them on startup.
class TabManager {
    final List<TabData> _tabs = [];
    final StreamController<void> _controller = StreamController.broadcast();
    final Map<TabData, int> _dbIds = {};
    final ScreenshotController screenshotController = ScreenshotController();
    final ValueNotifier<bool> showThumb = ValueNotifier<bool>(false);

    Database? _db;

    int _activeIndex = 0;
    bool _initialized = false;

    TabManager();

    /// Initializes the database, restores tabs, and ensures at least one tab exists.
    void init() {
        if (_initialized) return;

        _initDB();
        _restoreTabs();

        if (_tabs.isEmpty) {
            final data = createNew();
            setTabAsActive(data);
        }

        _initialized = true;
    }

    /// Creates a new TabData, inserts it into our list and the database,
    /// optionally notifying listeners and inserting after a specified tab.
    /// 
    /// If you want the UI to immediately reflect this new tab, set notify to true.
    TabData createNew({ViewData? view, bool notify = false, TabData? after}) {
        final newTab = TabData(
            manager: this,
            data: view
        );

        if (after != null && _tabs.contains(after)) {
            final index = _tabs.indexOf(after);
            _tabs.insert(index + 1, newTab);
        } else {
            _tabs.add(newTab);
        }

        _insertTab(newTab);

        if (notify) {
            _updateManager();
        }
    
        return newTab;
    }

    /// Removes a TabData, deletes it from the database, reorders remaining tabs,
    /// and ensures there’s always an active tab selected.
    /// 
    /// If you remove the active tab, the next available tab becomes active.
    void removeTab(TabData data) {
        final isActive = (data == active);
        final activeTab = active;
        var position = _tabs.indexed.firstWhere((element) => element.$2.hashCode == data.hashCode).$1;

        _tabs.removeAt(position);
        _deleteTab(data);
        _updatePositions();

        if (!isActive) {
            setTabAsActive(activeTab);
            return;
        }

        if (_tabs.isEmpty) {
            final tab = createNew();
            setTabAsActive(tab);
            return;
        }

        if (position >= _tabs.length) {
            position = _tabs.length - 1;
        }

        setTabAsActive(_tabs[position]);
        _updateManager();
    }

    /// Duplicates the given tab’s current ViewData and inserts it right after the original,
    /// notifying listeners so the UI can update immediately.
    TabData duplicateTab(TabData data, {TabManager? manager}) {
        final lastView = data.current;

        final duplicateView = ViewData.fromMap(
            type: lastView.type,
            data: lastView.export(),
            unload: false
        );

        return createNew(
            view: duplicateView,
            notify: true,
            after: data
        );
    }

    /// Marks the given tab as active and notifies it.
    void setTabAsActive(TabData data) {
        if (data.hashCode == _activeIndex) return;

        _activeIndex = _tabs.indexOf(data);
        data.current.onActive();

        for (final tab in _tabs) {
            _updateTab(tab);
        }

        _updateManager();
    }

    /// Moves a tab from oldIndex to newIndex in the list, adjusts active index if needed,
    /// and rewrites positions in SQLite.
    /// 
    /// If the tab being moved is currently active, after moving it still remains active.
    void swapTabs(int oldIndex, int newIndex) {
        final isActive = isActiveTab(_tabs.elementAt(oldIndex));

        Nokulog.i("IS ACTIVE!");

        final element = _tabs.removeAt(oldIndex);

        if (newIndex >= _tabs.length) {
            _tabs.add(element);
        } else if (newIndex < 0) {
            _tabs.insert(0, element);
        } else {
            _tabs.insert(newIndex, element);
        }

        if (isActive) {
            // We keep the moved tab as active.
            _activeIndex = newIndex.clamp(0, _tabs.length - 1);
        }

        _updatePositions();
        //_updateManager();
    }

    /// Returns true if the given tab matches the current active tab.
    bool isActiveTab(TabData data) {
        if (_tabs.isEmpty) return false;

        return data.hashCode == active.hashCode;
    }

    /// Register a callback that fires whenever any tab-related change occurs.
    /// 
    /// That callback gets called with a null payload, but you know something changed.
    void onActiveChange(void Function(void) onData) {
        ///TODO: Make sure that the onData signature doesn't force the usage of a dummy variable.
        _controller.stream.listen(onData);
    }

    /// Triggers an explicit update to all tabs and notifies listeners.
    void notify() {
        _updateManager();
    }

    /// Updates each tab in SQLite then pushes a change event to listeners.
    void _updateManager() {
        _tabs.forEach(_updateTab);

        _controller.sink.add(null);
    }

    /// Initializes the SQLite database.
    void _initDB() {
        if (_db != null) return;
        
        final dbPath = "${Settings.documentDirectory}/tabs01.db";
        
        _db = sqlite3.open(dbPath);
        
        _db!.execute('''
            CREATE TABLE IF NOT EXISTS tabs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                position INTEGER NOT NULL,
                active INTEGER NOT NULL,
                data TEXT NOT NULL
            );
        ''');
    }

    /// Disposes of the database connection.
    void dispose() {
        _db?.dispose();
        _db = null;
    }

    /// Converts a TabData’s thumbnail (low-quality if available or full-quality) 
    /// into a compressed, base64-encoded string for storage.
    /// 
    /// Returns null if there’s no thumbnail to encode.
    String? _encodeThumb(TabData tab) {
        final thumb = tab.lqThumb ?? tab.thumb;

        if (thumb == null) return null;

        final compressedData = codec.encode(thumb);
        return base64Encode(compressedData);
    }

    /// Serializes all relevant TabData fields—history stack, search input, client,
    /// and encoded thumbnail—into a JSON string, compresses it, and base64-encodes.
    /// 
    /// This is so we can store the full tab snapshot in a single TEXT column.
    String _exportTab(TabData tab) {
        // There might be a better way to do this in SQL. But I'm not an SQL expert so...
        final jsonData = jsonEncode({
            "pointer": tab.pointer,
            "dataStack": tab.history.sublist(0, tab.pointer).map((view) => {
                    "type": view.type.index,
                    "data": view.export()
                }).toList(),
            "searchBar": tab.searchBarInput.text,
            "client": tab.client,
            "thumb": _encodeThumb(tab)
        });

        final compressedData = codec.encode(utf8.encode(jsonData));
        return base64Encode(compressedData);
    }

    /// Inserts a new tab into the database.
    void _insertTab(TabData tab) {
        _initDB();
        
        final data = _exportTab(tab);
        final int position = _tabs.indexOf(tab);
        final int activeFlag = (tab == active) ? 1 : 0;
        
        _db!.execute(
            'INSERT INTO tabs (position, active, data) VALUES (?, ?, ?)',
            [position, activeFlag, data],
        );
        
        // Get the last inserted row ID.
        final ResultSet result = _db!.select('SELECT last_insert_rowid() as id');
        if (result.isNotEmpty) {
            _dbIds[tab] = result.first['id'] as int;
        }
    }

    /// Updates the database row for the tab’s position, active state, and data if it exists in the database.
    void _updateTab(TabData tab) {
        _initDB();
        
        if (!_dbIds.containsKey(tab)) return;
        
        final data = _exportTab(tab);
        final int position = _tabs.indexOf(tab);
        final int activeFlag = (tab == active) ? 1 : 0;
        
        _db!.execute(
            'UPDATE tabs SET position = ?, active = ?, data = ? WHERE id = ?',
            [position, activeFlag, data, _dbIds[tab]],
        );
    }

    /// Deletes the given tab from the database.
    void _deleteTab(TabData tab) {
        _initDB();

        if (!_dbIds.containsKey(tab)) return;
        
        _db!.execute(
            'DELETE FROM tabs WHERE id = ?',
            [_dbIds[tab]],
        );
        
        _dbIds.remove(tab);
    }

    /// Rewrites every tab’s `position` in the database to match the current in-memory order.
    void _updatePositions() {
        for (var i = 0; i < _tabs.length; i++) {
            final tab = _tabs[i];
            _db!.execute(
                'UPDATE tabs SET position = ? WHERE id = ?',
                [i, _dbIds[tab]],
            );
        }
    }

    /// Restores the tabs from the SQL database.
    void _restoreTabs() {
        _initDB();
        
        final ResultSet result = _db!.select(
            'SELECT id, position, active, data FROM tabs ORDER BY position ASC',
        );
        
        for (final row in result) {
            final int id = row['id'] as int;
            final String jsonBase64 = row['data'] as String;
            final Uint8List decodedData = base64Decode(jsonBase64);
            final String jsonString = utf8.decode(codec.decode(decodedData));
            final Map<String, dynamic> tabMap = jsonDecode(jsonString);
            final bool isActive = ((row['active'] as int) == 1);
            
            // Re-create the TabData from the map.
            final TabData tab = TabData.fromMap(manager: this, data: tabMap, isActive: isActive);
            
            _tabs.add(tab);
            _dbIds[tab] = id;
            
            // If the "active" column is 1, mark this tab as active.
            if (isActive) {
                _activeIndex = _tabs.length - 1;
            }
        }
    }

    /// Stream that emits whenever tabs change.
    Stream<void> get stream => _controller.stream;

    /// The current tabs tracked by this manager.
    List<TabData> get tabs => _tabs.toList();

    /// Returns the currently active TabData (or first tab if index is out of range).
    TabData get active => (_activeIndex >= _tabs.length) ? _tabs[0] : _tabs[_activeIndex];

    /// Returns the index of the currently active tab.
    int get index => _activeIndex;
}
