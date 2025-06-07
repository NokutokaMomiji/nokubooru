import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nokubooru/State/download_manager.dart';
import 'package:nokubooru/State/notify.dart';
import 'package:nokubooru/State/searcher.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/Widgets/General/menu_item.dart';
import 'package:nokubooru/Widgets/General/padded_widget.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';
import 'package:pasteboard/pasteboard.dart';

final RouteObserver<PageRoute> videoRouteObserver = RouteObserver<PageRoute>();

class PostMedia extends StatelessWidget {
    final Post post;
    final PostFile file;
    final VoidCallback? onTap;

    const PostMedia({required this.file, required this.post, this.onTap, super.key});

    @override
    Widget build(BuildContext context) => Builder(
            builder: (context) {
                if (post.isVideo) {
                    return Container(
                        decoration: const BoxDecoration(
                            boxShadow: [
                                BoxShadow(
                                    offset: Offset(4.0, 4.0),
                                    blurRadius: 32.0
                                )
                            ]
                        ),
                        child: PostVideo(
                            file: file, 
                            post: post
                        )
                    );
                }
        
                return Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                        onTap: onTap,
                        child: PostImageContainer(
                            key: ValueKey(file),
                            file: file, 
                            post: post
                        ),
                    )
                );
            }
        );
}

class PostImageContainer extends StatefulWidget {
    final PostFile file;
    final Post post;

    const PostImageContainer({required this.file, required this.post, super.key});

    @override
    State<PostImageContainer> createState() => _PostImageContainerState();
}

class _PostImageContainerState extends State<PostImageContainer> {
    List<Note> notes = [];
    Note? selectedNote;

    @override
    void initState() {
        super.initState();

        Searcher.postGetNotes(widget.post).then((notes) {
            this.notes = notes;
            if (mounted) {
                setState((){});
            }
        });
    }

    @override
    void didUpdateWidget(covariant PostImageContainer oldWidget) {
        super.didUpdateWidget(oldWidget);

        if (oldWidget.file != widget.file) {
            setState(() {
                
            });
        }
    }

    @override
    Widget build(BuildContext context) => LayoutBuilder(
            builder: (context, constraints) {
                final dimensions = widget.file.dimensions;
                final scale = (constraints.maxHeight.isFinite) ? constraints.maxHeight / dimensions.y : constraints.maxWidth / dimensions.x;
                final image = PostImage(
                    key: ValueKey(widget.file),
                    file: widget.file
                );

                if (widget.file.data == null) {
                    DownloadManager.fetch(widget.file).then((_) {
                        if (mounted) {
                            setState((){});
                        }
                    });
                    return image;
                }

                return Stack(
                    clipBehavior: Clip.none,
                    children: [
                        image,
                        for (final note in notes) Positioned(
                            top: note.y * scale,
                            left: note.x * scale,
                            child: SizedBox(
                                width: (note.width * scale),//.clamp(0.1, note.width * scale),
                                height: (note.height * scale),//.clamp(0.1, note.height * scale),
                                child: Material(
                                    borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                                    color: Colors.black.withAlpha(128),
                                    child: InkWell(
                                        onTap: () {
                                            setState(() {
                                                selectedNote = (selectedNote?.noteID == note.noteID) ? null : note;
                                            });
                                        },
                                        child: const SizedBox.shrink(),
                                    ),
                                )
                            )
                        ),
                        if (selectedNote != null) Positioned(
                            left: (selectedNote!.x * scale).clamp(0, constraints.maxWidth - 128),
                            top: (selectedNote!.y * scale + selectedNote!.height * scale).clamp(0, (constraints.maxHeight.isInfinite) ? ((dimensions.y * scale) - 128) : (constraints.maxHeight - 128)),
                            child: IgnorePointer(
                                child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        minWidth: 64,
                                        minHeight: 64,
                                        maxWidth: 128,
                                        maxHeight: ((dimensions.y * scale) - (selectedNote!.y * scale)).clamp(64, 256)
                                    ),
                                    child: Material(
                                        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                                        color: Colors.black.withAlpha(128),
                                        child: PaddedWidget(
                                            child: SingleChildScrollView(
                                                child: MarkdownBody(data: selectedNote!.bodyToMarkdown()),
                                            ),
                                        ),
                                    ),
                                ),
                            ),
                        )
                    ],
                );
            },
        );
}

