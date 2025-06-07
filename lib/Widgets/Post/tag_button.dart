import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:nokubooru/State/searcher.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/tags.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/menu_item.dart';
import 'package:nokubooru/Widgets/General/padded_widget.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';

class TagButton extends StatefulWidget {
    final Tag tag;
    final TabData tabData;
    
    const TagButton({required this.tag, required this.tabData, super.key});

    @override
    State<TagButton> createState() => _TagButtonState();
}

class _TagButtonState extends State<TagButton> {
    @override
    Widget build(BuildContext context) {
        Widget tagButton;

        final bool tagIsFavorite = Tags.isFavorite(widget.tag);
        final bool tagIsBlacklisted = Settings.blacklist.value.contains(widget.tag.original);

        if (tagIsFavorite) {
            tagButton = FavoriteTagButton(tabData: widget.tabData, tag: widget.tag);
        } else if (tagIsBlacklisted) {
            tagButton = BlacklistedTagButton(tabData: widget.tabData, tag: widget.tag);
        } else {
            switch(widget.tag.type) {
                case TagType.artist:
                    tagButton = ArtistTagButton(tabData: widget.tabData, tag: widget.tag);
                    break;
                case TagType.character:
                    tagButton = CharacterTagButton(tabData: widget.tabData, tag: widget.tag);
                    break;
                case TagType.series:
                    tagButton = SeriesTagButton(tabData: widget.tabData, tag: widget.tag);
                    break;
                default:
                    tagButton = DefaultTagButton(tabData: widget.tabData, tag: widget.tag);
                    break;
            }
        }

        return ContextMenuRegion(
            contextMenu: ContextMenu(
                padding: const EdgeInsets.all(8.0),
                entries: <ContextMenuEntry>[
                    MenuHeader(text: widget.tag.original),
                    if (!tagIsBlacklisted) NokuMenuItem(
                        onSelected: () {
                            if (tagIsFavorite) {
                                setState(() {
                                    Tags.removeFromFavorites(widget.tag);
                                });
                                return;
                            }

                            setState((){
                                Tags.addToFavorites(widget.tag);
                            });
                        },
                        label: languageText((tagIsFavorite) ? "app_tag_unfavorite" : "app_tag_favorite"),
                        icon: Icons.star
                    ),
                    NokuMenuItem(
                        onSelected: () {
                            if (!tagIsBlacklisted) {
                                setState(() {
                                    Settings.blacklist.value.add(widget.tag.original);
                                    Settings.save();
                                    if (tagIsFavorite) {
                                        Tags.removeFromFavorites(widget.tag);
                                    }            
                                });
                                return;
                            }

                            setState((){
                                Settings.blacklist.value.remove(widget.tag.original);
                                Settings.save();
                            });
                        },
                        label: languageText((tagIsBlacklisted) ? "app_tag_unblacklist" : "app_tag_blacklist"),
                        icon: Icons.remove_circle
                    ),
                    NokuMenuItem(
                        onSelected: () {
                            final tab = widget.tabData.manager.createNew(
                                view: ViewSearch(
                                    searchFuture: Searcher.searchPostsActive(
                                        widget.tag.original
                                    ),
                                    query: widget.tag.original,
                                ),
                                notify: true,
                                after: widget.tabData
                            );
                            
                            if (!isDesktop) {
                                widget.tabData.manager.setTabAsActive(tab);
                            }
                        },
                        label: languageText("app_open_on_new_tab"),
                        icon: Icons.open_in_new
                    ),
                    NokuMenuItem(
                        onSelected: () {
                            Clipboard.setData(ClipboardData(text: widget.tag.original));
                        },
                        label: languageText("app_tag_copy"),
                        icon: Icons.copy
                    ),
                ]
            ), 
            child: PaddedWidget(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: GestureDetector(
                    onTertiaryTapUp: (_) {
                        final tab = widget.tabData.manager.createNew(
                            view: ViewSearch(
                                searchFuture: Searcher.searchPostsActive(
                                    widget.tag.original
                                ),
                                query: widget.tag.original
                            ),
                            notify: true,
                            after: widget.tabData
                        );
                        
                        if (!isDesktop) {
                            widget.tabData.manager.setTabAsActive(tab);
                        }
                    },
                    child: tagButton
                )
            )
        );
    }
}

class ArtistTagButton extends StatelessWidget {
    final TabData tabData;
    final Tag tag;

    const ArtistTagButton({required this.tag, required this.tabData, super.key});

