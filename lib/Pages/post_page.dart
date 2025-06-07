import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nokubooru/State/post_resolver.dart';
import 'package:nokubooru/State/searcher.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/collapsable_container.dart';
import 'package:nokubooru/Widgets/General/custom_container.dart';
import 'package:nokubooru/Widgets/General/padded_widget.dart';
import 'package:nokubooru/Widgets/Post/comment_widget.dart';
import 'package:nokubooru/Widgets/Post/post_media.dart';
import 'package:nokubooru/Widgets/Post/tag_button.dart';
import 'package:nokubooru/Widgets/General/post_card.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';
import 'package:url_launcher/url_launcher.dart';

class TabViewPost extends StatefulWidget {
    final ViewPost data;

    const TabViewPost({super.key, required this.data});

    @override
    State<TabViewPost> createState() => _TabViewPostState();
}

class _TabViewPostState extends State<TabViewPost> {
    ScrollController controller = ScrollController();
    double mediaHeightScale = 0.75;
    double mediaHeight = 500;

    @override
    void initState() {
        super.initState();

        controller.addListener(() {
            final offset = controller.offset;

            setState(() {
                if (offset <= 0) {
                    mediaHeight = 500;
                } else if (offset > 100) {
                    mediaHeight = 250;
                }
            });
        });
    }

    @override
    void didUpdateWidget(covariant TabViewPost oldWidget) {
        super.didUpdateWidget(oldWidget);
    }

    @override
    Widget build(BuildContext context) {
        if (widget.data.isComplete) {
            return ActualViewPost(data: widget.data, post: widget.data.post);
        }

        return FutureBuilder(
            future: widget.data.future, 
            builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done || (snapshot.connectionState == ConnectionState.none && widget.data.isComplete)) {
                    return ActualViewPost(data: widget.data, post: widget.data.post);
                }

                return const Center(child: CircularProgressIndicator());
            },
        );
    }
}

class ActualViewPost extends StatelessWidget {
    final ViewPost data;
    final Post post;

    const ActualViewPost({required this.data, required this.post, super.key});

    @override
    Widget build(BuildContext context) {
        post.recheckTags();
        final tags = List<Tag>.from(post.tags)..sort(compareTags);
        const Duration animationDuration = Duration(milliseconds: 900);
        const Cubic animationCurve = Curves.easeOutSine;
        final String? url = generateOriginalURL(post);

        final tagSlivers = [
            SliverList(
                delegate: SliverChildBuilderDelegate(
                    (context, index) => TagButton(
                            tag: tags[index],
                            tabData: data.tab!,
                        ),
                    childCount: tags.length,
                ),
            ),
            const SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                ),
            ),
            SliverToBoxAdapter(
                child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            width: 2.0,
                            color: Themes.accent,
                        ),
                        iconColor: Themes.accent,
                    ),
                    onPressed: (url == null) ? null : () {
                        launchUrl(Uri.parse(url));
                    }, 
                    label: Text(
                        languageText("app_go_to_original"),
                        style: TextStyle(
                            color: Themes.accent
                        )
                    ),
                    icon: const Icon(Icons.open_in_browser),
                )
            ),
            const SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                ),
            ),
            SliverToBoxAdapter(
                child: PostInformationCard(post: post, tab: data.tab!),
            ),
        ];

        final postMedia = PostMedia(
            onTap: () {
                data.tab!.push(ViewViewer(post: post));
            },
            file: data.data.first,
            post: post
        );

        Widget viewPostContent = Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                CollapsableContainer(
                    child: DynMouseScroll(
                        builder: (context, controller, physics) => FadingEdgeScrollView.fromScrollView(
                                child: CustomScrollView(
                                    controller: controller,
                                    physics: physics,
                                    slivers: tagSlivers
                                ),
                            ),
                    ),
                ).animate()
                .moveX(begin: (-128 * 4), duration: animationDuration, curve: animationCurve)
                //.scale(begin: const Offset(0.75, 0.75), duration: duration, curve: curve)
                .fadeIn(begin: 0.25, duration: animationDuration, curve: animationCurve),
                Flexible(
                    flex: 2,
                    fit: FlexFit.tight,
                    child: PaddedWidget(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
                        child: MediaSide(
                            key: ValueKey(post.hashCode),
                            data: data,
                            child: postMedia
                        ),
                    ),
                )
            ],
        );

        if (!isDesktop) {
            viewPostContent = DynMouseScroll(
                builder: (p0, p1, p2) => RefreshIndicator(
                    onRefresh: () async {
                        data.reload();
                        return () async {
                            await data.future;
                        }();
                    },
                    child: FadingEdgeScrollView.fromScrollView(
                        child: CustomScrollView(
                            controller: p1,
                            physics: p2,
                            slivers: [
                                SliverToBoxAdapter(
                                    child: MediaSide(
                                        data: data,
                                        child: postMedia
                                    ),
                                ),
                                CustomSliverContainer(
                                    sliver: SliverPadding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                        sliver: MultiSliver(
                                            children: tagSlivers
                                        )
                                    )
                                ),
                                const SliverPadding(padding: EdgeInsets.only(bottom: 48.0)) // Temporary measure to avoid bottom UI.
                            ].map((element) => SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 8.0), sliver: element)).toList(),
                        ),
                    ),
                ),
            );
        }

        return viewPostContent;
    }
}

