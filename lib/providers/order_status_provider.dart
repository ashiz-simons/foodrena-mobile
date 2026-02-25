class OrderStatusProvider extends ChangeNotifier {
  OrderModel? order;
  Timer? _timer;
  bool isLoading = true;
  bool hasError = false;

  void startPolling(String orderId, String token) {
    _fetch(orderId, token);

    _timer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _fetch(orderId, token),
    );
  }

  Future<void> _fetch(String orderId, String token) async {
    try {
      isLoading = true;
      notifyListeners();

      order = await OrderService.fetchOrder(orderId, token);

      isLoading = false;
      hasError = false;
      notifyListeners();

      if (_shouldStopPolling(order!.status)) {
        stopPolling();
      }
    } catch (_) {
      hasError = true;
      isLoading = false;
      notifyListeners();
    }
  }

  bool _shouldStopPolling(String status) {
    return status == 'delivered' || status == 'cancelled';
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}