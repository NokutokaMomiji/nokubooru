import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nokubooru/State/download_manager.dart';
import 'package:nokubooru/themes.dart';
import 'package:nokufind/utils.dart';
import 'package:url_launcher/url_launcher.dart';

enum DownloadCardStyle { card, chip }

Map<String, Uint8List> _dataCache = {};

class DownloadCard extends StatefulWidget {
    final DownloadRecord record;
    final DownloadCardStyle style;

    const DownloadCard({
        required this.record,
        this.style = DownloadCardStyle.card,
        super.key,
    });

    @override
    State<DownloadCard> createState() => _DownloadCardState();
}

class _DownloadCardState extends State<DownloadCard> {
    DecorationImage? _thumbnail;
    bool _exists = true;

    @override
    void initState() {
        super.initState();
        _loadThumbnail();
    }

    void _loadThumbnail() {
        final path = widget.record.path;
        if (path == null) {
            _exists = false;
            return;
        }

        final type = FileSystemEntity.typeSync(path);
        _exists = (type != FileSystemEntityType.notFound);
        if (!_exists) return;

        if (_dataCache.containsKey(path)) {
            _thumbnail = DecorationImage(
                image: Image.memory(_dataCache[path]!).image,
                fit: BoxFit.cover,
            );
            return;
        }

        if (type == FileSystemEntityType.file) {    
            final file = File(path);
            file.readAsBytes().then((bytes) {
                _dataCache[path] = bytes;
                if (mounted) {
                    setState(() {
                        _thumbnail = DecorationImage(
                            image: Image.memory(bytes).image,
                            fit: BoxFit.cover,
                        );
                    });
                }
            });
        } else if (type == FileSystemEntityType.directory) {
            final dir = Directory(path);
            for (final item in dir.listSync()) {
                if (item is! File) continue;
                item.readAsBytes().then((bytes) {
                    _dataCache[path] = bytes;
                    if (mounted) {
                        setState(() {
                            _thumbnail = DecorationImage(
                                image: Image.memory(bytes).image,
                                fit: BoxFit.cover,
                            );
                        });
                    }
                });
                return;
            }
        }
    }

    void _openPath() {
        final path = widget.record.path;
        if (path == null) return;
        try {
            launchUrl(Uri.parse("file:///$path"));
        } catch (e, stackTrace) {
            Nokulog.e("Failed to open path.", error: e, stackTrace: stackTrace);
        }
    }

    String _formattedDateTime() {
        final timestamp = widget.record.timestamp.toLocal();
        
        final day = timestamp.day.toString().padLeft(2, '0');
        final month = timestamp.month.toString().padLeft(2, '0');
        final year = timestamp.year.toString();
        
        final hour = timestamp.hour.toString().padLeft(2, '0');
        final min = timestamp.minute.toString().padLeft(2, '0');

        return "$day/$month/$year $hour:$min";
    }

    @override
    Widget build(BuildContext context) => InkWell(
            onTap: _openPath,
            child: Material(
                clipBehavior: Clip.hardEdge,
                type: MaterialType.transparency,
                child: widget.style == DownloadCardStyle.chip
                    ? _ChipStyleDownloadCard(
                        record: widget.record,
                        thumbnail: _thumbnail,
                        exists: _exists,
                        formattedDateTime: _formattedDateTime(),
                    )
                    : _CardStyleDownloadCard(
                        record: widget.record,
                        thumbnail: _thumbnail,
                        exists: _exists,
                        formattedDateTime: _formattedDateTime(),
                    ),
            )
        );
}

class _CardStyleDownloadCard extends StatelessWidget {
    final DownloadRecord record;
    final DecorationImage? thumbnail;
    final bool exists;
    final String formattedDateTime;

    const _CardStyleDownloadCard({required this.record, required this.thumbnail, required this.exists,required this.formattedDateTime});

