// Every piece of text in Weather Dash, in English and Quebec French.
//
// Each getter or function returns the right language for the current
// setting, so the rest of the app writes `t.feelsLike(...)` instead of a
// fixed English sentence. Keeping both languages side by side makes it easy
// to check that nothing is missing.
//
// French follows Quebec usage where it differs from France: Environment
// Canada's weather vocabulary (averses, bruine, verglaçante...), times
// written as "13 h 05", a space before % and before a colon.

/// True while the app is showing French. Set from the settings.
bool frenchActive = false;

/// The app's text. Use the shared instance [t].
class Strings {
  const Strings();

  bool get fr => frenchActive;
  String _p(String en, String fr) => this.fr ? fr : en;

  // ---- Formatting -------------------------------------------------------

  /// A decimal number: "1.5" in English, "1,5" in French.
  String decimal(double value, int digits) {
    final s = value.toStringAsFixed(digits);
    return fr ? s.replaceAll('.', ',') : s;
  }

  /// "60%" in English, "60 %" in French (with a non-breaking space).
  String percent(num value) => fr ? '${value.round()} %' : '${value.round()}%';

  String weekdayShort(DateTime d) => (fr ? _weekdaysShortFr : _weekdaysShortEn)[d.weekday - 1];
  String weekday(DateTime d) => (fr ? _weekdaysFr : _weekdaysEn)[d.weekday - 1];
  String month(int m) => (fr ? _monthsFr : _monthsEn)[m - 1];

  /// "October 18" / "18 octobre" ("1er octobre" on the first).
  String dayMonth(DateTime d) =>
      fr ? '${d.day == 1 ? '1er' : d.day} ${month(d.month)}' : '${month(d.month)} ${d.day}';

  /// "Thursday, October 22" / "jeudi 22 octobre".
  String fullDate(DateTime d) => fr ? '${weekday(d)} ${dayMonth(d)}' : '${weekday(d)}, ${dayMonth(d)}';

