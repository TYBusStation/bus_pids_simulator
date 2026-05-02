import 'package:bus_pids_simulator/data/bus_route.dart';

class Status {
  static final unknown = Status(
    route: BusRoute.unknown,
    direction: Direction.go,
    dutyStatus: DutyStatus.offDuty,
  );

  final BusRoute route;
  final Direction direction;
  final DutyStatus dutyStatus;

  const Status({
    required this.route,
    required this.direction,
    required this.dutyStatus,
  });
}

enum DutyStatus { offDuty, onDuty }

enum Direction { go, back }
