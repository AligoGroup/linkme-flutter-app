import 'dart:math';
import '../models/wallet.dart';

class WalletService {
  // 模拟数据存储
  static final Map<String, Wallet> _wallets = {};
  static final Map<String, List<WalletTransaction>> _transactions = {};

  Future<Wallet> getWallet(String userId) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 使用固定的测试用户ID，确保数据一致性
    final testUserId = userId.isEmpty ? 'test_user' : userId;

    // 如果钱包不存在，创建一个新的
    if (!_wallets.containsKey(testUserId)) {
      final wallet = Wallet(
        id: 'wallet_$testUserId',
        userId: testUserId,
        balance: 0.20, // 初始余额0.20元，模拟截图中的数据
        lastUpdated: DateTime.now(),
        bankCards: [
          BankCard(
            id: 'card_${testUserId}_1',
            walletId: 'wallet_$testUserId',
            bankName: '建设银行',
            cardNumber: '6227001234567890',
            cardType: '储蓄卡',
            cardHolderName: '张三',
            isDefault: true,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ],
      );
      _wallets[testUserId] = wallet;
      
      // 同时预生成交易数据
      _transactions['wallet_$testUserId'] = _generateMockTransactions('wallet_$testUserId');
    }

    return _wallets[testUserId]!;
  }

