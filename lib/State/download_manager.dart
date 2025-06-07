import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:executor/executor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:nokubooru/State/downloads.dart';
import 'package:nokubooru/State/settings.dart';
import 'package:nokubooru/utilities.dart';
import 'package:nokufind/nokufind.dart';
import 'package:nokufind/utils.dart';

// For randomizing lists.
Random _random = Random();

/// Helper function to save a PostFile's data.
/// 
/// On Desktop environments, path is a [String] and the file is manually written
/// to the Download directory specified on [Settings.saveDirectory] or the one selected
/// by the user on the prompt found in [DownloadManager._getDownloadsDirectory].
/// 
/// On Mobile environments, [Gal] is used to store the data in the device's gallery.
Future<void> _storeFile(PostFile file, String? path) async {
    if (path == null) {
        if (file.type == PostFileType.video) {
            final tempFile = "${Directory.systemTemp.path}/${file.filename}";
            await File(tempFile).writeAsBytes(file.data!);
            await Gal.putVideo(tempFile);
            return;
        }

        var data = file.data!;

        if (file.type == PostFileType.zip) {
            await file.convertZipToGIF();
            data = file.data ?? data;
        } else if (file.filename.endsWith("webp")) {
            final cmd = img.Command()..decodeWebP(file.data!)..encodePng();
            final result = await cmd.executeThread();

            data = (await result.getBytes()) ?? data;
        }

        await Gal.putImageBytes(
            data,
            album: "Nokubooru",
            name: stripExtension(file.filename)
        );
        return;
    }

    final dir = Directory(path);

    if (!dir.existsSync()) {
        dir.createSync(recursive: true);
    }

    await File("$path/${file.filename}").writeAsBytes(file.data!);
}

/// Enum that defines the status of a [DownloadProcess].
enum DownloadProcessStatus {
    started,
    downloadStarted,
    downloadFailed,
    downloadCompleted,
    completed,
    cancelled
}

/// Object streamed by [DownloadProcess] to report information about it's process.
class DownloadProcessInfo {
    final DownloadProcessStatus status;
    final PostFile? file;
    final DownloadProcess process;

    final Object? error;
    final StackTrace? stackTrace;

    DownloadProcessInfo({
        required this.status,
        this.file,
        required this.process,
        this.error,
        this.stackTrace
    });
}

/// Class that represents an in-progress download process.
/// 
/// Download is immediately started on instantiation, and can be cancelled via [cancel].
/// Information on the status of a download can be checked via the [stream] stream.
class DownloadProcess {
    final List<PostFile> files = [];
    final String? path;

    int _currentSize = 0;
    int _totalSize = 0;
    bool _completed = false;
    bool _cancelled = false;
    final Completer<bool> _completer = Completer<bool>();
    final StreamController<DownloadProcessInfo> _controller = StreamController.broadcast();

    DownloadProcess({required List<PostFile> files, this.path}) {
        if (files.isEmpty) {
            throw ArgumentError.value(files, "files", "List of files cannot be empty.");
        }

        this.files.clear();
        this.files.addAll(files);

        _totalSize = (files.length == 1) ? files.first.contentLength : files.length;
    
        _controller.sink.add(
            DownloadProcessInfo(
                status: DownloadProcessStatus.started, 
                process: this
            )
        );

        _start();
    }

    void cancel() {
        _cancelled = true;
        _controller.sink.add(
            DownloadProcessInfo(
                status: DownloadProcessStatus.cancelled,
                process: this
            )
        );
    }

    // Starts the actual procedure.
    void _start() async {
        final func = (files.length == 1) ? _downloadSingle : _downloadMultiple;
        
        try {
            await func();
        } catch (e, stackTrace) {
            Nokulog.e("HOW THE F*CK DID YOU GET HERE!?", error: e, stackTrace: stackTrace);
        }

        _finish();
    }

    /// Handles the download of a single file.
    Future<void> _downloadSingle() async {
        final PostFile file = files.first;

        _controller.sink.add(
            DownloadProcessInfo(
                status: DownloadProcessStatus.downloadStarted, 
                process: this,
                file: file
            )
        );

        final wasFetched = (DownloadManager.stored(file) != null);
        try {
            final Uint8List? data = await DownloadManager.fetch(file);

            if (_cancelled) {
                _controller.sink.add(
                    DownloadProcessInfo(
                        status: DownloadProcessStatus.cancelled, 
                        process: this
                    )
                );

                if (!wasFetched) {
                    DownloadManager.dispose(file);
                }
                return;
            }

            if (data == null) {
                _controller.sink.add(
                    DownloadProcessInfo(
                        status: DownloadProcessStatus.downloadFailed,
                        file: file,
                        process: this
                    )
                );
                file.clear();
                return;
            }

            await _storeFile(file, path);

            if (!wasFetched) {
                Nokulog.i("Download process will dispose of data for file ${file.filename}");
                DownloadManager.dispose(file);
            }
        } catch (e, stackTrace) {
            if (e is GalException) {
                Nokulog.e("${e.type.code}: ${e.type.message}", error: e, stackTrace: stackTrace);
                return;
            }

            Nokulog.e("An unexpected error occurred whilst downloading file \"${file.filename}\".", error: e, stackTrace: stackTrace);
            _controller.sink.add(
                DownloadProcessInfo(
                    status: DownloadProcessStatus.downloadFailed,
                    file: file,
                    process: this,
                    error: e,
                    stackTrace: stackTrace
                )
            );

            if (!wasFetched) {
                Nokulog.i("Download process will dispose of data for file ${file.filename}");
                DownloadManager.dispose(file);
            }
        }
    }

