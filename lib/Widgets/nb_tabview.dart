import 'package:flutter/material.dart';
import 'package:nokubooru/Pages/downloads_page.dart';
import 'package:nokubooru/Pages/favorites_page.dart';
import 'package:nokubooru/Pages/history_page.dart';
import 'package:nokubooru/Pages/home_page.dart';
import 'package:nokubooru/Pages/post_page.dart';
import 'package:nokubooru/Pages/search_page.dart';
import 'package:nokubooru/Pages/settings_page.dart';
import 'package:nokubooru/Pages/viewer_page.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/view_data.dart';

class NBTabView extends StatefulWidget {
    final ViewData data;

    const NBTabView({super.key, required this.data});

    @override
    State<NBTabView> createState() => _NBTabViewState();
}

class _NBTabViewState extends State<NBTabView> {
    Widget? currentWidget;
    TabData? previousTab;

    @override
    void initState() {
        super.initState();

        previousTab = widget.data.tab;
    }

    @override
    Widget build(BuildContext context) {
        Widget defaultWidget = const Placeholder();

        switch (widget.data.type) {
            case ViewType.search:
                defaultWidget = TabViewSearch(
                    key: ValueKey(widget.data),
                    data: widget.data as ViewSearch
                );
            case ViewType.post:
                defaultWidget = TabViewPost(
                    key: ValueKey(widget.data),
                    data: widget.data as ViewPost
                );
            case ViewType.viewer:
                defaultWidget = TabViewViewer(
                    key: ValueKey(widget.data),
                    data: widget.data as ViewViewer
                );
            case ViewType.history:
                defaultWidget = TabViewHistory(
                    key: ValueKey(widget.data),
                    data: widget.data as ViewHistory
                );
            case ViewType.favorites:
                defaultWidget = TabViewFavorites(
                    key: ValueKey(widget.data),
                    data: widget.data as ViewFavorites
                );
            case ViewType.downloads:
                defaultWidget = TabViewDownloads(
                    key: ValueKey(widget.data),
                    data: widget.data as ViewDownloads,
                );
            case ViewType.settings:
                defaultWidget = TabViewSettings(
                    key: ValueKey(widget.data),
                    data: widget.data as ViewSettings
                );
            case ViewType.home:
                defaultWidget = TabViewHome(
                    key: ValueKey(widget.data),
                    home: widget.data as ViewHome
                );
            default:
                break;
        }

        //return defaultWidget;

        /*if ((currentWidget is TabViewPost && defaultWidget is TabViewViewer)
            || (currentWidget is TabViewViewer && defaultWidget is TabViewPost)) {
            if (previousTab == widget.data.tab) {
                currentWidget = defaultWidget;
                return defaultWidget;
            }
        }*/

        currentWidget = defaultWidget;
        previousTab = widget.data.tab;

        return AnimatedSwitcher(
            key: const ValueKey("tabViewCreator"),
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0.0, 0.1),
                        end: Offset.zero,
                    ).animate(animation),
                    child: ScaleTransition(
                        scale: Tween<double>(
                            begin: 1.1,
                            end: 1.0
                        ).animate(animation),
                        child: FadeTransition(
                            opacity: animation,
                            child: child,
                        ),
                    ),
                ),
            child: ValueListenableBuilder(
                valueListenable: widget.data.tab!.lockForFuture,
                builder: (context, value, child) => IgnorePointer(
                        ignoring: value,
                        child: Stack(
                            children: [
                                child!,
                                if (value) Container(
                                    constraints: BoxConstraints.tight(
                                        MediaQuery.sizeOf(context)
                                    ),
                                    decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(128)
                                    ),
                                    child: const Center(child: CircularProgressIndicator()),
                                )
                            ],
                        )
                    ),
                child: defaultWidget
            ),
        );
    }
}

class FutureWidget extends StatelessWidget {
    final Future future;
    final Widget child;
    final bool Function() condition;

    const FutureWidget({required this.future, required this.child, required this.condition, super.key});

    @override
    Widget build(BuildContext context) {
        if (condition()) return child;

        return FutureBuilder(
            future: future, 
            builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                    return child;
                }

                return const Center(child: CircularProgressIndicator());
            },
        );
    }
}