class MediaSide extends StatefulWidget {
    final ViewPost data;
    final Widget child;

    const MediaSide({required this.data, required this.child, super.key});

    @override
    State<MediaSide> createState() => _MediaSideState();
}

class _MediaSideState extends State<MediaSide> {
    final List<Comment> comments = [];
    final List<PostCard> family = [];

    @override
    void initState() {
        super.initState();

        if (!Searcher.isActiveSubfinder(widget.data.post.source)) {
            // Ask whether or not to enable.
            return;
        }

        if (widget.data.description == null && !widget.data.hasCheckedDescription) {
            Searcher.postGetDescription(widget.data.post).then((description) {
                widget.data.description = description;
                widget.data.hasCheckedDescription = true;

                if (mounted) {
                    setState((){});
                }
            });
        }

        if (widget.data.comments == null) {
            Searcher.postGetComments(widget.data.post).then((comments) {
                widget.data.comments = comments;
                setComments(comments);
                if (mounted) {
                    setState((){});
                }
            });
        } else {
            setComments(widget.data.comments!);
        }

        final parentFuture = () async {
            if (!widget.data.hasCheckedParent) {
                return Searcher.postGetParent(widget.data.post)..then(setParent);
            } else {
                setParent(widget.data.postParent);
                return null;
            }
        }();

        final childrenFuture = () async {
            if (widget.data.children == null) {
                return Searcher.postGetChildren(widget.data.post)..then(
                    (children) {
                        widget.data.children = children;
                        family.addAll(children.map((child) => PostCard(post: child, data: widget.data.tab!, type: PostCardType.child)));
                    }
                );
            } else {
                family.addAll(widget.data.children!.map((child) => PostCard(post: child, data: widget.data.tab!, type: PostCardType.child)));
                return null;
            }
        }();

        Future.wait([parentFuture, childrenFuture]).then((_) {
            if (mounted) {
                setState((){});
            }
        });
    }

    void setComments(List<Comment> comments) {
        this.comments.clear();
        this.comments.addAll(comments);
    }

    void setParent(Post? post) {
        if (post == null || widget.data.hasCheckedParent) return;

        if (family.isEmpty) {
            family.add(PostCard(post: post, data: widget.data.tab!, type: PostCardType.parent));
        } else {
            family.insert(0, PostCard(post: post, data: widget.data.tab!, type: PostCardType.parent));
        }

        widget.data.hasCheckedParent = true;
        widget.data.postParent = post;

        Searcher.postGetChildren(post).then(
            (children) {
                widget.data.children?.addAll(children);
                family.addAll(children.map((child) => PostCard(post: child, data: widget.data.tab!, type: PostCardType.child)));
                family.removeWhere((element) => element.post.identifier == widget.data.post.identifier);
                if (mounted) {
                    setState((){});
                }
            }
        );
    }

