import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models.dart';
import '../ui.dart';
import '../widgets.dart';
import 'transaction_form.dart';
import 'transaction_detail.dart';

class DashboardScreen extends StatefulWidget {
  final ApiClient api;
  final void Function(int tab, DateTime month)? onNavigate;
  final VoidCallback? onProfile;
  const DashboardScreen({
    super.key,
    required this.api,
    this.onNavigate,
    this.onProfile,
  });
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _report;
  List<FinanceTransaction> _recent = [];
  String _name = '';
  int _total = 0, _request = 0;
  bool _loading = true, _visible = true;
  String? _error;
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
      final results = await Future.wait([
        widget.api.request(
          'GET',
          '/reports/monthly',
          query: {'month': monthKey(_month)},
        ),
        widget.api.request(
          'GET',
          '/transactions',
          query: {'month': monthKey(_month), 'pageSize': '5'},
        ),
        widget.api.request('GET', '/profile'),
      ]);
      if (!mounted || request != _request) return;
      final transactions = results[1] as Map<String, dynamic>;
      setState(() {
        _report = results[0] as Map<String, dynamic>;
        _recent = (transactions['items'] as List)
            .map((x) => FinanceTransaction.fromJson(x))
            .toList();
        _total = (transactions['total'] as num).toInt();
        _name =
            (results[2] as Map<String, dynamic>)['displayName'] as String? ??
            '';
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

  Future<void> _add() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TransactionForm(api: widget.api)),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _detail(FinanceTransaction item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TransactionDetailScreen(api: widget.api, transaction: item),
      ),
    );
    if (changed == true && mounted) _load();
  }

  void _notifications() {
    final status = _report?['budgetStatus'];
    final limit = _report?['budgetLimitVnd'] as num?;
    final expense = _report?['expenseVnd'] as num? ?? 0;
    final text = switch (status) {
      'exceeded' =>
        'Bạn đã vượt ngân sách tháng ${_month.month} ${money(expense - limit!)}. Hãy điều chỉnh các khoản chi tiếp theo.',
      'reached' => 'Đã sử dụng hết ngân sách tháng ${_month.month}.',
      'warning' =>
        'Đã dùng ${(_report!['budgetPercent'] as num).toStringAsFixed(1)}% ngân sách. Còn ${money(limit! - expense)} cho tháng này.',
      'unset' =>
        'Bạn chưa thiết lập ngân sách tháng ${_month.month}. Đặt hạn mức để theo dõi chi tiêu.',
      _ =>
        'Chưa có cảnh báo ngân sách. Các khoản chi của bạn đang trong hạn mức.',
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông báo ngân sách',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(text),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onNavigate?.call(2, _month);
                },
                child: const Text('Xem ngân sách'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(
      subtitle: 'Trang chủ',
      actions: [
        IconButton(
          tooltip: 'Thông báo',
          onPressed: _report == null ? null : _notifications,
          icon: Badge(
            isLabelVisible: [
              'warning',
              'reached',
              'exceeded',
            ].contains(_report?['budgetStatus']),
            smallSize: 7,
            backgroundColor: AppColors.mint,
            child: const Icon(Icons.notifications_none_outlined),
          ),
        ),
        if (widget.onProfile != null)
          IconButton(
            tooltip: 'Cài đặt cá nhân',
            onPressed: widget.onProfile,
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person_outline, color: Colors.white, size: 21),
            ),
          ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: ErrorNotice(message: _error!, retry: _load),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: _content(),
            ),
          ),
  );
  List<Widget> _content() {
    final r = _report!;
    final expense = r['expenseVnd'] as num;
    final limit = r['budgetLimitVnd'] as num?;
    final percent = r['budgetPercent'] as num?;
    final status = r['budgetStatus'] as String;
    final warning = ['warning', 'reached', 'exceeded'].contains(status);
    final color = status == 'exceeded' || status == 'reached'
        ? AppColors.red
        : status == 'warning'
        ? AppColors.amber
        : AppColors.mint;
    final message = switch (status) {
      'warning' =>
        'Đã dùng ${percent!.toStringAsFixed(0)}% hạn mức. Còn ${money(limit! - expense)}.',
      'reached' => 'Đã dùng hết 100% ngân sách.',
      'exceeded' => 'Đã vượt ngân sách tháng!',
      'unset' => 'Chưa thiết lập ngân sách tháng.',
      _ => 'Chi tiêu đang trong ngân sách.',
    };
    return [
      Text(
        _name.isEmpty ? 'Chào bạn! 👋' : 'Chào $_name! 👋',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -.5,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Hôm nay chi tiêu thật kỷ luật nhé!',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 16),
      MonthSelector(
        month: _month,
        onChanged: (value) {
          _month = value;
          _load();
        },
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B7956), Color(0xFF006956), Color(0xFF087B70)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x25006C49),
              offset: Offset(0, 8),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Chênh lệch tháng  (Tổng thu - Tổng chi)',
                    style: TextStyle(fontSize: 12, color: Color(0xFFA4F3CE)),
                  ),
                ),
                IconButton(
                  tooltip: _visible ? 'Ẩn số tiền' : 'Hiện số tiền',
                  onPressed: () => setState(() => _visible = !_visible),
                  icon: Icon(
                    _visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _visible
                    ? '${(r['balanceVnd'] as num) > 0 ? '+' : ''}${money(r['balanceVnd'] as num)}'
                    : '•••••• đ',
                style: const TextStyle(
                  fontSize: 35,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    'Tổng thu',
                    r['incomeVnd'] as num,
                    Icons.south,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _metric('Tổng chi', expense, Icons.north)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBD4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.savings_outlined,
                    color: Color(0xFF855300),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ngân sách tháng ${_month.month}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Hạn mức sinh hoạt chung',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (widget.onNavigate != null)
                  IconButton(
                    tooltip: 'Chi tiết ngân sách',
                    onPressed: () => widget.onNavigate!(2, _month),
                    icon: const Icon(
                      Icons.chevron_right,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (limit != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${money(expense)} / ${money(limit)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${percent!.toStringAsFixed(0)}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (expense / limit).clamp(0, 1).toDouble(),
                  color: color,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: warning
                    ? const Color(0xFFFFF4E8)
                    : const Color(0xFFF3F3FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    warning ? Icons.warning_amber_rounded : Icons.info_outline,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(message, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _budget,
              child: Text(
                limit == null ? 'Thiết lập ngân sách' : 'Đổi ngân sách',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const SurfaceCard(
        color: AppColors.lavender,
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MẸO CHI TIÊU SINH VIÊN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: .5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ghi lại từng khoản nhỏ mỗi ngày để hiểu rõ thói quen chi tiêu của bạn.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Giao dịch gần nhất',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          if (widget.onNavigate != null)
            TextButton(
              onPressed: () => widget.onNavigate!(1, _month),
              child: const Text('Xem tất cả →'),
            ),
        ],
      ),
      if (_total > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '$_total giao dịch trong tháng · hiển thị ${_recent.length} gần nhất',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      if (_recent.isEmpty)
        SurfaceCard(
          child: EmptyState(
            title: 'Chưa có giao dịch',
            message:
                'Bắt đầu ghi lại khoản thu hoặc chi đầu tiên của bạn trong tháng này.',
            action: FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Thêm giao dịch'),
            ),
          ),
        ),
      for (final item in _recent)
        TransactionCard(
          category: item.categoryName,
          note: item.note,
          type: item.type,
          amount: item.amountVnd,
          date: item.date,
          onTap: () => _detail(item),
        ),
      if (_recent.isNotEmpty && widget.onNavigate != null) ...[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => widget.onNavigate!(1, _month),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text('Xem sổ chi tiết tháng ${_month.month}'),
          ),
        ),
      ],
    ];
  }

  Widget _metric(String title, num amount, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFA4F3CE), size: 18),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(color: Color(0xFFC9FBE5), fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _visible ? money(amount) : '•••••• đ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
  late final TextEditingController _amount = TextEditingController(
    text: widget.limit?.toString() ?? '',
  );
  bool _saving = false;
  String? _error;
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
              const Text(
                'Đặt tổng hạn mức chi tiêu cho tháng. Số tiền đã chi được tính từ các giao dịch của bạn.',
              ),
              const SizedBox(height: 18),
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
