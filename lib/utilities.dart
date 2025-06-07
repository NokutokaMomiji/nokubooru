import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';

import 'package:flutter/widgets.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tags.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokufind/nokufind.dart';

Random random = Random();

T? firstWhereOrNull<T>(List<T> items, bool Function(T element) condition) {
    if (items.isEmpty) return null;

    for (final item in items) {
        if (condition(item)) return item;
    }

    return null;
}

T? randomWhereOrNull<T>(List<T> items, bool Function(T element) condition) {
    if (items.isEmpty) return null;

    final List<T> current = [];

    for (final item in items) {
        if (condition(item)) {
            current.add(item);
        }
    }

    if (current.isEmpty) return null;

    return current.elementAtOrNull(random.nextInt(current.length));
}

T getRandom<T>(List<T> items) => items[random.nextInt(items.length)];

extension StringTitle on String {
    String toTitle() {
        if (isEmpty) return this;

        bool previousIsCased = false;
        final buffer = StringBuffer();

        for (final char in split('')) {
            final bool isCased = char.toLowerCase() != char.toUpperCase();

            if (!previousIsCased && isCased) {
                buffer.write(char.toUpperCase());
            } else if (previousIsCased && isCased) {
                buffer.write(char.toLowerCase());
            } else {
                buffer.write(char);
            }

            previousIsCased = isCased;
        }

        return buffer.toString();
    }

    String capitalize() => substring(0, 1).toUpperCase() + substring(1);
}

extension InsertString on String {
    String insert(int index, String string) => replaceRange(index, index, string);
}

extension GlobalPaintBounds on BuildContext {
    Rect? get globalPaintBounds {
        final renderObject = findRenderObject();
        final translation = renderObject?.getTransformTo(null).getTranslation();

        if (translation != null && renderObject?.paintBounds != null) {
            final offset = Offset(translation.x, translation.y);
            return renderObject!.paintBounds.shift(offset);
        } else {
            return null;
        }
    }
}

Color getTextColor(Color color) {
    final red = (color.r * 255).round();
    final green = (color.g * 255).round();
    final blue = (color.b * 255).round(); 

    final double luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255;

    if (luminance > 0.5) {
        return Themes.black;
    }

    return Themes.white;
}

int boolToInt(bool value) => (value) ? 1 : 0;

int compareTags(Tag a, Tag b) {
    const Map<TagType, int> typePriority = {
        TagType.artist: 0,
        TagType.series: 1,
        TagType.character: 2,
        TagType.general: 3,
    };

    // First check if the tag is an artist tag using the legacy HashMap.
    //var aIsArtist = Tags.artists.contains(a.original);
    //var bIsArtist = Tags.artists.contains(b.original);

    //if (aIsArtist || bIsArtist) {
    //    return (boolToInt(bIsArtist) - boolToInt(aIsArtist)) * 3;
    //}

    final aIsFavorite = Tags.isFavorite(a);
    final bIsFavorite = Tags.isFavorite(b);

    if (aIsFavorite || bIsFavorite) {
        return (boolToInt(bIsFavorite) - boolToInt(aIsFavorite)) * 3;
    }

    // Do tag type comparison.
    final int typeComparison = typePriority[a.type]!.compareTo(typePriority[b.type]!);

    if (typeComparison != 0) {
        return typeComparison;
    }

    // Compare alphabetically.
    return a.original.compareTo(b.original);
}

extension StringNumeric on String {
    bool get isNumeric => (double.tryParse(this) != null);
    bool get isInteger => (double.tryParse(this) != null);
    int get toInt => int.parse(this);
}

extension IsDay on DateTime {
    bool isSameDay(DateTime other) => (other.year == year && other.month == month && other.day == day);

    bool get isToday => isSameDay(DateTime.now());

    bool get isYesterday => isSameDay(DateTime.now().subtract(const Duration(days: 1)));
}

bool fuzzyMatch(String title, String query, [double threshold = 0.6]) {
    final lowerTitle = title.toLowerCase();
    final lowerQuery = query.toLowerCase();

    if (lowerTitle.contains(lowerQuery)) return true;
    
    final similarityValue = similarity(lowerTitle, lowerQuery);
    
    return similarityValue >= threshold;
}

double similarity(String s, String t) {
    final int distance = levenshtein(s, t);
    final int maxLen = s.length > t.length ? s.length : t.length;

    if (maxLen == 0) return 1.0;
    
    return (maxLen - distance) / maxLen;
}

int levenshtein(String s, String t) {
    final int m = s.length;
    final int n = t.length;
    final List<List<int>> dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
        dp[i][0] = i;
    }

    for (int j = 0; j <= n; j++) {
        dp[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
        for (int j = 1; j <= n; j++) {
            final int cost = s[i - 1] == t[j - 1] ? 0 : 1;

            dp[i][j] = [
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1,
                dp[i - 1][j - 1] + cost,
            ].reduce((a, b) => a < b ? a : b);
        }
    }

    return dp[m][n];
}

double bestSimilarity(Tag tag, String query) => [
        similarity(tag.original, query),
        similarity(tag.translated, query)
    ].reduce((a, b) => a > b ? a : b);

