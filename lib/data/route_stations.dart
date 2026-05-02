import 'package:bus_pids_simulator/data/bus_station.dart';
import 'package:json_annotation/json_annotation.dart';

part 'route_stations.g.dart';

@JsonSerializable()
class RouteStations {
  @JsonKey(name: "go")
  final List<BusStation> go;
  @JsonKey(name: "back")
  final List<BusStation> back;

  RouteStations({required this.go, required this.back});

  factory RouteStations.fromJson(Map<String, dynamic> json) =>
      _$RouteStationsFromJson(json);

  Map<String, dynamic> toJson() => _$RouteStationsToJson(this);
}