class PostNote extends StatefulWidget {
    final Note note;

    const PostNote({required this.note, super.key});

    @override
    State<PostNote> createState() => _PostNoteState();
}

class _PostNoteState extends State<PostNote> {
    bool isVisible = false;

    @override
    void initState() {
        super.initState();
    }

    @override
    Widget build(BuildContext context) => Material(
            color: Colors.black.withAlpha(128),
            child: InkWell(
                onTap: () {},
                child: const SizedBox.shrink(),
            ),
        );
}

class PostImage extends StatefulWidget {
    final PostFile file;
    final bool visible;

    const PostImage({required this.file, this.visible = true, super.key});

    @override
    State<PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<PostImage> {
    Future? gifFuture;
    bool inProgress = false;

    void convertIfGif() {
        if (gifFuture != null || widget.file.type != PostFileType.zip) return;

        inProgress = true;

        gifFuture = widget.file.convertZipToGIF(replace: true, frameRate: 30)..then((_) {
            inProgress = false;
            if (mounted) {
                setState((){});
            }
        });
    }

    @override
    Widget build(BuildContext context) {
        if ((widget.file.completed || widget.file.data != null) && (!inProgress)) {
            if (widget.file.type != PostFileType.zip || (widget.file.type == PostFileType.zip && (gifFuture != null || widget.file.converted))) {
                return ImageShadow(
                    key: ValueKey(widget.file),
                    file: widget.file,
                    visible: widget.visible,
                );
            } else {
                convertIfGif();
            }
        } else {
            DownloadManager.fetch(widget.file);
        }

        if (widget.file.type == PostFileType.zip && inProgress) {
            return const Center(
                child: CircularProgressIndicator(),
            );
        }

        return StreamBuilder(
            stream: widget.file.stream, 
            builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                    if (widget.file.data == null) {
                        return Center(
                            child: PostImageError(
                                onTap: () {
                                    setState(() {
                                        DownloadManager.dispose(widget.file);
                                        DownloadManager.fetch(widget.file);
                                    });
                                }
                            ),
                        );
                    }

                    if (widget.file.type == PostFileType.zip && inProgress) {
                        return const Center(
                            child: CircularProgressIndicator(),
                        );
                    }

                    return ImageShadow(
                        key: ValueKey(widget.file),
                        file: widget.file,
                        visible: widget.visible,
                    );
                }

                return Center(
                    child: PostFileProgressIndicator(file: widget.file),
                );
            },
        );
    }
}

class ImageShadow extends StatelessWidget {
    final PostFile file;
    final bool visible;

    const ImageShadow({required this.file, this.visible = true, super.key});

