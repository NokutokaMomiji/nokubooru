
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tags.dart';
import 'package:nokubooru/Widgets/clearance_cookie.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';

const String cfClearance = "vGre2JjF1.vknl7fr9pOi4YGGBgbhj0pEhZRmC1Weyw-1739127735-1.2.1.1-.jp1PnmsS7Hoj6P4ey_Iwh_c_tiJB9ROKxRQedbD3Db5gngas4TrAXuwvqgFUDogYCEwMdBFxBabjsxDefZkkqEfeh8.fNCxcjUcqW.BBc0erQs9zDoy.udnNGg2jETn6980T0ZVDYXsFR5KF6jCuqg6ibU0K.YElBkuttBHakhdorouG0apd5Bn_oB4aUVRp50MFoaxrrNw.61B_zOdjecyDPfcfBiwFmwV0vr2CfLRvo5_VGF7P6pOcFHfP.X9y43SrBj6N4BijcHM8LCCWQCSlkHZiy6ZHrJ4PUjtSS_3174f382osOALMxUv8tsTKUOAZk3M2mn5mOCg4Q91Xw";
const String csrfToken = "iG4WKMGYqhxLIwDOCLupqihZS2RCxFGU";
const String sessionAffinity = "1739110360.015.31.896907|2968378f2272707dac237fc5e1f12aaf";

/// Wrapper around the Nokufind [Finder].
class Searcher {
    static String defaultQuery = "";
    static String? defaultClient;

    static final Finder _finder = Finder()
                    ..addDefault()
                    ..addSubfinder("hypnohub", HypnohubFinder())
                    ..addSubfinder("nhentai", NHentaiFinder(cfClearance, csrfToken, sessionAffinity))
                    ..addSubfinder("hitomi", HitomiFinder(
                        preferWebp: true
                    ))
                    ..addSubfinder("nozomi", NozomiFinder())
                    ..addSubfinder("safebooru", SafebooruFinder());

    static Future<List<Post>> searchPosts(String mainTags, {String optionalTags = "", String blacklist = "", int page = 0, int? limit, String? client}) async {
        if (mainTags.isInteger) return getPost(mainTags.toInt, client: client);

        final results = await (_finder.searchPostsAdvanced(
            mainTags,
            optionalTags: optionalTags,
            blacklist: blacklist, 
            limit: limit ?? Settings.limit.value, 
            client: client, 
            page: page
            )..then(
                (posts) => Tags.add(posts.fold<List<Tag>>(<Tag>[], (list, post) => list..addAll(post.tags)))
            )
        );

        results.sort((element, other) => _finder.clientNames.indexOf(element.source) - _finder.clientNames.indexOf(other.source));

        return results;
    }

    static Future<List<Post>> searchPostsActive(String mainTags, {String optionalTags = "", String blacklist = "", int page = 0, String? client}) async {
        if (mainTags.startsWith("nokubooru:")) {
            throw ArgumentError.value(mainTags, "mainTags", "Tried searching a Nokubooru URL.");
        }
        
        Tags.addSearchQuery((splitRespectingQuotes(mainTags) + splitRespectingQuotes(optionalTags)).join(" "));

        return searchPosts(
            mainTags,
            optionalTags: optionalTags,
            blacklist: blacklist,
            page: page,
            client: client
        );
    }

    static Future<List<Post>> getPost(int postID, {String? client}) async {
        if (client == null) {
            final results = await Future.wait([for (final current in _finder.enabledClients) _finder.getPost(postID, client: current)]);
            return results.whereType<Post>().toList();
        }

        final result = await _finder.getPost(postID, client: client);

        return (result != null) ? [result] : [];
    }

    static Future<List<Comment>> postGetComments(Post post) => _finder.searchComments(
            client: post.source,
            postID: post.postID
        );

    static Future<Description?> postGetDescription(Post post) => _finder.getDescription(post.postID, client: post.source);

    static Future<Post?> postGetParent(Post post) => _finder.postGetParent(post, client: post.source);

    static Future<List<Post>> postGetChildren(Post post) => _finder.postGetChildren(post, client: post.source);

    static Future<List<Note>> postGetNotes(Post post) async => _finder.getNotes(post.postID, client: post.source);

    static bool isActiveSubfinder(String client) {
        try {
            return _finder.subfinderIsEnabled(client);
        } on NoSuchSubfinderException {
            return false;
        } catch (e, stackTrace) {
            Nokulog.e("An unexpected error ocurred when asking the finder if subfinder \"$client\" is enabled.", error: e, stackTrace: stackTrace);
            return false;
        }
    }

    static void configureNHentaiClearance(ClearanceCookie cookies) {
        if (!cookies.allMatched) {
            Nokulog.e("ClearanceCookie has not matched all cookies. $cookies");
            return;
        }

        final subfinder = _finder.getSubfinder("nhentai")!;
        subfinder.configuration.setConfig("csrfToken", cookies.csrfToken);
        subfinder.configuration.setConfig("sessionAffinity", cookies.sessionAffinity);
        subfinder.configuration.setConfig("cfClearance", cookies.cfClearance);
    }

    static List<String> get enabledSubfinders => _finder.enabledClients;
    static List<String> get subfinders => _finder.clientNames;
}
