import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nokufind/utils.dart';

class LogPage extends StatefulWidget {
    const LogPage({super.key});

    @override
    State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
    final ThemeData infoData = ThemeData.from(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark, dynamicSchemeVariant: DynamicSchemeVariant.rainbow));
    final ThemeData warningData = ThemeData.from(colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange, brightness: Brightness.dark, dynamicSchemeVariant: DynamicSchemeVariant.vibrant));
    final ThemeData errorData = ThemeData.from(colorScheme: ColorScheme.fromSeed(seedColor: Colors.red, brightness: Brightness.dark, dynamicSchemeVariant: DynamicSchemeVariant.vibrant));
    final ThemeData traceData = ThemeData.from(colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey, brightness: Brightness.dark, dynamicSchemeVariant: DynamicSchemeVariant.vibrant));
    final ScrollController controller = ScrollController();

    @override
    void initState() {
        super.initState();
    }

    ThemeData getDataFromType(NokulogEventType type) {
        switch(type) {
            case NokulogEventType.info:     return infoData;
            case NokulogEventType.warning:  return warningData;
            case NokulogEventType.error:    return errorData;
            case NokulogEventType.trace:    return traceData;
            default:                        return Theme.of(context);
        }
    }

    Icon getIconFromType(NokulogEventType type) {
        switch(type) {
            case NokulogEventType.info:     return const Icon(Icons.info);
            case NokulogEventType.warning:  return const Icon(Icons.warning_rounded);
            case NokulogEventType.error:    return const Icon(Icons.error_rounded);
            case NokulogEventType.trace:    return const Icon(Icons.track_changes);
            default:                        return const Icon(Icons.logo_dev);
        }
    }

    void showInfoPopup(NokulogEvent event) {
        final String eventName = toTitle(event.eventType.name);
        final ThemeData data = getDataFromType(event.eventType);
        final List<String> dateData = event.time.toString().split(" ");

        showDialog(
            context: context, 
            builder: (context) => Dialog(
                child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.circular(24.0)),
                        color: Colors.black.withAlpha((255 * 0.35).round())
                    ),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width - 16,
                        maxHeight: MediaQuery.sizeOf(context).height - 16
                    ),
                    child: Column(
                        children: [
                            Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                        Expanded(
                                            child: Text.rich(
                                                TextSpan(
                                                    children: [
                                                        TextSpan(text: eventName),
                                                        if (event.message != null && event.error != null)
                                                        TextSpan(text: ": ${event.message}")
                                                    ]
                                                ),
                                                softWrap: false,
                                                overflow: TextOverflow.fade,
                                                style: TextStyle(color: data.colorScheme.primaryFixed, fontSize: 21.0, fontWeight: FontWeight.bold),
                                            )
                                        ),
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                    child: IconButton(
                                                        onPressed: () {
                                                            Clipboard.setData(
                                                                ClipboardData(
                                                                    text: "${event.message}\n${event.error ?? ''}\n${event.stackTrace.toString()}"
                                                                )
                                                            );
                                                        }, 
                                                        icon: const Icon(Icons.copy)
                                                    ),
                                                ),
                                                Text.rich(
                                                    TextSpan(
                                                        children: dateData.map<TextSpan>((element) => TextSpan(text: "$element\n")).toList()
                                                    ),
                                                    style: TextStyle(color: data.colorScheme.primaryFixed, fontSize: 10.0, fontStyle: FontStyle.italic),
                                                ),
                                            ],
                                        )
                                    ],
                                ),
                            ),
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                        padding: const EdgeInsets.all(12.0),
                                        decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.all(Radius.circular(24.0)),
                                            color: Colors.black.withAlpha((255 * 0.35).round())
                                        ),
                                        child: SelectionArea(
                                            child: SingleChildScrollView(
                                                child: (event.error != null) ? Text(
                                                    event.error.toString(),
                                                    style: TextStyle(color: data.colorScheme.primaryFixed),
                                                ) : Text(
                                                    event.message.toString(),
                                                    style: TextStyle(color: data.colorScheme.primaryFixed)
                                                ),
                                            ),
                                        ),
                                    ),
                                ),
                            ),
                            const Divider(),
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                        padding: const EdgeInsets.all(12.0),
                                        decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.all(Radius.circular(24.0)),
                                            color: Colors.black.withAlpha((255 * 0.35).round())
                                        ),
                                        child: SelectionArea(
                                            child: SingleChildScrollView(
                                                child: Text(
                                                    event.stackTrace.toString(),
                                                    style: TextStyle(color: data.colorScheme.primaryFixed)
                                                ),
                                            ),
                                        ),
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
            )
        );
    }

    @override
    Widget build(BuildContext context) => Scaffold(
            body: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.chevron_left)),
                            Expanded(
                                child: ListView.builder(
                                    controller: controller,
                                    itemCount: Nokulog.log.length,
                                    itemBuilder: (context, index) {
                                        final NokulogEvent event = Nokulog.log[(Nokulog.log.length - 1) - index];
                                        final String eventName = toTitle(event.eventType.name);
                                        final ThemeData data = getDataFromType(event.eventType);
                                        
                                        return Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Container(
                                                padding: const EdgeInsets.all(8.0),
                                                decoration: BoxDecoration(
                                                    borderRadius: const BorderRadius.all(Radius.circular(24.0)),
                                                    color: Theme.of(context).cardColor,
                                                    boxShadow: const [
                                                        BoxShadow(
                                                            offset: Offset(4.0, 4.0),
                                                            blurRadius: 16.0
                                                        )
                                                    ]
                                                ),
                                                child: ListTile(
                                                    title: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Row(
                                                            mainAxisSize: MainAxisSize.max,
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                                Expanded(
                                                                    child: Text.rich(
                                                                        TextSpan(
                                                                            children: [
                                                                                TextSpan(text: eventName),
                                                                                if (event.message != null && event.error != null)
                                                                                TextSpan(text: ": ${event.message}")
                                                                            ]
                                                                        ),
                                                                        style: TextStyle(color: data.colorScheme.primaryFixed, fontSize: 21.0, fontWeight: FontWeight.bold),
                                                                    )
                                                                ),
                                                                Text.rich(
                                                                    TextSpan(text: event.time.toString()),
                                                                    style: TextStyle(color: data.colorScheme.primaryFixed, fontSize: 10.0, fontStyle: FontStyle.italic),
                                                                )
                                                            ],
                                                        ),
                                                    ),
                                                    subtitle: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: (event.error != null) ? Text(
                                                            event.error.toString(),
                                                            style: TextStyle(color: data.colorScheme.primaryFixed),
                                                            overflow: TextOverflow.ellipsis,
                                                        ) : Text(
                                                            event.message.toString(),
                                                            style: TextStyle(color: data.colorScheme.primaryFixed),
                                                            overflow: TextOverflow.ellipsis,
                                                        ),
                                                    ),
                                                    leading: getIconFromType(event.eventType),
                                                    contentPadding: const EdgeInsets.all(8.0),
                                                    onTap: () => showInfoPopup(event),
                                                ),
                                            ),
                                        );
                                    }
                                )
                            )
                        ],
                    ),
                ),
            ),
        );
}