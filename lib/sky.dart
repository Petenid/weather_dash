import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'alerts.dart';
import 'moon.dart';
import 'places.dart';
import 'sky_animation.dart';
import 'theme.dart';
import 'updates.dart';
import 'weather.dart';

/// The things in the sky's ⋮ menu.
enum SkyMenuAction { copyImage, saveImage, miniMode, settings }

/// The top of the screen: a sky whose colours follow the real weather, with
/// the place, the current temperature, and the sun's path along the horizon.
class SkyHeader extends StatelessWidget {
  const SkyHeader({
    super.key,
    required this.placeLabel,
    required this.report,
    required this.fahrenheit,
    required this.errorMessage,
    required this.onSearch,
    required this.onToggleUnits,
    required this.onRefresh,
    required this.favourites,
    required this.currentPlace,
    required this.isFavourite,
    required this.onToggleFavourite,
    required this.onChoosePlace,
    required this.alerts,
    required this.update,
    required this.onMenu,
    required this.onOpenLink,
  });

  final List<WeatherAlert> alerts;
  final UpdateInfo? update;
  final void Function(SkyMenuAction action) onMenu;
  final void Function(String url) onOpenLink;
  final List<Place> favourites;
  final Place currentPlace;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final void Function(Place place) onChoosePlace;
  final String placeLabel;
  final WeatherReport? report;
  final bool fahrenheit;
  final String? errorMessage;
  final VoidCallback onSearch;
  final VoidCallback onToggleUnits;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    final colors = report == null
        ? loadingSky
        : skyColors(report.current.weatherCode, isDay: report.current.isDay);

    // People who turn off animations in Windows get an instant change.
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      // A see-through Material lets buttons in the sky show their hover and
      // click effects on top of the gradient.
      child: Stack(
        children: [
          if (report != null)
            Positioned.fill(
              child: SkyAnimation(
                weatherCode: report.current.weatherCode,
                isDay: report.current.isDay,
              ),
            ),
          Material(
            type: MaterialType.transparency,
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.white),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TopBar(
                            placeLabel: placeLabel,
                            fahrenheit: fahrenheit,
                            onSearch: onSearch,
                            onToggleUnits: onToggleUnits,
                            onRefresh: onRefresh,
                            isFavourite: isFavourite,
                            onToggleFavourite: onToggleFavourite,
                            onMenu: onMenu,
                          ),
                          if (update != null)
                            _Banner(
                              icon: Icons.system_update_alt,
                              colour: Colors.white,
                              text: 'Weather Dash ${update!.version} is available.',
                              action: 'Download',
                              onTap: () => onOpenLink(update!.url),
                            ),
                          for (final alert in alerts)
                            _Banner(
                              icon: Icons.warning_amber_rounded,
                              colour: alert.displayColor,
                              text: alert.area.isEmpty ? alert.name : '${alert.name} for ${alert.area}',
                              action: 'Details',
                              onTap: () => _showAlert(context, alert, onOpenLink),
                            ),
                          if (favourites.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _FavouriteChips(
                              favourites: favourites,
                              current: currentPlace,
                              onChoose: onChoosePlace,
                            ),
                          ],
                          const SizedBox(height: 20),
                          if (report == null)
                            _Waiting(errorMessage: errorMessage, onRetry: onRefresh)
                          else ...[
                            _Conditions(report: report),
                            if (errorMessage != null)
                              _StaleNotice(
                                message: errorMessage!,
                                updated: report.current.time,
                                onRetry: onRefresh,
                              ),
                            const SizedBox(height: 28),
                            _SunHorizon(report: report),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.placeLabel,
    required this.fahrenheit,
    required this.onSearch,
    required this.onToggleUnits,
    required this.onRefresh,
    required this.isFavourite,
    required this.onToggleFavourite,
    required this.onMenu,
  });

  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final void Function(SkyMenuAction action) onMenu;

  final String placeLabel;
  final bool fahrenheit;
  final VoidCallback onSearch;
  final VoidCallback onToggleUnits;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: 'Find a city (Ctrl+F)',
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          placeLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.search,
                        size: 22,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(isFavourite ? Icons.star : Icons.star_border),
          color: isFavourite ? const Color(0xFFFFC34D) : Colors.white,
          tooltip: isFavourite ? 'Remove from saved places (Ctrl+D)' : 'Save this place (Ctrl+D)',
          onPressed: onToggleFavourite,
        ),
        const SizedBox(width: 8),
        _UnitToggle(fahrenheit: fahrenheit, onToggle: onToggleUnits),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.refresh),
          color: Colors.white,
          tooltip: 'Refresh (F5)',
          onPressed: onRefresh,
        ),
        PopupMenuButton<SkyMenuAction>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          tooltip: 'More',
          onSelected: onMenu,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: SkyMenuAction.copyImage,
              child: ListTile(leading: Icon(Icons.copy), title: Text('Copy as image')),
            ),
            PopupMenuItem(
              value: SkyMenuAction.saveImage,
              child: ListTile(leading: Icon(Icons.image_outlined), title: Text('Save as image…')),
            ),
            PopupMenuItem(
              value: SkyMenuAction.miniMode,
              child: ListTile(
                leading: Icon(Icons.picture_in_picture_alt_outlined),
                title: Text('Mini mode'),
                subtitle: Text('Ctrl+M'),
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: SkyMenuAction.settings,
              child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings')),
            ),
          ],
        ),
      ],
    );
  }
}

