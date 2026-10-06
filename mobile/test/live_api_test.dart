import 'package:flutter_test/flutter_test.dart';
import 'package:vi_sinh_vien/api_client.dart';

// Run against the isolated database using RUN_FLUTTER_LIVE=1 scripts/test-api.sh.
void main() {
  const live = bool.fromEnvironment('LIVE_API');
  test(
    'Flutter HTTP client writes 35,000 VND to PostgreSQL and reads it back',
    () async {
      final api = ApiClient();
      int? id;
      try {
        final categories = await api.categories();
        expect(categories.any((c) => c.name == 'Ăn uống'), isTrue);
        final created =
            await api.request(
                  'POST',
                  '/transactions',
                  body: {
                    'categoryId': 1,
                    'amountVnd': 35000,
                    'transactionDate': '2099-10-15',
                    'note': 'Flutter live test',
                  },
                )
                as Map;
        id = (created['id'] as num).toInt();
        final read = await api.request('GET', '/transactions/$id') as Map;
        expect(read['amountVnd'], 35000);
        expect(read['categoryName'], 'Ăn uống');
        final list =
            await api.request(
                  'GET',
                  '/transactions',
                  query: {'month': '2099-10', 'search': 'Flutter live test'},
                )
                as Map;
        expect((list['items'] as List).any((x) => x['id'] == id), isTrue);
        await api.request(
          'PUT',
          '/transactions/$id',
          body: {
            'categoryId': 1,
            'amountVnd': 42000,
            'transactionDate': '2099-10-15',
            'note': 'Updated Flutter live test',
          },
        );
        final report =
            await api.request(
                  'GET',
                  '/reports/monthly',
                  query: {'month': '2099-10'},
                )
                as Map;
        expect(report['expenseVnd'], 42000);
        await api.request('DELETE', '/transactions/$id');
        id = null;
        final after =
            await api.request(
                  'GET',
                  '/reports/monthly',
                  query: {'month': '2099-10'},
                )
                as Map;
        expect(after['expenseVnd'], 0);
      } finally {
        if (id != null) await api.request('DELETE', '/transactions/$id');
        api.close();
      }
    },
    skip: !live,
  );

  test('Flutter receives the real backend validation message', () async {
    final api = ApiClient();
    try {
      await expectLater(
        api.request(
          'POST',
          '/transactions',
          body: {
            'categoryId': 1,
            'amountVnd': -1,
            'transactionDate': '2099-10-15',
            'note': '',
          },
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Số tiền'),
          ),
        ),
      );
    } finally {
      api.close();
    }
  }, skip: !live);
}
