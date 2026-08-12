import 'package:bus_pids_simulator/data/route_path.dart';
import 'package:bus_pids_simulator/data/route_stations.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bus_route.g.dart';

@JsonSerializable()
class BusRoute {
  static final unknown = BusRoute.unknownWithId("未知");

  @JsonKey(name: "id")
  final String id;
  @JsonKey(name: "name")
  final String name;
  @JsonKey(name: "name_en")
  final String nameEn;
  @JsonKey(name: "description")
  final String description;
  @JsonKey(name: "description_en")
  final String descriptionEn;
  @JsonKey(name: "departure")
  final String departure;
  @JsonKey(name: "departure_en")
  final String departureEn;
  @JsonKey(name: "destination")
  final String destination;
  @JsonKey(name: "destination_en")
  final String destinationEn;
  @JsonKey(name: "path")
  final RoutePath path;
  @JsonKey(name: "stations")
  final RouteStations stations;

  BusRoute({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.description,
    required this.descriptionEn,
    required this.departure,
    required this.departureEn,
    required this.destination,
    required this.destinationEn,
    required this.path,
    required this.stations,
  });

  factory BusRoute.unknownWithId(String id) => BusRoute(
    id: id,
    name: '未知',
    nameEn: "Unknown",
    departure: "未知",
    destination: "未知",
    description: "未知",
    descriptionEn: "Unknown",
    departureEn: "Unknown",
    destinationEn: "Unknown",
    path: RoutePath(go: "", back: ""),
    stations: RouteStations(go: [], back: []),
  );

  factory BusRoute.fromJson(Map<String, dynamic> json) =>
      _$BusRouteFromJson(json);

  Map<String, dynamic> toJson() => _$BusRouteToJson(this);
}
