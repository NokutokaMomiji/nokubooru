import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/view_data.dart';
import 'package:nokubooru/Widgets/General/color_dots.dart';
import 'package:nokubooru/Widgets/General/custom_container.dart';
import 'package:nokubooru/Widgets/General/faded_divider.dart';
import 'package:nokubooru/Widgets/General/option_widgets.dart';
import 'package:nokubooru/Widgets/General/themed_widgets.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/utils.dart';

enum SettingsPageType {
    general,
    subfinder,
    tags,
    account
}

typedef SettingsPageOption = ({IconData data, String title, String subtitle, Widget widget});

Map<SettingsPageType, SettingsPageOption> _options = {
    SettingsPageType.general: (
        data: Icons.settings,
        title: languageText("app_settings_general"), 
        subtitle: languageText("app_settings_general_subtitle"),
        widget: const _GeneralSettings()
    ),
    SettingsPageType.subfinder: (
        data: Icons.search,
        title: languageText("app_settings_subfinder"), 
        subtitle: languageText("app_settings_subfinder_subtitle"),
        widget: const Placeholder()
    ),
    SettingsPageType.tags: (
        data: Icons.tag,
        title: languageText("app_settings_tags"), 
        subtitle: languageText("app_settings_tags_subtitle"),
        widget: const Placeholder()
    ),
    SettingsPageType.account: (
        data: Icons.person,
        title: languageText("app_settings_account"), 
        subtitle: languageText("app_settings_account_subtitle"),
        widget: const Placeholder()
    ),
};

SettingsPageType _type = SettingsPageType.general;

class TabViewSettings extends StatelessWidget {
    final ViewSettings data;

    const TabViewSettings({required this.data, super.key});

    @override
    Widget build(BuildContext context) {
        if (!isDesktop) {
            return _ViewSettingsMobile(
                data: data
            );
        }

        return _ViewSettingsDesktop(
            data: data
        );
    }
}

class _ViewSettingsDesktop extends StatefulWidget {
    final ViewSettings data;

    const _ViewSettingsDesktop({required this.data});

    @override
    State<_ViewSettingsDesktop> createState() => _ViewSettingsDesktopState();
}

class _ViewSettingsDesktopState extends State<_ViewSettingsDesktop> {
    @override
    Widget build(BuildContext context) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    CustomContainer(
                        constraints: const BoxConstraints(
                            maxWidth: 256
                        ),
                        child: Column(
                            spacing: 4.0,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _options.entries.map<Widget>(
                                (element) => SettingsOption(
                                    title: element.value.title,
                                    subtitle: element.value.subtitle, 
                                    icon: element.value.data,
                                    style: SettingsOptionStyle.chip,
                                    shrinkWrap: false,
                                    onTap: () {
                                        setState((){
                                            _type = element.key;
                                        });
                                    },
                                )
                            ).toList(),
                        )
                    ),
                    const FadedVerticalDivider(),
                    Expanded(
                        child: CustomContainer(
                            borderRadius: BorderRadius.circular(16.0),
                            padding: const EdgeInsets.all(8.0),
                            child: _options[_type]!.widget
                        )
                    )
                ],
            ),
        );
    }
}

class _ViewSettingsMobile extends StatefulWidget {
    final ViewSettings data;

    const _ViewSettingsMobile({required this.data});

    @override
    State<_ViewSettingsMobile> createState() => _ViewSettingsMobileState();
}

bool inTab = false;

