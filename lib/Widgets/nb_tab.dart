import 'package:flutter/material.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/custom_tooltip.dart';
import 'package:nokubooru/Widgets/General/rounded_box_button.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';

class NBTabWidget extends StatefulWidget {
    final TabData tabData;

    final VoidCallback? onTap;
    final void Function(bool entered)? onHover;

    const NBTabWidget({required this.tabData, this.onTap, this.onHover, super.key});

    @override
    State<NBTabWidget> createState() => _NBTabWidgetState();
}

class _NBTabWidgetState extends State<NBTabWidget> {
    bool closeButtonVisible = false;
    //bool _isLoading = false;

    @override
    void initState() {
        super.initState();

        registerSubscription();

        widget.tabData.manager.onActiveChange((_) {
            registerSubscription();
        });
    }

    void registerSubscription() {
        widget.tabData.onUpdate(() {
            if (mounted) {
                setState(() {
                    
                });
            }
        }, key: widget.hashCode);
    }

    @override
    void didUpdateWidget(covariant NBTabWidget oldWidget) {
        super.didUpdateWidget(oldWidget);
    }

    @override
    Widget build(BuildContext context) {
        final bool isActiveTab = widget.tabData.manager.isActiveTab(widget.tabData);
        final Widget? tabWidget = widget.tabData.current.favicon;
        final ImageProvider? faviconImage = (tabWidget != null && tabWidget is Image) ? tabWidget.image : null;
        final Color tabColor = (isActiveTab) ? Themes.accent : Theme.of(context).cardColor;

        return CustomTooltip(
            waitDuration: const Duration(milliseconds: 500),
            tooltip: Align(
                alignment: Alignment.topCenter,
                child: Container(
                    padding: const EdgeInsets.all(8.0),
                    constraints: const BoxConstraints(
                        minWidth: 64,
                        maxWidth: 256
                    ),
                    decoration: BoxDecoration(
                        image: (faviconImage != null) ? DecorationImage(
                            image: faviconImage, 
                            fit: BoxFit.cover,
                            opacity: 0.45,
                            alignment: imageAlignment,
                            onError: (exception, stackTrace) {},
                        ) : null,
                        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                        color: Theme.of(context).cardColor,
                        boxShadow: const [
                            BoxShadow(
                                offset: Offset(4.0, 4.0),
                                blurRadius: 32.0
                            )
                        ]
                    ),
                    child: Text.rich(
                        TextSpan(
                            style: TextStyle(
                                color: getTextColor(Theme.of(context).cardColor),
                                shadows: const [
                                    Shadow(
                                        offset: Offset(2.0, 2.0),
                                        blurRadius: 8.0
                                    )
                                ]
                            ),
                            children: [
                                TextSpan(
                                    text: widget.tabData.current.title,
                                    style: const TextStyle(fontSize: 16.0)
                                ),
                                if (widget.tabData.current.type == ViewType.post) TextSpan(
                                    children: [
                                        const TextSpan(text: "\n"),
                                        if ((widget.tabData.current as ViewPost).post.authors.isNotEmpty) TextSpan(
                                            text: "${languageText("app_original_by", [(widget.tabData.current as ViewPost).post.authors.join(', ')])} | "
                                        ),
                                        TextSpan(
                                            text: "${(widget.tabData.current as ViewPost).post.dimensions.first}"
                                        )
                                    ],
                                    style: const TextStyle(
                                        fontSize: 12.0,
                                        color: Colors.white70
                                    )
                                )
                            ]
                        )
                    ),
                ),
            ),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                //padding: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8.0),
                        topRight: Radius.circular(8.0)
                    ),
                    border: (!isActiveTab) ? Border.all(
                        color: Themes.accent
                    ) : null,
                    color: tabColor
                ),
                child: Material(
                    type: MaterialType.transparency,
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8.0),
                            topRight: Radius.circular(8.0)
                        ),
                        onTap: widget.onTap,
                        onHover: (entered) {
                            if (widget.onHover != null) {
                                widget.onHover!(entered);
                            }
            
                            closeButtonVisible = entered;
                            setState((){});
                        },
                        hoverColor: (isActiveTab) ? Theme.of(context).cardColor.withAlpha(128) : Theme.of(context).highlightColor,
                        child: GestureDetector(
                            onTertiaryTapUp: (_) {
                                final tab = widget.tabData.manager.duplicateTab(widget.tabData);
                                widget.tabData.manager.setTabAsActive(tab);
                            },
                            child: Padding(
                                padding: const EdgeInsets.only(right: 6.0, left: 2.0, top: 2.0, bottom: 2.0),
                                child: Stack(
                                    alignment: Alignment.centerLeft,
                                    fit: StackFit.passthrough,
                                    children: [
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                                CircleAvatar(
                                                    backgroundImage: (faviconImage != null) ? Image(
                                                        image: faviconImage,
                                                        alignment: imageAlignment,
                                                    ).image : null,
                                                    backgroundColor: Colors.transparent,
                                                    child: (tabWidget is! Image) ? Icon(
                                                        Icons.search, 
                                                        size: 21.0,
                                                        color: getTextColor(tabColor),
                                                    ) : null,
                                                ),
                                                Expanded(
                                                    child: Text(
                                                        widget.tabData.current.title,
                                                        overflow: TextOverflow.fade,
                                                        softWrap: false,
                                                        style: TextStyle(
                                                            color: getTextColor(tabColor),
                                                            fontWeight: FontWeight.w300
                                                        ),
                                                    ),
                                                ),
                                            ] 
                                        ),
                                        Opacity(
                                            opacity: (closeButtonVisible) ? 1 : 0,
                                            child: Align(
                                                alignment: Alignment.centerRight,
                                                child: RoundedBoxButton(
                                                    icon: const Icon(
                                                        Icons.close,
                                                        shadows: [
                                                            Shadow(
                                                                //offset: Offset(1.0, 1.0),
                                                                color: Colors.black45,
                                                                blurRadius: 3.0
                                                            )
                                                        ],
                                                    ),
                                                    backgroundColor: Colors.black.withAlpha(128),
                                                    onTap: () {
                                                        widget.tabData.manager.removeTab(widget.tabData);
                                                    },
                                                ),
                                            ),
                                        )
                                    ],
                                ),
                            ),
                        ),
                    ),
                ),
            ),
        );
    }
}

