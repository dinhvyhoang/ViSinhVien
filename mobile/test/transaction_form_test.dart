import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vi_sinh_vien/api_client.dart';
import 'package:vi_sinh_vien/screens/transaction_form.dart';

const categories = [
  {'id': 1, 'name': 'Ăn uống', 'type': 'expense', 'isArchived': false},
  {'id': 2, 'name': 'Làm thêm', 'type': 'income', 'isArchived': false},
];

Future<void> openForm(WidgetTester tester, ApiClient api) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TransactionForm(api: api),
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
}

Future<void> fillForm(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ăn uống').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('amount')), '35000');
  await tester.enterText(find.byKey(const Key('note')), 'Ăn trưa');
  await tester.ensureVisible(find.text('Lưu giao dịch'));
}

void main() {
  testWidgets('Invalid input never sends a transaction', (tester) async {
    var writes = 0;
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.method == 'POST') writes++;
        return http.Response(
          jsonEncode(categories),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await openForm(tester, api);
    await tester.ensureVisible(find.text('Lưu giao dịch'));
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn danh mục'), findsOneWidget);
    expect(writes, 0);
    await fillForm(tester);
    await tester.enterText(find.byKey(const Key('amount')), '0');
    await tester.ensureVisible(find.text('Lưu giao dịch'));
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
    expect(writes, 0);
  });

  testWidgets('Save sends VND and category, then closes only on success', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.method == 'POST') {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response('{"id":1}', 201);
        }
        return http.Response(
          jsonEncode(categories),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await openForm(tester, api);
    await fillForm(tester);
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
    expect(sent!['amountVnd'], 35000);
    expect(sent!['categoryId'], 1);
    expect(sent!['note'], 'Ăn trưa');
    expect(find.byType(TransactionForm), findsNothing);
  });

  testWidgets('Backend error retains the amount and note for retry', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient(
        (req) async => req.method == 'POST'
            ? http.Response(
                '{"message":"PostgreSQL chưa sẵn sàng"}',
                503,
                headers: {'content-type': 'application/json; charset=utf-8'},
              )
            : http.Response(
                jsonEncode(categories),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
      ),
    );
    await openForm(tester, api);
    await fillForm(tester);
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('PostgreSQL chưa sẵn sàng'), findsOneWidget);
    final amount = tester.widget<TextFormField>(
      find.byKey(const Key('amount')),
    );
    final note = tester.widget<TextFormField>(find.byKey(const Key('note')));
    expect(amount.controller!.text, '35000');
    expect(note.controller!.text, 'Ăn trưa');
  });

  testWidgets('Rapid repeated save cannot submit twice', (tester) async {
    var writes = 0;
    final pending = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.method == 'POST') {
          writes++;
          return pending.future;
        }
        return http.Response(
          jsonEncode(categories),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await openForm(tester, api);
    await fillForm(tester);
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Đang xử lý…'),
          )
          .onPressed,
      isNull,
    );
    expect(writes, 1);
    pending.complete(http.Response('{"id":1}', 201));
    await tester.pumpAndSettle();
  });
}
