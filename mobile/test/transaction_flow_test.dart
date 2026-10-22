import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vi_sinh_vien/api_client.dart';
import 'package:vi_sinh_vien/models.dart';
import 'package:vi_sinh_vien/ui.dart';
import 'package:vi_sinh_vien/screens/transaction_form.dart';
import 'package:vi_sinh_vien/screens/transaction_detail.dart';

void main() {
  testWidgets('Phone form starts empty and switches real category types', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var writes = 0;
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.method != 'GET') writes++;
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'Ăn uống',
              'type': 'expense',
              'isArchived': false,
            },
            {
              'id': 2,
              'name': 'Làm thêm',
              'type': 'income',
              'isArchived': false,
            },
            {'id': 3, 'name': 'Đã ẩn', 'type': 'expense', 'isArchived': true},
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: financeTheme(),
        home: TransactionForm(api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('amount')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('Đã ẩn'), findsNothing);
    expect(find.text('Làm thêm'), findsNothing);
    await tester.tap(find.text('+50k'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+100k'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('amount')))
          .controller!
          .text,
      '150000',
    );
    await tester.tap(find.text('Khoản Thu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Làm thêm'));
    expect(find.text('Ăn uống'), findsNothing);
    expect(find.text('Làm thêm'), findsOneWidget);
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Detail reads latest record and delete requires confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = {
      'id': 10,
      'categoryId': 1,
      'categoryName': 'Ăn uống',
      'type': 'expense',
      'amountVnd': 42000,
      'transactionDate': '2026-01-01',
      'note': 'Bữa trưa',
    };
    var deletes = 0;
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.method == 'DELETE') {
          deletes++;
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode(record),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: financeTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(
                    api: api,
                    transaction: FinanceTransaction.fromJson(record),
                  ),
                ),
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.text('Bữa trưa'), findsOneWidget);
    await tester.ensureVisible(find.text('Xóa giao dịch'));
    await tester.tap(find.text('Xóa giao dịch'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    await tester.tap(find.text('Xóa giao dịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(find.byType(TransactionDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