/// A one-line notice in the sky, with a coloured edge and a button.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.colour,
    required this.text,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final Color colour;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: colour, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colour),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

void _showAlert(BuildContext context, WeatherAlert alert, void Function(String url) onOpenLink) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: alert.displayColor, size: 36),
      title: Text(alert.name),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alert.area.isNotEmpty) Text(alert.area, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (alert.expires != null)
                Text('In effect until ${hoursMinutes(alert.expires!)} on ${alert.expires!.month}/${alert.expires!.day}.'),
              const SizedBox(height: 12),
              Text(alert.text.isEmpty ? 'No further details were given.' : alert.text),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => onOpenLink('https://weather.gc.ca/warnings/index_e.html'),
          child: const Text('Open Environment Canada'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}

/// Saved places as small buttons under the place name. The one on screen is
/// filled in.
class _FavouriteChips extends StatelessWidget {
  const _FavouriteChips({
    required this.favourites,
    required this.current,
    required this.onChoose,
  });

  final List<Place> favourites;
  final Place current;
  final void Function(Place place) onChoose;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final place in favourites)
          Tooltip(
            message: place.details.isEmpty ? place.name : '${place.name}, ${place.details}',
            child: InkWell(
              onTap: () => onChoose(place),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: place.sameAs(current) ? Colors.white : Colors.transparent,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  place.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: place.sameAs(current) ? const Color(0xFF13202A) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A small two-part switch: °C | °F. The chosen unit is filled in.
class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.fahrenheit, required this.onToggle});

  final bool fahrenheit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    Widget part(String label, bool selected) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF13202A) : Colors.white,
          ),
        ),
      );
    }

    return Tooltip(
      message: fahrenheit ? 'Show Celsius' : 'Show Fahrenheit',
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [part('°C', !fahrenheit), part('°F', fahrenheit)],
          ),
        ),
      ),
    );
  }
}

/// Shown in the sky before the first forecast arrives.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.errorMessage, required this.onRetry});

  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = errorMessage;
    return SizedBox(
      height: 260,
      child: Center(
        child: message == null
            ? const CircularProgressIndicator(color: Colors.white)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 44),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF13202A),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The big temperature and what the weather is doing.