    @override
    Widget build(BuildContext context) {
        if (!isDesktop) {
            return MediaSideMobile(
                key: ValueKey(widget.data.post),
                data: widget.data, 
                family: family, 
                comments: comments, 
                child: widget.child
            );
        }

        return MediaSideDesktop(
            key: ValueKey(widget.data.post),
            data: widget.data, 
            family: family, 
            comments: comments, 
            child: widget.child
        );
    }
}

class MediaSideDesktop extends StatefulWidget {
    final ViewPost data;
    final List<PostCard> family;
    final List<Comment> comments;
    final Widget child;

    const MediaSideDesktop({required this.data, required this.family, required this.comments, required this.child, super.key});

    @override
    State<MediaSideDesktop> createState() => _MediaSideDesktopState();
}

class _MediaSideDesktopState extends State<MediaSideDesktop> {
    final ScrollController controller = ScrollController();
    final double maxMediaHeightScale = 0.85;
    final double minMediaHeightScale = 0.45;

    double mediaHeightScale = 1;
    int scrollOffset = 5;

    @override
    void initState() {
        super.initState();

        mediaHeightScale = maxMediaHeightScale;
        controller.addListener(onScroll);
    }

    @override
    void dispose() {
        controller.dispose();
        super.dispose();
    }

    void onScroll() {
        final offset = controller.offset;

        setState(() {
            if (offset <= 0) {
                mediaHeightScale = maxMediaHeightScale;
            } else if (offset > scrollOffset) {
                mediaHeightScale = minMediaHeightScale;
            }
        });
    }

    @override
    Widget build(BuildContext context) {
        final Widget familyContainer = PostFamilyContainer(family: widget.family);
        const Duration animationDuration = Duration(milliseconds: 900);
        const Cubic animationCurve = Curves.easeOutSine;
        final List<Comment> comments = widget.comments;

        final Column content = Column(
            children: [
                Row(
                    children: [
                        if (widget.family.isNotEmpty) Expanded(child: familyContainer),
                        if (widget.data.description != null) Expanded(
                            child: PostDescription(
                                description: widget.data.description,
                                post: widget.data.post,    
                            )
                        )
                    ],
                ),
                Expanded(child: widget.child),
            ],
        );

        return LayoutBuilder(
            builder: (context, constraints) {
                //var dimensions = widget.data.post.data.first.dimensions;
                final beginPosition = (constraints.maxHeight - ((constraints.maxHeight - 64) * mediaHeightScale)) * 2;

                final Widget child = ConstrainedBox(
                    constraints: const BoxConstraints(
                        //maxHeight: constraints.maxWidth * (dimensions.x / dimensions.y)
                    ),
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutSine,
                        height: (comments.isEmpty) ? (constraints.maxHeight - 8) : (constraints.maxHeight - 64) * mediaHeightScale,
                        child: content,
                    ),
                );

                return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        child,
                        if (comments.isNotEmpty) Expanded(
                            child: CustomContainer(
                                padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
                                itemPadding: const EdgeInsets.all(8.0),
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16.0),
                                    topRight: Radius.circular(16.0)
                                ),
                                child: Column(
                                    children: [
                                        Text(
                                            languageText("app_comments"),
                                            style: TextStyle(
                                                color: getTextColor(Theme.of(context).cardColor),
                                                fontSize: 21,
                                                fontWeight: FontWeight.bold
                                            ),
                                        ),
                                        Expanded(
                                            child: CustomScrollView(
                                                controller: controller,
                                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                                slivers: [
                                                    SliverList.builder(
                                                        itemCount: comments.length,
                                                        itemBuilder: (context, index) => CommentWidget(
                                                                comment: comments[index], 
                                                                post: widget.data.post
                                                            ),
                                                    ),
                                                    SliverFillRemaining(
                                                        hasScrollBody: true,
                                                        child: ConstrainedBox(
                                                            constraints: BoxConstraints.loose(const Size.fromHeight(32)),
                                                            child: SizedBox.fromSize(size: const Size.fromHeight(32))
                                                        ),
                                                    )
                                                ],
                                            )
                                        )
                                    ],
                                )
                            ).animate()
                            .moveY(begin: beginPosition, duration: animationDuration, curve: animationCurve)
                            .fadeIn(begin: 0.25, duration: animationDuration, curve: animationCurve)
                        )
                    ],
                );
            },
        );
    }
}

