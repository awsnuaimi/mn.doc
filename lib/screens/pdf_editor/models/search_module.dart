part of '../../pdf_editor_screen.dart';

/// كل منطق البحث داخل الـ PDF: شريط البحث، التأخير (Debounce)، والتنقّل
/// بين نتائج البحث. نُقل من pdf_editor_screen.dart لتقليل حجمها.
///
/// `_controller` و`editorState` مطلوبتان كـ getters مجرّدة هون فقط لأن
/// `_PdfEditorScreenState` نفسها لا يمكن استخدامها كقيد `on` (دائرية:
/// الصنف نفسه غير معرّف بعد وقت تعريف الـmixin). الصنف المضيف يحقق هذا
/// الشرط تلقائيًا لأنه أصلاً يملك حقلين بنفس الاسمين.
mixin SearchModule on State<PdfEditorScreen> {
  PdfViewerController get _controller;
  EditorState get editorState;

  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  Timer? _searchDebounce;

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  void _search(String query) {
    if (query.trim().isEmpty) {
      _searchResult.clear();
      setState(() {});
      return;
    }
    _searchResult.removeListener(_onSearchResultChanged);
    _searchResult = _controller.searchText(query);
    _searchResult.addListener(_onSearchResultChanged);
    setState(() {});
  }

  void _onSearchResultChanged() {
    if (mounted) setState(() {});
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchResult.removeListener(_onSearchResultChanged);
    _searchResult.clear();
    editorState.searchVisible = false;
    editorState.notifyListeners();

    setState(() {
      _searchController.clear();
    });
  }
}
