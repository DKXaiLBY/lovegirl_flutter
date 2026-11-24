import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'study_workspace.dart';

class StudyPdfDocument {
  const StudyPdfDocument(this.id, this.name, this.pages);

  final String id;
  final String name;
  final int pages;

  StudyPageReference page(int number) => StudyPageReference(id, name, number);
}

class StudyPdfLine {
  const StudyPdfLine(this.text, this.x, this.y, this.height);

  final String text;
  final int x;
  final int y;
  final int height;
}

class StudyPdfText {
  const StudyPdfText(this.reference, this.text, {this.lines = const []});

  final StudyPageReference reference;
  final String text;
  final List<StudyPdfLine> lines;

  List<String> get rows {
    if (lines.isEmpty) return text.split('\n');
    final sorted = [...lines]..sort((a, b) => a.y.compareTo(b.y));
    final blocks = <List<StudyPdfLine>>[];
    for (final line in sorted) {
      final row = blocks.lastOrNull;
      final base = row?.first;
      if (row != null &&
          base != null &&
          (line.y - base.y).abs() <= (base.height * .55).clamp(5, 23)) {
        row.add(line);
      } else {
        blocks.add([line]);
      }
    }
    return blocks.map((row) {
      row.sort((a, b) => a.x.compareTo(b.x));
      return row.map((line) => line.text).join('  ');
    }).toList(growable: false);
  }
}

class StudyPdf {
  const StudyPdf(this.account);

  final int account;
  static const _channel = MethodChannel('lovegirl/device');
  static const maxRange = 16;
  static bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<StudyPdfDocument?> pick() async {
    final file = await _channel
        .invokeMapMethod<String, dynamic>('pickStudyPdf', {'account': account});
    return file == null
        ? null
        : StudyPdfDocument(
            file['id'] as String, file['name'] as String, file['pages'] as int);
  }

  Future<List<StudyPdfText>> read(
      StudyPdfDocument document, int first, int last,
      {bool forceOcr = false, bool answerGrid = false}) async {
    final pages = await _channel.invokeListMethod<dynamic>('readStudyPdf', {
      'account': account,
      'id': document.id,
      'first': first,
      'last': last,
      'forceOcr': forceOcr,
      'answerGrid': answerGrid,
    });
    return (pages ?? const []).map((entry) {
      final page = entry as Map;
      return StudyPdfText(
          document.page(page['number'] as int), page['text'] as String,
          lines: (page['lines'] as List? ?? const []).map((entry) {
            final line = entry as Map;
            return StudyPdfLine(line['text'] as String, line['x'] as int,
                line['y'] as int, line['height'] as int);
          }).toList(growable: false));
    }).toList(growable: false);
  }

  Future<Uint8List?> preview(StudyPageReference page) =>
      _channel.invokeMethod<Uint8List>('previewStudyPdf', {
        'account': account,
        'id': page.documentId,
        'first': page.page,
      });
}

void openStudyPage(BuildContext context, StudyPageReference page, int account) {
  final image = StudyPdf(account).preview(page);
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text('PDF 第 ${page.page} 页')),
      body: FutureBuilder<Uint8List?>(
        future: image,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('${page.name}\n本机暂时无法打开此 PDF。')));
          }
          return InteractiveViewer(
              maxScale: 4, child: Center(child: Image.memory(bytes)));
        },
      ),
    ),
  ));
}