class MediaSideMobile extends StatefulWidget {
    final ViewPost data;
    final List<PostCard> family;
    final List<Comment> comments;
    final Widget child;

    const MediaSideMobile({required this.data, required this.family, required this.comments, required this.child, super.key});

    @override
    State<MediaSideMobile> createState() => _MediaSideMobileState();
}

class _MediaSideMobileState extends State<MediaSideMobile> {
    @override
    Widget build(BuildContext context) {
        var child = widget.child;
        final comments = widget.comments;
        final post = widget.data.post;
        final dimension = post.dimensions.first;


        if (post.isVideo) {
            child = LayoutBuilder(
                builder: (context, constraints) => ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: dimension.y * constraints.maxWidth / dimension.x
                        ),
                        child: widget.child,
                    ),
            );
        }
        
        return Column(
            spacing: 8.0,
            children: [
                if (widget.family.isNotEmpty) PostFamilyContainer(family: widget.family),
                Padding(
                    padding: (widget.family.isEmpty) ? const EdgeInsets.only(top: 8.0) : EdgeInsets.zero,
                    child: child
                ),
                ConditionalWidget(
                    condition: (widget.data.description != null), 
                    alternate: const SizedBox.shrink(), 
                    child: PostDescription(
                        description: widget.data.description,
                        post: post,
                        height: 512,
                    )
                ),
                ConditionalWidget(
                    condition: comments.isNotEmpty,
                    alternate: const SizedBox.shrink(), 
                    child: CustomContainer(
                        borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                        padding: const EdgeInsets.all(8.0),
                        child: ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: comments.length,
                            itemBuilder: (context, index) => CommentWidget(
                                    comment: comments[index], 
                                    post: post
                                ),
                        )
                    )
                )
            ],
        );
    }
}

class ConditionalWidget extends StatelessWidget {
    final Widget child;
    final Widget alternate;
    final bool condition;

    const ConditionalWidget({required this.condition, required this.alternate, required this.child, super.key});

    @override
    Widget build(BuildContext context) {
        if (condition) {
            return child;
        }

        return alternate;
    }
}

class PostFamilyContainer extends StatefulWidget {
    static const double cardSize = 96.0;
    
    final List<PostCard> family;

    const PostFamilyContainer({required this.family, super.key});

    @override
    State<PostFamilyContainer> createState() => _PostFamilyContainerState();
}

class _PostFamilyContainerState extends State<PostFamilyContainer> {
    late ScrollController controller;

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
        Widget item = CustomContainer(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            padding: const EdgeInsets.all(8.0),
            itemPadding: EdgeInsets.zero,
            constraints: const BoxConstraints(
                maxHeight: PostFamilyContainer.cardSize
            ),
            child: Listener(
                onPointerSignal: (event) {
                    if (event is! PointerScrollEvent) return;

                    final offset = event.scrollDelta.dy;
                    final position = (controller.offset + offset).clamp(
                        0, 
                        controller.position.maxScrollExtent
                    ).toDouble();
                    controller.jumpTo(position);
                },
                child: FadingEdgeScrollView.fromScrollView(
                    child: ListView.builder(
                        controller: controller,
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.antiAlias,
                        itemCount: widget.family.length,
                        itemBuilder: (context, index) => ConstrainedBox(
                            constraints: BoxConstraints.tight(const Size.square(PostFamilyContainer.cardSize)),
                            child: widget.family[index]
                        ),
                    ),
                ),
            ),
        );
        if (widget.family.isEmpty) item = const SizedBox.shrink();

