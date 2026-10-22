import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'android_document_files.dart';

Future<XFile?> pickOfficeFile() => Platform.isAndroid
    ? const AndroidDocumentFiles().pick(allDocuments: true)
    : openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Tài liệu',
            extensions: ['docx', 'pdf', 'doc', 'xlsx', 'pptx'],
            mimeTypes: [
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              'application/pdf',
              'application/msword',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            ],
            uniformTypeIdentifiers: [
              'org.openxmlformats.wordprocessingml.document',
              'com.adobe.pdf',
              'com.microsoft.word.doc',
              'org.openxmlformats.spreadsheetml.sheet',
              'org.openxmlformats.presentationml.presentation',
            ],
          ),
        ],
      );
