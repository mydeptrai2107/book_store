import 'package:book_store/custom_widgets/custom_page_route.dart';
import 'package:book_store/screens/checkout/ui/checkout_page.dart';
import 'package:book_store/screens/transaction_status/cancelled/ui/cancelled_item.dart';
import 'package:book_store/screens/transaction_status/ui/empty_page.dart';
import 'package:book_store/screens/transaction_status/ui/transaction_detail_reorder_page.dart';
import 'package:book_store/screens/transaction_status/ui/transaction_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/cancelled_bloc.dart';

class CancelledTransactionPage extends StatelessWidget {
  const CancelledTransactionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CancelledBloc, CancelledState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const TransactionLoadingPage();
        }

        if (state.transactions.isEmpty) {
          return const EmptyTransactionPage();
        }

        return ListView.builder(
          itemBuilder: (context, index) {
            return CancelledItem(
              transactionData: state.transactions[index],
              onReOrder: () {
                Navigator.of(context).push(
                  PageRouteSlideTransition(
                    child: CheckoutPage(
                      listProduct: state.transactions[index].products,
                      checkoutFromCart: false,
                    ),
                  ),
                );
              },
              onTap: () {
                Navigator.of(context).push(
                  PageRouteSlideTransition(
                    child: ReOrderTransactionDetailPage(
                      transactionData: state.transactions[index],
                      onReOrder: () {
                        Navigator.of(context).push(
                          PageRouteSlideTransition(
                            child: CheckoutPage(
                              listProduct: state.transactions[index].products,
                              checkoutFromCart: false,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
          itemCount: state.transactions.length,
        );
      },
    );
  }
}
