// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_station.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusStation _$BusStationFromJson(Map<String, dynamic> json) => BusStation(
  order: (json['order'] as num).toInt(),
  name: json['name'] as String,
  nameEn: json['name_en'] as String,
  lat: (json['lat'] as num).toDouble(),
  lon: (json['lon'] as num).toDouble(),
);

Map<String, dynamic> _$BusStationToJson(BusStation instance) =>
    <String, dynamic>{
      'order': instance.order,
      'name': instance.name,
      'name_en': instance.nameEn,
      'lat': instance.lat,
      'lon': instance.lon,
    };
