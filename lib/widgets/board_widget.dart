import 'package:flutter/material.dart';

class BoardWidget extends StatelessWidget {
  final List<int?> board; // 0/1/null per cell
  final int? selectedCell; // مهره‌ی انتخاب‌شده در فاز جابه‌جایی
  final List<int> highlightCells; // مقصدهای مجاز برای نمایش
  final void Function(int cell) onCellTap;

  const BoardWidget({
    super.key,
    required this.board,
    required this.onCellTap,
    this.selectedCell,
    this.highlightCells = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, i) {
          final owner = board[i];
          final isSelected = selectedCell == i;
          final isHighlighted = highlightCells.contains(i);

          Color bg = Colors.grey.shade200;
          if (isSelected) bg = Colors.amber.shade300;
          if (isHighlighted) bg = Colors.green.shade200;

          return GestureDetector(
            onTap: () => onCellTap(i),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Center(
                child: owner == null
                    ? const SizedBox.shrink()
                    : Icon(
                        owner == 0 ? Icons.circle_outlined : Icons.close,
                        size: 42,
                        color: owner == 0 ? Colors.blue : Colors.red,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
