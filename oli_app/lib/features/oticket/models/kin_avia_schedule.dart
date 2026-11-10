import 'flight_schedule.dart';

/// Vols réguliers publiés par Kin Avia.
const _kin = 'KINSHASA';
const _bdd = 'BANDUNDU';
const _nio = 'NIOKI';

const _viaNioki = <FlightLeg>[
  FlightLeg.unnumbered(_kin, _bdd, '07:30', '08:30', '01:00'),
  FlightLeg.unnumbered(_bdd, _nio, '09:00', '09:15', '00:15'),
  FlightLeg.unnumbered(_nio, _kin, '09:30', '10:30', '01:00'),
];

const _bandunduOnly = <FlightLeg>[
  FlightLeg.unnumbered(_kin, _bdd, '07:30', '08:30', '01:00'),
  FlightLeg.unnumbered(_bdd, _kin, '08:45', '09:45', '01:00'),
];

const kinAviaSchedule = AirlineSchedule(
  name: 'Kin Avia',
  logoAsset: 'assets/images/logo_kin_avia.png',
  logoLabel: 'Kin Avia',
  caption: 'Destinations et vols réguliers',
  days: [
    FlightDay('Lundi', 'Lun', _viaNioki),
    FlightDay('Mardi', 'Mar', _bandunduOnly),
    FlightDay('Mercredi', 'Mer', _viaNioki),
    FlightDay('Jeudi', 'Jeu', _bandunduOnly),
    FlightDay('Vendredi', 'Ven', _viaNioki),
    FlightDay('Samedi', 'Sam', _bandunduOnly),
    FlightDay('Dimanche', 'Dim', []),
  ],
);
