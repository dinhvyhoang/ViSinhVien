import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../widgets.dart';

class DashboardScreen extends StatefulWidget {
  final ApiClient api;
  const DashboardScreen({super.key, required this.api});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report =
          await widget.api.request(
                'GET',
                '/reports/monthly',
                query: {'month': monthKey(_month)},
              )
              as Map<String, dynamic>;
      if (mounted && request == _request) {
        setState(() {
          _report = report;
          _loading = false;
        });
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

  Future<void> _budget() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BudgetDialog(
        api: widget.api,
        month: monthKey(_month),
        limit: (_report?['budgetLimitVnd'] as num?)?.toInt(),
      ),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ví Sinh Viên'),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        MonthSelector(
          month: _month,
          onChanged: (month) {
            _month = month;
            _load();
          },
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
                    padding: const EdgeInsets.all(16),
                    children: _content(),
                  ),
                ),
        ),
      ],
    ),
  );
  List<Widget> _content() {
    final r = _report!;
    final expense = r['expenseVnd'] as num;
    final limit = r['budgetLimitVnd'] as num?;
    final percent = r['budgetPercent'] as num?;
    final status = r['budgetStatus'] as String;
    final message = switch (status) {
      'warning' => 'Đã dùng từ 80% ngân sách. Hãy cân nhắc chi tiêu.',
      'reached' => 'Đã dùng hết 100% ngân sách.',
      'exceeded' => 'Đã vượt ngân sách tháng!',
      'unset' => 'Chưa thiết lập ngân sách tháng.',
      _ => 'Chi tiêu đang trong ngân sách.',
    };
    final color = status == 'exceeded' || status == 'reached'
        ? Colors.red
        : status == 'warning'
        ? Colors.orange.shade800
        : Colors.teal;
    final groups = r['expenseByCategory'] as List;
    return [
      _totalCard(
        'Tổng thu',
        r['incomeVnd'] as num,
        Icons.arrow_downward,
        Colors.teal,
      ),
      _totalCard('Tổng chi', expense, Icons.arrow_upward, Colors.red),
      _totalCard(
        'Chênh lệch',
        r['balanceVnd'] as num,
        Icons.account_balance_wallet_outlined,
        (r['balanceVnd'] as num) < 0 ? Colors.red : Colors.teal,
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ngân sách tháng',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(message, style: TextStyle(color: color)),
              if (limit != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (expense / limit).clamp(0.0, 1.0),
                  color: color,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  '${money(expense)} / ${money(limit)} (${percent?.toStringAsFixed(1)}%)',
                ),
                Text('Còn lại: ${money(limit - expense)}'),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _budget,
                child: Text(
                  limit == null ? 'Thiết lập ngân sách' : 'Đổi ngân sách',
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Chi tiêu theo danh mục',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      if (groups.isEmpty) const Text('Chưa có khoản chi trong tháng này.'),
      for (final group in groups)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['categoryName'] as String,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  minHeight: 12,
                  value: expense == 0
                      ? 0
                      : ((group['amountVnd'] as num) / expense).clamp(0.0, 1.0),
                ),
                const SizedBox(height: 8),
                Text(
                  '${money(group['amountVnd'] as num)} · ${expense == 0 ? '0' : ((group['amountVnd'] as num) * 100 / expense).toStringAsFixed(1)}% tổng chi',
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _totalCard(String title, num amount, IconData icon, Color color) =>
      Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title),
          subtitle: Text(
            money(amount),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: color),
          ),
        ),
      );
}

class BudgetDialog extends StatefulWidget {
  final ApiClient api;
  final String month;
  final int? limit;
  const BudgetDialog({
    super.key,
    required this.api,
    required this.month,
    this.limit,
  });
  @override
  State<BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<BudgetDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.limit?.toString() ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.request(
        'PUT',
        '/budgets/${widget.month}',
        body: {'limitVnd': int.parse(_amount.text)},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text('Ngân sách ${widget.month}'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amount,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Hạn mức (đồng)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: validateMoney,
              ),
              if (_error != null) ErrorNotice(message: _error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu…' : 'Lưu ngân sách'),
        ),
      ],
    ),
  );
}
