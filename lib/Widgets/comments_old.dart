import 'package:flutter/widgets.dart';
import 'package:nokubooru/State/searcher.dart';
import 'package:nokufind/nokufind.dart';

class CommentsOrig extends StatefulWidget {
    final Post post;
    final Widget child;

    const CommentsOrig({required this.post, required this.child, super.key});

    @override
    State<CommentsOrig> createState() => _CommentsOrigState();
}

class _CommentsOrigState extends State<CommentsOrig> {
    List<Comment> comments = [];
    ScrollController controller = ScrollController();

    @override
    void initState() {
        super.initState();

        Searcher.postGetComments(widget.post).then(
            (comments) {
                this.comments = comments;
                if (mounted) {
                    setState((){});
                }
            }
        );
    }

    @override
    Widget build(BuildContext context) {
        if (comments.isEmpty) return widget.child;
        
        return ListView(
            controller: controller,
            children: [
                ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: (controller.hasClients) ? controller.position.viewportDimension : MediaQuery.sizeOf(context).height
                    ),
                    child: widget.child,
                ),
                //for (var comment in comments) CommentWidget(
                //    comment: comment, 
                //    post: widget.post
                //)
            ],  
        );
    }
}