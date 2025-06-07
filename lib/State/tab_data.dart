import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:nokubooru/State/history.dart';
import 'package:nokubooru/State/searcher.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tab_manager.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/utils.dart';

class TabData {
    static int maxCacheViews = 2;

    final TabManager manager;
    
    final StreamController<void> _updateStream = StreamController.broadcast();
    final List<ViewData> _dataStack = <ViewData>[];
    final HashSet<int> _subscriberKeys = HashSet();
    final TextEditingController searchBarInput = TextEditingController();
    final ValueNotifier<bool> lockForFuture = ValueNotifier(false); 

    Uint8List? _thumb;
    Future<ViewData>? _viewFuture;

    Uint8List? get thumb => _thumb;
    set thumb(Uint8List? value) {
        if (value != null) {
            _thumb = value;
            notify();
        }
    
        if (value == null) {
            _lqThumb = value ?? _lqThumb ?? _thumb;
            notify();
            return;
        }

        final command = img.Command()
            ..decodeImage(value)
            ..copyResize(width: 256)
            ..encodeJpg(quality: 90);

        command.executeThread().then((value) {
            _lqThumb = value.outputBytes ?? _lqThumb;
            notify();
        });
    }

    Uint8List? _lqThumb;
    Uint8List? get lqThumb => _lqThumb;

    int _pointer = 0;
    String? _client;

    TabData({required this.manager, ViewData? data, Map<String, dynamic>? restore}) {
        if (restore != null) {
            _restore(restore);
            return;
        }

        push(data ?? ViewSearch(
            searchFuture: Searcher.searchPosts(Searcher.defaultQuery),
            query: Searcher.defaultQuery,
            client: Searcher.defaultClient
        ));

        if (Settings.showURL.value) {
            searchBarInput.text = history.last.url;
            return;
        }

        try {
            searchBarInput.text = (history.lastWhere((element) => element.type == ViewType.search) as ViewSearch).query;
        } catch (_) {
            searchBarInput.text = "";
        }
    }

    factory TabData.fromMap({required TabManager manager, required Map<String, dynamic> data, required bool isActive}) {
        data["is_active"] = isActive;
        
        return TabData(manager: manager, restore: data);
    }

    Future<void> reload() async {
        current.reload();
        _updateStream.add(null);
    }

    Future<void> update() async {

    }

    void handleURL(Uri url) {
        lockForFuture.value = true;
        notify();

        final future = ViewData.fromURL(url: url, tab: this);
        
        future.onError((e, stackTrace) {
            Nokulog.e(e, stackTrace: stackTrace);
            return ViewError(errorCode: 500);
        });

        future.then((value) {
            push(value);
            lockForFuture.value = false;
        });
    }

    void search(String query, {String optionalTags = "", String blacklist = ""}) {
        if (query.isNotEmpty) {
            final pieces = splitAdvancedQuery(query);

            optionalTags = pieces.where((element) => element.startsWith("~")).join(" ").replaceAll("~", "").trim();
            blacklist = pieces.where((element) => element.startsWith("-")).join(" ").replaceAll("-", "").trim();
            query = pieces.whereNot((element) => element.startsWith("~") || element.startsWith("-")).join(" ").trim();
        }

        push(
            ViewSearch(
                searchFuture: Searcher.searchPostsActive(
                    query,
                    optionalTags: optionalTags,
                    blacklist: blacklist,
                    client: client
                ), 
                query: query,
                optionalTags: optionalTags,
                blacklist: blacklist,
                client: client
            )
        );
    }

