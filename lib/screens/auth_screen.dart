import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../extensions/string_extensions.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _email = '';
  String _password = '';
  String _username = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _usernameFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      _formKey.currentState?.reset();
    });
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await _authService.signInWithEmailAndPassword(
          _email.trim(),
          _password.trim(),
        );
      } else {
        await _authService.createAccountWithEmailAndPassword(
          _email.trim(),
          _password.trim(),
          _username.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'no account found with this email';
          break;
        case 'wrong-password':
          message = 'incorrect password';
          break;
        case 'email-already-in-use':
          message = 'email is already registered';
          break;
        case 'weak-password':
          message = 'password is too weak';
          break;
        case 'invalid-email':
          message = 'invalid email address';
          break;
        default:
          message = e.message ?? 'an error occurred';
      }
      if (mounted) {
        setState(() {
          _errorMessage = message.toLowerCase();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().toLowerCase();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppColors.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Background that extends edge to edge
            Container(color: AppColors.background),
            
            // Content that respects safe area
            SafeArea(
              bottom: false,
              child: Container(
                color: AppColors.background,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left side - Logo
                        SizedBox(
                          width: 200,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.video_library,
                                    size: 48,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'TikBlok',
                                    style: theme.textTheme.displayMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Right side - Form
                        Flexible(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: _buildFormFields(context),
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

  Widget _buildFormFields(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isLogin) ...[
                  TextFormField(
                    focusNode: _usernameFocusNode,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'username'.toLowerCase(),
                      labelStyle: TextStyle(color: AppColors.textPrimary),
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                    ),
                    onSaved: (value) => _username = value ?? '',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'required';
                      }
                      if (!_authService.isValidUsername(value)) {
                        return '3-8 alphanumeric characters';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_emailFocusNode);
                    },
                    style: TextStyle(color: AppColors.accent),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'email'.toLowerCase(),
                    labelStyle: TextStyle(color: AppColors.textPrimary),
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                  ),
                  onSaved: (value) => _email = value ?? '',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'required';
                    }
                    if (!value.contains('@')) {
                      return 'invalid email';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                  },
                  style: TextStyle(color: AppColors.accent),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'password'.toLowerCase(),
                    labelStyle: TextStyle(color: AppColors.textPrimary),
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  onSaved: (value) => _password = value ?? '',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'required';
                    }
                    if (!_isLogin && value.length < 6) {
                      return 'min 6 characters';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                  style: TextStyle(color: AppColors.accent),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : Text(_isLogin ? 'sign in' : 'sign up'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : _toggleAuthMode,
                  child: Text(
                    _isLogin ? 'create account' : 'sign in instead',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 