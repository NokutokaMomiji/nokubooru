import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/Widgets/General/post_card.dart';
import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';

class PostGrid extends StatefulWidget {
    final List<Post> posts;
    final TabData data;
    final bool asSliver;
    final PageStorageKey<String>? scrollKey;

    const PostGrid({super.key, required this.posts, this.asSliver = false, required this.data, this.scrollKey});

    @override
    State<PostGrid> createState() => _PostGridState();
}

class _PostGridState extends State<PostGrid> {
    List<Widget> postCards = [];
    late ScrollController controller;

    @override
    void initState() {
        super.initState();

        controller = ScrollController();
        postCards = widget.posts.map(cardGenerator).toList();
    }

    @override
    void didUpdateWidget(covariant PostGrid oldWidget) {
        super.didUpdateWidget(oldWidget);

        if (oldWidget.posts != widget.posts) {
            //Nokulog.i("first: ${oldWidget.posts.first.identifier}   second: ${widget.posts.first.identifier}");
            postCards = widget.posts.map(cardGenerator).toList();
        }
    }

    @override
    void dispose() {
        controller.dispose();
        super.dispose();
    }

    Widget cardGenerator(Post element) {
        const Duration duration = Duration(milliseconds: 500);
        const Cubic curve = Curves.easeInOut;

        return PostCard(
            key: ValueKey(element),
            post: element, 
            data: widget.data
        ).animate(
            delay: const Duration(milliseconds: 100)
        ).move(begin: const Offset(32, 0), duration: duration, curve: curve)
        .scale(begin: const Offset(0.5, 0.5), duration: duration, curve: curve)
        .fadeIn(begin: 0, duration: duration, curve: curve);
    }

    @override
    Widget build(BuildContext context) {
        if (widget.asSliver) {
            return SliverGrid.builder(
                key: widget.scrollKey ?? PageStorageKey<String>("gridController${widget.posts.hashCode}"),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 128),
                itemCount: widget.posts.length, 
                itemBuilder: (context, index) => postCards[index],
            );
        }

        return DynMouseScroll(
            builder: (context, controller, physics) => GridView.builder(
                    key: widget.scrollKey ?? PageStorageKey<String>("gridController${widget.posts.hashCode}"),
                    controller: controller,
                    physics: physics,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 128),
                    itemCount: widget.posts.length,
                    itemBuilder: (context, index) => postCards[index],
                )
        );
    }
}