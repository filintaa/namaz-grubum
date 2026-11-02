import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import '../theme/app_theme.dart';

class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    required this.body,
    this.title,
    this.trailing,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget body;
  final String? title;
  final Widget? trailing;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isCupertino) {
      return CupertinoPageScaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        navigationBar: title == null
            ? null
            : CupertinoNavigationBar(
                middle: Text(title!),
                trailing: trailing,
                automaticBackgroundVisibility: false,
                backgroundColor: AppColors.warmWhite,
                border: const Border(
                  bottom: BorderSide(color: AppColors.line, width: .5),
                ),
              ),
        child: SafeArea(top: title == null, child: body),
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              actions: trailing == null ? null : <Widget>[trailing!],
              surfaceTintColor: Colors.transparent,
              backgroundColor: AppColors.warmWhite,
            ),
      body: body,
    );
  }
}

class AdaptivePrimaryButton extends StatelessWidget {
  const AdaptivePrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 19),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );
    if (PlatformInfo.isCupertino) {
      return CupertinoButton.filled(
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        borderRadius: BorderRadius.circular(99),
        child: child,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: expanded ? const Size.fromHeight(56) : const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: const StadiumBorder(),
      ),
      child: child,
    );
  }
}

class AdaptiveSecondaryButton extends StatelessWidget {
  const AdaptiveSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 7),
        ],
        Text(label),
      ],
    );
    if (PlatformInfo.isCupertino) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: child,
      );
    }
    return TextButton(onPressed: onPressed, child: child);
  }
}

class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField({
    this.controller,
    this.placeholder,
    this.prefixIcon,
    this.onChanged,
    this.keyboardType,
    super.key,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isCupertino) {
      return CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        prefix: prefixIcon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(prefixIcon, color: AppColors.muted, size: 20),
              ),
        onChanged: onChanged,
        keyboardType: keyboardType,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.mist,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
      );
    }
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: placeholder,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.brown,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
      ),
      ?action,
    ],
  );
}
