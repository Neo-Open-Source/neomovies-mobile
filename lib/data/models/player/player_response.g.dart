// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayerResponse _$PlayerResponseFromJson(Map<String, dynamic> json) =>
    PlayerResponse(
      embedUrl: json['embedUrl'] as String?,
      playerType: json['playerType'] as String?,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$PlayerResponseToJson(PlayerResponse instance) =>
    <String, dynamic>{
      'embedUrl': instance.embedUrl,
      'playerType': instance.playerType,
      'error': instance.error,
    };
