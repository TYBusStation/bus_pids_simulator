// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_route.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusRoute _$BusRouteFromJson(Map<String, dynamic> json) => BusRoute(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  departure: json['departure'] as String,
  destination: json['destination'] as String,
  path: RoutePath.fromJson(json['path'] as Map<String, dynamic>),
  stations: RouteStations.fromJson(json['stations'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BusRouteToJson(BusRoute instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'departure': instance.departure,
  'destination': instance.destination,
  'path': instance.path,
  'stations': instance.stations,
};
