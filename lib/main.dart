import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/permission_request_screen.dart';
import 'theme/app_theme.dart';
import 'services/permissions/permission_service.dart';

void main() {
  runApp(const LittleZiXiaApp());
}

class LittleZiXiaApp extends StatelessWidget {
  const LittleZiXiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MaterialApp(
        title: '小紫霞',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const StartupScreen(),
      ),
    );
  }
}

/// 启动屏幕 - 检查权限后再进入主界面
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _permissionsGranted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final hasAll = await appState.hasAllPermissions();

    if (mounted) {
      setState(() {
        _permissionsGranted = hasAll;
        _checking = false;
      });
    }
  }

  void _onPermissionsCompleted() {
    setState(() {
      _permissionsGranted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_permissionsGranted) {
      return PermissionRequestScreen(
        onCompleted: _onPermissionsCompleted,
      );
    }

    return const HomeScreen();
  }
}
