import 'package:book_store/screens/transaction_status/ui/abstract_transaction_detail_page.dart';
import 'package:book_store/theme.dart';
import 'package:flutter/material.dart';

class CanCancelledTransactionDetailPage extends AbstractTransactionDetailPage {
  final VoidCallback onCancelled;

  const CanCancelledTransactionDetailPage({
    super.key,
    required super.transactionData,
    required this.onCancelled,
  });

  @override
  Widget buildAction(context) {
    return Container(
      height: 48,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      color: Colors.white,
      child: ElevatedButton(
        onPressed: transactionData.paid ? null : onCancelled,
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          transactionData.paid
              ? 'Không thể hủy đơn đã thanh toán'
              : 'Hủy đơn hàng',
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
