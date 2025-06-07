import 'package:flutter/material.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tab_manager.dart';
import 'package:nokubooru/Widgets/General/custom_container.dart';

class DebugOverlay extends StatefulWidget {
    final TabManager manager;
    final Widget child;

    const DebugOverlay({required this.manager, required this.child, super.key});

    @override
    State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
    @override
    void initState() {
        super.initState();

            
    }

    @override
    Widget build(BuildContext context) => Stack(
            children: [
                widget.child,
                Positioned(
                    child: IgnorePointer(
                        child: Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Visibility(
                                    visible: false,
                                    child: Opacity(
                                        opacity: 0.85,
                                        child: CustomContainer(
                                            constraints: BoxConstraints.tight(const Size.square(256)),
                                            borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    Text(
                                                        widget.manager.active.formatStack(),
                                                        softWrap: true,
                                                        style: const TextStyle(
                                                            fontFamily: "Consolas",
                                                            color: Colors.white
                                                        ),
                                                    ),
                                                    Text(Settings.documentDirectory),
                                                    Text(Settings.legacyDirectory),
                                                ],
                                            ),
                                        ),
                                    ),
                                ),
                            ),
                        ),
                    ),
                )      
            ],
        );
}