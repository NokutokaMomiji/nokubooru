import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nokubooru/State/favorites.dart';
import 'package:nokubooru/State/searcher.dart';
import 'package:nokubooru/State/tags.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';
import 'package:path_provider/path_provider.dart';

/// A generic wrapper for a setting value that automatically registers
/// itself, notifies its listeners when changed, and triggers an auto-save.
class Setting<T> extends ValueNotifier<T> {
    final String key;
    final T defaultValue;

    Setting(this.key, T value) : defaultValue = value, super(value) {
        Settings._register(this);
    }

    @override
    set value(T newValue) {
        super.value = newValue;
        if (!Settings._loading) {
            Settings._onSettingChanged();
        }
    }
}
class Settings {
    static const String _appFolderName = "Nokubooru";

    // Registry for all auto-saved settings.
    static final Map<String, Setting<dynamic>> _registry = {};

    static late final Setting<List<String>> lastSearches;
    static late final Setting<bool> firstTime;
    static late final Setting<int> limit;
    static late final Setting<List<String>> blacklist;
    static late final Setting<int?> legacyColor;
    static late final Setting<String> colorAccent;
    static late final Setting<bool> isColorScheme;
    static late final Setting<bool> brightness;
    static late final Setting<int> filter;
    static late final Setting<String?> defaultClient;
    static late final Setting<Map<String, Map<String, String>>> aliases;
    static late final Setting<bool> autofetch;
    static late final Setting<bool> autocache;
    static late final Setting<String> initialQuery;
    static late final Setting<bool> filterMD5;
    static late final Setting<bool> saveToGallery;
    static late final Setting<bool> autotheme;
    static late final Setting<bool> shouldLimit;
    static late final Setting<bool> warned;
    static late final Setting<bool> lowerQuality;
    static late final Setting<List<String>> finders;
    static late final Setting<bool> bgImageSetting;
    static late final Setting<bool> alwaysShowFavoriteTags;
    static late final Setting<bool> sourceIcon;
    static late final Setting<String> languageCode;
    static late final Setting<List<Map<String, String>>> legacyFavoriteTags;
    static late final Setting<int> defaultPage;
    static late final Setting<bool> showURL;
    static late final Setting<bool> askDownloadDirectory;
    static late final Setting<String> saveDirectory;
    static late final Setting<int> preloadViewerDistance;

    static Directory _documents = Directory.systemTemp;
    static Directory _legacyDocuments = Directory.systemTemp;
    static Uint8List? _backgroundImage;
    static bool _loading = false;
    static bool _failed = false;

    /// Map that stores language strings. It shouldn't be accessed directly, but rather via [languageText]
    static Map<String, String> language = {};

    /// Global notifier that increments each time any setting changes.
    static final ValueNotifier<int> globalNotifier = ValueNotifier<int>(0);

    static Future<bool> init() async {
        await _settingInit();
        
        _documents = await getApplicationSupportDirectory();
        _legacyDocuments = await getApplicationDocumentsDirectory();
        
        await load();

        Themes.accent = decodeColor(colorAccent.value);

        _addNewAliases();

        Nokulog.d("Registry:\n${_registry.keys.join("\n")}");

        language = Map<String, String>.from(jsonDecode(await rootBundle.loadString("assets/Language/lang_${languageCode.value}.json")) as Map);

        final bgFile = File("$documentDirectory/bg");

        if (await bgFile.exists()) {
            _backgroundImage = Uint8List.fromList(codec.decode(await bgFile.readAsBytes()));
        }

        Nokulog.i("language: ${language.keys.length}");

        Nokulog.d("Settings initialized!");

        saveDirectory.value = saveDirectory.defaultValue;

        return true;
    }

    static void _addNewAliases() {
        for (final client in Searcher.subfinders) {
            aliases.value.putIfAbsent(client, () => <String, String>{});
        }
    }


