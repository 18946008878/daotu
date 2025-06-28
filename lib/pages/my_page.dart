import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../db/db_helper.dart';
import '../models/trip.dart';
import '../models/record.dart';
import '../utils/csv_exporter.dart';
import '../utils/csv_exporter_all.dart';
import '../utils/csv_importer.dart';
import '../utils/pgyer_updater.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool isLoggedIn = false;
  String username = '';
  bool hasNewVersion = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        isLoggedIn = true;
        username = user.email ?? user.id;
      });
    }
    // 静默检测新版本
    PgyerUpdater.checkUpdate(context, silent: true, onResult: (ver, log) {
      if (ver != null) setState(() => hasNewVersion = true);
    });
  }

  Future<void> _showLoginDialog() async {
    final userController = TextEditingController();
    final pwdController = TextEditingController();
    String? errorMsg;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('登录'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userController,
                decoration: const InputDecoration(labelText: '邮箱'),
              ),
              TextField(
                controller: pwdController,
                decoration: const InputDecoration(labelText: '密码'),
                obscureText: true,
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ]
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final res = await Supabase.instance.client.auth.signInWithPassword(
                    email: userController.text,
                    password: pwdController.text,
                  );
                  if (res.user != null) {
                    setState(() {
                      isLoggedIn = true;
                      username = res.user!.email ?? res.user!.id;
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登录成功')));
                  } else {
                    setState(() { errorMsg = '登录失败，请检查用户名或密码'; });
                  }
                } on AuthException catch (e) {
                  setState(() { errorMsg = e.message ?? '登录失败，请检查用户名或密码'; });
                } catch (e) {
                  setState(() { errorMsg = '网络异常或未知错误'; });
                }
              },
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRegisterDialog() async {
    final userController = TextEditingController();
    final pwdController = TextEditingController();
    String? errorMsg;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('注册'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userController,
                decoration: const InputDecoration(labelText: '邮箱'),
              ),
              TextField(
                controller: pwdController,
                decoration: const InputDecoration(labelText: '密码'),
                obscureText: true,
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ]
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final res = await Supabase.instance.client.auth.signUp(
                    email: userController.text,
                    password: pwdController.text,
                  );
                  if (res.user != null) {
                    setState(() {
                      isLoggedIn = true;
                      username = res.user!.email ?? res.user!.id;
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('注册成功，请查收邮箱激活账号')));
                  } else {
                    setState(() { errorMsg = '注册失败，请检查邮箱格式或密码强度'; });
                  }
                } on AuthException catch (e) {
                  setState(() { errorMsg = e.message ?? '注册失败，请检查邮箱格式或密码强度'; });
                } catch (e) {
                  setState(() { errorMsg = '网络异常或未知错误'; });
                }
              },
              child: const Text('注册'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    setState(() {
      isLoggedIn = false;
      username = '';
    });
  }

  void _showBackupDialog() async {
    final trips = await DBHelper().getAllTrips();
    final tripRecords = <int, List<Record>>{};
    for (final trip in trips) {
      tripRecords[trip.id!] = await DBHelper().getRecordsByTrip(trip.id!);
    }
    final filePath = await CsvExporterAll.exportAllTrips(trips, tripRecords);
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('数据备份'),
          content: Text('全部数据已导出到：\n$filePath'),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭'))],
        ),
      );
    }
  }

  void _showRestoreDialog() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final count = await CsvImporter.importAllTrips(filePath);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('数据恢复'),
            content: Text('已从备份文件恢复 $count 条收支记录'),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭'))],
          ),
        );
      }
    }
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部数据'),
        content: const Text('确定要清空所有数据吗？此操作不可恢复！'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              // 清空本地和云端所有数据
              final trips = await DBHelper().getAllTrips();
              final tripIds = trips.map((e) => e.id!).toList();
              await DBHelper().batchDeleteTrips(context, tripIds);
              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('所有数据已清空')));
              }
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('主题切换'),
        content: const Text('此处可实现深色/浅色/自定义主题切换。'),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭'))],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '导游记账',
      applicationVersion: 'v1.0.0',
      applicationIcon: const Icon(Icons.account_balance_wallet, size: 40, color: Colors.teal),
      children: [
        const Text('极简团队记账App，适合导游团队收支管理。\n作者：@凡哥出品\n微信公众号：小凡平凡'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        children: [
          // 第一栏：用户注册/登录
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_circle, size: 48, color: Colors.teal),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLoggedIn ? username : '未登录',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLoggedIn ? '欢迎使用导游记账' : '请注册或登录以同步数据',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      isLoggedIn
                          ? OutlinedButton(onPressed: _logout, child: const Text('退出'))
                          : Column(
                              children: [
                                ElevatedButton(
                                  onPressed: _showLoginDialog,
                                  child: const Text('登录'),
                                ),
                                TextButton(
                                  onPressed: _showRegisterDialog,
                                  child: const Text('注册'),
                                ),
                              ],
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // 第二栏：数据备份与恢复等功能
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('数据管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.backup, color: Colors.blue),
                    title: const Text('数据备份'),
                    onTap: _showBackupDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore, color: Colors.green),
                    title: const Text('数据恢复'),
                    onTap: _showRestoreDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    title: const Text('清空全部数据'),
                    onTap: _showClearDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // 第三栏：设置
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.system_update, color: Colors.blue),
                    title: Row(
                      children: [
                        const Text('检查更新'),
                        if (hasNewVersion)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () async {
                      setState(() => hasNewVersion = false);
                      await PgyerUpdater.checkUpdate(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.grey),
                    title: const Text('关于'),
                    onTap: _showAboutDialog,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
