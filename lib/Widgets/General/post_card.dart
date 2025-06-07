import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/custom_tooltip.dart';
import 'package:nokubooru/Widgets/General/menu_item.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';

enum PostCardType {
    normal,
    child,
    parent
}

class PostCard extends StatefulWidget {
    final Post post;
    final TabData data;
    final PostCardType type;
    final bool animated;
    final VoidCallback? tapCallback; 

    const PostCard({super.key, required this.post, required this.data, this.type = PostCardType.normal, this.animated = false, this.tapCallback});

    @override
    State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
    late ImageProvider image;

    @override
    void initState() {
        super.initState();

        updateImage();
    }

    @override
    void didUpdateWidget(covariant PostCard oldWidget) {
        super.didUpdateWidget(oldWidget);

        if (oldWidget.data != widget.data) {
            updateImage();
        }
    }

    void updateImage() {
        image = (widget.post.data.first.data != null && !(widget.post.isVideo || widget.post.isZip)) ? Image.memory(
            widget.post.data.first.data!,
            filterQuality: FilterQuality.high,
        ).image : Image.network(
            widget.post.preview,
            filterQuality: FilterQuality.high,
            headers: widget.post.headers,
        ).image;
    }

    @override
    Widget build(BuildContext context) {
        //final position = context.globalPaintBounds;
        //updateImage();

        Color borderColor = Themes.accent;
        const double opacity = 0.75;

        switch (widget.type) {
            case PostCardType.child:
                borderColor = Colors.lightGreenAccent.withAlpha((255 * opacity).round());
            case PostCardType.parent:
                borderColor = Colors.orangeAccent.withAlpha((255 * opacity).round());
            default:
                break;
        }

        final mainContainer = Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
                border: Border.all(
                    color: borderColor,
                    width: 2.0
                ),
                boxShadow: const [
                    BoxShadow(
                        offset: Offset(4.0, 4.0),
                        blurRadius: 16.0
                    )
                ],
                borderRadius: const BorderRadius.all(Radius.circular(8.0))
            ),
            child: Material(
                clipBehavior: Clip.hardEdge,
                borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                child: InkWell(
                    onTap: () {
                        final callback = widget.tapCallback;

                        if (callback != null) {
                            callback();
                        }
                        
                        widget.data.push(
                            ViewPost(post: widget.post)
                        );
                    },
                    child: Stack(
                        children: [
                            Ink.image(
                                image: image,
                                fit: BoxFit.cover,
                            ),
                            Positioned(
                                top: 4,
                                left: 4,
                                child: Row(
                                    spacing: 4.0,
                                    children: [
                                        Visibility(
                                            visible: true,
                                            child: Shadowed(
                                                offset: const Offset(1.0, 1.0),
                                                blurRadius: 8.0,
                                                child: CircleAvatar(
                                                    backgroundColor: Colors.transparent,
                                                    foregroundImage: Image.asset(
                                                        "assets/${widget.post.source}.png"
                                                    ).image,
                                                    radius: 10,
                                                ),
                                            )
                                        ),
                                        const Visibility(
                                            visible: false,
                                            child: Shadowed(
                                                offset: Offset(1.0, 1.0),
                                                blurRadius: 8.0,
                                                child: Icon(Icons.offline_pin),
                                            )
                                        )
                                    ],
                                ),
                            )
                        ],
                    ),
                ),
            ),
        );

        final card = Padding(
            padding: const EdgeInsets.all(8.0),
            child: ContextMenuRegion(
                contextMenu: ContextMenu(
                    padding: const EdgeInsets.all(8.0),
                    entries: <ContextMenuEntry>[
                        NokuMenuItem(
                            label: languageText("app_open_on_new_tab"),
                            icon: Icons.open_in_new,
                            onSelected: () {
                                final callback = widget.tapCallback;

                                if (callback != null) {
                                    callback();
                                }

                                widget.data.manager.createNew(
                                    view: ViewPost(post: widget.post),
                                    notify: true,
                                    after: widget.data
                                );
                            },
                        )
                    ]
                ),
                child: (!isDesktop) ? mainContainer : CustomTooltip(
                    position: TooltipPosition.right,
                    tooltip: Container(
                        padding: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                            image: DecorationImage(
                                image: image, 
                                fit: BoxFit.cover,
                                opacity: 0.45,
                                alignment: imageAlignment
                            ),
                            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                            color: Theme.of(context).cardColor,
                            boxShadow: const [
                                BoxShadow(
                                    offset: Offset(4.0, 4.0),
                                    blurRadius: 32.0
                                )
                            ],
                        ),
                        constraints: BoxConstraints.loose(
                            const Size.fromWidth(256.0)
                        ),
                        child: Text.rich(
                            TextSpan(
                                style: const TextStyle(
                                    color: Colors.white,
                                    shadows: [
                                        Shadow(
                                            offset: Offset(2.0, 2.0),
                                            blurRadius: 8.0
                                        )
                                    ]
                                ),
                                children: [
                                    TextSpan(
                                        text: widget.post.title,
                                        style: const TextStyle(fontSize: 14.0)
                                    ),
                                    const TextSpan(text: "\n"),
                                    TextSpan(
                                        children: [
                                            if (widget.post.authors.isNotEmpty) TextSpan(
                                                text: "${languageText("app_original_by", [widget.post.authors.join(', ')])} | "
                                            ),
                                            TextSpan(
                                                text: "${widget.post.dimensions.first}"
                                            ),
                                            TextSpan(
                                                children: [
                                                    const TextSpan(text: "\n"),
                                                    TextSpan(
                                                        text: "${languageText("app_from")} "
                                                    ),
                                                    WidgetSpan(
                                                        alignment: PlaceholderAlignment.middle,
                                                        child: SizedBox(
                                                            width: 16,
                                                            height: 16,
                                                            child: Image.asset(
                                                                "assets/${widget.post.source}.png",
                                                            ),
                                                        )
                                                    ),
                                                    TextSpan(text: " ${widget.post.source.capitalize()}.")
                                                ]
                                            )
                                        ],
                                        style: const TextStyle(
                                            fontSize: 10.0,
                                            color: Colors.white70
                                        )
                                    )
                                ]
                            )
                        ),
                    ),
                    child: mainContainer
                ),
            ),
        );

        if (!widget.animated) return card;

        const Duration duration = Duration(milliseconds: 500);
        const Cubic curve = Curves.easeInOut;

        return card.animate(
            delay: const Duration(milliseconds: 100)
        ).move(begin: const Offset(32, 0), duration: duration, curve: curve)
        .scale(begin: const Offset(0.5, 0.5), duration: duration, curve: curve)
        .fadeIn(begin: 0, duration: duration, curve: curve);
    }
}

class Shadowed extends StatelessWidget {
    final Widget child;
    final Offset? offset;
    final double? blurRadius;

    const Shadowed({required this.child, this.offset, this.blurRadius, super.key});

    @override
    Widget build(BuildContext context) => Container(
            decoration: BoxDecoration(
                boxShadow: [
                    BoxShadow(
                        offset: offset ?? const Offset(4.0, 4.0),
                        blurRadius: blurRadius ?? 32.0
                    )
                ]
            ),
            child: child,
        );
}