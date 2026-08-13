import 'package:bus_pids_simulator/data/route_path.dart';
import 'package:bus_pids_simulator/data/route_stations.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bus_route.g.dart';

@JsonSerializable()
class BusRoute {
  static final unknown = BusRoute(id: "未知");

  @JsonKey(name: "id", defaultValue: "")
  final String id;

  @JsonKey(name: "name", defaultValue: "未知")
  final String name;

  @JsonKey(name: "name_en", defaultValue: "Unknown")
  final String nameEn;

  @JsonKey(name: "description", defaultValue: "未知")
  final String description;

  @JsonKey(name: "description_en", defaultValue: "Unknown")
  final String descriptionEn;

  @JsonKey(name: "departure", defaultValue: "未知")
  final String departure;

  @JsonKey(name: "departure_en", defaultValue: "Unknown")
  final String departureEn;

  @JsonKey(name: "destination", defaultValue: "未知")
  final String destination;

  @JsonKey(name: "destination_en", defaultValue: "Unknown")
  final String destinationEn;

  @JsonKey(name: "path")
  final RoutePath path;

  @JsonKey(name: "stations")
  final RouteStations stations;

  BusRoute({
    this.id = "",
    this.name = "未知",
    this.nameEn = "Unknown",
    this.description = "未知",
    this.descriptionEn = "Unknown",
    this.departure = "未知",
    this.departureEn = "Unknown",
    this.destination = "未知",
    this.destinationEn = "Unknown",
    RoutePath? path,
    RouteStations? stations,
  })
      :
        this.path = path ?? RoutePath(go: "", back: ""),
        this.stations = stations ?? RouteStations(go: [], back: []);

  factory BusRoute.unknownWithId(String id) => BusRoute(id: id);

  factory BusRoute.fromJson(Map<String, dynamic> json) =>
      _$BusRouteFromJson(json);

  Map<String, dynamic> toJson() => _$BusRouteToJson(this);
}