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

showSuccessToast({
  required BuildContext context,
  required String title,
  required String description,
}) =>
    toastification.show(
      context: context,
      title: Text(title),
      description: Text(description),
      style: ToastificationStyle.flat,
      type: ToastificationType.success,
      autoCloseDuration: Duration(seconds: 2),
    );

showWarningToast({
  required BuildContext context,
  required String title,
  required String description,
}) =>
    toastification.show(
      context: context,
      title: Text(title),
      description: Text(description),
      style: ToastificationStyle.flat,
      type: ToastificationType.warning,
      autoCloseDuration: Duration(seconds: 2),
    );

showErrorToast({
  required BuildContext context,
  required String title,
  required String description,
}) =>
    toastification.show(
      context: context,
      title: Text(title),
      description: Text(description),
      style: ToastificationStyle.flat,
      type: ToastificationType.error,
      autoCloseDuration: Duration(seconds: 2),
    );