    // For some reason, doing this outside of a method causes some settings to not register themselves.
    // So, everything is wrapped inside this little helper function.
    // (P.S. That "little" was in massive sarcasm quotes.)
    static Future<void> _settingInit() async {
        lastSearches = Setting<List<String>>("last_searches", <String>[]);
        firstTime = Setting<bool>("first_time", true);
        limit = Setting<int>("limit", 50);
        blacklist = Setting<List<String>>("blacklist", <String>[]);
        legacyColor = Setting<int?>("color", null);
        colorAccent = Setting<String>("color_accent", encodeColor(Themes.accent));
        isColorScheme = Setting<bool>("is_color_scheme", false);
        brightness = Setting<bool>("brightness", true);
        filter = Setting<int>("filter", 1 | 2 | 4 | 8 | 16);
        defaultClient = Setting<String?>("default_client", null);
        aliases = Setting<Map<String, Map<String, String>>>("aliases", <String, Map<String, String>>{});
        autofetch = Setting<bool>("autofetch", false);
        autocache = Setting<bool>("autocache", false);
        initialQuery = Setting<String>("initial_query", "");
        filterMD5 = Setting<bool>("filter_md5", true);
        saveToGallery = Setting<bool>("save_to_gallery", false);
        autotheme = Setting<bool>("autotheme", false);
        shouldLimit = Setting<bool>("should_limit", true);
        warned = Setting<bool>("warned", false);
        lowerQuality = Setting<bool>("lower_quality", false);
        finders = Setting<List<String>>("finders", <String>[]);
        bgImageSetting = Setting<bool>("bg_image", false);
        alwaysShowFavoriteTags = Setting<bool>("always_show_favorite_tags", true);
        sourceIcon = Setting<bool>("source_icon", true);
        languageCode = Setting<String>("language_code", "en");
        legacyFavoriteTags = Setting<List<Map<String, String>>>("favorite_tags", <Map<String, String>>[]);
        defaultPage = Setting<int>("default_page", ViewType.home.index);
        showURL = Setting<bool>("show_url", false);
        askDownloadDirectory = Setting<bool>("ask_download_directory", false);
        saveDirectory = Setting<String>("save_directory", await _getDownloadsDirectory());
        preloadViewerDistance = Setting<int>("preload_viewer_distance", 4);
    }

    /// Loads settings from the JSON file.
    /// For each registered setting, if a key exists in the file its value is used.
    /// If the key is not found, the default value is used instead.
    /// Any extra keys in the file are ignored.
    static Future<void> load() async {
        try {
            final file = File("${Settings.documentDirectory}/settings.json");

            if (await file.exists()) {
                final contents = await file.readAsString();
                final Map<String, dynamic> jsonMap = jsonDecode(contents);
                _loading = true;
                
                _registry.forEach((key, setting) {
                    if (jsonMap.containsKey(key)) {
                        Nokulog.d("Loading value for setting $key from json.");
                        
                        final value = jsonMap[key];

                        if (value is! List && value is! Map) {
                            setting.value = jsonMap[key];
                            return;
                        }

                        try {
                            if (value is List) {
                                try {
                                    setting.value = List<String>.from(value);
                                } catch (_) {
                                    setting.value = List<Map<String, String>>.from(value);
                                }
                            } else if (value is Map) {
                                setting.value = <String, Map<String, String>>{for (final entry in value.entries) entry.key.toString(): Map<String, String>.from(entry.value)};
                            }
                        } catch(e, stackTrace) {
                            Nokulog.e("Failed to set value for setting $key.", error: e, stackTrace: stackTrace);
                            return;
                        }

                    } else {
                        Nokulog.d("Key $key not found in json map.");
                        setting.value = setting.defaultValue;
                    }
                });

                _loading = false;
            }

        } catch (e, stackTrace) {
            Nokulog.e("Error loading settings.", error: e, stackTrace: stackTrace);
            _failed = true;
        }
    }

