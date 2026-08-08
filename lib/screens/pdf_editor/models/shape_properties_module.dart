part of '../../pdf_editor_screen.dart';

/// نافذة خصائص الشكل المحدَّد (اللون، السماكة، نمط الخط، رأس السهم،
/// التعبئة والشفافية). نُقل من pdf_editor_screen.dart لتقليل حجمها.
mixin ShapePropertiesModule on State<PdfEditorScreen> {
  void _pushUndoState();
  void _scheduleAutoSave({bool markChanged = true});

  // حقول مملوكة فعليًا بـShapeSelectionModule.
  _ShapeAnnotation? get _selectedShape;
  List<_ShapeAnnotation> get _shapeAnnotations;

  Future<void> _editSelectedShapeProperties() async {
    final shape = _selectedShape;
    if (shape == null) return;

    Color borderColor = shape.color;
    double thickness = shape.thickness;
    Color? fillColor = shape.fillColor;
    double fillOpacity = shape.fillOpacity;
    _ShapeLineStyle lineStyle = shape.lineStyle;
    _ArrowHeadStyle arrowHeadStyle = shape.arrowHeadStyle;
    final isLinear =
        shape.kind == _ShapeKind.line || shape.kind == _ShapeKind.arrow;
    final canFill =
        shape.kind == _ShapeKind.rectangle || shape.kind == _ShapeKind.ellipse;

    const palette = <Color>[
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'خصائص الشكل',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  const Text('لون الحدود'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: palette
                        .map(
                          (c) => GestureDetector(
                            onTap: () => setSheetState(() => borderColor = c),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: borderColor == c
                                      ? AppColors.accent
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Text('سماكة الخط'),
                      Expanded(
                        child: Slider(
                          value: thickness.clamp(1.0, 10.0),
                          min: 1,
                          max: 10,
                          divisions: 18,
                          label: thickness.toStringAsFixed(1),
                          onChanged: (v) =>
                              setSheetState(() => thickness = v),
                        ),
                      ),
                    ],
                  ),
                  if (isLinear) ...[
                    const Divider(height: 28),
                    const Text('نمط الخط'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('متصل'),
                          selected: lineStyle == _ShapeLineStyle.solid,
                          onSelected: (_) => setSheetState(
                            () => lineStyle = _ShapeLineStyle.solid,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('متقطع'),
                          selected: lineStyle == _ShapeLineStyle.dashed,
                          onSelected: (_) => setSheetState(
                            () => lineStyle = _ShapeLineStyle.dashed,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('منقّط'),
                          selected: lineStyle == _ShapeLineStyle.dotted,
                          onSelected: (_) => setSheetState(
                            () => lineStyle = _ShapeLineStyle.dotted,
                          ),
                        ),
                      ],
                    ),
                    if (shape.kind == _ShapeKind.arrow) ...[
                      const SizedBox(height: 16),
                      const Text('رأس السهم'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('مفتوح'),
                            selected: arrowHeadStyle == _ArrowHeadStyle.open,
                            onSelected: (_) => setSheetState(
                              () => arrowHeadStyle = _ArrowHeadStyle.open,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('مغلق'),
                            selected: arrowHeadStyle == _ArrowHeadStyle.closed,
                            onSelected: (_) => setSheetState(
                              () => arrowHeadStyle = _ArrowHeadStyle.closed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                  if (canFill) ...[
                    const Divider(height: 28),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تعبئة الشكل'),
                      value: fillColor != null,
                      onChanged: (enabled) => setSheetState(
                        () => fillColor = enabled
                            ? (fillColor ?? borderColor)
                            : null,
                      ),
                    ),
                    if (fillColor != null) ...[
                      const Text('لون التعبئة'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: palette
                            .map(
                              (c) => GestureDetector(
                                onTap: () =>
                                    setSheetState(() => fillColor = c),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: fillColor == c
                                          ? AppColors.accent
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text('الشفافية'),
                          Expanded(
                            child: Slider(
                              value: fillOpacity,
                              min: 0.05,
                              max: 1.0,
                              divisions: 19,
                              label: '${(fillOpacity * 100).round()}%',
                              onChanged: (v) =>
                                  setSheetState(() => fillOpacity = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (applied != true || !mounted || !_shapeAnnotations.contains(shape)) {
      return;
    }

    final changed = shape.color != borderColor ||
        shape.thickness != thickness ||
        shape.fillColor != fillColor ||
        shape.fillOpacity != fillOpacity ||
        shape.lineStyle != lineStyle ||
        shape.arrowHeadStyle != arrowHeadStyle;
    if (!changed) return;

    _pushUndoState();
    setState(() {
      shape.color = borderColor;
      shape.thickness = thickness;
      shape.fillColor = canFill ? fillColor : null;
      shape.fillOpacity = fillOpacity;
      shape.lineStyle = lineStyle;
      shape.arrowHeadStyle = arrowHeadStyle;
    });
    _scheduleAutoSave();
  }

}
