import 'package:flutter/material.dart';

class RecordTypeContent extends StatelessWidget {
  const RecordTypeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 10,
        ),
        height: MediaQuery.sizeOf(context).height * 0.67,
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text('record'),
        ),
      ),
    );
  }
}