        return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: item,
        );
    }
}

class PostDescription extends StatefulWidget {
    static const double cardSize = 96.0;

    final Description? description;
    final Post post;
    final double? height;

    const PostDescription({required this.description, required this.post, this.height, super.key});

    @override
    State<PostDescription> createState() => _PostDescriptionState();
}

class _PostDescriptionState extends State<PostDescription> {
    bool inTranslated = true;
    ScrollController scrollController = ScrollController();

    @override
    void dispose() {
        scrollController.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final Description? description = widget.description;

        final bool hasTranslated = (description?.translatedTitle != null && description?.translatedDescription != null);

        if (inTranslated && !hasTranslated) {
            inTranslated = false;
        }

        if (description == null) {
            return AnimatedSwitcher(
                key: ValueKey("descriptionSwitcher${widget.post.hashCode}"),
                duration: const Duration(milliseconds: 500),
                child: const SizedBox.shrink(),
            );
        }

        final descriptionText = description.getDescription(preferTranslated: inTranslated, asMarkdown: true);
        final titleText = description.getTitle(preferTranslated: inTranslated, asMarkdown: true);

        final Widget finalWidget = CustomContainer(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            padding: const EdgeInsets.all(8.0),
            itemPadding: EdgeInsets.zero,
            constraints: BoxConstraints(
                maxHeight: widget.height ?? PostDescription.cardSize
            ),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                child: SelectionArea(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8.0,
                        children: [
                            Flexible(
                                fit: FlexFit.loose,
                                child: ConstrainedBox(
                                    constraints: BoxConstraints.loose(
                                        const Size.fromHeight(32)
                                    ),
                                    child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                            Expanded(
                                                child: FittedBox(
                                                    alignment: Alignment.topLeft,
                                                    child: MarkdownBody(
                                                        data: titleText ?? "Description",
                                                        onTapLink: (text, href, title) {
                                                            if (href == null) return;
                                                
                                                            if (href.startsWith("/")) {
                                                                href = "https://danbooru.donmai.us$href";
                                                            }
                                                
                                                            launchUrl(Uri.parse(href));
                                                        },
                                                        styleSheet: MarkdownStyleSheet(
                                                            p: const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight: FontWeight.bold
                                                            ),
                                                        ),
                                                    ),
                                                ),
                                            ),
                                            if (hasTranslated) OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                    iconColor: Themes.accent,
                                                    side: BorderSide(
                                                        color: Themes.accent,
                                                        width: 2.0
                                                    )
                                                ),
                                                onPressed: () {
                                                    setState(() {
                                                        inTranslated = !inTranslated;
                                                    });
                                                }, 
                                                label: Text(
                                                    (inTranslated) ? "Original" : "Translated",
                                                    style: TextStyle(
                                                        color: Themes.accent
                                                    ),
                                                )
                                            )
                                        ],
                                    ),
                                ),
                            ),
                            Flexible(
                                fit: FlexFit.loose,
                                child: FadingEdgeScrollView.fromSingleChildScrollView(
                                    child: SingleChildScrollView(
                                        controller: scrollController,
                                        child: MarkdownBody(
                                            shrinkWrap: (widget.height?.isInfinite == true),
                                            fitContent: (widget.height?.isInfinite == true),
                                            onTapLink: (text, href, title) {
                                                if (href == null) return;
                                    
                                                if (href.startsWith("/")) {
                                                    href = "https://danbooru.donmai.us$href";
                                                }
                                    
                                                launchUrl(Uri.parse(href));
                                            },
                                            data: descriptionText ?? "> No description."
                                        ),
                                    ),
                                ),
                            )
                        ],
                    ),
                ),
            ),
        );

        return AnimatedSwitcher(
            key: ValueKey("descriptionSwitcher${widget.post.hashCode}"),
            duration: const Duration(milliseconds: 500),
            child: finalWidget,
        );
    }
}

