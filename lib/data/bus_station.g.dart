// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_station.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusStation _$BusStationFromJson(Map<String, dynamic> json) => BusStation(
  order: (json['order'] as num).toInt(),
  name: json['name'] as String? ?? '',
  nameEn: json['name_en'] as String? ?? '',
  lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
  lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
  useGlobalNext: json['use_global_next'] as bool? ?? true,
  useGlobalArrival: json['use_global_arrival'] as bool? ?? true,
  nextTemplate: (json['next_template'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  arrivalTemplate: (json['arrival_template'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  useGlobalNextLed: json['use_global_next_led'] as bool? ?? true,
  useGlobalArrivalLed: json['use_global_arrival_led'] as bool? ?? true,
  nextLedTemplate: (json['next_led_template'] as List<dynamic>?)
      ?.map((e) => LedSequence.fromJson(e as Map<String, dynamic>))
      .toList(),
  arrivalLedTemplate: (json['arrival_led_template'] as List<dynamic>?)
      ?.map((e) => LedSequence.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$BusStationToJson(BusStation instance) =>
    <String, dynamic>{
      'order': instance.order,
      'name': instance.name,
      'name_en': instance.nameEn,
      'lat': instance.lat,
      'lon': instance.lon,
      'use_global_next': instance.useGlobalNext,
      'use_global_arrival': instance.useGlobalArrival,
      'next_template': instance.nextTemplate,
      'arrival_template': instance.arrivalTemplate,
      'use_global_next_led': instance.useGlobalNextLed,
      'use_global_arrival_led': instance.useGlobalArrivalLed,
      'next_led_template': instance.nextLedTemplate,
      'arrival_led_template': instance.arrivalLedTemplate,
    };
