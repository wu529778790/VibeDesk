class IceServer {
  final String urls;
  final String? username;
  final String? credential;

  const IceServer({
    required this.urls,
    this.username,
    this.credential,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'urls': urls};
    if (username != null) map['username'] = username;
    if (credential != null) map['credential'] = credential;
    return map;
  }

  factory IceServer.fromMap(Map<String, dynamic> map) {
    return IceServer(
      urls: map['urls'] as String,
      username: map['username'] as String?,
      credential: map['credential'] as String?,
    );
  }
}

class IceConfig {
  static const defaultServers = [
    IceServer(urls: 'stun:stun.l.google.com:19302'),
    IceServer(urls: 'stun:stun1.l.google.com:19302'),
  ];

  final List<IceServer> servers;

  const IceConfig({this.servers = defaultServers});

  List<Map<String, dynamic>> toMapList() =>
      servers.map((s) => s.toMap()).toList();
}
