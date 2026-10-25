import 'package:flutter/material.dart';
import 'creation_catalog.dart';

int creationInt(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
double creationDouble(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

int creationArgb(Color color) =>
    (color.a * 255).round() << 24 |
    (color.r * 255).round() << 16 |
    (color.g * 255).round() << 8 |
    (color.b * 255).round();

class CreationInk {
  final List<Offset> points;
  final double width;
  final Color color;
  const CreationInk(
      {required this.points,
      this.width = .006,
      this.color = const Color(0xff202126)});
  Map<String, dynamic> toJson() => {
        'points': points.map((point) => [point.dx, point.dy]).toList(),
        'width': width,
        'color': creationArgb(color),
      };
  factory CreationInk.fromJson(Map<String, dynamic> data) => CreationInk(
        points: (data['points'] as List)
            .map((point) =>
                Offset(creationDouble(point[0]), creationDouble(point[1])))
            .toList(growable: false),
        width: creationDouble(data['width'], .006),
        color: Color(creationInt(data['color'], 0xff202126)),
      );
}

class CreationCrop {
  final double scale;
  final double x;
  final double y;
  const CreationCrop({this.scale = 1, this.x = 0, this.y = 0});
  Map<String, dynamic> toJson() => {'scale': scale, 'x': x, 'y': y};
  factory CreationCrop.fromJson(Map<String, dynamic> data) => CreationCrop(
        scale: creationDouble(data['scale'], 1).clamp(1, 5),
        x: creationDouble(data['x']).clamp(-2, 2),
        y: creationDouble(data['y']).clamp(-2, 2),
      );
}

class CreationDocument {
  final String kind;
  final String templateId;
  final String lookId;
  final double intensity;
  final String title;
  final String note;
  final String? date;
  final Color accent;
  final Color background;
  final bool gradient;
  final List<CreationInk> frontInk;
  final List<CreationInk> backInk;
  final List<CreationCrop> transforms;
  const CreationDocument(
      {this.kind = 'polaroid',
      this.templateId = 'classic',
      this.lookId = 'instant_clear',
      this.intensity = 1,
      this.title = '',
      this.note = '',
      this.date,
      this.accent = const Color(0xff7d899b),
      this.background = const Color(0xffeef0f3),
      this.gradient = false,
      this.frontInk = const [],
      this.backInk = const [],
      this.transforms = const [CreationCrop()]});

  PaperTemplate get paper =>
      paperTemplates.firstWhere((value) => value.id == templateId,
          orElse: () => paperTemplates.first);
  TicketTemplate get ticket =>
      ticketTemplates.firstWhere((value) => value.id == templateId,
          orElse: () => ticketTemplates.first);
  CreationLook get look =>
      creationLooks.firstWhere((value) => value.id == lookId,
          orElse: () => creationLooks.first);
  double get aspectRatio => kind == 'ticket' ? ticket.aspectRatio : 88 / 107;
  int get minimumPhotos => kind == 'ticket' ? ticket.minimumPhotos : 1;

  CreationDocument copyWith(
          {String? templateId,
          String? lookId,
          double? intensity,
          String? title,
          String? note,
          String? date,
          Color? accent,
          Color? background,
          bool? gradient,
          List<CreationInk>? frontInk,
          List<CreationInk>? backInk,
          List<CreationCrop>? transforms}) =>
      CreationDocument(
        kind: kind,
        templateId: templateId ?? this.templateId,
        lookId: lookId ?? this.lookId,
        intensity: intensity ?? this.intensity,
        title: title ?? this.title,
        note: note ?? this.note,
        date: date ?? this.date,
        accent: accent ?? this.accent,
        background: background ?? this.background,
        gradient: gradient ?? this.gradient,
        frontInk: frontInk ?? this.frontInk,
        backInk: backInk ?? this.backInk,
        transforms: transforms ?? this.transforms,
      );
  Map<String, dynamic> toJson() => {
        'schema': 1,
        'kind': kind,
        'templateId': templateId,
        'lookId': lookId,
        'intensity': intensity,
        'title': title,
        'note': note,
        'date': date,
        'accent': creationArgb(accent),
        'background': creationArgb(background),
        'gradient': gradient,
        'frontInk': frontInk.map((value) => value.toJson()).toList(),
        'backInk': backInk.map((value) => value.toJson()).toList(),
        'transforms': transforms.map((value) => value.toJson()).toList(),
      };
  factory CreationDocument.fromJson(Map<String, dynamic> data) =>
      CreationDocument(
        kind: data['kind']?.toString() ?? 'polaroid',
        templateId: data['templateId']?.toString() ?? 'classic',
        lookId: data['lookId']?.toString() ?? 'instant_clear',
        intensity: creationDouble(data['intensity'], 1).clamp(0, 1),
        title: data['title']?.toString() ?? '',
        note: data['note']?.toString() ?? '',
        date: data['date']?.toString(),
        accent: Color(creationInt(data['accent'], 0xff7d899b)),
        background: Color(creationInt(data['background'], 0xffeef0f3)),
        gradient: data['gradient'] == true,
        frontInk: ((data['frontInk'] as List?) ?? [])
            .map((value) =>
                CreationInk.fromJson(Map<String, dynamic>.from(value)))
            .toList(growable: false),
        backInk: ((data['backInk'] as List?) ?? [])
            .map((value) =>
                CreationInk.fromJson(Map<String, dynamic>.from(value)))
            .toList(growable: false),
        transforms: ((data['transforms'] as List?) ?? [{}])
            .map((value) =>
                CreationCrop.fromJson(Map<String, dynamic>.from(value)))
            .toList(growable: false),
      );
}

class CreationWork {
  final int id;
  final String clientId;
  final int ownerId;
  final int revision;
  final int? tripId;
  final String? tripTitle;
  final String previewUrl;
  final List<String> sourceUrls;
  final CreationDocument document;
  final DateTime updatedAt;
  const CreationWork(
      {required this.id,
      required this.clientId,
      required this.ownerId,
      required this.revision,
      this.tripId,
      this.tripTitle,
      required this.previewUrl,
      required this.sourceUrls,
      required this.document,
      required this.updatedAt});
  factory CreationWork.fromJson(Map<String, dynamic> data) => CreationWork(
        id: creationInt(data['id']),
        clientId: data['clientId'].toString(),
        ownerId: creationInt(data['ownerId']),
        revision: creationInt(data['revision']),
        tripId: data['tripId'] == null ? null : creationInt(data['tripId']),
        tripTitle: data['tripTitle']?.toString(),
        previewUrl: data['previewUrl'].toString(),
        sourceUrls: (data['sourceUrls'] as List)
            .map((value) => value.toString())
            .toList(),
        document: CreationDocument.fromJson(
            Map<String, dynamic>.from(data['document'])),
        updatedAt: DateTime.parse(data['updatedAt'].toString()),
      );
}

class CreationDraft {
  final String id;
  final int ownerId;
  final CreationDocument document;
  final List<String> sourcePaths;
  final int? workId;
  final int? revision;
  final int? tripId;
  final String? tripTitle;
  final DateTime updatedAt;
  const CreationDraft(
      {required this.id,
      required this.ownerId,
      required this.document,
      required this.sourcePaths,
      this.workId,
      this.revision,
      this.tripId,
      this.tripTitle,
      required this.updatedAt});
  CreationDraft copyWith(
          {CreationDocument? document,
          List<String>? sourcePaths,
          int? workId,
          int? revision,
          int? tripId,
          String? tripTitle,
          bool clearTrip = false}) =>
      CreationDraft(
        id: id,
        ownerId: ownerId,
        document: document ?? this.document,
        sourcePaths: sourcePaths ?? this.sourcePaths,
        workId: workId ?? this.workId,
        revision: revision ?? this.revision,
        tripId: clearTrip ? null : tripId ?? this.tripId,
        tripTitle: clearTrip ? null : tripTitle ?? this.tripTitle,
        updatedAt: DateTime.now(),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'document': document.toJson(),
        'sourcePaths': sourcePaths,
        'workId': workId,
        'revision': revision,
        'tripId': tripId,
        'tripTitle': tripTitle,
        'updatedAt': updatedAt.toIso8601String(),
      };
  factory CreationDraft.fromJson(Map<String, dynamic> data) => CreationDraft(
        id: data['id'].toString(),
        ownerId: creationInt(data['ownerId']),
        document: CreationDocument.fromJson(
            Map<String, dynamic>.from(data['document'])),
        sourcePaths: (data['sourcePaths'] as List)
            .map((value) => value.toString())
            .toList(),
        workId: data['workId'] == null ? null : creationInt(data['workId']),
        revision:
            data['revision'] == null ? null : creationInt(data['revision']),
        tripId: data['tripId'] == null ? null : creationInt(data['tripId']),
        tripTitle: data['tripTitle']?.toString(),
        updatedAt: DateTime.parse(data['updatedAt'].toString()),
      );
}
