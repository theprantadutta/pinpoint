import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../services/drift_note_folder_service.dart';

class HomeScreenFolderList extends StatelessWidget {
  const HomeScreenFolderList({super.key});

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return StreamBuilder(
      stream: DriftNoteFolderService.watchAllNoteFoldersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HomeScreenFolderListSkeletonizer();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Something Went Wrong'),
          );
        }
        final noteFoldersData = snapshot.data!;
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
                margin: EdgeInsets.only(right: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.folder,
                      size: MediaQuery.sizeOf(context).height * 0.045,
                    ),
                    Text(
                      currentFolder.noteFolderTitle,
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
      },
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
