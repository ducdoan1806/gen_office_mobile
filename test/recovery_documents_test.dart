import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/features/documents/domain/office_document.dart';
import 'package:gen_office_mobile/features/editor/data/document_recovery_store.dart';
import 'package:gen_office_mobile/features/editor/presentation/recovery_documents.dart';

class MemoryRecoveryStore extends DocumentRecoveryStore {
  final pending = <RecoverySnapshot>[
    RecoverySnapshot(
      document: const OfficeDocument(
        id: 'doc',
        name: 'report.docx',
        format: DocumentFormat.docx,
      ),
      createdAt: DateTime.utc(2026, 10, 21),
      baseHash: null,
      contentPath: '/unused',
      contentHash: 'unused',
    ),
  ];
  @override
  Future<List<RecoverySnapshot>> list() async => List.of(pending);
  @override
  Future<void> clear(String id) async =>
      pending.removeWhere((s) => s.document.id == id);
}

void main() {
  testWidgets(
    'startup recovery offers restore and explicit discard with cancel',
    (tester) async {
      final store = MemoryRecoveryStore();
      var restores = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoveryDocuments(
              store: store,
              onRestore: (snapshot) async {
                expect(snapshot.document.id, 'doc');
                restores++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Có tài liệu chưa lưu'), findsOneWidget);
      await tester.tap(find.text('Khôi phục'));
      await tester.pumpAndSettle();
      expect(restores, 1);
      expect(store.pending, hasLength(1));
      await tester.tap(find.byTooltip('Bỏ bản tạm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(store.pending, hasLength(1));
      await tester.tap(find.byTooltip('Bỏ bản tạm'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Bỏ bản tạm'));
      await tester.pumpAndSettle();
      expect(store.pending, isEmpty);
      expect(find.text('Có tài liệu chưa lưu'), findsNothing);
    },
  );
}
