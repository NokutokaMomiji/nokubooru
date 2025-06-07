
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nokubooru/Pages/post_page.dart';
import 'package:nokubooru/State/download_manager.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/custom_container.dart';
import 'package:nokubooru/Widgets/General/faded_divider.dart';
import 'package:nokubooru/Widgets/General/option_widgets.dart';
import 'package:nokubooru/Widgets/General/post_card.dart';
import 'package:nokubooru/Widgets/General/rounded_box_button.dart';
import 'package:nokubooru/Widgets/Post/post_media.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';

typedef _TagSectionEntry = ({String? header, String? tag});

List<_TagSectionEntry> _flattenHomeIntoSections(ViewHome home) {
    final result = <_TagSectionEntry>[];

    if (ViewHome.recentTags.isNotEmpty) {
        result.add((
            header: "More of...",
            tag: null
        ));

        for (final tag in ViewHome.recentTags) {
            result.add((header: null, tag: tag));
        }
    }

    if (ViewHome.recurringTags.isNotEmpty) {
        result.add((
            header: "You might like...",
            tag: null
        ));

        for (final tag in ViewHome.recurringTags) {
            result.add((header: null, tag: tag));
        }
    }

    if (ViewHome.favoriteTags.isNotEmpty) {
        result.add((
            header: "Favorites",
            tag: null
        ));

        for (final tag in ViewHome.favoriteTags) {
            result.add((header: null, tag: tag));
        }
    }

    return result;
}

class TabViewHome extends StatelessWidget {
    final ViewHome home;

    const TabViewHome({required this.home, super.key});

    @override
    Widget build(BuildContext context) {
        if (!isDesktop) {
            return _ViewHomeMobile(home: home);
        }
        return _ViewHomeDesktop(home: home);
    }
}

class _ViewHomeDesktop extends StatefulWidget {
    final ViewHome home;
    const _ViewHomeDesktop({required this.home});

    @override
    State<_ViewHomeDesktop> createState() => _ViewHomeDesktopState();
}

class _ViewHomeDesktopState extends State<_ViewHomeDesktop> {
    @override
    void initState() {
        super.initState();
        widget.home.initializeIfNeeded();
    }

    @override
    Widget build(BuildContext context) {
        final home = widget.home;

        return Row(
            children: [
                Expanded(
                    child: ActualDisplay(
                        home: home
                    ),
                )
            ],
        );
    }
}

class _ViewHomeMobile extends StatefulWidget {
    final ViewHome home;
    const _ViewHomeMobile({required this.home});

    @override
    State<_ViewHomeMobile> createState() => _ViewHomeMobileState();
}

class _ViewHomeMobileState extends State<_ViewHomeMobile> {
    @override
    void initState() {
        super.initState();
        widget.home.initializeIfNeeded();
    }

    @override
    Widget build(BuildContext context) {
        final home = widget.home;
        return ActualDisplay(home: home);
    }
}

class ActualDisplay extends StatefulWidget {
    final ViewHome home;

    const ActualDisplay({required this.home, super.key});

    @override
    State<ActualDisplay> createState() => _ActualDisplayState();
}

class _ActualDisplayState extends State<ActualDisplay> {
    late ScrollController controller;
    List<_TagSectionEntry> sections = [];

    @override
    void initState() {
        super.initState();

        controller = ScrollController();
    }

