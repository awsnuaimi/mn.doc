import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../theme/app_theme.dart';
import '../services/app_settings.dart';
import '../services/app_text.dart';
import '../services/isolate_helpers.dart';
import '../services/arabic_font_loader.dart';
import 'summarize_screen.dart';
import 'ai_chat_screen.dart';
import 'translate_screen.dart';
import 'tts_reader_screen.dart';
import 'manage_pages_screen.dart';
import 'pdf_editor/controllers/editor_state.dart';
import 'pdf_editor/widgets/editor_toolbar.dart';
import 'pdf_editor/widgets/floating_toolbar.dart';
import 'pdf_editor/widgets/top_toolbar.dart';
import 'pdf_editor/widgets/pdf_viewer_widget.dart';

part 'pdf_editor/models/text_annotation.dart';
part 'pdf_editor/models/image_annotation.dart';
part 'pdf_editor/models/search_module.dart';
part 'pdf_editor/models/drawing_module.dart';
part 'pdf_editor/models/save_module.dart';
part 'pdf_editor/models/text_module.dart';
part 'pdf_editor/models/image_module.dart';
part 'pdf_editor/models/shape_selection_module.dart';
part 'pdf_editor/models/shape_drawing_module.dart';
part 'pdf_editor/models/shape_multiselect_module.dart';
part 'pdf_editor/models/shape_layout_module.dart';
part 'pdf_editor/models/shape_properties_module.dart';
part 'pdf_editor/models/ai_module.dart';
part 'pdf_editor/models/form_module.dart';
part 'pdf_editor/models/gesture_module.dart';
part 'pdf_editor/models/shape_annotation.dart';
part 'pdf_editor/models/drawing_stroke.dart';
part 'pdf_editor/models/editor_snapshot.dart';
part 'pdf_editor/controllers/editor_history.dart';
part 'pdf_editor/geometry/pdf_page_transform.dart';
part 'pdf_editor/geometry/shape_geometry.dart';
part 'pdf_editor/geometry/shape_snap_geometry.dart';
part 'pdf_editor/geometry/shape_layout_geometry.dart';
part 'pdf_editor/geometry/shape_transform_geometry.dart';
part 'pdf_editor/painters/snap_guide_painter.dart';
part 'pdf_editor/painters/shape_painter.dart';
part 'pdf_editor/painters/drawing_painter.dart';

