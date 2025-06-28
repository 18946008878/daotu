import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 蒲公英自动更新工具
class PgyerUpdater {
  /// 检查蒲公英新版本并自动对比本地版本号，支持静默检测和自定义回调
  static Future<void> checkUpdate(
    BuildContext context, {
    bool silent = false, // true时仅有新版本才弹窗，无新版本不提示
    void Function(String? newVersion, String? changelog)? onResult,
  }) async {
    const apiKey = '10a66fefcf73d0fe78441ee207542503'; // 请替换
    const appKey = '84ac4dc8a399e1fc8cedb6d5fe241e50'; // 请替换
    final url = 'https://www.pgyer.com/apiv2/app/check';
    final resp = await http.post(Uri.parse(url), body: {
      '_api_key': apiKey,
      'appKey': appKey,
    });
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      if (data['code'] == 0) {
        final buildVersion = data['data']['buildVersion'] ?? '';
        final buildUpdateDescription = data['data']['buildUpdateDescription'] ?? '';
        final downloadUrl = 'https://www.pgyer.com/$appKey';
        // 获取本地版本号
        String localVersion = 'unknown';
        try {
          final info = await PackageInfo.fromPlatform();
          localVersion = info.version;
        } catch (_) {}
        if (buildVersion != localVersion) {
          if (onResult != null) onResult(buildVersion, buildUpdateDescription);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('发现新版本 $buildVersion'),
              content: Text(buildUpdateDescription),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final uri = Uri.parse(downloadUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('前往下载'),
                ),
              ],
            ),
          );
        } else {
          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
          }
          if (onResult != null) onResult(null, null);
        }
      } else {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未检测到新版本')));
        }
        if (onResult != null) onResult(null, null);
      }
    } else {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('检查更新失败')));
      }
      if (onResult != null) onResult(null, null);
    }
  }
}
