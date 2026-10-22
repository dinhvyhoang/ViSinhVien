import 'package:flutter/material.dart';
import '../api_client.dart';
import '../ui.dart';
import '../widgets.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ApiClient api;
  const SettingsScreen({super.key, required this.api});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _name = TextEditingController();
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await widget.api.request('GET', '/profile') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _name.text = data['displayName'] as String? ?? '';
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.request(
        'PUT',
        '/profile',
        body: {'displayName': _name.text.trim()},
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu thông tin cá nhân')));
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cài đặt cá nhân')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.person_outline,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin của bạn',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tên bạn sẽ xuất hiện ở lời chào trên trang chủ.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _name,
                      enabled: !_saving,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Tên hiển thị',
                        hintText: 'Nhập tên của bạn',
                      ),
                    ),
                    if (_error != null)
                      ErrorNotice(message: _error!, retry: _load),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Đang lưu…' : 'Lưu thông tin'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  leading: const Icon(
                    Icons.category_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Quản lý danh mục'),
                  subtitle: const Text('Thêm, đổi tên và lưu trữ danh mục'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoriesScreen(api: widget.api),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ví Sinh Viên',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Một nơi để ghi chép thu chi, đặt ngân sách và hiểu rõ tài chính của bạn.',
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Phiên bản cá nhân · 1.0.0',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}
