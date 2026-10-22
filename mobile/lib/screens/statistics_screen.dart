import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';
import '../ui.dart';
import '../widgets.dart';

class StatisticsScreen extends StatefulWidget {
  final ApiClient api;
  final DateTime? initialMonth;
  const StatisticsScreen({super.key, required this.api, this.initialMonth});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late DateTime _date;
  String _period = 'month';
  bool _barChart = false;
  bool _loading = true;
  bool _exporting = false;
  int _generation = 0;
  String? _error;
  Map<String, dynamic>? _data;
  static const _chartColors = [
    Color(0xffbd1219),
    Color(0xff10b981),
    Color(0xff3485ff),
    Color(0xfff59e0b),
    Color(0xff8b5cf6),
    Color(0xff0d9488),
    Color(0xffec4899),
  ];

  @override
  void initState() {
    super.initState();
    _date = widget.initialMonth ?? DateTime.now();
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
          await widget.api.request(
                'GET',
                '/reports/summary',
                query: {'period': _period, 'date': dateKey(_date)},
              )
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

  Future<void> _export() async {
    if (_exporting) return;
    final query = {'period': _period, 'date': dateKey(_date)};
    setState(() => _exporting = true);
    try {
      // Check API before opening the file so a disconnected server gives an
      // actionable message in the app instead of an empty browser download.
      await widget.api.request('GET', '/health');
      final uri = Uri.parse(
        '${widget.api.baseUrl}/api/reports/export',
      ).replace(queryParameters: query);
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
      if (!opened) throw ApiException('Không mở được báo cáo. Hãy thử lại.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _shift(int direction) {
    final candidate = switch (_period) {
      'week' => _date.add(Duration(days: 7 * direction)),
      'year' => DateTime(_date.year + direction, 1, 1),
      _ => DateTime(_date.year, _date.month + direction, 1),
    };
    if (candidate.year < 1900 || candidate.year > 2100) return;
    _date = candidate;
    _load();
  }

  String get _periodLabel {
    if (_period == 'year') return 'Năm ${_date.year}';
    if (_period == 'month') {
      return 'Tháng ${DateFormat('MM / yyyy').format(_date)}';
    }
    final start = _date.subtract(Duration(days: _date.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return '${DateFormat('dd/MM').format(start)} – ${DateFormat('dd/MM/yyyy').format(end)}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: _period == 'week'
          ? 'Chọn một ngày trong tuần cần xem'
          : _period == 'year'
          ? 'Chọn ngày trong năm cần xem'
          : 'Chọn tháng cần xem',
    );
    if (picked != null && mounted) {
      _date = picked;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(
      subtitle: 'Thống kê',
      actions: [
        IconButton(
          tooltip: 'Tải lại thống kê',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              children: [
                for (final entry in const {
                  'week': 'Tuần',
                  'month': 'Tháng',
                  'year': 'Năm',
                }.entries)
                  Expanded(
                    child: Semantics(
                      selected: _period == entry.key,
                      child: InkWell(
                        onTap: () {
                          if (_period == entry.key) return;
                          _period = entry.key;
                          _load();
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _period == entry.key
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            entry.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _period == entry.key
                                  ? AppColors.primary
                                  : AppColors.ink,
                              fontWeight: _period == entry.key
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Row(
              children: [
                IconButton(
                  onPressed:
                      _date.year <= 1900 &&
                          (_period == 'year' ||
                              _date.month == 1 && _date.day <= 7)
                      ? null
                      : () => _shift(-1),
                  tooltip: 'Kỳ trước',
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(
                      _periodLabel,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _date.year >= 2100 &&
                          (_period == 'year' ||
                              _date.month == 12 && _date.day >= 25)
                      ? null
                      : () => _shift(1),
                  tooltip: 'Kỳ sau',
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
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
    final expense = data['expenseVnd'] as num;
    final income = data['incomeVnd'] as num;
    final groups = (data['expenseByCategory'] as List)
        .cast<Map<String, dynamic>>();
    final transactionCount = data['transactionCount'] as num? ?? 0;
    final total = expense.toDouble();
    final values = groups
        .map((g) => (g['amountVnd'] as num).toDouble())
        .toList();
    return [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff087a57), Color(0xff006c62)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TỔNG KẾT CHI TIÊU',
              style: TextStyle(
                color: Color(0xff89e7c2),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(expense),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  color: Color(0xff89e7c2),
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '$transactionCount giao dịch ghi nhận',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                Text(
                  '${groups.length} danh mục chi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _summaryMetric('Tổng thu', income, AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryMetric(
              'Chênh lệch',
              data['balanceVnd'] as num,
              (data['balanceVnd'] as num) < 0
                  ? AppColors.red
                  : AppColors.primary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SurfaceCard(
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.donut_large_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tỷ trọng chi tiêu',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Biểu đồ tròn',
                        onPressed: () => setState(() => _barChart = false),
                        color: _barChart ? AppColors.muted : AppColors.primary,
                        icon: const Icon(Icons.donut_small_rounded, size: 21),
                      ),
                      IconButton(
                        tooltip: 'Biểu đồ thanh',
                        onPressed: () => setState(() => _barChart = true),
                        color: _barChart ? AppColors.primary : AppColors.muted,
                        icon: const Icon(Icons.bar_chart_rounded, size: 21),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (groups.isEmpty || expense == 0) ...[
              const SizedBox(height: 12),
              Icon(
                Icons.pie_chart_outline_rounded,
                size: 68,
                color: AppColors.primary.withValues(alpha: .3),
              ),
              const SizedBox(height: 14),
              const Text(
                'Chưa có khoản chi trong kỳ này.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
            ] else if (_barChart) ...[
              for (var i = 0; i < groups.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              groups[i]['categoryName'] as String,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '${(values[i] * 100 / total).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: values[i] / total,
                          color: _chartColors[i % _chartColors.length],
                          backgroundColor: AppColors.lavender,
                          minHeight: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              SizedBox(
                width: 230,
                height: 230,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ExpenseDonut(
                          values: values,
                          colors: _chartColors,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(45),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Tổng chi',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            child: Text(
                              NumberFormat.decimalPattern(
                                'vi_VN',
                              ).format(expense),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Text(
                            'VNĐ',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 14,
                runSpacing: 9,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < groups.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _chartColors[i % _chartColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${groups[i]['categoryName']} (${(values[i] * 100 / total).toStringAsFixed(1)}%)',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Chi tiết theo danh mục',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${groups.length} mục',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (groups.isEmpty)
        const SurfaceCard(
          child: Text(
            'Ghi nhận khoản chi đầu tiên để xem phân tích theo danh mục.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ),
      for (var i = 0; i < groups.length; i++) ...[
        _categoryRow(groups[i], _chartColors[i % _chartColors.length], expense),
        const SizedBox(height: 12),
      ],
      if (groups.isNotEmpty) ...[
        const SizedBox(height: 4),
        SurfaceCard(
          color: AppColors.lavender,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.tips_and_updates_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Góc nhìn chi tiêu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${groups.first['categoryName']} là khoản chi lớn nhất, chiếm ${((groups.first['amountVnd'] as num) * 100 / expense).toStringAsFixed(1)}% tổng chi (${money(groups.first['amountVnd'] as num)}). Theo dõi danh mục này để điều chỉnh kế hoạch phù hợp.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: _exporting ? null : _export,
        icon: const Icon(Icons.file_download_outlined),
        label: Text(_exporting ? 'Đang xuất…' : 'Xuất báo cáo CSV'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Báo cáo gồm các giao dịch thực tế trong kỳ đã chọn.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.muted),
      ),
    ];
  }

  Widget _summaryMetric(String title, num amount, Color color) => SurfaceCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            money(amount),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _categoryRow(Map<String, dynamic> group, Color color, num expense) {
    final amount = group['amountVnd'] as num;
    final percent = expense == 0 ? 0.0 : amount / expense;
    return SurfaceCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CategoryAvatar(name: group['categoryName'] as String),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group['categoryName'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${group['transactionCount'] ?? 0} giao dịch',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
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
                      money(amount),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(percent * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              color: color,
              backgroundColor: AppColors.lavender,
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseDonut extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _ExpenseDonut({required this.values, required this.colors});
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    final rect = Rect.fromLTWH(13, 13, size.width - 26, size.height - 26);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _ExpenseDonut oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}
