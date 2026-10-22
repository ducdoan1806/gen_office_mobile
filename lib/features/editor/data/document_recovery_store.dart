import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../../documents/domain/office_document.dart';

class RecoverySnapshot {
  const RecoverySnapshot({
    required this.document,
    required this.createdAt,
    required this.baseHash,
    required this.contentPath,
    required this.contentHash,
  });
  final OfficeDocument document;
  final DateTime createdAt;
  final String? baseHash;
  final String contentPath;
  final String contentHash;
  Future<Uint8List> read() async {
    final bytes = await File(contentPath).readAsBytes();
    if (DocumentRecoveryStore.hash(bytes) != contentHash) {
      throw const FormatException(
        'Bản tạm bị hỏng. File gốc không bị thay đổi.',
      );
    }
    return bytes;
  }
}

/// App-private DOCX revisions. A directory rename publishes a complete snapshot;
/// interrupted writes are ignored and the preceding revision remains readable.
class DocumentRecoveryStore {
  DocumentRecoveryStore({Future<Directory> Function()? documentsDirectory})
    : _directory = documentsDirectory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directory;
  static const maxBytes = 32 * 1024 * 1024;
  static final _keys = RegExp(r'^[a-f0-9]{64}$');
  static final _revisions = RegExp(r'^[a-f0-9]{32}$');
  static final _queues = <String, Future<void>>{};
  static String hash(List<int> bytes) => sha256.convert(bytes).toString();
  String _key(String id) => hash(utf8.encode(id));
  String _revision() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  Future<Directory> _root() async =>
      Directory('${(await _directory()).path}/GenOffice/recovery');

  Future<T> _locked<T>(String key, Future<T> Function() action) async {
    final lockKey = Directory(key).absolute.uri.normalizePath().toString();
    final previous = _queues[lockKey] ?? Future<void>.value();
    final complete = Completer<void>();
    _queues[lockKey] = complete.future;
    try {
      await previous;
      return await action();
    } finally {
      complete.complete();
      if (identical(_queues[lockKey], complete.future)) _queues.remove(lockKey);
    }
  }

  Future<List<RecoverySnapshot>> _readGroup(Directory group) async {
    if (!await group.exists()) return [];
    final snapshots = <RecoverySnapshot>[];
    var committed = 0;
    await for (final entry in group.list(followLinks: false)) {
      final name = entry.uri.pathSegments.where((p) => p.isNotEmpty).last;
      if (entry is! Directory || !_revisions.hasMatch(name)) continue;
      committed++;
      try {
        final data =
            jsonDecode(await File('${entry.path}/snapshot.json').readAsString())
                as Map<String, dynamic>;
        if (data['version'] != 1 ||
            _key(data['id'] as String) !=
                group.uri.pathSegments.where((p) => p.isNotEmpty).last) {
          throw const FormatException('Metadata bản tạm không hợp lệ.');
        }
        final snapshot = RecoverySnapshot(
          document: OfficeDocument(
            id: data['id'] as String,
            name: data['name'] as String,
            format: DocumentFormat.values.byName(
              (data['format'] ?? 'docx') as String,
            ),
            sourceUri: data['sourceUri'] as String?,
            assetPath: data['assetPath'] as String?,
            filePath: data['filePath'] as String?,
            legacyDoc: data['legacyDoc'] == true,
            sourceHash: data['sourceHash'] as String?,
          ),
          createdAt: DateTime.parse(data['createdAt'] as String),
          baseHash: data['baseHash'] as String?,
          contentPath: '${entry.path}/content.docx',
          contentHash: data['contentHash'] as String,
        );
        final file = File(snapshot.contentPath);
        if (await file.length() > maxBytes) {
          throw const FormatException('Bản tạm quá lớn.');
        }
        await snapshot.read();
        snapshots.add(snapshot);
      } catch (_) {
        /* Try the preceding complete revision; never touch the source. */
      }
    }
    if (committed > 0 && snapshots.isEmpty) {
      throw const FormatException(
        'Không đọc được bản tạm. Dữ liệu được giữ lại để kiểm tra.',
      );
    }
    snapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return snapshots;
  }

  Future<List<RecoverySnapshot>> list() async {
    final root = await _root();
    if (!await root.exists()) return [];
    final result = <RecoverySnapshot>[];
    await for (final entry in root.list(followLinks: false)) {
      final key = entry.uri.pathSegments.where((p) => p.isNotEmpty).last;
      if (entry is! Directory || !_keys.hasMatch(key)) continue;
      final snapshots = await _locked(
        entry.absolute.path,
        () => _readGroup(entry),
      );
      if (snapshots.isNotEmpty) result.add(snapshots.first);
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<RecoverySnapshot?> find(String id) async {
    final group = Directory('${(await _root()).path}/${_key(id)}');
    return _locked(group.absolute.path, () async {
      final snapshots = await _readGroup(group);
      return snapshots.isEmpty ? null : snapshots.first;
    });
  }

  Future<void> write(
    OfficeDocument document,
    Uint8List bytes, {
    required String? baseHash,
  }) async {
    if (bytes.length < 4 ||
        bytes.length > maxBytes ||
        bytes[0] != 80 ||
        bytes[1] != 75) {
      throw const FormatException('Bản tạm DOCX không hợp lệ hoặc vượt 32 MB.');
    }
    final group = Directory('${(await _root()).path}/${_key(document.id)}');
    await _locked(group.absolute.path, () async {
      await group.create(recursive: true);
      final revision = _revision();
      final staging = Directory('${group.path}/.$revision.tmp');
      await staging.create();
      try {
        await File(
          '${staging.path}/content.docx',
        ).writeAsBytes(bytes, flush: true);
        await File('${staging.path}/snapshot.json').writeAsString(
          jsonEncode({
            'version': 1,
            'id': document.id,
            'name': document.name,
            'format': document.format.name,
            'sourceUri': document.sourceUri,
            'assetPath': document.assetPath,
            'filePath': document.filePath,
            'legacyDoc': document.legacyDoc,
            'sourceHash': document.sourceHash,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'baseHash': baseHash,
            'contentHash': hash(bytes),
          }),
          flush: true,
        );
        await staging.rename('${group.path}/$revision');
      } catch (_) {
        if (await staging.exists()) await staging.delete(recursive: true);
        rethrow;
      }
      // Cleanup failure must not turn a committed snapshot into a failed write.
      try {
        final snapshots = await _readGroup(group);
        final retained = snapshots
            .take(2)
            .map((s) => File(s.contentPath).parent.path)
            .toSet();
        await for (final entry in group.list(followLinks: false)) {
          final name = entry.uri.pathSegments.where((p) => p.isNotEmpty).last;
          if (entry is Directory &&
              _revisions.hasMatch(name) &&
              !retained.contains(entry.path)) {
            await entry.delete(recursive: true);
          }
        }
      } on FileSystemException {
        /* Retry cleanup on a later checkpoint. */
      }
    });
  }

  Future<void> clear(String id) async {
    final root = await _root();
    final group = Directory('${root.path}/${_key(id)}');
    await _locked(group.absolute.path, () async {
      if (!await group.exists()) return;
      // The rename is the durable discard. An interrupted cleanup cannot make
      // this draft reappear, and arbitrary metadata paths are never deleted.
      final removed = await group.rename(
        '${root.path}/.${_key(id)}.${_revision()}.deleted',
      );
      try {
        await removed.delete(recursive: true);
      } on FileSystemException {
        /* Discard is committed. */
      }
    });
  }
}
