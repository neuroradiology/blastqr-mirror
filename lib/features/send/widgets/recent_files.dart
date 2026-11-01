import 'dart:io';

import 'package:blast_qr/color_scheme.dart';
import 'package:blast_qr/l10n/extension.dart';
import 'package:blast_qr/model/file_wrapper.dart';
import 'package:blast_qr/widgets/file_list_row.dart';
import 'package:blast_qr/widgets/file_list_selection.dart';
import 'package:blast_qr/widgets/file_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class RecentFilesTiles extends StatefulWidget {
  const RecentFilesTiles({
    super.key,
    required this.entries,
    required this.bottomInset,
    required this.onSend,
  });

  final List<FileWrapper> entries;

  /// The height of the bottom tabs, which the list runs under.
  final double bottomInset;
  final void Function(List<File>) onSend;

  @override
  State<RecentFilesTiles> createState() => _RecentFilesTilesState();
}

class _RecentFilesTilesState extends State<RecentFilesTiles> {
  late final _selection = FileListSelection<FileWrapper>(() => widget.entries)
    ..addListener(_onSelectionChanged);

  bool get _selecting => _selection.isNotEmpty;

  void _onSelectionChanged() => setState(() {});

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _send(List<FileWrapper> entries) {
    // Sending moves the files to the top of the list.
    _selection.clear();
    if (entries.isNotEmpty) {
      widget.onSend([for (final entry in entries) entry.file]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 24,
            child: Row(
              spacing: 4,
              children: [
                Text(
                  _selecting
                      ? '${_selection.length} ${context.l10n.selected}'
                      : context.l10n.recent,
                  style: const TextStyle(fontFamily: 'Jersey25', fontSize: 18),
                ),
                if (_selecting)
                  IconButton(
                    onPressed: _selection.clear,
                    tooltip: context.l10n.cancel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      color: context.color.onSurface,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                // Room to scroll the last file above the tabs and the
                // send button.
                padding: EdgeInsets.only(
                  bottom: widget.bottomInset + (_selecting ? 64 : 0),
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return FileListTile(
                    thumbnail: entry.buildThumbnail(
                      context,
                      size: FileListTile.thumbnailSize,
                    ),
                    title: entry.name,
                    subtitle: entry.sizeInkB,
                    isSelecting: _selecting,
                    isSelected: _selection.contains(entry),
                    onTap: _selecting
                        ? () => _selection.toggle(entry)
                        : () => _send([entry]),
                    onLongPress: () => _selection.toggle(entry),
                  );
                },
              ),
              if (_selecting)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: widget.bottomInset + 8,
                  child: _SendSelectedButton(
                    onPressed: () => _send(_selection.selected),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Desktop recents: a file list that works like the Received page, where
/// opening the selection sends it.
class RecentFilesList extends StatefulWidget {
  const RecentFilesList({
    super.key,
    required this.entries,
    required this.onSend,
  });

  final List<FileWrapper> entries;
  final void Function(List<File>) onSend;

  @override
  State<RecentFilesList> createState() => _RecentFilesListState();
}

class _RecentFilesListState extends State<RecentFilesList> {
  late final _selection = FileListSelection<FileWrapper>(() => widget.entries)
    ..addListener(_onSelectionChanged);

  void _onSelectionChanged() => setState(() {});

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _send(List<FileWrapper> entries) {
    // Sending moves the files to the top of the list.
    _selection.clear();
    widget.onSend([for (final entry in entries) entry.file]);
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            context.l10n.recent,
            style: const TextStyle(fontFamily: 'Jersey25', fontSize: 18),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FileListKeyboard(
                selection: _selection,
                onOpen: _send,
                child: ListView.builder(
                  // Room to scroll the last file above the send button.
                  padding: EdgeInsets.only(bottom: _selection.isEmpty ? 0 : 64),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return FileListRow(
                      key: entry == _selection.cursor
                          ? _selection.cursorKey
                          : null,
                      thumbnail: entry.buildThumbnail(
                        context,
                        size: FileListRow.iconSize,
                      ),
                      name: entry.name,
                      size: entry.sizeInkB,
                      striped: index.isOdd,
                      selected: _selection.contains(entry),
                      showCheckmark: _selection.length > 1,
                      margin: EdgeInsets.zero,
                      onTap: () => _selection.tap(entry, _send),
                      onSecondaryTap: () =>
                          _selection.secondaryTap(entry, _send),
                    );
                  },
                ),
              ),
              if (_selection.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(
                    child: _SendSelectedButton(
                      onPressed: () => _send(_selection.selected),
                      fitLabel: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SendSelectedButton extends StatelessWidget {
  const _SendSelectedButton({required this.onPressed, this.fitLabel = false});

  final VoidCallback onPressed;

  /// As wide as its label instead of the available width.
  final bool fitLabel;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      // Floats over the list, so a shadow sets it apart from the rows under
      // it, which can be selected and in the same color.
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        elevation: 3,
        shadowColor: Colors.black,
        minimumSize: fitLabel ? const Size(0, 48) : null,
        padding: fitLabel ? const EdgeInsets.symmetric(horizontal: 24) : null,
      ),
      icon: const HugeIcon(
        icon: HugeIcons.strokeRoundedSent02,
        color: Colors.white,
      ),
      label: Text(context.l10n.send_selected),
    );
  }
}
