// lib/widgets/home_filter_panel.dart

import 'package:flutter/material.dart';

class HomeFilterPanel extends StatelessWidget {
  final String? selectedSchool;
  final List<String> schoolNames;
  final Function(String?) onSchoolSelected;
  
  final String selectedGradeLevel;
  final List<String> gradeLevels;
  final Function(String?) onGradeLevelChanged;

  final String selectedClassName;
  final List<String> classNames;
  final Function(String?) onClassNameChanged;

  final String selectedPhotoStatus;
  final List<String> photoStatuses;
  final Function(String?) onPhotoStatusChanged;
  
  final TextEditingController searchController;

  const HomeFilterPanel({
    super.key,
    required this.selectedSchool,
    required this.schoolNames,
    required this.onSchoolSelected,
    required this.selectedGradeLevel,
    required this.gradeLevels,
    required this.onGradeLevelChanged,
    required this.selectedClassName,
    required this.classNames,
    required this.onClassNameChanged,
    required this.selectedPhotoStatus,
    required this.photoStatuses,
    required this.onPhotoStatusChanged,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]),
      child: Column(
        children: [
          _buildDropdown(
            context: context,
            hint: 'กรุณาเลือกโรงเรียน',
            value: selectedSchool,
            items: schoolNames,
            onChanged: onSchoolSelected
          ),
          if (selectedSchool != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDropdown(context: context, hint: 'ระดับชั้น', value: selectedGradeLevel, items: gradeLevels, onChanged: onGradeLevelChanged)),
                const SizedBox(width: 12),
                Expanded(child: _buildDropdown(context: context, hint: 'ห้อง', value: selectedClassName, items: classNames, onChanged: onClassNameChanged)),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              context: context,
              hint: 'สถานะรูปภาพ',
              value: selectedPhotoStatus,
              items: photoStatuses,
              onChanged: onPhotoStatusChanged
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'ค้นหา...',
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                prefixIcon: Icon(Icons.search, size: 20, color: Theme.of(context).hintColor),
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDropdown({required BuildContext context, String? hint, required String? value, required List<String> items, required void Function(String?)? onChanged}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12.0)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: hint != null ? Text(hint) : null,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: theme.hintColor),
          dropdownColor: theme.cardColor,
          style: theme.textTheme.bodyLarge,
          items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}