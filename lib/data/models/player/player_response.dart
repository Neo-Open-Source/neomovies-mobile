import 'package:json_annotation/json_annotation.dart';

part 'player_response.g.dart';

/// Response from player endpoints
/// Contains embed URL for different player services
@JsonSerializable()
class PlayerResponse {
  final String? embedUrl;
  final String? playerType; // 'alloha', 'lumex', 'vibix'
  final String? error;

  PlayerResponse({
    this.embedUrl,
    this.playerType,
    this.error,
  });

  factory PlayerResponse.fromJson(Map<String, dynamic> json) =>
      _$PlayerResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PlayerResponseToJson(this);
}
