import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';

class CategoriesScreen extends StatefulWidget {
  final ApiClient api;
  const CategoriesScreen({super.key, required this.api});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _items = [];
  bool _loading = true;
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
      final data = await widget.api.categories();
      if (mounted) {
        setState(() {
          _items = data;
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

  Future<void> _edit([Category? item]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CategoryDialog(api: widget.api, category: item),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Danh mục')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _edit(),
      tooltip: 'Thêm danh mục',
      child: const Icon(Icons.add),
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
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Lưu trữ danh mục để ngừng sử dụng. Các giao dịch cũ vẫn được giữ.',
                  ),
                ),
                for (final type in ['expense', 'income']) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      typeLabel(type),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final item in _items.where((c) => c.type == type))
                    ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        item.isArchived ? 'Đã lưu trữ' : 'Đang sử dụng',
                      ),
                      leading: Icon(
                        item.isArchived
                            ? Icons.archive_outlined
                            : Icons.category_outlined,
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(item),
                    ),
                ],
              ],
            ),
          ),
  );
}

class CategoryDialog extends StatefulWidget {
  final ApiClient api;
  final Category? category;
  const CategoryDialog({super.key, required this.api, this.category});
  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _type;
  late bool _archived;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _type = widget.category?.type ?? 'expense';
    _archived = widget.category?.isArchived ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = widget.category?.id;
      await widget.api.request(
        id == null ? 'POST' : 'PUT',
        id == null ? '/categories' : '/categories/$id',
        body: {
          'name': _name.text.trim(),
          if (id == null) 'type': _type,
          if (id != null) 'isArchived': _archived,
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.category == null ? 'Thêm danh mục' : 'Sửa danh mục'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_saving,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Tên danh mục'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nhập tên danh mục' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Chi')),
                  DropdownMenuItem(value: 'income', child: Text('Thu')),
                ],
                onChanged: widget.category != null || _saving
                    ? null
                    : (v) => setState(() => _type = v!),
                decoration: const InputDecoration(labelText: 'Loại'),
              ),
              if (widget.category != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lưu trữ'),
                  value: _archived,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _archived = v),
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
          child: Text(_saving ? 'Đang lưu…' : 'Lưu danh mục'),
        ),
      ],
    ),
  );
}
