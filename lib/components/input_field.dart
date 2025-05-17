import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class InputField extends StatelessWidget {
  final String label;
  final String hintText;
  final bool hideText;
  final Widget fieldIcon;
  final TextEditingController? controller; // Add controller
  final String? Function(String?)? validator; // Add validator

  const InputField({
    Key? key,
    required this.label,
    required this.hintText,
    required this.hideText,
    required this.fieldIcon,
    this.controller,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          obscureText: hideText,
          style: GoogleFonts.poppins(fontSize: 14.sp),
          decoration: InputDecoration(
            prefixIcon: fieldIcon,
            hintText: hintText,
            isDense: true,
            prefixIconConstraints: BoxConstraints(
              minWidth: 35.w,
              maxWidth: 35.w,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 10.w,
              vertical: 12.h,
            ),
          ),
          validator: validator, // Set the validator
        ),
      ],
    );
  }
}
