// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_route.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusRoute _$BusRouteFromJson(Map<String, dynamic> json) => BusRoute(
  id: json['id'] as String,
  name: json['name'] as String,
  nameEn: json['name_en'] as String,
  description: json['description'] as String,
  descriptionEn: json['description_en'] as String,
  departure: json['departure'] as String,
  departureEn: json['departure_en'] as String,
  destination: json['destination'] as String,
  destinationEn: json['destination_en'] as String,
  path: RoutePath.fromJson(json['path'] as Map<String, dynamic>),
  stations: RouteStations.fromJson(json['stations'] as Map<String, dynamic>),
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
