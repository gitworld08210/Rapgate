import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// A reusable table widget with alternating row background colors.
///
/// Used for Nutrition Summary, Push-up Discipline Log, Most Logged Foods,
/// and Weekly Breakdown tables in the health report.
class ReportTable extends StatelessWidget {
  const ReportTable({
    super.key,
    required this.headers,
    required this.rows,
    this.columnAlignments,
    this.columnFlex,
  });

  /// Column header labels.
  final List<String> headers;

  /// Row data - each inner list should have the same length as [headers].
  final List<List<String>> rows;

  /// Optional alignment for each column (defaults to left).
  final List<TextAlign>? columnAlignments;

  /// Optional flex values for columns. Defaults to equal flex.
  final List<int>? columnFlex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? AppColors.darkBorder : AppColors.grey200;
    final evenBg = isDark ? AppColors.darkCard : AppColors.white;
    final oddBg = isDark ? AppColors.darkSurface : AppColors.grey100;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        children: [
          // Header row
          Container(
            color: headerBg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: List.generate(headers.length, (i) {
                return Expanded(
                  flex: columnFlex != null && i < columnFlex!.length
                      ? columnFlex![i]
                      : 1,
                  child: Text(
                    headers[i],
                    textAlign: _alignAt(i),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.white : AppColors.ink,
                    ),
                  ),
                );
              }),
            ),
          ),
          // Data rows
          ...List.generate(rows.length, (rowIdx) {
            final isEven = rowIdx % 2 == 0;
            return Container(
              color: isEven ? evenBg : oddBg,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: List.generate(headers.length, (colIdx) {
                  final cellText =
                      colIdx < rows[rowIdx].length ? rows[rowIdx][colIdx] : '';
                  return Expanded(
                    flex: columnFlex != null && colIdx < columnFlex!.length
                        ? columnFlex![colIdx]
                        : 1,
                    child: Text(
                      cellText,
                      textAlign: _alignAt(colIdx),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.white : AppColors.ink,
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  TextAlign _alignAt(int index) {
    if (columnAlignments != null && index < columnAlignments!.length) {
      return columnAlignments![index];
    }
    return index == 0 ? TextAlign.left : TextAlign.center;
  }
}
