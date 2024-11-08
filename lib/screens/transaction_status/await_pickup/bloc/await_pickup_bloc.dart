import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:book_store/core/models/transaction_model.dart';
import 'package:book_store/core/repositories/notification_repository.dart';
import 'package:book_store/core/repositories/transaction_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../../core/models/cart_item_model.dart';
import '../../../../core/models/logging_model.dart';
import '../../../../core/services/logging_service.dart';

part 'await_pickup_event.dart';
part 'await_pickup_state.dart';

class AwaitPickupBloc extends Bloc<AwaitPickupEvent, AwaitPickupState> {
  StreamSubscription? _bookingStream;
  final TransactionRepository _transactionRepository;
  final NotificationRepository _notificationRepository;

  AwaitPickupBloc(this._transactionRepository, this._notificationRepository)
      : super(const AwaitPickupState()) {
    on<AwaitPickupLoadingEvent>(_onLoading);
    on<AwaitPickupUpdateEvent>(_onUpdate);
    on<AwaitPickupUpdateEmptyEvent>(_onEmpty);
    on<AwaitPickupCancelEvent>(_onCancel);
  }

  @override
  Future<void> close() async {
    _bookingStream?.cancel();
    _bookingStream = null;
    super.close();
  }

  _onLoading(AwaitPickupLoadingEvent event, Emitter emit) async {
    emit(state.copyWith(isLoading: true));

    _bookingStream = _transactionRepository
        .transactionStream([1, 2]).listen((snapshotEvent) async {
      if (snapshotEvent.docs.isNotEmpty) {
        List<TransactionModel> list = [];

        // final futureGroup = await Future.wait(
        //   snapshotEvent.docs.map(
        //     (e) => _transactionRepository.getAllProductOfTransaction(e.id),
        //   ),
        // );

        for (int i = 0; i < snapshotEvent.size; i++) {
          List<CartItemModel> prs = [];

          List<Map<String, dynamic>> rawPrs =
              List.from(snapshotEvent.docs[i].data()['products']);

          final productsInfo = await Future.wait(
            rawPrs.map(
              (e) => _transactionRepository.getOrderProduct(e['productID']),
            ),
          );

          for (int j = 0; j < rawPrs.length; j++) {
            CartItemModel cartItem = CartItemModel(
              id: '',
              bookID: rawPrs[j]['productID'],
              count: rawPrs[j]['count'],
              price: rawPrs[j]['price'],
              imgUrl: productsInfo[j]['imgURL'],
              title: productsInfo[j]['productName'],
              priceBeforeDiscount: rawPrs[j]['priceBeforeDiscount'],
            );

            prs.add(cartItem);
          }

          list.add(
            TransactionModel.fromSnapshot(
              snapshotEvent.docs[i],
              // futureGroup[i],
              prs,
            ),
          );
        }

        if (!isClosed) {
          add(AwaitPickupUpdateEvent(transactions: list));
        }
      } else {
        if (!isClosed) {
          add(AwaitPickupUpdateEmptyEvent());
        }
      }
    });
  }

  _onUpdate(AwaitPickupUpdateEvent event, Emitter emit) {
    emit(
      state.copyWith(
        isLoading: false,
        transactions: event.transactions,
      ),
    );
  }

  _onEmpty(AwaitPickupUpdateEmptyEvent event, Emitter emit) {
    emit(
      state.copyWith(
        isLoading: false,
        transactions: [],
      ),
    );
  }

  _onCancel(AwaitPickupCancelEvent event, Emitter emit) async {
    await _transactionRepository
        .cancelTransaction(event.transactionID)
        .then((value) async {
      await Future.wait([
        _notificationRepository
            .createCancelTransactionNoti(event.transactionID),
        _notificationRepository.sendCancelNotiToAdmin(event.transactionID),
      ]);
      Fluttertoast.showToast(msg: 'Hủy đơn hàng thành công');

      LoggingService().logging(LoggingModel(
        id: '',
        time: DateTime.now(),
        uid: FirebaseAuth.instance.currentUser!.uid,
        function: 'Cancel Order',
        metaData: {
          'orderId': event.transactionID,
          'status': 'success',
        },
      ));
    }).catchError((_err) {
      LoggingService().logging(LoggingModel(
        id: '',
        time: DateTime.now(),
        uid: FirebaseAuth.instance.currentUser!.uid,
        function: 'Cancel Order',
        metaData: {
          'orderId': event.transactionID,
          'status': 'failure',
          'code': _err.toString(),
        },
      ));
    });
  }
}