    @override
    Widget build(BuildContext context) {
        final multiple = (record.fileCount > 1);
        final theme = Theme.of(context);

        return SizedBox(
            width: 200,
            child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 8.0,
                clipBehavior: Clip.antiAlias,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        // Thumbnail or placeholder
                        Container(
                            height: 100,
                            decoration: BoxDecoration(
                                color: theme.cardColor,
                                image: thumbnail,
                            ),
                            child: thumbnail == null
                                ? Center(
                                    child: Icon(
                                        exists ? Icons.file_download : Icons.error_outline,
                                        size: 40,
                                        color: theme.hintColor,
                                    ),
                                )
                                : null,
                        ),

                        // Title, date/time, and status area
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    // Title
                                    Text(
                                        record.title,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4.0),

                                    // Date / Time
                                    Text(
                                        formattedDateTime,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.hintColor,
                                        ),
                                    ),
                                    const SizedBox(height: 8.0),

                                    // Download status / file count
                                    StreamBuilder<DownloadProcessInfo>(
                                        stream: record.process?.stream,
                                        builder: (context, snapshot) {
                                            final process = record.process;

                                            if (!exists) {
                                                return Text(
                                                    "Not found",
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                        color: theme.colorScheme.error,
                                                    ),
                                                );
                                            }

                                            if (snapshot.connectionState == ConnectionState.active && process != null) {
                                                final progressValue = process.progress;
                                                final currentName = snapshot.data?.file?.filename;
                                                return Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                        if (multiple && currentName != null)
                                                            Text(
                                                                "Downloading: $currentName",
                                                                style: theme.textTheme.bodySmall,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                            ),
                                                        const SizedBox(height: 4.0),
                                                        ClipRRect(
                                                            borderRadius: BorderRadius.circular(4.0),
                                                            child: LinearProgressIndicator(
                                                                backgroundColor: Theme.of(context).disabledColor,
                                                                color: Themes.accent,
                                                                value: progressValue,
                                                                minHeight: 6.0,
                                                            ),
                                                        ),
                                                        const SizedBox(height: 4.0),
                                                        Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                                Text(
                                                                    "${process.currentSize} / ${process.totalSize} ${multiple ? "files" : "bytes"}",
                                                                    style: theme.textTheme.bodySmall,
                                                                ),
                                                                if (!process.completed && !process.cancelled)
                                                                    Text(
                                                                        "${process.progressPercentage}%",
                                                                        style: theme.textTheme.bodySmall,
                                                                    ),
                                                            ],
                                                        ),
                                                    ],
                                                );
                                            }

                                            if (process?.cancelled == true) {
                                                return Text(
                                                    "Cancelled",
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                        color: theme.disabledColor,
                                                    ),
                                                );
                                            }

                                            return Text(
                                                "${record.fileCount} ${record.fileCount > 1 ? "files" : "file"}",
                                                style: theme.textTheme.bodySmall,
                                            );
                                        },
                                    ),
                                ],
                            ),
                        ),

                        // Cancel button if in progress
                        if (record.process != null) Padding(
                            padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                            child: Align(
                                alignment: Alignment.centerRight,
                                child: StreamBuilder<DownloadProcessInfo>(
                                    stream: record.process?.stream,
                                    builder: (context, snapshot) {
                                        final state = snapshot.connectionState;
                                        if (state != ConnectionState.none && state != ConnectionState.done) {
                                            return IconButton(
                                                icon: const Icon(Icons.cancel_outlined),
                                                color: theme.colorScheme.secondary,
                                                onPressed: () {
                                                    record.process!.cancel();
                                                },
                                            );
                                        }
                                        return const SizedBox.shrink();
                                    },
                                ),
                            ),
                        ),
                    ],
                ),
            ),
        );
    }
}

class _ChipStyleDownloadCard extends StatelessWidget {
    final DownloadRecord record;
    final DecorationImage? thumbnail;
    final bool exists;
    final String formattedDateTime;

    const _ChipStyleDownloadCard({
        required this.record,
        required this.thumbnail,
        required this.exists,
        required this.formattedDateTime,
    });

