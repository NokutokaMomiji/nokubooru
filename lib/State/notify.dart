import 'package:flutter/material.dart';
import 'package:nokubooru/themes.dart';
import 'package:toastification/toastification.dart';

class Notify {
    static ToastificationItem showMessage({String? title, required String message, Widget? icon, bool autoClose = true}) => toastification.show(
            type: ToastificationType.success,
            title: (title != null) ? Text.rich(
                TextSpan(
                    text: title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18
                    )
                )
            ) : null,
            description: Padding(
                padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                child: Text(message),
            ),
            icon: icon,
            primaryColor: Themes.accent,
            backgroundColor: Themes.darkTheme.cardColor,
            foregroundColor: Themes.accent,
            progressBarTheme: Themes.darkTheme.progressIndicatorTheme,
            borderSide: BorderSide(
                color: Themes.accent,
                width: 2.0
            ),
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: const [
                BoxShadow(
                    offset: Offset(4.0, 4.0),
                    blurRadius: 32.0
                )
            ],
            showProgressBar: autoClose,
            autoCloseDuration: (autoClose) ? const Duration(seconds: 3) : null,
            closeOnClick: true,
        );
}