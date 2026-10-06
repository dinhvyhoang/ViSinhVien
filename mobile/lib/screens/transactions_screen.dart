import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';
import 'transaction_form.dart';

class TransactionsScreen extends StatefulWidget {
  final ApiClient api;
  const TransactionsScreen({super.key, required this.api});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _type = '';
  int? _category;
  int _page = 1, _total = 0, _request = 0;
  List<Category> _categories = [];
  List<FinanceTransaction> _items = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cats = await widget.api.categories();
      final data =
          await widget.api.request(
                'GET',
                '/transactions',
                query: {
                  'month': monthKey(_month),
                  'page': '$_page',
                  'pageSize': '20',
                  if (_type.isNotEmpty) 'type': _type,
                  if (_category != null) 'categoryId': '$_category',
                  if (_search.text.trim().isNotEmpty)
                    'search': _search.text.trim(),
                },
              )
              as Map<String, dynamic>;
      if (!mounted || request != _request) return;
      setState(() {
        _categories = cats;
        _items = (data['items'] as List)
            .map((x) => FinanceTransaction.fromJson(x))
            .toList();
        _total = (data['total'] as num).toInt();
        _loading = false;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _open([FinanceTransaction? transaction]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TransactionForm(api: widget.api, transaction: transaction),
      ),
    );
    if (changed == true && mounted) {
      _page = 1;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Giao dịch')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _open(),
      tooltip: 'Thêm giao dịch',
      child: const Icon(Icons.add),
    ),
    body: Column(
      children: [
        MonthSelector(
          month: _month,
          onChanged: (month) {
            _month = month;
            _page = 1;
            _load();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Tìm ghi chú hoặc danh mục',
              suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                icon: const Icon(Icons.search),
                onPressed: () {
                  _page = 1;
                  _load();
                },
              ),
            ),
            onSubmitted: (_) {
              _page = 1;
              _load();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Loại'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Tất cả')),
                    DropdownMenuItem(value: 'income', child: Text('Thu')),
                    DropdownMenuItem(value: 'expense', child: Text('Chi')),
                  ],
                  onChanged: (value) {
                    _type = value!;
                    _category = null;
                    _page = 1;
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('filter-$_type-$_category'),
                  initialValue: _category ?? 0,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('Tất cả')),
                    ..._categories
                        .where((c) => _type.isEmpty || c.type == _type)
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  ],
                  onChanged: (value) {
                    _category = value == 0 ? null : value;
                    _page = 1;
                    _load();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: ErrorNotice(message: _error!, retry: _load),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Chưa có giao dịch phù hợp.'),
                          ),
                        ),
                      for (var i = 0; i < _items.length; i++) ...[
                        if (i == 0 ||
                            dateKey(_items[i].date) !=
                                dateKey(_items[i - 1].date))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_items[i].date),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ListTile(
                          onTap: () => _open(_items[i]),
                          title: Text(_items[i].categoryName),
                          subtitle: _items[i].note.isEmpty
                              ? null
                              : Text(
                                  _items[i].note,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: Text(
                            '${_items[i].type == 'income' ? '+' : '−'}${money(_items[i].amountVnd)}',
                            style: TextStyle(
                              color: _items[i].type == 'income'
                                  ? Colors.teal
                                  : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Trang trước',
              onPressed: _loading || _page <= 1
                  ? null
                  : () {
                      _page--;
                      _load();
                    },
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Trang $_page · $_total giao dịch'),
            IconButton(
              tooltip: 'Trang sau',
              onPressed: _loading || _page * 20 >= _total
                  ? null
                  : () {
                      _page++;
                      _load();
                    },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    ),
  );
}