    @override
    void dispose() {
        controller.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final home = widget.home;

        if (sections.isEmpty) {
            sections = _flattenHomeIntoSections(widget.home);
        }

        return FadingEdgeScrollView.fromScrollView(
            child: CustomScrollView(
                key: PageStorageKey(widget.home),
                controller: controller,
                slivers: [
                    const SliverPadding(padding: EdgeInsets.symmetric(vertical: 4.0)),
                    SliverToBoxAdapter(
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                Image.asset(
                                    "assets/logo_white.png",
                                    width: 64,
                                    height: 64,
                                    color: Themes.accent,
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            Text(
                                                "Welcome to Nokubooru!",
                                                style: Theme.of(context).textTheme.headlineLarge,
                                            ),
                                            Text(
                                                "Here's a little something for ya.",
                                                style: Theme.of(context).textTheme.titleMedium,
                                            ),
                                        ],
                                    ),
                                )
                            ],
                        ),
                    ),
                    const SliverPadding(padding: EdgeInsets.symmetric(vertical: 4.0)),
                    const SliverToBoxAdapter(child: FadedDivider()),
                    const SliverPadding(padding: EdgeInsets.symmetric(vertical: 4.0)),
                    SliverToBoxAdapter(
                        child: NewestCarousel(
                            home: home,
                            posts: ViewHome.newestPosts
                        ),
                    ),
                    const SliverPadding(padding: EdgeInsets.symmetric(vertical: 4.0)),
                    const SliverToBoxAdapter(child: FadedDivider()),
                    const SliverPadding(padding: EdgeInsets.symmetric(vertical: 4.0)),
                    SliverList(
                        delegate: SliverChildBuilderDelegate(
                            (context, index) {
                                final current = sections[index];

                                if (current.tag == null) {
                                    return SettingsOption(
                                        title: current.header!, 
                                        icon: Icons.tag
                                    );
                                }

                                return TagPostSection(
                                    tag: current.tag!, 
                                    home: home
                                );
                            },
                            childCount: sections.length
                        )
                    ),
                    const SliverPadding(padding: EdgeInsets.symmetric(vertical: 16.0)),
                ],
            ),
        );
    }
}

class NewestCarousel extends StatefulWidget {
    final ViewHome home;
    final List<Post> posts;

    const NewestCarousel({required this.home, required this.posts, super.key});

    @override
    State<NewestCarousel> createState() => _NewestCarouselState();
}

class _NewestCarouselState extends State<NewestCarousel> {
    CarouselSliderController controller = CarouselSliderController();

    @override
    Widget build(BuildContext context) {
        final posts = widget.posts;
        final home = widget.home;
        final scale = (0.35 - 0.8) / (1536 - 600) * (MediaQuery.sizeOf(context).width - 600) + 0.8;

        return CustomContainer(
            borderRadius: BorderRadius.circular(16.0),
            itemPadding: const EdgeInsets.symmetric(vertical: 16.0),
            child: FutureBuilder(
                future: home.newest,
                builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                    }

                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: ValueListenableBuilder(
                                        valueListenable: home.carouselIndex,
                                        builder: (context, value, child) {
                                            return SettingsOption(
                                                title: "Newest Posts",
                                                subtitle: "Check out more from ${posts[home.carouselIndex.value].source.capitalize()}", 
                                                icon: null,
                                                style: SettingsOptionStyle.chip,
                                            );
                                        }
                                    )
                                ),
                            ),
                            Listener(
                                onPointerSignal: (event) {
                                    return;
                                    /*if (event is! PointerScrollEvent) return;
                    
                                    final offset = event.scrollDelta.dy;
                                    
                                    if (offset.sign < 0) {
                                        controller.previousPage(curve: Curves.fastOutSlowIn);
                                        return;
                                    }
                    
                                    controller.nextPage(curve: Curves.fastOutSlowIn);*/
                                },
                                child: CarouselSlider.builder(
                                    carouselController: controller,
                                    itemCount: ViewHome.newestPosts.length,
                                    itemBuilder: (context, index, realIndex) {
                                        return NewestPostCard(
                                            post: ViewHome.newestPosts[index],
                                            tab: home.tab!,
                                        );
                                    },
                                    options: CarouselOptions(
                                        height: 256,
                                        //initialPage: home.carouselIndex.value,
                                        //scrollPhysics: const NeverScrollableScrollPhysics(),
                                        onPageChanged: (index, reason) {
                                            home.carouselIndex.value = index;
                                        },
                                        pageViewKey: const PageStorageKey("carousel"),
                                        enlargeCenterPage: true,
                                        viewportFraction: scale,
                                        enableInfiniteScroll: true,
                                        enlargeStrategy: CenterPageEnlargeStrategy.height
                                    )
                                ),
                            ),
                        ],
                    );
                }
            )
        );
    }
}

