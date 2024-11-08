import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:book_store/core/models/address_model.dart';
import 'package:book_store/core/models/create_order_response.dart';
import 'package:book_store/core/models/payment_method_model.dart';
import 'package:book_store/core/models/transaction_model.dart';
import 'package:book_store/core/models/transport_model.dart';
import 'package:book_store/core/repositories/address_repository.dart';
import 'package:book_store/core/repositories/checkout_repository.dart';
import 'package:book_store/core/repositories/notification_repository.dart';
import 'package:book_store/utils/zalopay_app_config.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/cart_item_model.dart';
import '../../../core/models/logging_model.dart';
import '../../../core/services/logging_service.dart';

part 'checkout_event.dart';
part 'checkout_state.dart';

class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  static const MethodChannel platform =
      MethodChannel('flutter.native/channelPayOrder');
  StreamSubscription? _addressStream;
  final AddressRepository _addressRepository;
  final CheckoutRepository _checkoutRepository;
  final NotificationRepository _notiRepository;

  CheckoutBloc(
      this._addressRepository, this._checkoutRepository, this._notiRepository)
      : super(const CheckoutState(isLoading: true)) {
    on<CheckoutLoadingEvent>(_onLoading);
    on<CheckoutUpdateEmptyAddressEvent>(_onUpdateEmptyAddress);
    on<CheckoutUpdateAddressEvent>(_onUpdateAdrress);
    on<CheckoutSimpleOrderEvent>(_onOder);
    on<CheckoutZaloPayOrderEvent>(_onZaloPayOrder);
    on<CheckoutUpdatePaymentMethodEvent>(_onUpdatePaymentMethod);
    on<CheckoutUpdateTransportEvent>(_onUpdateTransport);
    on<UpdateUserNoteEvent>(_updateUserNote);
  }

  @override
  Future<void> close() async {
    _addressStream?.cancel();
    _addressStream = null;
    super.close();
  }

  _onLoading(CheckoutLoadingEvent event, Emitter emit) {
    emit(state.copyWith(isLoading: true));
    _addressStream = _addressRepository
        .userMainAddressStream()
        .listen((firebaseEvent) async {
      if (firebaseEvent.docs.isNotEmpty) {
        AddressModel userAddress =
            AddressModel.fromSnapshot(firebaseEvent.docs.first);

        add(CheckoutUpdateAddressEvent(newAddress: userAddress));
      } else {
        List<TransportModel> transports =
            await _checkoutRepository.getTransports();

        add(CheckoutUpdateEmptyAddressEvent(transports: transports));
      }
    });
  }

  _onUpdateAdrress(CheckoutUpdateAddressEvent event, Emitter emit) async {
    if (state.isLoading) {
      List<TransportModel> transports =
          await _checkoutRepository.getTransports();
      List<PaymentMethodModel> payments =
          List.from(PaymentMethodModel.listPayment);

      emit(
        state.copyWith(
          isLoading: false,
          showLoadingDialog: false,
          userAddress: event.newAddress,
          transports: transports,
          selectedTransport: transports.firstOrNull,
          payments: payments,
          selectedPayments: payments.firstOrNull,
        ),
      );
    } else {
      emit(
        state.copyWith(
          isLoading: false,
          showLoadingDialog: false,
          userAddress: event.newAddress,
        ),
      );
    }
  }

  _onUpdateEmptyAddress(CheckoutUpdateEmptyAddressEvent event, Emitter emit) {
    List<PaymentMethodModel> payments =
        List.from(PaymentMethodModel.listPayment);

    emit(state.copyWith(
      showLoadingDialog: false,
      isLoading: false,
      payments: payments,
      selectedPayments: payments.firstOrNull,
      transports: event.transports,
      selectedTransport: event.transports.firstOrNull,
    ));
  }

  _onOder(CheckoutSimpleOrderEvent event, Emitter emit) async {
    if (state.userAddress != null) {
      emit(state.copyWith(showLoadingDialog: true));

      bool checkStock =
          await _checkoutRepository.checkProductQuantity(event.list);

      if (checkStock == true) {
        final transactionModel = TransactionModel(
          id: '',
          dateCreated: DateTime.now(),
          dateCompleted: getDateCompleted(state.selectedTransport),
          address: state.userAddress!.address,
          transport: state.selectedTransport!.name,
          note: state.note,
          totalPrice: calculateTotalPrice(event.list, state.selectedTransport!),
          productPrice: calculateTotalProductPrice(event.list) -
              calculateTotalDiscount(event.list),
          transportPrice: state.selectedTransport!.price,
          products: event.list,
          status: 0,
          paid: false,
          paymentMethod: 'Thanh toán khi nhận hàng',
          phone: state.userAddress!.phone,
          userName: state.userAddress!.name,
        );

        try {
          await _checkoutRepository
              .createTransaction2(transactionModel)
              .then((value) async {
            await Future.wait([
              _notiRepository.createOrderTransactionNoti(value),
              _notiRepository.sendCreateNotiToAdmin(value),
              _checkoutRepository
                  .decreaseMultiProduct(transactionModel.products),
              event.fromCart
                  ? _checkoutRepository
                      .deleteItemFromCart(transactionModel.products)
                  : Future.value(null),
            ]);
            LoggingService().logging(LoggingModel(
              id: '',
              time: DateTime.now(),
              uid: FirebaseAuth.instance.currentUser!.uid,
              function: 'Create Order',
              metaData: {
                'status': 'create_order_successfully',
                'orderId': value,
                'payment': 'simple',
              },
            ));

            emit(CheckoutOrderSuccessfulState(idTransaction: value));
          });
        } on FirebaseException catch (e) {
          emit(state.copyWith(showLoadingDialog: false));
          Fluttertoast.showToast(msg: "Error: ${e.message}");

          LoggingService().logging(LoggingModel(
            id: '',
            time: DateTime.now(),
            uid: FirebaseAuth.instance.currentUser!.uid,
            function: 'Create Order',
            metaData: {
              'status': 'create_order_failure',
              'code': e.code,
              'actor': 'firebase',
            },
          ));
        }
      } else {
        emit(state.copyWith(showLoadingDialog: false));
        Fluttertoast.showToast(msg: "Số lượng hàng trong kho không đủ");

        LoggingService().logging(LoggingModel(
          id: '',
          time: DateTime.now(),
          uid: FirebaseAuth.instance.currentUser!.uid,
          function: 'Create Order',
          metaData: {
            'status': 'create_order_failure',
            'reason': 'not_enough',
            'actor': 'firebase',
          },
        ));
      }
    } else if (state.userAddress == null) {
      Fluttertoast.showToast(msg: 'Vui lòng cung cấp địa chỉ giao hàng');
    }
  }

  _onZaloPayOrder(CheckoutZaloPayOrderEvent event, Emitter emit) async {
    if (state.userAddress != null) {
      emit(state.copyWith(showLoadingDialog: true));

      bool checkStock =
          await _checkoutRepository.checkProductQuantity(event.list);

      if (checkStock == true) {
        final transactionModel = TransactionModel(
          id: '',
          dateCreated: DateTime.now(),
          dateCompleted: getDateCompleted(state.selectedTransport),
          address: state.userAddress!.address,
          transport: state.selectedTransport!.name,
          note: state.note,
          totalPrice: calculateTotalPrice(event.list, state.selectedTransport!),
          productPrice: calculateTotalProductPrice(event.list) -
              calculateTotalDiscount(event.list),
          transportPrice: state.selectedTransport!.price,
          products: event.list,
          status: 0,
          paid: true,
          paymentMethod: 'ZaloPay',
          phone: state.userAddress!.phone,
          userName: state.userAddress!.name,
        );

        var createOrderResult =
            await createOrder(transactionModel.totalPrice.toInt());
        if (createOrderResult != null) {
          final String result = await platform.invokeMethod(
              'payOrder', {"zptoken": createOrderResult.zptranstoken});
          if (result == 'Payment Success') {
            try {
              await _checkoutRepository
                  .createTransaction2(transactionModel)
                  .then((value) async {
                await Future.wait([
                  _notiRepository.createOrderTransactionNoti(value),
                  _notiRepository.sendCreateNotiToAdmin(value),
                  _checkoutRepository
                      .decreaseMultiProduct(transactionModel.products),
                  event.fromCart
                      ? _checkoutRepository
                          .deleteItemFromCart(transactionModel.products)
                      : Future.value(null),
                ]);

                LoggingService().logging(LoggingModel(
                  id: '',
                  time: DateTime.now(),
                  uid: FirebaseAuth.instance.currentUser!.uid,
                  function: 'Create Order',
                  metaData: {
                    'status': 'create_order_successfully',
                    'orderId': value,
                    'payment': 'zalopay',
                  },
                ));

                emit(CheckoutOrderSuccessfulState(idTransaction: value));
              });
            } on FirebaseException catch (e) {
              emit(state.copyWith(showLoadingDialog: false));
              Fluttertoast.showToast(msg: "Error: ${e.message}");

              LoggingService().logging(LoggingModel(
                id: '',
                time: DateTime.now(),
                uid: FirebaseAuth.instance.currentUser!.uid,
                function: 'Create Order',
                metaData: {
                  'status': 'create_order_failure',
                  'code': e.code,
                  'actor': 'firebase',
                },
              ));
            }
          } else {
            switch (result) {
              case 'User Canceled':
                emit(state.copyWith(showLoadingDialog: false));
                Fluttertoast.showToast(msg: "Thanh toán bị hủy");

                LoggingService().logging(LoggingModel(
                  id: '',
                  time: DateTime.now(),
                  uid: FirebaseAuth.instance.currentUser!.uid,
                  function: 'Create Order',
                  metaData: {
                    'status': 'create_order_failure',
                    'reason': 'user_cancelled',
                    'actor': 'zalopay',
                  },
                ));
                break;
              case 'Payment failed':
                emit(state.copyWith(showLoadingDialog: false));
                Fluttertoast.showToast(msg: "Lỗi thanh toán");

                LoggingService().logging(LoggingModel(
                  id: '',
                  time: DateTime.now(),
                  uid: FirebaseAuth.instance.currentUser!.uid,
                  function: 'Create Order',
                  metaData: {
                    'status': 'create_order_failure',
                    'reason': 'payment_error',
                    'actor': 'zalopay',
                  },
                ));
                break;
            }
          }
        } else {
          emit(state.copyWith(showLoadingDialog: false));
          Fluttertoast.showToast(msg: "Lỗi không xác định");

          LoggingService().logging(LoggingModel(
            id: '',
            time: DateTime.now(),
            uid: FirebaseAuth.instance.currentUser!.uid,
            function: 'Create Order',
            metaData: {
              'status': 'create_order_failure',
              'reason': 'unknow_reason',
              'actor': 'zalopay',
            },
          ));
        }
      } else {
        emit(state.copyWith(showLoadingDialog: false));
        Fluttertoast.showToast(msg: "Số lượng hàng trong kho không đủ");

        LoggingService().logging(LoggingModel(
          id: '',
          time: DateTime.now(),
          uid: FirebaseAuth.instance.currentUser!.uid,
          function: 'Create Order',
          metaData: {
            'status': 'create_order_failure',
            'reason': 'not_enough',
            'actor': 'firebase',
          },
        ));
      }
    } else if (state.userAddress == null) {
      Fluttertoast.showToast(msg: 'Vui lòng cung cấp địa chỉ giao hàng');
    }
  }

  Future<CreateOrderResponse?> createOrder(int price) async {
    var header = <String, String>{};
    header["Content-Type"] = "application/x-www-form-urlencoded";

    var body = <String, String>{};
    body["app_id"] = ZaloAppConfig.appId;
    body["app_user"] = ZaloAppConfig.appName;
    body["app_time"] = DateTime.now().millisecondsSinceEpoch.toString();
    body["amount"] = price.toStringAsFixed(0);
    body["app_trans_id"] =
        DateFormat('yyMMdd_hhmmss').format(DateTime.now()).toString();
    body["embed_data"] = "{}";
    body["item"] = "[]";
    body["bank_code"] = "zalopayapp";
    body["description"] = getDescription(body["app_trans_id"]);

    var dataGetMac =
        '${body["app_id"]}|${body["app_trans_id"]}|${body["app_user"]}|${body["amount"]}|${body["app_time"]}|${body["embed_data"]}|${body["item"]}';
    body["mac"] = getMacCreateOrder(dataGetMac);

    http.Response response = await http.post(
      Uri.parse(Uri.encodeFull(ZaloAppConfig.createOrderUrl)),
      headers: header,
      body: body,
    );

    if (response.statusCode != 200) {
      return null;
    }

    var data = jsonDecode(response.body);

    return CreateOrderResponse.fromJson(data);
  }

  String getDescription(String? body) =>
      "DuyHien thanh toán cho đơn hàng #$body";

  String getMacCreateOrder(String dataGetMac) {
    var hmac = Hmac(sha256, utf8.encode(ZaloAppConfig.key1));
    return hmac.convert(utf8.encode(dataGetMac)).toString();
  }

  _onUpdatePaymentMethod(CheckoutUpdatePaymentMethodEvent event, Emitter emit) {
    emit(state.copyWith(
      showLoadingDialog: false,
      selectedPayments: event.payment,
    ));
  }

  _onUpdateTransport(CheckoutUpdateTransportEvent event, Emitter emit) {
    emit(
      state.copyWith(
        selectedTransport: event.newTransport,
        showLoadingDialog: false,
      ),
    );
  }

  _updateUserNote(UpdateUserNoteEvent event, Emitter emit) {
    emit(state.copyWith(note: event.note.trim()));
  }

  double calculateTotalPrice(
      List<CartItemModel> list, TransportModel transports) {
    double result = 0;
    for (var item in list) {
      result += item.price * item.count;
    }
    result += transports.price;

    return result;
  }

  DateTime getDateCompleted(TransportModel? transportModel) {
    final dateNow = DateTime.now();
    final dayFromNow = dateNow.add(Duration(days: transportModel!.max));
    return dayFromNow;
  }

  double calculateTotalProductPrice(List<CartItemModel> list) {
    double result = 0;
    for (var item in list) {
      result += item.priceBeforeDiscount * item.count;
    }
    return result;
  }

  double calculateTotalDiscount(List<CartItemModel> list) {
    double result = 0;
    for (var item in list) {
      result += (item.priceBeforeDiscount - item.price) * item.count;
    }
    return result;
  }
}

