import 'package:flutter/material.dart';
import 'package:proyecto_app_delivery_gessof/src/environment/environment.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';

/// Imagen de red o de assets con placeholder consistente.
class AppImage extends StatelessWidget {
  final String? source;
  final BoxFit fit;
  final IconData fallbackIcon;

  const AppImage(
    this.source, {
    super.key,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.fastfood_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: AppColors.primary, size: 34),
    );
    final src = resolveImageSource(source);
    if (src == null) return placeholder;
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : Container(color: AppColors.line),
      );
    }
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    return placeholder;
  }
}

String? resolveImageSource(String? value) {
  final src = value?.trim() ?? '';
  if (src.isEmpty) return null;
  if (src.startsWith('assets/') ||
      src.startsWith('http://') ||
      src.startsWith('https://')) {
    return src;
  }
  if (src.startsWith('/catalog/') || src.startsWith('catalog/')) {
    return Uri.parse(
      Environment.apiUrl,
    ).resolve('/${src.replaceFirst(RegExp(r'^/+'), '')}').toString();
  }
  return null;
}