class NewestPostCard extends StatelessWidget {
    final TabData tab;
    final Post post;

    const NewestPostCard({required this.tab, required this.post, super.key});

    @override
    Widget build(BuildContext context) {
        final file = post.data.first;
        final data = DownloadManager.fetch(file);
        final ratingInfo = ratingData[post.rating]!;

        return FittedBox(
            child: SizedBox(
                width: (256 * (16 / 9)),
                height: (256),
                child: Card(
                    elevation: 12.0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                        onTap: () {
                            tab.push(ViewPost(post: post));
                        },
                        child: Ink(
                            decoration: BoxDecoration(
                                image: (file.data != null) ? DecorationImage(
                                    image: MemoryImage(
                                        file.data!
                                    ),
                                    fit: BoxFit.cover,
                                    opacity: 0.25
                                ) : null,
                            ),
                            child: Row(
                                children: [
                                    FutureBuilder(
                                        future: data,
                                        initialData: file.data,
                                        builder: (context, snapshot) {
                                            return Ink(
                                                width: (256 * (16 / 9)) / 2,
                                                height: double.infinity,
                                                decoration: BoxDecoration(
                                                    color: Themes.accent.withAlpha((255 * 0.35).floor()),
                                                    image: (file.data != null) ? DecorationImage(
                                                        image: MemoryImage(
                                                            file.data!
                                                        ),
                                                        fit: BoxFit.cover
                                                    ) : null,
                                                ),
                                                child: (snapshot.connectionState == ConnectionState.done) ? (
                                                    (file.data == null) ? Icon(
                                                        Icons.error,
                                                        color: Themes.accent,
                                                    ) : null
                                                ) : Center(
                                                    child: CircularProgressIndicator(
                                                        color: Themes.accent,
                                                    ),
                                                )
                                            );
                                        },
                                    ),
                                    Expanded(
                                        child: Padding(
                                            padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                    Text(
                                                        post.title,
                                                        style: Theme.of(context).textTheme.titleLarge,
                                                        softWrap: true,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text.rich(
                                                        TextSpan(
                                                            children: [
                                                                WidgetSpan(
                                                                    alignment: PlaceholderAlignment.middle,
                                                                    child: CircleAvatar(
                                                                        radius: 12.0,
                                                                        backgroundColor: Colors.transparent,
                                                                        backgroundImage: AssetImage(
                                                                            "assets/${post.source}.png"
                                                                        ),
                                                                    ),
                                                                ),
                                                                const WidgetSpan(
                                                                    alignment: PlaceholderAlignment.middle,
                                                                    child: SizedBox(width: 8.0),
                                                                ),
                                                                TextSpan(
                                                                    text: "#${post.postID}"
                                                                )
                                                            ]
                                                        ),
                                                        style: Theme.of(context).textTheme.bodyMedium,
                                                    ),
                                                    const FadedDivider(height: 24.0),
                                                    FittedBox(
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                                InfoChip(
                                                                    label: ratingInfo.$1,
                                                                    color: ratingInfo.$2,
                                                                    icon: Icon(
                                                                        Icons.star_border,
                                                                        size: 16.0,
                                                                        color: ratingInfo.$2,
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 8.0),
                                                                Text(
                                                                    languageText("app_authors"),
                                                                    style: Theme.of(context).textTheme.titleMedium
                                                                ),
                                                                (post.authors.isEmpty) ? Text(
                                                                    languageText("app_none"), 
                                                                    style: const TextStyle(
                                                                        color: Colors.grey
                                                                    )
                                                                ) : Wrap(
                                                                    children: post.authors.map(
                                                                        (author) => InfoChip(
                                                                            label: author,
                                                                            icon: const Icon(
                                                                                Icons.person,
                                                                                size: 16.0,
                                                                                color: Themes.black
                                                                            ),
                                                                        )
                                                                    ).toList(),
                                                                ),
                                                            ],
                                                        ),
                                                    )
                                                ],
                                            ),
                                        ),
                                    )
                                ],
                            ),
                        ),
                    ),
                ),
            ),
        );
    }
}

