import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:test_gorilla/core/api/api_client.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';
import 'package:test_gorilla/features/shared/models/models.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:test_gorilla/features/shared/widgets/app_widgets.dart'
    as app_widgets;
import 'package:test_gorilla/features/candidate/test_service.dart';

class AttemptScreen extends StatefulWidget {
  final Test test;

  const AttemptScreen({Key? key, required this.test}) : super(key: key);

  @override
  State<AttemptScreen> createState() => _AttemptScreenState();
}

class _AttemptScreenState extends State<AttemptScreen> {
  late TestService _testService;
  late Future<List<Question>> _questionsFuture;
  List<Question> _questionsCache = [];
  TestAttempt? _currentAttempt;
  int _currentQuestionIndex = 0;
  Timer? _timer;
  final AudioPlayer _lowTimerWarningPlayer = AudioPlayer();
  late Duration _remainingTime;
  Map<String, String> _answers = {};
  final Map<String, TextEditingController> _codeControllers = {};
  bool _isLoading = false;
  bool _isSubmittingResponse = false;
  bool _isBlocked = false;
  String _blockedMessage = '';
  bool _hasPlayedLowTimerWarning = false;
  bool _hasShownLowTimerFallbackNotice = false;
  bool _hasPlayedNativeToneFallback = false;
  bool _isAudioUnlockAttempted = false;
  bool _isLowTimerWarningPendingAudioUnlock = false;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _testService = TestService(apiClient);
    _remainingTime = Duration(minutes: widget.test.durationMinutes);
    unawaited(_primeLowTimerWarningAudio());
    _initializeAttempt();
  }

  Future<void> _primeLowTimerWarningAudio() async {
    if (kIsWeb) {
      const webAssetUrls = <String>[
        'assets/lib/core/utils/tenseconds.mp3',
        'assets/tenseconds.mp3',
      ];

      for (final url in webAssetUrls) {
        try {
          await _lowTimerWarningPlayer.setSourceUrl(url);
          await _lowTimerWarningPlayer.stop();
          return;
        } catch (_) {
          // Try the next URL variant.
        }
      }
    }

    const candidateAssetPaths = <String>[
      'tenseconds.mp3',
      'core/utils/tenseconds.mp3',
      'lib/core/utils/tenseconds.mp3',
      'assets/lib/core/utils/tenseconds.mp3',
    ];

    for (final path in candidateAssetPaths) {
      try {
        await _lowTimerWarningPlayer.setSource(AssetSource(path));
        await _lowTimerWarningPlayer.stop();
        return;
      } catch (_) {
        // Try the next key variant.
      }
    }
  }

  Future<void> _unlockLowTimerAudioFromGesture() async {
    if (_isAudioUnlockAttempted && !_isLowTimerWarningPendingAudioUnlock) {
      return;
    }

    _isAudioUnlockAttempted = true;
    var didUnlock = false;

    try {
      await _lowTimerWarningPlayer.setReleaseMode(ReleaseMode.stop);
      await _lowTimerWarningPlayer.setVolume(0.0);

      if (kIsWeb) {
        const webAssetUrls = <String>[
          'assets/lib/core/utils/tenseconds.mp3',
          'assets/tenseconds.mp3',
        ];

        for (final url in webAssetUrls) {
          try {
            await _lowTimerWarningPlayer.play(UrlSource(url));
            await Future<void>.delayed(const Duration(milliseconds: 40));
            await _lowTimerWarningPlayer.stop();
            await _lowTimerWarningPlayer.setVolume(1.0);
            didUnlock = true;
            break;
          } catch (_) {
            // Try the next URL variant.
          }
        }
      }

      if (!didUnlock) {
        const candidateAssetPaths = <String>[
          'tenseconds.mp3',
          'core/utils/tenseconds.mp3',
          'lib/core/utils/tenseconds.mp3',
          'assets/lib/core/utils/tenseconds.mp3',
        ];

        for (final path in candidateAssetPaths) {
          try {
            await _lowTimerWarningPlayer.play(AssetSource(path));
            await Future<void>.delayed(const Duration(milliseconds: 40));
            await _lowTimerWarningPlayer.stop();
            await _lowTimerWarningPlayer.setVolume(1.0);
            didUnlock = true;
            break;
          } catch (_) {
            // Try the next key variant.
          }
        }
      }

      await _lowTimerWarningPlayer.setVolume(1.0);
    } catch (_) {
      // Leave fallback path active.
    }

    final lowTimerWarningSeconds = _getLowTimerWarningSeconds();
    if (_isLowTimerWarningPendingAudioUnlock &&
        !_hasPlayedLowTimerWarning &&
        _remainingTime.inSeconds > 0 &&
        _remainingTime.inSeconds <= lowTimerWarningSeconds) {
      _hasPlayedLowTimerWarning = true;
      _isLowTimerWarningPendingAudioUnlock = false;
      unawaited(_playLowTimerWarning());
    }
  }

  Future<void> _initializeAttempt() async {
    _questionsFuture = _testService.getTestQuestions(widget.test.id).then((
      questions,
    ) {
      _questionsCache = questions;
      return questions;
    });
    await _startAttempt();
    if (_currentAttempt != null) {
      _startTimer();
    }
  }

  TextEditingController _getCodeController(String questionId) {
    return _codeControllers.putIfAbsent(
      questionId,
      () => TextEditingController(text: _answers[questionId] ?? ''),
    );
  }

  Future<void> _startAttempt() async {
    try {
      _currentAttempt = await _testService.startAttempt(widget.test.id);
    } catch (e) {
      if (e is ApiException && e.statusCode == 409) {
        if (!mounted) return;

        setState(() {
          _isBlocked = true;
          _blockedMessage =
              'This test has already been started for your account. Reattempts and resume are disabled.';
        });
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting attempt: $e')));
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      var shouldPlayLowTimerWarning = false;
      setState(() {
        if (_remainingTime.inSeconds > 0) {
          _remainingTime = _remainingTime - Duration(seconds: 1);
        }

        final lowTimerWarningSeconds = _getLowTimerWarningSeconds();
        if (!_hasPlayedLowTimerWarning &&
            _remainingTime.inSeconds == lowTimerWarningSeconds) {
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

      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        _submitAttempt();
      }
    });
  }

  String _formatTimerDisplay(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(String questionId, String answerId) {
    setState(() {
      _answers[questionId] = answerId;
    });

    if (_currentAttempt == null || _isSubmittingResponse) {
      return;
    }

    _submitAnswer(questionId, answerId);
  }

  Future<bool> _saveCodingAnswer(Question question) async {
    if (_currentAttempt == null || _isSubmittingResponse) {
      return false;
    }

    final controller = _getCodeController(question.id);
    final codeAnswer = controller.text;

    setState(() {
      _isSubmittingResponse = true;
      _answers[question.id] = codeAnswer;
    });

    try {
      await _testService.submitResponse(
        _currentAttempt!.id,
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

  void _submitAnswer(String questionId, String answerId) async {
    if (_isSubmittingResponse || _currentAttempt == null) return;

    setState(() {
      _isSubmittingResponse = true;
    });

    try {
      await _testService.submitResponse(
        _currentAttempt!.id,
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

  Future<void> _submitAttempt({Question? currentQuestion}) async {
    if (_isLoading || _currentAttempt == null) return;

    setState(() => _isLoading = true);
    _timer?.cancel();

    try {
      // Save current coding answer if available
      final questionToSave =
          currentQuestion ??
          (_questionsCache.isNotEmpty &&
                  _currentQuestionIndex < _questionsCache.length
              ? _questionsCache[_currentQuestionIndex]
              : null);

      if (questionToSave != null && questionToSave.type == 'coding') {
        final controller = _getCodeController(questionToSave.id);
        final codeAnswer = controller.text;

        try {
          await _testService.submitResponse(
            _currentAttempt!.id,
            questionId: questionToSave.id,
            codeAnswer: codeAnswer,
          );
        } catch (e) {
          // Continue with attempt submission even if saving answer fails
        }
      }

      // Submit the test attempt
      await _testService.submitAttempt(_currentAttempt!.id);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/candidate/result',
          arguments: _currentAttempt!.id,
        );
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
      }
    }
  }

  int _getLowTimerWarningSeconds() {
    final totalMinutes = widget.test.durationMinutes;

    if (totalMinutes >= 10) {
      return 60;
    }

    if (totalMinutes >= 5) {
      return 30;
    }

    return 10;
  }

  Future<void> _playLowTimerWarning() async {
    var didPlayAudio = false;

    try {
      if (kIsWeb && !_isAudioUnlockAttempted) {
        // Web playback often requires a prior user gesture to unlock audio.
        return;
      }

      await _lowTimerWarningPlayer.stop();
      await _lowTimerWarningPlayer.setReleaseMode(ReleaseMode.stop);
      await _lowTimerWarningPlayer.setVolume(1.0);

      if (kIsWeb) {
        const webAssetUrls = <String>[
          'assets/lib/core/utils/tenseconds.mp3',
          'assets/tenseconds.mp3',
        ];

        for (final url in webAssetUrls) {
          try {
            for (var i = 0; i < 3; i++) {
              await _lowTimerWarningPlayer.play(UrlSource(url));
              didPlayAudio = true;

              if (i < 2) {
                await Future<void>.delayed(const Duration(milliseconds: 400));
              }
            }
            break;
          } catch (_) {
            // Try the next URL variant.
          }
        }
      }

      const candidateAssetPaths = <String>[
        'tenseconds.mp3',
        'core/utils/tenseconds.mp3',
        'lib/core/utils/tenseconds.mp3',
        'assets/lib/core/utils/tenseconds.mp3',
      ];

      for (final path in candidateAssetPaths) {
        try {
          for (var i = 0; i < 3; i++) {
            await _lowTimerWarningPlayer.play(AssetSource(path));
            didPlayAudio = true;

            if (i < 2) {
              await Future<void>.delayed(const Duration(milliseconds: 400));
            }
          }
          break;
        } catch (_) {
          // Try the next key variant.
        }
      }
    } catch (_) {}

    if (didPlayAudio) {
      return;
    }

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
      } catch (_) {
        // Continue to non-ringtone fallbacks.
      }
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

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_lowTimerWarningPlayer.dispose());
    for (final controller in _codeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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

    return WillPopScope(
      onWillPop: () async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exit Test?'),
                content: const Text('Your progress will be lost'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Exit'),
                  ),
                ],
              ),
            ) ??
            false;
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
                    color:
                        _remainingTime.inSeconds <= _getLowTimerWarningSeconds()
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _formatTimerDisplay(_remainingTime),
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
          body: FutureBuilder<List<Question>>(
            future: _questionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const app_widgets.LoadingWidget(
                  message: 'Loading questions...',
                );
              }

              if (snapshot.hasError) {
                return app_widgets.ErrorWidget(
                  message: snapshot.error.toString(),
                );
              }

              final questions = snapshot.data ?? [];
              if (questions.isEmpty) {
                return const app_widgets.EmptyStateWidget(
                  title: 'No Questions',
                );
              }

              final currentQuestion = questions[_currentQuestionIndex];

              return app_widgets.AppPageScaffold(
                maxContentWidth: 940,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    app_widgets.GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              app_widgets.StatusBadge(
                                label:
                                    'Question ${_currentQuestionIndex + 1}/${questions.length}',
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
                            value:
                                (_currentQuestionIndex + 1) / questions.length,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                            ...currentQuestion.options!.asMap().entries.map((
                              entry,
                            ) {
                              final optionIndex = entry.key;
                              final option = entry.value;
                              final isSelected =
                                  _answers[currentQuestion.id] ==
                                  optionIndex.toString();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () {
                                    _selectAnswer(
                                      currentQuestion.id,
                                      optionIndex.toString(),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.08)
                                          : AppTheme.surfaceMuted,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd,
                                      ),
                                      border: Border.all(
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : const Color(0xFFE2E8F0),
                                        width: isSelected ? 1.4 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Radio<String>(
                                          value: optionIndex.toString(),
                                          groupValue:
                                              _answers[currentQuestion.id],
                                          onChanged: (value) {
                                            if (value != null) {
                                              _selectAnswer(
                                                currentQuestion.id,
                                                value,
                                              );
                                            }
                                          },
                                        ),
                                        Expanded(
                                          child: Text(option.optionText),
                                        ),
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
                              controller: _getCodeController(
                                currentQuestion.id,
                              ),
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
                                        if (!saved || !mounted) {
                                          return;
                                        }
                                      }

                                      setState(() => _currentQuestionIndex--);
                                    },
                              child: const Text('Previous'),
                            ),
                          ),
                        if (_currentQuestionIndex > 0)
                          const SizedBox(width: 12),
                        Expanded(
                          child: _currentQuestionIndex == questions.length - 1
                              ? ElevatedButton(
                                  onPressed:
                                      (_isLoading || _isSubmittingResponse)
                                      ? null
                                      : () => _submitAttempt(
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
                                  onPressed:
                                      (_isLoading || _isSubmittingResponse)
                                      ? null
                                      : () async {
                                          if (currentQuestion.type ==
                                              'coding') {
                                            final saved =
                                                await _saveCodingAnswer(
                                                  currentQuestion,
                                                );
                                            if (!saved || !mounted) {
                                              return;
                                            }
                                          }

                                          setState(
                                            () => _currentQuestionIndex++,
                                          );
                                        },
                                  child: const Text('Next'),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