    @override
    Widget build(BuildContext context) {
        final multiple = (record.fileCount > 1);
        final theme = Theme.of(context);

        return Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 8.0,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
                //height: 100,
                child: IntrinsicHeight(
                    child: Row(
                        children: [
                            // Thumbnail or placeholder on left
                            Container(
                                //width: 100,
                                constraints: BoxConstraints.expand(
                                    width: 100
                                ),
                                decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    image: thumbnail,
                                ),
                                child: thumbnail == null
                                    ? Center(
                                        child: Icon(
                                            exists ? Icons.file_download : Icons.error_outline,
                                            size: 32,
                                            color: theme.hintColor,
                                        ),
                                    )
                                    : null,
                            ),
                    
                            // Right side: text and progress
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            // Top row: title + cancel button if needed
                                            Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    Expanded(
                                                        child: Text(
                                                            record.title,
                                                            style: theme.textTheme.bodyMedium?.copyWith(
                                                                fontWeight: FontWeight.w600,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                        ),
                                                    ),
                                                    if (record.process != null)
                                                        StreamBuilder<DownloadProcessInfo>(
                                                            stream: record.process?.stream,
                                                            builder: (context, snapshot) {
                                                                final state = snapshot.connectionState;
                                                                if (state != ConnectionState.none && state != ConnectionState.done) {
                                                                    return IconButton(
                                                                        icon: const Icon(Icons.cancel_outlined),
                                                                        color: theme.colorScheme.secondary,
                                                                        iconSize: 20,
                                                                        padding: EdgeInsets.zero,
                                                                        constraints: const BoxConstraints(),
                                                                        onPressed: () {
                                                                            record.process!.cancel();
                                                                        },
                                                                    );
                                                                }
                                                                return const SizedBox.shrink();
                                                            },
                                                        ),
                                                ],
                                            ),
                    
                                            const SizedBox(height: 4.0),
                    
                                            // Date/time
                                            Text(
                                                formattedDateTime,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                    color: theme.hintColor,
                                                ),
                                            ),
                    
                                            const SizedBox(height: 8.0),
                    
                                            // Status or file count
                                            StreamBuilder<DownloadProcessInfo>(
                                                stream: record.process?.stream,
                                                builder: (context, snapshot) {
                                                    final process = record.process;
                    
                                                    if (!exists) {
                                                        return Text(
                                                            "Not found",
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                                color: theme.colorScheme.error,
                                                            ),
                                                        );
                                                    }
                    
                                                    if (snapshot.connectionState == ConnectionState.active && process != null) {
                                                        final progressValue = process.progress;
                                                        final currentName = snapshot.data?.file?.filename;
                                                        return Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                                if (multiple && currentName != null)
                                                                    Text(
                                                                        "Downloading: $currentName",
                                                                        style: theme.textTheme.bodySmall,
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                const SizedBox(height: 4.0),
                                                                ClipRRect(
                                                                    borderRadius: BorderRadius.circular(4.0),
                                                                    child: LinearProgressIndicator(
                                                                        backgroundColor: Theme.of(context).disabledColor,
                                                                        color: Themes.accent,
                                                                        value: progressValue,
                                                                        minHeight: 6.0,
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 4.0),
                                                                Text(
                                                                    "${process.currentSize} / ${process.totalSize} ${multiple ? "files" : "bytes"}   ${!process.completed && !process.cancelled ? "${process.progressPercentage}%" : ""}",
                                                                    style: theme.textTheme.bodySmall,
                                                                ),
                                                            ],
                                                        );
                                                    }
                    
                                                    if (process?.cancelled == true) {
                                                        return Text(
                                                            "Cancelled",
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                                color: theme.disabledColor,
                                                            ),
                                                        );
                                                    }
                    
                                                    return Text(
                                                        "${record.fileCount} ${record.fileCount > 1 ? "files" : "file"}",
                                                        style: theme.textTheme.bodySmall,
                                                    );
                                                },
                                            ),
                                        ],
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }
}