class HomeTagSection extends StatelessWidget {
    final ViewHome home;
    
    const HomeTagSection({required this.home, super.key});

    @override
    Widget build(BuildContext context) {
        return Column(
            children: [
                const Card.filled(
                    child: Row(
                        children: [
                            Icon(Icons.tag)
                        ],
                    ),
                ),
                ...ViewHome.recentTags.map(
                    (element) => TagPostSection(
                        home: home, 
                        tag: element
                    )
                ),
                const Card.filled(
                    child: Row(
                        children: [
                            Icon(Icons.tag)
                        ],
                    ),
                ),
                ...ViewHome.recurringTags.map(
                    (element) => TagPostSection(
                        home: home, 
                        tag: element
                    )
                ),
                const Card.filled(
                    child: Row(
                        children: [
                            Icon(Icons.tag)
                        ],
                    ),
                ),
                ...ViewHome.favoriteTags.map(
                    (element) => TagPostSection(
                        home: home, 
                        tag: element
                    )
                )
            ],
        );
    }
}

class TagPostSection extends StatefulWidget {
    final String tag;
    final ViewHome home;

    const TagPostSection({
        required this.tag,
        required this.home,
        super.key,
    });

    @override
    State<TagPostSection> createState() => _TagPostSectionState();
}

class _TagPostSectionState extends State<TagPostSection> {
    late final ScrollController _scrollController;

    @override
    void initState() {
        super.initState();
        _scrollController = ScrollController()..addListener(_onScroll);

        final list = ViewHome.posts[widget.tag]!.posts;
        if (list.isEmpty) {
            widget.home.loadNextPageForTag(widget.tag);
        }
    }

    @override
    void dispose() {
        _scrollController.dispose();
        super.dispose();
    }

    void _onScroll() {
        final hasMore = ViewHome.posts[widget.tag]!.hasMore;
        if (_scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 200 &&
            hasMore) {
            widget.home.loadNextPageForTag(widget.tag);
        }
    }

    @override
    Widget build(BuildContext context) {
        final home = widget.home;
        final posts = ViewHome.posts[widget.tag]!.posts;
        final hasMore = ViewHome.posts[widget.tag]!.hasMore;

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SettingsOption(
                        title: widget.tag, 
                        icon: Icons.tag,
                        trailing: Align(
                            alignment: Alignment.centerRight,
                            child: RoundedBoxButton(
                                onTap: () {
                                    home.tab!.search(widget.tag);
                                },
                                icon: const Icon(Icons.open_in_new)
                            ),
                        ),
                        style: SettingsOptionStyle.chip,
                    ),
                ),
                const SizedBox(height: 4.0),
                SizedBox(
                    height: 128,
                    child: ListView.builder(
                        key: PageStorageKey(widget.tag),
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        itemCount: posts.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                            if (index < posts.length) {
                                final post = posts[index];

                                return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: SizedBox(
                                        width: 128,
                                        child: PostCard(
                                            post: post,
                                            data: home.tab!,
                                            type: PostCardType.normal,
                                            animated: true,
                                        ),
                                    ),
                                );
                            } else {
                                return const SizedBox(
                                    width: 80,
                                    child: Center(
                                        child: CircularProgressIndicator(),
                                    ),
                                );
                            }
                        },
                    ),
                ),
            ],
        );
    }
}
