import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';

part 'bus_station.g.dart';

@JsonSerializable()
class BusStation {
  @JsonKey(name: "order")
  final int order;
  @JsonKey(name: "name")
  final String name;
  @JsonKey(name: "name_en")
  final String nameEn;
  @JsonKey(name: "lat")
  final double lat;
  @JsonKey(name: "lon")
  final double lon;
  @JsonKey(name: "use_global_next", defaultValue: true)
  final bool useGlobalNext;
  @JsonKey(name: "use_global_arrival", defaultValue: true)
  final bool useGlobalArrival;
  @JsonKey(name: "next_template")
  final List<String>? nextTemplate;
  @JsonKey(name: "arrival_template")
  final List<String>? arrivalTemplate;

  BusStation({
    required this.order,
    required this.name,
    required this.nameEn,
    required this.lat,
    required this.lon,
    this.useGlobalNext = true,
    this.useGlobalArrival = true,
    this.nextTemplate,
    this.arrivalTemplate,
  });

  LatLng get position => LatLng(lat, lon);

  factory BusStation.fromJson(Map<String, dynamic> json) =>
      _$BusStationFromJson(json);

  Map<String, dynamic> toJson() => _$BusStationToJson(this);
}
