import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/components/shared/account_list_tile.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/screens/archive_screen.dart';
import 'package:pinpoint/screens/sync_screen.dart';
import 'package:pinpoint/screens/tags_screen.dart';
import 'package:pinpoint/screens/trash_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/screens/theme_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountScreen extends StatefulWidget {
  static const String kRouteName = '/account';
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _viewType = 'list';
  String _sortType = 'updatedAt';
  String _sortDirection = 'desc';
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _viewType = _prefs?.getString(kHomeScreenViewTypeKey) ?? 'list';
      _sortType = _prefs?.getString(kHomeScreenSortTypeKey) ?? 'updatedAt';
      _sortDirection =
          _prefs?.getString(kHomeScreenSortDirectionKey) ?? 'desc';
    });
  }

  Future<void> _setViewType(String value) async {
    await _prefs?.setString(kHomeScreenViewTypeKey, value);
    setState(() {
      _viewType = value;
    });
  }

  Future<void> _setSortType(String? value) async {
    if (value == null) return;
    await _prefs?.setString(kHomeScreenSortTypeKey, value);
    setState(() {
      _sortType = value;
    });
  }

  Future<void> _setSortDirection(String? value) async {
    if (value == null) return;
    await _prefs?.setString(kHomeScreenSortDirectionKey, value);
    setState(() {
      _sortDirection = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('General',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          AccountListTile(
            title: 'Archive',
            icon: Icons.archive_outlined,
            onTap: () => context.push(ArchiveScreen.kRouteName),
          ),
          AccountListTile(
            title: 'Trash',
            icon: Icons.delete_outline,
            onTap: () => context.push(TrashScreen.kRouteName),
          ),
          AccountListTile(
            title: 'Tags',
            icon: Icons.label_outline,
            onTap: () => context.push(TagsScreen.kRouteName),
          ),
          AccountListTile(
            title: 'Sync',
            icon: Icons.sync_outlined,
            onTap: () => context.push(SyncScreen.kRouteName),
          ),
          AccountListTile(
            title: 'Import Note',
            icon: Icons.file_upload_outlined,
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pinpoint-note'],
              );
              if (result != null) {
                final file = File(result.files.single.path!);
                final jsonString = await file.readAsString();
                await DriftNoteService.importNoteFromJson(jsonString);
                final ctx = context;
                if (ctx.mounted) {
                  showSuccessToast(
                      context: ctx,
                      title: 'Note Imported',
                      description: 'The note has been successfully imported.');
                }
              }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child:
                Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          AccountListTile(
            title: 'Theme',
            icon: Icons.color_lens_outlined,
            onTap: () => context.push(ThemeScreen.kRouteName),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child:
                Text('Home Screen', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('Use Grid View'),
            value: _viewType == 'grid',
            onChanged: (value) {
              _setViewType(value ? 'grid' : 'list');
            },
            secondary: const Icon(Icons.grid_view_outlined),
          ),
          ListTile(
            leading: const Icon(Icons.sort_outlined),
            title: const Text('Sort by'),
            trailing: DropdownButton<String>(
              value: _sortType,
              items: const [
                DropdownMenuItem(value: 'updatedAt', child: Text('Last Modified')),
                DropdownMenuItem(value: 'createdAt', child: Text('Date Created')),
                DropdownMenuItem(value: 'title', child: Text('Title')),
              ],
              onChanged: _setSortType,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sort_by_alpha_outlined),
            title: const Text('Sort Direction'),
            trailing: DropdownButton<String>(
              value: _sortDirection,
              items: const [
                DropdownMenuItem(value: 'desc', child: Text('Descending')),
                DropdownMenuItem(value: 'asc', child: Text('Ascending')),
              ],
              onChanged: _setSortDirection,
            ),
          ),
        ],
      ),
    );
  }
}
