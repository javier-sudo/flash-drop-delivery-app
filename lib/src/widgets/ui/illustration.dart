import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';

/// Ilustraciones de estados vacíos y de error (assets/illustrations/states).
enum AppIllustration {
  emptyCart('empty_cart'),
  emptyOrders('empty_orders'),
  emptyAddress('empty_address'),
  searchEmpty('search_empty'),
  locationPermission('location_permission'),
  noConnection('no_connection'),
  error('error');

  final String file;
  const AppIllustration(this.file);

  /// Los estados son SVG; el de error es PNG.
  String get asset =>
      'assets/illustrations/states/$file.${this == error ? 'png' : 'svg'}';
}

/// Pines del mapa (assets/illustrations/markers).
enum MapPinKind {
  rider('rider'),
  store('store'),
  home('home');

  final String file;
  const MapPinKind(this.file);

  String get asset => 'assets/illustrations/markers/$file.png';
}

/// Íconos de etiqueta de dirección (assets/illustrations/address).
enum AddressIcon {
  home('home'),
  work('work'),
  other('other');

  final String file;
  const AddressIcon(this.file);

  String get asset => 'assets/illustrations/address/$file.png';
}

/// Pin del mapa. La imagen mide 256x276 con la punta abajo al centro, así que el
/// Marker debe usar `alignment: Alignment.topCenter`.
class MapPin extends StatelessWidget {
  final MapPinKind kind;
  final double size;

  const MapPin(this.kind, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kind.asset,
      width: size,
      height: size * 1.08,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
      semanticLabel: switch (kind) {
        MapPinKind.rider => 'Repartidor',
        MapPinKind.store => 'Local',
        MapPinKind.home => 'Entrega',
      },
    );
  }
}

/// Ilustración + título + mensaje + acción opcional, centrados.
class IllustratedMessage extends StatelessWidget {
  final AppIllustration illustration;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double size;
  final Color? titleColor;
  final Color? messageColor;

  const IllustratedMessage({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.size = 170,
    this.titleColor,
    this.messageColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration.asset.endsWith('.png'))
              Image.asset(
                illustration.asset,
                width: size,
                height: size * 200 / 240,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              )
            else
              SvgPicture.asset(
                illustration.asset,
                width: size,
                height: size * 200 / 240,
                excludeFromSemantics: true,
              ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: titleColor ?? AppColors.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: messageColor ?? AppColors.muted,
                  height: 1.35,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ícono de una dirección guardada según su etiqueta (Casa, Trabajo u otra).
class AddressLabelIcon extends StatelessWidget {
  final String label;
  final double size;
  final Color color;

  const AddressLabelIcon(
    this.label, {
    super.key,
    this.size = 15,
    this.color = AppColors.ink,
  });

  static AddressIcon kindOf(String label) =>
      switch (label.trim().toLowerCase()) {
        'casa' => AddressIcon.home,
        'trabajo' => AddressIcon.work,
        _ => AddressIcon.other,
      };

  @override
  Widget build(BuildContext context) {
    // Silueta de un solo color: se tiñe con el color recibido.
    return Image.asset(
      kindOf(label).asset,
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}

/// Imagen de cada paso del pedido: Recibido, Preparando, Listo, En camino y
/// Entregado (mismo orden que `OrderStage`).
enum OrderStepArt {
  received('received'),
  preparing('preparing'),
  ready('ready'),
  onTheWay('on_the_way'),
  delivered('delivered');

  final String file;
  const OrderStepArt(this.file);

  String get asset => 'assets/img/steps/$file.png';

  /// Paso 0..4 del seguimiento; fuera de rango usa el más cercano.
  static OrderStepArt of(int step) => values[step.clamp(0, values.length - 1)];
}

/// Imagen de un paso. Los pasos pendientes se muestran en gris y tenues.
class OrderStepImage extends StatelessWidget {
  final int step;
  final double size;
  final bool pending;

  const OrderStepImage({
    super.key,
    required this.step,
    this.size = 28,
    this.pending = false,
  });

  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      OrderStepArt.of(step).asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
    if (!pending) return image;
    return Opacity(
      opacity: 0.4,
      child: ColorFiltered(colorFilter: _grayscale, child: image),
    );
  }
}
