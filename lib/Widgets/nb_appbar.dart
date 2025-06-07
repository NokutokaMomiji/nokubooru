import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:nokubooru/Widgets/nb_tabbar.dart';
import 'package:nokubooru/themes.dart';

var buttonColor = WindowButtonColors(iconNormal: Themes.offlineRing);

class NBAppBar extends StatelessWidget {
    final NBTabBar bar;

    const NBAppBar({required this.bar, super.key});

    @override
    Widget build(BuildContext context) => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: LayoutBuilder(
                builder: (context, constraints) => Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                            Padding(
                                padding: const EdgeInsets.only(top: 8.0, left: 12.0, bottom: 2.0),
                                child: Image.asset("assets/logo_white.png", scale: 2, color: Themes.accent)
                            ),
                            Expanded(
                                //constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.75),
                                child: bar,
                            ),
                            ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 32),
                                child: MoveWindow()
                            ),
                            Row(
                                children: [
                                    MinimizeWindowButton(colors: buttonColor),
                                    MaximizeWindowButton(colors: buttonColor),
                                    CloseWindowButton(colors: buttonColor),
                                ],
                            )
                        ],
                    ),
            ),
        );
}