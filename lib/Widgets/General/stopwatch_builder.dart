import 'dart:async';

import 'package:flutter/material.dart';

class StopwatchBuilder extends StatefulWidget {
    final Stopwatch stopwatch;
    final Widget Function(BuildContext context, Duration elapsed) builder;
    final Duration? updateInterval;

    const StopwatchBuilder({required this.stopwatch, required this.builder, this.updateInterval, super.key});

    @override
    State<StopwatchBuilder> createState() => _StopwatchBuilderState();
}

class _StopwatchBuilderState extends State<StopwatchBuilder> {
    Timer? timer;

    @override
    void initState() {
        super.initState();
        manageTimer();
    }

    @override
    void dispose() {
        stopTimer();
        super.dispose();
    }

    void manageTimer() {
        if (!widget.stopwatch.isRunning) {
            stopTimer();
            if (mounted) {
                setState((){});
            }
            return;
        }

        if (timer != null) return;

        timer = Timer.periodic(widget.updateInterval ?? const Duration(milliseconds: 16), (timer) {
            if (!widget.stopwatch.isRunning) {
                stopTimer();
            }

            setState((){});
        });
    }

    void stopTimer() {
        timer?.cancel();
        timer = null;
    }

    @override
    Widget build(BuildContext context) => widget.builder(context, widget.stopwatch.elapsed);
}