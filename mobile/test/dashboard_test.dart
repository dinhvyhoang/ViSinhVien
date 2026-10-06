import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vi_sinh_vien/api_client.dart';
import 'package:vi_sinh_vien/main.dart';

void main() {
  testWidgets(
    'Dashboard displays totals, warning and category chart on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ApiClient(
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'incomeVnd': 20000,
              'expenseVnd': 35000,
              'balanceVnd': -15000,
              'budgetLimitVnd': 30000,
              'budgetPercent': 116.67,
              'budgetStatus': 'exceeded',
              'expenseByCategory': [
                {
                  'categoryId': 1,
                  'categoryName': 'Ăn uống',
                  'amountVnd': 35000,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await tester.pumpWidget(FinanceApp(api: api));
      await tester.pumpAndSettle();
      expect(find.text('20.000 đ'), findsOneWidget);
      expect(
        find.text('−15.000 đ'),
        findsNothing,
      ); // intl uses the normal minus sign.
      expect(find.text('-15.000 đ'), findsOneWidget);
      expect(find.text('Đã vượt ngân sách tháng!'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ăn uống'), 150);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Budget dialog saves integer VND and reloads the report', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? limit;
    var reports = 0;
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.method == 'PUT') {
          limit = (jsonDecode(req.body) as Map)['limitVnd'] as int;
          return http.Response('{}', 200);
        }
        reports++;
        return http.Response(
          jsonEncode({
            'incomeVnd': 0,
            'expenseVnd': 0,
            'balanceVnd': 0,
            'budgetLimitVnd': limit,
            'budgetPercent': limit == null ? null : 0,
            'budgetStatus': limit == null ? 'unset' : 'normal',
            'expenseByCategory': [],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(FinanceApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thiết lập ngân sách'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '500000');
    await tester.tap(find.text('Lưu ngân sách'));
    await tester.pumpAndSettle();
    expect(limit, 500000);
    expect(reports, 2);
    expect(find.text('Đổi ngân sách'), findsOneWidget);
  });
}
