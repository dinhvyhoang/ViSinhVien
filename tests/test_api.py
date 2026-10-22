"""Run against the isolated PostgreSQL database created by test-api.sh."""
import json
import unittest
import urllib.error
import urllib.parse
import urllib.request
import uuid
import datetime
from concurrent.futures import ThreadPoolExecutor


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
    def add(self, amount=35000, date='2000-01-15', category=1, note='test'):
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
            'transactionDate': '2000-01-16', 'note': 'xe buýt'})
        self.assertEqual(status, 200)
        self.assertEqual(edited['amountVnd'], 42000)
        self.assertEqual(request('GET', path)[1]['categoryId'], 2)
        self.assertEqual(request('DELETE', path)[0], 204)
        self.assertEqual(request('GET', path)[0], 404)
        self.assertEqual(request('DELETE', path)[0], 404)

    def test_invalid_money_category_note_date(self):
        base = {'categoryId': 1, 'amountVnd': 35000, 'transactionDate': '2000-01-15', 'note': ''}
        for changes in [{'amountVnd': -1}, {'amountVnd': 0}, {'amountVnd': 1.5},
            {'amountVnd': 1000000000001}, {'categoryId': 999999}, {'note': 'a' * 501},
            {'transactionDate': '2000-02-30'}, {'transactionDate': '0001-01-01'}]:
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
            'amountVnd': 1, 'transactionDate': '2000-01-15'})[0], 400)
        self.assertEqual(request('GET', '/transactions/' + str(item['id']))[1]['categoryName'], name)
        self.assertEqual(request('PUT', '/transactions/' + str(item['id']), {
            'categoryId': category['id'], 'amountVnd': 36000, 'transactionDate': '2000-01-15'})[0], 200)
        self.assertEqual(request('PUT', path, {'name': name + ' edited', 'isArchived': False})[0], 200)

    def test_category_validation(self):
        for data in [{'name': '', 'type': 'income'}, {'name': 'x', 'type': 'wrong'},
            {'name': 'x' * 101, 'type': 'expense'}, {'name': 'Ăn uống', 'type': 'expense'}]:
            self.assertEqual(request('POST', '/categories', data)[0], 400)
        token = 'Ăn thử ' + uuid.uuid4().hex[:8]
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda name: request('POST', '/categories', {'name': name, 'type': 'expense'})[0], [token, token.upper()]))
        self.assertEqual(sorted(results), [201, 400])

    def test_filters_pagination_month_boundaries(self):
        token = uuid.uuid4().hex
        a = self.add(date='2001-01-31', category=1, note=token + ' ĂN TRƯA')
        self.add(date='2001-02-01', category=1, note=token)
        self.add(date='2001-01-31', category=5, note=token)
        query = urllib.parse.urlencode({'month': '2001-01', 'type': 'expense',
            'categoryId': 1, 'search': token, 'pageSize': 1})
        status, result = request('GET', '/transactions?' + query)
        self.assertEqual(status, 200)
        self.assertEqual(result['total'], 1)
        self.assertEqual(result['items'][0]['id'], a['id'])
        self.assertEqual(request('GET', '/transactions?' + query + '&page=2')[1]['items'], [])
        vietnamese = urllib.parse.urlencode({'month': '2001-01', 'search': token + ' ăn trưa'})
        self.assertEqual(request('GET', '/transactions?' + vietnamese)[1]['total'], 1)
        category_search = urllib.parse.urlencode({'month': '2001-01', 'search': 'ăn uống'})
        self.assertTrue(any(x['id'] == a['id'] for x in request('GET', '/transactions?' + category_search)[1]['items']))
        for query in ['month=2001-13', 'month=2001-1', 'type=no', 'page=0', 'pageSize=101']:
            self.assertEqual(request('GET', '/transactions?' + query)[0], 400)

    def test_report_and_budget_thresholds(self):
        self.add(amount=100000, date='2002-10-01', category=5)
        expense = self.add(amount=79000, date='2002-10-31')
        self.add(amount=999999, date='2002-11-01')
        request('PUT', '/budgets/2002-10', {'limitVnd': 100000})
        for amount, expected in [(79000, 'normal'), (80000, 'warning'), (100000, 'reached'), (100001, 'exceeded')]:
            request('PUT', '/transactions/' + str(expense['id']), {'categoryId': 1,
                'amountVnd': amount, 'transactionDate': '2002-10-31', 'note': ''})
            status, report = request('GET', '/reports/monthly?month=2002-10')
            self.assertEqual(status, 200)
            self.assertEqual(report['incomeVnd'], 100000)
            self.assertEqual(report['expenseVnd'], amount)
            self.assertEqual(report['balanceVnd'], 100000 - amount)
            self.assertEqual(report['budgetStatus'], expected)
            self.assertEqual(report['expenseByCategory'][0]['amountVnd'], amount)
        request('DELETE', '/transactions/' + str(expense['id']))
        self.assertEqual(request('GET', '/reports/monthly?month=2002-10')[1]['expenseVnd'], 0)

    def test_budget_upsert_validation(self):
        self.assertEqual(request('GET', '/budgets/2003-03')[1]['limitVnd'], None)
        for amount in [100000, 200000]:
            self.assertEqual(request('PUT', '/budgets/2003-03', {'limitVnd': amount})[0], 200)
            self.assertEqual(request('GET', '/budgets/2003-03')[1]['limitVnd'], amount)
        self.assertEqual(request('PUT', '/budgets/2003-03', {'limitVnd': 0})[0], 400)
        self.assertEqual(request('GET', '/budgets/2003-13')[0], 400)
        self.assertEqual(request('GET', '/reports/monthly?month=2003-13')[0], 400)
        self.assertEqual(request('GET', '/reports/monthly?month=2004-01')[1]['budgetStatus'], 'unset')
        with ThreadPoolExecutor(max_workers=4) as pool:
            statuses = list(pool.map(lambda amount: request('PUT', '/budgets/2003-04', {'limitVnd': amount})[0], [1000, 2000, 3000, 4000]))
        self.assertEqual(statuses, [200] * 4)
        self.assertIn(request('GET', '/budgets/2003-04')[1]['limitVnd'], [1000, 2000, 3000, 4000])

    def test_delete_monthly_budget_preserves_transactions_and_category_limits(self):
        month = '2008-07'
        self.assertEqual(request('GET', f'/budgets/{month}')[1]['status'], 'unset')
        self.assertEqual(request('DELETE', f'/budgets/{month}')[0], 404)
        self.assertEqual(request('PUT', f'/budgets/{month}', {'limitVnd': 100000})[0], 200)
        self.assertEqual(request('PUT', f'/budgets/{month}/categories/1', {'limitVnd': 50000})[0], 200)
        transaction = self.add(amount=42000, date='2008-07-12', category=1)
        self.assertEqual(request('DELETE', f'/budgets/{month}')[0], 204)
        budget = request('GET', f'/budgets/{month}')[1]
        self.assertEqual(budget['status'], 'unset')
        self.assertIsNone(budget['limitVnd'])
        self.assertEqual(budget['spentVnd'], 42000)
        row = next(x for x in budget['categoryBudgets'] if x['categoryId'] == 1)
        self.assertEqual(row['limitVnd'], 50000)
        self.assertEqual(row['spentVnd'], 42000)
        self.assertEqual(request('GET', f'/transactions/{transaction["id"]}')[0], 200)
        self.assertEqual(request('DELETE', f'/budgets/{month}')[0], 404)

    def test_empty_period_is_not_populated_with_mock_transactions(self):
        summary = request('GET', '/reports/summary?period=month&date=2017-03-20')[1]
        self.assertEqual(summary['incomeVnd'], 0)
        self.assertEqual(summary['expenseVnd'], 0)
        self.assertEqual(summary['transactionCount'], 0)
        self.assertEqual(summary['expenseByCategory'], [])
        transactions = request('GET', '/transactions?month=2017-03')[1]
        self.assertEqual(transactions['total'], 0)
        self.assertEqual(transactions['items'], [])

    def test_future_date_rejected(self):
        tomorrow = (datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=7))) + datetime.timedelta(days=1)).date()
        self.assertEqual(request('POST', '/transactions', {
            'categoryId': 1, 'amountVnd': 1, 'transactionDate': tomorrow.isoformat()})[0], 400)

    def test_period_reports_and_csv(self):
        self.add(amount=80, date='2005-01-03', note='=SUM(A1:A2), "note"')
        self.add(amount=20, date='2005-01-09', category=2)
        self.add(amount=200, date='2005-01-10', category=5)
        self.add(amount=300, date='2005-02-01')
        report = request('GET', '/reports/summary?period=week&date=2005-01-05')[1]
        self.assertEqual(report['startDate'], '2005-01-03')
        self.assertEqual(report['endDate'], '2005-01-09')
        self.assertEqual(report['expenseVnd'], 100)
        self.assertEqual(report['transactionCount'], 2)
        self.assertEqual(report['expenseByCategory'][0]['percent'], 80)
        monthly = request('GET', '/reports/summary?period=month&date=2005-01-05')[1]
        self.assertEqual(monthly['incomeVnd'], 200)
        self.assertEqual(monthly['balanceVnd'], 100)
        yearly = request('GET', '/reports/summary?period=year&date=2005-01-05')[1]
        self.assertEqual(yearly['expenseVnd'], 400)
        for query in ['period=bad&date=2005-01-01', 'period=week&date=2005-02-30', 'period=month&date=0001-01-01']:
            self.assertEqual(request('GET', '/reports/summary?' + query)[0], 400)
        with urllib.request.urlopen('http://127.0.0.1:5081/api/reports/export?period=week&date=2005-01-05') as response:
            raw = response.read()
            self.assertTrue(raw.startswith(b'\xef\xbb\xbf'))
            csv = raw.decode('utf-8-sig')
            self.assertIn("'=SUM(A1:A2)", csv)
            self.assertIn('""note""', csv)
            self.assertIn('2005-01-09', csv)
            self.assertNotIn('2005-01-10', csv)

    def test_category_budgets_and_archived_history(self):
        self.assertEqual(request('PUT', '/budgets/2006-01', {'limitVnd': 1000})[0], 200)
        for category, amount in [(1, 100), (2, 200)]:
            self.assertEqual(request('PUT', f'/budgets/2006-01/categories/{category}', {'limitVnd': amount})[0], 200)
        expense = self.add(amount=80, date='2006-01-15')
        for amount, status in [(79, 'normal'), (80, 'warning'), (100, 'reached'), (101, 'exceeded')]:
            request('PUT', f'/transactions/{expense["id"]}', {'categoryId': 1, 'amountVnd': amount, 'transactionDate': '2006-01-15'})
            result = request('GET', '/budgets/2006-01')[1]
            row = next(x for x in result['categoryBudgets'] if x['categoryId'] == 1)
            self.assertEqual(row['status'], status)
            self.assertEqual(row['remainingVnd'], 100 - amount)
            self.assertEqual(result['spentVnd'], amount)
            self.assertEqual(result['remainingVnd'], 1000 - amount)
        self.assertEqual(request('PUT', '/budgets/2006-01/categories/5', {'limitVnd': 1})[0], 400)
        self.assertEqual(request('PUT', '/budgets/2006-01/categories/1', {'limitVnd': 0})[0], 400)
        self.assertEqual(request('DELETE', '/budgets/2006-01/categories/1')[0], 204)
        row = next(x for x in request('GET', '/budgets/2006-01')[1]['categoryBudgets'] if x['categoryId'] == 1)
        self.assertEqual(row['limitVnd'], None)
        self.assertEqual(row['status'], 'unset')

    def test_profile_persistence_and_validation(self):
        self.assertEqual(request('GET', '/profile')[1]['displayName'], '')
        self.assertEqual(request('PUT', '/profile', {'displayName': '  Sinh viên kiểm thử  '})[0], 200)
        self.assertEqual(request('GET', '/profile')[1]['displayName'], 'Sinh viên kiểm thử')
        self.assertEqual(request('PUT', '/profile', {'displayName': 'x' * 81})[0], 400)
        self.assertEqual(request('PUT', '/profile', {'displayName': 'bad\nname'})[0], 400)

    def test_missing_default_categories(self):
        categories = request('GET', '/categories')[1]
        for name in ['Tiền trọ', 'Giải trí', 'Chi khác', 'Học bổng', 'Thu khác']:
            self.assertTrue(any(x['name'] == name for x in categories), name)