class PostInformation extends StatelessWidget {
    final Post post;
    final TabData tab;

    const PostInformation({required this.post, required this.tab, super.key});

    @override
    Widget build(BuildContext context) => Container(
            padding: const EdgeInsets.all(8.0),
            child: SelectionArea(
                child: MarkdownBody(
                    data:   "- **${languageText("app_title")}**: ${post.title}\n"
                            "- **${languageText("app_post_id")}**: ${post.postID}\n"
                            "- **${languageText("app_rating")}**: ${toTitle(post.rating.name)}\n"
                            "- **${languageText("app_authors")}**:\n${(post.authors.isEmpty) ? '(${languageText("app_empty")})\n' : post.authors.map((author) => "  - \"$author\"\n").join()}"
                            "- **${languageText("app_source")}**: ${post.source}\n"
                            "- **${languageText("app_sources")}**:\n${(post.sources.isEmpty) ? '(${languageText("app_empty")})\n' : post.sources.map((source) => "  - $source\n").join()}"
                            "- **${languageText("app_posted_by")}**: ${post.poster} (${post.posterID ?? languageText("app_unknown")})\n"
                            "- **${languageText("app_dimensions")}**: ${post.dimensions.first}\n"
                            "- **${languageText("app_images")}**:\n${post.images.map((image) => "  - $image\n").join()}",
                    onTapLink: (text, href, title) async {
                        if (href == null) return;
                
                        final PostResult possiblePostResult = PostResolver.resolve(Uri.parse(href));
                        final Post? possiblePost = (await (possiblePostResult.post ?? Future.value(null)));
                        final String possibleQuery = possiblePostResult.query;
                
                        if (possiblePost != null && post.identifier != possiblePost.identifier) {
                            tab.push(
                                ViewPost(
                                    post: possiblePost
                                )
                            );
                            return;
                        }
                        
                        launchUrl(Uri.parse(href));     
                    },
                    selectable: true,
                ),
            ),
        );
}

// Imagine descovering what records are.
Map<Rating, (String name, Color color)> ratingData = {
    Rating.general:         (languageText("app_rating_general"), Colors.lightGreenAccent),
    Rating.sensitive:       (languageText("app_rating_sensitive"), Colors.yellow),
    Rating.questionable:    (languageText("app_rating_questionable"),  Colors.orangeAccent),
    Rating.explicit:        (languageText("app_rating_explicit"), Colors.red),
    Rating.unknown:         (languageText("app_rating_unknown"), Colors.grey),
};

class PostInformationCard extends StatelessWidget {
    final Post post;
    final TabData tab;

    const PostInformationCard({required this.post, required this.tab, super.key});

