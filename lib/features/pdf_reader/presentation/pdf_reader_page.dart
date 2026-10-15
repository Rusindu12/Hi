import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../services/external_link_service.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../state/library_controller.dart';
import '../../../state/streak_controller.dart';

/// The PDF reader.
///
/// Three things this screen must get right:
///   * **Zero ads.** Not a policy detail — a reading surface interrupted by an
///     interstitial is the fastest way to lose a student. There is no ad import
///     in this file, and a unit test enforces that.
///   * **Resume.** The last page is written back to Hive (debounced) and restored
///     on the next open, per book.
///   * **Sinhala/Tamil shaping.** Delegated to pdfrx, which bundles HarfBuzz —
///     hence the deliberate choice over `pdf_render` in the brief.
class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
    super.key,
    required this.itemId,
    required this.title,
    required this.subtitle,
    required this.localPath,
    this.initialPage = 1,
    this.externalUrl,
  });

  final String itemId;
  final String title;
  final String subtitle;

  /// Null when there is no offline copy; the page then offers the official link
  /// instead of pretending to render something.
  final String? localPath;

  final int initialPage;
  final String? externalUrl;

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  final PdfViewerController _controller = PdfViewerController();

  int _page = 1;
  int _totalPages = 0;
  bool _resumeApplied = false;
  bool _restored = false;
  bool _filePresent = true;
  Timer? _persistDebounce;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage <= 0 ? 1 : widget.initialPage;
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordStudyOnce());
    _verifyFile();
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Reading counts towards today's streak (the brief's rule: "opens any PDF").
  Future<void> _recordStudyOnce() async {
    if (!mounted) {
      return;
    }
    await context.read<StreakController>().recordStudy();
  }

  /// The download record can outlive its file (user cleared data, OS reclaimed
  /// space), so verify rather than show a blank viewer.
  Future<void> _verifyFile() async {
    final String? path = widget.localPath;
    if (path == null || kIsWeb) {
      return;
    }
    final bool exists = await File(path).exists();
    if (!mounted || exists) {
      return;
    }
    setState(() => _filePresent = false);
  }

  void _onControllerChanged() {
    final int? pageNumber = _controller.pageNumber;
    final int pageCount = _controller.pages.length;

    final bool changed = (pageNumber != null && pageNumber != _page) ||
        (pageCount > 0 && pageCount != _totalPages);

    if (!changed) {
      return;
    }

    setState(() {
      if (pageNumber != null) {
        _page = pageNumber;
      }
      if (pageCount > 0) {
        _totalPages = pageCount;
      }
    });

    // Jump to the stored position once, after pdfrx knows the page count.
    if (!_resumeApplied && pageCount > 0 && widget.initialPage > 1) {
      _resumeApplied = true;
      _controller.goToPage(pageNumber: widget.initialPage);
      _announceResume(widget.initialPage);
    }
    if (!_restored && pageCount > 0) {
      _restored = true;
    }

    _schedulePersist();
  }

  /// Tells the student why the book did not open on page one. Without this,
  /// a resumed position looks like a mis-scrolled page.
  void _announceResume(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.pdfResume(page)),
            duration: const Duration(seconds: 3),
          ),
        );
    });
  }

  /// Writing on every frame would hammer Hive while a student scrolls, so
  /// coalesce page writes.
  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) {
        return;
      }
      await context.read<LibraryController>().recordReadingProgressForReader(
            itemId: widget.itemId,
            page: _page,
            pageCount: _totalPages == 0 ? null : _totalPages,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? path = widget.localPath;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _totalPages > 0
                  ? l10n.pdfPageOf(_page, _totalPages)
                  : widget.subtitle,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: <Widget>[
          if (widget.externalUrl != null && widget.externalUrl!.isNotEmpty)
            IconButton(
              tooltip: l10n.pdfOpenOfficial,
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () =>
                  const ExternalLinkService().open(widget.externalUrl!),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _totalPages == 0
              ? const SizedBox(height: 3)
              : LinearProgressIndicator(
                  value: (_page / _totalPages).clamp(0.0, 1.0),
                  minHeight: 3,
                ),
        ),
      ),
      // No ad widgets in this subtree, by policy and by test.
      body: _buildBody(context, path),
    );
  }

  Widget _buildBody(BuildContext context, String? path) {
    final AppLocalizations l10n = context.l10n;

    if (kIsWeb) {
      return EmptyState(
        illustration: AppIllustration.emptySearch,
        title: l10n.pdfWebNotice,
        body: l10n.pdfWebNoticeBody,
        actionLabel: l10n.pdfOpenOfficial,
        onAction: widget.externalUrl == null
            ? null
            : () => const ExternalLinkService().open(widget.externalUrl!),
      );
    }

    if (path == null) {
      return EmptyState(
        illustration: AppIllustration.emptyDownloads,
        title: l10n.pdfNoOfflineCopy,
        body: l10n.pdfNoOfflineCopyBody,
        actionLabel: widget.externalUrl == null ? null : l10n.tbOpenOfficial,
        onAction: widget.externalUrl == null
            ? null
            : () => const ExternalLinkService().open(widget.externalUrl!),
      );
    }

    if (!_filePresent) {
      return EmptyState(
        illustration: AppIllustration.emptyDownloads,
        title: l10n.errFileMissing,
        body: l10n.pdfNoOfflineCopyBody,
        actionLabel: l10n.actionBack,
        onAction: () => Navigator.of(context).pop(),
      );
    }

    return PdfViewer.file(
      path,
      controller: _controller,
      params: PdfViewerParams(
        // Dark surround so the page edges read clearly in night mode.
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.canvasDark
            : AppColors.canvas,
        margin: 8,
        enableTextSelection: true,
        maxScale: 6,
        // Long-press selection menus are noise for a textbook scan; the reader's
        // job is reading, and copy-paste is not a supported study flow.
        panAxis: PanAxis.free,
      ),
    );
  }
}

/// Kept for the router's contract documentation and for quick greps.
const List<String> debugReaderForbiddenImports = <String>[
  'google_mobile_ads',
  'ad_banner.dart',
  'ad_service.dart',
];
