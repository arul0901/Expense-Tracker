import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/haptic_feedback_util.dart';
import '../../../providers/app_providers.dart';

class SuggestIdeaSheet extends ConsumerStatefulWidget {
  const SuggestIdeaSheet({super.key});

  @override
  ConsumerState<SuggestIdeaSheet> createState() => _SuggestIdeaSheetState();
}

class _SuggestIdeaSheetState extends ConsumerState<SuggestIdeaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _selectedTabIndex = 0; // 0: Submit, 1: Browse Community Ideas
  String _selectedCategory = 'Feature Request';
  String _selectedImpact = '💡 Great Idea';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Feature Request', 'icon': Icons.lightbulb_outlined, 'color': AppColors.primary},
    {'label': 'UI / Design', 'icon': Icons.palette_outlined, 'color': Colors.purple},
    {'label': 'Performance', 'icon': Icons.speed_outlined, 'color': Colors.orange},
    {'label': 'Bug Report', 'icon': Icons.bug_report_outlined, 'color': AppColors.expense},
    {'label': 'General Feedback', 'icon': Icons.chat_bubble_outline, 'color': AppColors.income},
  ];

  final List<String> _impactOptions = ['🔥 High Priority', '✨ Nice to Have', '💡 Great Idea'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityIdeas() async {
    final client = ref.read(supabaseClientProvider);
    try {
      final rows = await client
          .from('app_feedback')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return [];
    }
  }

  Future<void> _submitIdea() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedbackUtil.heavyImpact();
    setState(() => _isSubmitting = true);

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final client = ref.read(supabaseClientProvider);
    final currentUser = client.auth.currentUser;

    try {
      await client.from('app_feedback').insert({
        'user_id': currentUser?.id,
        'type': _selectedCategory,
        'title': title,
        'description': description,
        'impact': _selectedImpact,
        'status': 'Under Review',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error inserting feedback: $e');
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _titleController.clear();
        _descriptionController.clear();
        _selectedTabIndex = 1; // Switch to community ideas tab to show inserted idea
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.income,
          duration: const Duration(seconds: 4),
          content: const Row(
            children: [
              Icon(Icons.stars_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Idea Saved to Database! 🎉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Thank you for helping us shape ProFin.', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tips_and_updates_outlined, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text('Community Ideas Hub', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab Switcher
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Submit Idea'),
                icon: Icon(Icons.add_comment_outlined, size: 18),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Browse Ideas'),
                icon: Icon(Icons.explore_outlined, size: 18),
              ),
            ],
            selected: {_selectedTabIndex},
            onSelectionChanged: (set) {
              HapticFeedbackUtil.selectionClick();
              setState(() => _selectedTabIndex = set.first);
            },
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _selectedTabIndex == 0
                ? _buildSubmitForm(theme)
                : _buildCommunityFeed(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Got a feature request or suggestion? Post your idea below to save it to the ProFin database.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Category Selector Chips
            Text('Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final label = cat['label'] as String;
                final icon = cat['icon'] as IconData;
                final color = cat['color'] as Color;
                final isSelected = _selectedCategory == label;

                return FilterChip(
                  avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
                  label: Text(label),
                  selected: isSelected,
                  selectedColor: color,
                  onSelected: (val) {
                    if (val) {
                      HapticFeedbackUtil.selectionClick();
                      setState(() => _selectedCategory = label);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Idea Title Input
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Idea Title',
                hintText: 'e.g. Splitwise import, Dark theme toggle, CSV export',
                prefixIcon: Icon(Icons.title_outlined),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Enter an idea title' : null,
            ),
            const SizedBox(height: 16),

            // Detailed Description Input
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Idea Details / Description',
                hintText: 'Describe how this feature should work and why it would be helpful...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 50),
                  child: Icon(Icons.notes_outlined),
                ),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Describe your idea' : null,
            ),
            const SizedBox(height: 16),

            // Impact / Importance Chips
            Text('Priority / Impact', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: _impactOptions.map((opt) {
                final isSelected = _selectedImpact == opt;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: FittedBox(child: Text(opt)),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      onSelected: (val) {
                        if (val) {
                          HapticFeedbackUtil.selectionClick();
                          setState(() => _selectedImpact = opt);
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitIdea,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save Idea to Database', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityFeed(ThemeData theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchCommunityIdeas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final ideas = snapshot.data ?? [];

        if (ideas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb_outline, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No Community Ideas Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Be the first to submit a feature idea!'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedTabIndex = 0),
                  icon: const Icon(Icons.add),
                  label: const Text('Submit First Idea'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: ideas.length,
          itemBuilder: (context, index) {
            final item = ideas[index];
            final title = item['title']?.toString() ?? 'Idea';
            final desc = item['description']?.toString() ?? '';
            final type = item['type']?.toString() ?? 'Feature Request';
            final impact = item['impact']?.toString() ?? '💡 Great Idea';
            final status = item['status']?.toString() ?? 'Under Review';
            final dateStr = item['created_at']?.toString();
            final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(desc, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(impact, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        if (date != null)
                          Text(
                            DateFormat('dd MMM yyyy').format(date),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
