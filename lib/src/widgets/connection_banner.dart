import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/services/connection_service.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
      child: Obx(() {
        final offline = ConnectionService.instance.isOffline.value;
        return IgnorePointer(
          ignoring: true,
          child: SafeArea(
            child: AnimatedSlide(
              offset: offline ? Offset.zero : const Offset(0, -1.4),
              duration: const Duration(milliseconds: 220),
              child: AnimatedOpacity(
                opacity: offline ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20252B),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 12),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_off_outlined, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sin conexión. Reintentando...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