class _ViewSettingsMobileState extends State<_ViewSettingsMobile> {
    @override
    Widget build(BuildContext context) {
        return CustomContainer(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 32.0,
                maxHeight: MediaQuery.sizeOf(context).height - 64.0
            ),
            borderRadius: BorderRadius.circular(16.0),
            padding: const EdgeInsets.all(8.0),
            child: IndexedStack(
                index: (inTab) ? _type.index : _options.length,
                children: [
                    ..._options.values.map(
                        (element) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                IconButton(
                                    style: IconButton.styleFrom(
                                        backgroundColor: Theme.of(context).cardColor.withAlpha(128),
                                        elevation: 8.0
                                    ),
                                    onPressed: () {
                                        setState(() {
                                            inTab = false;
                                        });
                                    },
                                    icon: const Icon(
                                        Icons.chevron_left,
                                    )
                                ),
                                Expanded(child: element.widget),
                            ]
                        )
                    ),
                    Column(
                        spacing: 4.0,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _options.entries.map<Widget>(
                            (element) => SettingsOption(
                                title: element.value.title,
                                subtitle: element.value.subtitle, 
                                icon: element.value.data,
                                style: SettingsOptionStyle.chip,
                                shrinkWrap: false,
                                onTap: () {
                                    setState((){
                                        _type = element.key;
                                        inTab = true;
                                    });
                                },
                            )
                        ).toList(),
                    ),
                ] 
            )
        );
    }
}

class _GeneralSettings extends StatefulWidget {
    const _GeneralSettings();

