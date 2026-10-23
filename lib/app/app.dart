import 'package:flutter/material.dart';
import '../features/documents/presentation/document_library_page.dart';
import 'dependencies.dart';
import 'branding.dart';

class GenOfficeApp extends StatelessWidget {
  const GenOfficeApp({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppBranding.name,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF156B63)),
      useMaterial3: true,
    ),
    home: DocumentLibraryPage(dependencies: dependencies),
  );
}
