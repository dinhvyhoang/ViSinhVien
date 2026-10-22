import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';
import '../ui.dart';
import 'transaction_form.dart';

class TransactionDetailScreen extends StatefulWidget {
  final ApiClient api;
  final FinanceTransaction transaction;
  const TransactionDetailScreen({
    super.key,
    required this.api,
    required this.transaction,
  });
  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late FinanceTransaction _item = widget.transaction;
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.request('GET', '/transactions/${_item.id}');
      if (mounted) {
        setState(() {
          _item = FinanceTransaction.fromJson(data);
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

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionForm(api: widget.api, transaction: _item),
      ),
    );
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: Text(
          'Xóa khoản ${_item.type == 'income' ? 'thu' : 'chi'} ${money(_item.amountVnd)}? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
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
      await widget.api.request('DELETE', '/transactions/${_item.id}');
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Chi tiết giao dịch')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && !_saving
          ? Column(
              children: [
                ErrorNotice(message: _error!, retry: _load),
                if (_item.id > 0)
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Về danh sách'),
                  ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SurfaceCard(
                  child: Column(
                    children: [
                      CategoryAvatar(name: _item.categoryName, size: 64),
                      const SizedBox(height: 14),
                      Text(
                        _item.categoryName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FittedBox(
                        child: Text(
                          '${_item.type == 'income' ? '+' : '−'}${money(_item.amountVnd)}',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: _item.type == 'income'
                                ? AppColors.primary
                                : AppColors.red,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _item.type == 'income' ? 'Khoản thu' : 'Khoản chi',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SurfaceCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.primary,
                        ),
                        title: const Text('Ngày phát sinh'),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy').format(_item.date),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.notes_outlined,
                          color: AppColors.primary,
                        ),
                        title: const Text('Ghi chú'),
                        subtitle: Text(
                          _item.note.isEmpty ? 'Không có ghi chú' : _item.note,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _saving ? null : _edit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Sửa giao dịch'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(_saving ? 'Đang xóa…' : 'Xóa giao dịch'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
    ),
  );
}
