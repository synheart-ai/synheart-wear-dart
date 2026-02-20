//
// Local implementation of google.protobuf.Timestamp for protobuf 2.x compatibility.
// Wire-format compatible with server (seconds + nanos).
//
// @dart = 2.12

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

/// google.protobuf.Timestamp: seconds since Unix epoch + nanos.
class Timestamp extends $pb.GeneratedMessage {
  factory Timestamp() => create();
  Timestamp._() : super();
  factory Timestamp.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Timestamp.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    _omitMessageNames ? '' : 'Timestamp',
    package: const $pb.PackageName(_omitMessageNames ? '' : 'google.protobuf'),
    createEmptyInstance: create,
  )
    ..aInt64(1, _omitFieldNames ? '' : 'seconds')
    ..aInt64(2, _omitFieldNames ? '' : 'nanos') // wire-compatible with int32 (varint)
    ..hasRequiredFields = false;

  @$core.Deprecated('Use [GeneratedMessageGenericExtensions.deepCopy] instead.')
  Timestamp clone() => Timestamp()..mergeFromMessage(this);
  @$core.Deprecated('Use [GeneratedMessageGenericExtensions.rebuild] instead.')
  Timestamp copyWith(void Function(Timestamp) updates) =>
      super.copyWith((message) => updates(message as Timestamp)) as Timestamp;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Timestamp create() => Timestamp._();
  Timestamp createEmptyInstance() => create();
  static $pb.PbList<Timestamp> createRepeated() => $pb.PbList<Timestamp>();
  @$core.pragma('dart2js:noInline')
  static Timestamp getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Timestamp>(create);
  static Timestamp? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seconds => $_getI64(0);
  @$pb.TagNumber(1)
  set seconds($fixnum.Int64 v) {
    $_setInt64(0, v);
  }

  @$pb.TagNumber(2)
  $core.int get nanos => $_getI64(1).toInt();
  @$pb.TagNumber(2)
  set nanos($core.int v) {
    $_setInt64(1, $fixnum.Int64(v));
  }

  /// Creates a Timestamp from [dateTime]. Uses UTC.
  static Timestamp fromDateTime($core.DateTime dateTime) {
    final utc = dateTime.toUtc();
    final millis = utc.millisecondsSinceEpoch;
    final sec = (millis / 1000).floor();
    final n = (millis % 1000) * 1000000;
    return Timestamp()
      ..seconds = $fixnum.Int64(sec)
      ..nanos = n;
  }

  /// Converts this Timestamp to DateTime (UTC).
  $core.DateTime toDateTime() {
    final sec = seconds.toInt();
    final n = nanos;
    final millis = sec * 1000 + (n / 1000000).floor();
    return $core.DateTime.utc(1970, 1, 1).add($core.Duration(milliseconds: millis));
  }
}

const $core.bool _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
