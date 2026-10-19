import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pasteboard/pasteboard.dart';

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

/// Asks where to save, then saves a picture of the weather as a PNG file.
/// Returns false if the person cancelled.
Future<bool> saveImage(GlobalKey key, String suggestedName) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PNG image', extensions: ['png']),
    ],
  );
  if (location == null) return false;
  final bytes = await captureImage(key);
  var path = location.path;
  if (!path.toLowerCase().endsWith('.png')) path = '$path.png';
  await File(path).writeAsBytes(bytes);
  return true;
}
