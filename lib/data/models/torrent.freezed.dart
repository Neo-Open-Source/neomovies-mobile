// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'torrent.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Torrent _$TorrentFromJson(Map<String, dynamic> json) {
  return _Torrent.fromJson(json);
}

/// @nodoc
mixin _$Torrent {
  String get magnet => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get quality => throw _privateConstructorUsedError;
  int? get seeders => throw _privateConstructorUsedError;
  int? get size => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TorrentCopyWith<Torrent> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TorrentCopyWith<$Res> {
  factory $TorrentCopyWith(Torrent value, $Res Function(Torrent) then) =
      _$TorrentCopyWithImpl<$Res, Torrent>;
  @useResult
  $Res call(
      {String magnet,
      String? title,
      String? name,
      String? quality,
      int? seeders,
      int? size});
}

/// @nodoc
class _$TorrentCopyWithImpl<$Res, $Val extends Torrent>
    implements $TorrentCopyWith<$Res> {
  _$TorrentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? magnet = null,
    Object? title = freezed,
    Object? name = freezed,
    Object? quality = freezed,
    Object? seeders = freezed,
    Object? size = freezed,
  }) {
    return _then(_value.copyWith(
      magnet: null == magnet
          ? _value.magnet
          : magnet // ignore: cast_nullable_to_non_nullable
              as String,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      quality: freezed == quality
          ? _value.quality
          : quality // ignore: cast_nullable_to_non_nullable
              as String?,
      seeders: freezed == seeders
          ? _value.seeders
          : seeders // ignore: cast_nullable_to_non_nullable
              as int?,
      size: freezed == size
          ? _value.size
          : size // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TorrentImplCopyWith<$Res> implements $TorrentCopyWith<$Res> {
  factory _$$TorrentImplCopyWith(
          _$TorrentImpl value, $Res Function(_$TorrentImpl) then) =
      __$$TorrentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String magnet,
      String? title,
      String? name,
      String? quality,
      int? seeders,
      int? size});
}

/// @nodoc
class __$$TorrentImplCopyWithImpl<$Res>
    extends _$TorrentCopyWithImpl<$Res, _$TorrentImpl>
    implements _$$TorrentImplCopyWith<$Res> {
  __$$TorrentImplCopyWithImpl(
      _$TorrentImpl _value, $Res Function(_$TorrentImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? magnet = null,
    Object? title = freezed,
    Object? name = freezed,
    Object? quality = freezed,
    Object? seeders = freezed,
    Object? size = freezed,
  }) {
    return _then(_$TorrentImpl(
      magnet: null == magnet
          ? _value.magnet
          : magnet // ignore: cast_nullable_to_non_nullable
              as String,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      quality: freezed == quality
          ? _value.quality
          : quality // ignore: cast_nullable_to_non_nullable
              as String?,
      seeders: freezed == seeders
          ? _value.seeders
          : seeders // ignore: cast_nullable_to_non_nullable
              as int?,
      size: freezed == size
          ? _value.size
          : size // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TorrentImpl implements _Torrent {
  const _$TorrentImpl(
      {required this.magnet,
      this.title,
      this.name,
      this.quality,
      this.seeders,
      this.size});

  factory _$TorrentImpl.fromJson(Map<String, dynamic> json) =>
      _$$TorrentImplFromJson(json);

  @override
  final String magnet;
  @override
  final String? title;
  @override
  final String? name;
  @override
  final String? quality;
  @override
  final int? seeders;
  @override
  final int? size;

  @override
  String toString() {
    return 'Torrent(magnet: $magnet, title: $title, name: $name, quality: $quality, seeders: $seeders, size: $size)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TorrentImpl &&
            (identical(other.magnet, magnet) || other.magnet == magnet) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.quality, quality) || other.quality == quality) &&
            (identical(other.seeders, seeders) || other.seeders == seeders) &&
            (identical(other.size, size) || other.size == size));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, magnet, title, name, quality, seeders, size);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TorrentImplCopyWith<_$TorrentImpl> get copyWith =>
      __$$TorrentImplCopyWithImpl<_$TorrentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TorrentImplToJson(
      this,
    );
  }
}

abstract class _Torrent implements Torrent {
  const factory _Torrent(
      {required final String magnet,
      final String? title,
      final String? name,
      final String? quality,
      final int? seeders,
      final int? size}) = _$TorrentImpl;

  factory _Torrent.fromJson(Map<String, dynamic> json) = _$TorrentImpl.fromJson;

  @override
  String get magnet;
  @override
  String? get title;
  @override
  String? get name;
  @override
  String? get quality;
  @override
  int? get seeders;
  @override
  int? get size;
  @override
  @JsonKey(ignore: true)
  _$$TorrentImplCopyWith<_$TorrentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