    void push(ViewData data) {
        data.parent(this);

        Nokulog.d("Pointer: $_pointer | DataStack: ${_dataStack.length}");

        if (_pointer <= _dataStack.length) {
            try {
                final int numToPop = _dataStack.length - _pointer;

                for (int i = 0; i < numToPop; i++) {
                    _dataStack.removeLast();
                }
            } catch(e, stackTrace) {
                Nokulog.e(formatStack(), error: e, stackTrace: stackTrace);
            }
        }

        _dataStack.add(data);

        History.add(data);

        _pointer++;

        printStack();

        current.onActive();

        // Unload data from previous view data except for the last two.
        if (_pointer > maxCacheViews) {
            for (var i = 0; i < _pointer - maxCacheViews; i++) {
                //Nokulog.d("Unloading element ${_dataStack.elementAt(i).title}");
                _dataStack.elementAt(i).unload();
            }
        }

        if (Settings.showURL.value) {
            searchBarInput.text = data.url;
        }

        notify();
    }

    void backtrack() {
        if (!canBacktrack) return;

        _pointer--;

        printStack();

        current.onActive();

        if (Settings.showURL.value) {
            searchBarInput.text = current.url;
        }

        notify();
    }

    String formatStack() {
        int i = 0;

        final List<String> stackStrings = _dataStack.map((element) {
            String separator = (element == current) ? ">>>>" : "    ";
            final String index = i.toString().padLeft(4, '0');

            separator = (i++ == _pointer) ? "****" : separator;

            return "$separator [$index] ${element.title}";
        }).toList();
    
        return stackStrings.join("\n");
    }

    void printStack() {
        Nokulog.i(formatStack());
    }

    void advance() {
        if (!canAdvance) return;

        _pointer++;

        if (Settings.showURL.value) {
            searchBarInput.text = current.url;
        }

        notify();
    }

    void replace(ViewData target, ViewData replacement) {
        final index = _dataStack.indexOf(target);

        _dataStack.removeAt(index);
        if (index >= _dataStack.length) {
            push(replacement);
            return;
        } else {
            _dataStack.insert(index, replacement);
        }

        if (Settings.showURL.value) {
            searchBarInput.text = current.url;
        }

        notify();
    }

    void notify() {
        _updateStream.sink.add(null);
        manager.notify();
    }

    void onUpdate(VoidCallback onData, {int? key}) {
        if (key != null) {
            if (_subscriberKeys.contains(key)) {
                //Nokulog.w("Subscriber that already subscribed trying to subscribe again.");
                return;
            }

            _subscriberKeys.add(key);
        }

        _updateStream.stream.listen((_) => onData());
    }

    Uint8List? _decodeThumb(String? data) {
        if (data == null) {
            return null;
        }

        final decodedData = base64Decode(data);
        return Uint8List.fromList(codec.decode(decodedData));
    }

    void _restore(Map<String, dynamic> data) {
        _pointer = data["pointer"] as int;
        searchBarInput.text = data["searchBar"] as String? ?? "";
        _client = data["client"];
        _thumb = _decodeThumb(data["thumb"]);
        _lqThumb = _thumb;

        final isActive = data["is_active"] as bool;
        
        final List<dynamic> stackList = data["dataStack"];

        for (final viewRecord in stackList.indexed) {
            final viewIndex = viewRecord.$1;
            final viewMap = viewRecord.$2;

            final ViewType type = ViewType.values[viewMap["type"] as int];
            final Map<String, dynamic> data = Map<String, dynamic>.from(viewMap["data"]);

            final isCurrentTab = (viewIndex == (_pointer - 1) && isActive);

            final ViewData viewData = ViewData.fromMap(type: type, data: data, unload: !isCurrentTab);

            viewData.parent(this);
            _dataStack.add(viewData);
        }
    }

    Stream get stream => _updateStream.stream;
    ViewData get current => _dataStack.elementAt(_pointer - 1);
    List<ViewData> get history => List.unmodifiable(_dataStack);
    bool get canBacktrack => _pointer > 1;
    bool get canAdvance => (_pointer < _dataStack.length);
    int get pointer => _pointer;
    
    String? get client => _client;
    set client(String? value) {
        _client = value;
        notify();
    }
}