    @override
    Widget build(BuildContext context) {
        final contrastColor = getTextColor(Colors.redAccent);

        return FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: contrastColor,
                iconColor: contrastColor
            ),
            onPressed: () {
                tabData.searchBarInput.text = tag.original;
                tabData.search(tag.original);
            }, 
            label: Text.rich(
                TextSpan(
                    //style: TextStyle(color: Themes.accent),
                    children: [
                        TextSpan(text: tag.original),
                        if (tag.translated.isNotEmpty) TextSpan(
                            text: " (${tag.translated})",
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 11
                            )
                        )
                    ]
                ),
            ),
            icon: const Icon(Icons.palette),
        );
    }
}

class CharacterTagButton extends StatelessWidget {
    final TabData tabData;
    final Tag tag;

    const CharacterTagButton({required this.tag, required this.tabData, super.key});

    @override
    Widget build(BuildContext context) {
        final contrastColor = getTextColor(Colors.lightGreenAccent);

        return FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.lightGreenAccent,
                foregroundColor: contrastColor,
                iconColor: contrastColor
            ),
            onPressed: () {
                tabData.searchBarInput.text = tag.original;
                tabData.search(tag.original);
            }, 
            label: Text.rich(
                TextSpan(
                    //style: TextStyle(color: Themes.accent),
                    children: [
                        TextSpan(text: tag.original),
                        if (tag.translated.isNotEmpty) TextSpan(
                            text: " (${tag.translated})",
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 11
                            )
                        )
                    ]
                ),
            ),
            icon: const Icon(Icons.person),
        );
    }
}

class SeriesTagButton extends StatelessWidget {
    final TabData tabData;
    final Tag tag;

    const SeriesTagButton({required this.tag, required this.tabData, super.key});

    @override
    Widget build(BuildContext context) {
        final contrastColor = getTextColor(Colors.purpleAccent);

        return FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: contrastColor,
                iconColor: contrastColor
            ),
            onPressed: () {
                tabData.searchBarInput.text = tag.original;
                tabData.search(tag.original);
            }, 
            label: Text.rich(
                TextSpan(
                    //style: TextStyle(color: Themes.accent),
                    children: [
                        TextSpan(text: tag.original),
                        if (tag.translated.isNotEmpty) TextSpan(
                            text: " (${tag.translated})",
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 11
                            )
                        )
                    ]
                ),
            ),
            icon: const Icon(Icons.tv),
        );
    }
}

class FavoriteTagButton extends StatelessWidget {
    final TabData tabData;
    final Tag tag;

    const FavoriteTagButton({required this.tag, required this.tabData, super.key});

    @override
    Widget build(BuildContext context) {
        final contrastColor = getTextColor(Colors.amberAccent);

        return FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: contrastColor,
                iconColor: contrastColor
            ),
            onPressed: () {
                tabData.searchBarInput.text = tag.original;
                tabData.search(tag.original);
            }, 
            label: Text.rich(
                TextSpan(
                    //style: TextStyle(color: Themes.accent),
                    children: [
                        TextSpan(text: tag.original),
                        if (tag.translated.isNotEmpty) TextSpan(
                            text: " (${tag.translated})",
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 11
                            )
                        )
                    ]
                ),
            ),
            icon: const Icon(Icons.star),
        );
    }
}

class BlacklistedTagButton extends StatelessWidget {
    final TabData tabData;
    final Tag tag;

    const BlacklistedTagButton({required this.tag, required this.tabData, super.key});

    @override
    Widget build(BuildContext context) {
        final contrastColor = getTextColor(Themes.errorBackground);

        return FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Themes.errorBackground,
                foregroundColor: contrastColor,
                iconColor: contrastColor
            ),
            onPressed: () {
                tabData.searchBarInput.text = tag.original;
                tabData.search(tag.original);
            }, 
            label: Text.rich(
                TextSpan(
                    //style: TextStyle(color: Themes.accent),
                    children: [
                        TextSpan(text: tag.original),
                        if (tag.translated.isNotEmpty) TextSpan(
                            text: " (${tag.translated})",
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 11
                            )
                        )
                    ]
                ),
            ),
            icon: const Icon(Icons.disabled_by_default),
        );
    }
}

class DefaultTagButton extends StatelessWidget {
    final TabData tabData;
    final Tag tag;

    const DefaultTagButton({required this.tabData, required this.tag, super.key,});

    @override
    Widget build(BuildContext context) => OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                side: BorderSide(
                    width: 2.0,
                    color: Themes.accent
                )
            ),
            onPressed: () {
                tabData.searchBarInput.text = tag.original;
                tabData.search(tag.original);
            }, 
            label: Text.rich(
                TextSpan(
                    style: TextStyle(color: Themes.accent),
                    children: [
                        TextSpan(text: tag.original),
                        if (tag.translated.isNotEmpty) TextSpan(
                            text: " (${tag.translated})",
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 11
                            )
                        )
                    ]
                ),
            ),
            icon: Icon(Icons.tag, color: Themes.accent),
        );
}