// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_stations.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RouteStations _$RouteStationsFromJson(Map<String, dynamic> json) =>
    RouteStations(
      go: (json['go'] as List<dynamic>)
          .map((e) => BusStation.fromJson(e as Map<String, dynamic>))
          .toList(),
      back: (json['back'] as List<dynamic>)
          .map((e) => BusStation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RouteStationsToJson(RouteStations instance) =>
    <String, dynamic>{'go': instance.go, 'back': instance.back};
