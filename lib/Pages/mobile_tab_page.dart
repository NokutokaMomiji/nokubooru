import 'package:flutter/material.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/tab_manager.dart';
import 'package:nokubooru/Widgets/General/padded_widget.dart';
import 'package:nokubooru/Widgets/General/rounded_box_button.dart';
import 'package:nokubooru/themes.dart';
import 'package:positioned_scroll_observer/positioned_scroll_observer.dart';

class MobileTabPage extends StatefulWidget {
    final TabManager manager;

    const MobileTabPage({required this.manager, super.key});

    @override
    State<MobileTabPage> createState() => _MobileTabPageState();
}

class _MobileTabPageState extends State<MobileTabPage> {
    final key = GlobalKey<AnimatedGridState>();
    final controller = ScrollController();

    var observer = ScrollObserver.sliverMulti();

    @override
    void initState() {
        super.initState();

        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            observer.jumpToIndex(widget.manager.tabs.indexOf(widget.manager.active), position: controller.position);
        });
    }

    @override
    Widget build(BuildContext context) {
        final tabs = widget.manager.tabs;
        DecorationImage? image;

        if (Settings.backgroundImage != null) {
            image = DecorationImage(
                image: Image.memory(Settings.backgroundImage!).image,
                fit: BoxFit.cover,
                opacity: 0.35
            );
        }
        
        return Scaffold(
            body: Container(
                decoration: BoxDecoration(
                    image: image,
                ),
                child: Stack(
                    children: [
                        Positioned.fill(
                            top: 50,
                            child: AnimatedGrid(
                                key: key,
                                controller: controller,
                                reverse: false,
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 256,
                                    childAspectRatio: 3/4
                                ),
                                initialItemCount: tabs.length, 
                                itemBuilder: (context, index, animation) {
                                    final newAnimation = CurvedAnimation(
                                        parent: animation, 
                                        curve: Curves.fastEaseInToSlowEaseOut
                                    );
                                    return ObserverProxy(
                                        observer: observer,
                                        child: ScaleTransition(
                                            scale: newAnimation,
                                            child: FadeTransition(
                                                opacity: newAnimation,
                                                child: PaddedWidget(
                                                    child: MobileTabCard(
                                                        onCloseTab: () {
                                                            final tab = tabs[index];
                                                
                                                            setState(() {
                                                                widget.manager.removeTab(tab);
                                                            });
                                                            
                                                            key.currentState?.removeItem(
                                                                index, 
                                                                (context, animation) {
                                                                    final newAnimation = CurvedAnimation(
                                                                        parent: animation, 
                                                                        curve: Curves.fastEaseInToSlowEaseOut
                                                                    );
                                        
                                                                    return ScaleTransition(
                                                                        scale: newAnimation,
                                                                        child: FadeTransition(
                                                                            opacity: newAnimation,
                                                                            child: PaddedWidget(
                                                                                child: MobileTabCard(
                                                                                    onCloseTab: null,
                                                                                    data: tabs[index]
                                                                                )
                                                                            ),
                                                                        ),
                                                                    );
                                                                },
                                                                duration: const Duration(milliseconds: 600)
                                                            );
                                                                            
                                                            //setState(() {});
                                                        },
                                                        data: tabs[index]
                                                    )
                                                ),
                                            ),
                                        ),
                                    );
                                },
                            ),
                        ),
                        Positioned(
                            top: 0,
                            left: 0,
                            width: MediaQuery.sizeOf(context).width,
                            child: SafeArea(
                                child: Container(
                                    constraints: const BoxConstraints(
                                        maxHeight: 128
                                    ),
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(8.0),
                                            bottomRight: Radius.circular(8.0)
                                        ),
                                        boxShadow: const [
                                            BoxShadow(
                                                offset: Offset(2.0, 2.0),
                                                blurRadius: 16.0
                                            )
                                        ],
                                        color: Theme.of(context).cardColor
                                    ),
                                    child: PaddedWidget(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                                IconButton(
                                                    onPressed: () {
                                                        final newTab = widget.manager.createNew();
                                
                                                        setState(() {
                                                            widget.manager.setTabAsActive(newTab);
                                                        });
                                
                                                        key.currentState?.insertItem(widget.manager.tabs.indexOf(newTab));
                                
                                                        Future.delayed(Duration.zero, () {
                                                            if (context.mounted) {
                                                                Navigator.of(context).pop();
                                                            }
                                                        });
                                                    },
                                                    icon: const Icon(Icons.add)
                                                ),
                                                const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                        RoundedBoxButton(
                                                            icon: Icon(Icons.grid_view),
                                                        )
                                                    ],
                                                ),
                                            ],
                                        )
                                    )
                                ),
                            ),
                        ),
                    ],
                )
            ),
        );
    }
}

class MobileTabCard extends StatelessWidget {
    final TabData data;
    final Function()? onCloseTab;
    const MobileTabCard({required this.data, required this.onCloseTab, super.key});

    @override
    Widget build(BuildContext context) {
        final manager = data.manager;
        final isActive = manager.isActiveTab(data);
        final icon = data.current.favicon;
        final thumb = data.thumb ?? data.current.thumb;
        final image = (thumb != null) ? Hero(
            tag: data,
            child: Image.memory(
                thumb, 
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
            ),
        ) : const Placeholder();

        return Material(
            borderRadius: const BorderRadius.all(Radius.circular(16.0)),
            color: (isActive) ? Themes.accent : Theme.of(context).cardColor,
            elevation: 8.0,
            child: InkWell(
                onTap: () {
                    manager.setTabAsActive(data);
                    Navigator.of(context).pop();
                },
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                child: PaddedWidget(
                    child: Column(
                        children: [
                            Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                        CircleAvatar(
                                            backgroundImage: (icon is Image) ? icon.image : null,
                                            backgroundColor: (icon is Image) ? Colors.transparent : null,
                                            radius: 13,
                                            child: (icon is! Image) ? SizedBox.fromSize(
                                                size: const Size.fromRadius(13),
                                                child: FittedBox(
                                                    child: icon
                                                ),
                                            ) : null,
                                        ),
                                        Expanded(
                                            child: Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
                                                child: Text(
                                                    data.current.title,
                                                    overflow: TextOverflow.fade,
                                                    softWrap: false,
                                                    style: const TextStyle(
                                                        fontSize: 13.0
                                                    ),
                                                ),
                                            ),
                                        ),
                                        RoundedBoxButton(
                                            onTap: onCloseTab,
                                            backgroundColor: Colors.transparent,
                                            icon: const Icon(Icons.close),
                                        )
                                    ],
                                ),
                            ),
                            Expanded(
                                child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(6.0),
                                        topRight: Radius.circular(6.0),
                                        bottomLeft: Radius.circular(12.0),
                                        bottomRight: Radius.circular(12.0)
                                    ),
                                    child: SizedBox.expand(
                                        child: image,
                                    ),
                                )
                            )
                        ],
                    ),
                ),
            ),
        );
    }
}