  Future<List<WalletTransaction>> getTransactions(String walletId) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 300));

    if (!_transactions.containsKey(walletId)) {
      // 生成丰富的模拟交易记录
      _transactions[walletId] = _generateMockTransactions(walletId);
    }

    return _transactions[walletId]!;
  }

  List<WalletTransaction> _generateMockTransactions(String walletId) {
    final now = DateTime.now();
    final random = Random();
    final transactions = <WalletTransaction>[];

    // 交易类型和描述的模拟数据
    final transactionData = [
      {'type': TransactionType.deposit, 'descriptions': ['银行卡充值', '支付宝充值', '微信充值', '余额充值']},
      {'type': TransactionType.payment, 'descriptions': ['在线支付', '商户消费', '转账支付', '购买商品', '服务费用', '餐饮消费']},
      {'type': TransactionType.withdraw, 'descriptions': ['提现到银行卡', '余额提现', '快速提现']},
      {'type': TransactionType.transfer, 'descriptions': ['转账给朋友', '红包转账', '群聊转账', '好友转账']},
    ];

    // 生成15条交易记录，确保每种类型都有
    for (int i = 0; i < 15; i++) {
      // 前4条确保每种类型都有一条，后面的随机生成
      final dataIndex = i < 4 ? i : random.nextInt(transactionData.length);
      final typeData = transactionData[dataIndex];
      final type = typeData['type'] as TransactionType;
      final descriptions = typeData['descriptions'] as List<String>;
      final description = descriptions[random.nextInt(descriptions.length)];
      
      // 生成随机金额
      double amount;
      switch (type) {
        case TransactionType.deposit:
          amount = 50.0 + random.nextDouble() * 450.0; // 50-500元
          break;
        case TransactionType.withdraw:
          amount = 20.0 + random.nextDouble() * 280.0; // 20-300元
          break;
        case TransactionType.payment:
          amount = 5.0 + random.nextDouble() * 195.0; // 5-200元
          break;
        case TransactionType.transfer:
          amount = 10.0 + random.nextDouble() * 490.0; // 10-500元
          break;
      }
      
      // 生成随机时间（最近30天内）
      final daysAgo = random.nextInt(30);
      final hoursAgo = random.nextInt(24);
      final minutesAgo = random.nextInt(60);
      final createdAt = now.subtract(Duration(
        days: daysAgo,
        hours: hoursAgo,
        minutes: minutesAgo,
      ));

      // 生成流水编号
      final serialNumber = '${DateTime.now().year}${(DateTime.now().month).toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}${random.nextInt(999999).toString().padLeft(6, '0')}';
      
      // 生成支付方式和收款方信息
      String paymentMethod;
      String? targetUserName;
      String? merchantName;
      
      switch (type) {
        case TransactionType.deposit:
          final methods = ['银行卡', '支付宝', '微信支付', '余额充值'];
          paymentMethod = methods[random.nextInt(methods.length)];
          break;
        case TransactionType.withdraw:
          final methods = ['中国银行', '工商银行', '建设银行', '农业银行', '招商银行'];
          paymentMethod = methods[random.nextInt(methods.length)];
          break;
        case TransactionType.transfer:
          paymentMethod = 'Link钱包余额';
          final names = ['张三', '李四', '王五', '赵六', '钱七', '孙八', '周九', '吴十'];
          targetUserName = names[random.nextInt(names.length)];
          break;
        case TransactionType.payment:
          paymentMethod = 'Link钱包余额';
          final merchants = ['星巴克咖啡', '麦当劳', '肯德基', '美团外卖', '滴滴出行', '京东商城', '淘宝网', '天猫超市'];
          merchantName = merchants[random.nextInt(merchants.length)];
          break;
      }

      transactions.add(WalletTransaction(
        id: 'tx_${i + 1}_${DateTime.now().millisecondsSinceEpoch}',
        walletId: walletId,
        type: type,
        amount: double.parse(amount.toStringAsFixed(2)),
        description: description,
        createdAt: createdAt,
        targetUserId: type == TransactionType.transfer ? 'user_${random.nextInt(1000)}' : null,
        targetUserName: targetUserName,
        serialNumber: serialNumber,
        paymentMethod: paymentMethod,
        merchantName: merchantName,
      ));
    }

    // 按时间降序排序（最新的在前面）
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return transactions;
  }

  Future<BankCard> addBankCard({
    required String walletId,
    required String bankName,
    required String cardNumber,
    required String cardType,
    required String cardHolderName,
    bool isDefault = false,
  }) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));

    // 模拟添加银行卡的验证
    if (cardNumber.length < 16) {
      throw Exception('银行卡号格式不正确');
    }

    final bankCard = BankCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      walletId: walletId,
      bankName: bankName,
      cardNumber: cardNumber,
      cardType: cardType,
      cardHolderName: cardHolderName,
      isDefault: isDefault,
      createdAt: DateTime.now(),
    );

    return bankCard;
  }

  Future<void> removeBankCard(String cardId) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 模拟删除操作
    // 在实际应用中，这里会调用API删除银行卡
  }

  Future<double> deposit({
    required String walletId,
    required double amount,
    required String bankCardId,
  }) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 1000));

    if (amount <= 0) {
      throw Exception('充值金额必须大于0');
    }

    // 获取当前钱包
    final wallet = _wallets.values.firstWhere((w) => w.id == walletId);
    final newBalance = wallet.balance + amount;

    // 更新钱包余额
    _wallets[wallet.userId] = wallet.copyWith(
      balance: newBalance,
      lastUpdated: DateTime.now(),
    );

    // 添加交易记录
    final transaction = WalletTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      walletId: walletId,
      type: TransactionType.deposit,
      amount: amount,
      description: '银行卡充值',
      createdAt: DateTime.now(),
      targetUserId: null,
      targetUserName: null,
      serialNumber: '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      paymentMethod: '银行卡',
      merchantName: null,
    );

    if (!_transactions.containsKey(walletId)) {
      _transactions[walletId] = [];
    }
    _transactions[walletId]!.insert(0, transaction);

    return newBalance;
  }

  Future<double> withdraw({
    required String walletId,
    required double amount,
    required String bankCardId,
  }) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 1000));

    if (amount <= 0) {
      throw Exception('提现金额必须大于0');
    }

    // 获取当前钱包
    final wallet = _wallets.values.firstWhere((w) => w.id == walletId);
    
    if (amount > wallet.balance) {
      throw Exception('余额不足');
    }

    final newBalance = wallet.balance - amount;

    // 更新钱包余额
    _wallets[wallet.userId] = wallet.copyWith(
      balance: newBalance,
      lastUpdated: DateTime.now(),
    );

    // 添加交易记录
    final transaction = WalletTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      walletId: walletId,
      type: TransactionType.withdraw,
      amount: amount,
      description: '提现到银行卡',
      createdAt: DateTime.now(),
      targetUserId: null,
      targetUserName: null,
      serialNumber: '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      paymentMethod: '银行卡',
      merchantName: null,
    );

    if (!_transactions.containsKey(walletId)) {
      _transactions[walletId] = [];
    }
    _transactions[walletId]!.insert(0, transaction);

    return newBalance;
  }
}