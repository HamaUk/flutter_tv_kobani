import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

import '../main.dart';
import '../services/login_codes_service.dart';

class Login extends ConsumerStatefulWidget {
  const Login({super.key});

  @override
  ConsumerState<Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<Login> {
  String _code = '';
  bool _isLoading = false;
  String _errorMessage = '';

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_keyboardFocusNode);
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final isValid = await LoginCodesService.validate(_code);

      if (isValid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("auth_code", _code);
        
        if (mounted) {
          this.ref.read(authCodeProvider.notifier).state = _code;
          this.ref.read(authStateProvider.notifier).state = true;
        }
      } else {
        setState(() => _errorMessage = 'Invalid code. Please try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error. Check your internet.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onKeyPress(String key) {
    setState(() {
      _errorMessage = '';
      if (key == 'DEL') {
        if (_code.isNotEmpty) {
          _code = _code.substring(0, _code.length - 1);
        }
      } else if (key == 'CLR') {
        _code = '';
      } else {
        if (_code.length < 15) { // reasonable limit for code
          _code += key;
        }
      }
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final keyLabel = event.logicalKey.keyLabel;
      if (keyLabel != null && keyLabel.length == 1 && int.tryParse(keyLabel) != null) {
        _onKeyPress(keyLabel);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.backspace || 
                 event.logicalKey == LogicalKeyboardKey.delete) {
        _onKeyPress('DEL');
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                 event.logicalKey == LogicalKeyboardKey.enter) {
        if (!_isLoading && _code.isNotEmpty) {
          _login();
        }
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          final keyLabel = event.logicalKey.keyLabel;
          if (keyLabel != null && keyLabel.length == 1 && int.tryParse(keyLabel) != null) {
            _onKeyPress(keyLabel);
          } else if (event.logicalKey == LogicalKeyboardKey.backspace || event.logicalKey == LogicalKeyboardKey.delete) {
            _onKeyPress('DEL');
          }
        }
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF17262A), Color(0xFF213333), Color(0xFF17262A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: 800,
                    height: 400,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        // Left Side: Branding and Display
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'KOBANI 4K',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Enter your activation code',
                                style: TextStyle(fontSize: 16, color: Colors.white54),
                              ),
                              const SizedBox(height: 32),
                              
                              // Code Display Box
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _code.isEmpty ? Colors.transparent : Colors.amber),
                                ),
                                child: Text(
                                  _code.isEmpty ? 'Tap keys to enter code' : _code,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                    color: _code.isEmpty ? Colors.white24 : Colors.amber,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              if (_errorMessage.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                                  ),
                                ),
                              
                              // Login Button
                              _FocusableButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading 
                                    ? const SizedBox(
                                        height: 24, width: 24, 
                                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                                      )
                                    : const Text(
                                        'LOGIN NOW',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1.5),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 60),
                        
                        // Right Side: Custom Numeric Keypad
                        SizedBox(
                          width: 280,
                          child: GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.2,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (var i = 1; i <= 9; i++) 
                                _KeypadButton(
                                  text: '$i', 
                                  onPressed: () => _onKeyPress('$i')
                                ),
                              _KeypadButton(
                                text: 'CLR', 
                                onPressed: () => _onKeyPress('CLR'),
                                color: Colors.redAccent.withOpacity(0.2),
                                textColor: Colors.redAccent,
                              ),
                              _KeypadButton(
                                text: '0', 
                                onPressed: () => _onKeyPress('0')
                              ),
                              _KeypadButton(
                                icon: Icons.backspace_rounded, 
                                onPressed: () => _onKeyPress('DEL'),
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ],
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
    );
  }
}

class _KeypadButton extends StatefulWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;

  const _KeypadButton({
    this.text,
    this.icon,
    required this.onPressed,
    this.color,
    this.textColor,
  });

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isFocused 
                ? Colors.amber 
                : (widget.color ?? Colors.white.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.white.withOpacity(0.1),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused ? [const BoxShadow(color: Colors.amber, blurRadius: 10)] : [],
          ),
          alignment: Alignment.center,
          child: widget.icon != null
              ? Icon(
                  widget.icon, 
                  color: _isFocused ? Colors.black : Colors.white70,
                )
              : Text(
                  widget.text!,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isFocused ? Colors.black : (widget.textColor ?? Colors.white),
                  ),
                ),
        ),
      ),
    );
  }
}

class _FocusableButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _FocusableButton({
    required this.onPressed,
    required this.child,
  });

  @override
  State<_FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<_FocusableButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          if (widget.onPressed != null) widget.onPressed!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _isFocused ? Colors.amber : Colors.amber.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isFocused 
                ? [const BoxShadow(color: Colors.amber, blurRadius: 15, spreadRadius: 2)] 
                : [],
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
