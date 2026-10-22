import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String money(num value) =>
    '${NumberFormat.decimalPattern('vi_VN').format(value)} đ';
String monthKey(DateTime date) => DateFormat('yyyy-MM').format(date);
String dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
String typeLabel(String type) => type == 'income' ? 'Thu' : 'Chi';

String? validateMoney(String? text) {
  final value = int.tryParse(text?.trim() ?? '');
  return value == null || value <= 0 || value > 1000000000000
      ? 'Nhập số nguyên từ 1 đến 1.000.000.000.000 đồng'
      : null;
}

class MonthSelector extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  const MonthSelector({
    super.key,
    required this.month,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'Tháng trước',
        onPressed: month.year == 1900 && month.month == 1
            ? null
            : () => onChanged(DateTime(month.year, month.month - 1)),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: TextButton(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: month,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100, 12, 31),
            );
            if (date != null) onChanged(DateTime(date.year, date.month));
          },
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_outlined, size: 18),
                const SizedBox(width: 7),
                Text(
                  'Tháng ${DateFormat('MM/yyyy').format(month)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.expand_more, size: 16),
              ],
            ),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Tháng sau',
        onPressed: month.year == 2100 && month.month == 12
            ? null
            : () => onChanged(DateTime(month.year, month.month + 1)),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class ErrorNotice extends StatelessWidget {
  final String message;
  final VoidCallback? retry;
  const ErrorNotice({super.key, required this.message, this.retry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Thử lại')),
      ],
    ),
  );
}
