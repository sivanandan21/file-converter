import 'package:hive/hive.dart';

part 'conversion_record.g.dart';

@HiveType(typeId: 0)
class ConversionRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String conversionType; // e.g. "PDF â†’ Image"

  @HiveField(2)
  final String sourceFileName;

  @HiveField(3)
  final String outputFileName;

  @HiveField(4)
  final String outputFilePath;

  @HiveField(5)
  final int outputFileSize; // bytes

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  bool isStarred;

  ConversionRecord({
    required this.id,
    required this.conversionType,
    required this.sourceFileName,
    required this.outputFileName,
    required this.outputFilePath,
    required this.outputFileSize,
    required this.createdAt,
    this.isStarred = false,
  });

  String get outputExtension {
    final parts = outputFileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : '';
  }

  ConversionRecord copyWith({bool? isStarred}) {
    return ConversionRecord(
      id: id,
      conversionType: conversionType,
      sourceFileName: sourceFileName,
      outputFileName: outputFileName,
      outputFilePath: outputFilePath,
      outputFileSize: outputFileSize,
      createdAt: createdAt,
      isStarred: isStarred ?? this.isStarred,
    );
  }
}
