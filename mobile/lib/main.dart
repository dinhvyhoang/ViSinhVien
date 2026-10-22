import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api_client.dart';
import 'ui.dart';
import 'screens/transactions_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/transaction_form.dart';
import 'screens/settings_screen.dart';

void main() => runApp(const FinanceApp());

class FinanceApp extends StatefulWidget {
  final ApiClient? api;
  const FinanceApp({super.key, this.api});
  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  late final ApiClient _api = widget.api ?? ApiClient();
  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ví Sinh Viên',
    debugShowCheckedModeBanner: false,
    locale: const Locale('vi', 'VN'),
    supportedLocales: const [Locale('vi', 'VN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: financeTheme(),
    builder: (context, child) => ColoredBox(
      color: const Color(0xFFF0F2F8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: child!,
        ),
      ),
    ),
    home: FinanceHome(api: _api),
  );
}

class FinanceHome extends StatefulWidget {
  final ApiClient api;
  const FinanceHome({super.key, required this.api});
  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _tab = 0, _revision = 0;
  DateTime? _initialMonth;
  void _navigate(int tab, DateTime? month) => setState(() {
    _tab = tab;
    _initialMonth = month;
    _revision++;
  });
  Future<void> _add() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TransactionForm(api: widget.api)),
    );
    if (changed == true && mounted) {
      setState(() {
        _revision++;
      });
    }
  }

  Future<void> _settings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(api: widget.api)),
    );
    if (mounted) {
      setState(() {
        _revision++;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch (_tab) {
      0 => DashboardScreen(
        key: ValueKey('home-$_revision'),
        api: widget.api,
        onNavigate: _navigate,
        onProfile: _settings,
      ),
      1 => TransactionsScreen(
        key: ValueKey('transactions-$_revision'),
        api: widget.api,
        initialMonth: _initialMonth,
      ),
      2 => BudgetScreen(
        key: ValueKey('budget-$_revision'),
        api: widget.api,
        initialMonth: _initialMonth,
      ),
      _ => StatisticsScreen(
        key: ValueKey('statistics-$_revision'),
        api: widget.api,
        initialMonth: _initialMonth,
      ),
    },
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 7),
          child: Row(
            children: [
              _destination(0, Icons.home_outlined, 'Trang chủ'),
              _destination(1, Icons.receipt_long_outlined, 'Giao dịch'),
              Expanded(
                child: Center(
                  heightFactor: 1,
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: FloatingActionButton(
                      heroTag: 'global-add',
                      tooltip: 'Thêm giao dịch',
                      elevation: 5,
                      shape: const CircleBorder(),
                      onPressed: _add,
                      child: const Icon(Icons.add, size: 30),
                    ),
                  ),
                ),
              ),
              _destination(
                2,
                Icons.account_balance_wallet_outlined,
                'Ngân sách',
              ),
              _destination(3, Icons.pie_chart_outline, 'Thống kê'),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _destination(int tab, IconData icon, String label) => Expanded(
    child: Semantics(
      selected: _tab == tab,
      button: true,
      child: InkWell(
        onTap: () => _navigate(tab, null),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _tab == tab
                      ? const Color(0xFFE3F7ED)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: 23,
                  color: _tab == tab
                      ? AppColors.primary
                      : const Color(0xFF344B40),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: _tab == tab ? FontWeight.w600 : FontWeight.w400,
                  color: _tab == tab
                      ? AppColors.primary
                      : const Color(0xFF344B40),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
