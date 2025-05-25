import 'package:flutter/material.dart';
import 'package:eoreporter_v1/constants/app_constants.dart';

class UserAvatar extends StatelessWidget {
  final String? fullName;
  final String? email;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.fullName,
    this.email,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.onTap,
  });

  String _getInitials() {
    if (fullName != null && fullName!.isNotEmpty) {
      final names = fullName!.trim().split(' ');
      if (names.length >= 2) {
        return '${names[0][0]}${names[1][0]}'.toUpperCase();
      } else if (names.isNotEmpty) {
        return names[0][0].toUpperCase();
      }
    }
    
    if (email != null && email!.isNotEmpty) {
      return email![0].toUpperCase();
    }
    
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials();
    final defaultFontSize = radius * 0.8;

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppConstants.primaryColor,
      child: Text(
        initials,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: fontSize ?? defaultFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
} 