import 'package:flutter/material.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/Widgets/General/custom_container.dart';
import 'package:nokubooru/themes.dart';

class FirstTimePage extends StatefulWidget {
    const FirstTimePage({super.key});

    @override
    State<FirstTimePage> createState() => _FirstTimePageState();
}

class _FirstTimePageState extends State<FirstTimePage> {
    Widget firstSide = const Placeholder();
    Widget secondSide = const Placeholder();
    int page = 0;
    bool popAfterImportConfiguration = false;
    bool shouldImportConfiguration = false;

    @override
    void initState() {
        super.initState();

        shouldImportConfiguration = Settings.legacyFilesExist();
    }

    @override
    Widget build(BuildContext context) {
        switch (page) {
            case 0:
                firstSide = Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Image.asset(
                        "assets/logo_white.png", 
                        color: Themes.accent
                    ),
                );
                secondSide = Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                            Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text.rich(
                                    TextSpan(
                                        children: [
                                            TextSpan(
                                                style: const TextStyle(
                                                    fontSize: 23,
                                                    fontWeight: FontWeight.bold
                                                ),
                                                children: [
                                                    const TextSpan(
                                                        text: "Welcome to Nokubooru "
                                                    ),
                                                    TextSpan(
                                                        text: "2.0",
                                                        style: TextStyle(
                                                            color: Themes.accent
                                                        )
                                                    ),
                                                    const TextSpan(
                                                        text: "!\n\n"
                                                    )
                                                ]
                                            ),
                                            const TextSpan(
                                                text: "Quite a few things have changed since the previous version, so let's set things up for ya!"
                                            )
                                        ]
                                    ),
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                ),
                            ),
                            Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Wrap(
                                    //mainAxisSize: MainAxisSize.min,
                                    //mainAxisAlignment: MainAxisAlignment.center,
                                    //crossAxisAlignment: CrossAxisAlignment.center,
                                    runAlignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 16.0,
                                    children: [
                                        OutlinedButton.icon(
                                            onPressed: () {
                                                if (!shouldImportConfiguration) {
                                                    Navigator.of(context).pop();
                                                    return;
                                                }

                                                setState(() {
                                                    page++;
                                                });
                                            }, 
                                            label: const Text("Skip configuration"),
                                            icon: const Icon(Icons.skip_next),
                                        ),
                                        FilledButton.icon(
                                            onPressed: () {
                                                setState(() {
                                                    if (shouldImportConfiguration) {
                                                        page++;
                                                    } else {
                                                        page = 2;
                                                    }
                                                });
                                            }, 
                                            label: const Text("Continue"),
                                            icon: const Icon(Icons.chevron_right),
                                        )
                                    ],
                                ),
                            )
                        ],
                    )
                );
            break;

            case 1:
                final future = () async {
                    final firstResult = await Settings.loadLegacyConfig();
                    final secondResult = await Settings.importLegacyFavorites();
                
                    return (firstResult, secondResult);
                }();
                firstSide = FutureBuilder(
                    future: future,
                    builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                            Future.delayed(Duration.zero, () {
                                setState((){
                                    page++;
                                });
                            });
                        }

                        return const Center(child: CircularProgressIndicator());
                    },
                );
                secondSide = const Text("Importing data from previous version...");
            break;

            case 2:
                firstSide = const Text.rich(TextSpan(text: "Wow"));
                Future.delayed(Duration.zero, () {
                    if (context.mounted) {
                        Navigator.of(context).pop();
                    }
                    Settings.firstTime.value = false;
                });
            break;
        }

        return Dialog(
            backgroundColor: Colors.transparent,
            child: CustomContainer(
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                padding: const EdgeInsets.all(8.0),
                child: LayoutBuilder(
                    builder: (context, constraints) {
                        final children = [
                            Expanded(
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    child: firstSide,
                                ),
                            ),
                            Expanded(
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    child: secondSide
                                ),
                            ),
                        ];
                
                        if ((constraints.maxWidth / constraints.maxHeight) < 1) {
                            return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: children,
                            );
                        }
                
                        return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: children
                        );
                    }, 
                ),
            ),
        );
    }
}

