import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'android_document_files.dart';

Future<XFile?> pickPdfFile() => Platform.isAndroid
    ? const AndroidDocumentFiles().pick(pdf: true)
    : openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'PDF',
            extensions: ['pdf'],
            mimeTypes: ['application/pdf'],
          ),
        ],
      );
