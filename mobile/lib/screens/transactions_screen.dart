import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';
import '../ui.dart';
import 'transaction_form.dart';
import 'transaction_detail.dart';

class TransactionsScreen extends StatefulWidget {
  final ApiClient api;
  final DateTime? initialMonth;
  const TransactionsScreen({super.key, required this.api, this.initialMonth});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  late DateTime _month =
      widget.initialMonth ??
      DateTime(DateTime.now().year, DateTime.now().month);
  Timer? _debounce;
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
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    final query = {
      'month': monthKey(_month),
      'page': '$_page',
      'pageSize': '20',
      if (_type.isNotEmpty) 'type': _type,
      if (_category != null) 'categoryId': '$_category',
      if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
    };
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.categories(),
        widget.api.request('GET', '/transactions', query: query),
      ]);
      final data = results[1] as Map<String, dynamic>;
      if (!mounted || request != _request) return;
      setState(() {
        _categories = results[0] as List<Category>;
        _items = (data['items'] as List)
            .map((x) => FinanceTransaction.fromJson(x))
            .toList();
        _total = (data['total'] as num).toInt();
        _loading = false;
      });
      if (_items.isEmpty && _page > 1 && _total > 0) {
        _page = ((_total - 1) ~/ 20) + 1;
        await _load();
      }
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
        builder: (_) => transaction == null
            ? TransactionForm(api: widget.api)
            : TransactionDetailScreen(
                api: widget.api,
                transaction: transaction,
              ),
      ),
    );
    if (changed == true && mounted) {
      _page = 1;
      await _load();
    }
  }

  void _searchNow() {
    _debounce?.cancel();
    _page = 1;
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(
      subtitle: 'Giao dịch',
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _open(),
      tooltip: 'Thêm giao dịch',
      child: const Icon(Icons.add),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: MonthSelector(
            month: _month,
            onChanged: (month) {
              _month = month;
              _page = 1;
              _load();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Tìm ghi chú hoặc danh mục',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _searchNow();
                      },
                    ),
            ),
            onChanged: (_) {
              setState(() {});
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _searchNow);
            },
            onSubmitted: (_) => _searchNow(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('type-$_type'),
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Loại giao dịch',
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Tất cả')),
                    DropdownMenuItem(value: 'income', child: Text('Khoản thu')),
                    DropdownMenuItem(
                      value: 'expense',
                      child: Text('Khoản chi'),
                    ),
                  ],
                  onChanged: (value) {
                    _type = value!;
                    _category = null;
                    _page = 1;
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey(
                    'filter-$_type-$_category-${_categories.length}',
                  ),
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                    children: [
                      if (_items.isEmpty)
                        SurfaceCard(
                          child: Column(
                            children: [
                              const SizedBox(height: 18),
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: AppColors.muted,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Chưa có giao dịch phù hợp.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Thêm giao dịch đầu tiên hoặc thay đổi bộ lọc.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 14),
                              TextButton.icon(
                                onPressed: () => _open(),
                                icon: const Icon(Icons.add),
                                label: const Text('Thêm giao dịch'),
                              ),
                            ],
                          ),
                        ),
                      for (var i = 0; i < _items.length; i++) ...[
                        if (i == 0 ||
                            dateKey(_items[i].date) !=
                                dateKey(_items[i - 1].date))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_items[i].date),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SurfaceCard(
                            padding: EdgeInsets.zero,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _open(_items[i]),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    CategoryAvatar(
                                      name: _items[i].categoryName,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _items[i].categoryName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _items[i].note.isEmpty
                                                ? DateFormat(
                                                    'dd/MM/yyyy',
                                                  ).format(_items[i].date)
                                                : _items[i].note,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${_items[i].type == 'income' ? '+' : '−'}${money(_items[i].amountVnd)}',
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: _items[i].type == 'income'
                                                  ? AppColors.primary
                                                  : AppColors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _items[i].type == 'income'
                                                ? 'Thu nhập'
                                                : 'Chi tiêu',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Row(
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
              Text(
                'Trang $_page · $_total giao dịch',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
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
        ),
      ],
    ),
  );
}
