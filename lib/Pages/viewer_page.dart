import 'dart:async';

import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/overlay.dart';
import 'package:nokubooru/Widgets/Post/post_media.dart';
import 'package:nokubooru/main.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/utils.dart';

class TabViewViewer extends StatelessWidget {
    final ViewViewer data;

    const TabViewViewer({required this.data, super.key});

    @override
    Widget build(BuildContext context) => FutureBuilder(
            future: data.future, 
            builder: (context, snapshot) {
                if (snapshot.hasError) {
                    data.tab!.replace(data, ViewError());

                    return Container(
                        constraints: BoxConstraints.tight(
                            MediaQuery.sizeOf(context)
                        ),
                        decoration: BoxDecoration(
                            color: Colors.black.withAlpha(128)
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                    );
                }

                if (snapshot.connectionState == ConnectionState.done) {
                    return _TabViewViewer(
                        key: key,
                        data: data
                    );
                }

                return Container(
                    constraints: BoxConstraints.tight(
                        MediaQuery.sizeOf(context)
                    ),
                    decoration: BoxDecoration(
                        color: Colors.black.withAlpha(128)
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                );
            },
        );
}

class _TabViewViewer extends StatefulWidget {
    final ViewViewer data;

    const _TabViewViewer({required this.data, super.key});

    @override
    State<_TabViewViewer> createState() => _TabViewViewerState();
}

class _TabViewViewerState extends State<_TabViewViewer> with SingleTickerProviderStateMixin {
    List<PostImage> images = [];
    SwiperController controller = SwiperController();
    TransformationController transformationController = TransformationController();
    Timer? fadeTimer;
    Offset offset = const Offset(0, 128);
    Duration duration = const Duration(seconds: 3);
    Matrix4? transform;
    double opacity = 0.0;
    SwiperControl? control = const SwiperControl();
    final double zoomScale = 2.0;
    TapDownDetails? tapDownDetails;

    // Animation controller and tween for smooth zoom animation.
    late AnimationController _animationController;
    Animation<Matrix4>? _animation;

    @override
    void initState() {
        super.initState();

        images = widget.data.post.data
            .map((element) => PostImage(file: element, visible: false))
            .toList();

        transformationController.addListener(() {
            control = (transformationController.value.isIdentity())
                ? const SwiperControl()
                : null;
        });
        transform = Transform.translate(offset: Offset.zero).transform;
        fadeTimer = Timer(duration, swipeDown);

        _animationController = AnimationController(
            duration: const Duration(milliseconds: 300),
            vsync: this,
        );

        SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky
        );

        if (!isDesktop) {
            nbSearchBarController.setFixed(false);
            Future.delayed(Duration.zero, (){
                nbSearchBarController.toggleBar(false);
            });
        }
    }

    @override
    void dispose() {
        print("dispooooooooooose");
        _animationController.dispose();
        fadeTimer?.cancel();
        
        Future.delayed(Duration.zero, () {
            nbSearchBarController.setFixed(true);
        });

        SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.edgeToEdge
        );
        
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent, // Make status bar transparent
            systemNavigationBarColor: Colors.transparent, // Make navigation bar transparent
            statusBarIconBrightness: Brightness.light, // Adjust icon brightness if needed
            systemNavigationBarIconBrightness: Brightness.light,
        ));

        super.dispose();
    }

    void swipeDown() {
        fadeTimer?.cancel();
        if (mounted) {
            setState(() {
                transform = Transform.translate(offset: offset).transform;
                opacity = 0.0;
            });
        }
    }

    void _onDoubleTap(TapDownDetails details) {
        final tapPosition = details.localPosition;
        final identity = Matrix4.identity();
        final currentMatrix = transformationController.value;
        Matrix4 targetMatrix;

        if (currentMatrix == identity) {
            targetMatrix = Matrix4.identity()
                ..translate(
                    -tapPosition.dx * (zoomScale - 1),
                    -tapPosition.dy * (zoomScale - 1),
                )
                ..scale(zoomScale);
        } else {
            targetMatrix = identity;
        }
        _animateTransformation(currentMatrix, targetMatrix);
    }

    void _animateTransformation(Matrix4 begin, Matrix4 end) {
        _animation = Matrix4Tween(begin: begin, end: end).animate(
            CurvedAnimation(
                parent: _animationController,
                curve: Curves.fastEaseInToSlowEaseOut,
            ),
        );

        _animation!.addListener(() {
            setState(() {
                transformationController.value = _animation!.value;
            });
        });

        _animationController.forward(from: 0);
    }

    void preloadNext() {
        if (images.length <= 1) return;

        final preloadLength = Settings.preloadViewerDistance.value;
        final numOfImages = images.length;

        for (var i = widget.data.current; i < (widget.data.current + preloadLength); i++) {
            final image = images[i % numOfImages];

            if (image.file.completed || image.file.inProgress) continue;

            image.file.fetch();
        }
    }

    @override
    Widget build(BuildContext context) => OverlayWidget(
            onTap: (active) {
                Nokulog.d("active: $active");
                if (active) {
                    SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.edgeToEdge
                    );
                    nbSearchBarController.toggleBar(true);
                    return;
                }

                SystemChrome.setEnabledSystemUIMode(
                    SystemUiMode.immersiveSticky
                );
                nbSearchBarController.toggleBar(false);
            },
            overlay: Container(
                padding: const EdgeInsets.all(12.0),
                child: (!isDesktop) ? IconButton.outlined(
                    style: IconButton.styleFrom(
                        side: BorderSide(
                            color: Themes.accent,
                            width: 2.0
                        )
                    ),
                    onPressed: (widget.data.tab!.canBacktrack) ? widget.data.tab!.backtrack : null, 
                    icon: Icon(
                        Icons.chevron_left,
                        color: (widget.data.tab!.canBacktrack ) ? Themes.accent : null,
                    )
                ) : const SizedBox.shrink(),
            ),
            child: Swiper.list(
                list: images,
                control: control,
                loop: (images.length > 1),
                pagination: SwiperCustomPagination(
                    builder: (context, config) => Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: AnimatedContainer(
                                    curve: Curves.fastEaseInToSlowEaseOut,
                                    duration: const Duration(milliseconds: 600),
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(16.0),
                                        ),
                                        color: Theme.of(context).cardColor,
                                        boxShadow: const [
                                            BoxShadow(
                                                offset: Offset(4.0, 4.0),
                                                blurRadius: 32.0,
                                            )
                                        ],
                                    ),
                                    transform: transform,
                                    child: Text(
                                        "${config.activeIndex + 1} / ${config.itemCount}",
                                    ),
                                ),
                            ),
                        ),
                ),
                controller: controller,
                onIndexChanged: (index) {
                    setState(() {
                        widget.data.current = index;
                        widget.data.tab!.update();
                    });

                    preloadNext();

                    transform = Transform.translate(offset: Offset.zero).transform;
                    opacity = 1.0;

                    fadeTimer?.cancel();
                    fadeTimer = Timer(duration, swipeDown);
                },
                builder: (context, data, index) => GestureDetector(
                        onDoubleTapDown: (details) {
                            tapDownDetails = details;
                        },
                        onDoubleTap: () {
                            if (tapDownDetails != null) {
                                _onDoubleTap(tapDownDetails!);
                            }
                        },
                        child: InteractiveViewer(
                            transformationController: transformationController,
                            constrained: true,
                            clipBehavior: Clip.none,
                            minScale: 0.5,
                            maxScale: 6.5,
                            child: data,
                        ),
                    ),
            ),
        );
}
