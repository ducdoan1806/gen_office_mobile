import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gen_office_mobile/app/app.dart';
import 'package:gen_office_mobile/app/dependencies.dart';

void main() {
  testWidgets('preserves existing factory AI mock on the demo page', (
    tester,
  ) async {
    await tester.pumpWidget(GenOfficeApp(dependencies: AppDependencies.mock()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hướng dẫn an toàn.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Vùng editor Office'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tóm tắt');
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(
      find.textContaining('API AI nội bộ chưa được kết nối'),
      findsOneWidget,
    );
  });
}
