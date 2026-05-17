import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_state.dart';

const _deviceIdKey = 'vibedesk_device_id';

class AuthNotifier extends StateNotifier<VibeDeskAuthState> {
  final SupabaseClient _supabase;

  AuthNotifier(this._supabase) : super(const VibeDeskAuthState()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      await prefs.setString(_deviceIdKey, deviceId);
    }

    final user = _supabase.auth.currentUser;
    if (user != null) {
      state = VibeDeskAuthState(
        status: VibeDeskAuthStatus.authenticated,
        userId: user.id,
        email: user.email,
        deviceId: deviceId,
      );
      _registerDevice(deviceId, user.id);
    } else {
      state = VibeDeskAuthState(
        status: VibeDeskAuthStatus.unauthenticated,
        deviceId: deviceId,
      );
    }

    _supabase.auth.onAuthStateChange.listen((event) {
      final user = event.session?.user;
      if (user != null && state.status != VibeDeskAuthStatus.authenticated) {
        state = VibeDeskAuthState(
          status: VibeDeskAuthStatus.authenticated,
          userId: user.id,
          email: user.email,
          deviceId: state.deviceId,
        );
        _registerDevice(state.deviceId!, user.id);
      } else if (event.event == AuthChangeEvent.signedOut) {
        state = state.copyWith(status: VibeDeskAuthStatus.unauthenticated, userId: null, email: null);
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: VibeDeskAuthStatus.loading);
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      state = state.copyWith(status: VibeDeskAuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(status: VibeDeskAuthStatus.loading);
    try {
      await _supabase.auth.signUp(email: email, password: password);
    } catch (e) {
      state = state.copyWith(status: VibeDeskAuthStatus.unauthenticated);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  String? get jwt => _supabase.auth.currentSession?.accessToken;

  Future<void> _registerDevice(String deviceId, String userId) async {
    try {
      await _supabase.from('devices').upsert({
        'id': deviceId,
        'user_id': userId,
        'device_name': _deviceName(),
        'platform': Platform.operatingSystem,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  String _deviceName() {
    return '${Platform.operatingSystem} ${Platform.localHostname}';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, VibeDeskAuthState>((ref) {
  return AuthNotifier(Supabase.instance.client);
});
