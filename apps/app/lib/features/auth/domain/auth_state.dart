enum VibeDeskAuthStatus { unauthenticated, authenticated, loading }

class VibeDeskAuthState {
  final VibeDeskAuthStatus status;
  final String? userId;
  final String? email;
  final String? deviceId;

  const VibeDeskAuthState({
    this.status = VibeDeskAuthStatus.unauthenticated,
    this.userId,
    this.email,
    this.deviceId,
  });

  VibeDeskAuthState copyWith({
    VibeDeskAuthStatus? status,
    String? userId,
    String? email,
    String? deviceId,
  }) {
    return VibeDeskAuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