    /// Handles the download of multiple files via an [Executor].
    Future<void> _downloadMultiple() async {
        files.shuffle(_random);

        final Executor executor = Executor(concurrency: 3, rate: Rate.perSecond(5));

        for (final file in files) {
            executor.scheduleTask(() async {
                if (_cancelled) return;

                _controller.sink.add(
                    DownloadProcessInfo(
                        status: DownloadProcessStatus.downloadStarted,
                        process: this,
                        file: file,
                    )
                );

                final wasFetched = (DownloadManager.stored(file) != null);

                try {
                    final Uint8List? data = await DownloadManager.fetch(file);

                    if (data == null) {
                        _controller.sink.add(
                            DownloadProcessInfo(
                                status: DownloadProcessStatus.downloadFailed, 
                                process: this,
                                file: file
                            )
                        );
                        file.clear();
                        return;
                    }

                    await _storeFile(file, path);

                    if (!wasFetched) {
                        Nokulog.i("Download process will dispose of data for file ${file.filename}");
                        DownloadManager.dispose(file);
                    }

                    _currentSize++;
                    _controller.sink.add(
                        DownloadProcessInfo(
                            status: DownloadProcessStatus.downloadCompleted,
                            file: file,
                            process: this
                        )
                    );
                } catch (e, stackTrace) {
                    if (e is GalException) {
                        Nokulog.e("${e.type.code}: ${e.type.message}", error: e, stackTrace: stackTrace);
                        return;
                    }

                    Nokulog.e("An unexpected error occurred whilst downloading file \"${file.filename}\".", error: e, stackTrace: stackTrace);
                    _controller.sink.add(
                        DownloadProcessInfo(
                            status: DownloadProcessStatus.downloadFailed,
                            file: file,
                            process: this,
                            error: e,
                            stackTrace: stackTrace
                        )
                    );
                    
                    if (!wasFetched) {
                        Nokulog.i("Download process will dispose of data for file ${file.filename}");
                        DownloadManager.dispose(file);
                    }
                }
            });
        }

        await executor.join(withWaiting: true);
        await executor.close();
    }

    void _finish() async {
        _completed = !_cancelled;

        _controller.sink.add(
            DownloadProcessInfo(
                status: DownloadProcessStatus.completed, 
                process: this
            )
        );

        _completer.complete(_completed);
        _controller.close();

        _cleanUp();
    }

    /// We clean up and dispose of the files that were marked for disposal whilst the 
    /// download was in progress.
    void _cleanUp() {
        for (final file in files) {
            if (DownloadManager._pendingDispose.contains(file)) {
                file.clear();
                DownloadManager._pendingDispose.remove(file);
            }
        }
    }

    Stream<DownloadProcessInfo> get stream => _controller.stream;
    Future<bool> get future => _completer.future;
    bool get completed => _completed;
    bool get cancelled => _cancelled;
    int get currentSize => (files.length == 1) ? files.first.receivedLength : _currentSize;
    int get totalSize => (files.length == 1) ? files.first.contentLength : _totalSize;
    double get progress => (totalSize == 0) ? 0 : currentSize / totalSize;
    int get progressPercentage => (progress * 100).floor();
}

/// Represents a Download.
/// 
/// If the download is currently in progress, [process] will contain a [DownloadProcess]
/// object that can be used to keep track of the progress of the download.
class DownloadRecord {
    final String title;
    final String? path;
    final List<PostFile> files;
    final int fileCount;
    final DownloadProcess? process;
    final DateTime timestamp;

    DownloadRecord({
        required this.title,
        required this.path,
        required this.files,
        this.process,
        int? fileCount,
        DateTime? timestamp
    }) : timestamp = timestamp ?? DateTime.now(), fileCount = fileCount ?? files.length;
}

/// Class in charge of managing the life of [PostFile] data.
/// 
/// [fetch] and [dispose] can be used to both fetch the data of a file and dispose of it.
/// This class also contains methods for download a file, a post, or a list of posts.
/// 
/// This class should be used instead of manually calling [PostFile.fetch] since it avoids
/// early disposal if the file is being downloaded, and allows for these files to be automatically
/// disposed when no longer in use.
class DownloadManager {
    static final List<DownloadRecord> history = [];
    static final Set<PostFile> _pendingDispose = {};
    static final Set<PostFile> _registry = {};

