import 'package:flutter/material.dart';
import '../config/theme.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0, 0.0),
              end: Alignment(1.0, 0.0),
              colors: [
                AppTheme.mediumBlack,
                AppTheme.mediumBlack.withOpacity(0.5),
                AppTheme.mediumBlack,
              ],
              stops: [
                (_animationController.value - 0.3).clamp(0.0, 1.0),
                _animationController.value.clamp(0.0, 1.0),
                (_animationController.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppTheme.mediumBlack,
              borderRadius: widget.borderRadius,
            ),
          ),
        );
      },
    );
  }
}

class HeroSkeletonLoader extends StatelessWidget {
  const HeroSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SkeletonLoader(
          width: double.infinity,
          height: 400,
          borderRadius: const BorderRadius.all(Radius.circular(0)),
        ),
        const SizedBox(height: 16),
        // Dots pagination
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SkeletonLoader(
                width: index == 0 ? 24 : 8,
                height: 8,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MovieListSkeletonLoader extends StatelessWidget {
  final int itemCount;

  const MovieListSkeletonLoader({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: 130,
                  height: 195,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                const SizedBox(height: 8),
                SkeletonLoader(
                  width: 130,
                  height: 12,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 6),
                SkeletonLoader(
                  width: 100,
                  height: 12,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DetailsPageSkeletonLoader extends StatelessWidget {
  const DetailsPageSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Backdrop
          SkeletonLoader(
            width: double.infinity,
            height: 300,
            borderRadius: const BorderRadius.all(Radius.circular(0)),
          ),
          const SizedBox(height: 24),
          // Title and metadata
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: double.infinity,
                  height: 28,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 12),
                SkeletonLoader(
                  width: 150,
                  height: 16,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SkeletonLoader(
                        width: double.infinity,
                        height: 48,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SkeletonLoader(
                      width: 48,
                      height: 48,
                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                    ),
                    const SizedBox(width: 12),
                    SkeletonLoader(
                      width: 48,
                      height: 48,
                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Genres/chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SkeletonLoader(
                    width: 80,
                    height: 32,
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Overview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: 80,
                  height: 20,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 12),
                SkeletonLoader(
                  width: double.infinity,
                  height: 14,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 8),
                SkeletonLoader(
                  width: double.infinity,
                  height: 14,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 8),
                SkeletonLoader(
                  width: 200,
                  height: 14,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Cast section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: 60,
                  height: 20,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            SkeletonLoader(
                              width: 90,
                              height: 90,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(45),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SkeletonLoader(
                              width: 90,
                              height: 12,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
