import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart' as svg;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final svgPath = 'assets/Images/IconAndLogo/logo-normal.svg';
  final pngPath = 'assets/Images/IconAndLogo/logo-normal.png';

  if (!File(svgPath).existsSync()) {
    exit(1);
  }

  final svgString = await File(svgPath).readAsString();
  final svg.DrawableRoot svgRoot = await svg.fromSvgString(svgString, svgPath);

  const int size = 1024;
  final ui.Picture picture =
      svgRoot.toPicture(size: ui.Size(size.toDouble(), size.toDouble()));
  final ui.Image image = await picture.toImage(size, size);
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    exit(1);
  }
  final Uint8List pngBytes = byteData.buffer.asUint8List();
  await File(pngPath).writeAsBytes(pngBytes);
  exit(0);
}
