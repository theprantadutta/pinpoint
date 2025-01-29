import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../constants/fquery_keys.dart';

class HomeScreenFolderList extends HookWidget {
  const HomeScreenFolderList({super.key});

  @override
  Widget build(BuildContext context) {
    final noteFolders =
        useQuery([kNoteFoldersKey], DriftNoteFolderService.getAllNoteFolders);
    final kPrimaryColor = Theme.of(context).primaryColor;

    if (noteFolders.isLoading) {
      return HomeScreenFolderListSkeletonizer();
    }

    if (noteFolders.isError) {
      return Center(
        child: Text('Something Went Wrong'),
      );
    }

    final noteFoldersData = noteFolders.data!;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.11,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: noteFoldersData.length,
        itemBuilder: (context, index) {
          final currentFolder = noteFoldersData[index];
          return Container(
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            width: MediaQuery.sizeOf(context).width * 0.25,
            margin: const EdgeInsets.only(right: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Symbols.folder,
                  size: MediaQuery.sizeOf(context).height * 0.045,
                ),
                Text(
                  currentFolder.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w200,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class HomeScreenFolderListSkeletonizer extends StatelessWidget {
  const HomeScreenFolderListSkeletonizer({super.key});

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Skeletonizer(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.11,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              width: MediaQuery.sizeOf(context).width * 0.25,
              margin: const EdgeInsets.only(right: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Symbols.folder,
                    size: MediaQuery.sizeOf(context).height * 0.045,
                  ),
                  Text(
                    'HomeWork',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w200,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
