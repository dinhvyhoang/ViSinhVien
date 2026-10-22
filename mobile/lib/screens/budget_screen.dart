import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../ui.dart';
import '../widgets.dart';

class BudgetScreen extends StatefulWidget {
  final ApiClient api;
  final DateTime? initialMonth;
  const BudgetScreen({super.key, required this.api, this.initialMonth});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late DateTime _month;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth ?? DateTime.now();
    _month = DateTime(initial.year, initial.month);
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await widget.api.request('GET', '/budgets/${monthKey(_month)}')
              as Map<String, dynamic>;
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _edit([Map<String, dynamic>? category]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LimitDialog(
        api: widget.api,
        month: monthKey(_month),
        category: category,
        currentLimit: ((category ?? _data)?['limitVnd'] as num?)?.toInt(),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(
      subtitle: 'Ngân sách',
      actions: [
        IconButton(
          tooltip: 'Tải lại ngân sách',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SurfaceCard(
            color: AppColors.lavender,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: MonthSelector(
              month: _month,
              onChanged: (month) {
                _month = month;
                _load();
              },
            ),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: _content(),
                  ),
                ),
        ),
      ],
    ),
  );

  List<Widget> _content() {
    final data = _data!;
    final limit = data['limitVnd'] as num?;
    final spent = data['spentVnd'] as num? ?? 0;
    final remaining = limit == null ? null : limit - spent;
    final percent = limit == null ? null : spent * 100 / limit;
    final categories = (data['categoryBudgets'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final color = _statusColor(percent);
    final now = DateTime.now();
    final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
    final currentMonth = now.year == _month.year && now.month == _month.month;
    final daysLeft = currentMonth
        ? lastDay - now.day + 1
        : (_month.isAfter(DateTime(now.year, now.month)) ? lastDay : 0);
    return [
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'NGÂN SÁCH TỔNG THỂ',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(limit == null ? 'Thiết lập' : 'Sửa'),
                ),
              ],
            ),
            if (limit == null) ...[
              const SizedBox(height: 8),
              const Text(
                'Chưa thiết lập',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Đặt hạn mức để theo dõi mức chi và nhận cảnh báo khi gần hết ngân sách.',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ] else ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(limit),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, color: color, size: 10),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _statusLabel(percent!),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BudgetProgress(value: spent / limit, color: color),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    'Đã chi tiêu',
                    spent,
                    AppColors.red,
                    AppColors.lavender,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metric(
                    remaining == null
                        ? 'Hạn mức tháng'
                        : remaining < 0
                        ? 'Vượt ngân sách'
                        : 'Còn lại an toàn',
                    remaining?.abs(),
                    remaining != null && remaining < 0
                        ? AppColors.red
                        : AppColors.primary,
                    const Color(0xffdcfcef),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      if (percent != null && percent >= 80) ...[
        const SizedBox(height: 16),
        SurfaceCard(
          color: percent >= 100
              ? const Color(0xffffe3e0)
              : const Color(0xffffdfb8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      percent > 100
                          ? 'Bạn đã vượt ngân sách tháng!'
                          : percent == 100
                          ? 'Đã sử dụng hết ngân sách tháng.'
                          : 'Cảnh báo chi tiêu: đã dùng ${percent.toStringAsFixed(1)}% ngân sách.',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      remaining! < 0
                          ? 'Khoản chi đã vượt hạn mức ${money(-remaining)}. Hãy xem lại các khoản chi và điều chỉnh kế hoạch.'
                          : daysLeft > 0
                          ? 'Còn ${money(remaining)} cho $daysLeft ngày${currentMonth ? ' còn lại' : ''}, khoảng ${money((remaining / daysLeft).floor())}/ngày.'
                          : 'Tháng này còn ${money(remaining)} chưa sử dụng.',
                      style: const TextStyle(height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      Row(
        children: [
          const Icon(Icons.donut_large_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Phân rã theo hạng mục',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${categories.length} mục',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (categories.isEmpty)
        const SurfaceCard(
          child: Text(
            'Chưa có danh mục chi. Hãy thêm danh mục trong phần Cài đặt.',
          ),
        ),
      for (final category in categories) ...[
        _categoryCard(category),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 8),
      FilledButton(
        onPressed: () => _edit(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                limit == null
                    ? 'Thiết lập ngân sách tháng'
                    : 'Điều chỉnh ngân sách tháng',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const SurfaceCard(
        color: AppColors.lavender,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tips_and_updates_outlined, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mẹo sinh viên: Đặt hạn mức cho từng danh mục để dễ theo dõi tiền trọ, ăn uống và đi lại. Hạn mức danh mục được theo dõi độc lập với ngân sách tổng.',
                style: TextStyle(height: 1.6, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _categoryCard(Map<String, dynamic> category) {
    final limit = category['limitVnd'] as num?;
    final spent = category['spentVnd'] as num? ?? 0;
    final percent = limit == null ? null : spent * 100 / limit;
    final remaining = limit == null ? null : limit - spent;
    final color = _statusColor(percent);
    return SurfaceCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CategoryAvatar(name: category['categoryName'] as String),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category['categoryName'] as String,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      limit == null
                          ? 'Chưa đặt hạn mức'
                          : remaining! < 0
                          ? 'Vượt ${money(-remaining)}'
                          : remaining == 0
                          ? 'Đã chạm trần hạn mức'
                          : 'Còn ${money(remaining)}',
                      style: TextStyle(
                        color: limit == null ? AppColors.muted : color,
                        fontSize: 12,
                      ),
                    ),
                    if (category['isArchived'] == true)
                      const Text(
                        'Danh mục đã lưu trữ',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(spent),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (limit != null)
                      Text(
                        'Mục tiêu: ${money(limit)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    if (category['isArchived'] != true || limit != null)
                      InkWell(
                        onTap: () => _edit(category),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 7,
                            horizontal: 2,
                          ),
                          child: Text(
                            category['isArchived'] == true
                                ? 'Gỡ hạn mức'
                                : limit == null
                                ? '+ Đặt hạn mức'
                                : 'Sửa hạn mức',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BudgetProgress(
            value: limit == null ? 0 : spent / limit,
            color: color,
            height: 7,
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, num? value, Color color, Color background) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value == null ? 'Chưa thiết lập' : money(value),
                style: TextStyle(
                  color: color,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

Color _statusColor(num? percent) => percent == null
    ? AppColors.primary
    : percent >= 100
    ? AppColors.red
    : percent >= 80
    ? AppColors.amber
    : AppColors.primary;
String _statusLabel(num percent) => percent > 100
    ? 'Vượt ngân sách (${percent.toStringAsFixed(1)}%)'
    : percent == 100
    ? 'Đã dùng hết ngân sách (100%)'
    : percent >= 80
    ? 'Mức chạm cảnh báo (${percent.toStringAsFixed(1)}%)'
    : 'Đã sử dụng ${percent.toStringAsFixed(1)}% ngân sách';

class _BudgetProgress extends StatelessWidget {
  final num value;
  final Color color;
  final double height;
  const _BudgetProgress({
    required this.value,
    required this.color,
    this.height = 10,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: LinearProgressIndicator(
      value: value.toDouble().clamp(0, 1),
      color: color,
      backgroundColor: AppColors.lavender,
      minHeight: height,
    ),
  );
}

class _LimitDialog extends StatefulWidget {
  final ApiClient api;
  final String month;
  final Map<String, dynamic>? category;
  final int? currentLimit;
  const _LimitDialog({
    required this.api,
    required this.month,
    this.category,
    this.currentLimit,
  });
  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.currentLimit?.toString() ?? '',
  );
  bool _saving = false;
  String? _error;
  String get _path =>
      '/budgets/${widget.month}${widget.category == null ? '' : '/categories/${widget.category!['categoryId']}'}';
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    if (_saving || (!remove && !_form.currentState!.validate())) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.request(
        remove ? 'DELETE' : 'PUT',
        _path,
        body: remove ? null : {'limitVnd': int.parse(_amount.text)},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận gỡ hạn mức'),
        content: Text(widget.category == null
            ? 'Chỉ gỡ ngân sách tổng tháng này. Giao dịch và các hạn mức danh mục vẫn được giữ.'
            : 'Chỉ gỡ hạn mức danh mục này. Các giao dịch vẫn được giữ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gỡ hạn mức'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _save(remove: true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.category == null
            ? 'Ngân sách ${widget.month}'
            : 'Hạn mức ${widget.category!['categoryName']}',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                autofocus: true,
                enabled: !_saving && widget.category?['isArchived'] != true,
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: validateMoney,
                decoration: const InputDecoration(
                  labelText: 'Hạn mức (VNĐ)',
                  hintText: 'Nhập số tiền',
                ),
              ),
              if (_error != null) ErrorNotice(message: _error!),
              if (widget.currentLimit != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton.icon(
                    onPressed: _saving ? null : _confirmRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                    label: Text(widget.category == null
                        ? 'Gỡ ngân sách tháng'
                        : 'Gỡ hạn mức danh mục'),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        if (widget.category?['isArchived'] != true)
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Đang lưu…' : 'Lưu hạn mức'),
          ),
      ],
    ),
  );
}
