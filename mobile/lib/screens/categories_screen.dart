import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets.dart';
import '../ui.dart';

class CategoriesScreen extends StatefulWidget {
  final ApiClient api;
  const CategoriesScreen({super.key, required this.api});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _items = [];
  bool _loading = true, _showArchived = false;
  String _type = 'expense';
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
      builder: (_) =>
          CategoryDialog(api: widget.api, category: item, initialType: _type),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items
        .where((c) => c.type == _type && (_showArchived || !c.isArchived))
        .toList();
    return Scaffold(
      appBar: const BrandAppBar(subtitle: 'Quản lý danh mục'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm danh mục'),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                children: [
                  const Text(
                    'Danh mục thu chi',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sắp xếp khoản thu và chi theo cách của bạn.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'expense',
                        icon: Icon(Icons.trending_down),
                        label: Text('Khoản chi'),
                      ),
                      ButtonSegment(
                        value: 'income',
                        icon: Icon(Icons.trending_up),
                        label: Text('Khoản thu'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (values) =>
                        setState(() => _type = values.first),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Hiện danh mục đã lưu trữ',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: _showArchived,
                    onChanged: (v) => setState(() => _showArchived = v),
                  ),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    const SurfaceCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('Chưa có danh mục trong nhóm này.'),
                        ),
                      ),
                    ),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SurfaceCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CategoryAvatar(name: item.name),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            item.isArchived
                                ? 'Đã lưu trữ · Chạm để khôi phục'
                                : 'Đang sử dụng',
                            style: TextStyle(
                              color: item.isArchived
                                  ? AppColors.muted
                                  : AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onTap: () => _edit(item),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const SurfaceCard(
                    color: AppColors.lavender,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lưu trữ để ngừng sử dụng một danh mục. Các giao dịch và báo cáo trước đây vẫn được giữ nguyên.',
                            style: TextStyle(
                              color: AppColors.muted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class CategoryDialog extends StatefulWidget {
  final ApiClient api;
  final Category? category;
  final String initialType;
  const CategoryDialog({
    super.key,
    required this.api,
    this.category,
    this.initialType = 'expense',
  });
  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late String _type = widget.category?.type ?? widget.initialType;
  late bool _archived = widget.category?.isArchived ?? false;
  bool _saving = false;
  String? _error;
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
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Tên danh mục'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nhập tên danh mục'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  items: const [
                    DropdownMenuItem(
                      value: 'expense',
                      child: Text('Khoản chi'),
                    ),
                    DropdownMenuItem(value: 'income', child: Text('Khoản thu')),
                  ],
                  onChanged: widget.category != null || _saving
                      ? null
                      : (v) => setState(() => _type = v!),
                  decoration: const InputDecoration(labelText: 'Loại'),
                ),
                if (widget.category != null) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lưu trữ danh mục'),
                    subtitle: const Text('Ẩn khỏi form giao dịch mới'),
                    value: _archived,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _archived = v),
                  ),
                ],
                if (_error != null) ErrorNotice(message: _error!),
              ],
            ),
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
