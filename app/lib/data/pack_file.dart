import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:verger_core/verger_core.dart';

/// Paquet d'arbre (`.verger`) : archive ZIP contenant `pack.json` (une
/// [VergerArchive] : arbre, connaissances, contenus, ancres, notes) et,
/// pour les PDF inclus, `files/<identifiant>.pdf`. Un PDF non inclus est
/// décrit par son adresse et son empreinte : il sera téléchargé à l'import.
abstract final class PackFile {
  static const extension = 'verger';
  static const _manifest = 'pack.json';

  static Uint8List encode(VergerArchive archive, Map<String, Uint8List> pdfs) {
    final zip = Archive()
      ..add(
        ArchiveFile.string(
          _manifest,
          const JsonEncoder.withIndent(' ').convert(archive.toJson()),
        ),
      );
    for (final e in pdfs.entries) {
      zip.add(ArchiveFile.bytes('files/${e.key}.pdf', e.value));
    }
    return ZipEncoder().encodeBytes(zip);
  }

  /// Lit un paquet ; lève [ArchiveFormatException] s'il est invalide.
  static (VergerArchive, Map<String, Uint8List>) decode(Uint8List bytes) {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const ArchiveFormatException('Ce fichier n\'est pas un paquet.');
    }
    final manifest = zip.findFile(_manifest);
    if (manifest == null) {
      throw const ArchiveFormatException(
        'Paquet incomplet (pack.json absent).',
      );
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(manifest.content));
    } on FormatException {
      throw const ArchiveFormatException(
        'pack.json n\'est pas un JSON valide.',
      );
    }
    if (json is! Map) {
      throw const ArchiveFormatException('pack.json invalide.');
    }
    final archive = VergerArchive.fromJson(json.cast<String, Object?>());
    final pdfs = <String, Uint8List>{};
    for (final d in archive.documents) {
      final file = zip.findFile('files/${d.id}.pdf');
      if (file != null) pdfs[d.id] = file.content;
    }
    return (archive, pdfs);
  }
}
