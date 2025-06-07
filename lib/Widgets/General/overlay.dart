import 'dart:async';
import 'package:flutter/material.dart';

class OverlayWidget extends StatefulWidget {
    final Widget child;
    final Widget overlay;
    final Function(bool enabled)? onTap;

    const OverlayWidget({
        super.key,
        required this.child,
        required this.overlay,
        this.onTap,
    });

    @override
    State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
    bool overlayVisible = false;
    Timer? overlayTimer;
    double opacity = 0.0;

    @override
    void dispose() {
        overlayTimer?.cancel();
        super.dispose();
    }

    void showOverlay() {
        setState(() {
            overlayVisible = true;
            opacity = 1.0; // This will cause the AnimatedOpacity to fade in.
        });
        startOverlayTimer();
    }

    void hideOverlay() {
        overlayTimer?.cancel();
        setState(() {
            opacity = 0.0; // Trigger fade out.
        });
        // After the fade-out duration, remove the overlay.
        Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
                setState(() {
                    overlayVisible = false;
                });
            }
        });
    }

    void startOverlayTimer() {
        overlayTimer?.cancel();
        overlayTimer = Timer(const Duration(seconds: 5), () {
            hideOverlay();
            widget.onTap?.call(false);
        });
    }

    @override
    Widget build(BuildContext context) => Stack(
            children: [
                GestureDetector(
                    onTap: () {
                        if (overlayVisible) {
                            hideOverlay();
                            widget.onTap?.call(false);

                            return;
                        }

                        showOverlay();
                        widget.onTap?.call(true);
                    },
                    child: widget.child,
                ),
                if (overlayVisible)
                    GestureDetector(
                        onTap: startOverlayTimer,
                        child: AnimatedOpacity(
                            opacity: opacity,
                            duration: const Duration(milliseconds: 400),
                            child: widget.overlay,
                        ),
                    ),
            ],
        );
}