import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

const kTitleTextStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: Colors.white,
);

const kDescriptionTextStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: Colors.white,
);

void showSuccessToast({
  required BuildContext context,
  required String title,
  required String description,
}) =>
    toastification.show(
      context: context,
      title: Text(title),
      description: Text(description),
      style: ToastificationStyle.flatColored,
      type: ToastificationType.success,
      autoCloseDuration: Duration(seconds: 4),
    );

void showWarningToast({
  required BuildContext context,
  required String title,
  required String description,
}) =>
    toastification.show(
      context: context,
      title: Text(title),
      description: Text(description),
      style: ToastificationStyle.flatColored,
      type: ToastificationType.warning,
      autoCloseDuration: Duration(seconds: 4),
    );

void showErrorToast({
  required BuildContext context,
  required String title,
  required String description,
}) =>
    toastification.show(
      context: context,
      title: Text(title),
      description: Text(description),
      style: ToastificationStyle.flatColored,
      type: ToastificationType.error,
      autoCloseDuration: Duration(seconds: 4),
    );
