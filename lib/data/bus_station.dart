import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';

part 'bus_station.g.dart';

@JsonSerializable()
class BusStation {
  @JsonKey(name: "order")
  final int order;
  @JsonKey(name: "name")
  final String name;
  @JsonKey(name: "lat")
  final double lat;
  @JsonKey(name: "lon")
  final double lon;

  BusStation({
    required this.order,
    required this.name,
    required this.lat,
    required this.lon,
  });

  LatLng get position => LatLng(lat, lon);

  factory BusStation.fromJson(Map<String, dynamic> json) =>
      _$BusStationFromJson(json);

  Map<String, dynamic> toJson() => _$BusStationToJson(this);
}
