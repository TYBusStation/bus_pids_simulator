import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';

import 'led_sequence.dart';

part 'bus_station.g.dart';

@JsonSerializable()
class BusStation {
  @JsonKey(name: "order")
  final int order;

  @JsonKey(name: "name", defaultValue: "")
  final String name;

  @JsonKey(name: "name_en", defaultValue: "")
  final String nameEn;

  @JsonKey(name: "lat", defaultValue: 0.0)
  final double lat;

  @JsonKey(name: "lon", defaultValue: 0.0)
  final double lon;

  @JsonKey(name: "use_global_next", defaultValue: true)
  final bool useGlobalNext;

  @JsonKey(name: "use_global_arrival", defaultValue: true)
  final bool useGlobalArrival;

  @JsonKey(name: "next_template")
  final List<String>? nextTemplate;

  @JsonKey(name: "arrival_template")
  final List<String>? arrivalTemplate;

  @JsonKey(name: "use_global_next_led", defaultValue: true)
  final bool useGlobalNextLed;

  @JsonKey(name: "use_global_arrival_led", defaultValue: true)
  final bool useGlobalArrivalLed;

  @JsonKey(name: "next_led_template")
  final List<LedSequence>? nextLedTemplate;

  @JsonKey(name: "arrival_led_template")
  final List<LedSequence>? arrivalLedTemplate;

  BusStation({
    required this.order,
    this.name = "",
    this.nameEn = "",
    this.lat = 0.0,
    this.lon = 0.0,
    this.useGlobalNext = true,
    this.useGlobalArrival = true,
    this.nextTemplate,
    this.arrivalTemplate,
    this.useGlobalNextLed = true,
    this.useGlobalArrivalLed = true,
    this.nextLedTemplate,
    this.arrivalLedTemplate,
  });

  BusStation copyWith({
    int? order,
    String? name,
    String? nameEn,
    double? lat,
    double? lon,
    bool? useGlobalNext,
    bool? useGlobalArrival,
    List<String>? nextTemplate,
    List<String>? arrivalTemplate,
    bool? useGlobalNextLed,
    bool? useGlobalArrivalLed,
    List<LedSequence>? nextLedTemplate,
    List<LedSequence>? arrivalLedTemplate,
  }) {
    return BusStation(
      order: order ?? this.order,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      useGlobalNext: useGlobalNext ?? this.useGlobalNext,
      useGlobalArrival: useGlobalArrival ?? this.useGlobalArrival,
      nextTemplate: nextTemplate ?? this.nextTemplate,
      arrivalTemplate: arrivalTemplate ?? this.arrivalTemplate,
      useGlobalNextLed: useGlobalNextLed ?? this.useGlobalNextLed,
      useGlobalArrivalLed: useGlobalArrivalLed ?? this.useGlobalArrivalLed,
      nextLedTemplate: nextLedTemplate ?? this.nextLedTemplate,
      arrivalLedTemplate: arrivalLedTemplate ?? this.arrivalLedTemplate,
    );
  }

  LatLng get position => LatLng(lat, lon);

  factory BusStation.fromJson(Map<String, dynamic> json) =>
      _$BusStationFromJson(json);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'order': order,
      'name': name,
      'name_en': nameEn,
      'lat': lat,
      'lon': lon,
    };
    if (useGlobalNext == false) data['use_global_next'] = false;
    if (useGlobalArrival == false) data['use_global_arrival'] = false;
    if (nextTemplate != null && nextTemplate!.isNotEmpty) {
      data['next_template'] = nextTemplate;
    }
    if (arrivalTemplate != null && arrivalTemplate!.isNotEmpty) {
      data['arrival_template'] = arrivalTemplate;
    }
    if (useGlobalNextLed == false) data['use_global_next_led'] = false;
    if (useGlobalArrivalLed == false) data['use_global_arrival_led'] = false;
    if (nextLedTemplate != null && nextLedTemplate!.isNotEmpty) {
      data['next_led_template'] = nextLedTemplate!
          .map((e) => e.toJson())
          .toList();
    }
    if (arrivalLedTemplate != null && arrivalLedTemplate!.isNotEmpty) {
      data['arrival_led_template'] = arrivalLedTemplate!
          .map((e) => e.toJson())
          .toList();
    }
    return data;
  }
}
