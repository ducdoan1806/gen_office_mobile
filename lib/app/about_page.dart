import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'branding.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final _version = const MethodChannel(
    'genoffice/app_info',
  ).invokeMapMethod<String, dynamic>('getAppInfo');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Giới thiệu')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                AppBranding.icon,
                width: 96,
                height: 96,
                cacheWidth: 288,
                semanticLabel: 'Biểu tượng VPIC1 Office',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppBranding.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(AppBranding.summary, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          const Text(AppBranding.description),
          const SizedBox(height: 24),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Đơn vị sử dụng'),
            subtitle: Text(AppBranding.company),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Nền tảng'),
            subtitle: Text('Android'),
          ),
          FutureBuilder<Map<String, dynamic>?>(
            future: _version,
            builder: (context, snapshot) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Phiên bản'),
              subtitle: Text(
                snapshot.hasData
                    ? '${snapshot.data!['version']} (bản dựng ${snapshot.data!['buildNumber']})'
                    : snapshot.hasError
                    ? 'Không đọc được thông tin phiên bản'
                    : 'Đang tải…',
              ),
            ),
          ),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: AppBranding.name,
              applicationIcon: Image.asset(
                AppBranding.icon,
                width: 48,
                height: 48,
              ),
            ),
            child: const Text('Giấy phép phần mềm'),
          ),
        ],
      ),
    ),
  );
}
