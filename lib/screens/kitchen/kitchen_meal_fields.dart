import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const kitchenMealSlots = {
  'breakfast': '早餐',
  'lunch': '午餐',
  'dinner': '晚餐',
  'snack': '加餐'
};

String kitchenMealPlanLabel(String? date, String? slot) => [
      if (date != null && date.isNotEmpty) date,
      if (kitchenMealSlots.containsKey(slot)) kitchenMealSlots[slot]!,
    ].join(' · ');

class KitchenMealFields extends StatelessWidget {
  final String? date;
  final String? slot;
  final ValueChanged<String?> onDate;
  final ValueChanged<String?> onSlot;
  final bool enabled;
  const KitchenMealFields(
      {super.key,
      required this.date,
      required this.slot,
      required this.onDate,
      required this.onSlot,
      required this.enabled});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: !enabled
                      ? null
                      : () async {
                          final first = DateTime(2000),
                              last = DateTime(2099, 12, 31);
                          final initial =
                              DateTime.tryParse(date ?? '') ?? DateTime.now();
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: initial.isBefore(first)
                                  ? first
                                  : initial.isAfter(last)
                                      ? last
                                      : initial,
                              firstDate: first,
                              lastDate: last);
                          if (context.mounted && picked != null) {
                            onDate(DateFormat('yyyy-MM-dd').format(picked));
                          }
                        },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(date ?? '选择用餐日期')),
              if (date != null)
                TextButton(
                    onPressed: enabled ? () => onDate(null) : null,
                    child: const Text('清除日期')),
            ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: kitchenMealSlots.containsKey(slot) ? slot : '',
          decoration: const InputDecoration(labelText: '用餐时段'),
          items: [
            const DropdownMenuItem(value: '', child: Text('时段未定')),
            for (final entry in kitchenMealSlots.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value))
          ],
          onChanged: enabled
              ? (value) => onSlot(value?.isNotEmpty == true ? value : null)
              : null,
        ),
      ]);
}
