import 'package:flutter/material.dart';

/// A simple controller for controlling the SearchBar.
class NBSearchBarController extends ChangeNotifier {
    bool _isFixed = true;
    bool _isVisible = true;

    /// If fixed is true, the SearchBar will always be shown.
    /// If fixed is false, toggleBar() controls its visibility.
    void setFixed(bool fixed) {
        _isFixed = fixed;
        if (fixed) {
            _isVisible = true;
        }
        notifyListeners();
    }

    /// When [show] is false the bar will slide out of view.
    /// Only works if setFixed(false) has been called.
    void toggleBar(bool show) {
        if (!_isFixed) {
            _isVisible = show;
            notifyListeners();
        }
    }

    bool get isFixed => _isFixed;
    bool get isVisible => _isVisible;
}
