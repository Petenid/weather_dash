import 'package:flutter/foundation.dart';

/// True while Weather Dash is the window in front (or the browser tab being
/// looked at). Kept up to date by the home page, and read by the sky
/// animation so it can rest while nobody is watching.
final appInForeground = ValueNotifier<bool>(true);
