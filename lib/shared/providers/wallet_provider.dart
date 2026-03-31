import 'package:flutter/foundation.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService _walletService = WalletService();
  
  Wallet? _wallet;
  bool _isLoading = false;
  String? _errorMessage;
  List<WalletTransaction> _transactions = [];

  Wallet? get wallet => _wallet;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<WalletTransaction> get transactions => _transactions;

  double get balance => _wallet?.balance ?? 0.0;
  String get formattedBalance => _wallet?.formattedBalance ?? '¥0.00';
  int get bankCardCount => _wallet?.bankCardCount ?? 0;
  List<BankCard> get bankCards => _wallet?.bankCards ?? [];

  Future<void> loadWallet(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // 使用测试用户ID，确保能加载到数据
      final testUserId = userId.isEmpty ? 'test_user' : userId;
      _wallet = await _walletService.getWallet(testUserId);
      
      // 自动加载交易数据
      if (_wallet != null) {
        await loadTransactions(_wallet!.id);
      }
      
      notifyListeners();
    } catch (e) {
      _setError('加载钱包信息失败: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTransactions(String walletId) async {
    try {
      _transactions = await _walletService.getTransactions(walletId);
      notifyListeners();
    } catch (e) {
      debugPrint('加载交易记录失败: $e');
    }
  }

  Future<bool> addBankCard({
    required String bankName,
    required String cardNumber,
    required String cardType,
    required String cardHolderName,
    bool isDefault = false,
  }) async {
    if (_wallet == null) return false;

    try {
      final bankCard = await _walletService.addBankCard(
        walletId: _wallet!.id,
        bankName: bankName,
        cardNumber: cardNumber,
        cardType: cardType,
        cardHolderName: cardHolderName,
        isDefault: isDefault,
      );

      final updatedCards = List<BankCard>.from(_wallet!.bankCards)..add(bankCard);
      _wallet = _wallet!.copyWith(bankCards: updatedCards);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('添加银行卡失败: ${e.toString()}');
      return false;
    }
  }

  Future<bool> removeBankCard(String cardId) async {
    if (_wallet == null) return false;

    try {
      await _walletService.removeBankCard(cardId);
      final updatedCards = _wallet!.bankCards.where((card) => card.id != cardId).toList();
      _wallet = _wallet!.copyWith(bankCards: updatedCards);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('删除银行卡失败: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deposit(double amount, String bankCardId) async {
    if (_wallet == null) return false;

    try {
      final newBalance = await _walletService.deposit(
        walletId: _wallet!.id,
        amount: amount,
        bankCardId: bankCardId,
      );

      _wallet = _wallet!.copyWith(
        balance: newBalance,
        lastUpdated: DateTime.now(),
      );
      
      // 重新加载交易记录
      await loadTransactions(_wallet!.id);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('充值失败: ${e.toString()}');
      return false;
    }
  }

  Future<bool> withdraw(double amount, String bankCardId) async {
    if (_wallet == null) return false;

    if (amount > _wallet!.balance) {
      _setError('余额不足');
      return false;
    }

    try {
      final newBalance = await _walletService.withdraw(
        walletId: _wallet!.id,
        amount: amount,
        bankCardId: bankCardId,
      );

      _wallet = _wallet!.copyWith(
        balance: newBalance,
        lastUpdated: DateTime.now(),
      );
      
      // 重新加载交易记录
      await loadTransactions(_wallet!.id);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('提现失败: ${e.toString()}');
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearWallet() {
    _wallet = null;
    _transactions = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}