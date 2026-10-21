import 'package:file_selector/file_selector.dart';

Future<XFile?> pickDocxFile() => openFile(
  acceptedTypeGroups: const [
    XTypeGroup(
      label: 'Word DOCX',
      extensions: ['docx'],
      mimeTypes: [
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ],
      uniformTypeIdentifiers: ['org.openxmlformats.wordprocessingml.document'],
    ),
  ],
);
