import 'package:choice/choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fquery/fquery.dart';

import '../../constants/fquery_keys.dart';
import '../../services/drift_note_folder_service.dart';

class CreateNoteFolderSelect extends HookWidget {
  final List<String> selectedFolders;
  final Function(List<String> folders) setSelectedFolders;

  const CreateNoteFolderSelect({
    super.key,
    required this.selectedFolders,
    required this.setSelectedFolders,
  });

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final noteFolders =
        useQuery([kNoteFoldersKey], DriftNoteFolderService.getAllNoteFolders);
    if (noteFolders.isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.8,
          height: MediaQuery.sizeOf(context).height * 0.07,
          margin: EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(),
        ),
      );
    }

    if (noteFolders.isError) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text('Something Went Wrong'),
        ),
      );
    }
    final noteFolderData = noteFolders.data!;

    return SliverToBoxAdapter(
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.8,
        height: MediaQuery.sizeOf(context).height * 0.07,
        margin: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: PromptedChoice<String>.multiple(
              title: 'Folder',
              clearable: true,
              confirmation: true,
              searchable: true,
              value: selectedFolders,
              onChanged: setSelectedFolders,
              itemCount: noteFolderData.length,
              itemSkip: (state, i) => !ChoiceSearch.match(
                noteFolderData[i].title,
                state.search?.value,
              ),
              itemBuilder: (state, i) {
                final title = noteFolderData[i].title;
                return CheckboxListTile(
                  value: state.selected(title),
                  onChanged: state.onSelected(title),
                  title: ChoiceText(
                    title,
                    highlight: state.search?.value,
                  ),
                );
              },
              listBuilder: ChoiceList.createWrapped(
                padding: const EdgeInsets.all(15),
                spacing: 0,
                runSpacing: 0,
              ),
              modalHeaderBuilder: ChoiceModal.createHeader(
                automaticallyImplyLeading: false,
                actionsBuilder: [
                  ChoiceModal.createConfirmButton(),
                ],
              ),
              anchorBuilder: ChoiceAnchor.create(inline: true),
            ),
          ),
        ),
      ),
    );
  }
}
