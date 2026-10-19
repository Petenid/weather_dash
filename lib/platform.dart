import 'package:flutter/foundation.dart';

/// True in the desktop app (Windows, and Mac or Linux if built for them).
/// False in the browser and on phones, where saving files to a chosen folder
/// and the small always-on-top window don't apply.
bool get desktopFeatures =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// True when running as a web page.
const runningOnWeb = kIsWeb;