    @override
    Widget build(BuildContext context) {
        final ratingInfo = ratingData[post.rating]!;

        return Padding(
            padding: const EdgeInsets.all(4.0),
            child: SelectionArea(
                child: Card(
                    elevation: 8.0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0)
                    ),
                    child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4.0,
                            children: [
                                Text(
                                    post.title,
                                    style: Theme.of(context).textTheme.headlineSmall,
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
                                    style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const Divider(height: 24.0),
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
                                const SizedBox(height: 8.0),
                                Text(
                                    languageText(
                                        (post.sources.length > 1) ? "app_sources" : "app_source"
                                    ), 
                                    style: Theme.of(context).textTheme.titleMedium
                                ),
                                (post.sources.isEmpty) ? Text(
                                    languageText("app_none"),
                                    style: const TextStyle(
                                        color: Colors.grey
                                    )
                                )
                                : Wrap(
                                    children: post.sources.map(
                                        (source) => InfoChip(
                                            label: source,
                                            icon: const Icon(
                                                Icons.link,
                                                size: 16.0,
                                                color: Themes.black
                                            ),
                                        )
                                    ).toList(),
                                ),
                                const SizedBox(height: 8.0),
                                Text.rich(
                                    TextSpan(
                                        children: [
                                            const WidgetSpan(
                                                child: Icon(Icons.person, size: 20),
                                                alignment: PlaceholderAlignment.middle
                                            ),
                                            const WidgetSpan(child: SizedBox(width: 6)),
                                            TextSpan(text: "${post.poster} (${post.posterID ?? languageText("app_unknown")})")
                                        ]
                                    )
                                ),
                                const SizedBox(height: 8.0),
                                Text.rich(
                                    TextSpan(
                                        children: [
                                            const WidgetSpan(
                                                child: Icon(Icons.aspect_ratio, size: 20),
                                                alignment: PlaceholderAlignment.middle
                                            ),
                                            const WidgetSpan(child: SizedBox(width: 6)),
                                            TextSpan(text: post.dimensions.first.toString())
                                        ]
                                    )
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                    languageText("app_media"), 
                                    style: Theme.of(context).textTheme.titleMedium
                                ),
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: post.data.map(
                                        (file) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: MediaItem(
                                                file: file
                                            ),
                                        )
                                    ).toList(),
                                ),
                            ],
                        ),
                    ),
                ),
            ),
        );
    }
}

class InfoChip extends StatelessWidget {
    final String label;
    final Color? color;
    final Icon? icon;

    const InfoChip({required this.label, this.color, this.icon, super.key});

    @override
    Widget build(BuildContext context) {
        final Uri? possibleUrl = (label.startsWith("http") || label.startsWith("nokubooru")) ? Uri.tryParse(label) : null;

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 4, bottom: 4),
            decoration: BoxDecoration(
                color: (color?.withAlpha((0.1 * 255).floor())) ?? Themes.white,
                borderRadius: BorderRadius.circular(16),
            ),
            child: Text.rich(
                TextSpan(
                    children: [
                        if (icon != null) WidgetSpan(
                            child: icon!,
                            alignment: PlaceholderAlignment.middle
                        ),
                        if (icon != null) const WidgetSpan(child: SizedBox(width: 6.0)),
                        (possibleUrl == null) ? TextSpan(
                            text: label
                        ) : WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: InkWell(
                                onTapUp: (_) {
                                    launchUrl(
                                        possibleUrl,
                                    );
                                },
                                child: Text(
                                    label,
                                    style: TextStyle(
                                        color: color ?? Themes.black
                                    )
                                ),
                            )
                        ),
                    ]
                ), 
                style: TextStyle(
                    color: color ?? Themes.black
                )
            ),
        );
    }
}

class MediaItem extends StatelessWidget {
    final PostFile file;

    const MediaItem({required this.file, super.key});

    @override
    Widget build(BuildContext context) {
        IconData icon;

        switch (file.type) {
            case PostFileType.video:
                icon = FontAwesomeIcons.video;
                break;
            case PostFileType.image:
                icon = (file.filename.endsWith(".gif")) ? FontAwesomeIcons.fileImage : FontAwesomeIcons.image;
                break;
            case PostFileType.zip:
                icon = FontAwesomeIcons.fileZipper;
                break;
            default:
                icon = FontAwesomeIcons.image;
                break;
        }

        return InkWell(
            borderRadius: BorderRadius.circular(4.0),
            onTap: () async {
                bool result;

                try {
                    result = await launchUrl(
                        Uri.parse(file.url),
                        webViewConfiguration: WebViewConfiguration(
                            headers: file.headers
                        ),
                    );
                } catch (e, stackTrace) {
                    Nokulog.e("An error occurred whilst launching the URL.", error: e, stackTrace: stackTrace);
                    result = false;
                }

                if (result) return;

                //Notify.showMessage(message: message)
            },
            child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Row(
                    children: [
                        Icon(
                            icon,
                            size: 16,
                            color: Themes.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                file.url,
                                overflow: TextOverflow.ellipsis,
                            )
                        )
                    ],
                ),
            ),
        );
    }
}