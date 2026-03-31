class Wallet {
  final String id;
  final String userId;
  final double balance;
  final String currency;
  final DateTime lastUpdated;
  final List<BankCard> bankCards;

  const Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    this.currency = 'CNY',
    required this.lastUpdated,
    this.bankCards = const [],
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      userId: json['userId'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'CNY',
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      bankCards: (json['bankCards'] as List<dynamic>?)
          ?.map((e) => BankCard.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'balance': balance,
      'currency': currency,
      'lastUpdated': lastUpdated.toIso8601String(),
      'bankCards': bankCards.map((e) => e.toJson()).toList(),
    };
  }

  Wallet copyWith({
    String? id,
    String? userId,
    double? balance,
    String? currency,
    DateTime? lastUpdated,
    List<BankCard>? bankCards,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      bankCards: bankCards ?? this.bankCards,
    );
  }

  String get formattedBalance {
    return '¥${balance.toStringAsFixed(2)}';
  }

  int get bankCardCount => bankCards.length;
}

class BankCard {
  final String id;
  final String walletId;
  final String bankName;
  final String cardNumber;
  final String cardType;
  final String cardHolderName;
  final bool isDefault;
  final DateTime createdAt;

  const BankCard({
    required this.id,
    required this.walletId,
    required this.bankName,
    required this.cardNumber,
    required this.cardType,
    required this.cardHolderName,
    this.isDefault = false,
    required this.createdAt,
  });

  factory BankCard.fromJson(Map<String, dynamic> json) {
    return BankCard(
      id: json['id'] as String,
      walletId: json['walletId'] as String,
      bankName: json['bankName'] as String,
      cardNumber: json['cardNumber'] as String,
      cardType: json['cardType'] as String,
      cardHolderName: json['cardHolderName'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'bankName': bankName,
      'cardNumber': cardNumber,
      'cardType': cardType,
      'cardHolderName': cardHolderName,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get maskedCardNumber {
    if (cardNumber.length < 4) return cardNumber;
    return '**** ${cardNumber.substring(cardNumber.length - 4)}';
  }

  BankCard copyWith({
    String? id,
    String? walletId,
    String? bankName,
    String? cardNumber,
    String? cardType,
    String? cardHolderName,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return BankCard(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      bankName: bankName ?? this.bankName,
      cardNumber: cardNumber ?? this.cardNumber,
      cardType: cardType ?? this.cardType,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum TransactionType {
  deposit,  // 充值
  withdraw, // 提现
  transfer, // 转账
  payment,  // 支付
}

class WalletTransaction {
  final String id;
  final String walletId;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime createdAt;
  final String? targetUserId;
  final String? targetUserName;
  final String serialNumber; // 流水编号
  final String paymentMethod; // 支付方式
  final String? merchantName; // 商户名称/收款方

  const WalletTransaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.targetUserId,
    this.targetUserName,
    required this.serialNumber,
    required this.paymentMethod,
    this.merchantName,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      walletId: json['walletId'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      targetUserId: json['targetUserId'] as String?,
      targetUserName: json['targetUserName'] as String?,
      serialNumber: json['serialNumber'] as String,
      paymentMethod: json['paymentMethod'] as String,
      merchantName: json['merchantName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'type': type.toString().split('.').last,
      'amount': amount,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'targetUserId': targetUserId,
      'targetUserName': targetUserName,
      'serialNumber': serialNumber,
      'paymentMethod': paymentMethod,
      'merchantName': merchantName,
    };
  }

  String get formattedAmount {
    final prefix = (type == TransactionType.deposit || type == TransactionType.transfer && targetUserId != null) ? '+' : '-';
    return '$prefix¥${amount.toStringAsFixed(2)}';
  }

  String get typeDisplayName {
    switch (type) {
      case TransactionType.deposit:
        return '充值';
      case TransactionType.withdraw:
        return '提现';
      case TransactionType.transfer:
        return '转账';
      case TransactionType.payment:
        return '支付';
    }
  }

  String get recipientName {
    switch (type) {
      case TransactionType.deposit:
        return 'Link钱包';
      case TransactionType.withdraw:
        return paymentMethod;
      case TransactionType.transfer:
        return targetUserName ?? '未知用户';
      case TransactionType.payment:
        return merchantName ?? '商户';
    }
  }
}