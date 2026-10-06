"""Run against the isolated PostgreSQL database created by test-api.sh."""
import json
import unittest
import urllib.error
import urllib.parse
import urllib.request
import uuid


def request(method, path, data=None):
    req = urllib.request.Request('http://127.0.0.1:5081/api' + path,
        data=None if data is None else json.dumps(data).encode(), method=method,
        headers={'Content-Type': 'application/json'})
    try:
        response = urllib.request.urlopen(req, timeout=10)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        raw = response.read()
        return response.status, json.loads(raw) if raw else None


class FinanceApiTests(unittest.TestCase):
    def add(self, amount=35000, date='2090-01-15', category=1, note='test'):
        status, item = request('POST', '/transactions', {
            'categoryId': category, 'amountVnd': amount, 'transactionDate': date, 'note': note})
        self.assertEqual(status, 201, item)
        return item

    def test_health_and_seed_categories(self):
        self.assertEqual(request('GET', '/health')[1]['status'], 'ok')
        status, items = request('GET', '/categories')
        self.assertEqual(status, 200)
        self.assertTrue(any(x['name'] == 'Ăn uống' for x in items))

    def test_create_read_update_delete(self):
        item = self.add()
        path = '/transactions/' + str(item['id'])
        self.assertEqual(request('GET', path)[1]['amountVnd'], 35000)
        status, edited = request('PUT', path, {'categoryId': 2, 'amountVnd': 42000,
            'transactionDate': '2090-01-16', 'note': 'xe buýt'})
        self.assertEqual(status, 200)
        self.assertEqual(edited['amountVnd'], 42000)
        self.assertEqual(request('GET', path)[1]['categoryId'], 2)
        self.assertEqual(request('DELETE', path)[0], 204)
        self.assertEqual(request('GET', path)[0], 404)
        self.assertEqual(request('DELETE', path)[0], 404)

    def test_invalid_money_category_note_date(self):
        base = {'categoryId': 1, 'amountVnd': 35000, 'transactionDate': '2090-01-15', 'note': ''}
        for changes in [{'amountVnd': -1}, {'amountVnd': 0}, {'amountVnd': 1.5},
            {'amountVnd': 1000000000001}, {'categoryId': 999999}, {'note': 'a' * 501},
            {'transactionDate': '2090-02-30'}, {'transactionDate': '0001-01-01'}]:
            with self.subTest(changes=changes):
                self.assertEqual(request('POST', '/transactions', base | changes)[0], 400)

    def test_archive_preserves_history(self):
        name = 'Archive ' + uuid.uuid4().hex[:8]
        status, category = request('POST', '/categories', {'name': name, 'type': 'expense'})
        self.assertEqual(status, 201)
        item = self.add(category=category['id'])
        path = '/categories/' + str(category['id'])
        self.assertEqual(request('PUT', path, {'name': name, 'isArchived': True})[0], 200)
        self.assertEqual(request('POST', '/transactions', {'categoryId': category['id'],
            'amountVnd': 1, 'transactionDate': '2090-01-15'})[0], 400)
        self.assertEqual(request('GET', '/transactions/' + str(item['id']))[1]['categoryName'], name)
        self.assertEqual(request('PUT', '/transactions/' + str(item['id']), {
            'categoryId': category['id'], 'amountVnd': 36000, 'transactionDate': '2090-01-15'})[0], 200)
        self.assertEqual(request('PUT', path, {'name': name + ' edited', 'isArchived': False})[0], 200)

    def test_category_validation(self):
        for data in [{'name': '', 'type': 'income'}, {'name': 'x', 'type': 'wrong'},
            {'name': 'x' * 101, 'type': 'expense'}, {'name': 'Ăn uống', 'type': 'expense'}]:
            self.assertEqual(request('POST', '/categories', data)[0], 400)

    def test_filters_pagination_month_boundaries(self):
        token = uuid.uuid4().hex
        a = self.add(date='2091-01-31', category=1, note=token)
        self.add(date='2091-02-01', category=1, note=token)
        self.add(date='2091-01-31', category=5, note=token)
        query = urllib.parse.urlencode({'month': '2091-01', 'type': 'expense',
            'categoryId': 1, 'search': token, 'pageSize': 1})
        status, result = request('GET', '/transactions?' + query)
        self.assertEqual(status, 200)
        self.assertEqual(result['total'], 1)
        self.assertEqual(result['items'][0]['id'], a['id'])
        self.assertEqual(request('GET', '/transactions?' + query + '&page=2')[1]['items'], [])
        for query in ['month=2091-13', 'month=2091-1', 'type=no', 'page=0', 'pageSize=101']:
            self.assertEqual(request('GET', '/transactions?' + query)[0], 400)

    def test_report_and_budget_thresholds(self):
        self.add(amount=100000, date='2092-10-01', category=5)
        expense = self.add(amount=79000, date='2092-10-31')
        self.add(amount=999999, date='2092-11-01')
        request('PUT', '/budgets/2092-10', {'limitVnd': 100000})
        for amount, expected in [(79000, 'normal'), (80000, 'warning'), (100000, 'reached'), (100001, 'exceeded')]:
            request('PUT', '/transactions/' + str(expense['id']), {'categoryId': 1,
                'amountVnd': amount, 'transactionDate': '2092-10-31', 'note': ''})
            status, report = request('GET', '/reports/monthly?month=2092-10')
            self.assertEqual(status, 200)
            self.assertEqual(report['incomeVnd'], 100000)
            self.assertEqual(report['expenseVnd'], amount)
            self.assertEqual(report['balanceVnd'], 100000 - amount)
            self.assertEqual(report['budgetStatus'], expected)
            self.assertEqual(report['expenseByCategory'][0]['amountVnd'], amount)
        request('DELETE', '/transactions/' + str(expense['id']))
        self.assertEqual(request('GET', '/reports/monthly?month=2092-10')[1]['expenseVnd'], 0)

    def test_budget_upsert_validation(self):
        self.assertEqual(request('GET', '/budgets/2093-03')[1]['limitVnd'], None)
        for amount in [100000, 200000]:
            self.assertEqual(request('PUT', '/budgets/2093-03', {'limitVnd': amount})[0], 200)
            self.assertEqual(request('GET', '/budgets/2093-03')[1]['limitVnd'], amount)
        self.assertEqual(request('PUT', '/budgets/2093-03', {'limitVnd': 0})[0], 400)
        self.assertEqual(request('GET', '/budgets/2093-13')[0], 400)
        self.assertEqual(request('GET', '/reports/monthly?month=2093-13')[0], 400)
        self.assertEqual(request('GET', '/reports/monthly?month=2094-01')[1]['budgetStatus'], 'unset')