class _Conditions extends StatelessWidget {
  const _Conditions({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final now = report.current;
    final today = report.today;
    final soft = Colors.white.withValues(alpha: 0.88);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 28,
      runSpacing: 8,
      children: [
        Text(
          degrees(now.temperature),
          style: numberStyle(136, weight: FontWeight.w300, color: Colors.white),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(weatherIcon(now.weatherCode, isDay: now.isDay), size: 28),
                  const SizedBox(width: 10),
                  Text(
                    describeWeather(now.weatherCode),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Feels like ${degrees(now.feelsLike)}',
                style: TextStyle(fontSize: 18, color: soft),
              ),
              if (today != null)
                Text(
                  'High ${degrees(today.high)}    Low ${degrees(today.low)}',
                  style: TextStyle(fontSize: 18, color: soft),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// When a refresh fails but older data is still on screen.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({
    required this.message,
    required this.updated,
    required this.onRetry,
  });

  final String message;
  final DateTime updated;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          const Icon(Icons.error_outline, size: 18),
          Text("Couldn't refresh. Showing the forecast from ${hoursMinutes(updated)}."),
          Tooltip(
            message: message,
            child: TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The horizon line along the bottom of the sky, with the sun's path from
/// sunrise to sunset drawn above it. In the daytime the sun sits on the path
/// where it is right now. After sunset it rests just below the horizon on the
/// right, where it went down; before sunrise it waits below the left end.
class _SunHorizon extends StatelessWidget {
  const _SunHorizon({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final now = report.current.time;
    final today = report.today;
    final sunrise = today?.sunrise;
    final sunset = today?.sunset;
    const labelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
    final moon = MoonPhase.at(DateTime.now());

    // A line in the middle saying what the sun does next.
    String? next;
    if (sunrise != null && sunset != null) {
      if (now.isBefore(sunrise)) {
        next = 'Sun rises in ${_until(now, sunrise)}';
      } else if (now.isBefore(sunset)) {
        next = 'Sun sets in ${_until(now, sunset)}';
      } else {
        // After sunset, the next sunrise is tomorrow's.
        final tomorrow = report.daily.length > 1 ? report.daily[1].sunrise : null;
        next = tomorrow == null
            ? 'The sun has set'
            : 'Sun rises in ${_until(now, tomorrow)}';
      }
    }

    return SizedBox(
      height: 76,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SunPathPainter(
                sunrise: sunrise,
                sunset: sunset,
                now: now,
              ),
            ),
          ),
          if (sunrise != null)
            Positioned(
              left: 0,
              top: 0,
              child: Text('Sunrise ${hoursMinutes(sunrise)}', style: labelStyle),
            ),
          if (next != null)
            Align(
              alignment: Alignment.topCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // At night, the moon's current phase sits beside the label.
                  if (!report.current.isDay) ...[
                    Tooltip(
                      message: '${moon.name}, ${(moon.illumination * 100).round()}% lit',
                      child: MoonPicture(phase: moon, size: 18),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    next,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          if (sunset != null)
            Positioned(
              right: 0,
              top: 0,
              child: Text('Sunset ${hoursMinutes(sunset)}', style: labelStyle),
            ),
        ],
      ),
    );
  }
}

/// "2 h 05 min" or "40 min" from one time to a later one.
String _until(DateTime from, DateTime to) {
  final minutes = to.difference(from).inMinutes;
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')} min';
}

class _SunPathPainter extends CustomPainter {
  _SunPathPainter({
    required this.sunrise,
    required this.sunset,
    required this.now,
  });

  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime now;

  static const _sunColor = Color(0xFFFFC34D);

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height - 1;
    final arcHeight = size.height * 0.7;

    // The point on the sun's path for a fraction of the day, 0 to 1.
    Offset pointAt(double t) =>
        Offset(t * size.width, base - math.sin(math.pi * t) * arcHeight);

    Path pathTo(double end) {
      final path = Path()..moveTo(0, base);
      const steps = 80;
      for (var i = 1; i <= steps; i++) {
        final p = pointAt(end * i / steps);
        path.lineTo(p.dx, p.dy);
      }
      return path;
    }

    // The full path, faint.
    canvas.drawPath(
      pathTo(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.3),
    );

    final rise = sunrise;
    final set = sunset;
    if (rise != null && set != null && set.isAfter(rise)) {
      _drawSun(canvas, size, rise, set, base, pointAt, pathTo);
    }

    // The horizon, drawn last so it sits on top of the sun.
    canvas.drawLine(
      Offset(0, base),
      Offset(size.width, base),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _drawSun(
    Canvas canvas,
    Size size,
    DateTime rise,
    DateTime set,
    double base,
    Offset Function(double t) pointAt,
    Path Function(double end) pathTo,
  ) {
    if (!now.isBefore(rise) && !now.isAfter(set)) {
      // Daytime: highlight the part of the path already travelled today,
      // and put the sun where it is now.
      final t = now.difference(rise).inMinutes / set.difference(rise).inMinutes;
      canvas.drawPath(
        pathTo(t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.9),
      );
      final sun = pointAt(t);
      canvas.drawCircle(sun, 15, Paint()..color = _sunColor.withValues(alpha: 0.25));
      canvas.drawCircle(sun, 8, Paint()..color = _sunColor);
    } else {
      // Night: the sun peeks up from just below the horizon, on the right
      // after sunset or on the left before sunrise. Clipping to the area
      // above the horizon hides the part of the sun that's "underground".
      final x = now.isAfter(set) ? size.width - 18 : 18.0;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, size.width, base));
      canvas.drawCircle(
        Offset(x, base + 3),
        11,
        Paint()..color = _sunColor.withValues(alpha: 0.6),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SunPathPainter old) =>
      old.sunrise != sunrise || old.sunset != sunset || old.now != now;
}
