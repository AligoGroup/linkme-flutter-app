import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/models/wallet.dart';
import '../../shared/providers/wallet_provider.dart';

class TransactionDetailScreen extends StatelessWidget {
  final WalletTransaction transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('交易详情'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 交易状态卡片
            _buildTransactionStatusCard(),
            
            const SizedBox(height: 16),
            
            // 交易详情信息
            _buildTransactionDetails(),
            
            const SizedBox(height: 24),
            
            // 功能按钮
            _buildActionButtons(context),
            
            const SizedBox(height: 24),
            
            // 其他账单
            _buildOtherTransactions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionStatusCard() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 交易图标
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _getTransactionTypeColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              _getTransactionTypeIcon(),
              size: 30,
              color: _getTransactionTypeColor(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 交易状态
          Text(
            '交易成功',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 交易金额
          Text(
            transaction.formattedAmount,
            style: AppTextStyles.h1.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _getTransactionTypeColor(),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 交易时间
          Text(
            _formatDateTime(transaction.createdAt),
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildDetailItem('消费类型', transaction.typeDisplayName),
          _buildDetailItem('流水编号', transaction.serialNumber),
          _buildDetailItem('收款方', transaction.recipientName),
          _buildDetailItem('账单时间', _formatDateTime(transaction.createdAt)),
          _buildDetailItem('金额', transaction.formattedAmount),
          _buildDetailItem('支付方式', transaction.paymentMethod, isLast: true),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(
            color: AppColors.textLight.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              context,
              '同类型账单',
              Icons.category_outlined,
              () => _showSameTypeTransactions(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionButton(
              context,
              '同收款方账单',
              Icons.person_outline,
              () => _showSameRecipientTransactions(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherTransactions(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        // 获取其他交易（排除当前交易）
        final otherTransactions = walletProvider.transactions
            .where((t) => t.id != transaction.id)
            .take(5)
            .toList();

        if (otherTransactions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '其他账单',
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...otherTransactions.map((t) => _buildOtherTransactionItem(context, t)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOtherTransactionItem(BuildContext context, WalletTransaction t) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(transaction: t),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.textLight.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // 交易图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getTransactionTypeColorForTransaction(t).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _getTransactionTypeIconForTransaction(t),
                size: 20,
                color: _getTransactionTypeColorForTransaction(t),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // 交易信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.description,
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(t.createdAt),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // 交易金额
            Text(
              t.formattedAmount,
              style: AppTextStyles.body2.copyWith(
                color: _getTransactionTypeColorForTransaction(t),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTransactionTypeColor() {
    return _getTransactionTypeColorForTransaction(transaction);
  }

  Color _getTransactionTypeColorForTransaction(WalletTransaction t) {
    switch (t.type) {
      case TransactionType.deposit:
        return AppColors.success;
      case TransactionType.withdraw:
        return AppColors.error;
      case TransactionType.transfer:
        return AppColors.primary;
      case TransactionType.payment:
        return AppColors.error;
    }
  }

  IconData _getTransactionTypeIcon() {
    return _getTransactionTypeIconForTransaction(transaction);
  }

  IconData _getTransactionTypeIconForTransaction(WalletTransaction t) {
    switch (t.type) {
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

  void _showSameTypeTransactions(BuildContext context) {
    final walletProvider = context.read<WalletProvider>();
    final sameTypeTransactions = walletProvider.transactions
        .where((t) => t.type == transaction.type && t.id != transaction.id)
        .toList();

    _showTransactionListDialog(
      context,
      '同类型账单 (${transaction.typeDisplayName})',
      sameTypeTransactions,
    );
  }

  void _showSameRecipientTransactions(BuildContext context) {
    final walletProvider = context.read<WalletProvider>();
    final sameRecipientTransactions = walletProvider.transactions
        .where((t) => t.recipientName == transaction.recipientName && t.id != transaction.id)
        .toList();

    _showTransactionListDialog(
      context,
      '同收款方账单 (${transaction.recipientName})',
      sameRecipientTransactions,
    );
  }

  void _showTransactionListDialog(
    BuildContext context,
    String title,
    List<WalletTransaction> transactions,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.textLight.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // 交易列表
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text(
                        '暂无相关交易记录',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final t = transactions[index];
                        return _buildOtherTransactionItem(context, t);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}