    static PostFile? stored(PostFile file) => _registry.lookup(file);

    /// Fetches the data from a [PostFile] and stores the file in a registry to keep track of it.
    static Future<Uint8List?> fetch(PostFile file) async {
        if (_registry.contains(file)) {
            final storedFile = _registry.lookup(file)!;

            if (storedFile.data != null) {
                return storedFile.data!;
            }

            _registry.add(file);
            return await file.fetch();
        }
        
        final data = await file.fetch();
        
        if (data != null) {
            _registry.add(file);
        }

        return data;
    }

    /// Downloads a single [PostFile] and stores it.
    /// The file's data should have been fetched via [fetch].
    static Future<DownloadRecord?> downloadFile(PostFile file) async {
        if (!_registry.contains(file) && file.data != null) {
            Nokulog.w("Post file $file was not fetched via the registry.");
        }

        final downloadsDir = (isDesktop) ? await _getDownloadsDirectory() : null;
        
        if (downloadsDir == null && isDesktop) {
            return null;
        }
        
        final files = [file];
        final process = DownloadProcess(
            files: files,
            path: downloadsDir
        );
        final record = DownloadRecord(
            title: file.filename,
            process: process,
            path: (downloadsDir != null) ? "$downloadsDir/${file.filename}" : downloadsDir, 
            files: files
        );

        history.add(record);

        process.stream.listen((status) {
            if (status.status != DownloadProcessStatus.completed) {
                return;
            }

            Downloads.save(record);
        });
        
        await process.future;

        //history.last.path = await _resolveFilePath(file, null);
        return record;
    }

    /// Downloads the files of a [Post].
    static Future<DownloadRecord?> downloadPost(Post post) async {
        if (post.images.length == 1) {
            return downloadFile(post.data.first);
        }
        
        final downloadsDir = (isDesktop) ? await _getDownloadsDirectory() : null;
        
        if (downloadsDir == null && isDesktop) {
            return null;
        }

        String? postDir;
        
        if (downloadsDir != null) {
            postDir = "$downloadsDir/${_sanitize(post.title)}";
        }

        final process = DownloadProcess(files: post.data, path: postDir);
        final record = DownloadRecord(
            title: post.title,
            path: postDir,
            files: post.data,
            process: process
        );

        history.add(record);

        process.stream.listen((status) {
            if (status.status != DownloadProcessStatus.completed) {
                return;
            }

            Downloads.save(record);
        });

        await process.future;

        return record;
    }

    /// Downloads the files of a list of posts.
    static Future<DownloadRecord?> downloadPosts(List<Post> posts, String title) async {
        final downloadsDir = (isDesktop) ? await _getDownloadsDirectory() : null;
        
        if (downloadsDir == null && isDesktop) {
            return null;
        }

        String? postDir;
        
        if (downloadsDir != null) {
            postDir = "$downloadsDir/${_sanitize(title)}";
        }
        
        final files = posts.expand((post) => post.data).toList();
        final process = DownloadProcess(files: files, path: postDir);
        final record = DownloadRecord(
            title: title,
            path: postDir,
            files: files,
            process: process
        );

        process.stream.listen((status) {
            if (status.status != DownloadProcessStatus.completed) {
                return;
            }

            Downloads.save(record);
        });

        history.add(record);

        await process.future;

        return record;
    }

    /// Disposes of the data in a [PostFile].
    /// 
    /// If the file is currently being downloaded, it is marked for disposal and automatically disposed of
    /// when the file finishes.
    static void dispose(PostFile file) {
        if (file.inProgress || history.any((r) => r.files.contains(file) && r.process?.completed == false && r.process?.cancelled == false)) {
            _pendingDispose.add(file);
            _registry.remove(file);
            return;
        }

        file.clear();
        _registry.remove(file);
    }

    /// Sanitizes the string for use as a file / directory name.
    static String _sanitize(String input) => input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    /// Gets a directory for where to store the file(s) for a download.
    static Future<String?> _getDownloadsDirectory() async {
        // If the user prefers to just store to the selected directory, we just return the stored directory path.
        // Since Windows supports forward slashes, I prefer to switch backslashes to forward ones for standarization.
        if (!Settings.askDownloadDirectory.value) {
            return Settings.saveDirectory.value.replaceAll("\\", "/");
        }
    
        final userDirectory = await FilePicker.platform.getDirectoryPath(
            dialogTitle: "Select directory to download files.",
            initialDirectory: Settings.saveDirectory.value,
            lockParentWindow: true
        );

        return userDirectory?.replaceAll("\\", "/");
    }
}