List<String> splitRespectingQuotes(String input, {bool keepQuotes = false}) {
    final List<String> result = [];
    final RegExp regex = RegExp(r'"([^"]+)"|(\S+)'); // Match quoted text or words

    for (final match in regex.allMatches(input)) {
        final quoted = match.group(1);
        final unquoted = match.group(2);

        if (quoted != null) {
            result.add(keepQuotes ? '"$quoted"' : quoted);
        } else if (unquoted != null) {
            result.add(unquoted);
        }
    }

    return result;
}

List<String> splitAdvancedQuery(String query) {
    query = query.trim();
    
    final result = <String>[];
    
    bool inQuotes = false;
    String buffer = "";

    for (int i = 0; i < query.length; i++) {
        final char = query[i];

        if (char == " " && !inQuotes) {
            result.add(buffer);
            buffer = "";
            continue;
        }

        if (char == "\"") {
            inQuotes = !inQuotes;
        }

        buffer += char;
    }

    if (buffer.isNotEmpty) {
        result.add(buffer);
    }

    return result;
}

String getWordAtIndex(String input, int index) {
    if (index < 0 || index >= input.length || input.trim().isEmpty) {
        return "";  
    }

    if (index == 0) {
        index = 1;
    }

    final RegExp regex = RegExp(r'"([^"]+)"|(\S+)'); // Matches quoted phrases or words

    for (final RegExpMatch match in regex.allMatches(input)) {
        final int start = match.start;
        final int end = match.end;

        if (index >= start && index < end) {
            return match.group(1) ?? match.group(2) ?? "";
        }
    }

    return "";
}

String replaceWordAtIndex(String input, String replacement, int index) {
    // Get the word or space at the given index using getWordAtIndex
    final String wordToReplace = getWordAtIndex(input, index);
    
    if (wordToReplace.isEmpty) {
        return input.insert((index + 1).clamp(0, input.length), "$replacement "); // Return the original string if no word or space is found at the given index
    }

    // Handle special case for spaces (if the word to replace is a space)
    if (wordToReplace == " ") {
        // We need to replace the exact space at the given index
        return input.substring(0, index) + replacement + input.substring(index + 1);
    }

    // Find the start and end position of the word/space to replace using the same regular expression logic
    final RegExp regex = RegExp(r'"([^"]+)"|(\S+)|\s'); // Match quoted phrases, non-whitespace words, and spaces
    int start = -1;
    int end = -1;
    
    // Iterate over the matches to find the exact word or space at the given index
    for (final RegExpMatch match in regex.allMatches(input)) {
        if (index >= match.start && index < match.end) {
            start = match.start;
            end = match.end;
            break;
        }
    }

    // If the word/space is found, replace it with the replacement
    if (start != -1 && end != -1) {
        final String beforeWord = input.substring(0, start);
        final String afterWord = input.substring(end);

        if (afterWord.isEmpty) {
            replacement = "$replacement ";
        }
        
        return beforeWord + replacement + afterWord;
    }
    
    // If no word or space is found to replace, return the original string
    return input;
}

String languageText(String key, [List<dynamic>? replacements]) {
    final languageMap = Settings.language;

    if (!languageMap.containsKey(key)) {
        return key;
    }

    var text = languageMap[key]!;

    if (replacements == null || replacements.isEmpty) {
        return text;
    }

    for (final replacement in replacements) {
        text = text.replaceFirst("%s", replacement.toString());
    }

    return text;
}

String encodeColor(Color color) => "${color.a};${color.r};${color.g};${color.b}";

Color decodeColor(String color) {
    final List<double> components = color.split(";").map((element) => double.parse(element)).toList();

    return Color.from(alpha: components[0], red: components[1], green: components[2], blue: components[3]);
}

bool hasCommonElement(List<String> list1, List<String> list2) {
    final set1 = list1.toSet();

    return list2.any(set1.contains);
}

bool isMatrixNearlyIdentity(Matrix4 matrix, {double tolerance = 1e-5}) {
    final List<double> m = matrix.storage;
    final List<double> identity = Matrix4.identity().storage;

    for (int i = 0; i < m.length; i++) {
        if ((m[i] - identity[i]).abs() > tolerance) return false;
    }
    
    return true;
}


final GZipCodec codec = GZipCodec(level: ZLibOption.maxLevel);
final AlignmentGeometry imageAlignment = Alignment.topCenter.add(const Alignment(0, 0.5));

bool Function(List?, List?) eq = const ListEquality().equals;

bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

String stripExtension(String filename) => filename.substring(0, filename.lastIndexOf("."));

String? generateOriginalURL(Post post) {
    switch(post.source) {
        case "danbooru":   return "https://danbooru.donmai.us/posts/${post.postID}";
        case "rule34":     return "https://rule34.xxx/index.php?page=post&s=view&id=${post.postID}";
        case "hypnohub":   return "https://hypnohub.net/index.php?page=post&s=view&id=${post.postID}";
        case "safebooru":  return "https://safebooru.org/index.php?page=post&s=view&id=${post.postID}";
        case "konachan":   return "https://konachan.com/post/show/${post.postID}";
        case "yande.re":   return "https://yande.re/post/show/${post.postID}";
        case "gelbooru":   return "https://gelbooru.com/index.php?page=post&s=view&id=${post.postID}";
        case "nozomi":     return "https://nozomi.la/post/${post.postID}.html";
        case "pixiv":      return "https://www.pixiv.net/en/artworks/${post.postID}";
        case "nhentai": 
        default:
            return post.sources.firstOrNull;
    }
}