    /// Loads the old config file (config.dat) from the legacy directory,
    /// converts and assigns its values into the new settings, saves the new settings,
    /// and deletes the legacy config file.
    ///
    /// If an error ocurrs, the error object is returned instead. Otherwise, it returns null.
    static Future<Object?> loadLegacyConfig() async {
        // Path to the legacy config file.
        final configFile = File("$legacyDirectory/config.dat");

        // If the file does not exist, nothing to do.
        if (!(await configFile.exists())) {
            return null;
        }

        try {
            final fileData = await configFile.readAsBytes();
            final decodedData = utf8.decode(codec.decode(fileData));
            final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(decodedData));

            for (final entry in data.entries) {
                final key = entry.key;
                final value = entry.value;

                if (key == "aliases") {
                    if (_registry.containsKey("aliases")) {
                        final Map<String, Map<String, String>> aliasMap = {};
                        (value as Map<String, dynamic>).forEach((group, groupData) {
                            aliasMap[group] = Map<String, String>.from(groupData);
                        });
                        aliases.value = aliasMap;
                    }
                    continue;
                }

                // *sigh.* Nokubooru 1.x's settings contained structures such as lists and maps and such.
                // This is such a pain in the ass thanks to Dart's type system. This is pretty bodged together. 
                if (key == "blacklist") {
                    List<String> list;
                    if (value is String) {
                        list = value.split(" ");
                    } else if (value is List) {
                        list = List<String>.from(value);
                    } else {
                        list = <String>[];
                    }
                    if (_registry.containsKey("blacklist")) {
                        blacklist.value = list;
                    }
                    continue;
                }

                if (key == "filter") {
                    int filterValue = value;
                    
                    // The filter is a bitmask so we clamp the value between 0 (0x00000) and 31 (0x11111).
                    filterValue = filterValue.clamp(0, 31).toInt();
                    
                    if (_registry.containsKey("filter")) {
                        filter.value = filterValue;
                    }
                    continue;
                }

                if (key == "last_searches") {
                    if (_registry.containsKey("last_searches")) {
                        lastSearches.value = List<String>.from(value);
                    }
                    continue;
                }

                if (key == "lower_quality") {
                    if (_registry.containsKey("lower_quality")) {
                        lowerQuality.value = value;
                    }
                    continue;
                }

                if (key == "finder") {
                    if (_registry.containsKey("finders")) {
                        finders.value = List<String>.from(value);
                    }
                    continue;
                }

                if (key == "favorite_tags") {
                    if (!_registry.containsKey("favorite_tags") || (value as List).isEmpty) continue;
                    
                    for (final item in value) {
                        final casted = Map<String, String>.from(item);
                        final original = casted["original"]!;
                        final translated = casted["translated"]!;

                        if (Post.specialTags.containsKey(original)) {
                            Tags.addToFavorites(Post.specialTags[original]!);
                            continue;
                        }

                        final tag = Tag(original, translated: translated);
                        Tags.addToFavorites(tag);
                    }

                    continue;
                }

                if (_registry.containsKey(key)) {
                    try {
                        _registry[key]!.value = value;
                    } catch (_) {
                        _registry[key]!.value = List<String>.from(value);
                    }
                }
            }

            _addNewAliases();

            if (lastSearches.value.isNotEmpty) {
                for (final search in lastSearches.value) {
                    Tags.addSearchQuery(search.trim());
                }
                lastSearches.value.clear();
            }

            if (legacyColor.value != null) {
                Themes.accent = Color(legacyColor.value!);
            }

            await save();

            // Scary...
            await configFile.delete();
            Nokulog.d("Legacy config loaded, transformed, and legacy file deleted.");

            return null;
        } catch (e, stackTrace) {
            Nokulog.e("Error loading legacy config.", error: e, stackTrace: stackTrace);
            return e;
        }
    }

    /// Saves all registered settings to the JSON file.
    static Future<void> save() async {
        final file = File("${Settings.documentDirectory}/settings.json");
        final jsonMap = <String, dynamic>{};

        Nokulog.d("Saving settings. Registry:\n${_registry.keys.join("\n")}");

        _registry.forEach((key, setting) {
            jsonMap[key] = setting.value;
        });
        
        await file.writeAsString(jsonEncode(jsonMap));
    }

    /// Whether legacy configuration or favorite files exist.
    static bool legacyFilesExist() {
        final legacyFavorites = File("${Settings.legacyDirectory}/favorites.dat");
        final legacyConfig = File("${Settings.legacyDirectory}/config.dat");

        return legacyConfig.existsSync() || legacyFavorites.existsSync();
    }

    /// Loads compressed favorites from the legacy favorites file.
    static List<Post> loadCompressedFavorites() {
        final File favoritesFile = File("${Settings.legacyDirectory}/favorites.dat");
        final List<int> data = favoritesFile.readAsBytesSync().toList();

        final decoded = codec.decode(data);

        final List<dynamic> content = jsonDecode(const Utf8Codec().decode(decoded));
        final List<Post> results = [];

        for (final item in content) {
            final Post post = Post.importPostFromMap(Map<String, dynamic>.from(item));
            results.add(post);
        }

        return results;
    }

    /// Imports legacy favorites into the new system and deletes the old file.
    static Future<Object?> importLegacyFavorites() async {
        final legacyFilePath = "$legacyDirectory/favorites.dat";
        final legacyFile = File(legacyFilePath);

        if (!legacyFile.existsSync()) {
            return null;
        }

        try {
            final List<Post> legacyPosts = loadCompressedFavorites();
            
            const int chunkSize = 100;
            
            for (int i = 0; i < legacyPosts.length; i += chunkSize) {
                final int end = (i + chunkSize < legacyPosts.length) ? i + chunkSize : legacyPosts.length;
                final List<Post> chunk = legacyPosts.sublist(i, end);
                
                final bool success = await Favorites.addFavoritesBulk(chunk);
                if (!success) {
                    throw Exception("Failed to import favorite posts in chunk starting at index $i");
                }
                
                await Future.delayed(Duration.zero);
            }

            legacyFile.deleteSync();
            Nokulog.i("Legacy favorites imported successfully and legacy file deleted.");
            
            return null;
        } catch (e, stackTrace) {
            Nokulog.e("Failed to import legacy favorites.", error: e, stackTrace: stackTrace);
            return e;
        }
    }

    /// Called by each Setting upon creation to register themselves.
    static void _register(Setting<dynamic> setting) {
        _registry[setting.key] = setting;
    }

    /// Returns the Downloads directory path.
    static Future<String> _getDownloadsDirectory() async {
        Directory? directory;
        
        try {
            directory = await getDownloadsDirectory();
        } catch (e, stackTrace) {
            Nokulog.e("Failed to fetch download directory.", error: e, stackTrace: stackTrace);
        }

        final home = (Platform.isWindows) ? Platform.environment["USERPROFILE"] : Platform.environment["HOME"];
        final downloads = "${home ?? "."}/Downloads";
            
        directory = directory ?? Directory(downloads);

        if (!directory.existsSync()) {
            directory.createSync(recursive: true);
        }

        return directory.path;
    }

    /// Called whenever any setting changes.
    static void _onSettingChanged() {
        globalNotifier.value++;
        save();
    }

    static String get documentDirectory => _documents.path.replaceAll("\\", "/");
    static String get legacyDirectory => "${_legacyDocuments.path.replaceAll("\\", "/")}/$_appFolderName";
    static bool get failed => _failed;
    static Uint8List? get backgroundImage => _backgroundImage;
    static set backgroundImage(Uint8List? value) {
        final previous = _backgroundImage;
        
        _backgroundImage = value;
        
        if (previous != value) {
            bgImageSetting.value = !bgImageSetting.value;

            final bgFile = File("$documentDirectory/bg");

            if (value == null) {
                if (bgFile.existsSync()) {
                    bgFile.delete();
                }
                return;
            }

            bgFile.writeAsBytes(codec.encode(value));
        }
    }
}
