import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';
import '../ui.dart';
import 'categories_screen.dart';

class TransactionForm extends StatefulWidget {
  final ApiClient api;
  final FinanceTransaction? transaction;
  const TransactionForm({super.key, required this.api, this.transaction});
  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  List<Category> _categories = [];
  String _type = 'expense';
  int? _categoryId;
  DateTime _date = DateTime.now();
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    if (t != null) {
      _amount.text = t.amountVnd.toString();
      _note.text = t.note;
      _type = t.type;
      _categoryId = t.categoryId;
      _date = t.date;
    }
    _amount.addListener(_refreshAmount);
    _loadCategories();
  }

  void _refreshAmount() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amount.removeListener(_refreshAmount);
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.categories();
      if (mounted) {
        setState(() {
          _categories = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _addCategory() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CategoryDialog(api: widget.api, initialType: _type),
    );
    if (changed == true && mounted) await _loadCategories();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final today = DateTime.now();
    if (_date.isAfter(
      DateTime(today.year, today.month, today.day, 23, 59, 59),
    )) {
      setState(() => _error = 'Ngày giao dịch không được ở tương lai.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = widget.transaction?.id;
      await widget.api.request(
        id == null ? 'POST' : 'PUT',
        id == null ? '/transactions' : '/transactions/$id',
        body: {
          'categoryId': _categoryId,
          'amountVnd': int.parse(_amount.text),
          'transactionDate': dateKey(_date),
          'note': _note.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = _categories
        .where(
          (c) =>
              c.type == _type &&
              (!c.isArchived || c.id == widget.transaction?.categoryId),
        )
        .toList();
    final expense = _type == 'expense';
    final amount = int.tryParse(_amount.text) ?? 0;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            widget.transaction == null ? 'Thêm giao dịch' : 'Sửa giao dịch',
          ),
          leading: IconButton(
            tooltip: 'Quay lại',
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: 'Lưu giao dịch',
              onPressed: _saving || _loading ? null : _save,
              icon: const Icon(Icons.check_circle, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _categories.isEmpty && _error != null
            ? Center(
                child: ErrorNotice(message: _error!, retry: _loadCategories),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Text(
                      widget.transaction == null
                          ? 'Thêm giao dịch mới'
                          : 'Cập nhật giao dịch',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ghi chép hôm nay, chủ động ngày mai',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.lavender,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          for (final type in ['expense', 'income'])
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _saving
                                    ? null
                                    : () => setState(() {
                                        _type = type;
                                        _categoryId = null;
                                      }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _type == type
                                        ? (type == 'expense'
                                              ? const Color(0xffffdad6)
                                              : const Color(0xffbcf9df))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        type == 'expense'
                                            ? Icons.trending_down
                                            : Icons.trending_up,
                                        color: type == 'expense'
                                            ? AppColors.red
                                            : AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          type == 'expense'
                                              ? 'Khoản Chi'
                                              : 'Khoản Thu',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: _type == type
                                                ? (type == 'expense'
                                                      ? AppColors.red
                                                      : AppColors.primary)
                                                : AppColors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SurfaceCard(
                      child: Column(
                        children: [
                          Text(
                            expense ? 'SỐ TIỀN CHI TIÊU' : 'SỐ TIỀN THU NHẬP',
                            style: const TextStyle(
                              color: AppColors.muted,
                              letterSpacing: 1.3,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('amount'),
                            controller: _amount,
                            enabled: !_saving,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: expense
                                  ? AppColors.red
                                  : AppColors.primary,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              suffixText: 'VNĐ',
                              labelText: 'Số tiền (đồng)',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              filled: false,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: validateMoney,
                          ),
                          if (amount > 0)
                            Text(
                              money(amount),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final n in [50000, 100000, 200000, 500000])
                                ActionChip(
                                  backgroundColor: AppColors.lavender,
                                  side: BorderSide.none,
                                  label: Text('+${n ~/ 1000}k'),
                                  onPressed: _saving
                                      ? null
                                      : () {
                                          _amount.text =
                                              '${(int.tryParse(_amount.text) ?? 0) + n}';
                                          _amount.selection =
                                              TextSelection.collapsed(
                                                offset: _amount.text.length,
                                              );
                                        },
                                ),
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
                              const Icon(
                                Icons.category_outlined,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Danh mục sinh viên',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                'Bắt buộc',
                                style: TextStyle(
                                  color: _categoryId == null
                                      ? AppColors.muted
                                      : AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          FormField<int>(
                            key: ValueKey('category-$_type-$_categoryId'),
                            initialValue: _categoryId,
                            validator: (value) =>
                                value == null ||
                                    !choices.any((c) => c.id == value)
                                ? 'Chọn danh mục'
                                : null,
                            builder: (field) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final count = constraints.maxWidth < 340
                                        ? 3
                                        : 4;
                                    final width =
                                        (constraints.maxWidth -
                                            (count - 1) * 8) /
                                        count;
                                    return Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final c in choices)
                                          SizedBox(
                                            width: width,
                                            child: Semantics(
                                              button: true,
                                              selected: c.id == _categoryId,
                                              child: InkWell(
                                                onTap: _saving
                                                    ? null
                                                    : () => setState(() {
                                                        _categoryId = c.id;
                                                        field.didChange(c.id);
                                                      }),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 12,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: c.id == _categoryId
                                                        ? const Color(
                                                            0xffe1f2eb,
                                                          )
                                                        : AppColors.background,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    border: c.id == _categoryId
                                                        ? Border.all(
                                                            color: AppColors
                                                                .primary,
                                                          )
                                                        : null,
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      CategoryAvatar(
                                                        name: c.name,
                                                        size: 46,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        c.name,
                                                        maxLines: 2,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              c.id ==
                                                                  _categoryId
                                                              ? AppColors
                                                                    .primary
                                                              : AppColors.ink,
                                                          fontWeight:
                                                              c.id ==
                                                                  _categoryId
                                                              ? FontWeight.w700
                                                              : FontWeight.w500,
                                                        ),
                                                      ),
                                                      if (c.isArchived)
                                                        const Text(
                                                          'Đã lưu trữ',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        SizedBox(
                                          width: width,
                                          child: InkWell(
                                            onTap: _saving
                                                ? null
                                                : _addCategory,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.background,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: const Column(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 23,
                                                    backgroundColor: Color(
                                                      0xffbcf4ee,
                                                    ),
                                                    child: Icon(
                                                      Icons.add,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Tạo mới',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                if (field.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      field.errorText!,
                                      style: const TextStyle(
                                        color: AppColors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Ngày phát sinh',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      final now = DateTime.now();
                                      final today = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                      );
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _date.isAfter(today)
                                            ? today
                                            : _date,
                                        firstDate: DateTime(1900),
                                        lastDate: today,
                                      );
                                      if (date != null && mounted) {
                                        setState(() => _date = date);
                                      }
                                    },
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(
                                DateFormat('dd/MM/yyyy').format(_date),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            key: const Key('note'),
                            controller: _note,
                            enabled: !_saving,
                            decoration: const InputDecoration(
                              labelText: 'Ghi chú chi tiết',
                              hintText: 'Bạn đã chi tiêu cho việc gì?',
                              alignLabelWithHint: true,
                            ),
                            maxLength: 500,
                            minLines: 2,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ErrorNotice(message: _error!),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: AppColors.mint,
                        foregroundColor: const Color(0xff004b38),
                      ),
                      label: Text(
                        _saving ? 'Đang xử lý…' : 'Lưu giao dịch',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Giao dịch được lưu và tự động cập nhật các báo cáo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
