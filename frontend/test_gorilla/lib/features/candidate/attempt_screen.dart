import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/storage/access_code_storage.dart';
import 'package:test_gorilla/core/storage/attempt_storage.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';
import 'package:test_gorilla/core/utils/before_unload.dart';
import 'package:test_gorilla/features/candidate/test_service.dart';
import 'package:test_gorilla/features/shared/models/models.dart';
import 'package:test_gorilla/features/shared/widgets/app_widgets.dart'
    as app_widgets;

class AttemptScreen extends StatefulWidget {
  final Test test;
  final String accessCode;

  /// Optional: if resuming from storage, pass the attemptId directly
  final String? resumeAttemptId;

  const AttemptScreen({
    Key? key,
    required this.test,
    this.accessCode = '',
    this.resumeAttemptId,
  }) : super(key: key);

  @override
  State<AttemptScreen> createState() => _AttemptScreenState();
}

class _AttemptScreenState extends State<AttemptScreen>
    with WidgetsBindingObserver {
  late TestService _testService;

  // --- Questions ---
  List<Question> _questionsCache = [];
  int _currentQuestionIndex = 0;

  // --- Attempt data from backend ---
  String? _attemptId;
  DateTime? _startTime;
  int _durationMinutes = 60;
  String _attemptStatus = 'in_progress';

  // --- Server-authoritative timer ---
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _timeExpired = false;

  // --- Audio / low-timer warning ---
  final AudioPlayer _lowTimerWarningPlayer = AudioPlayer();
  bool _hasPlayedLowTimerWarning = false;
  bool _hasShownLowTimerFallbackNotice = false;
  bool _hasPlayedNativeToneFallback = false;
  bool _isAudioUnlockAttempted = false;
  bool _isLowTimerWarningPendingAudioUnlock = false;

  // --- Answers ---
  Map<String, String> _answers = {};
  final Map<String, TextEditingController> _codeControllers = {};

  // --- Loading states ---
  bool _isLoading = false;
  bool _isSubmittingResponse = false;
  bool _isInitializing = true;
  String? _initError;

  // --- Blocked state (409 or other permanent block) ---
  bool _isBlocked = false;
  String _blockedMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final apiClient = context.read<ApiClient>();
    _testService = TestService(apiClient);
    unawaited(_primeLowTimerWarningAudio());
    _loadQuestions();
    _initializeAttempt();
  }

  // ── Lifecycle: detect app resume / browser refresh ──

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _attemptId != null) {
      // Re-sync with backend on app resume
      unawaited(_syncAttemptFromBackend());
    }
  }

  // ── Browser refresh warning (JS interop) ──

  void _setupBeforeUnloadWarning() {
    if (_attemptStatus != 'in_progress') return;
    BeforeUnloadHandler.enableWarning();
  }

  void _removeBeforeUnloadWarning() {
    BeforeUnloadHandler.disableWarning();
  }

  @override
  void dispose() {
    _removeBeforeUnloadWarning();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_lowTimerWarningPlayer.dispose());
    for (final controller in _codeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ── Fetch questions ──

  Future<void> _loadQuestions() async {
    try {
      _questionsCache = await _testService.getTestQuestions(widget.test.id);
    } catch (_) {
      // Will be shown in UI
    }
  }

  // ── Initialization: start or resume ──

  Future<void> _initializeAttempt() async {
    try {
      String code = widget.accessCode;
      if (code.isEmpty) {
        code = (await AccessCodeStorage.getCode(widget.test.id)) ?? '';
      }

      Map<String, dynamic> data;

      if (widget.resumeAttemptId != null) {
        // Resume existing attempt
        data = await _testService.getAttempt(widget.resumeAttemptId!);
      } else {
        // Start new attempt (backend handles idempotency)
        data = await _testService.startAttempt(
          widget.test.id,
          accessCode: code,
        );
      }

      _applyAttemptData(data);
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        if (!mounted) return;
        setState(() {
          _isBlocked = true;
          _blockedMessage =
              'This test has already been submitted or is no longer available.';
          _isInitializing = false;
        });
        return;
      }
      if (mounted) {
        setState(() {
          _initError = e.toString();
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
          _isInitializing = false;
        });
      }
    }
  }

  /// Parse attempt data from backend and set up timer + navigation state
  void _applyAttemptData(Map<String, dynamic> data) {
    final attempt = data['attempt'] as Map<String, dynamic>?;
    if (attempt == null) {
      setState(() {
        _initError = 'Invalid attempt data from server';
        _isInitializing = false;
      });
      return;
    }

    final status = (attempt['status'] as String?) ?? 'in_progress';

    // If already completed, go straight to results
    if (status == 'submitted' || status == 'completed') {
      _attemptId = attempt['id'] as String?;
      _removeBeforeUnloadWarning();
      if (_attemptId != null && mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed('/candidate/result', arguments: _attemptId);
      }
      return;
    }

    // Parse timing
    final startTimeStr =
        data['start_time'] as String? ?? attempt['start_time'] as String?;
    final durationMinutes =
        data['duration'] as int? ?? widget.test.durationMinutes;

    _attemptId = attempt['id'] as String?;
    _attemptStatus = status;
    _durationMinutes = durationMinutes;

    if (startTimeStr != null) {
      _startTime = DateTime.tryParse(startTimeStr)?.toUtc();
    }
    _startTime ??= DateTime.now().toUtc();

    // Parse current question index
    final idx = data['current_question_index'];
    if (idx is int && idx >= 0) {
      _currentQuestionIndex = idx;
    }

    // ── Restore answers from backend responses ──
    _restoreAnswersFromResponses(data['responses']);

    // Persist to local storage
    if (_attemptId != null) {
      unawaited(
        AttemptStorage.setActiveAttempt(
          attemptId: _attemptId!,
          testId: widget.test.id,
          durationMinutes: _durationMinutes,
        ),
      );
    }

    // Compute remaining time from server data
    _recomputeRemainingTime();

    if (!mounted) return;
    setState(() {
      _isInitializing = false;
    });
    _startTimer();
    _setupBeforeUnloadWarning();
  }

  /// Restore user answers from backend responses.
  /// Maps responses like:
  ///   { question_id: "abc", selected_option_id: "xyz" }  →  _answers["abc"] = "optionIndex"
  ///   { question_id: "def", code_answer: "some text" }   →  _answers["def"] = "some text"
  void _restoreAnswersFromResponses(dynamic responses) {
    if (responses is! List) return;

    // Build a quick lookup: optionId → option index for each question
    final optionIndexMap = <String, int>{};
    for (final q in _questionsCache) {
      if (q.options != null) {
        for (var i = 0; i < q.options!.length; i++) {
          optionIndexMap[q.options![i].id] = i;
        }
      }
    }

    final restored = <String, String>{};

    for (final r in responses) {
      if (r is! Map<String, dynamic>) continue;

      final questionId = r['question_id'] as String?;
      if (questionId == null) continue;

      // MCQ: selected_option_id → find its index
      final selectedOptionId = r['selected_option_id'] as String?;
      if (selectedOptionId != null) {
        final idx = optionIndexMap[selectedOptionId];
        if (idx != null) {
          restored[questionId] = idx.toString();
        }
      }

      // Coding/Essay: code_answer → text
      final codeAnswer = r['code_answer'] as String?;
      if (codeAnswer != null && codeAnswer.isNotEmpty) {
        restored[questionId] = codeAnswer;
      }
    }

    _answers = restored;

    // Populate code controllers for coding questions
    for (final entry in restored.entries) {
      final matching = _questionsCache.where((q) => q.id == entry.key);
      if (matching.isNotEmpty) {
        final q = matching.first;
        if (q.type == 'coding') {
          _codeControllers[q.id] = TextEditingController(text: entry.value);
        }
      }
    }
  }

  // ── Server-authoritative timer ──

  /// Compute remainingTime = endTime - now (in seconds)
  /// endTime = startTime + duration
  void _recomputeRemainingTime() {
    if (_startTime == null) {
      _remainingSeconds = _durationMinutes * 60;
      return;
    }

    final endTime = _startTime!.add(Duration(minutes: _durationMinutes));
    final now = DateTime.now().toUtc();
    _remainingSeconds = endTime.difference(now).inSeconds;

    if (_remainingSeconds < 0) {
      _remainingSeconds = 0;
    }
  }

  void _startTimer() {
    _timer?.cancel();

    // Do an initial sync with backend to get accurate time
    _recomputeRemainingTime();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Every 30 seconds, re-sync with backend
      if (_remainingSeconds > 0 && _remainingSeconds % 30 == 0) {
        unawaited(_syncAttemptFromBackend());
      }

      var shouldPlayLowTimerWarning = false;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        }

        final lowTimerWarningSeconds = _getLowTimerWarningSeconds();
        if (!_hasPlayedLowTimerWarning &&
            _remainingSeconds <= lowTimerWarningSeconds &&
            _remainingSeconds > 0) {
          shouldPlayLowTimerWarning = true;
        }
      });

      if (shouldPlayLowTimerWarning) {
        if (kIsWeb && !_isAudioUnlockAttempted) {
          _isLowTimerWarningPendingAudioUnlock = true;
        } else {
          _hasPlayedLowTimerWarning = true;
          _isLowTimerWarningPendingAudioUnlock = false;
          unawaited(_playLowTimerWarning());
        }
      }

      if (_remainingSeconds <= 0 && !_timeExpired) {
        _timeExpired = true;
        timer.cancel();
        _handleTimeExpired();
      }
    });
  }

  Future<void> _syncAttemptFromBackend() async {
    if (_attemptId == null) return;
    try {
      final data = await _testService.getAttempt(_attemptId!);
      final attempt = data['attempt'] as Map<String, dynamic>?;

      if (attempt != null) {
        final status = (attempt['status'] as String?) ?? '';
        if (status == 'submitted' || status == 'completed') {
          // Server auto-submitted
          _removeBeforeUnloadWarning();
          _timer?.cancel();
          if (mounted) {
            Navigator.of(
              context,
            ).pushReplacementNamed('/candidate/result', arguments: _attemptId);
          }
          return;
        }

        // Update timing from server
        final startTimeStr = data['start_time'] as String?;
        if (startTimeStr != null) {
          _startTime = DateTime.tryParse(startTimeStr)?.toUtc();
        }
        _recomputeRemainingTime();

        if (mounted) {
          setState(() {});
        }
      }
    } catch (_) {
      // Non-critical sync failure, timer continues locally
    }
  }

  Future<void> _handleTimeExpired() async {
    _removeBeforeUnloadWarning();
    _timer?.cancel();
    if (_attemptId == null || !mounted) return;

    try {
      await _testService.submitAttempt(_attemptId!);
    } catch (_) {
      // Best-effort submit on expiry
    }

    await AttemptStorage.clear();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacementNamed('/candidate/result', arguments: _attemptId);
    }
  }

  int _getLowTimerWarningSeconds() {
    final totalMinutes = _durationMinutes;
    if (totalMinutes >= 10) return 60;
    if (totalMinutes >= 5) return 30;
    return 10;
  }

  String _formatTimerDisplay(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // ── Answers ──

  TextEditingController _getCodeController(String questionId) {
    return _codeControllers.putIfAbsent(
      questionId,
      () => TextEditingController(text: _answers[questionId] ?? ''),
    );
  }

  void _selectAnswer(String questionId, String answerId) {
    setState(() {
      _answers[questionId] = answerId;
    });
    if (_attemptId == null || _isSubmittingResponse) return;
    _submitAnswer(questionId, answerId);
  }

  void _submitAnswer(String questionId, String answerId) async {
    if (_isSubmittingResponse || _attemptId == null) return;
    setState(() => _isSubmittingResponse = true);
    try {
      await _testService.submitResponse(
        _attemptId!,
        questionId: questionId,
        selectedOptionId: answerId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving answer: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingResponse = false);
      }
    }
  }

  Future<bool> _saveCodingAnswer(Question question) async {
    if (_attemptId == null || _isSubmittingResponse) return false;
    final controller = _getCodeController(question.id);
    final codeAnswer = controller.text;
    setState(() {
      _isSubmittingResponse = true;
      _answers[question.id] = codeAnswer;
    });
    try {
      await _testService.submitResponse(
        _attemptId!,
        questionId: question.id,
        codeAnswer: codeAnswer,
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving answer: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSubmittingResponse = false);
      }
    }
  }

  // ── Submission ──

  Future<void> _submitAttempt({Question? currentQuestion}) async {
    if (_isLoading || _attemptId == null) return;
    setState(() => _isLoading = true);
    _timer?.cancel();

    try {
      // Save current coding answer if any
      final questionToSave =
          currentQuestion ??
          (_questionsCache.isNotEmpty &&
                  _currentQuestionIndex < _questionsCache.length
              ? _questionsCache[_currentQuestionIndex]
              : null);

      if (questionToSave != null && questionToSave.type == 'coding') {
        final controller = _getCodeController(questionToSave.id);
        try {
          await _testService.submitResponse(
            _attemptId!,
            questionId: questionToSave.id,
            codeAnswer: controller.text,
          );
        } catch (_) {
          // Continue with submission
        }
      }

      await _testService.submitAttempt(_attemptId!);
      await AttemptStorage.clear();
      _removeBeforeUnloadWarning();

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed('/candidate/result', arguments: _attemptId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting test: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        // Restart timer on submission failure
        _recomputeRemainingTime();
        if (_remainingSeconds > 0) {
          _startTimer();
        }
      }
    }
  }

  Future<void> _confirmSubmitAttempt({Question? currentQuestion}) async {
    if (_isLoading || _isSubmittingResponse || _attemptId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit Test?'),
        content: const Text(
          'Are you sure you want to submit this test? You will not be able to change your answers after submitting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _submitAttempt(currentQuestion: currentQuestion);
  }

  // ── Audio (unchanged from original) ──

  Future<void> _primeLowTimerWarningAudio() async {
    if (kIsWeb) {
      try {
        await _lowTimerWarningPlayer.setSourceUrl(
          'assets/lib/core/utils/tenseconds.mp3',
        );
        await _lowTimerWarningPlayer.stop();
        return;
      } catch (_) {}
    }

    try {
      await _lowTimerWarningPlayer.setSource(
        AssetSource('lib/core/utils/tenseconds.mp3'),
      );
      await _lowTimerWarningPlayer.stop();
    } catch (_) {}
  }

  Future<void> _unlockLowTimerAudioFromGesture() async {
    if (_isAudioUnlockAttempted && !_isLowTimerWarningPendingAudioUnlock)
      return;
    _isAudioUnlockAttempted = true;
    var didUnlock = false;

    try {
      await _lowTimerWarningPlayer.setReleaseMode(ReleaseMode.stop);
      await _lowTimerWarningPlayer.setVolume(0.0);

      if (kIsWeb) {
        try {
          await _lowTimerWarningPlayer.play(
            UrlSource('assets/lib/core/utils/tenseconds.mp3'),
          );
          await Future<void>.delayed(const Duration(milliseconds: 40));
          await _lowTimerWarningPlayer.stop();
          await _lowTimerWarningPlayer.setVolume(1.0);
          didUnlock = true;
        } catch (_) {}
      }

      if (!didUnlock) {
        try {
          await _lowTimerWarningPlayer.play(
            AssetSource('lib/core/utils/tenseconds.mp3'),
          );
          await Future<void>.delayed(const Duration(milliseconds: 40));
          await _lowTimerWarningPlayer.stop();
          await _lowTimerWarningPlayer.setVolume(1.0);
          didUnlock = true;
        } catch (_) {}
      }

      await _lowTimerWarningPlayer.setVolume(1.0);
    } catch (_) {}

    if (_isLowTimerWarningPendingAudioUnlock &&
        !_hasPlayedLowTimerWarning &&
        _remainingSeconds > 0 &&
        _remainingSeconds <= _getLowTimerWarningSeconds()) {
      _hasPlayedLowTimerWarning = true;
      _isLowTimerWarningPendingAudioUnlock = false;
      unawaited(_playLowTimerWarning());
    }
  }

  Future<void> _playLowTimerWarning() async {
    var didPlayAudio = false;

    try {
      if (kIsWeb && !_isAudioUnlockAttempted) return;

      await _lowTimerWarningPlayer.stop();
      await _lowTimerWarningPlayer.setReleaseMode(ReleaseMode.stop);
      await _lowTimerWarningPlayer.setVolume(1.0);

      if (kIsWeb) {
        try {
          for (var i = 0; i < 3; i++) {
            await _lowTimerWarningPlayer.play(
              UrlSource('assets/lib/core/utils/tenseconds.mp3'),
            );
            didPlayAudio = true;
            if (i < 2) {
              await Future<void>.delayed(const Duration(milliseconds: 400));
            }
          }
        } catch (_) {}
      }

      try {
        for (var i = 0; i < 3; i++) {
          await _lowTimerWarningPlayer.play(
            AssetSource('lib/core/utils/tenseconds.mp3'),
          );
          didPlayAudio = true;
          if (i < 2) {
            await Future<void>.delayed(const Duration(milliseconds: 400));
          }
        }
      } catch (_) {}
    } catch (_) {}

    if (didPlayAudio) return;

    if (!_hasPlayedNativeToneFallback) {
      _hasPlayedNativeToneFallback = true;
      try {
        FlutterRingtonePlayer().playNotification(
          asAlarm: true,
          volume: 1.0,
          looping: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 450));
        FlutterRingtonePlayer().playNotification(
          asAlarm: true,
          volume: 1.0,
          looping: false,
        );
        return;
      } catch (_) {}
    }

    for (var i = 0; i < 3; i++) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.mediumImpact();
      if (i < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }

    if (mounted && !_hasShownLowTimerFallbackNotice) {
      _hasShownLowTimerFallbackNotice = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Low time warning triggered. Device audio appears unavailable.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Init / error states
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.test.title)),
        body: const app_widgets.LoadingWidget(
          message: 'Setting up your test...',
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.test.title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load test',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(_initError!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isBlocked) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.test.title)),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Test Locked',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(_blockedMessage, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final lowWarningSeconds = _getLowTimerWarningSeconds();
    final isTimerLow = _remainingSeconds <= lowWarningSeconds;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave Test?'),
            content: const Text(
              'Your progress is saved on the server. You can resume this test later. '
              'Are you sure you want to leave?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          // Don't clear storage — allow resume later
          Navigator.of(context).pop();
        }
      },
      child: Listener(
        onPointerDown: (_) {
          unawaited(_unlockLowTimerAudioFromGesture());
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.test.title),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: Container(
                  width: 102,
                  decoration: BoxDecoration(
                    color: isTimerLow
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _formatTimerDisplay(_remainingSeconds),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'monospace',
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: _questionsCache.isEmpty
              ? const app_widgets.LoadingWidget(message: 'Loading questions...')
              : _buildTestBody(),
        ),
      ),
    );
  }

  Widget _buildTestBody() {
    final currentQuestion = _questionsCache[_currentQuestionIndex];

    return app_widgets.AppPageScaffold(
      maxContentWidth: 940,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress bar
          app_widgets.GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    app_widgets.StatusBadge(
                      label:
                          'Question ${_currentQuestionIndex + 1}/${_questionsCache.length}',
                      status: 'draft',
                    ),
                    Text(
                      '${currentQuestion.marks} marks',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _questionsCache.length,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Question content
          app_widgets.GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentQuestion.questionText,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                if (currentQuestion.type == 'mcq' &&
                    currentQuestion.options != null) ...[
                  ...currentQuestion.options!.asMap().entries.map((entry) {
                    final optionIndex = entry.key;
                    final option = entry.value;
                    final isSelected =
                        _answers[currentQuestion.id] == optionIndex.toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          _selectAnswer(
                            currentQuestion.id,
                            optionIndex.toString(),
                          );
                        },
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.08)
                                : AppTheme.surfaceMutedOf(context),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                              width: isSelected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: optionIndex.toString(),
                                groupValue: _answers[currentQuestion.id],
                                onChanged: (value) {
                                  if (value != null) {
                                    _selectAnswer(currentQuestion.id, value);
                                  }
                                },
                              ),
                              Expanded(child: Text(option.optionText)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ] else if (currentQuestion.type == 'coding') ...[
                  Text(
                    'Write your answer below',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _getCodeController(currentQuestion.id),
                    minLines: 10,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: 'Type your code or explanation here',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (value) {
                      _answers[currentQuestion.id] = value;
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Navigation buttons
          Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_isLoading || _isSubmittingResponse)
                        ? null
                        : () async {
                            if (currentQuestion.type == 'coding') {
                              final saved = await _saveCodingAnswer(
                                currentQuestion,
                              );
                              if (!saved || !mounted) return;
                            }
                            setState(() => _currentQuestionIndex--);
                          },
                    child: const Text('Previous'),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: _currentQuestionIndex == _questionsCache.length - 1
                    ? ElevatedButton(
                        onPressed: (_isLoading || _isSubmittingResponse)
                            ? null
                            : () => _confirmSubmitAttempt(
                                currentQuestion: currentQuestion,
                              ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Submit Test'),
                      )
                    : ElevatedButton(
                        onPressed: (_isLoading || _isSubmittingResponse)
                            ? null
                            : () async {
                                if (currentQuestion.type == 'coding') {
                                  final saved = await _saveCodingAnswer(
                                    currentQuestion,
                                  );
                                  if (!saved || !mounted) return;
                                }
                                setState(() => _currentQuestionIndex++);
                              },
                        child: const Text('Next'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
