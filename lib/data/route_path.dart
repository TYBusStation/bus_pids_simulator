import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';
import '../utils/static.dart';

part 'route_path.g.dart';

@JsonSerializable()
class RoutePath {
  @JsonKey(name: "go")
  final String go;
  @JsonKey(name: "back")
  final String back;
  @JsonKey(includeFromJson: false, includeToJson: false)
  late final List<LatLng> goPoints;

  @JsonKey(includeFromJson: false, includeToJson: false)
  late final List<LatLng> backPoints;

  RoutePath({required this.go, required this.back}) {
    goPoints = Static.wktPrase(go);
    backPoints = Static.wktPrase(back);
  }

  factory RoutePath.fromJson(Map<String, dynamic> json) =>
      _$RoutePathFromJson(json);

  Map<String, dynamic> toJson() => _$RoutePathToJson(this);
}
