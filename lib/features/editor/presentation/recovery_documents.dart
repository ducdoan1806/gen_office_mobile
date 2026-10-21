import 'package:flutter/material.dart';
import '../data/document_recovery_store.dart';

class RecoveryDocuments extends StatefulWidget {
  const RecoveryDocuments({
    super.key,
    required this.store,
    required this.onRestore,
  });
  final DocumentRecoveryStore store;
  final Future<void> Function(RecoverySnapshot) onRestore;
  @override
  State<RecoveryDocuments> createState() => _RecoveryDocumentsState();
}

class _RecoveryDocumentsState extends State<RecoveryDocuments> {
  late Future<List<RecoverySnapshot>> _pending = widget.store.list();
  bool _working = false;
  void _reload() => setState(() {
    _pending = widget.store.list();
  });
  Future<void> _act(RecoverySnapshot snapshot, bool restore) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      if (restore) {
        await widget.onRestore(snapshot);
      } else {
        if (!mounted) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bỏ bản tạm?'),
            content: Text(
              'Xóa các thay đổi chưa lưu của ${snapshot.document.name}? File gốc vẫn được giữ nguyên.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Bỏ bản tạm'),
              ),
            ],
          ),
        );
        if (discard != true) return;
        await widget.store.clear(snapshot.document.id);
      }
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không xử lý được bản tạm: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RecoverySnapshot>>(
    future: _pending,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ListTile(
          title: const Text('Không đọc được bản tạm khôi phục.'),
          trailing: TextButton(
            onPressed: _reload,
            child: const Text('Thử lại'),
          ),
        );
      }
      final documents = snapshot.data ?? [];
      if (documents.isEmpty) return const SizedBox.shrink();
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: SingleChildScrollView(
          child: Card(
            margin: const EdgeInsets.all(12),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('Có tài liệu chưa lưu'),
                  subtitle: Text('Khôi phục bản tạm để tiếp tục chỉnh sửa.'),
                ),
                for (final document in documents)
                  ListTile(
                    title: Text(document.document.name),
                    subtitle: Text('Bản tạm: ${document.createdAt.toLocal()}'),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Bỏ bản tạm',
                          onPressed: _working
                              ? null
                              : () => _act(document, false),
                          icon: const Icon(Icons.delete_outline),
                        ),
                        TextButton(
                          key: ValueKey('restore-${document.document.id}'),
                          onPressed: _working
                              ? null
                              : () => _act(document, true),
                          child: const Text('Khôi phục'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
