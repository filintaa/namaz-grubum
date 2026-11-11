import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models.dart';
import 'telemetry_service.dart';

class InviteService {
  InviteService._();

  static final instance = InviteService._();
  static const _inviteOrigin = 'https://namaz-grubum.web.app';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  void Function(String groupId)? _onGroup;
  String? _pendingGroupId;

  void setPendingGroupId(String groupId) {
    _pendingGroupId = groupId;
  }

  String? takePendingGroupId() {
    final value = _pendingGroupId;
    _pendingGroupId = null;
    return value;
  }

  Future<void> initialize() async {
    final initial = await _appLinks.getInitialLink();
    _accept(initial);
    await _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen(_accept);
  }

  void startNavigation(void Function(String groupId) onGroup) {
    _onGroup = onGroup;
    final pending = _pendingGroupId;
    _pendingGroupId = null;
    if (pending != null) onGroup(pending);
    if (pending != null) {
      TelemetryService.instance.track(
        'invite_opened',
        parameters: {'group_id': pending},
      );
    }
  }

  Future<void> shareGroup(GroupSummary group, {Rect? origin}) async {
    final url = '$_inviteOrigin/g/${Uri.encodeComponent(group.id)}';
    await SharePlus.instance.share(
      ShareParams(
        subject: '${group.name} · Namaz Grubum',
        text: '${group.name} grubuna katıl: $url',
        sharePositionOrigin: origin,
      ),
    );
    await TelemetryService.instance.track(
      'invite_shared',
      parameters: {'group_id': group.id},
    );
  }

  void _accept(Uri? uri) {
    final groupId = groupIdFromUri(uri);
    if (groupId == null) return;
    final handler = _onGroup;
    if (handler == null) {
      _pendingGroupId = groupId;
    } else {
      handler(groupId);
    }
    TelemetryService.instance.track(
      'invite_opened',
      parameters: {'group_id': groupId},
    );
  }

  static String? groupIdFromUri(Uri? uri) {
    if (uri == null) return null;
    final isWebInvite =
        uri.scheme == 'https' &&
        (uri.host == 'namaz-grubum.web.app' ||
            uri.host == 'join.namazgrubum.app') &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'g';
    final isAppInvite =
        uri.scheme == 'namazgrubum' &&
        uri.host == 'g' &&
        uri.pathSegments.isNotEmpty;
    if (!isWebInvite && !isAppInvite) return null;
    final value = isWebInvite ? uri.pathSegments[1] : uri.pathSegments.first;
    return RegExp(r'^[A-Za-z0-9_-]{3,128}$').hasMatch(value) ? value : null;
  }
}
