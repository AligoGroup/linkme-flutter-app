import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../widgets/common/linkme_loader.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/providers/wallet_provider.dart';
import '../../shared/models/wallet.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('交易记录'),
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
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

          if (walletProvider.transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无交易记录',
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: walletProvider.transactions.length,
            itemBuilder: (context, index) {
              final transaction = walletProvider.transactions[index];
              return _buildTransactionItem(transaction);
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionItem(WalletTransaction transaction) {
    return GestureDetector(
      onTap: () {
        context.push('/wallet/transaction-detail', extra: transaction);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 交易类型图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getTransactionTypeColor(transaction.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTransactionTypeIcon(transaction.type),
                color: _getTransactionTypeColor(transaction.type),
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 交易信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 交易类型和描述
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTransactionTypeColor(transaction.type).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          transaction.typeDisplayName,
                          style: AppTextStyles.caption.copyWith(
                            color: _getTransactionTypeColor(transaction.type),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          transaction.description,
                          style: AppTextStyles.body2.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 时间
                  Text(
                    _formatDateTime(transaction.createdAt),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                  
                  // 如果是转账，显示目标用户
                  if (transaction.targetUserName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '对方: ${transaction.targetUserName}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // 金额
            Text(
              transaction.formattedAmount,
              style: AppTextStyles.h6.copyWith(
                color: transaction.type == TransactionType.deposit 
                    ? AppColors.success 
                    : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTransactionTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return AppColors.success;
      case TransactionType.withdraw:
        return AppColors.error;
      case TransactionType.transfer:
        return AppColors.primary;
      case TransactionType.payment:
        return AppColors.warning;
    }
  }

  IconData _getTransactionTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return Icons.add_circle_outline;
      case TransactionType.withdraw:
        return Icons.remove_circle_outline;
      case TransactionType.transfer:
        return Icons.swap_horiz;
      case TransactionType.payment:
        return Icons.payment;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
