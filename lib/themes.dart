import 'package:flutter/material.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/utilities.dart';

class Themes {
    static const Color offlineRing = Color(0xffdadada);
    static List<Color> offlineColors = [];
    
    static const Color liveRing = Color(0xffdd0000);
    static List<Color> liveColors = [Colors.red.shade400, Colors.redAccent[100]!];
    static Gradient liveGradient = LinearGradient(colors: liveColors);

    static const Color errorBackground = Color(0xff880000);
    static const Color errorText = Color(0xffffaaaa);

    static const Color black = Color(0xff212121);
    static const Color white = Color(0xfffcfcfc);
    static const Color gold = Color(0xffbf9b30);

    static Color _accent = Colors.redAccent;
    static Color get accent => _accent;
    static set accent(Color value) {
        _accent = value;
        Settings.colorAccent.value = encodeColor(value);
    }

    static ValueNotifier<ThemeData> themeData = ValueNotifier<ThemeData>(darkTheme);
    static ValueNotifier<bool> accentNotifier = ValueNotifier<bool>(false);

    static ThemeData lightTheme = ThemeData.from(
        colorScheme: const ColorScheme.light(
            primary: Color(0xff212121),
            secondary: Color(0xffdadada),
            error: Color(0xffcf6679),
            surface: Color(0xfffcfcfc),
        ),
        useMaterial3: true
    );

    static ThemeData darkTheme = ThemeData.from(
        colorScheme: const ColorScheme.dark(
            primary: Color(0xfffcfcfc),
            secondary: Color(0xffdadada),
            error: Color(0xffcf6679),
            surface: Color(0xff212121),
        ),
        useMaterial3: true
    );

}