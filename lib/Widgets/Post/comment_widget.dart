import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nokubooru/Widgets/General/padded_widget.dart';
import 'package:nokufind/nokufind.dart';
import 'package:url_launcher/url_launcher.dart';

class CommentWidget extends StatelessWidget {
    final Comment comment;
    final Post post;

    const CommentWidget({required this.comment, required this.post, super.key});

    @override
    Widget build(BuildContext context) {
        final Widget? userAvatar = (comment.creatorAvatar != null) ? Image.network(
            comment.creatorAvatar as String, 
            headers: post.headers,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) => ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 64, maxHeight: 64),
                    child: child,
                ),
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
        ) : null;

        return PaddedWidget(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: SelectionArea(
                child: ListTile(
                    leading: userAvatar,
                    title: MarkdownBody(
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                        data: "**${comment.creator}** *(#${comment.creatorID})*",
                    ),
                    subtitle: MarkdownBody(
                        data: "*${comment.createdDatetime.toString()}*\n\n${comment.bodyToMarkdown()}",
                        onTapLink: (text, href, title) {
                            if (href == null) return;
                            
                            launchUrl(Uri.parse(href));     
                        },
                    ),
                ),
            )
        );
    }
}