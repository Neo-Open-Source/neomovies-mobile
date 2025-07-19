import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Глобальный менеджер фокуса для управления навигацией между элементами интерфейса
class GlobalFocusManager {
  static final GlobalFocusManager _instance = GlobalFocusManager._internal();
  factory GlobalFocusManager() => _instance;
  GlobalFocusManager._internal();

  // Фокус ноды для разных элементов интерфейса
  FocusNode? _appBarFocusNode;
  FocusNode? _contentFocusNode;
  FocusNode? _bottomNavFocusNode;
  
  // Текущее состояние фокуса
  FocusArea _currentFocusArea = FocusArea.content;
  
  // Callback для уведомления об изменении фокуса
  VoidCallback? _onFocusChanged;

  void initialize({
    FocusNode? appBarFocusNode,
    FocusNode? contentFocusNode,
    FocusNode? bottomNavFocusNode,
    VoidCallback? onFocusChanged,
  }) {
    _appBarFocusNode = appBarFocusNode;
    _contentFocusNode = contentFocusNode;
    _bottomNavFocusNode = bottomNavFocusNode;
    _onFocusChanged = onFocusChanged;
  }

  /// Обработка глобальных клавиш
  KeyEventResult handleGlobalKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.escape:
        case LogicalKeyboardKey.goBack:
          _focusAppBar();
          return KeyEventResult.handled;
          
        case LogicalKeyboardKey.arrowUp:
          if (_currentFocusArea == FocusArea.appBar) {
            _focusContent();
            return KeyEventResult.handled;
          }
          break;
          
        case LogicalKeyboardKey.arrowDown:
          if (_currentFocusArea == FocusArea.content) {
            _focusBottomNav();
            return KeyEventResult.handled;
          } else if (_currentFocusArea == FocusArea.appBar) {
            _focusContent();
            return KeyEventResult.handled;
          }
          break;
      }
    }
    return KeyEventResult.ignored;
  }

  void _focusAppBar() {
    if (_appBarFocusNode != null) {
      _currentFocusArea = FocusArea.appBar;
      _appBarFocusNode!.requestFocus();
      _onFocusChanged?.call();
    }
  }

  void _focusContent() {
    if (_contentFocusNode != null) {
      _currentFocusArea = FocusArea.content;
      _contentFocusNode!.requestFocus();
      _onFocusChanged?.call();
    }
  }

  void _focusBottomNav() {
    if (_bottomNavFocusNode != null) {
      _currentFocusArea = FocusArea.bottomNav;
      _bottomNavFocusNode!.requestFocus();
      _onFocusChanged?.call();
    }
  }

  /// Установить фокус на контент (для использования извне)
  void focusContent() => _focusContent();
  
  /// Установить фокус на навбар (для использования извне)
  void focusAppBar() => _focusAppBar();
  
  /// Получить текущую область фокуса
  FocusArea get currentFocusArea => _currentFocusArea;
  
  /// Проверить, находится ли фокус в контенте
  bool get isContentFocused => _currentFocusArea == FocusArea.content;
  
  /// Проверить, находится ли фокус в навбаре
  bool get isAppBarFocused => _currentFocusArea == FocusArea.appBar;

  void dispose() {
    _appBarFocusNode = null;
    _contentFocusNode = null;
    _bottomNavFocusNode = null;
    _onFocusChanged = null;
  }
}

/// Области фокуса в приложении
enum FocusArea {
  appBar,
  content,
  bottomNav,
}

/// Виджет-обертка для глобального управления фокусом
class GlobalFocusWrapper extends StatefulWidget {
  final Widget child;
  final FocusNode? contentFocusNode;

  const GlobalFocusWrapper({
    super.key,
    required this.child,
    this.contentFocusNode,
  });

  @override
  State<GlobalFocusWrapper> createState() => _GlobalFocusWrapperState();
}

class _GlobalFocusWrapperState extends State<GlobalFocusWrapper> {
  final GlobalFocusManager _focusManager = GlobalFocusManager();
  late final FocusNode _wrapperFocusNode;

  @override
  void initState() {
    super.initState();
    _wrapperFocusNode = FocusNode();
    
    // Инициализируем глобальный менеджер фокуса
    _focusManager.initialize(
      contentFocusNode: widget.contentFocusNode ?? _wrapperFocusNode,
      onFocusChanged: () => setState(() {}),
    );
  }

  @override
  void dispose() {
    _wrapperFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _wrapperFocusNode,
      onKeyEvent: (node, event) => _focusManager.handleGlobalKey(event),
      child: widget.child,
    );
  }
}
