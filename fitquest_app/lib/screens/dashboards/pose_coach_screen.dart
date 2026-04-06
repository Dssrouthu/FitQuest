import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../main.dart';
import '../../services/analytics_service.dart';

// ── Exercise definitions ──────────────────────────────────────────────────────
class _Exercise {
  final String id;
  final String name;
  final String muscle;
  final IconData icon;
  final String difficulty;
  final String cameraPlacement;
  final List<String> steps;
  final bool isPlank; // hold timer instead of rep counter

  const _Exercise(
    this.id, this.name, this.muscle, this.icon, {
    this.difficulty = 'Intermediate',
    this.cameraPlacement = 'Place phone ~2m away, full body visible.',
    this.steps = const [],
    this.isPlank = false,
  });
}

const _exercises = [
  _Exercise('squat', 'Squat', 'Legs', Icons.accessibility_new,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at hip height, ~2m in front. Full body visible.',
      steps: ['Feet shoulder-width apart', 'Lower until thighs parallel to floor', 'Drive through heels to stand', 'Keep chest up throughout']),
  _Exercise('pushup', 'Push-up', 'Chest', Icons.fitness_center,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at shoulder height on the side, ~1.5m away.',
      steps: ['Hands shoulder-width apart', 'Keep body straight (plank position)', 'Lower chest to floor', 'Push back up to full extension']),
  _Exercise('curl', 'Curl', 'Biceps', Icons.sports_gymnastics,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at waist height in front, ~1.5m away.',
      steps: ['Stand straight, elbows at sides', 'Curl weight up toward shoulders', 'Squeeze at the top', 'Lower slowly']),
  _Exercise('ohp', 'OHP', 'Shoulders', Icons.arrow_upward,
      difficulty: 'Intermediate',
      cameraPlacement: 'Place phone at chest height in front, ~2m away.',
      steps: ['Stand with feet shoulder-width', 'Bar at upper chest level', 'Press straight overhead', 'Lock out arms at top']),
  _Exercise('row', 'Bent Row', 'Back', Icons.rowing,
      difficulty: 'Intermediate',
      cameraPlacement: 'Place phone at waist height on the side, ~2m away.',
      steps: ['Hinge at hips, back straight', 'Pull weight to lower chest', 'Squeeze shoulder blades', 'Lower under control']),
  _Exercise('extension', 'Extension', 'Triceps', Icons.sports_handball,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at shoulder height on the side, ~1.5m away.',
      steps: ['Hold weight overhead', 'Elbows close to head', 'Lower weight behind head', 'Extend arms fully']),
  _Exercise('burpee', 'Burpee', 'Full Body', Icons.electric_bolt,
      difficulty: 'Intermediate',
      cameraPlacement: 'Place phone at hip height, ~2m in front. Full body visible.',
      steps: ['Stand with feet together', 'Drop to squat, hands on floor', 'Jump feet back to plank', 'Jump feet forward, leap up']),
  _Exercise('lunge', 'Lunge', 'Legs', Icons.directions_walk,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at knee height, ~2m on the side.',
      steps: ['Stand with feet together', 'Step forward into lunge', 'Lower back knee toward floor', 'Push off front foot to return']),
  _Exercise('deadlift', 'Deadlift', 'Back/Legs', Icons.fitness_center,
      difficulty: 'Intermediate',
      cameraPlacement: 'Place phone at knee height on the side, ~2m away.',
      steps: ['Feet hip-width, bar over mid-foot', 'Hinge down, grip bar', 'Drive through heels, keep back flat', 'Stand tall, shoulders back']),
  _Exercise('plank', 'Plank', 'Core', Icons.horizontal_rule,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at ground level on the side, ~2m away.',
      steps: ['Forearms on ground, elbows under shoulders', 'Body straight from head to heels', 'Engage core and glutes', 'Hold position'],
      isPlank: true),
  _Exercise('jumpingjack', 'Jumping Jack', 'Full Body', Icons.open_in_full,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at chest height in front, ~2.5m away. Full body visible.',
      steps: ['Start with feet together, arms down', 'Jump and spread feet wide', 'Raise arms overhead simultaneously', 'Jump back to start']),
  _Exercise('mountainclimber', 'Mountain Climber', 'Core', Icons.terrain,
      difficulty: 'Intermediate',
      cameraPlacement: 'Place phone at ground level on the side, ~1.5m away.',
      steps: ['Start in high plank position', 'Drive right knee toward left wrist', 'Return and switch legs', 'Maintain plank alignment']),
  _Exercise('lateralraise', 'Lateral Raise', 'Shoulders', Icons.compare_arrows,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at shoulder height in front, ~2m away.',
      steps: ['Stand tall, weights at sides', 'Raise arms out to shoulder height', 'Lead with elbows, not wrists', 'Lower under control']),
  _Exercise('hammercurl', 'Hammer Curl', 'Biceps/Forearms', Icons.sports_gymnastics,
      difficulty: 'Beginner',
      cameraPlacement: 'Place phone at waist height in front, ~1.5m away.',
      steps: ['Neutral grip (palms facing each other)', 'Elbows pinned at sides', 'Curl to shoulder height', 'Lower slowly']),
  _Exercise('dip', 'Dip', 'Triceps', Icons.arrow_downward,
      difficulty: 'Intermediate',
      cameraPlacement: 'Place phone at hip height on the side, ~2m away.',
      steps: ['Grip parallel bars, arms straight', 'Lean slightly forward', 'Lower until elbows at 90°', 'Press back to full extension']),
];

class PoseCoachScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final String? password;

  const PoseCoachScreen({super.key, this.userData, this.password});

  @override
  State<PoseCoachScreen> createState() => _PoseCoachScreenState();
}

class _PoseCoachScreenState extends State<PoseCoachScreen> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  List<Pose> _poses = [];
  bool _isDetecting = false;
  bool _cameraReady = false;
  bool _detecting = false;
  String _hint = 'TAP START to begin';
  _Exercise? _selectedExercise;
  CameraLensDirection _cameraDirection = CameraLensDirection.front;

  // Performance & Smoothing
  int _frameCount = 0;
  final Map<PoseLandmarkType, List<Offset>> _smaBuffers = {};
  static const int _smaSize = 5;

  // Recording & Pose Data
  bool _isRecording = false;
  final List<Map<String, dynamic>> _recordedPoseData = [];
  DateTime? _recordingStartTime;

  // Rep counter state
  int _repCount = 0;
  bool _inDownPhase = false;
  String _phase = '';
  Timer? _heartbeatTimer;

  // Plank hold timer
  int _plankSeconds = 0;
  Timer? _plankTimer;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == _cameraDirection,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: FQColors.red));
      }
    }
  }

  void _selectExercise(_Exercise ex) async {
    // Show tip sheet first
    final start = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExerciseTipSheet(exercise: ex),
    );
    if (start != true || !mounted) return;

    setState(() {
      _selectedExercise = ex;
      _repCount = 0;
      _plankSeconds = 0;
      _inDownPhase = false;
      _phase = '';
      _frameCount = 0;
      _smaBuffers.clear();
      _recordedPoseData.clear();
    });
    _initCamera();
  }

  void _toggleDetection() async {
    if (_detecting) {
      await _stopDetection();
    } else {
      await _startDetection();
    }
  }

  Future<void> _startDetection() async {
    if (_cameraController == null || !_cameraReady) return;
    
    try {
      _recordingStartTime = DateTime.now();
      _recordedPoseData.clear();
      
      setState(() {
        _detecting = true;
        _isRecording = true;
        _hint = 'Detecting & Recording...';
        _repCount = 0;
        _plankSeconds = 0;
        _inDownPhase = false;
      });

      if (_selectedExercise?.isPlank == true) {
        _plankTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && _detecting) setState(() => _plankSeconds++);
        });
      }
      _startHeartbeat();

      _cameraController!.startImageStream((image) async {
        _frameCount++;
        // Throttle: Process only every 3rd frame (~10 FPS assuming 30 FPS stream)
        if (_frameCount % 3 != 0) return;
        
        if (_isDetecting) return;
        _isDetecting = true;
        try {
          final inputImage = _convertToInputImage(image);
          final poses = await _poseDetector!.processImage(inputImage);
          
          if (poses.isNotEmpty) {
            final smoothedPose = _smoothPose(poses.first);
            
            // Record pose data with timestamp
            if (_isRecording) {
              final timestamp = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
              _recordPoseFrame(smoothedPose, timestamp);
            }

            if (mounted) {
              setState(() {
                _poses = [smoothedPose];
                final result = _analyzeExercise([smoothedPose]);
                _hint = result.hint;
                _phase = result.phase;
                if (result.countRep) _repCount++;
              });
            }
          }
        } catch (_) {
        } finally {
          _isDetecting = false;
        }
      });
    } catch (e) {
      print("Error starting detection: $e");
    }
  }

  Pose _smoothPose(Pose originalPose) {
    final Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks = {};
    
    originalPose.landmarks.forEach((type, landmark) {
      if (!_smaBuffers.containsKey(type)) {
        _smaBuffers[type] = [];
      }
      
      final buffer = _smaBuffers[type]!;
      buffer.add(Offset(landmark.x, landmark.y));
      if (buffer.length > _smaSize) {
        buffer.removeAt(0);
      }
      
      double avgX = 0;
      double avgY = 0;
      for (var p in buffer) {
        avgX += p.dx;
        avgY += p.dy;
      }
      avgX /= buffer.length;
      avgY /= buffer.length;
      
      smoothedLandmarks[type] = PoseLandmark(
        type: type,
        x: avgX,
        y: avgY,
        z: landmark.z,
        likelihood: landmark.likelihood,
      );
    });
    
    return Pose(landmarks: smoothedLandmarks);
  }

  void _recordPoseFrame(Pose pose, int timestampMs) {
    final Map<String, dynamic> frameData = {
      't': timestampMs,
      'p': pose.landmarks.map((type, lm) => MapEntry(type.name, [lm.x.toInt(), lm.y.toInt()])),
    };
    _recordedPoseData.add(frameData);
  }

  Future<void> _stopDetection() async {
    await _cameraController?.stopImageStream();
    _heartbeatTimer?.cancel();
    _plankTimer?.cancel();
    
    setState(() {
      _detecting = false;
      _isRecording = false;
      _poses = [];
      _hint = 'Saving results...';
      _phase = '';
    });

    _saveSetResults();
  }

  void _saveSetResults() async {
    // In a real app, you'd upload videoFile.path to Cloudinary here
    // For this implementation, we'll send the pose_data to Django.
    if (widget.userData == null || widget.password == null) return;

    try {
      final String poseJson = jsonEncode(_recordedPoseData);
      
      await AnalyticsService.logSet(
        widget.userData!['username'],
        widget.password!,
        {
          'exercise_name': _selectedExercise!.name,
          'reps': _selectedExercise!.isPlank ? 0 : _repCount,
          'weight_kg': null,
          'effectiveness': 'Just Right',
          'set_type': 'Regular',
          'pose_data': poseJson,
          'video_url': 'https://res.cloudinary.com/demo/video/upload/v1/sample_set.mp4', // Mock URL
        }
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout set saved successfully!'), backgroundColor: FQColors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: FQColors.red)
        );
      }
    }

    setState(() {
      _hint = 'TAP START to begin';
    });
  }

  void _startHeartbeat() {
    if (widget.userData == null || widget.password == null) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      AnalyticsService.sendHeartbeat(
        widget.userData!['username'] ?? '',
        widget.password!,
        'working_out',
        0,
      );
    });
  }

  InputImage _convertToInputImage(CameraImage image) {
    final camera = _cameraController!.description;
    final rotation = InputImageRotationValue.fromRawValue(
            camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    // Fix dimension swap: previewSize width/height are swapped on Android
    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  // ── Angle helper ────────────────────────────────────────────────────────────
  double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ab = Offset(a.x - b.x, a.y - b.y);
    final cb = Offset(c.x - b.x, c.y - b.y);
    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final cross = ab.dx * cb.dy - ab.dy * cb.dx;
    return (atan2(cross.abs(), dot) * 180 / pi).abs();
  }

  // ── Per-exercise analysis ───────────────────────────────────────────────────
  _AnalysisResult _analyzeExercise(List<Pose> poses) {
    if (poses.isEmpty) {
      return _AnalysisResult('No person detected — step into frame', '', false);
    }
    final pose = poses.first;
    final ex = _selectedExercise;
    if (ex == null) return _AnalysisResult('Select an exercise first', '', false);

    switch (ex.id) {
      case 'squat':
        return _analyzeSquat(pose);
      case 'pushup':
        return _analyzePushup(pose);
      case 'curl':
      case 'hammercurl':
        return _analyzeCurl(pose);
      case 'ohp':
        return _analyzeOhp(pose);
      case 'row':
      case 'extension':
      case 'dip':
        return _analyzeRowExtension(pose, ex.id);
      case 'burpee':
        return _analyzeBurpee(pose);
      case 'lunge':
        return _analyzeLunge(pose);
      case 'deadlift':
        return _analyzeDeadlift(pose);
      case 'plank':
        return _analyzePlank(pose);
      case 'jumpingjack':
        return _analyzeJumpingJack(pose);
      case 'mountainclimber':
        return _analyzeMountainClimber(pose);
      case 'lateralraise':
        return _analyzeLateralRaise(pose);
      default:
        return _AnalysisResult('Exercise not configured', '', false);
    }
  }

  _AnalysisResult _analyzeLunge(Pose pose) {
    final lHip   = pose.landmarks[PoseLandmarkType.leftHip];
    final lKnee  = pose.landmarks[PoseLandmarkType.leftKnee];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (lHip == null || lKnee == null || lAnkle == null) {
      return _AnalysisResult('Stand sideways to camera', '', false);
    }
    final kneeAngle = _angle(lHip, lKnee, lAnkle);
    bool countRep = false;
    final phase = kneeAngle < 100 ? 'DOWN' : 'UP';
    String hint;
    if (kneeAngle < 100) {
      if (!_inDownPhase) _inDownPhase = true;
      hint = 'Good depth! Keep front knee over ankle';
    } else {
      if (_inDownPhase) { countRep = true; _inDownPhase = false; }
      hint = 'Step forward and lower back knee';
    }
    return _AnalysisResult(hint, phase, countRep);
  }

  _AnalysisResult _analyzeDeadlift(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lHip      = pose.landmarks[PoseLandmarkType.leftHip];
    final lKnee     = pose.landmarks[PoseLandmarkType.leftKnee];
    if (lShoulder == null || lHip == null || lKnee == null) {
      return _AnalysisResult('Stand sideways to camera', '', false);
    }
    // Torso angle: shoulder-hip vs vertical
    final torsoAngle = _angle2D(lShoulder, lHip);
    bool countRep = false;
    final isUpright = torsoAngle > 70; // close to vertical = standing
    final phase = isUpright ? 'UP' : 'DOWN';
    String hint;
    if (!isUpright) {
      if (!_inDownPhase) _inDownPhase = true;
      hint = 'Back flat! Drive through heels';
    } else {
      if (_inDownPhase) { countRep = true; _inDownPhase = false; }
      hint = 'Hinge at hips, keep bar close';
    }
    return _AnalysisResult(hint, phase, countRep);
  }

  _AnalysisResult _analyzePlank(Pose pose) {
    // Plank: returns hint based on body alignment, no rep counting
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lHip      = pose.landmarks[PoseLandmarkType.leftHip];
    final lAnkle    = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (lShoulder == null || lHip == null || lAnkle == null) {
      return _AnalysisResult('Face sideways to camera — full body visible', 'HOLD', false);
    }
    final hipDiff = (lHip.y - ((lShoulder.y + lAnkle.y) / 2)).abs();
    String hint;
    if (hipDiff > 40) {
      hint = lHip.y < lShoulder.y ? 'Hips too high — lower them' : 'Hips sagging — lift core!';
    } else {
      hint = 'Great form! Hold tight ($_plankSeconds s)';
    }
    return _AnalysisResult(hint, 'HOLD', false);
  }

  _AnalysisResult _analyzeJumpingJack(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lWrist    = pose.landmarks[PoseLandmarkType.leftWrist];
    if (lShoulder == null || lWrist == null) {
      return _AnalysisResult('Face camera — full body visible', '', false);
    }
    final armsUp = lWrist.y < lShoulder.y - 30;
    bool countRep = false;
    final phase = armsUp ? 'UP' : 'DOWN';
    if (armsUp) {
      if (!_inDownPhase) _inDownPhase = true;
      return _AnalysisResult('Arms up! Jump feet back together', phase, false);
    } else {
      if (_inDownPhase) { countRep = true; _inDownPhase = false; }
      return _AnalysisResult('Jump and raise arms overhead', phase, countRep);
    }
  }

  _AnalysisResult _analyzeMountainClimber(Pose pose) {
    final lKnee   = pose.landmarks[PoseLandmarkType.leftKnee];
    final rWrist  = pose.landmarks[PoseLandmarkType.rightWrist];
    if (lKnee == null || rWrist == null) {
      return _AnalysisResult('Face sideways — high plank position', '', false);
    }
    final dist = sqrt(pow(lKnee.x - rWrist.x, 2) + pow(lKnee.y - rWrist.y, 2));
    bool countRep = false;
    final phase = dist < 80 ? 'CRUNCH' : 'EXTEND';
    if (dist < 80) {
      if (!_inDownPhase) _inDownPhase = true;
      return _AnalysisResult('Knee to opposite wrist! Switch!', phase, false);
    } else {
      if (_inDownPhase) { countRep = true; _inDownPhase = false; }
      return _AnalysisResult('Drive knee toward opposite wrist', phase, countRep);
    }
  }

  _AnalysisResult _analyzeLateralRaise(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lWrist    = pose.landmarks[PoseLandmarkType.leftWrist];
    if (lShoulder == null || lWrist == null) {
      return _AnalysisResult('Face camera — arms visible', '', false);
    }
    final armsRaised = lWrist.y < lShoulder.y;
    bool countRep = false;
    final phase = armsRaised ? 'UP' : 'DOWN';
    if (armsRaised) {
      if (!_inDownPhase) _inDownPhase = true;
      return _AnalysisResult('Arms at shoulder height — lower slowly', phase, false);
    } else {
      if (_inDownPhase) { countRep = true; _inDownPhase = false; }
      return _AnalysisResult('Raise arms out to shoulder height', phase, countRep);
    }
  }

  // Helper: angle between two points vs vertical (in degrees)
  double _angle2D(dynamic top, dynamic bottom) {
    final dy = (bottom.y - top.y).abs();
    final dx = (bottom.x - top.x).abs();
    return (atan2(dy, dx) * 180 / pi);
  }

  _AnalysisResult _analyzeSquat(Pose pose) {
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (lHip == null || lKnee == null || lAnkle == null) {
      return _AnalysisResult('Stand facing camera', '', false);
    }

    final kneeAngle = _angle(lHip, lKnee, lAnkle);
    String hint = '';
    bool countRep = false;
    String phase = kneeAngle < 90 ? 'DOWN' : 'UP';

    if (kneeAngle < 90) {
      if (!_inDownPhase) _inDownPhase = true;
      hint = 'Good depth! Keep back straight';
      // Check knees caving
      if (rKnee != null && rAnkle != null) {
        if ((rKnee.x - rAnkle.x).abs() > 40) hint = 'Knees caving — push them out!';
      }
    } else {
      if (_inDownPhase) {
        countRep = true;
        _inDownPhase = false;
      }
      hint = 'Lower until thighs parallel — keep chest up';
    }

    return _AnalysisResult(hint, phase, countRep);
  }

  _AnalysisResult _analyzePushup(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final lWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];

    if (lShoulder == null || lElbow == null || lWrist == null) {
      return _AnalysisResult('Face side to camera', '', false);
    }

    final elbowAngle = _angle(lShoulder, lElbow, lWrist);
    bool countRep = false;
    String phase = elbowAngle < 90 ? 'DOWN' : 'UP';

    String hint;
    if (elbowAngle < 90) {
      if (!_inDownPhase) _inDownPhase = true;
      hint = 'Good! Push back up';
      if (lHip != null) {
        if ((lHip.y - lShoulder.y).abs() > 60) hint = 'Hips sagging — keep body straight!';
      }
    } else {
      if (_inDownPhase) {
        countRep = true;
        _inDownPhase = false;
      }
      hint = 'Lower chest to ground — elbows at 45°';
    }

    return _AnalysisResult(hint, phase, countRep);
  }

  _AnalysisResult _analyzeCurl(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final lWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    if (lShoulder == null || lElbow == null || lWrist == null) {
      return _AnalysisResult('Face camera sideways', '', false);
    }

    final elbowAngle = _angle(lShoulder, lElbow, lWrist);
    bool countRep = false;
    String phase = elbowAngle < 90 ? 'UP' : 'DOWN';
    String hint;

    if (elbowAngle < 60) {
      if (!_inDownPhase) {
        _inDownPhase = true; // Using as "in-top" marker
      }
      hint = 'Peak contraction! Lower slowly';
    } else if (elbowAngle > 160) {
      if (_inDownPhase) {
        countRep = true;
        _inDownPhase = false;
      }
      hint = 'Full extension — curl upward';
    } else {
      hint = 'Keep elbow fixed at side';
    }

    return _AnalysisResult(hint, phase, countRep);
  }

  _AnalysisResult _analyzeOhp(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final lWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    if (lShoulder == null || lElbow == null || lWrist == null) {
      return _AnalysisResult('Face camera sideways', '', false);
    }

    final wristAboveShoulder = lWrist.y < lShoulder.y;
    final elbowAngle = _angle(lShoulder, lElbow, lWrist);
    bool countRep = false;
    String phase = wristAboveShoulder ? 'UP' : 'DOWN';
    String hint;

    if (wristAboveShoulder) {
      if (!_inDownPhase) _inDownPhase = true;
      hint = 'Arms locked out! Lower with control';
    } else {
      if (_inDownPhase) {
        countRep = true;
        _inDownPhase = false;
      }
      hint = 'Elbows at 90° — press overhead';
      if (elbowAngle < 70) hint = 'Good start position — PRESS!';
    }

    return _AnalysisResult(hint, phase, countRep);
  }

  _AnalysisResult _analyzeRowExtension(Pose pose, String exerciseId) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final lWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    if (lShoulder == null || lElbow == null || lWrist == null) {
      return _AnalysisResult('Face camera sideways', '', false);
    }

    final elbowAngle = _angle(lShoulder, lElbow, lWrist);
    bool countRep = false;
    String phase;
    String hint;

    if (exerciseId == 'row') {
      phase = elbowAngle < 90 ? 'PULL' : 'EXTEND';
      if (elbowAngle < 80) {
        if (!_inDownPhase) _inDownPhase = true;
        hint = 'Good row! Squeeze back at top';
      } else {
        if (_inDownPhase) {
          countRep = true;
          _inDownPhase = false;
        }
        hint = 'Pull elbow back — retract shoulder blade';
      }
    } else {
      phase = elbowAngle > 150 ? 'EXTEND' : 'FLEX';
      if (elbowAngle > 150) {
        if (!_inDownPhase) _inDownPhase = true;
        hint = 'Full extension! Lower slowly';
      } else {
        if (_inDownPhase) {
          countRep = true;
          _inDownPhase = false;
        }
        hint = 'Keep upper arm still — extend forearm';
      }
    }

    return _AnalysisResult(hint, phase, countRep);
  }

  _AnalysisResult _analyzeBurpee(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];

    if (lShoulder == null || lHip == null || lKnee == null) {
      return _AnalysisResult('Full body in frame', '', false);
    }

    // Standing: shoulder y much less than hip y (higher on screen)
    final isStanding = lShoulder.y < lHip.y - 100;
    bool countRep = false;
    String phase = isStanding ? 'STAND' : 'FLOOR';
    String hint;

    if (!isStanding) {
      if (!_inDownPhase) _inDownPhase = true;
      hint = 'Push up and jump!';
    } else {
      if (_inDownPhase) {
        countRep = true;
        _inDownPhase = false;
      }
      hint = 'Drop down — chest to floor';
    }

    return _AnalysisResult(hint, phase, countRep);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Exercise selector screen
    if (_selectedExercise == null) {
      return _buildExerciseSelector();
    }

    // Camera + detection screen
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: FQColors.surface,
        foregroundColor: Colors.white,
        title: Text('POSE COACH — ${_selectedExercise!.name.toUpperCase()}',
            style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: FQColors.purple),
            tooltip: 'Flip camera',
            onPressed: () {
              setState(() {
                _cameraDirection = (_cameraDirection == CameraLensDirection.front)
                    ? CameraLensDirection.back
                    : CameraLensDirection.front;
                _cameraReady = false;
              });
              _initCamera();
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: FQColors.purple),
            tooltip: 'Change exercise',
            onPressed: () {
              _stopDetection();
              _cameraController?.dispose();
              setState(() {
                _selectedExercise = null;
                _cameraReady = false;
              });
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_cameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Container(
              color: FQColors.bg,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: FQColors.purple),
                  const SizedBox(height: 16),
                  Text('Initializing camera...',
                      style: GoogleFonts.rajdhani(
                          color: FQColors.muted, fontSize: 16)),
                ]),
              ),
            ),

          // Bounding box guide (only when not detecting)
          if (!_detecting)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: FQColors.purple.withOpacity(0.3),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    'POSITION FULL BODY INSIDE',
                    style: GoogleFonts.rajdhani(
                      color: FQColors.purple.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),

          // Pose skeleton overlay
          if (_poses.isNotEmpty && _cameraController != null)
            CustomPaint(
              painter: _PosePainter(
                poses: _poses,
                imageSize: Size(
                  // Fix: actual image dimensions (not swapped preview size)
                  _cameraController!.value.previewSize?.height ?? 1,
                  _cameraController!.value.previewSize?.width ?? 1,
                ),
                screenSize: MediaQuery.of(context).size,
              ),
            ),

          // Rep counter / hold timer overlay (top left)
          if (_detecting)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: FQColors.purple.withOpacity(0.5)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      _selectedExercise?.isPlank == true ? 'HOLD' : 'REPS',
                      style: GoogleFonts.rajdhani(
                          color: FQColors.muted,
                          fontSize: 10,
                          letterSpacing: 2)),
                  Text(
                      _selectedExercise?.isPlank == true
                          ? '${_plankSeconds}s'
                          : '$_repCount',
                      style: GoogleFonts.rajdhani(
                          color: FQColors.purple,
                          fontSize: 40,
                          fontWeight: FontWeight.bold)),
                  if (_phase.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _phase == 'DOWN' ||
                                _phase == 'FLOOR' ||
                                _phase == 'HOLD'
                            ? FQColors.green.withOpacity(0.2)
                            : FQColors.cyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_phase,
                          style: GoogleFonts.rajdhani(
                              color: _phase == 'DOWN' ||
                                      _phase == 'FLOOR' ||
                                      _phase == 'HOLD'
                                  ? FQColors.green
                                  : FQColors.cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                ]),
              ),
            ),

          // Hint overlay at bottom
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: FQColors.purple.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.tips_and_updates_outlined,
                        color: FQColors.purple, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_hint,
                          style: GoogleFonts.rajdhani(
                              color: Colors.white, fontSize: 14)),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          // Start/Stop button
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _cameraReady ? _toggleDetection : null,
                icon: Icon(_detecting ? Icons.stop : Icons.play_arrow),
                label: Text(_detecting ? 'STOP' : 'START',
                    style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 2)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _detecting ? FQColors.red : FQColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSelector() {
    return Scaffold(
      backgroundColor: FQColors.bg,
      appBar: AppBar(
        backgroundColor: FQColors.surface,
        foregroundColor: Colors.white,
        title: Text('POSE COACH',
            style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SELECT EXERCISE',
              style: GoogleFonts.rajdhani(
                  color: FQColors.muted,
                  fontSize: 12,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Choose the movement to track reps & form',
              style: TextStyle(color: FQColors.muted, fontSize: 12)),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.92,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _exercises.length,
              itemBuilder: (_, i) {
                final ex = _exercises[i];
                final diffColor = ex.difficulty == 'Beginner'
                    ? FQColors.green
                    : ex.difficulty == 'Advanced'
                        ? FQColors.red
                        : FQColors.gold;
                return GestureDetector(
                  onTap: () => _selectExercise(ex),
                  child: Container(
                    decoration: BoxDecoration(
                      color: FQColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: FQColors.purple.withOpacity(0.3)),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FQColors.purple.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(ex.icon,
                            color: FQColors.purple, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(ex.name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rajdhani(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      Text(ex.muscle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: FQColors.muted, fontSize: 9)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: diffColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(ex.difficulty,
                            style: TextStyle(
                                color: diffColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Analysis Result ───────────────────────────────────────────────────────────
class _AnalysisResult {
  final String hint;
  final String phase;
  final bool countRep;

  _AnalysisResult(this.hint, this.phase, this.countRep);
}

// ── Exercise Tip Sheet ────────────────────────────────────────────────────────
class _ExerciseTipSheet extends StatelessWidget {
  final _Exercise exercise;
  const _ExerciseTipSheet({required this.exercise});

  Color get _difficultyColor {
    switch (exercise.difficulty) {
      case 'Beginner':
        return FQColors.green;
      case 'Advanced':
        return FQColors.red;
      default:
        return FQColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: FQColors.border)),
      ),
      child: Column(children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 20),
          decoration: BoxDecoration(
            color: FQColors.muted.withOpacity(0.35),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header row: icon + name + chips
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FQColors.purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(exercise.icon, color: FQColors.purple, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(exercise.name.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      _chip(exercise.muscle, FQColors.cyan),
                      _chip(exercise.difficulty, _difficultyColor),
                      if (exercise.isPlank)
                        _chip('HOLD TIMER', FQColors.purple),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),

              // Camera placement box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FQColors.gold.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FQColors.gold.withOpacity(0.2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.videocam_outlined,
                      color: FQColors.gold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('CAMERA PLACEMENT',
                          style: GoogleFonts.rajdhani(
                              color: FQColors.gold,
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(exercise.cameraPlacement,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              // How-to steps
              Text('HOW TO PERFORM',
                  style: GoogleFonts.rajdhani(
                      color: FQColors.muted,
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...exercise.steps.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: FQColors.purple.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: FQColors.purple.withOpacity(0.4)),
                      ),
                      child: Text('${entry.key + 1}',
                          style: GoogleFonts.rajdhani(
                              color: FQColors.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(entry.value,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                    ),
                  ]),
                );
              }),
            ]),
          ),
        ),

        // START EXERCISE button
        Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.play_arrow),
              label: Text('START EXERCISE',
                  style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 2)),
              style: ElevatedButton.styleFrom(
                backgroundColor: FQColors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Pose Painter ──────────────────────────────────────────────────────────────
class _PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final Size screenSize;

  _PosePainter(
      {required this.poses,
      required this.imageSize,
      required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()
      ..color = FQColors.purple
      ..strokeWidth = 6
      ..style = PaintingStyle.fill;

    final bonePaint = Paint()
      ..color = FQColors.purple.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final pose in poses) {
      for (final landmark in pose.landmarks.values) {
        final x = landmark.x / imageSize.width * screenSize.width;
        final y = landmark.y / imageSize.height * screenSize.height;
        canvas.drawCircle(Offset(x, y), 5, jointPaint);
      }

      void drawLine(PoseLandmarkType a, PoseLandmarkType b) {
        final lmA = pose.landmarks[a];
        final lmB = pose.landmarks[b];
        if (lmA == null || lmB == null) return;
        canvas.drawLine(
          Offset(lmA.x / imageSize.width * screenSize.width,
              lmA.y / imageSize.height * screenSize.height),
          Offset(lmB.x / imageSize.width * screenSize.width,
              lmB.y / imageSize.height * screenSize.height),
          bonePaint,
        );
      }

      // Torso
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
      // Arms
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
      // Legs
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    }
  }

  @override
  bool shouldRepaint(covariant _PosePainter oldDelegate) =>
      oldDelegate.poses != poses;
}
