import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api_client.dart';
import 'screens/transactions_screen.dart';
import 'screens/categories_screen.dart';

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
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
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
  int _tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: _tab == 0
        ? TransactionsScreen(api: widget.api)
        : CategoriesScreen(api: widget.api),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) => setState(() => _tab = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Giao dịch',
        ),
        NavigationDestination(
          icon: Icon(Icons.category_outlined),
          label: 'Danh mục',
        ),
      ],
    ),
  );
}
