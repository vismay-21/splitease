import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    required this.nextPage,
    this.onGetStarted,
    super.key,
  });

  final Widget nextPage;
  final VoidCallback? onGetStarted;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _wordmarkPath = 'assets/images/batvaara_wordmark.png';

  late final AnimationController _titlePopController;
  late final Animation<double> _titlePopScale;
  late final Animation<double> _titlePopOpacity;

  bool _showContent = false;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();

    _titlePopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      reverseDuration: const Duration(milliseconds: 360),
    );

    _titlePopScale = Tween<double>(begin: 0.52, end: 1).animate(
      CurvedAnimation(parent: _titlePopController, curve: Curves.easeOutBack),
    );

    _titlePopOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _titlePopController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _showContent = true;
        });
        _titlePopController.forward();
      }
    });
  }

  Future<void> _onGetStarted() async {
    if (_isTransitioning) {
      return;
    }

    setState(() {
      _isTransitioning = true;
    });

    await _titlePopController.reverse();

    if (!mounted) {
      return;
    }

    if (widget.onGetStarted != null) {
      widget.onGetStarted!();
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => widget.nextPage));
  }

  @override
  void dispose() {
    _titlePopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE7F3FF), Color(0xFFDFF0FF), Color(0xFFF7FBFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -40,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4CA3EB).withValues(alpha: 0.16),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8CC8F7).withValues(alpha: 0.2),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSlide(
                              offset: _showContent
                                  ? Offset.zero
                                  : const Offset(0, 0.06),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity: _showContent ? 1 : 0,
                                duration: const Duration(milliseconds: 520),
                                child: AnimatedBuilder(
                                  animation: _titlePopController,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: _titlePopOpacity.value,
                                      child: Transform.scale(
                                        scale: _titlePopScale.value,
                                        alignment: Alignment.center,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      shape: BoxShape.circle,
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x290F5E9E),
                                          blurRadius: 20,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'web/icons/Icon-512.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.wallet_rounded,
                                            size: 42,
                                            color: Color(0xFF1D6CAB),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            AnimatedSlide(
                              offset: _showContent
                                  ? Offset.zero
                                  : const Offset(0, 0.09),
                              duration: const Duration(milliseconds: 760),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity: _showContent ? 1 : 0,
                                duration: const Duration(milliseconds: 620),
                                child: AnimatedBuilder(
                                  animation: _titlePopController,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: _titlePopOpacity.value,
                                      child: Transform.scale(
                                        scale: _titlePopScale.value,
                                        alignment: Alignment.center,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: [
                                      Text(
                                        'Welcome to',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.headlineMedium?.copyWith(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.8,
                                          color: const Color(0xFF163A58),
                                          height: 1.15,
                                        ),
                                      ),
                                      Image.asset(
                                        _wordmarkPath,
                                        height: 40,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Text(
                                            'BATVAARA',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.headlineMedium
                                                ?.copyWith(
                                                  fontSize: 40,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.3,
                                                  color: const Color(0xFF2E5D36),
                                                ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            AnimatedSlide(
                              offset: _showContent
                                  ? Offset.zero
                                  : const Offset(0, 0.12),
                              duration: const Duration(milliseconds: 840),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity: _showContent ? 1 : 0,
                                duration: const Duration(milliseconds: 720),
                                child: AnimatedBuilder(
                                  animation: _titlePopController,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: _titlePopOpacity.value,
                                      child: Transform.scale(
                                        scale: _titlePopScale.value,
                                        alignment: Alignment.center,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Split bills in seconds, track shared expenses, and settle up with your friends without confusion.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: 16,
                                      color: const Color(0xFF4A6783),
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSlide(
                      offset: _showContent ? Offset.zero : const Offset(0, 0.2),
                      duration: const Duration(milliseconds: 920),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: _showContent ? 1 : 0,
                        duration: const Duration(milliseconds: 780),
                        child: AnimatedBuilder(
                          animation: _titlePopController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _titlePopOpacity.value,
                              child: Transform.scale(
                                scale: _titlePopScale.value,
                                alignment: Alignment.center,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x21176AA9),
                                  blurRadius: 22,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Track. Split. Settle.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF17324D),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isTransitioning ? null : _onGetStarted,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(54),
                                      backgroundColor: const Color(0xFF1D6CAB),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Get Started',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
