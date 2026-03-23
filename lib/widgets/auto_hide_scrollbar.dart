import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// A minimal, auto-hiding scrollbar thumb overlay for ScrollablePositionedList.
/// It becomes visible on scroll and fades out after [fadeDuration].
class AutoHideScrollbar extends StatefulWidget {
  final Widget child;
  final ItemPositionsListener itemPositionsListener;
  final ItemScrollController itemScrollController;
  final int totalItems;
  final Duration fadeDuration;

  const AutoHideScrollbar({
    super.key,
    required this.child,
    required this.itemPositionsListener,
    required this.itemScrollController,
    required this.totalItems,
    this.fadeDuration = const Duration(seconds: 2),
  });

  @override
  State<AutoHideScrollbar> createState() => _AutoHideScrollbarState();
}

class _AutoHideScrollbarState extends State<AutoHideScrollbar> {
  double _thumbPosition = 0.0;
  bool _isVisible = false;
  Timer? _hideTimer;
  bool _isDragging = false;
  int _lastTargetIndex = -1;

  static const double _thumbHeight = 48.0;
  static const double _thumbWidth = 4.0;
  static const double _trackRightMargin = 3.0;

  @override
  void initState() {
    super.initState();
    widget.itemPositionsListener.itemPositions.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.itemPositionsListener.itemPositions.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final positions = widget.itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || widget.totalItems <= 0) return;

    // Calculate scroll fraction based on the first visible item
    final firstVisible = positions.reduce(
      (a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b,
    );

    final fraction = (firstVisible.index + firstVisible.itemLeadingEdge) /
        widget.totalItems.clamp(1, double.infinity);

    if (mounted && !_isDragging) {
      setState(() {
        _thumbPosition = fraction.clamp(0.0, 1.0);
        _isVisible = true;
      });
    }

    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!_isDragging) {
      _hideTimer = Timer(widget.fadeDuration, () {
        if (mounted) {
          setState(() => _isVisible = false);
        }
      });
    }
  }

  void _onDragStart(DragStartDetails details) {
    _hideTimer?.cancel();
    setState(() {
      _isDragging = true;
      _isVisible = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final trackHeight = constraints.maxHeight - _thumbHeight;
    if (trackHeight <= 0) return;

    final newPos = (_thumbPosition + details.delta.dy / trackHeight).clamp(0.0, 1.0);
    final targetIndex = (newPos * widget.totalItems).floor().clamp(0, widget.totalItems - 1);

    setState(() => _thumbPosition = newPos);
    
    if (targetIndex != _lastTargetIndex) {
      _lastTargetIndex = targetIndex;
      widget.itemScrollController.jumpTo(index: targetIndex);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    _resetHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight - _thumbHeight;
        final topOffset = _thumbPosition * trackHeight;

        return Stack(
          children: [
            widget.child,
            Positioned(
              right: _trackRightMargin,
              top: topOffset,
              child: AnimatedOpacity(
                opacity: _isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: GestureDetector(
                  onVerticalDragStart: _onDragStart,
                  onVerticalDragUpdate: (d) => _onDragUpdate(d, constraints),
                  onVerticalDragEnd: _onDragEnd,
                  child: Container(
                    width: _isDragging ? 6.0 : _thumbWidth,
                    height: _thumbHeight,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(
                        _isDragging ? 0.6 : 0.35,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
