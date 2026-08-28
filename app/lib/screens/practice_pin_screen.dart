import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/child.dart';
import '../services/api_service.dart';
import 'practice_subject_screen.dart';

class PracticePinScreen extends StatefulWidget {
  final ApiService apiService;
  final Child child;

  const PracticePinScreen({super.key, required this.apiService, required this.child});

  @override
  State<PracticePinScreen> createState() => _PracticePinScreenState();
}

class _PracticePinScreenState extends State<PracticePinScreen> {
  final _pinController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text;
    if (pin.length != 4) {
      setState(() => _error = 'יש להזין קוד בן 4 ספרות');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final session = await widget.apiService.startChildSession(
        childId: widget.child.id,
        pin: pin,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PracticeSubjectScreen(session: session),
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = 'קוד שגוי, נסו שוב';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('שלום, ${widget.child.name}!')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 16),
              const Text('הזינו את קוד ה-PIN שלכם כדי להתחיל תרגול',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                autofocus: true,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, letterSpacing: 16),
                decoration: InputDecoration(
                  counterText: '',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('כניסה'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
