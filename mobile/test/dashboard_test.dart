import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vi_sinh_vien/api_client.dart';
import 'package:vi_sinh_vien/main.dart';

http.Response jsonResponse(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Map<String, dynamic> report({int income = 0, int expense = 0, int? limit}) => {
  'incomeVnd': income,
  'expenseVnd': expense,
  'balanceVnd': income - expense,
  'budgetLimitVnd': limit,
  'budgetPercent': limit == null ? null : expense * 100 / limit,
  'budgetStatus': limit == null
      ? 'unset'
      : expense > limit
      ? 'exceeded'
      : 'normal',
  'expenseByCategory': [],
};
void main() {
  testWidgets(
    'Dashboard uses real responses and starts empty without sample identity or transactions',
    (tester) async {
      viewport(tester, const Size(360, 900));
      final api = ApiClient(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/profile')) {
            return jsonResponse({'displayName': ''});
          }
          if (req.url.path.endsWith('/transactions')) {
            return jsonResponse({'items': [], 'total': 0});
          }
          return jsonResponse(report());
        }),
      );
      await tester.pumpWidget(FinanceApp(api: api));
      await tester.pumpAndSettle();
      expect(find.text('Chào bạn! 👋'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsNothing);
      await tester.scrollUntilVisible(find.text('Chưa có giao dịch'), 150);
      expect(find.text('Chưa có giao dịch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Dashboard displays server totals and warning at narrow width, privacy hides all amounts',
    (tester) async {
      viewport(tester, const Size(360, 900));
      final api = ApiClient(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/profile')) {
            return jsonResponse({'displayName': 'Minh'});
          }
          if (req.url.path.endsWith('/transactions')) {
            return jsonResponse({'items': [], 'total': 0});
          }
          return jsonResponse(
            report(income: 20000, expense: 35000, limit: 30000),
          );
        }),
      );
      await tester.pumpWidget(FinanceApp(api: api));
      await tester.pumpAndSettle();
      expect(find.text('Chào Minh! 👋'), findsOneWidget);
      expect(find.text('20.000 đ'), findsOneWidget);
      expect(find.text('-15.000 đ'), findsOneWidget);
      await tester.tap(find.byTooltip('Ẩn số tiền'));
      await tester.pumpAndSettle();
      expect(find.text('-15.000 đ'), findsNothing);
      expect(find.text('•••••• đ'), findsNWidgets(3));
      await tester.scrollUntilVisible(
        find.text('Đã vượt ngân sách tháng!'),
        100,
      );
      expect(find.text('Đã vượt ngân sách tháng!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Budget dialog saves integer VND and reloads persisted report', (
    tester,
  ) async {
    viewport(tester, const Size(600, 1200));
    int? limit;
    var reports = 0;
    final api = ApiClient(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/profile')) {
          return jsonResponse({'displayName': ''});
        }
        if (req.url.path.endsWith('/transactions')) {
          return jsonResponse({'items': [], 'total': 0});
        }
        if (req.method == 'PUT') {
          limit = (jsonDecode(req.body) as Map)['limitVnd'] as int;
          return jsonResponse({'limitVnd': limit});
        }
        reports++;
        return jsonResponse(report(limit: limit));
      }),
    );
    await tester.pumpWidget(FinanceApp(api: api));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thiết lập ngân sách'));
    await tester.tap(find.text('Thiết lập ngân sách'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '500000');
    await tester.tap(find.text('Lưu ngân sách'));
    await tester.pumpAndSettle();
    expect(limit, 500000);
    expect(reports, 2);
    await tester.ensureVisible(find.text('Đổi ngân sách'));
    expect(find.text('Đổi ngân sách'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Dashboard network failure has retry and does not fabricate totals',
    (tester) async {
      viewport(tester, const Size(360, 800));
      var failing = true;
      final api = ApiClient(
        client: MockClient((req) async {
          if (failing) {
            return http.Response(
              '{"message":"Không kết nối được PostgreSQL"}',
              503,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (req.url.path.endsWith('/profile')) {
            return jsonResponse({'displayName': ''});
          }
          if (req.url.path.endsWith('/transactions')) {
            return jsonResponse({'items': [], 'total': 0});
          }
          return jsonResponse(report());
        }),
      );
      await tester.pumpWidget(FinanceApp(api: api));
      await tester.pumpAndSettle();
      expect(find.text('Không kết nối được PostgreSQL'), findsOneWidget);
      expect(find.text('0 đ'), findsNothing);
      failing = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Chào bạn! 👋'), findsOneWidget);
    },
  );
}