  /// A length of time: "10 h 47 min" (the same in both languages).
  String duration(Duration d) =>
      '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')} min';

  /// "2 h 05 min" or "40 min".
  String minutesSpan(int minutes) =>
      minutes < 60 ? '$minutes min' : duration(Duration(minutes: minutes));

  // ---- General ----------------------------------------------------------

  String get appName => 'Weather Dash';
  String get tryAgain => _p('Try again', 'Réessayer');
  String get close => _p('Close', 'Fermer');
  String get details => _p('Details', 'Détails');
  String get today => _p('Today', "Aujourd'hui");
  String get now => _p('Now', 'Maintenant');
  String get loading => _p('Loading…', 'Chargement…');
  String highLow(String high, String low) => _p('High $high    Low $low', 'Max. $high    Min. $low');
  String get highWord => _p('High', 'Max.');
  String get lowWord => _p('Low', 'Min.');
  String feelsLike(String temp) => _p('Feels like $temp', 'Ressenti $temp');
  String couldNotOpen(String url) => _p("Couldn't open $url", "Impossible d'ouvrir $url");

  // ---- Errors ------------------------------------------------------------

  String serviceError(String service, int code) =>
      _p('$service returned error $code.', "$service a renvoyé l'erreur $code.");
  String serviceHiccup(String service) =>
      _p('$service had a temporary problem.', '$service a eu un problème passager.');
  String get timeoutError => _p(
        'The weather service took too long to answer. Check your connection and try again.',
        'Le service météo a mis trop de temps à répondre. Vérifiez votre connexion et réessayez.',
      );
  String get offlineError => _p(
        "Can't reach the weather service. Check your internet connection and try again.",
        'Impossible de joindre le service météo. Vérifiez votre connexion Internet et réessayez.',
      );
  String get airService => _p('The air quality service', "Le service de qualité de l'air");
  String get historyService => _p('The historical weather service', 'Le service des données historiques');
  String get searchService => _p('The search service', 'Le service de recherche');
  String get noHistory =>
      _p('No historical records for this place.', 'Aucune donnée historique pour cet endroit.');
  String get noModels => _p(
        'No model forecasts are available for this place.',
        "Aucune prévision des modèles n'est offerte pour cet endroit.",
      );

  // ---- Top of the screen (sky) ------------------------------------------

  String get findCityTip => _p('Find a city (Ctrl+F)', 'Trouver une ville (Ctrl+F)');
  String get saveFavouriteTip => _p('Save this place (Ctrl+D)', 'Enregistrer cet endroit (Ctrl+D)');
  String get removeFavouriteTip =>
      _p('Remove from saved places (Ctrl+D)', 'Retirer des endroits enregistrés (Ctrl+D)');
  String get refreshTip => _p('Refresh (F5)', 'Actualiser (F5)');
  String get more => _p('More', 'Plus');
  String get copyImage => _p('Copy as image', 'Copier comme image');
  String get saveImage => _p('Save as image…', 'Enregistrer comme image…');
  String get miniMode => _p('Mini mode', 'Mode mini');
  String get settings => _p('Settings', 'Paramètres');
  String get showCelsius => _p('Show Celsius', 'Afficher en Celsius');
  String get showFahrenheit => _p('Show Fahrenheit', 'Afficher en Fahrenheit');
  String updateAvailable(String v) => _p('Weather Dash $v is available.', 'Weather Dash $v est offert.');
  String get download => _p('Download', 'Télécharger');
  String alertFor(String name, String area) => _p('$name for $area', '$name pour $area');
  String inEffectUntil(String time, DateTime d) =>
      _p('In effect until $time on ${dayMonth(d)}.', "En vigueur jusqu'à $time le ${dayMonth(d)}.");
  String get noAlertDetails =>
      _p('No further details were given.', "Aucun autre détail n'a été fourni.");
  String get openEnvCanada => _p('Open Environment Canada', 'Ouvrir Environnement Canada');
  String get envCanadaWarningsUrl => _p(
        'https://weather.gc.ca/warnings/index_e.html',
        'https://meteo.gc.ca/warnings/index_f.html',
      );
  String staleForecast(String time) => _p(
        "Couldn't refresh. Showing the forecast from $time.",
        'Actualisation impossible. Prévisions de $time affichées.',
      );
  String sunrisesIn(String span) => _p('Sun rises in $span', 'Lever du soleil dans $span');
  String sunsetsIn(String span) => _p('Sun sets in $span', 'Coucher du soleil dans $span');
  String get sunHasSet => _p('The sun has set', 'Le soleil est couché');
  String sunriseAt(String time) => _p('Sunrise $time', 'Lever $time');
  String sunsetAt(String time) => _p('Sunset $time', 'Coucher $time');
  String moonLit(String phase, int percentLit) =>
      _p('$phase, $percentLit% lit', '$phase, éclairée à ${percent(percentLit)}');

  // ---- Main sections ------------------------------------------------------

  String get atAGlance => _p('At a glance', "En un coup d'œil");
  String get next24Hours => _p('Next 24 hours', 'Prochaines 24 heures');
  String get sevenDay => _p('7-day forecast', 'Prévisions sur 7 jours');
  String get clickADay =>
      _p('Click a day for hour-by-hour details.', 'Cliquez sur un jour pour le détail heure par heure.');
  String get temperature => _p('Temperature', 'Température');
  String get precipitation => _p('Precipitation', 'Précipitations');
  String get wind => _p('Wind', 'Vent');
  String get gusts => _p('Gusts', 'Rafales');
  String get noPrecipExpected => _p('No rain or snow expected', 'Aucune pluie ni neige prévue');
  String precipTooltip(String chance, String amount) =>
      _p('$chance chance\n$amount expected', 'Probabilité de $chance\n$amount prévus');
  String get hourByHour => _p('Hour by hour', 'Heure par heure');

  // ---- Details panel ------------------------------------------------------

  String fromDirection(String dir) => _p('From the $dir', fr ? (dir.startsWith('e') || dir.startsWith('o') ? "De l'$dir" : 'Du $dir') : '');
  String get humidity => _p('Humidity', 'Humidité');
  String get airQuality => _p('Air quality', "Qualité de l'air");
  String fineParticles(int value) => _p('fine particles $value µg/m³', 'particules fines $value µg/m³');
  String get unavailable => _p('Unavailable right now', 'Non disponible pour le moment');
  String get aqiTip => _p(
        'US Air Quality Index, 0 to 500. Lower is better.',
        "Indice américain de la qualité de l'air (AQI), de 0 à 500. Plus il est bas, mieux c'est.",
      );
  String get uvIndex => _p('UV index', 'Indice UV');
  String get uvPeakToday => _p('UV peak today', "Indice UV maximal aujourd'hui");
  String get moon => _p('Moon', 'Lune');
  String get sunrise => _p('Sunrise', 'Lever du soleil');
  String get sunset => _p('Sunset', 'Coucher du soleil');
  String get daylight => _p('Daylight', 'Durée du jour');
  String updated(String time, int minutes) => _p(
        'Updated $time, local time. Refreshes every $minutes minutes.',
        'Mis à jour à $time, heure locale. Actualisation toutes les $minutes minutes.',
      );
  String get windChill => _p('Wind chill', 'Refroidissement éolien');
  String get humidex => 'Humidex';

  // ---- Wind chill and humidex (Environment Canada's categories) ----------

  String windChillRisk(double wc) {
    if (wc > -10) return _p('Low risk', 'Risque faible');
    if (wc > -28) return _p('Moderate risk: dress warmly', 'Risque modéré : habillez-vous chaudement');
    if (wc > -40) {
      return _p('High risk: frostbite in 10 to 30 minutes', 'Risque élevé : engelures en 10 à 30 minutes');
    }
    if (wc > -48) {
      return _p('Very high risk: frostbite in 5 to 10 minutes', 'Risque très élevé : engelures en 5 à 10 minutes');
    }
    if (wc > -55) {
      return _p('Severe risk: frostbite in 2 to 5 minutes', 'Risque grave : engelures en 2 à 5 minutes');
    }
    return _p('Extreme risk: frostbite in under 2 minutes', 'Risque extrême : engelures en moins de 2 minutes');
  }

  String humidexLevel(double h) {
    if (h < 30) return _p('Little or no discomfort', "Peu ou pas d'inconfort");
    if (h < 40) return _p('Some discomfort', 'Un certain inconfort');
    if (h <= 45) return _p('Great discomfort: avoid exertion', 'Grand inconfort : évitez les efforts');
    if (h < 54) return _p('Dangerous: risk of heat stroke', 'Dangereux : risque de coup de chaleur');
    return _p('Heat stroke likely', 'Coup de chaleur probable');
  }

  String windChillWarning(String value, String risk) => _p(
        'Wind chill of $value right now. $risk. Cover exposed skin.',
        'Refroidissement éolien de $value en ce moment. $risk. Couvrez la peau exposée.',
      );
  String humidexWarning(String value, String level) => _p(
        'Humidex of $value right now. $level. Drink plenty of water.',
        "Humidex de $value en ce moment. $level. Buvez beaucoup d'eau.",
      );

  // ---- Photographer's times ------------------------------------------------

  String get lightForPhotos => _p('Light for photos', 'Lumière pour la photo');
  String get blueHourMorning => _p('Morning blue hour', 'Heure bleue du matin');
  String get goldenHourMorning => _p('Morning golden hour', 'Heure dorée du matin');
  String get goldenHourEvening => _p('Evening golden hour', 'Heure dorée du soir');
  String get blueHourEvening => _p('Evening blue hour', 'Heure bleue du soir');
  String timeRange(String a, String b) => _p('$a to $b', '$a à $b');
  String get photoTip => _p(
        'Golden hour: the sun is low and the light is warm and soft. '
            'Blue hour: the sun is just below the horizon and the sky turns deep blue.',
        "Heure dorée : le soleil est bas et la lumière est chaude et douce. "
            "Heure bleue : le soleil est juste sous l'horizon et le ciel devient bleu profond.",
      );

  // ---- Day details ---------------------------------------------------------

  String todayDate(DateTime d) => _p('Today, ${dayMonth(d)}', "Aujourd'hui, ${dayMonth(d)}");
  String get previousDay => _p('Previous day', 'Jour précédent');
  String get nextDay => _p('Next day', 'Jour suivant');
  String get chanceOfPrecip => _p('Chance of rain or snow', 'Probabilité de pluie ou de neige');
  String get expectedTotal => _p('Expected total', 'Total prévu');
  String get strongestWind => _p('Strongest wind', 'Vent le plus fort');
  String strongestWindFrom(String dir) => _p('Strongest wind, from the $dir', 'Vent le plus fort, ${fromDirection(dir).toLowerCase()}');
  String get gustsUpTo => _p('Gusts up to', "Rafales jusqu'à");
  String uvPeak(String level) =>
      _p('UV peak, ${level.toLowerCase()}', 'Indice UV max., ${level.toLowerCase()}');

  // ---- Insights ---------------------------------------------------------

  String normalAbout(String high, String date) => _p(
        "Today's high of $high is about normal for $date.",
        "Le maximum d'aujourd'hui, $high, est près de la normale pour le $date.",
      );
  String normalDiff(String high, int diff, bool warmer, String date, String normal) => _p(
        "Today's high of $high is $diff° ${warmer ? 'warmer' : 'colder'} than normal for $date. "
            'The 30-year average high is $normal.',
        "Le maximum d'aujourd'hui, $high, est $diff° ${warmer ? 'au-dessus de' : 'sous'} la normale pour le $date. "
            'La moyenne des maximums sur 30 ans est de $normal.',
      );
  String bestTime(bool today, String from, String to, String temp, int rain) {
    final dry = rain < 20;
    return _p(
      'Best time to be outside ${today ? 'today' : 'tomorrow'}: $from to $to, around $temp '
          '${dry ? 'and likely dry' : 'with a $rain% chance of rain or snow'}.',
      "Meilleur moment pour sortir ${today ? "aujourd'hui" : 'demain'} : de $from à $to, environ $temp, "
          '${dry ? 'probablement au sec' : 'avec ${percent(rain)} de risque de pluie ou de neige'}.',
    );
  }

  String frostTonight(String low) => _p(
        'Frost likely tonight, down to $low. Cover tender plants and expect icy windshields in the morning.',
        "Gel probable cette nuit, jusqu'à $low. Protégez les plantes fragiles et prévoyez des pare-brise givrés au matin.",
      );
  String nextFrost(DateTime day, String low) => _p(
        'No frost tonight. The next frost looks likely early ${weekday(day)} morning, down to $low.',
        "Pas de gel cette nuit. Le prochain gel semble probable tôt ${weekday(day)} matin, jusqu'à $low.",
      );

  /// [chance] is 'good', 'possible' or 'unlikely'.
  String auroraChance(String chance) => switch (chance) {
        'good' => _p('good chance', 'bonnes chances'),
        'possible' => _p('possible', 'possibles'),
        _ => _p('unlikely', 'peu probables'),
      };
  String auroraNote(bool southern, String chance, String kp, String needed, bool cloudy) {
    final lights = southern
        ? _p('Southern lights', 'Aurores australes')
        : _p('Northern lights', 'Aurores boréales');
    return _p(
      '$lights tonight: $chance. Geomagnetic activity should reach about Kp $kp; '
          'seeing them from here usually takes Kp $needed or more.${cloudy ? ' Cloud may hide the sky.' : ''}',
      "$lights cette nuit : $chance. L'activité géomagnétique devrait atteindre environ Kp $kp; "
          "il faut habituellement Kp $needed ou plus pour les voir d'ici.${cloudy ? ' Les nuages pourraient les cacher.' : ''}",
    );
  }

  // ---- Model comparison ------------------------------------------------------

  String get modelsTitle => _p('Forecast models compared', 'Comparaison des modèles de prévision');
  String get modelsIntro => _p(
        'The forecast above blends several computer weather models. Here is what three national '
            'weather services predict on their own. Where they agree, the forecast is more certain.',
        'Les prévisions ci-dessus combinent plusieurs modèles météo informatiques. Voici ce que '
            'prévoient trois services météorologiques nationaux, chacun de son côté. Quand ils '
            "s'entendent, la prévision est plus sûre.",
      );
  String modelsFailed(String error) => _p(
        "Couldn't load the model forecasts. $error",
        'Impossible de charger les prévisions des modèles. $error',
      );
  String modelsAgreeWeek(bool allThree, int spread) => _p(
        '${allThree ? 'All three models' : 'The models'} agree closely this week: '
            'their daily highs are never more than $spread° apart.',
        "${allThree ? 'Les trois modèles' : 'Les modèles'} s'entendent bien cette semaine : "
            'leurs maximums quotidiens ne diffèrent jamais de plus de $spread°.',
      );
  String get modelsAgreeToday => _p('They agree closely today. ', "Ils s'entendent bien aujourd'hui. ");
  String modelsTodaySpread(int spread) => _p(
        'Today their highs are $spread° apart. ',
        "Aujourd'hui, leurs maximums diffèrent de $spread°. ",
      );

  /// [day] is null for today.
  String modelsDisagree(DateTime? day, int spread) => _p(
        'They disagree most ${day == null ? 'today' : 'on ${weekday(day)}'}, when their highs differ by '
            '$spread°, so treat that forecast with some caution.',
        "Ils divergent le plus ${day == null ? "aujourd'hui" : weekday(day)}, avec des maximums qui "
            'diffèrent de $spread°; prenez cette prévision avec prudence.',
      );
  String get highAndLow => _p('High and low', 'Max. et min.');
  String get canada => 'Canada';
  String get unitedStates => _p('United States', 'États-Unis');
  String get europe => 'Europe';
  String get gemSource => _p('Environment Canada, GEM model', 'Environnement Canada, modèle GEM');
  String get gfsSource => _p('NOAA, GFS model', 'NOAA, modèle GFS');
  String get ecmwfSource => _p('ECMWF, IFS model', 'CEPMMT, modèle IFS');

  // ---- Radar -------------------------------------------------------------

  String get radar => 'Radar';
  String latestFrame(String time) => _p('Latest, $time', 'Plus récente, $time');
  String get stop => _p('Stop', 'Arrêter');
  String get playRadar => _p('Play the last two hours', 'Animer les deux dernières heures');
  String radarFailed(String error) =>
      _p("Couldn't load the radar pictures. $error", 'Impossible de charger les images radar. $error');
  String get radarHelp => _p(
        'Coloured areas show rain and snow; deeper colours mean heavier precipitation. '
            'Drag to move the map, double-click to zoom in.',
        'Les zones colorées montrent la pluie et la neige; plus la couleur est foncée, plus les '
            'précipitations sont fortes. Faites glisser pour déplacer la carte et double-cliquez pour zoomer.',
      );
  String get mapContributors => _p('OpenStreetMap contributors', "Contributeurs d'OpenStreetMap");

  // ---- Credits -------------------------------------------------------------

  String get creditsWeather => _p('Weather data by ', 'Données météo : ');
  String get creditsPlaces => _p('. Place search by ', '. Recherche de lieux : ');
  String get creditsAir => _p('. Air quality from the ', ". Qualité de l'air : ");
  String get creditsAirName =>
      _p('Copernicus Atmosphere Monitoring Service', "Service de surveillance de l'atmosphère de Copernicus");
  String get creditsPast => _p('. Past weather from ', '. Données historiques : ');
  String get creditsPastName =>
      _p('ERA5, Copernicus Climate Change Service', 'ERA5, Service concernant le changement climatique de Copernicus');
  String get creditsAlerts => _p('. Alerts from ', '. Alertes : ');
  String get creditsAlertsName =>
      _p('Environment and Climate Change Canada', 'Environnement et Changement climatique Canada');
  String get creditsAurora => _p('. Aurora forecast from ', ". Prévisions d'aurores : ");
  String get creditsAuroraName =>
      _p('NOAA Space Weather Prediction Center', 'Space Weather Prediction Center de la NOAA');
  String get creditsRadar => _p('. Radar from ', '. Radar : ');
  String get creditsMaps => _p(', maps from ', ', cartes : ');

  // ---- Search ------------------------------------------------------------

  String get findACity => _p('Find a city', 'Trouver une ville');
  String get searchHint =>
      _p('City or town, like North Bay or Paris, France', 'Ville ou village, p. ex. Rouyn-Noranda ou Paris, France');
  String get search => _p('Search', 'Rechercher');
  String get findingYou => _p('Finding you…', 'Recherche de votre position…');
  String get useMyLocation => _p('Use my location', 'Utiliser ma position');
  String get searchEmpty => _p(
        'Type a city or town, then press Enter.\nAdd a province or country after a comma to narrow it down.',
        "Tapez le nom d'une ville ou d'un village, puis appuyez sur Entrée.\n"
            'Ajoutez une province ou un pays après une virgule pour préciser.',
      );
  String searchFailed(String error) => _p('Search failed. $error', 'La recherche a échoué. $error');
  String get noPlaces => _p(
        'No places match that name. Check the spelling, or try a larger town nearby.',
        "Aucun endroit ne correspond à ce nom. Vérifiez l'orthographe ou essayez une ville plus grande à proximité.",
      );
  String get myLocation => _p('My location', 'Ma position');
  String get locationOff => _p(
        'Location is turned off. On Windows, turn it on in Settings, Privacy & security, Location, '
            'including "Let desktop apps access your location".',
        'La localisation est désactivée. Sous Windows, activez-la dans Paramètres, Confidentialité et '
            'sécurité, Emplacement, y compris « Autoriser les applications de bureau à accéder à votre emplacement ».',
      );
  String get locationDenied => _p(
        "Weather Dash isn't allowed to use your location. You can allow it in your system or browser settings.",
        "Weather Dash n'a pas la permission d'utiliser votre position. Vous pouvez l'autoriser dans "
            'les paramètres de votre système ou de votre navigateur.',
      );

  // ---- Sharing and messages ------------------------------------------------

  String get copied =>
      _p('Copied. Paste it into a chat or document.', 'Image copiée. Collez-la dans une conversation ou un document.');
  String get copyFailed => _p("Couldn't copy the picture.", "Impossible de copier l'image.");
  String get saved => _p('Picture saved.', 'Image enregistrée.');
  String get saveFailed => _p("Couldn't save the picture.", "Impossible d'enregistrer l'image.");
  String imageName(String place) => _p('Weather $place.png', 'Météo $place.png');
  String get pngImage => _p('PNG image', 'Image PNG');
  String get backToFull =>
      _p('Back to the full window (Ctrl+M)', 'Revenir à la fenêtre complète (Ctrl+M)');

  // ---- Settings ------------------------------------------------------------

  String get clock => _p('Clock', 'Horloge');
  String get clock24 => _p('24-hour (13:00)', '24 heures (13 h)');
  String get clock12 => _p('12-hour (1 pm)', '12 heures (1 h p.m.)');
  String get windSpeed => _p('Wind speed', 'Vitesse du vent');
  String get appearance => _p('Appearance', 'Apparence');
  String get matchSystem => _p('Match system', 'Comme le système');
  String get light => _p('Light', 'Clair');
  String get dark => _p('Dark', 'Sombre');
  String get language => _p('Language', 'Langue');
  String get onOpen => _p('When Weather Dash opens', "À l'ouverture de Weather Dash");
  String get startHere => _p('Show the weather where I am', 'Afficher la météo là où je suis');
  String get startHereHelp => _p(
        'Uses your location. When this is off, Weather Dash opens on the last place you looked at.',
        "Utilise votre position. Si l'option est désactivée, Weather Dash s'ouvre sur le dernier endroit consulté.",
      );
  String get tempUnitsNote => _p(
        'Temperature units are switched with the °C / °F button on the main screen.',
        "Les unités de température se changent avec le bouton °C / °F de l'écran principal.",
      );
  String get powerSaving => _p('Power saving', "Économie d'énergie");
  String get powerSaver => _p('Power saver', "Mode économie d'énergie");
  String get powerSaverHelp => _p(
        'Stops the sky animation and refreshes every hour instead of every 15 minutes. Useful on battery.',
        "Arrête l'animation du ciel et actualise toutes les heures plutôt qu'aux 15 minutes. Pratique sur batterie.",
      );
  String get pauseInBackground =>
      _p('Pause the animation when Weather Dash is in the background', "Mettre l'animation en pause quand Weather Dash est en arrière-plan");
  String get pauseInBackgroundHelp => _p(
        'Saves power while you work in other windows. The sky starts moving again when you come back.',
        "Économise l'énergie pendant que vous travaillez dans d'autres fenêtres. Le ciel s'anime de nouveau à votre retour.",
      );

  String windUnitLabel(String key) => switch (key) {
        'kmh' => 'km/h',
        'ms' => 'm/s',
        'mph' => _p('mph', 'mi/h'),
        'kn' => _p('knots', 'nœuds'),
        _ => key,
      };

  // ---- Weather words -------------------------------------------------------

  String describeWeather(int code) => switch (code) {
        0 => _p('Clear sky', 'Ciel dégagé'),
        1 => _p('Mainly clear', 'Généralement dégagé'),
        2 => _p('Partly cloudy', 'Partiellement nuageux'),
        3 => _p('Overcast', 'Couvert'),
        45 => _p('Fog', 'Brouillard'),
        48 => _p('Freezing fog', 'Brouillard givrant'),
        51 => _p('Light drizzle', 'Faible bruine'),
        53 => _p('Moderate drizzle', 'Bruine modérée'),
        55 => _p('Dense drizzle', 'Forte bruine'),
        56 => _p('Light freezing drizzle', 'Faible bruine verglaçante'),
        57 => _p('Dense freezing drizzle', 'Forte bruine verglaçante'),
        61 => _p('Light rain', 'Faible pluie'),
        63 => _p('Moderate rain', 'Pluie modérée'),
        65 => _p('Heavy rain', 'Forte pluie'),
        66 => _p('Light freezing rain', 'Faible pluie verglaçante'),
        67 => _p('Heavy freezing rain', 'Forte pluie verglaçante'),
        71 => _p('Light snow', 'Faible neige'),
        73 => _p('Moderate snow', 'Neige modérée'),
        75 => _p('Heavy snow', 'Forte neige'),
        77 => _p('Snow grains', 'Neige en grains'),
        80 => _p('Light rain showers', 'Faibles averses de pluie'),
        81 => _p('Moderate rain showers', 'Averses de pluie modérées'),
        82 => _p('Violent rain showers', 'Violentes averses de pluie'),
        85 => _p('Light snow showers', 'Faibles averses de neige'),
        86 => _p('Heavy snow showers', 'Fortes averses de neige'),
        95 => _p('Thunderstorm', 'Orage'),
        96 => _p('Thunderstorm with light hail', 'Orage avec faible grêle'),
        97 => _p('Heavy thunderstorm', 'Fort orage'),
        99 => _p('Thunderstorm with heavy hail', 'Orage avec forte grêle'),
        _ => _p('Unknown', 'Inconnu'),
      };

  /// Compass point letters, in order from north (French uses O for ouest).
  List<String> get compassPoints =>
      fr ? const ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'] : const ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  List<String> get compassNames => fr
      ? const ['nord', 'nord-est', 'est', 'sud-est', 'sud', 'sud-ouest', 'ouest', 'nord-ouest']
      : const ['north', 'northeast', 'east', 'southeast', 'south', 'southwest', 'west', 'northwest'];

  String uvLevel(double uv) {
    if (uv < 3) return _p('Low', 'Faible');
    if (uv < 6) return _p('Moderate', 'Modéré');
    if (uv < 8) return _p('High', 'Élevé');
    if (uv < 11) return _p('Very high', 'Très élevé');
    return _p('Extreme', 'Extrême');
  }

  String aqiLevel(int aqi) {
    if (aqi <= 50) return _p('Good', 'Bon');
    if (aqi <= 100) return _p('Moderate', 'Modéré');
    if (aqi <= 150) return _p('Unhealthy for sensitive groups', 'Mauvais pour les groupes sensibles');
    if (aqi <= 200) return _p('Unhealthy', 'Mauvais');
    if (aqi <= 300) return _p('Very unhealthy', 'Très mauvais');
    return _p('Hazardous', 'Dangereux');
  }

  /// Moon phase names, in order from new moon.
  List<String> get moonPhases => fr
      ? const [
          'Nouvelle lune', 'Premier croissant', 'Premier quartier', 'Gibbeuse croissante',
          'Pleine lune', 'Gibbeuse décroissante', 'Dernier quartier', 'Dernier croissant',
        ]
      : const [
          'New moon', 'Waxing crescent', 'First quarter', 'Waxing gibbous',
          'Full moon', 'Waning gibbous', 'Last quarter', 'Waning crescent',
        ];
}

/// The shared instance: `t.next24Hours`, `t.feelsLike('−3°')` and so on.
const t = Strings();

const _weekdaysShortEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdaysShortFr = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _weekdaysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _weekdaysFr = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _monthsFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
