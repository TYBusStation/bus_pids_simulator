// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_route.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusRoute _$BusRouteFromJson(Map<String, dynamic> json) => BusRoute(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '未知',
  nameEn: json['name_en'] as String? ?? 'Unknown',
  description: json['description'] as String? ?? '未知',
  descriptionEn: json['description_en'] as String? ?? 'Unknown',
  departure: json['departure'] as String? ?? '未知',
  departureEn: json['departure_en'] as String? ?? 'Unknown',
  destination: json['destination'] as String? ?? '未知',
  destinationEn: json['destination_en'] as String? ?? 'Unknown',
  path: json['path'] == null
      ? null
      : RoutePath.fromJson(json['path'] as Map<String, dynamic>),
  stations: json['stations'] == null
      ? null
      : RouteStations.fromJson(json['stations'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BusRouteToJson(BusRoute instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'name_en': instance.nameEn,
  'description': instance.description,
  'description_en': instance.descriptionEn,
  'departure': instance.departure,
  'departure_en': instance.departureEn,
  'destination': instance.destination,
  'destination_en': instance.destinationEn,
  'path': instance.path,
  'stations': instance.stations,
};
