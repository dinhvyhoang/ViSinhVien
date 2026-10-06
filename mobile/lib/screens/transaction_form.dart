import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';

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
  bool _loading = true;
  bool _saving = false;
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
    _loadCategories();
  }

  @override
  void dispose() {
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
      if (!mounted) return;
      setState(() {
        _categories = items;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
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
          'note': _note.text,
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: const Text('Giao dịch này sẽ bị xóa khỏi database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.request(
        'DELETE',
        '/transactions/${widget.transaction!.id}',
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
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.transaction == null ? 'Thêm giao dịch' : 'Sửa giao dịch',
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'expense', label: Text('Chi')),
                        ButtonSegment(value: 'income', label: Text('Thu')),
                      ],
                      selected: {_type},
                      onSelectionChanged: _saving
                          ? null
                          : (values) => setState(() {
                              _type = values.first;
                              _categoryId = null;
                            }),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      key: ValueKey('category-$_type-$_categoryId'),
                      initialValue: choices.any((c) => c.id == _categoryId)
                          ? _categoryId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Danh mục'),
                      items: choices
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                '${c.name}${c.isArchived ? ' (đã lưu trữ)' : ''}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _categoryId = value),
                      validator: (value) =>
                          value == null ? 'Chọn danh mục' : null,
                    ),
                    if (choices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Chưa có danh mục. Hãy thêm danh mục ở màn hình Danh mục.',
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('amount'),
                      controller: _amount,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Số tiền (đồng)',
                        hintText: 'Ví dụ: 35000',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: validateMoney,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2100, 12, 31),
                              );
                              if (date != null && mounted) {
                                setState(() => _date = date);
                              }
                            },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        'Ngày: ${DateFormat('dd/MM/yyyy').format(_date)}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('note'),
                      controller: _note,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                      maxLength: 500,
                      maxLines: 3,
                    ),
                    if (_error != null)
                      ErrorNotice(
                        message: _error!,
                        retry: _categories.isEmpty ? _loadCategories : null,
                      ),
                    FilledButton(
                      onPressed: _saving || _categories.isEmpty ? null : _save,
                      child: Text(_saving ? 'Đang xử lý…' : 'Lưu giao dịch'),
                    ),
                    if (widget.transaction != null)
                      TextButton.icon(
                        onPressed: _saving ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Xóa giao dịch'),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
