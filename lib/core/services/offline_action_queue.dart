import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_coordinator.dart';
import '../domain/models.dart';

class OfflineActionQueue {
  OfflineActionQueue._();

  static final instance = OfflineActionQueue._();
  static const _storageKey = 'offline_callable_actions_v1';
  static const _maxActions = 100;

  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  bool _flushing = false;

  Future<void> enqueueRecordCheckin(Map<String, Object> payload) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final preferences = await SharedPreferences.getInstance();
    final actions = _read(preferences);
    actions.add(<String, Object>{
      'type': 'recordCheckin',
      'userId': userId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    });
    final bounded = actions.length > _maxActions
        ? actions.sublist(actions.length - _maxActions)
        : actions;
    await preferences.setString(_storageKey, jsonEncode(bounded));
  }

  Future<void> flush() async {
    if (_flushing) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    _flushing = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final actions = _read(preferences);
      final remaining = <Map<String, dynamic>>[];
      var networkUnavailable = false;
      for (final action in actions) {
        if (action['userId'] != userId || networkUnavailable) {
          remaining.add(action);
          continue;
        }
        final createdAt = DateTime.tryParse(
          action['createdAt'] as String? ?? '',
        );
        if (createdAt == null ||
            DateTime.now().toUtc().difference(createdAt).inDays >= 7) {
          continue;
        }
        try {
          final payload = Map<String, dynamic>.from(action['payload'] as Map);
          await _functions
              .httpsCallable(action['type'] as String)
              .call(payload);
          if (payload['action'] == 'complete') {
            final prayer = Prayer.values
                .where((item) => item.name == payload['prayer'])
                .firstOrNull;
            if (prayer != null && payload['dateKey'] is String) {
              try {
                await AlarmCoordinator.instance.markPrayerCompleted(
                  prayer: prayer,
                  dateKey: payload['dateKey'] as String,
                );
              } catch (error) {
                debugPrint('Queued prayer alarm cancellation failed: $error');
              }
            }
          }
        } on FirebaseFunctionsException catch (error) {
          if (_isNetworkError(error.code)) {
            networkUnavailable = true;
            remaining.add(action);
          } else {
            debugPrint('Queued action discarded (${error.code}).');
          }
        }
      }
      await preferences.setString(_storageKey, jsonEncode(remaining));
    } finally {
      _flushing = false;
    }
  }

  bool isNetworkError(Object error) =>
      error is FirebaseFunctionsException && _isNetworkError(error.code);

  bool _isNetworkError(String code) =>
      code == 'unavailable' || code == 'deadline-exceeded';

  List<Map<String, dynamic>> _read(SharedPreferences preferences) {
    final value = preferences.getString(_storageKey);
    if (value == null || value.isEmpty) return <Map<String, dynamic>>[];
    try {
      return (jsonDecode(value) as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
