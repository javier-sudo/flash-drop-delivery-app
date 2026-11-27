import 'dart:async';
import 'package:flutter/material.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/pages/client/home/client_shell_controller.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/test_payment.dart';
import 'package:proyecto_app_delivery_gessof/src/utils/format.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderPaymentPage extends StatefulWidget {
  const OrderPaymentPage({
    super.key,
    required this.orderId,
    this.initialUrl,
    this.total,
    this.provider,
    this.autoApproveTestPayment = Environment.autoApproveTestPayments,
  });
  final Object orderId;
  final String? initialUrl;
  final double? total;
  final AppProvider? provider;
  final bool autoApproveTestPayment;
  @override
  State<OrderPaymentPage> createState() => _OrderPaymentPageState();
}

class _OrderPaymentPageState extends State<OrderPaymentPage>
    with WidgetsBindingObserver {
  late final _api =
      widget.provider ??
      (Get.isRegistered<AppProvider>()
          ? Get.find<AppProvider>()
          : AppProvider());
  Map<String, dynamic> _payment = {};
  bool _loading = true;
  bool _busy = false;
  bool _refreshing = false;
  String? _error;
  Timer? _timer;
  final _autoAttempts = <String>{};
  bool _redirected = false;
  String get _status => '${_payment['paymentStatus'] ?? ''}'.toUpperCase();
  String get _orderStatus => '${_payment['orderStatus'] ?? ''}'.toLowerCase();
  bool get _closed =>
      _status == 'APROBADO' ||
      _status == 'EXPIRADO' ||
      _orderStatus.contains('cancelado') ||
      _orderStatus.contains('rechazado');
  Uri? get _url => Uri.tryParse(
    '${_payment['paymentUrl'] ?? (_payment.isEmpty ? widget.initialUrl : '') ?? ''}',
  );
  bool get _testGateway => simulatedPaymentTransaction(_url) != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_closed && !_busy) _load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _startPolling();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      var data = await _api.getPayment(widget.orderId);
      if (!mounted) return;
      final transaction = pendingSimulatedPayment(data);
      if (widget.autoApproveTestPayment &&
          transaction != null &&
          _autoAttempts.add(transaction)) {
        setState(() {
          _payment = data;
          _busy = true;
        });
        await _api.resolveTestPayment(transaction, true);
        if (!mounted) return;
        data = await _api.getPayment(widget.orderId);
      }
      if (!mounted) return;
      setState(() {
        _payment = data;
        _loading = false;
        _error = null;
        if (widget.autoApproveTestPayment &&
            _orderStatus == 'pendiente de pago' &&
            _status == 'PENDIENTE') {
          _error = transaction == null
              ? 'No se pudo validar un pago simulado vigente. Este APK no aprueba cobros reales.'
              : 'El pedido aun no esta confirmado. Puedes reintentar sin crear otro pedido.';
        }
      });
      if (_closed) _timer?.cancel();
      if (widget.autoApproveTestPayment && testOrderIsConfirmed(data)) {
        _showConfirmedOrder();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = widget.autoApproveTestPayment
              ? 'No se pudo confirmar el pedido de prueba. El pedido se conserva; actualiza o reintenta.'
              : 'No se pudo comprobar el pago. El pedido se conserva.';
        });
      }
    } finally {
      _refreshing = false;
      if (mounted && widget.autoApproveTestPayment) {
        setState(() => _busy = false);
      }
    }
  }

  void _showConfirmedOrder() {
    if (_redirected) return;
    _redirected = true;
    _timer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Get.isRegistered<ClientShellController>()) {
        Get.find<ClientShellController>().goTo(ClientTab.orders);
      }
      Get.offNamed('/client/orders/tracking', arguments: widget.orderId);
    });
  }

  Future<void> _retryAutomaticConfirmation() async {
    if (_busy || _refreshing) return;
    // Re-read server state before retrying a request whose response may be lost.
    _autoAttempts.clear();
    await _load();
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo confirmar la operación. Actualiza antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejected = _status == 'RECHAZADO';
    final approved = _status == 'APROBADO';
    final expires = DateTime.tryParse('${_payment['paymentExpiresAt'] ?? ''}');
    final expired =
        _status == 'EXPIRADO' ||
        (expires != null && DateTime.now().isAfter(expires) && !approved);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.autoApproveTestPayment
              ? 'Pedido de prueba'
              : 'Pago del pedido',
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar pago',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Icon(
                  approved ? Icons.check_circle_outline : Icons.credit_card,
                  size: 48,
                  color: approved ? Colors.green.shade700 : null,
                ),
                const SizedBox(height: 16),
                if (widget.total != null)
                  Text(
                    clp(widget.total),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                Text(
                  approved
                      ? 'Pago aprobado'
                      : expired
                      ? 'Pago vencido'
                      : rejected
                      ? 'Pago rechazado'
                      : 'Pendiente de pago',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (_orderStatus.contains('cancelado') ||
                    _orderStatus.contains('rechazado'))
                  Text('Pedido: ${_payment['orderStatus']}'),
                if (expires != null && !approved)
                  Text('Vence: ${expires.toLocal()}'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (!_closed && !expired && !rejected && _testGateway) ...[
                  const Text('Pasarela simulada: no se cobra dinero real.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed:
                        _busy ||
                            (!widget.autoApproveTestPayment && _error != null)
                        ? null
                        : widget.autoApproveTestPayment
                        ? _retryAutomaticConfirmation
                        : () => _action(() async {
                            await _api.resolveTestPayment(
                              _url!.pathSegments.last,
                              true,
                            );
                          }),
                    child: Text(
                      widget.autoApproveTestPayment
                          ? 'Reintentar confirmacion'
                          : 'Aprobar pago de prueba',
                    ),
                  ),
                  if (!widget.autoApproveTestPayment)
                    OutlinedButton(
                      onPressed: _busy || _error != null
                          ? null
                          : () => _action(() async {
                              await _api.resolveTestPayment(
                                _url!.pathSegments.last,
                                false,
                              );
                            }),
                      child: const Text('Rechazar pago de prueba'),
                    ),
                ] else if (!_closed &&
                    !expired &&
                    !rejected &&
                    !widget.autoApproveTestPayment &&
                    _url?.scheme == 'https')
                  FilledButton.icon(
                    onPressed: _busy || _error != null
                        ? null
                        : () => _action(() async {
                            if (!await launchUrl(
                              _url!,
                              mode: LaunchMode.externalApplication,
                            )) {
                              throw StateError('No se pudo abrir la pasarela');
                            }
                          }),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ir a pagar'),
                  ),
                if (rejected && !expired && !_closed)
                  FilledButton.icon(
                    onPressed: _busy || _error != null
                        ? null
                        : () => _action(() async {
                            final retry = await _api.retryPayment(
                              widget.orderId,
                            );
                            if (mounted) {
                              setState(
                                () => _payment = {
                                  ...retry,
                                  'paymentStatus': 'PENDIENTE',
                                },
                              );
                            }
                            _startPolling();
                          }),
                    icon: const Icon(Icons.replay),
                    label: const Text('Reintentar pago'),
                  ),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Get.offNamed(
                    '/client/orders/tracking',
                    arguments: widget.orderId,
                  ),
                  child: const Text('Ver pedido'),
                ),
              ],
            ),
    );
  }
}