class PdfEditorScreen extends StatefulWidget {
  final String filePath;
  const PdfEditorScreen({super.key, required this.filePath});

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> with SearchModule, DrawingModule, SaveModule, TextModule, ImageModule, ShapeSelectionModule, ShapeDrawingModule, ShapeMultiselectModule, ShapeLayoutModule, ShapePropertiesModule, AiModule, FormModule, GestureModule {
  late final EditorState editorState;
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerStateKey = GlobalKey();
  final List<_DrawingStroke> _drawingStrokes = [];
  bool _eraserGestureChanged = false;

  bool _disposed = false; // نمنع أي حفظ أو setState بعد التخلص من الشاشة
  late final bool _fileExists; // يُفحص مرة واحدة عند فتح الشاشة — يحمي من انهيار البناء لو الملف المُختار (خصوصًا من مدير ملفات خارجي) غير موجود فعليًا على القرص

  // ------- تراجع/إعادة موحّد وقابل للتوسعة لكل عناصر المحرر -------
  final _EditorHistory _history = _EditorHistory(limit: 20);

  @override
  void initState() {
    super.initState();
    editorState = EditorState();
    // نتحقق من قابلية القراءة الفعلية وليس فقط من وجود الملف: بعض المسارات
    // القادمة من مدير ملفات خارجي (عبر Storage Access Framework) قد تكون
    // "موجودة" حسب stat لكن ترمي استثناء لحظة القراءة الفعلية (نسخ غير
    // مكتمل، صلاحيات، أو مسار افتراضي لا يدعمه dart:io File).
    try {
      final file = File(widget.filePath);
      _fileExists = file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      _fileExists = false;
    }
  }

  _EditorSnapshot _captureEditorState() => _EditorSnapshot.capture(
        _annotations,
        _imageAnnotations,
        _drawingStrokes,
        _shapeAnnotations,
      );

  void _restoreEditorState(_EditorSnapshot snapshot) {
    _annotations
      ..clear()
      ..addAll(snapshot.textAnnotations.map((a) => a.copy()));
    _imageAnnotations
      ..clear()
      ..addAll(snapshot.imageAnnotations.map((a) => a.copy()));
    _drawingStrokes
      ..clear()
      ..addAll(snapshot.drawingStrokes.map((s) => s.copy()));
    _shapeAnnotations
      ..clear()
      ..addAll(snapshot.shapeAnnotations.map((s) => s.copy()));
    _activeDrawingStroke = null;
    _activeShape = null;
    _selectedShape = null;
    _selectedShapes.clear();
  }

  void _pushUndoState() {
    _history.record(_captureEditorState());
    if (mounted) setState(() {});
  }

  void _undo() {
    final previous = _history.undo(_captureEditorState());
    if (previous == null) return;
    setState(() => _restoreEditorState(previous));
    _scheduleAutoSave();
  }

  void _redo() {
    final next = _history.redo(_captureEditorState());
    if (next == null) return;
    setState(() => _restoreEditorState(next));
    _scheduleAutoSave();
  }

  void _zoomIn() {
    editorState.setZoom((editorState.zoomLevel + 0.25).clamp(1.0, 3.0));
    _controller.zoomLevel = editorState.zoomLevel;
  }

  void _zoomOut() {
    editorState.setZoom((editorState.zoomLevel - 0.25).clamp(1.0, 3.0));
    _controller.zoomLevel = editorState.zoomLevel;
  }

  void _resetZoom() {
    editorState.setZoom(1.0);
    _controller.zoomLevel = 1.0;
  }

  void _toggleDrawMode() {
    setState(() {
      editorState.drawMode = !editorState.drawMode;
      editorState.eraserMode = false;
      _shapeMode = null;
      editorState.shapeEditMode = false;
      _selectedShape = null;
      editorState.addTextMode = false;
      editorState.addImageMode = false;
      _pendingImageBytes = null;
      _controller.annotationMode = PdfAnnotationMode.none;
    });
  }

  void _toggleEraserMode() {
    setState(() {
      editorState.eraserMode = !editorState.eraserMode;
      editorState.drawMode = false;
      _shapeMode = null;
      editorState.shapeEditMode = false;
      _selectedShape = null;
      _activeDrawingStroke = null;
      editorState.addTextMode = false;
      editorState.addImageMode = false;
      _pendingImageBytes = null;
      _controller.annotationMode = PdfAnnotationMode.none;
    });
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared <= 0.0001) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared)
        .clamp(0.0, 1.0)
        .toDouble();
    final closest = a + ab * t;
    return (p - closest).distance;
  }

  bool _strokeHitTest(_DrawingStroke stroke, Offset pdfPoint) {
    if (stroke.points.isEmpty) return false;
    final tolerance = 10.0 / editorState.zoomLevel + stroke.thickness / 2;
    if (stroke.points.length == 1) {
      return (stroke.points.first - pdfPoint).distance <= tolerance;
    }
    for (var i = 1; i < stroke.points.length; i++) {
      if (_distanceToSegment(
            pdfPoint,
            stroke.points[i - 1],
            stroke.points[i],
          ) <=
          tolerance) {
        return true;
      }
    }
    return false;
  }

  void _eraseAt(PointerEvent event) {
    if (!editorState.eraserMode) return;
    final pdfPoint = _eventToPdfPoint(event, editorState.currentPage);
    if (pdfPoint == null) return;

    final hits = _drawingStrokes
        .where(
          (stroke) =>
              stroke.pageNumber == editorState.currentPage &&
              _strokeHitTest(stroke, pdfPoint),
        )
        .toList(growable: false);
    if (hits.isEmpty) return;

    if (!_eraserGestureChanged) {
      _pushUndoState();
      _eraserGestureChanged = true;
    }
    setState(() => _drawingStrokes.removeWhere(hits.contains));
  }

  void _onEraserPointerDown(PointerDownEvent event) {
    _eraserGestureChanged = false;
    _eraseAt(event);
  }

  void _onEraserPointerMove(PointerMoveEvent event) {
    _eraseAt(event);
  }

  void _finishEraserGesture() {
    if (_eraserGestureChanged) {
      _scheduleAutoSave();
    }
    _eraserGestureChanged = false;
  }

  @override
  void dispose() {
    _disposed = true;
    editorState.dispose();
    _controller.dispose();
    _searchController.dispose();
    _searchResult.removeListener(_onSearchResultChanged);
    _searchDebounce?.cancel();
    _autoSaveDebounce?.cancel();
    _moveHoldTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPdfPageSizes() async {
    sf.PdfDocument? document;
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      document = sf.PdfDocument(inputBytes: bytes);
      final sizes = <int, Size>{};
      for (var i = 0; i < document.pages.count; i++) {
        sizes[i + 1] = document.pages[i].getClientSize();
      }
      if (_disposed || !mounted) return;
      setState(() {
        _pdfPageSizes
          ..clear()
          ..addAll(sizes);
        _pageTransforms.clear();
      });
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('تعذر قراءة أبعاد صفحات PDF: $e');
        debugPrintStack(stackTrace: stack);
      }
    } finally {
      document?.dispose();
    }
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    unawaited(_loadPdfPageSizes());
    _handleFormFieldsDetected(_controller.getFormFields().length);
  }

  void _setAnnotationMode(PdfAnnotationMode mode) {
    setState(() {
      _controller.annotationMode =
          _controller.annotationMode == mode ? PdfAnnotationMode.none : mode;
    });
  }


  Widget build(BuildContext context) {
    // EditorState لم يكن مُقدَّمًا (Provided) لأي مكان بالشجرة من قبل —
    // context.watch<EditorState>() يحتاج Provider أب فعلي، لا يكفي أن
    // يكون editorState مجرد حقل عادي بالـState. نلفّ هون بـ
    // ChangeNotifierProvider.value ثم نستخدم Builder للحصول على
    // BuildContext جديد تحت الـProvider مباشرة (سياق الدالة الأصلي
    // "context" هو الأب، ولا يصلح للبحث عن Provider نُدرجه بنفس الشجرة).
    return ChangeNotifierProvider<EditorState>.value(
      value: editorState,
      child: Builder(
        builder: (context) {
    final editor = context.watch<EditorState>();

    final hasSearchResult = _searchResult.hasResult;
    final settings = context.watch<AppSettingsController>();
    final lang = settings.languageCode;
    String tr(String key) => AppText.t(key, lang);

    // الملف اختير من مدير ملفات خارجي وقد يكون المسار المُعاد غير موجود
    // فعليًا (مسار مؤقت لم يكتمل نسخه، أو رابط لا يدعمه dart:io File).
    // بدون هذا الفحص، بناء SfPdfViewer.file على ملف غير موجود يرمي
    // استثناءً أثناء الـ build فيلتقطه ErrorWidget.builder ويعرض شاشة
    // "حدث خطأ غير متوقع" العامة بدل رسالة واضحة للمستخدم.
    if (!_fileExists) {
      return Directionality(
        textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.filePath.split('/').last, overflow: TextOverflow.ellipsis),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    tr('ed_file_not_found'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('ed_file_not_found_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr('cancel')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: settings.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: PopScope(
        canPop: !editor.hasUnsavedChanges,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tr('unsaved_title')),
              content: Text(tr('unsaved_body')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(tr('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(tr('discard_exit')),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, null),
                  icon: const Icon(Icons.save_rounded),
                  label: Text(tr('save')),
                ),
              ],
            ),
          );
          if (!context.mounted) return;

          if (shouldDiscard == true) {
            // خروج صريح بدون حفظ.
            _autoSaveDebounce?.cancel();
            editor.hasUnsavedChanges = false;
            Navigator.pop(context);
            return;
          }

          if (shouldDiscard == null) {
            // زر "حفظ": لا نخرج إلا بعد تثبيت أحدث Revision فعليًا.
            final saved = await _flushLatestRevisionForStructuralOperation();
            if (!context.mounted) return;

            if (saved && !editor.hasUnsavedChanges) {
              Navigator.pop(context);
            } else {
              final lang = Provider.of<AppSettingsController>(
                context,
                listen: false,
              ).languageCode;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppText.t('ed_save_error_prefix', lang)),
                ),
              );
            }
          }
        },
        child: Scaffold(
      // نمنع تغيّر حجم الشاشة عند ظهور لوحة المفاتيح — هذا يضمن بقاء
      // موضع النصوص المضافة مستقرًا بصريًا حتى أثناء فتح نافذة التعديل.
      resizeToAvoidBottomInset: false,
      appBar: TopToolbar(
        title: widget.filePath.split('/').last,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: tr('undo'),
            onPressed: !_history.canUndo ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: tr('redo'),
            onPressed: !_history.canRedo ? null : _redo,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: tr('ed_search_tooltip'),
            onPressed: editor.toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: tr('ed_bookmarks_tooltip'),
            onPressed: () => _pdfViewerStateKey.currentState?.openBookmarkView(),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'إدارة الصفحات بالصور المصغرة',
            onPressed: editor.saving ? null : _openPageManager,
          ),
          IconButton(
            icon: Icon(editorState.addTextMode ? Icons.text_fields_rounded : Icons.text_fields_outlined),
            tooltip: tr('ed_addtext_tooltip'),
            onPressed: () => setState(() { editorState.addTextMode = !editorState.addTextMode; if (editorState.addTextMode) { editorState.addImageMode = false; _pendingImageBytes = null; } }),
          ),
          IconButton(
            icon: Icon(editorState.addImageMode ? Icons.image_rounded : Icons.add_photo_alternate_outlined),
            tooltip: 'إضافة صورة إلى PDF',
            onPressed: _pickImageForPdf,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.smart_toy_rounded),
            tooltip: tr('ed_ai_tooltip'),
            onSelected: _openAiFeature,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'summarize', child: Text(tr('ed_ai_summarize'))),
              PopupMenuItem(value: 'chat', child: Text(tr('ed_ai_chat'))),
              PopupMenuItem(value: 'translate', child: Text(tr('ed_ai_translate'))),
              PopupMenuItem(value: 'read_aloud', child: Text(tr('tool_tts_t'))),
            ],
          ),
          editor.saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: Badge(
                    isLabelVisible: editor.hasUnsavedChanges,
                    smallSize: 8,
                    backgroundColor: Colors.orangeAccent,
                    child: const Icon(Icons.save_rounded),
                  ),
                  tooltip: tr('save'),
                  onPressed: _saveDocument,
                ),
        ],
),
      body: Column(
        children: [
          if (editor.searchVisible)
            Container(
              color: AppColors.primaryDark.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: tr('ed_search_hint'),
                        isDense: true,
                      ),
                      onSubmitted: _search,
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  if (hasSearchResult) ...[
                    Text('${_searchResult.currentInstanceIndex}/${_searchResult.totalInstanceCount}',
                        style: const TextStyle(fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      onPressed: () => _searchResult.previousInstance(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: () => _searchResult.nextInstance(),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _closeSearch,
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _annotationChip(
                    icon: Icons.border_color_rounded,
                    label: tr('ed_highlight'),
                    mode: PdfAnnotationMode.highlight,
                  ),
                  _annotationChip(
                    icon: Icons.format_underlined_rounded,
                    label: tr('ed_underline'),
                    mode: PdfAnnotationMode.underline,
                  ),
                  _annotationChip(
                    icon: Icons.strikethrough_s_rounded,
                    label: tr('ed_strikethrough'),
                    mode: PdfAnnotationMode.strikethrough,
                  ),
                  _annotationChip(
                    icon: Icons.sticky_note_2_rounded,
                    label: tr('ed_stickynote'),
                    mode: PdfAnnotationMode.stickyNote,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      avatar: Icon(
                        Icons.draw_rounded,
                        size: 18,
                        color: editorState.drawMode ? Colors.white : AppColors.primaryDark,
                      ),
                      label: const Text('قلم'),
                      selected: editorState.drawMode,
                      selectedColor: AppColors.primaryDark,
                      labelStyle: TextStyle(
                        color: editorState.drawMode
                            ? Colors.white
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : AppColors.textDark),
                        fontSize: 12,
                      ),
                      onSelected: (_) => _toggleDrawMode(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      avatar: Icon(
                        Icons.auto_fix_off_rounded,
                        size: 18,
                        color: editorState.eraserMode
                            ? Colors.white
                            : AppColors.primaryDark,
                      ),
                      label: const Text('ممحاة'),
                      selected: editorState.eraserMode,
                      selectedColor: AppColors.primaryDark,
                      labelStyle: TextStyle(
                        color: editorState.eraserMode
                            ? Colors.white
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : AppColors.textDark),
                        fontSize: 12,
                      ),
                      onSelected: (_) => _toggleEraserMode(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      avatar: Icon(
                        Icons.open_with_rounded,
                        size: 18,
                        color: editorState.shapeEditMode
                            ? Colors.white
                            : AppColors.primaryDark,
                      ),
                      label: const Text('تعديل'),
                      selected: editorState.shapeEditMode,
                      selectedColor: AppColors.primaryDark,
                      labelStyle: TextStyle(
                        color: editorState.shapeEditMode
                            ? Colors.white
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : AppColors.textDark),
                        fontSize: 12,
                      ),
                      onSelected: (_) => _toggleShapeEditMode(),
                    ),
                  ),
                  if (editorState.shapeEditMode && !_multiSelectMode && _shapeClipboard != null)
                    IconButton(
                      icon: const Icon(Icons.content_paste_rounded),
                      tooltip: 'لصق الشكل',
                      onPressed: _pasteShape,
                    ),
                  if (editorState.shapeEditMode && !_multiSelectMode && _selectedShape != null) ...[
                    IconButton(icon: const Icon(Icons.copy_rounded), tooltip: 'نسخ الشكل', onPressed: _copySelectedShape),
                    IconButton(icon: const Icon(Icons.control_point_duplicate_rounded), tooltip: 'تكرار الشكل', onPressed: _duplicateSelectedShape),
                    IconButton(icon: const Icon(Icons.flip_to_front_rounded), tooltip: 'إحضار للأمام', onPressed: _bringSelectedShapeForward),
                    IconButton(icon: const Icon(Icons.flip_to_back_rounded), tooltip: 'إرسال للخلف', onPressed: _sendSelectedShapeBackward),
                    IconButton(icon: const Icon(Icons.palette_outlined), tooltip: 'خصائص الشكل', onPressed: _editSelectedShapeProperties),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded), tooltip: 'حذف الشكل المحدد', onPressed: _deleteSelectedShape),
                  ],
                  if (editorState.shapeEditMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        avatar: Icon(
                          Icons.select_all_rounded,
                          size: 18,
                          color: _multiSelectMode
                              ? Colors.white
                              : AppColors.primaryDark,
                        ),
                        label: const Text('متعدد'),
                        selected: _multiSelectMode,
                        selectedColor: AppColors.primaryDark,
                        onSelected: (_) => _toggleMultiSelectMode(),
                      ),
                    ),
                  if (editorState.shapeEditMode && _multiSelectMode) ...[
                    IconButton(
                      icon: const Icon(Icons.done_all_rounded),
                      tooltip: 'تحديد كل أشكال الصفحة',
                      onPressed: _selectAllShapesOnCurrentPage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded),
                      tooltip: 'عكس تحديد أشكال الصفحة',
                      onPressed: _invertShapeSelectionOnCurrentPage,
                    ),
                    if (_selectedShapes.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.deselect_rounded),
                        tooltip: 'إلغاء التحديد',
                        onPressed: _clearShapeMultiSelection,
                      ),
                  ],
                  if (editorState.shapeEditMode && _multiSelectMode && _shapeClipboardGroup.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.content_paste_rounded),
                      tooltip: 'لصق المجموعة',
                      onPressed: _pasteShapeGroup,
                    ),
                  if (editorState.shapeEditMode && _multiSelectMode && _selectedShapes.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.copy_all_rounded),
                      tooltip: 'نسخ المجموعة',
                      onPressed: _copySelectedShapes,
                    ),
                    IconButton(
                      icon: const Icon(Icons.control_point_duplicate_rounded),
                      tooltip: 'تكرار المجموعة',
                      onPressed: _duplicateSelectedShapes,
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_to_front_rounded),
                      tooltip: 'إحضار المجموعة للأمام',
                      onPressed: _bringSelectedShapesForward,
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_to_back_rounded),
                      tooltip: 'إرسال المجموعة للخلف',
                      onPressed: _sendSelectedShapesBackward,
                    ),
                    IconButton(
                      icon: const Icon(Icons.vertical_align_top_rounded),
                      tooltip: 'إحضار المجموعة إلى المقدمة',
                      onPressed: _bringSelectedShapesToFront,
                    ),
                    IconButton(
                      icon: const Icon(Icons.vertical_align_bottom_rounded),
                      tooltip: 'إرسال المجموعة إلى الخلف تمامًا',
                      onPressed: _sendSelectedShapesToBack,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined),
                      tooltip: 'حذف المجموعة',
                      onPressed: _deleteSelectedShapes,
                    ),
                    IconButton(
                      icon: const Icon(Icons.vertical_align_center_rounded),
                      tooltip: 'توسيط المجموعة أفقيًا في الصفحة',
                      onPressed: () => _centerSelectedShapesOnPage(horizontal: true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.horizontal_rule_rounded),
                      tooltip: 'توسيط المجموعة عموديًا في الصفحة',
                      onPressed: () => _centerSelectedShapesOnPage(horizontal: false),
                    ),
                    if (_selectedShapes.length >= 2) ...[
                      IconButton(icon: const Icon(Icons.align_horizontal_left_rounded), tooltip: 'محاذاة لليسار', onPressed: () => _alignSelectedShapes('left')),
                      IconButton(icon: const Icon(Icons.align_horizontal_center_rounded), tooltip: 'توسيط أفقي', onPressed: () => _alignSelectedShapes('centerH')),
                      IconButton(icon: const Icon(Icons.align_horizontal_right_rounded), tooltip: 'محاذاة لليمين', onPressed: () => _alignSelectedShapes('right')),
                      IconButton(icon: const Icon(Icons.align_vertical_top_rounded), tooltip: 'محاذاة للأعلى', onPressed: () => _alignSelectedShapes('top')),
                      IconButton(icon: const Icon(Icons.align_vertical_center_rounded), tooltip: 'توسيط عمودي', onPressed: () => _alignSelectedShapes('centerV')),
                      IconButton(icon: const Icon(Icons.align_vertical_bottom_rounded), tooltip: 'محاذاة للأسفل', onPressed: () => _alignSelectedShapes('bottom')),
                    ],
                    if (_selectedShapes.length >= 3) ...[
                      IconButton(icon: const Icon(Icons.space_bar_rounded), tooltip: 'توزيع أفقي', onPressed: () => _distributeSelectedShapes(true)),
                      IconButton(icon: const Icon(Icons.vertical_distribute_rounded), tooltip: 'توزيع عمودي', onPressed: () => _distributeSelectedShapes(false)),
                      IconButton(icon: const Icon(Icons.format_align_justify_rounded), tooltip: 'مسافات أفقية متساوية', onPressed: () => _distributeSelectedShapesByGap(true)),
                      IconButton(icon: const Icon(Icons.density_medium_rounded), tooltip: 'مسافات عمودية متساوية', onPressed: () => _distributeSelectedShapesByGap(false)),
                    ],
                  ],
                  _shapeToolChip(
                    icon: Icons.horizontal_rule_rounded,
                    label: 'خط',
                    kind: _ShapeKind.line,
                  ),
                  _shapeToolChip(
                    icon: Icons.arrow_forward_rounded,
                    label: 'سهم',
                    kind: _ShapeKind.arrow,
                  ),
                  _shapeToolChip(
                    icon: Icons.rectangle_outlined,
                    label: 'مستطيل',
                    kind: _ShapeKind.rectangle,
                  ),
                  _shapeToolChip(
                    icon: Icons.circle_outlined,
                    label: 'دائرة',
                    kind: _ShapeKind.ellipse,
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: 'إعدادات القلم',
                    onPressed: _showDrawSettings,
                  ),
                ],
              ),
            ),
          ),
          if (_hasFormFields)
            Container(
              width: double.infinity,
              color: Colors.green.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.fact_check_rounded, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tr('ed_form_banner'), style: const TextStyle(fontSize: 12)),
                  ),
                  Text(tr('ed_form_flatten'), style: const TextStyle(fontSize: 11)),
                  Switch(
                    value: _flattenFormsOnSave,
                    onChanged: (v) => setState(() => _flattenFormsOnSave = v),
                  ),
                ],
              ),
            ),
          if (editorState.shapeEditMode)
            Container(
              width: double.infinity,
              color: Colors.blue.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              child: const Row(
                children: [
                  Icon(Icons.open_with_rounded, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تعديل الأشكال — اضغط لتحديد، اسحب للتحريك، واسحب المقابض لتغيير الحجم',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (_shapeMode != null)
            Container(
              width: double.infinity,
              color: _drawColor.withOpacity(0.10),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.category_outlined, size: 18, color: _drawColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'وضع الأشكال — اسحب على الصفحة لرسم الشكل',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${_drawThickness.toStringAsFixed(1)} pt',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          if (editorState.eraserMode)
            Container(
              width: double.infinity,
              color: Colors.orange.withOpacity(0.10),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              child: const Row(
                children: [
                  Icon(Icons.auto_fix_off_rounded,
                      size: 18, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'وضع الممحاة — مرّر إصبعك فوق أي خط لحذفه',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (editorState.drawMode)
            Container(
              width: double.infinity,
              color: _drawColor.withOpacity(0.10),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.draw_rounded, size: 18, color: _drawColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'وضع الرسم الحر — ارسم بإصبعك على الصفحة',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${_drawThickness.toStringAsFixed(1)} pt',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          if (editorState.addTextMode)
            Container(
              width: double.infinity,
              color: AppColors.accent.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr('ed_addtext_banner'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (_movingAnnotation != null)
            Container(
              width: double.infinity,
              color: AppColors.primaryDark.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'اسحب النص بإصبعك إلى المكان المطلوب',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelTextMove,
                    child: Text(tr('cancel'), style: const TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: _confirmTextMove,
                    child: Text(
                      tr('ed_nudge_done'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PdfViewerWidget(
              key: _viewerKey,
              children: [
                SfPdfViewer.file(
                  File(widget.filePath),
                  key: _pdfViewerStateKey,
                  controller: _controller,
                  // عرض صفحة واحدة في كل مرة لضمان دقة وضع النصوص المضافة
                  pageLayoutMode: PdfPageLayoutMode.single,
                  onPageChanged: (details) {
                    if (!mounted) return;
                    editor.setCurrentPage(details.newPageNumber);
                  },
                  onZoomLevelChanged: (details) {
                    if (!mounted) return;
                    editor.setZoom(details.newZoomLevel);
                    setState(() {
                      // أي تغيير Zoom يغيّر إسقاط الصفحة على الشاشة، لذلك
                      // نبطل أي معايرة قديمة. fallback يعيد حساب Scale/Origin
                      // من zoomLevel + scrollOffset حتى أثناء التكبير.
                      _pageTransforms.clear();
                    });
                  },
                  onDocumentLoaded: _onDocumentLoaded,
                  onTap: _handlePdfTap,
                  // تعليقات Syncfusion المدمجة (تظليل/تسطير/شطب/ملاحظة لاصقة)
                  // وتعبئة حقول النماذج لا تمر بكودنا الخاص إطلاقًا — بدون
                  // هذه الاستدعاءات، أي تعديل منها ما كان رح يُحفَظ تلقائيًا.
                  onAnnotationAdded: (_) => _scheduleAutoSave(),
                  onAnnotationEdited: (_) => _scheduleAutoSave(),
                  onAnnotationRemoved: (_) => _scheduleAutoSave(),
                  onFormFieldValueChanged: (_) => _scheduleAutoSave(),
                ),
                  // طبقة عرض النصوص المضافة على الصفحة الحالية فقط
                  ..._annotations
                      .where((a) => a.pageNumber == editor.currentPage)
                      .map((ann) => _buildAnnotationOverlay(ann)),
                  ..._imageAnnotations
                      .where((a) => a.pageNumber == editor.currentPage)
                      .map((ann) => _buildImageOverlay(ann)),
                  if ((_snapGuideX != null || _snapGuideY != null) &&
                      (_pageTransforms[editor.currentPage] ??
                              _fallbackPageTransform(editor.currentPage)) !=
                          null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _PdfSnapGuidePainter(
                            guideX: _snapGuideX,
                            guideY: _snapGuideY,
                            transform: (_pageTransforms[editor.currentPage] ??
                                _fallbackPageTransform(editor.currentPage))!,
                          ),
                        ),
                      ),
                    ),
                  ..._shapeAnnotations
                      .where((s) => s.pageNumber == editor.currentPage)
                      .map((shape) {
                    final transform = _pageTransforms[shape.pageNumber] ??
                        _fallbackPageTransform(shape.pageNumber);
                    if (transform == null) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _PdfShapePainter(
                            shape: shape,
                            transform: transform,
                            selected: identical(shape, _selectedShape) || _selectedShapes.contains(shape),
                          ),
                        ),
                      ),
                    );
                  }),
                  ..._drawingStrokes
                      .where((s) => s.pageNumber == editor.currentPage)
                      .map((stroke) {
                    final transform = _pageTransforms[stroke.pageNumber] ??
                        _fallbackPageTransform(stroke.pageNumber);
                    if (transform == null) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _PdfDrawingPainter(
                            stroke: stroke,
                            transform: transform,
                          ),
                        ),
                      ),
                    );
                  }),
                  if (editorState.drawMode || editorState.eraserMode || _shapeMode != null || editorState.shapeEditMode)
                    Positioned.fill(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) {
                          if (editorState.shapeEditMode) {
                            _onShapeEditPointerDown(event);
                          } else if (_shapeMode != null) {
                            _onShapePointerDown(event);
                          } else if (editorState.drawMode) {
                            _onDrawPointerDown(event);
                          } else {
                            _onEraserPointerDown(event);
                          }
                        },
                        onPointerMove: (event) {
                          if (editorState.shapeEditMode) {
                            _onShapeEditPointerMove(event);
                          } else if (_shapeMode != null) {
                            _onShapePointerMove(event);
                          } else if (editorState.drawMode) {
                            _onDrawPointerMove(event);
                          } else {
                            _onEraserPointerMove(event);
                          }
                        },
                        onPointerUp: (_) {
                          if (editorState.shapeEditMode) {
                            _finishShapeEditGesture();
                          } else if (_shapeMode != null) {
                            _finishShapeGesture();
                          } else if (editorState.drawMode) {
                            _finishDrawingStroke();
                          } else {
                            _finishEraserGesture();
                          }
                        },
                        onPointerCancel: (_) {
                          if (editorState.shapeEditMode) {
                            _finishShapeEditGesture();
                          } else if (_shapeMode != null) {
                            _finishShapeGesture();
                          } else if (editorState.drawMode) {
                            _finishDrawingStroke();
                          } else {
                            _finishEraserGesture();
                          }
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  if (_showFloatingToolbar && _toolbarPosition != null)
                    FloatingToolbar(
                      position: _toolbarPosition!,
                      onEdit: () {
                        if (_selectedAnnotation == null) return;

                        setState(() {
                          _showFloatingToolbar = false;
                        });

                        _editAnnotation(_selectedAnnotation!);
                      },
                      onCopy: () {},
                      onDelete: () {
                        if (_selectedAnnotation == null) return;

                        _pushUndoState();

                        setState(() {
                          _annotations.remove(_selectedAnnotation);
                          _selectedAnnotation = null;
                          _showFloatingToolbar = false;
                        });

                        _scheduleAutoSave();
                      },
                      onColor: () {},
                      onFont: () {},
                    ),
                  // أزرار التكبير/التصغير العائمة
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'zoom_in',
                          onPressed: _zoomIn,
                          backgroundColor: AppColors.primaryDark,
                          child: const Icon(Icons.add_rounded, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'zoom_out',
                          onPressed: _zoomOut,
                          backgroundColor: AppColors.primaryDark,
                          child: const Icon(Icons.remove_rounded, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'zoom_reset',
                          onPressed: _resetZoom,
                          backgroundColor: AppColors.textMuted,
                          child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ),
        ],
      ),
      ),
      ),
    );
        },
      ),
    );
  }

  Widget _shapeToolChip({
    required IconData icon,
    required String label,
    required _ShapeKind kind,
  }) {
    final selected = _shapeMode == kind;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : AppColors.primaryDark,
        ),
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primaryDark,
        labelStyle: TextStyle(
          color: selected
              ? Colors.white
              : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : AppColors.textDark),
          fontSize: 12,
        ),
        onSelected: (_) => _toggleShapeMode(kind),
      ),
    );
  }

  Widget _annotationChip({required IconData icon, required String label, required PdfAnnotationMode mode}) {
    final active = _controller.annotationMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18, color: active ? Colors.white : AppColors.primaryDark),
        label: Text(label),
        selected: active,
        selectedColor: AppColors.primaryDark,
        labelStyle: TextStyle(
          color: active ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textDark),
          fontSize: 12,
        ),
        onSelected: (_) => _setAnnotationMode(mode),
      ),
    );
  }

}

class _TextDialogResult {
  final String text;
  final double fontSize;
  final Color color;
  final TextAlign alignment;
  _TextDialogResult({required this.text, required this.fontSize, required this.color, this.alignment = TextAlign.right});
}