import 'dart:async';
import 'dart:js' as js;

Future<Map<String, String>?> openRazorpayWebCheckout(
  Map<String, dynamic> options,
) async {
  final dynamic razorpayCtor = js.context['Razorpay'];
  if (razorpayCtor == null) {
    throw StateError('Razorpay checkout script not loaded');
  }

  final completer = Completer<Map<String, String>?>();

  final handler = (dynamic response) {
    if (completer.isCompleted) return;
    completer.complete({
      'razorpay_order_id': '${response['razorpay_order_id'] ?? ''}',
      'payment_id': '${response['razorpay_payment_id'] ?? ''}',
      'signature': '${response['razorpay_signature'] ?? ''}',
    });
  };

  final dismiss = () {
    if (completer.isCompleted) return;
    completer.complete(null);
  };

  final failed = (dynamic event) {
    if (completer.isCompleted) return;
    final dynamic errorObj = event['error'];
    final dynamic description = errorObj == null ? null : errorObj['description'];
    completer.completeError(
      StateError(description?.toString() ?? 'Payment failed'),
    );
  };

  final checkoutOptions = <String, dynamic>{
    ...options,
    'handler': handler,
    'modal': {
      'ondismiss': dismiss,
    },
  };

  final dynamic razorpayInstance = js.JsObject(
    razorpayCtor,
    [js.JsObject.jsify(checkoutOptions)],
  );

  razorpayInstance.callMethod('on', ['payment.failed', failed]);
  razorpayInstance.callMethod('open');

  return completer.future;
}
