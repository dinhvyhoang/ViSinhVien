import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vi_sinh_vien/api_client.dart';
import 'package:vi_sinh_vien/screens/budget_screen.dart';
import 'package:vi_sinh_vien/screens/statistics_screen.dart';
import 'package:vi_sinh_vien/ui.dart';

http.Response jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  for (final size in [const Size(360, 800), const Size(320, 700)]) {
    testWidgets('Budget supports long names and large values at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ApiClient(
        client: MockClient(
          (req) async => jsonResponse({
            'month': '2026-10',
            'limitVnd': 1000000000000,
            'spentVnd': 999999999999,
            'categoryBudgets': [
              {
                'categoryId': 1,
                'categoryName':
                    'Tiền trọ và chi phí sinh hoạt sinh viên trong ký túc xá trường đại học',
                'limitVnd': 1000000000000,
                'spentVnd': 999999999999,
                'isArchived': false,
              },
            ],
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: financeTheme(),
          home: BudgetScreen(api: api, initialMonth: DateTime(2026, 10)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('Stats supports long legend and large values at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ApiClient(
        client: MockClient(
          (req) async => jsonResponse({
            'incomeVnd': 1000000000000,
            'expenseVnd': 999999999999,
            'balanceVnd': 1,
            'transactionCount': 100000,
            'expenseByCategory': [
              {
                'categoryId': 1,
                'categoryName':
                    'Tiền trọ và chi phí sinh hoạt sinh viên trong ký túc xá trường đại học',
                'amountVnd': 999999999999,
                'transactionCount': 100000,
              },
            ],
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: financeTheme(),
          home: StatisticsScreen(api: api, initialMonth: DateTime(2026, 10)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'CSV export launches the selected API period after a health check',
    (tester) async {
      String? launchedUrl;
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'launch') {
              launchedUrl = (call.arguments as Map)['url'] as String;
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      var healthChecked = false;
      final api = ApiClient(
        baseUrl: 'http://127.0.0.1:5080',
        client: MockClient((req) async {
          if (req.url.path == '/api/health') {
            healthChecked = true;
            return jsonResponse({'status': 'ok'});
          }
          return jsonResponse({
            'incomeVnd': 0,
            'expenseVnd': 0,
            'balanceVnd': 0,
            'transactionCount': 0,
            'expenseByCategory': <dynamic>[],
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: financeTheme(),
          home: StatisticsScreen(
            api: api,
            initialMonth: DateTime(2026, 10, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Năm'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Xuất báo cáo CSV'), 250);
      await tester.tap(find.text('Xuất báo cáo CSV'));
      await tester.pumpAndSettle();
      expect(healthChecked, isTrue);
      expect(
        launchedUrl,
        'http://127.0.0.1:5080/api/reports/export?period=year&date=2026-10-15',
      );
    },
  );
  testWidgets(
    'Budget persists the entered monthly limit and renders API totals',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? limit;
      var reads = 0;
      final api = ApiClient(
        client: MockClient((req) async {
          expect(req.url.path, '/api/budgets/2026-10');
          if (req.method == 'PUT') {
            limit = jsonDecode(req.body)['limitVnd'] as int;
            return jsonResponse({'limitVnd': limit});
          }
          reads++;
          return jsonResponse({
            'month': '2026-10',
            'limitVnd': limit,
            'spentVnd': 1700000,
            'categoryBudgets': <dynamic>[],
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: financeTheme(),
          home: BudgetScreen(api: api, initialMonth: DateTime(2026, 10)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa thiết lập'), findsWidgets);
      await tester.tap(find.text('Thiết lập'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '2000000');
      await tester.tap(find.text('Lưu hạn mức'));
      await tester.pumpAndSettle();
      expect(limit, 2000000);
      expect(reads, 2);
      expect(find.text('Mức chạm cảnh báo (85.0%)'), findsOneWidget);
      expect(find.text('300.000 đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Removing the monthly cap requires confirmation and keeps spending',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var hasLimit = true;
      var deletes = 0;
      final api = ApiClient(
        client: MockClient((req) async {
          expect(req.url.path, '/api/budgets/2026-10');
          if (req.method == 'DELETE') {
            deletes++;
            hasLimit = false;
            return http.Response('', 204);
          }
          return jsonResponse({
            'month': '2026-10',
            'limitVnd': hasLimit ? 2000000 : null,
            'spentVnd': 1700000,
            'categoryBudgets': <dynamic>[],
          });
        }),
      );
      await tester.pumpWidget(MaterialApp(
        theme: financeTheme(),
        home: BudgetScreen(api: api, initialMonth: DateTime(2026, 10)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gỡ ngân sách tháng'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      await tester.tap(find.text('Hủy').last);
      await tester.pumpAndSettle();
      expect(deletes, 0);
      await tester.tap(find.text('Gỡ ngân sách tháng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gỡ hạn mức'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.text('Chưa thiết lập'), findsWidgets);
      expect(find.text('1.700.000 đ'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Stats changes reporting periods and clears chart for empty API data',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final periods = <String>[];
      final api = ApiClient(
        client: MockClient((req) async {
          expect(req.url.path, '/api/reports/summary');
          final period = req.url.queryParameters['period']!;
          periods.add(period);
          return jsonResponse({
            'incomeVnd': 0,
            'expenseVnd': period == 'month' ? 100000 : 0,
            'balanceVnd': period == 'month' ? -100000 : 0,
            'transactionCount': period == 'month' ? 1 : 0,
            'expenseByCategory': period == 'month'
                ? [
                    {
                      'categoryId': 1,
                      'categoryName': 'Tiền trọ',
                      'amountVnd': 100000,
                      'transactionCount': 1,
                    },
                  ]
                : <dynamic>[],
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: financeTheme(),
          home: StatisticsScreen(
            api: api,
            initialMonth: DateTime(2026, 10, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 giao dịch ghi nhận'), findsOneWidget);
      expect(find.text('Tiền trọ (100.0%)'), findsOneWidget);
      await tester.tap(find.text('Tuần'));
      await tester.pumpAndSettle();
      expect(periods, ['month', 'week']);
      expect(find.text('Chưa có khoản chi trong kỳ này.'), findsOneWidget);
      expect(find.text('Tiền trọ (100.0%)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