    @override
    State<_GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends State<_GeneralSettings> {
    ScrollController controller = ScrollController();
    TextEditingController limitController = TextEditingController(text: Settings.limit.value.toString());

    @override
    Widget build(BuildContext context) {
        final data = _options[SettingsPageType.general]!;

        return FadingEdgeScrollView.fromScrollView(
            child: ListView(
                key: PageStorageKey(this),
                controller: controller,
                padding: const EdgeInsets.all(8.0),
                children: [
                    Text.rich(
                        TextSpan(
                            children: [
                                WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Icon(
                                        data.data,
                                        color: Themes.accent,
                                    )
                                ),
                                const WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: SizedBox(width: 8.0,)
                                ),
                                TextSpan(
                                    text: data.title
                                )
                            ]
                        ),
                        style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                        data.subtitle,
                        style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8.0),
                    const FadedDivider(),
                    const SizedBox(height: 8.0),
                    Column(
                        spacing: 4.0,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            SettingsOption(
                                style: SettingsOptionStyle.chip,
                                title: "Limit",
                                subtitle: "The maximum amount of posts to fetch per Subfinder.\nThere is a hard limit of 1000.",
                                icon: Icons.circle,
                                trailing: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxWidth: 256,
                                    ),
                                    child: TextField(
                                        controller: limitController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly
                                        ],
                                        onChanged: (value) {
                                            if (value.isEmpty) return;
                                                                
                                            try {
                                                Settings.limit.value = int.parse(value);
                                            } catch (e, stackTrace) {
                                                Nokulog.e("Failed to set limit.", error: e, stackTrace: stackTrace);
                                                Settings.limit.value = Settings.limit.defaultValue;
                                            }
                                                                
                                            limitController.text = Settings.limit.value.toString();
                                        },
                                    ),
                                ),
                            ),
                            SettingsOption(
                                style: SettingsOptionStyle.chip,
                                title: "Cache posts on favorite",
                                subtitle: "Automatically cache a post when favoriting it, which will store a local copy and allow you to view the post both immediately and offline.",
                                icon: Icons.cached,
                                trailing: ThemedSwitch(
                                    value: Settings.autocache.value, 
                                    onChanged: (value) {
                                        setState(() {
                                            Settings.autocache.value = value;
                                        });
                                    }
                                ),
                            ),
                            SettingsOption(
                                style: SettingsOptionStyle.chip,
                                title: "Filter by MD5",
                                subtitle: "Filter posts on search via their MD5 hash (if it has one) to avoid duplicate posts.",
                                icon: Icons.filter_list,
                                trailing: ThemedSwitch(
                                    value: Settings.filterMD5.value, 
                                    onChanged: (value) {
                                        setState(() {
                                            Settings.filterMD5.value = value;
                                        });
                                    }
                                ),
                            ),
                            SettingsOption(
                                style: SettingsOptionStyle.chip,
                                title: "Show favorite tags",
                                subtitle: "Whether to always display the list of favorite tags on search pages.",
                                icon: Icons.tag_sharp,
                                trailing: ThemedSwitch(
                                    value: Settings.alwaysShowFavoriteTags.value, 
                                    onChanged: (value) {
                                        setState(() {
                                            Settings.alwaysShowFavoriteTags.value = value;
                                        });
                                    }
                                ),
                            ),
                            SettingsOption(
                                style: SettingsOptionStyle.chip,
                                title: "Show source icons",
                                subtitle: "Whether to always display the source icons on a Post card.",
                                icon: FontAwesomeIcons.globe,
                                trailing: ThemedSwitch(
                                    value: Settings.sourceIcon.value, 
                                    onChanged: (value) {
                                        setState(() {
                                            Settings.sourceIcon.value = value;
                                        });
                                    }
                                ),
                            ),
                            SettingsOption(
                                style: SettingsOptionStyle.chip,
                                title: "URL Mode",
                                subtitle: "Just like in a web browser, the search bar will display each page's URL instead.",
                                icon: Icons.link,
                                trailing: ThemedSwitch(
                                    value: Settings.showURL.value, 
                                    onChanged: (value) {
                                        setState(() {
                                            Settings.showURL.value = value;
                                        });
                                    }
                                ),
                            ),
                        ],
                    ),
                    const SizedBox(height: 8.0),
                    const FadedDivider(),
                    if (isDesktop) ...[
                        const SizedBox(height: 8.0),
                        Column(
                            spacing: 4.0,
                            children: [
                                SettingsOption(
                                    style: SettingsOptionStyle.chip,
                                    title: "Ask on download",
                                    subtitle: "Whether to prompt for a storage location on every download.",
                                    icon: Icons.folder,
                                    trailing: ThemedSwitch(
                                        value: Settings.askDownloadDirectory.value, 
                                        onChanged: (value) {
                                            setState(() {
                                                Settings.askDownloadDirectory.value = value;
                                            });
                                        }
                                    ),
                                ),
                                SettingsOption(
                                    style: SettingsOptionStyle.chip,
                                    title: "Download storage location",
                                    subtitle: Settings.saveDirectory.value,
                                    icon: Icons.folder,
                                    trailing: SizedBox(
                                        child: IconButton.outlined(
                                            color: Themes.accent,
                                            style: IconButton.styleFrom(
                                                side: BorderSide(
                                                    width: 2.0,
                                                    color: Themes.accent
                                                )
                                            ),
                                            onPressed: () {
                                        
                                            },
                                            icon: const Icon(Icons.drive_folder_upload)
                                        ),
                                    )
                                ),
                            ],
                        ),
                    ],
                    const SizedBox(height: 8.0),
                    const FadedDivider(),
                    const SizedBox(height: 8.0),
                    Wrap(
                        spacing: 4.0,
                        children: [
                            SettingsOption(
                                style: SettingsOptionStyle.card,
                                title: "Color theme",
                                icon: Icons.color_lens,
                                trailing: ColorDots(
                                    onColorSelect: (pair) {
                                        setState(() {
                                            Themes.accent = pair.mainColor;
                                        });
                                    },
                                )
                            ),
                            SettingsOption(
                                style: SettingsOptionStyle.card,
                                title: "Colorful Mode!",
                                subtitle: "The selected color theme will be used as the basis for the entire app theme.",
                                icon: Icons.color_lens,
                                trailing: ThemedSwitch(
                                    value: Settings.isColorScheme.value, 
                                    onChanged: (value) {
                                        setState(() {
                                            Themes.accent = Themes.accent;
                                            Settings.isColorScheme.value = value;
                                        });
                                    }
                                ),
                            ),
                            SettingsOption(
                                style: SettingsOptionStyle.card,
                                title: "Reset background",
                                subtitle: "Remove the background image, if there is one.",
                                icon: Icons.color_lens,
                                trailing: SizedBox(
                                    child: IconButton.outlined(
                                        color: Themes.accent,
                                        style: IconButton.styleFrom(
                                            side: BorderSide(
                                                width: 2.0,
                                                color: Themes.accent
                                            )
                                        ),
                                        onPressed: () {
                                            Settings.backgroundImage = null;
                                        },
                                        icon: const Icon(Icons.remove_circle)
                                    ),
                                ),
                            ),
                        ],
                    )
                ],
            )
        );
    }
}