    @override
    Widget build(BuildContext context) => ContextMenuRegion(
            contextMenu: ContextMenu(
                padding: const EdgeInsets.all(8.0),
                entries: [
                    NokuMenuItem(
                        onSelected: () async {
                            DownloadManager.downloadFile(file);

                            final record = DownloadManager.history.last;

                            record.process!.stream.listen((data) {
                                switch (data.status) {
                                    case DownloadProcessStatus.completed:
                                        Notify.showMessage(
                                            title: "Download Finished!",
                                            message: "Image \"${file.filename}\" has been ${(isDesktop) ? "downloaded" : "stored in your gallery"}!",
                                            icon: const Icon(Icons.download_done)
                                        );
                                        break;
                                    default: break;
                                }
                            });
                        },
                        label: "Download",
                        icon: Icons.download
                    ),
                    NokuMenuItem(
                        onSelected: () async {
                            try {
                                if (!isDesktop) {
                                    await Pasteboard.writeImage(file.data);
                                } else {
                                    final temp = File("${Directory.systemTemp.path}/${file.filename}")..writeAsBytesSync(file.data!);
                                    await Pasteboard.writeFiles([
                                        temp.path
                                    ]);
                                    temp.deleteSync();
                                }

                                Notify.showMessage(
                                    title: "Copied to Clipboard!",
                                    message: "Image \"${file.filename}\" has been copied to your clipboard!",
                                    icon: const Icon(Icons.download_done)
                                );
                            } catch (e, stackTrace) {
                                Nokulog.e("Failed to copy image to clipboard.", error: e, stackTrace: stackTrace);
                                Notify.showMessage(
                                    title: "Clipboard Error",
                                    message: "An unexpected error occurred whilst trying to copy the image to the clipboard.",
                                    icon: const Icon(Icons.error)
                                );
                            }
                        },
                        label: "Copy Image",
                        icon: FontAwesomeIcons.clipboard
                    ),
                    NokuMenuItem(
                        onSelected: () {
                            Settings.backgroundImage = file.data;
                        },
                        label: "Set as background",
                        icon: Icons.wallpaper
                    )
                ]
            ),
            child: Container(
                decoration: (visible) ? const BoxDecoration(
                    boxShadow: [
                        BoxShadow(
                            offset: Offset(4.0, 4.0),
                            blurRadius: 32.0
                        )
                    ]
                ) : null,
                child: Image.memory(
                    file.data!, 
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                        Nokulog.e("Error occurred whilst loading image.", error: error, stackTrace: stackTrace);

                        return Card(
                            child: Center(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Icon(
                                            Icons.error,
                                            color: Themes.accent,
                                        ),
                                        const SizedBox(height: 8.0),
                                        Text(
                                            "Failed to load image!",
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold
                                            ),
                                        ),
                                        Text(error.toString())
                                    ],
                                ),
                            ),
                        );
                    },
                ),
            ),
        );
}

class PostImageError extends StatelessWidget {
    final VoidCallback? onTap;

    const PostImageError({required this.onTap, super.key});

    @override
    Widget build(BuildContext context) => InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(16.0)),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    const Icon(Icons.error),
                    Text.rich(
                        textAlign: TextAlign.center,
                        TextSpan(
                            children: [
                                TextSpan(
                                    text: "${languageText("app_image_load_failed")}\n",
                                    style: TextStyle(
                                        color: Themes.accent,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold
                                    )
                                ),
                                TextSpan(
                                    text: languageText("app_image_retry"),
                                    style: TextStyle(
                                        color: Theme.of(context).secondaryHeaderColor
                                    )
                                )
                            ]
                        )
                    )
                ],
            ),
        );
}

class PostFileProgressIndicator extends StatelessWidget {
    final PostFile file;

    const PostFileProgressIndicator({required this.file, super.key});

    @override
    Widget build(BuildContext context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 4.0,
            children: [
                CircularProgressIndicator(
                    value: (file.progress == 0) ? null : file.progress,
                ),
                Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                        children: [
                            TextSpan(
                                text: "${file.progressPercentage}%\n",
                                style: TextStyle(
                                    color: Themes.accent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold
                                )
                            ),
                            TextSpan(
                                text: "${file.receivedLength} / ${file.contentLength} bytes.",
                                style: TextStyle(
                                    color: Theme.of(context).secondaryHeaderColor
                                )
                            )
                        ]
                    )
                )
            ],
        );
}

class PostVideo extends StatefulWidget {
    final PostFile file;
    final Post post;

    const PostVideo({required this.file, required this.post, super.key});

    @override
    State<PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends State<PostVideo> with RouteAware {
    final Player player = Player();
    late final VideoController controller;
    
    Future? loading;

    @override
    void initState() {
        super.initState();

        controller = VideoController(
            player,
        );

        player.open(Playlist([Media(widget.file.url, httpHeaders: widget.file.headers)]));
        player.setPlaylistMode(PlaylistMode.single);
    }

    @override
    void didChangeDependencies() {
        super.didChangeDependencies();

        final route = ModalRoute.of(context);

        if (route is PageRoute) {
            videoRouteObserver.subscribe(this, route);
        }
    }

    @override
    void dispose() {
        videoRouteObserver.unsubscribe(this);
        player.dispose();

        super.dispose();
    }

    @override
    void didPushNext() {
        player.pause();
    }

    @override
    Widget build(BuildContext context) {
        final aspectRatio = widget.file.dimensions.x / widget.file.dimensions.y;

        return Video(
            aspectRatio: aspectRatio,
            controller: controller,
        );
    }
}