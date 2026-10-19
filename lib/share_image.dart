import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pasteboard/pasteboard.dart';

import 'strings.dart';

/// Takes a picture of whatever is inside the RepaintBoundary with [key].
Future<Uint8List> captureImage(GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Copies a picture of the weather, ready to paste into a chat or document.
Future<void> copyImage(GlobalKey key) async {
  final bytes = await captureImage(key);
  await Pasteboard.writeImage(bytes);
}

/// Saves a picture of the weather as a PNG file. In the desktop app this
/// asks where to save it; in a browser it downloads straight away.
/// Returns false if the person cancelled.
Future<bool> saveImage(GlobalKey key, String suggestedName) async {
  final bytes = await captureImage(key);
  final file = XFile.fromData(bytes, mimeType: 'image/png', name: suggestedName);
  if (kIsWeb) {
    await file.saveTo(suggestedName);
    return true;
  }
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: [
      XTypeGroup(label: t.pngImage, extensions: const ['png']),
    ],
  );
  if (location == null) return false;
  var path = location.path;
  if (!path.toLowerCase().endsWith('.png')) path = '$path.png';
  await file.saveTo(path);
  return true;
}
