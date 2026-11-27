import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proyecto_app_delivery_gessof/src/providers/app_provider.dart';
import 'package:proyecto_app_delivery_gessof/src/theme/app_theme.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({
    super.key,
    this.orderId,
    this.restaurantId,
    this.provider,
  });
  final int? orderId;
  final int? restaurantId;
  final AppProvider? provider;
  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _RatingDraft {
  int rating = 0;
  final comment = TextEditingController();
}

class _ReviewsPageState extends State<ReviewsPage> {
  late final _api =
      widget.provider ??
      (Get.isRegistered<AppProvider>()
          ? Get.find<AppProvider>()
          : AppProvider());
  final _drafts = <String, _RatingDraft>{};
  Map<String, dynamic> _data = {};
  String? _selectedType;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _needsRefresh = false;
  bool _sent = false;
  int _page = 0;
  int _loadRevision = 0;

  static List<Map<String, dynamic>> _rows(Object? raw) => raw is List
      ? raw
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : [];
  List<Map<String, dynamic>> get _pending => _rows(_data['pending']);
  List<Map<String, dynamic>> get _reviews =>
      _rows(_data[widget.orderId == null ? 'items' : 'completed']);
  _RatingDraft get _draft =>
      _drafts.putIfAbsent(_selectedType!, _RatingDraft.new);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loadRevision++;
    for (final draft in _drafts.values) {
      draft.comment.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    final revision = ++_loadRevision;
    setState(() {
      if (!quiet) _loading = true;
      _error = null;
    });
    try {
      final data = widget.orderId != null
          ? await _api.pendingReviews(widget.orderId!)
          : widget.restaurantId != null
          ? await _api.targetReviews(widget.restaurantId!, page: _page)
          : await _api.myReviews(page: _page);
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _data = data;
        _needsRefresh = false;
        final types = _pending.map((row) => '${row['targetType']}');
        if (!types.contains(_selectedType)) {
          _selectedType = types.isEmpty ? null : types.first;
        }
      });
    } catch (_) {
      if (mounted && revision == _loadRevision) {
        setState(() {
          _needsRefresh = true;
          _error = 'No se pudieron actualizar las calificaciones.';
        });
      }
    } finally {
      if (mounted && revision == _loadRevision) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_sending ||
        _needsRefresh ||
        _selectedType == null ||
        _draft.rating == 0) {
      return;
    }
    final type = _selectedType!;
    final rating = _draft.rating;
    final comment = _draft.comment.text.trim();
    if (comment.characters.length > 500) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await _api.createReview(
        orderId: widget.orderId!,
        targetType: type,
        rating: rating,
        comment: comment,
      );
      if (!mounted) return;
      // A successful POST remains authoritative if the subsequent refresh fails.
      setState(() {
        _sent = true;
        _data = {
          ..._data,
          'pending': _pending
              .where((target) => target['targetType'] != type)
              .toList(),
          'completed': [
            ..._reviews,
            {
              ...result,
              'targetType': type,
              'rating': rating,
              'comment': comment,
            },
          ],
        };
        _selectedType = _pending.isEmpty
            ? null
            : '${_pending.first['targetType']}';
      });
      await _load(quiet: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _needsRefresh = true;
          _error =
              'No pudimos confirmar el envío. Actualiza antes de reintentar; tu comentario sigue aquí.';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _label(String type) => switch (type) {
    'TIENDA' => 'Comercio',
    'REPARTIDOR' => 'Repartidor',
    'CLIENTE' => 'Cliente',
    _ => type,
  };
  IconData _icon(String type) => switch (type) {
    'TIENDA' => Icons.storefront_outlined,
    'REPARTIDOR' => Icons.delivery_dining_outlined,
    _ => Icons.person_outline,
  };
  String _question(String type) => switch (type) {
    'TIENDA' => '¿Cómo estuvo tu pedido?',
    'REPARTIDOR' => '¿Cómo estuvo la entrega?',
    _ => '¿Cómo fue la experiencia?',
  };
  String _ratingLabel(int rating) => switch (rating) {
    1 => 'Muy mala',
    2 => 'Mala',
    3 => 'Regular',
    4 => 'Buena',
    5 => 'Excelente',
    _ => 'Tu valoración',
  };

  Widget _composer() {
    final type = _selectedType!;
    final draft = _draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pending.length > 1) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 320 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18 ||
                  _pending.length > 2) {
                return DropdownButtonFormField<String>(
                  value: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Calificar a'),
                  items: [
                    for (final target in _pending)
                      DropdownMenuItem(
                        value: '${target['targetType']}',
                        child: Text(_label('${target['targetType']}')),
                      ),
                  ],
                  onChanged: _sending
                      ? null
                      : (value) => setState(() => _selectedType = value),
                );
              }
              return SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final target in _pending)
                    ButtonSegment(
                      value: '${target['targetType']}',
                      icon: Icon(_icon('${target['targetType']}')),
                      label: Text(_label('${target['targetType']}')),
                    ),
                ],
                selected: {type},
                onSelectionChanged: _sending
                    ? null
                    : (values) => setState(() => _selectedType = values.first),
              );
            },
          ),
          const SizedBox(height: 28),
        ],
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F3F5),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon(type), size: 36, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _question(type),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${_label(type)} · Pedido FD-${widget.orderId}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 1; i <= 5; i++)
                    SizedBox(
                      width: constraints.maxWidth / 5,
                      height: 60,
                      child: Semantics(
                        selected: i <= draft.rating,
                        child: IconButton(
                          tooltip: '$i estrellas',
                          padding: EdgeInsets.zero,
                          onPressed: _sending
                              ? null
                              : () => setState(() => draft.rating = i),
                          iconSize: 42,
                          icon: Icon(
                            i <= draft.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i <= draft.rating
                                ? AppColors.primary
                                : const Color(0xFFB7BBC1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Center(
            child: Text(
              _ratingLabel(draft.rating),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '¿Quieres agregar algo?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextField(
          key: ValueKey('review-comment-$type'),
          controller: draft.comment,
          enabled: !_sending,
          maxLength: 500,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Cuéntanos cómo fue tu experiencia (opcional)',
            filled: true,
            fillColor: const Color(0xFFF6F7F8),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE7E9EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewTile(Map<String, dynamic> review) {
    final rating = int.tryParse('${review['rating']}') ?? 0;
    final comment = '${review['comment'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _icon('${review['targetType']}'),
                size: 22,
                color: AppColors.ink,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _label('${review['targetType']}'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '$rating/5',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 24,
                  color: i <= rating
                      ? AppColors.primary
                      : const Color(0xFFB7BBC1),
                ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(comment, style: const TextStyle(fontSize: 15, height: 1.5)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasComposer =
        widget.orderId != null && _selectedType != null && _pending.isNotEmpty;
    final aggregate = _data['aggregate'];
    final count = aggregate is Map ? aggregate['count'] : null;
    final average = aggregate is Map
        ? double.tryParse('${aggregate['average']}')
        : null;
    final canSend =
        hasComposer &&
        !_loading &&
        !_sending &&
        !_needsRefresh &&
        _draft.rating > 0;
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(hasComposer ? 'Calificar pedido' : 'Calificaciones'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: 'Actualizar calificaciones',
              onPressed: _sending || _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: !hasComposer || _loading
            ? null
            : Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: canSend ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE8EAED),
                        disabledForegroundColor: AppColors.muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Enviar calificación',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        height: 1.4,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _sending ? null : () => _load(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (hasComposer) _composer(),
                  if (!hasComposer &&
                      widget.orderId != null &&
                      _reviews.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _sent
                          ? 'Gracias por calificar'
                          : 'Tu opinión ya está guardada',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Pedido FD-${widget.orderId}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 28),
                  ],
                  if (!hasComposer && widget.orderId == null) ...[
                    Text(
                      widget.restaurantId == null
                          ? 'Tus calificaciones'
                          : 'Opiniones del comercio',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (average != null && average.isFinite && count != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          average.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            '$count calificaciones',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (hasComposer && _reviews.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Ya calificaste',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final review in _reviews) _reviewTile(review),
                  if (_pending.isEmpty &&
                      _reviews.isEmpty &&
                      _error == null) ...[
                    const SizedBox(height: 56),
                    const Icon(
                      Icons.reviews_outlined,
                      size: 52,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Aún no hay calificaciones',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (widget.orderId == null && _reviews.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Página anterior',
                          onPressed: _page == 0 || _loading
                              ? null
                              : () {
                                  _page--;
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Página ${_page + 1}'),
                        IconButton(
                          tooltip: 'Página siguiente',
                          onPressed:
                              _page + 1 >=
                                      (int.tryParse('${_data['totalPages']}') ??
                                          1) ||
                                  _loading
                              ? null
                              : () {
                                  _page++;
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
