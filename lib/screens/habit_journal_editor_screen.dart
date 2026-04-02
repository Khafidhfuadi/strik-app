import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:strik_app/controllers/habit_journal_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/models/habit_journal.dart';

class HabitJournalEditorScreen extends StatefulWidget {
  const HabitJournalEditorScreen({
    super.key,
    required this.habit,
    required this.journalController,
    this.journal,
    this.date,
  });

  final Habit habit;
  final HabitJournalController journalController;
  final HabitJournal? journal;
  final DateTime? date;

  @override
  State<HabitJournalEditorScreen> createState() =>
      _HabitJournalEditorScreenState();
}

class _HabitJournalEditorScreenState extends State<HabitJournalEditorScreen> {
  late final TextEditingController _textController;
  late final DateTime _displayDate;
  Timer? _debounce;

  File? _selectedImage;
  String? _existingImageUrl;
  String? _originalImageUrl;
  bool _removeExistingImage = false;
  String _saveStatus = '';
  bool _isSubmitting = false;

  bool get _isEditing => widget.journal != null;
  bool get _hasAttachedImage =>
      _selectedImage != null || _existingImageUrl != null;
  bool get _isChallengeHabit => widget.habit.challengeId != null;

  @override
  void initState() {
    super.initState();
    _displayDate =
        widget.date ?? (widget.journal?.createdAt.toLocal() ?? DateTime.now());
    _textController = TextEditingController(
      text: widget.journal?.content ?? '',
    );
    _originalImageUrl = widget.journal?.imageUrl;
    _existingImageUrl = _originalImageUrl;

    if (!_isEditing) {
      _loadDraft();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final draft = await widget.journalController.getDraft(_displayDate);
    if (!mounted || draft == null || draft.isEmpty) return;

    _textController.text = draft;
    setState(() {
      _saveStatus = 'Draft';
    });
  }

  void _handleTextChanged(String value) {
    setState(() {
      _saveStatus = 'Menyimpan...';
    });

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      await widget.journalController.saveDraft(value, _displayDate);
      if (!mounted) return;
      setState(() {
        _saveStatus = 'Draft';
      });
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await widget.journalController.pickImage(source: source);
    if (!mounted || file == null) return;

    setState(() {
      _selectedImage = file;
      _existingImageUrl = _originalImageUrl;
      _removeExistingImage = false;
    });
  }

  void _removeImage() {
    setState(() {
      if (_selectedImage != null) {
        _selectedImage = null;
        _existingImageUrl = _removeExistingImage ? null : _originalImageUrl;
      } else if (_existingImageUrl != null) {
        _existingImageUrl = null;
        _removeExistingImage = true;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final content = _textController.text.trim();
    if (content.isEmpty &&
        _selectedImage == null &&
        _existingImageUrl == null) {
      Get.snackbar(
        'Error',
        'Isi konten atau upload foto dulu ya',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isEditing) {
        await widget.journalController.updateJournal(
          widget.journal!.id!,
          content,
          newImageFile: _selectedImage,
          removeImage: _removeExistingImage && _selectedImage == null,
        );
      } else {
        await widget.journalController.addJournal(
          content,
          date: _displayDate,
          imageFile: _selectedImage,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final journal = widget.journal;
    if (journal == null) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Jurnal?',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            color: AppTheme.textPrimary,
          ),
        ),
        content: const Text(
          'Jurnal ini akan dihapus dari habit kamu.',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.journalController.deleteJournal(journal.id!);
    if (mounted) {
      Get.back();
    }
  }

  void _showImageViewer({
    String? imageUrl,
    File? imageFile,
    required String heroTag,
  }) {
    if (imageUrl == null && imageFile == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Hero(
                      tag: heroTag,
                      child: imageFile != null
                          ? Image.file(imageFile, fit: BoxFit.contain)
                          : CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) {
                                return const Icon(
                                  Icons.broken_image,
                                  color: Colors.white24,
                                  size: 48,
                                );
                              },
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final previewHeroTag =
        'journal-editor-image-${widget.journal?.id ?? _displayDate.toIso8601String()}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Jurnal' : 'Tulis Jurnal',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              widget.habit.title,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildHeroCard(), const SizedBox(height: 0)],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                extent: 90,
                child: Container(
                  color: AppTheme.background,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  alignment: Alignment.bottomCenter,
                  child: _buildStickyEditorHeader(),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                keyboardInset > 0 ? 24 : 184,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEditorCard(),
                    const SizedBox(height: 16),
                    _buildAttachmentCard(previewHeroTag),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(20, 12, 20, keyboardInset > 0 ? 12 : 20),
          decoration: BoxDecoration(
            color: AppTheme.background,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildQuickAction(
                      icon: Icons.camera_alt_outlined,
                      label: 'Kamera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Galeri',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    disabledBackgroundColor: AppTheme.primary.withValues(
                      alpha: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Simpan Perubahan' : 'Simpan Jurnal',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final accent = _isChallengeHabit
        ? const Color(0xFFFFB703)
        : AppTheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.95),
            accent == AppTheme.primary
                ? const Color(0xFFE7FF77)
                : const Color(0xFFFFD166),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Jurnal '${widget.habit.title}'", //nama habit
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isChallengeHabit
                ? 'Tambahkan catatan dan foto bukti progres kamu.'
                : 'Catat progres, hambatan, atau hal kecil yang kamu rasain terkait habit ini.',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textController,
            minLines: 12,
            maxLines: null,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 15,
              color: AppTheme.textPrimary,
              height: 1.7,
            ),
            onChanged: _handleTextChanged,
            decoration: InputDecoration(
              hintText: 'Tulis jurnal kamu di sini...',
              hintStyle: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white.withValues(alpha: 0.34),
                height: 1.6,
              ),
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyEditorHeader() {
    final isSaving = _saveStatus == 'Menyimpan...';
    final accent = isSaving ? Colors.amber : Colors.green;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_displayDate),
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (_saveStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSaving ? Icons.sync : Icons.check_circle,
                    size: 12,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _saveStatus,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard(String previewHeroTag) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Lampiran Foto',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (_isChallengeHabit)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Text(
                    'Wajib',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_hasAttachedImage)
            Stack(
              children: [
                GestureDetector(
                  onTap: () => _showImageViewer(
                    imageUrl: _existingImageUrl,
                    imageFile: _selectedImage,
                    heroTag: previewHeroTag,
                  ),
                  child: Hero(
                    tag: previewHeroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Container(
                          color: Colors.black,
                          child: _selectedImage != null
                              ? Image.file(_selectedImage!, fit: BoxFit.contain)
                              : CachedNetworkImage(
                                  imageUrl: _existingImageUrl!,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.white24,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Tap untuk lihat penuh',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _removeImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 28,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isChallengeHabit
                        ? 'Tambahkan foto bukti progress'
                        : 'Belum ada foto yang dilampirkan',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.03),
              blurRadius: 0,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppTheme.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || child != oldDelegate.child;
  }
}
