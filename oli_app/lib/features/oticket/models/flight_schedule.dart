const _internationalCities = {'LUANDA'};

/// Un vol du programme. Les heures sont en heure locale de chaque ville.
class FlightLeg {
  final String? aircraft;
  final String? number;
  final String departure;
  final String arrival;
  final String departureTime;
  final String arrivalTime;
  final String blockTime;

  const FlightLeg(
    String this.aircraft,
    String this.number,
    this.departure,
    this.arrival,
    this.departureTime,
    this.arrivalTime,
    this.blockTime,
  );

  /// Vol dont la compagnie ne publie ni numéro ni type d'avion.
  const FlightLeg.unnumbered(
    this.departure,
    this.arrival,
    this.departureTime,
    this.arrivalTime,
    this.blockTime,
  )   : aircraft = null,
        number = null;

  bool get isInternational =>
      _internationalCities.contains(departure) || _internationalCities.contains(arrival);
}

/// Programme d'un jour de la semaine.
class FlightDay {
  final String label;
  final String shortLabel;
  final List<FlightLeg> flights;
  final String? note;

  const FlightDay(this.label, this.shortLabel, this.flights, {this.note});
}

/// Programme hebdomadaire d'une compagnie aérienne.
class AirlineSchedule {
  final String name;
  final String logoAsset;
  final String logoLabel;
  final String caption;

  /// Du lundi au dimanche, dans l'ordre de DateTime.weekday.
  final List<FlightDay> days;

  const AirlineSchedule({
    required this.name,
    required this.logoAsset,
    required this.logoLabel,
    required this.caption,
    required this.days,
  });
}
