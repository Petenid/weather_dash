# Weather Dash

A weather dashboard for Windows, built with Flutter for Monthly Build Challenge #1.

The top of the window is a sky that changes colour with the real weather: bright blue on a clear afternoon, grey under cloud, deep navy on a clear night. Along its bottom edge, the horizon traces the sun's path from sunrise to sunset and shows where the sun is right now.

<!-- Screenshots go here: add images to docs/ and link them, for example
![Weather Dash on a clear day](docs/screenshot-day.png) -->

## Download

Go to the [latest release](https://github.com/Petenid/weather_dash/releases/latest) and pick one:

- **WeatherDash-…-windows-setup.exe** installs Weather Dash with a Start menu shortcut. No administrator password needed.
- **WeatherDash-…-windows-portable.zip** runs without installing. Unzip it anywhere and open `weather_dash.exe`.

Requires 64-bit Windows 10 or 11. The app isn't code-signed, so Windows SmartScreen may warn the first time. Choose **More info**, then **Run anyway**.

## What it shows

- Current conditions: temperature, feels-like, wind, humidity and UV index
- The next 24 hours as a temperature chart
- A 7-day forecast, with each day's low-to-high range drawn on a shared scale and coloured by temperature
- Sunrise, sunset and hours of daylight
- City search for anywhere in the world
- °C or °F, remembered between sessions along with your last city
- Light and dark mode, following your Windows setting
- Refreshes itself every 15 minutes

Keyboard shortcuts: **Ctrl+F** finds a city, **F5** or **Ctrl+R** refreshes.

## Data and credits

- Weather data by [Open-Meteo.com](https://open-meteo.com/), under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- Place search by [GeoNames](https://www.geonames.org/), through Open-Meteo's geocoding API
- Typeface: [Barlow](https://github.com/jpt/barlow) by The Barlow Project Authors, under the SIL Open Font License (see `assets/fonts/OFL.txt`)

Open-Meteo needs no API key for non-commercial use, so this repository contains no keys or secrets.

## Build it yourself

1. Install [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop) and Visual Studio with the "Desktop development with C++" workload.
2. Clone this repository, then run:

   ```
   flutter pub get
   flutter run -d windows
   ```

3. For a release build: `flutter build windows --release`. The app ends up in `build\windows\x64\runner\Release`.

## How releases are made

GitHub Actions (`.github/workflows/build.yml`) checks the code, runs the tests and builds the app on every push to `main`. Pushing a version tag publishes a release with the installer and the zip:

```
git tag v1.0.0
git push origin v1.0.0
```

The installer is made with [Inno Setup](https://jrsoftware.org/isinfo.php) from `installer/weather_dash.iss`.
