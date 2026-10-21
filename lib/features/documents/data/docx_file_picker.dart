import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'android_document_files.dart';

Future<XFile?> pickDocxFile() => Platform.isAndroid
    ? const AndroidDocumentFiles().pick()
    : openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Word DOCX',
            extensions: ['docx'],
            mimeTypes: [
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            ],
            uniformTypeIdentifiers: [
              'org.openxmlformats.wordprocessingml.document',
            ],
          ),
        ],
      );
