class User {
  final int id;
  final String username;
  final String email;
  final String? nickname;
  final String? avatar;
  final String? signature;
  final String? phone;
  final UserStatus status;
  // Optional account control fields from backend (for bans/suspensions)
  // Keep separate from presence `status` to avoid breaking existing logic.
  final bool? isBanned;
  final String? banReason;
  // Some backends may expose an explicit account state string
  // like BANNED/SUSPENDED/DISABLED; we store it verbatim for diagnostics.
  final String? accountState;
  final bool profileCompleted;
  final bool passwordSet;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.nickname,
    this.avatar,
    this.signature,
    this.phone,
    required this.status,
    this.isBanned,
    this.banReason,
    this.accountState,
    this.profileCompleted = false,
    this.passwordSet = true,
    this.emailVerified = false,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parse extended account control fields defensively.
    final parsedAccountState = _parseAccountState(json);
    final parsedIsBanned = _parseIsBanned(json, parsedAccountState);
    final parsedBanReason = _parseBanReason(json);
    return User(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      signature: json['signature'] as String?,
      phone: json['phone'] as String?,
      status: _parseUserStatus(json['status']),
      isBanned: parsedIsBanned,
      banReason: parsedBanReason,
      accountState: parsedAccountState,
      profileCompleted:
          _asBool(json['profileCompleted'] ?? json['profile_completed']) ??
              false,
      passwordSet: _asBool(json['passwordSet'] ?? json['password_set']) ?? true,
      emailVerified:
          _asBool(json['emailVerified'] ?? json['email_verified']) ?? false,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  static UserStatus _parseUserStatus(dynamic status) {
    if (status == null) return UserStatus.offline;
    final statusStr = status.toString().toUpperCase();
    switch (statusStr) {
      case 'ONLINE':
        return UserStatus.online;
      case 'OFFLINE':
        return UserStatus.offline;
      case 'BUSY':
        return UserStatus.busy;
      case 'AWAY':
        return UserStatus.away;
      case 'ACTIVE':
        return UserStatus.active;
      default:
        return UserStatus.offline;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'nickname': nickname,
      'avatar': avatar,
      'signature': signature,
      'phone': phone,
      'status': status.name.toUpperCase(),
      if (isBanned != null) 'isBanned': isBanned,
      if (banReason != null) 'banReason': banReason,
      if (accountState != null) 'accountState': accountState,
      'profileCompleted': profileCompleted,
      'passwordSet': passwordSet,
      'emailVerified': emailVerified,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? nickname,
    String? avatar,
    String? signature,
    String? phone,
    UserStatus? status,
    bool? isBanned,
    String? banReason,
    String? accountState,
    bool? profileCompleted,
    bool? passwordSet,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      signature: signature ?? this.signature,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      accountState: accountState ?? this.accountState,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      passwordSet: passwordSet ?? this.passwordSet,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum UserStatus { online, offline, busy, away, active }

// Helpers for flexible parsing of backend account-control fields.
bool _parseIsBanned(Map<String, dynamic> json, String? accountState) {
  final v1 = json['isBanned'];
  if (v1 is bool) return v1;
  final v2 = json['banned'];
  if (v2 is bool) return v2;
  final v3 = json['disabled'];
  if (v3 is bool) return v3;
  final v4 = json['suspended'];
  if (v4 is bool) return v4;

  // String/num flags like 0/1
  final v5 = json['is_banned'] ?? json['banFlag'] ?? json['ban_flag'];
  if (v5 is num) return v5 != 0;
  if (v5 is String) {
    final s = v5.toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }

  // Fall back to textual account state if provided
  if (accountState != null) {
    final s = accountState.toUpperCase();
    if (s == 'BANNED' ||
        s == 'DISABLED' ||
        s == 'SUSPENDED' ||
        s == 'BLOCKED') {
      return true;
    }
  }
  // Some backends overload `status` field for account state.
  final rawStatus = json['status'];
  if (rawStatus is String) {
    final s = rawStatus.toUpperCase();
    if (s == 'BANNED' ||
        s == 'DISABLED' ||
        s == 'SUSPENDED' ||
        s == 'BLOCKED') {
      return true;
    }
  }
  return false;
}

String? _parseBanReason(Map<String, dynamic> json) {
  final keys = [
    'banReason',
    'reason',
    'ban_reason',
    'blockReason',
    'disabledReason',
    'banMsg',
    'ban_msg'
  ];
  for (final k in keys) {
    final v = json[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

String? _parseAccountState(Map<String, dynamic> json) {
  final keys = ['accountStatus', 'account_state', 'accountState'];
  for (final k in keys) {
    final v = json[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
  }
  return null;
}
