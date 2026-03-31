import 'dart:async';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/unified_toast.dart';
import '../../widgets/common/linkme_loader.dart';
import '../../shared/providers/wallet_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/wallet.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with TickerProviderStateMixin {
  bool _isBalanceVisible = true;
  int _currentTransactionIndex = 0;
  Timer? _transactionTimer;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final walletProvider = context.read<WalletProvider>();
      
      // 使用用户ID或默认测试ID加载钱包数据
      final userId = authProvider.user?.id.toString() ?? 'test_user';
      await walletProvider.loadWallet(userId);
      
      // 启动交易轮播定时器
      _startTransactionTimer();
    });
  }

  @override
  void dispose() {
    _transactionTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startTransactionTimer() {
    _transactionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final walletProvider = context.read<WalletProvider>();
      if (walletProvider.transactions.isNotEmpty && walletProvider.transactions.length > 1) {
        _animationController.forward().then((_) {
          if (mounted) {
            setState(() {
              final transactionCount = walletProvider.transactions.length;
              if (transactionCount > 0) {
                _currentTransactionIndex = (_currentTransactionIndex + 1) % transactionCount;
              }
            });
            _animationController.reset();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Link钱包'),
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {

          
          if (walletProvider.isLoading) {
            return const Center(
              child: SizedBox(height: 28, child: LinkMeLoader(fontSize: 18)),
            );
          }

          if (walletProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    walletProvider.errorMessage!,
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final authProvider = context.read<AuthProvider>();
                      final userId = authProvider.user?.id.toString() ?? 'test_user';
                      walletProvider.loadWallet(userId);
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          if (walletProvider.wallet == null) {
            return const Center(
              child: Text('钱包信息不可用'),
            );
          }

          return Container(
            color: AppColors.background, // 确保背景色正确
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 余额显示区域（包含操作按钮）
                  _buildBalanceSection(walletProvider),
                  
                  // 账单明细区域
                  _buildTransactionBanner(context, walletProvider),
                  
                  // 银行卡列表
                  _buildBankCardSection(context, walletProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceSection(WalletProvider walletProvider) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '我的余额(元)',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textWhite.withOpacity(0.8),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isBalanceVisible = !_isBalanceVisible;
                  });
                },
                child: Icon(
                  _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textWhite.withOpacity(0.8),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isBalanceVisible ? walletProvider.balance.toStringAsFixed(2) : '***',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.textWhite,
              fontWeight: FontWeight.bold,
              fontSize: 36,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '上次更新: ${_formatDateTime(walletProvider.wallet!.lastUpdated)}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textWhite.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          // 操作按钮放在余额卡片内部
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: '充值',
                  onTap: () => _showDepositDialog(context, walletProvider),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: '提现',
                  onTap: () => _showWithdrawDialog(context, walletProvider),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionBanner(BuildContext context, WalletProvider walletProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () {
          // 点击账单明细横幅，跳转到交易历史页面
          context.push('/wallet/transactions');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.textLight.withOpacity(0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左侧：账单明细文本（固定不动）
              Text(
                '账单明细',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              
              // 中间：可变化的交易信息（带动画）
              Expanded(
                child: Container(
                  height: 20,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: walletProvider.transactions.isNotEmpty 
                    ? (walletProvider.transactions.length > 1 
                        ? AnimatedBuilder(
                            animation: _slideAnimation,
                            builder: (context, child) {
                              if (walletProvider.transactions.isEmpty) {
                                return Text(
                                  '暂无交易记录',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textLight,
                                  ),
                                );
                              }
                              
                              // 确保索引安全
                              final transactionCount = walletProvider.transactions.length;
                              if (transactionCount == 0) {
                                return Text(
                                  '暂无交易记录',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textLight,
                                  ),
                                );
                              }
                              
                              final safeCurrentIndex = _currentTransactionIndex.clamp(0, transactionCount - 1);
                              final safeNextIndex = (safeCurrentIndex + 1) % transactionCount;
                              
                              final currentTransaction = walletProvider.transactions[safeCurrentIndex];
                              final nextTransaction = walletProvider.transactions[safeNextIndex];
                              
                              return Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  // 当前交易 - 向上移动
                                  Transform.translate(
                                    offset: Offset(0, -20 * _slideAnimation.value),
                                    child: _buildSimpleTransactionText(currentTransaction),
                                  ),
                                  // 下一个交易 - 从下方移入
                                  Transform.translate(
                                    offset: Offset(0, 20 * (1 - _slideAnimation.value)),
                                    child: _buildSimpleTransactionText(nextTransaction),
                                  ),
                                ],
                              );
                            },
                          )
                        : _buildSimpleTransactionText(walletProvider.transactions.first))
                    : Text(
                        '暂无交易记录',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // 右侧：全部文本和箭头（固定不动）
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '全部',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleTransactionText(WalletTransaction transaction) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 类型标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getTransactionTypeColor(transaction.type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            transaction.typeDisplayName,
            style: AppTextStyles.caption.copyWith(
              color: _getTransactionTypeColor(transaction.type),
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        
        // 金额
        Text(
          transaction.formattedAmount,
          style: AppTextStyles.caption.copyWith(
            color: transaction.type == TransactionType.deposit ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        
        // 时间
        Text(
          _formatTransactionTime(transaction.createdAt),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textLight,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(WalletTransaction transaction) {
    return GestureDetector(
      onTap: () {
        context.push('/wallet/transaction-detail', extra: transaction);
      },
      child: _buildSimpleTransactionText(transaction),
    );
  }

  Color _getTransactionTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return AppColors.success; // 充值 - 绿色
      case TransactionType.withdraw:
        return AppColors.error; // 提现 - 红色
      case TransactionType.transfer:
        return AppColors.primary; // 转账 - 蓝色
      case TransactionType.payment:
        return AppColors.error; // 支付 - 红色（支出）
    }
  }

  String _formatTransactionTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  Widget _buildBankCardSection(BuildContext context, WalletProvider walletProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '我的卡(${walletProvider.bankCardCount}张)',
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => _showAddBankCardDialog(context, walletProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '添加',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 银行卡列表
        if (walletProvider.bankCards.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.credit_card_off,
                    size: 48,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '暂无银行卡',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: walletProvider.bankCards.map((card) {
              return _buildBankCardItem(context, card, walletProvider);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildBankCardItem(BuildContext context, BankCard card, WalletProvider walletProvider) {
    final colors = [
      Colors.blue.withOpacity(0.1),
      Colors.green.withOpacity(0.1),
      Colors.orange.withOpacity(0.1),
      Colors.purple.withOpacity(0.1),
      Colors.teal.withOpacity(0.1),
    ];
    final borderColors = [
      Colors.blue.withOpacity(0.3),
      Colors.green.withOpacity(0.3),
      Colors.orange.withOpacity(0.3),
      Colors.purple.withOpacity(0.3),
      Colors.teal.withOpacity(0.3),
    ];
    
    final cardIndex = walletProvider.bankCards.indexOf(card);
    final backgroundColor = colors[cardIndex % colors.length];
    final borderColor = borderColors[cardIndex % borderColors.length];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 银行图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 银行卡信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      card.bankName,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (card.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '默认',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textWhite,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  card.maskedCardNumber,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // 操作按钮
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: AppColors.textLight,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
              side: BorderSide(color: AppColors.textLight.withOpacity(0.2)),
            ),
            offset: const Offset(0, 10),
            onSelected: (value) {
              if (value == 'rebind') {
                _showRebindCardDialog(context, card, walletProvider);
              } else if (value == 'unbind') {
                _showUnbindCardDialog(context, card, walletProvider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rebind',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('换绑', style: TextStyle(color: AppColors.primary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'unbind',
                child: Row(
                  children: [
                    Icon(Icons.link_off, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('解绑', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}月${dateTime.day}日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showDepositDialog(BuildContext context, WalletProvider walletProvider) {
    if (walletProvider.bankCards.isEmpty) {
      context.showErrorToast('请先添加银行卡');
      return;
    }

    final amountController = TextEditingController();
    BankCard? selectedCard = walletProvider.bankCards.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('充值'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '充值金额',
                hintText: '请输入充值金额',
                prefixText: '¥',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BankCard>(
              value: selectedCard,
              decoration: const InputDecoration(
                labelText: '选择银行卡',
              ),
              items: walletProvider.bankCards.map((card) {
                return DropdownMenuItem(
                  value: card,
                  child: Text('${card.bankName} ${card.maskedCardNumber}'),
                );
              }).toList(),
              onChanged: (card) {
                selectedCard = card;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              amountController.dispose();
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                context.showErrorToast('请输入有效的充值金额');
                return;
              }

              if (selectedCard == null) {
                context.showErrorToast('请选择银行卡');
                return;
              }

              Navigator.of(context).pop();
              amountController.dispose();

              final success = await walletProvider.deposit(amount, selectedCard!.id);
              if (context.mounted) {
                if (success) {
                  context.showSuccessToast('充值成功');
                } else {
                  context.showErrorToast(walletProvider.errorMessage ?? '充值失败');
                }
              }
            },
            child: const Text('确认充值'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, WalletProvider walletProvider) {
    if (walletProvider.bankCards.isEmpty) {
      context.showErrorToast('请先添加银行卡');
      return;
    }

    final amountController = TextEditingController();
    BankCard? selectedCard = walletProvider.bankCards.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提现'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '提现金额',
                hintText: '请输入提现金额',
                prefixText: '¥',
                helperText: '当前余额: ${walletProvider.formattedBalance}',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BankCard>(
              value: selectedCard,
              decoration: const InputDecoration(
                labelText: '选择银行卡',
              ),
              items: walletProvider.bankCards.map((card) {
                return DropdownMenuItem(
                  value: card,
                  child: Text('${card.bankName} ${card.maskedCardNumber}'),
                );
              }).toList(),
              onChanged: (card) {
                selectedCard = card;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              amountController.dispose();
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                context.showErrorToast('请输入有效的提现金额');
                return;
              }

              if (amount > walletProvider.balance) {
                context.showErrorToast('提现金额不能超过余额');
                return;
              }

              if (selectedCard == null) {
                context.showErrorToast('请选择银行卡');
                return;
              }

              Navigator.of(context).pop();
              amountController.dispose();

              final success = await walletProvider.withdraw(amount, selectedCard!.id);
              if (context.mounted) {
                if (success) {
                  context.showSuccessToast('提现成功');
                } else {
                  context.showErrorToast(walletProvider.errorMessage ?? '提现失败');
                }
              }
            },
            child: const Text('确认提现'),
          ),
        ],
      ),
    );
  }

  void _showAddBankCardDialog(BuildContext context, WalletProvider walletProvider) {
    final bankNameController = TextEditingController();
    final cardNumberController = TextEditingController();
    final cardHolderController = TextEditingController();
    String cardType = '储蓄卡';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加银行卡'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bankNameController,
                decoration: const InputDecoration(
                  labelText: '银行名称',
                  hintText: '如：中国建设银行',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cardNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '银行卡号',
                  hintText: '请输入银行卡号',
                ),
                maxLength: 19,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cardHolderController,
                decoration: const InputDecoration(
                  labelText: '持卡人姓名',
                  hintText: '请输入持卡人姓名',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: cardType,
                decoration: const InputDecoration(
                  labelText: '卡片类型',
                ),
                items: ['储蓄卡', '信用卡'].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (type) {
                  if (type != null) {
                    cardType = type;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              bankNameController.dispose();
              cardNumberController.dispose();
              cardHolderController.dispose();
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final bankName = bankNameController.text.trim();
              final cardNumber = cardNumberController.text.trim();
              final cardHolder = cardHolderController.text.trim();

              if (bankName.isEmpty || cardNumber.isEmpty || cardHolder.isEmpty) {
                context.showErrorToast('请填写完整信息');
                return;
              }

              if (cardNumber.length < 16) {
                context.showErrorToast('银行卡号格式不正确');
                return;
              }

              Navigator.of(context).pop();
              
              bankNameController.dispose();
              cardNumberController.dispose();
              cardHolderController.dispose();

              final success = await walletProvider.addBankCard(
                bankName: bankName,
                cardNumber: cardNumber,
                cardType: cardType,
                cardHolderName: cardHolder,
                isDefault: walletProvider.bankCards.isEmpty,
              );

              if (context.mounted) {
                if (success) {
                  context.showSuccessToast('银行卡添加成功');
                } else {
                  context.showErrorToast(walletProvider.errorMessage ?? '添加银行卡失败');
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showUnbindCardDialog(BuildContext context, BankCard card, WalletProvider walletProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解绑银行卡'),
        content: Text('确定要解绑 ${card.bankName} ${card.maskedCardNumber} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final success = await walletProvider.removeBankCard(card.id);
              if (context.mounted) {
                if (success) {
                  context.showSuccessToast('银行卡解绑成功');
                } else {
                  context.showErrorToast(walletProvider.errorMessage ?? '解绑银行卡失败');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(
              '解绑',
              style: TextStyle(color: AppColors.textWhite),
            ),
          ),
        ],
      ),
    );
  }

  void _showRebindCardDialog(BuildContext context, BankCard card, WalletProvider walletProvider) {
    final bankNameController = TextEditingController(text: card.bankName);
    final cardNumberController = TextEditingController();
    final cardHolderController = TextEditingController(text: card.cardHolderName);
    String cardType = card.cardType;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('换绑银行卡'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bankNameController,
                decoration: const InputDecoration(
                  labelText: '银行名称',
                  hintText: '如：中国建设银行',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cardNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '新银行卡号',
                  hintText: '请输入新的银行卡号',
                ),
                maxLength: 19,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cardHolderController,
                decoration: const InputDecoration(
                  labelText: '持卡人姓名',
                  hintText: '请输入持卡人姓名',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: cardType,
                decoration: const InputDecoration(
                  labelText: '卡片类型',
                ),
                items: ['储蓄卡', '信用卡'].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (type) {
                  if (type != null) {
                    cardType = type;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              bankNameController.dispose();
              cardNumberController.dispose();
              cardHolderController.dispose();
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final bankName = bankNameController.text.trim();
              final cardNumber = cardNumberController.text.trim();
              final cardHolder = cardHolderController.text.trim();

              if (bankName.isEmpty || cardNumber.isEmpty || cardHolder.isEmpty) {
                context.showErrorToast('请填写完整信息');
                return;
              }

              if (cardNumber.length < 16) {
                context.showErrorToast('银行卡号格式不正确');
                return;
              }

              Navigator.of(context).pop();
              
              bankNameController.dispose();
              cardNumberController.dispose();
              cardHolderController.dispose();

              // 这里可以添加换绑的具体逻辑
              // 目前先使用删除旧卡添加新卡的方式模拟
              final removeSuccess = await walletProvider.removeBankCard(card.id);
              if (removeSuccess) {
                final addSuccess = await walletProvider.addBankCard(
                  bankName: bankName,
                  cardNumber: cardNumber,
                  cardType: cardType,
                  cardHolderName: cardHolder,
                  isDefault: card.isDefault,
                );
                
                if (context.mounted) {
                  if (addSuccess) {
                    context.showSuccessToast('银行卡换绑成功');
                  } else {
                    context.showErrorToast(walletProvider.errorMessage ?? '换绑银行卡失败');
                  }
                }
              } else {
                if (context.mounted) {
                  context.showErrorToast('换绑银行卡失败');
                }
              }
            },
            child: const Text('确认换绑'),
          ),
        ],
      ),
    );
  }
}
