import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Form data
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String _gender = 'male';

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveProfile();
    }
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 0:
        return _nameController.text.trim().isNotEmpty;
      case 1:
        final age = int.tryParse(_ageController.text);
        final weight = double.tryParse(_weightController.text);
        final height = double.tryParse(_heightController.text);
        if (age == null || weight == null || height == null) return false;
        if (age < 13 || age > 120) return false;
        if (weight < 20 || weight > 500) return false;
        if (height < 50 || height > 300) return false;
        return true;
      case 2:
        return true;
      default:
        return false;
    }
  }

  String? _getValidationError() {
    if (_currentPage != 1) return null;
    final ageText = _ageController.text;
    final weightText = _weightController.text;
    final heightText = _heightController.text;

    if (ageText.isEmpty && weightText.isEmpty && heightText.isEmpty) {
      return null; // Don't show errors before user starts typing
    }

    final age = int.tryParse(ageText);
    final weight = double.tryParse(weightText);
    final height = double.tryParse(heightText);

    if (ageText.isNotEmpty && age == null) return 'Age must be a whole number';
    if (age != null && (age < 13 || age > 120)) return 'Age must be between 13 and 120';
    if (weightText.isNotEmpty && weight == null) return 'Weight must be a number';
    if (weight != null && (weight < 20 || weight > 500)) return 'Weight must be between 20 and 500 kg';
    if (heightText.isNotEmpty && height == null) return 'Height must be a number';
    if (height != null && (height < 50 || height > 300)) return 'Height must be between 50 and 300 cm';
    return null;
  }

  Future<void> _saveProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final uid = authService.uid;
    if (uid == null) return;

    final weight = double.tryParse(_weightController.text) ?? 70.0;
    final height = double.tryParse(_heightController.text) ?? 170.0;
    final age = int.tryParse(_ageController.text) ?? 25;

    // Safety net: clamp values to valid bounds
    final clampedAge = age.clamp(13, 120);
    final clampedWeight = weight.clamp(20.0, 500.0);
    final clampedHeight = height.clamp(50.0, 300.0);

    // AI-suggested targets based on user profile
    final calorieTarget = calculateDailyCalorieTarget(
      weightKg: clampedWeight,
      heightCm: clampedHeight,
      age: clampedAge,
      gender: _gender,
    );
    final proteinTarget = calculateDailyProteinTarget(clampedWeight);

    final user = UserModel(
      uid: uid,
      name: _nameController.text.trim(),
      age: clampedAge,
      weight: clampedWeight,
      height: clampedHeight,
      gender: _gender,
      dailyCalorieTarget: calorieTarget,
      dailyProteinTarget: proteinTarget,
      pushupTarget: 10,
    );

    try {
      await userProvider.saveProfile(user);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userProvider.error ?? 'Could not save your profile. Please retry.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? AppTheme.primaryColor
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _buildNamePage(),
                  _buildBodyStatsPage(),
                  _buildGenderPage(),
                ],
              ),
            ),

            // Next button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  return ElevatedButton(
                    onPressed: userProvider.isLoading
                        ? null
                        : (_canProceed() ? _nextPage : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: userProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _currentPage == 2 ? 'Get Started 🚀' : 'Next',
                            style: const TextStyle(fontSize: 18),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'Welcome! 👋',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Let's set up your profile",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 48),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person_outline),
              hintText: 'Enter your name',
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyStatsPage() {
    final validationError = _getValidationError();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'Body Stats 📊',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This helps us calculate your nutrition targets',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                prefixIcon: Icon(Icons.cake_outlined),
                suffixText: 'years',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight',
                prefixIcon: Icon(Icons.monitor_weight_outlined),
                suffixText: 'kg',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _heightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Height',
                prefixIcon: Icon(Icons.height),
                suffixText: 'cm',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (validationError != null) ...[
              const SizedBox(height: 12),
              Text(
                validationError,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGenderPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'One last thing 🎯',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'For accurate calorie calculations',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 48),
          _genderOption('male', 'Male', Icons.male),
          const SizedBox(height: 12),
          _genderOption('female', 'Female', Icons.female),
          const SizedBox(height: 12),
          _genderOption('other', 'Prefer not to say', Icons.person_outline),
        ],
      ),
    );
  }

  Widget _genderOption(String value, String label, IconData icon) {
    final isSelected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : null,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
