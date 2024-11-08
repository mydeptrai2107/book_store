import 'package:book_store/theme.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shimmer/shimmer.dart';

class ProfileLoadingPage extends StatelessWidget {
  const ProfileLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: themeColor,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: Shimmer.fromColors(
                baseColor: baseShimmer,
                highlightColor: highlightShimmer,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 4,
            ),
            Expanded(
              child: SizedBox(
                height: 62,
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 14,
                        ),
                        Shimmer.fromColors(
                          baseColor: baseShimmer,
                          highlightColor: highlightShimmer,
                          child: Container(
                            width: 120,
                            height: 19,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chỉnh sửa tài khoản',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      icon: FaIcon(
                        size: 14,
                        FontAwesomeIcons.penToSquare,
                        color: themeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
