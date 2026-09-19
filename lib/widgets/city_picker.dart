import 'package:flutter/material.dart';
import '../utils/city_data.dart';
import '../utils/lovegirl_theme.dart';

/// 城市选择器 — 弹出底部面板，支持热门+字母索引+搜索
Future<String?> showCityPicker(BuildContext context, {String? currentCity}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CityPickerSheet(currentCity: currentCity),
  );
}

class _CityPickerSheet extends StatefulWidget {
  final String? currentCity;
  const _CityPickerSheet({this.currentCity});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _keyword.isNotEmpty;
    final searchResults = isSearching ? CityData.search(_keyword) : <String>[];

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.lgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          // 拖拽条
          SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),

          // 标题
          Text('选择城市',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),

          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索城市...',
                prefixIcon:
                    Icon(Icons.search, color: context.lgTextMuted),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _keyword = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.lgBg,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _keyword = v.trim()),
            ),
          ),
          SizedBox(height: 12),

          // 内容
          Expanded(
            child: isSearching
                ? _buildSearchResults(searchResults)
                : _buildCityList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<String> results) {
    if (results.isEmpty) {
      return Center(
        child: Text('未找到匹配的城市', style: TextStyle(color: context.lgTextMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: results.length,
      itemBuilder: (_, i) => _buildCityTile(results[i]),
    );
  }

  Widget _buildCityList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // 热门城市
        Text('热门城市',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.lgTextSecondary)),
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CityData.hotCities.map((city) {
            final isSelected = city == widget.currentCity;
            return GestureDetector(
              onTap: () => Navigator.pop(context, city),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.lgInk.withAlpha(30)
                      : context.lgBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? context.lgInk
                        : Colors.black.withAlpha(10),
                  ),
                ),
                child: Text(
                  city,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected
                        ? context.lgInk
                        : context.lgTextPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 20),

        // 按字母分组
        ...CityData.citiesByLetter.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.lgTextSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: entry.value.map((city) {
                  final isSelected = city == widget.currentCity;
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, city),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Text(
                        city,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? context.lgInk
                              : context.lgTextPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCityTile(String city) {
    final isSelected = city == widget.currentCity;
    return ListTile(
      dense: true,
      leading: Icon(Icons.location_city,
          size: 20,
          color: isSelected ? context.lgInk : context.lgTextMuted),
      title: Text(city,
          style: TextStyle(
            fontSize: 15,
            color: isSelected ? context.lgInk : context.lgTextPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          )),
      trailing: isSelected
          ? Icon(Icons.check, size: 18, color: context.lgInk)
          : null,
      onTap: () => Navigator.pop(context, city),
    );
  }
}
