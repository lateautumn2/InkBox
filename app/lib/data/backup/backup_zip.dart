import 'package:archive/archive_io.dart';

Map<String, ArchiveFile> readBackupZip(
  InputFileStream input, {
  required int maxEntries,
  required int maxEntryBytes,
  required int maxTotalBytes,
}) {
  final directory = ZipDirectory();
  final entries = <String, ArchiveFile>{};
  var total = 0;
  input.byteOrder = ByteOrder.littleEndian;
  try {
    for (final header in directory.headers(input, verify: true)) {
      if (entries.length >= maxEntries) {
        throw const FormatException('Backup contains too many archive entries');
      }
      if (header.versionMadeBy >> 8 == 3 &&
          (header.externalFileAttributes >> 16) & 0xf000 == 0xa000) {
        throw const FormatException('Backup contains a symbolic link');
      }
      final file = header.file!;
      file.verify = true;
      file.throwOnError = true;
      final name = file.filename;
      if (entries.containsKey(name)) {
        throw const FormatException(
          'Backup contains duplicate archive entries',
        );
      }
      final size = file.uncompressedSize;
      if (size < 0 || size > maxEntryBytes || size > maxTotalBytes - total) {
        throw const FormatException('Backup archive exceeds the size limit');
      }
      total += size;
      entries[name] = name.endsWith('/')
          ? ArchiveFile.directory(name)
          : ArchiveFile.file(name, size, file);
    }
    if (directory.filePosition < 0) {
      throw const FormatException('Invalid backup archive');
    }
    return entries;
  } on ArchiveException {
    throw const FormatException('Invalid backup archive');
  }
}
