
import 'dart:async';

import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_hero/local_hero.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mobile_window_features/mobile_window_features.dart';
import 'package:mobile_window_features/status_navigation_bars_options.dart';
import 'package:nokubooru/Pages/first_time_page.dart';
import 'package:nokubooru/State/downloads.dart';
import 'package:nokubooru/State/post_resolver.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/State/tab_data.dart';
import 'package:nokubooru/State/tab_manager.dart';
import 'package:nokubooru/State/tags.dart';
import 'package:nokubooru/Widgets/Debug/debug_overlay.dart';
import 'package:nokubooru/Widgets/Post/post_media.dart';
import 'package:nokubooru/Widgets/nb_tabbar.dart';
import 'package:nokubooru/Widgets/nb_tabview.dart';
import 'package:nokubooru/Widgets/search_bar.dart';
import 'package:nokubooru/Widgets/search_bar_controller.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/utils.dart';
import 'package:screenshot/screenshot.dart';
import 'package:toastification/toastification.dart';
import 'Widgets/nb_appbar.dart';
import 'themes.dart';

Future? initializing;
Future? total;

TabManager manager = TabManager();
bool activatedPopup = false;
NBSearchBarController nbSearchBarController = NBSearchBarController();

void main() async {
    ErrorWidget.builder = (FlutterErrorDetails details) => Material(
            color: Themes.black,
            child: Center(
                child: Container(
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.all(20.0),
                    constraints: const BoxConstraints(
                        maxWidth: 400, // Prevents excessive stretching
                    ),
                    decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: const [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8.0,
                                offset: Offset(2, 2),
                            ),
                        ],
                    ),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                            const Icon(Icons.error, color: Colors.red, size: 48.0),
                            const SizedBox(height: 10),
                            Text(
                                "Oops! Something went wrong.",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                ),
                                textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                                details.exception.toString(),
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Divider(color: Colors.red.shade300, thickness: 1),
                            const SizedBox(height: 10),
                            Text(
                                "Stack Trace:",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                                height: 150, // Limits stack trace height
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8.0),
                                    border: Border.all(
                                        color: Colors.red.shade400,
                                        width: 1.0,
                                    ),
                                ),
                                child: SingleChildScrollView(
                                    child: Text(
                                        details.stack.toString(),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                        ),
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
            ),
        );

    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
    ));

    if (kDebugMode) {
        Nokulog.mode = NokulogMode.base;
    } else {
        Nokulog.mode = NokulogMode.errors;
    }

    PostResolver.initialize();

    final Completer completer = Completer();
    
    await Settings.init();

    initializing = Future.wait([
        Future.delayed(const Duration(seconds: 1)),
        () async {
            await Future.wait([
                Tags.init(),
                Downloads.init(),
            ]);
        }()
    ]);

    total = Future.wait([initializing!, completer.future]);

    //debugRepaintRainbowEnabled = true;

    runApp(const MainApp());

    if (isDesktop) {
        doWhenWindowReady(() {
            final win = appWindow;
            const initialSize = Size(1280, 720);

            win.minSize = const Size(600, 450);
            win.size = initialSize;
            win.alignment = Alignment.center;
            win.title = "Nokubooru";
            
            win.show();
            Future.delayed(
                const Duration(seconds: 1),
                completer.complete
            );
        });
    } else {
        completer.complete();
    }
}

class MainApp extends StatelessWidget {
    const MainApp({super.key});

