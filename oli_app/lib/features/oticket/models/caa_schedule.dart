/// Programme des vols de la Compagnie Africaine d'Aviation (CAA).
/// Transcription du programme publié par la compagnie le 11/11/2026.
import 'flight_schedule.dart';

const caaScheduleDate = '11/11/2026';

const _kin = 'KINSHASA';
const _fbm = 'LUBUMBASHI';
const _kwz = 'KOLWEZI';
const _fki = 'KISANGANI';
const _mjm = 'MBUJI-MAYI';
const _mdk = 'MBANDAKA';
const _knn = 'KANANGA';
const _knd = 'KINDU';
const _fmi = 'KALEMIE';
const _lad = 'LUANDA';

const _a330 = 'A330';
const _a320 = 'A320';
const _abm = 'A320 9S-ABM';

/// Du lundi au dimanche, dans l'ordre de DateTime.weekday.
const caaSchedule = <FlightDay>[
  FlightDay('Lundi', 'Lun', note: 'A330 : aucun vol ce jour', [
    FlightLeg(_a320, '1633', _fbm, _kwz, '08:00', '08:45', '00:45'),
    FlightLeg(_a320, '1633', _kwz, _kin, '09:30', '10:30', '02:00'),
    FlightLeg(_a320, '1634', _kin, _kwz, '11:45', '14:45', '02:00'),
    FlightLeg(_a320, '1634', _kwz, _fbm, '15:30', '16:15', '00:45'),
    FlightLeg(_abm, '1641', _kin, _fki, '08:00', '11:00', '02:00'),
    FlightLeg(_abm, '1642', _fki, _kin, '11:45', '12:45', '02:00'),
    FlightLeg(_a320, '1414', _kin, _mjm, '09:00', '11:40', '01:40'),
    FlightLeg(_a320, '1414', _mjm, _fbm, '12:25', '13:45', '01:20'),
    FlightLeg(_a320, '1413', _fbm, _mjm, '14:30', '15:50', '01:20'),
    FlightLeg(_a320, '1413', _mjm, _kin, '16:35', '17:15', '01:40'),
  ]),
  FlightDay('Mardi', 'Mar', [
    FlightLeg(_a330, '1612', _fbm, _kin, '10:00', '11:30', '02:30'),
    FlightLeg(_a330, '1611', _kin, _fbm, '13:45', '17:15', '02:30'),
    FlightLeg(_abm, '1433', _kin, _mjm, '09:00', '11:40', '01:40'),
    FlightLeg(_abm, '1433', _mjm, _kwz, '12:25', '13:40', '01:15'),
    FlightLeg(_abm, '1433', _kwz, _fbm, '14:25', '15:10', '00:45'),
    FlightLeg(_a320, '1161', _kin, _mdk, '08:00', '09:15', '01:15'),
    FlightLeg(_a320, '1162', _mdk, _kin, '10:00', '11:15', '01:15'),
    FlightLeg(_a320, '1641', _kin, _fki, '13:00', '16:00', '02:00'),
    FlightLeg(_a320, '1642', _fki, _kin, '16:45', '17:45', '02:00'),
    FlightLeg(_a320, '1434', _fbm, _kwz, '08:00', '08:45', '00:45'),
    FlightLeg(_a320, '1434', _kwz, _mjm, '09:30', '10:45', '01:15'),
    FlightLeg(_a320, '1434', _mjm, _kin, '11:30', '12:10', '01:40'),
  ]),
  FlightDay('Mercredi', 'Mer', [
    FlightLeg(_a330, '1612', _fbm, _kin, '10:00', '11:30', '02:30'),
    FlightLeg(_a330, '1611', _kin, _fbm, '13:45', '17:15', '02:30'),
    FlightLeg(_a320, '1634', _kin, _kwz, '09:00', '12:00', '02:00'),
    FlightLeg(_a320, '1634', _kwz, _fbm, '12:45', '13:30', '00:45'),
    FlightLeg(_a320, '1633', _fbm, _kwz, '14:15', '15:00', '00:45'),
    FlightLeg(_a320, '1633', _kwz, _kin, '15:45', '16:45', '02:00'),
    FlightLeg(_a320, '1424', _kin, _knn, '08:00', '10:25', '01:25'),
    FlightLeg(_a320, '1423', _knn, _kin, '11:10', '11:35', '01:25'),
    FlightLeg(_a320, '1257', _kin, _knd, '12:30', '15:30', '02:00'),
    FlightLeg(_a320, '1647', _knd, _fmi, '16:15', '17:45', '01:30'),
    FlightLeg(_a320, '1638', _fmi, _fbm, '18:30', '20:00', '01:30'),
  ]),
  FlightDay('Jeudi', 'Jeu', [
    FlightLeg(_a330, '1612', _fbm, _kin, '10:00', '11:30', '02:30'),
    FlightLeg(_a330, '1611', _kin, _fbm, '13:45', '17:15', '02:30'),
    FlightLeg(_a320, '1434', _fbm, _kwz, '08:00', '08:45', '00:45'),
    FlightLeg(_a320, '1434', _kwz, _mjm, '09:30', '10:45', '01:15'),
    FlightLeg(_a320, '1434', _mjm, _kin, '11:30', '12:10', '01:40'),
    FlightLeg(_a320, '1256', _kin, _knd, '13:00', '16:00', '02:00'),
    FlightLeg(_a320, '1256', _knd, _fki, '16:45', '17:45', '01:00'),
    FlightLeg(_a320, '1256', _fki, _kin, '18:30', '19:30', '02:00'),
    FlightLeg(_a320, '1161', _kin, _mdk, '08:00', '09:15', '01:15'),
    FlightLeg(_a320, '1162', _mdk, _kin, '10:00', '11:15', '01:15'),
    FlightLeg(_a320, '1433', _kin, _mjm, '12:00', '14:40', '01:40'),
    FlightLeg(_a320, '1433', _mjm, _kwz, '15:25', '16:40', '01:15'),
    FlightLeg(_a320, '1433', _kwz, _fbm, '17:25', '18:10', '00:45'),
    FlightLeg(_a320, '1631', _fbm, _fmi, '09:00', '10:30', '01:30'),
    FlightLeg(_a320, '1648', _fmi, _knd, '11:15', '12:45', '01:30'),
    FlightLeg(_a320, '1258', _knd, _kin, '13:30', '14:30', '02:00'),
    FlightLeg(_a320, '0021', _kin, _lad, '19:00', '20:30', '01:30'),
    FlightLeg(_a320, '0022', _lad, _kin, '21:30', '23:00', '01:30'),
  ]),
  FlightDay('Vendredi', 'Ven', [
    FlightLeg(_a330, '1612', _fbm, _kin, '10:00', '11:30', '02:30'),
    FlightLeg(_a330, '1611', _kin, _fbm, '13:45', '17:15', '02:30'),
    FlightLeg(_a320, '1633', _fbm, _kwz, '08:00', '08:45', '00:45'),
    FlightLeg(_a320, '1633', _kwz, _kin, '09:30', '10:30', '02:00'),
    FlightLeg(_a320, '1634', _kin, _kwz, '11:15', '14:15', '02:00'),
    FlightLeg(_a320, '1634', _kwz, _fbm, '15:00', '15:45', '00:45'),
    FlightLeg(_a320, '1641', _kin, _fki, '08:00', '11:00', '02:00'),
    FlightLeg(_a320, '1642', _fki, _kin, '11:45', '12:45', '02:00'),
    FlightLeg(_a320, '1257', _kin, _knd, '09:00', '12:00', '02:00'),
    FlightLeg(_a320, '1647', _knd, _fmi, '12:45', '14:15', '01:30'),
    FlightLeg(_a320, '1638', _fmi, _fbm, '15:00', '16:30', '01:30'),
  ]),
  FlightDay('Samedi', 'Sam', [
    FlightLeg(_a330, '1612', _fbm, _kin, '10:00', '11:30', '02:30'),
    FlightLeg(_a330, '1611', _kin, _fbm, '13:45', '17:15', '02:30'),
    FlightLeg(_a320, '1161', _kin, _mdk, '08:00', '09:15', '01:15'),
    FlightLeg(_a320, '1162', _mdk, _kin, '10:00', '11:15', '01:15'),
    FlightLeg(_a320, '1641', _kin, _fki, '12:00', '15:00', '02:00'),
    FlightLeg(_a320, '1642', _fki, _kin, '15:45', '16:45', '02:00'),
    FlightLeg(_a320, '1414', _fbm, _mjm, '08:00', '09:20', '01:20'),
    FlightLeg(_a320, '1414', _mjm, _kin, '10:05', '10:45', '01:40'),
    FlightLeg(_a320, '1413', _kin, _mjm, '11:30', '14:10', '01:40'),
    FlightLeg(_a320, '1413', _mjm, _fbm, '15:00', '16:20', '01:20'),
    FlightLeg(_a320, '1631', _fbm, _fmi, '09:00', '10:30', '01:30'),
    FlightLeg(_a320, '1648', _fmi, _knd, '11:15', '12:45', '01:30'),
    FlightLeg(_a320, '1258', _knd, _kin, '13:30', '14:30', '02:00'),
  ]),
  FlightDay('Dimanche', 'Dim', [
    FlightLeg(_a330, '1612', _fbm, _kin, '08:00', '09:30', '02:30'),
    FlightLeg(_a330, '1611', _kin, _fbm, '10:55', '14:25', '02:30'),
    FlightLeg(_a330, '1614', _fbm, _kin, '15:45', '17:15', '02:30'),
    FlightLeg(_a330, '1613', _kin, _fbm, '18:30', '22:00', '02:30'),
    FlightLeg(_a320, '1256', _kin, _fki, '08:00', '11:00', '02:00'),
    FlightLeg(_a320, '1256', _fki, _knd, '11:45', '12:45', '01:00'),
    FlightLeg(_a320, '1256', _knd, _kin, '13:30', '14:30', '02:00'),
    FlightLeg(_a320, '1424', _kin, _knn, '15:15', '17:40', '01:25'),
    FlightLeg(_a320, '1423', _knn, _kin, '18:25', '18:50', '01:25'),
    FlightLeg(_a320, '1257', _kin, _knd, '09:00', '12:00', '02:00'),
    FlightLeg(_a320, '1647', _knd, _fmi, '12:45', '14:15', '01:30'),
    FlightLeg(_a320, '1638', _fmi, _fbm, '15:00', '16:30', '01:30'),
    FlightLeg(_a320, '1631', _fbm, _fmi, '10:15', '11:45', '01:30'),
    FlightLeg(_a320, '1648', _fmi, _knd, '12:30', '14:00', '01:30'),
    FlightLeg(_a320, '1258', _knd, _kin, '14:45', '15:45', '02:00'),
    FlightLeg(_a320, '0021', _kin, _lad, '19:00', '20:30', '01:30'),
    FlightLeg(_a320, '0022', _lad, _kin, '21:30', '23:00', '01:30'),
  ]),
];

const caaAirlineSchedule = AirlineSchedule(
  name: 'CAA',
  logoAsset: 'assets/images/logo_caa.png',
  logoLabel: "Compagnie Africaine d'Aviation",
  caption: 'Programme du $caaScheduleDate',
  days: caaSchedule,
);