    @override
    Widget build(BuildContext context) {
        // Themes.accent = Colors.lightGreenAccent;
        // TabData.maxCacheViews = 5;
        // isDesktop = true;

        MobileWindowFeatures.setScreenProperties(
            screenLimits: ScreenLimits.pageDrawBehindTheStatusBarNavigationBar,
            statusBarColor: Colors.transparent,
            statusBarTheme: StatusBarThemeMWF.darkStatusBar,
            navigationBarColor: Colors.transparent,
            navigationBarTheme: NavigationBarThemeMWF.darkNavigationBar
        );

        List<Widget> children;

        return ValueListenableBuilder(
            valueListenable: Settings.colorAccent,
            builder: (context, value, child) {
                final mainTheme = (Settings.isColorScheme.value) ? ThemeData.from(
                    colorScheme: ColorScheme.fromSeed(
                        seedColor: Themes.accent,
                        brightness: Brightness.dark
                    )
                ) : ThemeData.from(
                    colorScheme: const ColorScheme.dark(
                        primary: Color(0xfffcfcfc),
                        secondary: Color(0xffdadada),
                        error: Color(0xffcf6679),
                        surface: Color(0xff212121)
                    ),
                    useMaterial3: true
                );

                return ToastificationWrapper(
                    child: PopScope(
                        canPop: (manager.tabs.isNotEmpty) ? !manager.active.canBacktrack : true,
                        onPopInvokedWithResult: (didPop, result) {
                            if (didPop) return;

                            if (manager.active.canBacktrack) {
                                manager.active.backtrack();
                            }
                        },
                        child: MaterialApp(
                            title: "Nokubooru",
                            theme: Themes.lightTheme.copyWith(
                                textTheme: GoogleFonts.aldrichTextTheme()
                            ),
                            darkTheme: mainTheme.copyWith(
                                textTheme: GoogleFonts.aldrichTextTheme().merge(
                                    TextTheme(
                                        // Ok, so... Yeah. For some reason, the dark theme leaves certain text objects as black.
                                        // I have to manually adjust for that.
                                        bodyMedium: const TextStyle(color: Themes.white),
                                        titleMedium: const TextStyle(color: Themes.white),
                                        labelMedium: const TextStyle(color: Themes.white),
                                        displayMedium: const TextStyle(color: Themes.white),
                                        headlineMedium: const TextStyle(color: Themes.white),
                                        labelLarge: TextStyle(color: Themes.accent),
                                        bodyLarge: TextStyle(color: Themes.accent),
                                        titleLarge: TextStyle(color: Themes.accent, fontWeight: FontWeight.bold),
                                        displayLarge: TextStyle(color: Themes.accent, fontWeight: FontWeight.bold),
                                        headlineLarge: TextStyle(color: Themes.accent, fontWeight: FontWeight.bold),
                                        headlineSmall: TextStyle(color: Themes.accent),
                                        bodySmall: TextStyle(color: Themes.accent),
                                    )
                                ).apply(
                                    fontFamilyFallback: [
                                        GoogleFonts.kosugiMaru().fontFamily!
                                    ]
                                ),
                            ),
                            themeMode: ThemeMode.dark,
                            navigatorObservers: [
                                videoRouteObserver
                            ],
                            home: Scaffold(
                                body: FutureBuilder(
                                    future: total,
                                    builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.done) {
                                            manager.init();
                            
                                            if (Settings.firstTime.value && !activatedPopup) {
                                                Future.delayed(
                                                    Duration.zero,
                                                    () {
                                                        activatedPopup = true;
                                                        if (context.mounted) {
                                                            showDialog(
                                                                context: context, 
                                                                barrierDismissible: false,
                                                                builder: (context) => const FirstTimePage(),
                                                            );
                                                        }
                                                    }  
                                                );
                                            }

                                            if (isDesktop) {
                                                children = [
                                                    ConstrainedBox(
                                                        constraints: const BoxConstraints(minHeight: 42.0),
                                                        child: WindowTitleBarBox(
                                                            child: NBAppBar(bar: NBTabBar(tabManager: manager))
                                                        ),
                                                    ),
                                                    const Expanded(child: ActualAppView())
                                                ];
                                            } else {
                                                children = [
                                                    const Expanded(child: ActualAppView())
                                                ];
                                            }
                                                
                                            return Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: children
                                            );
                                        }
                                
                                        return const Center(
                                            child: CircularProgressIndicator(),
                                        );
                                    },
                                ),
                            ),
                            debugShowCheckedModeBanner: false,
                        ),
                    ),
                );
            },
        );
    }
}

class ActualAppView extends StatefulWidget {
    const ActualAppView({super.key});

    @override
    State<ActualAppView> createState() => _ActualAppViewState();
}

class _ActualAppViewState extends State<ActualAppView> {
    bool showThumb = false;

    @override
    void initState() {
        super.initState();

        manager.active.onUpdate(() {
            if (mounted) {
                setState((){});
            }
        });

        manager.onActiveChange((_) {
            if (mounted) {
                setState((){});
            }
        });

        BackButtonInterceptor.add(interceptor, context: context);
    }

    @override
    void dispose() {
        BackButtonInterceptor.remove(interceptor);
        super.dispose();
    }

    bool interceptor(bool stopDefaultButtonEvent, RouteInfo info) {
        if (info.ifRouteChanged(context)) return false;

        final canPop = (manager.tabs.isNotEmpty) ? !manager.active.canBacktrack : true;

        if (!canPop) {
            if (manager.active.canBacktrack) {
                manager.active.backtrack();
            }
            return true;
        }

        return false;
    }

    @override
    Widget build(BuildContext context) => ValueListenableBuilder(
            valueListenable: Settings.bgImageSetting,
            builder: (context, value, child) => Screenshot(
                    controller: manager.screenshotController,
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        padding: (isDesktop) ? const EdgeInsets.only(left: 1.0, right: 1.0, bottom: 1.0) : null,
                        decoration: BoxDecoration(
                            border: (isDesktop) ? Border.all(color: Themes.accent, width: 2.0) : null,
                            borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(10.0),
                                bottomRight: Radius.circular(10.0)
                            ),
                            gradient: LinearGradient(
                                colors: [
                                    Theme.of(context).canvasColor, 
                                    Theme.of(context).primaryColorDark
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter
                            ),
                            image: (Settings.backgroundImage != null) ? DecorationImage(
                                image: Image.memory(Settings.backgroundImage!).image,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter.add(const Alignment(0, 0.5)),
                                opacity: 0.35
                            ) : null,
                            backgroundBlendMode: null //(Settings.backgroundImage != null) ? BlendMode.multiply : null
                        ),
                        child: child
                    ),
                ),
            child: StreamBuilder(
                stream: manager.active.stream,
                builder: (context, snapshot) => DebugOverlay(
                    manager: manager,
                    child: LocalHeroScope(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.fastEaseInToSlowEaseOut,
                        child: Stack(
                            children: [
                                Column(
                                    children: [
                                        NBSearchBar(
                                            manager: manager,
                                            controller: nbSearchBarController,
                                        ),
                                        Expanded(
                                            child: NBTabView(data: manager.active.current)
                                        )
                                    ],
                                ),  
                                /*if (!isDesktop && false) ValueListenableBuilder(
                                    valueListenable: manager.showThumb,
                                    builder: (context, value, child) {
                                        if (value == true && manager.active.thumb != null) {
                                            return Positioned.fill(
                                                child: Hero(
                                                    tag: manager.active, 
                                                    child: Image.memory(
                                                        manager.active.thumb!,
                                                        fit: BoxFit.cover,
                                                        alignment: Alignment.topCenter,
                                                    )
                                                )
                                            );
                                        }
                        
                                        return const SizedBox.shrink();
                                    },
                                )*/
                            ]
                        ),
                    ),
                ),
            )
        );
}
