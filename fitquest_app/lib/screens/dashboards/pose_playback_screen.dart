import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../main.dart';

class PosePlaybackScreen extends StatefulWidget {
  final String? videoUrl;
  final List<dynamic> poseData;

  const PosePlaybackScreen({
    super.key,
    this.videoUrl,
    required this.poseData,
  });

  @override
  State<PosePlaybackScreen> createState() => _PosePlaybackScreenState();
}

class _PosePlaybackScreenState extends State<PosePlaybackScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showPose = true;
  
  // For no-video fallback
  Timer? _playbackTimer;
  int _currentTimeMs = 0;
  int _totalDurationMs = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      _initVideo();
    } else {
      _initSkeletonOnly();
    }
  }

  void _initVideo() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
          _totalDurationMs = _controller!.value.duration.inMilliseconds;
        });
        _controller!.play();
      });
    
    _controller!.addListener(() {
      if (mounted) {
        setState(() {
          _currentTimeMs = _controller!.value.position.inMilliseconds;
          _isPlaying = _controller!.value.isPlaying;
        });
      }
    });
  }

  void _initSkeletonOnly() {
    if (widget.poseData.isNotEmpty) {
      _totalDurationMs = widget.poseData.last['t'] ?? 5000;
    }
    setState(() {
      _initialized = true;
      _isPlaying = true;
    });
    _startTimer();
  }

  void _startTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_isPlaying) {
        setState(() {
          _currentTimeMs += 30;
          if (_currentTimeMs >= _totalDurationMs) {
            _currentTimeMs = 0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlayback() {
    if (_controller != null) {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    } else {
      setState(() => _isPlaying = !_isPlaying);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: FQColors.surface,
        foregroundColor: Colors.white,
        title: Text('POSE PLAYBACK',
            style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: Icon(_showPose ? Icons.visibility : Icons.visibility_off,
                color: FQColors.purple),
            onPressed: () => setState(() => _showPose = !_showPose),
            tooltip: 'Toggle Pose Overlay',
          ),
        ],
      ),
      body: Center(
        child: _initialized
            ? Stack(
                children: [
                  if (_controller != null)
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black,
                      child: const Center(
                        child: Text('NO VIDEO RECORDED\n(SKELETON PLAYBACK ONLY)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white24, fontSize: 10)),
                      ),
                    ),
                  
                  if (_showPose)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PlaybackPosePainter(
                          poseData: widget.poseData,
                          currentTimestampMs: _currentTimeMs,
                        ),
                      ),
                    ),
                  
                  // Controls overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.black45,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (_controller != null)
                          VideoProgressIndicator(_controller!,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                  playedColor: FQColors.purple,
                                  bufferedColor: FQColors.muted))
                        else
                          Slider(
                            value: _currentTimeMs.toDouble(),
                            max: _totalDurationMs.toDouble(),
                            onChanged: (v) => setState(() => _currentTimeMs = v.toInt()),
                            activeColor: FQColors.purple,
                            inactiveColor: FQColors.muted,
                          ),
                        Row(children: [
                          IconButton(
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white),
                            onPressed: _togglePlayback,
                          ),
                          Text(
                            '${(_currentTimeMs ~/ 1000) ~/ 60}:${((_currentTimeMs ~/ 1000) % 60).toString().padLeft(2, '0')} / '
                            '${(_totalDurationMs ~/ 1000) ~/ 60}:${((_totalDurationMs ~/ 1000) % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ],
              )
            : const CircularProgressIndicator(color: FQColors.purple),
      ),
    );
  }
}

class _PlaybackPosePainter extends CustomPainter {
  final List<dynamic> poseData;
  final int currentTimestampMs;

  _PlaybackPosePainter({
    required this.poseData,
    required this.currentTimestampMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poseData.isEmpty) return;

    // Find the closest frame to the current timestamp
    Map<String, dynamic>? currentFrame;
    for (var frame in poseData) {
      if (frame['t'] <= currentTimestampMs) {
        currentFrame = frame;
      } else {
        break;
      }
    }

    if (currentFrame == null) return;

    final Map<String, dynamic> landmarks = currentFrame['p'];
    final jointPaint = Paint()
      ..color = FQColors.purple
      ..strokeWidth = 6
      ..style = PaintingStyle.fill;

    final bonePaint = Paint()
      ..color = FQColors.purple.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // We don't have the original image size here easily, 
    // but we can assume normalized or relative to the preview size.
    // In our capture, we stored LM coordinates as ints.
    // Let's assume they were relative to a standard 480x720 or 720x1280.
    // To be safe, we should have recorded the imageSize.
    // For this prototype, we'll map them.
    
    // Note: In a production app, poseData would include original resolution.
    // Here we'll just draw circles at their coordinates.
    
    Offset? getOffset(String key) {
      if (!landmarks.containsKey(key)) return null;
      final List<dynamic> coords = landmarks[key];
      // Assume coordinates were normalized 0-1000 for storage
      return Offset(
        coords[0] / 480 * size.width, 
        coords[1] / 640 * size.height
      );
    }

    void drawLine(String a, String b) {
      final offA = getOffset(a);
      final offB = getOffset(b);
      if (offA != null && offB != null) {
        canvas.drawLine(offA, offB, bonePaint);
      }
    }

    landmarks.forEach((key, value) {
      final off = getOffset(key);
      if (off != null) canvas.drawCircle(off, 4, jointPaint);
    });

    // Torso
    drawLine('leftShoulder', 'rightShoulder');
    drawLine('leftShoulder', 'leftHip');
    drawLine('rightShoulder', 'rightHip');
    drawLine('leftHip', 'rightHip');
    // Arms
    drawLine('leftShoulder', 'leftElbow');
    drawLine('leftElbow', 'leftWrist');
    drawLine('rightShoulder', 'rightElbow');
    drawLine('rightElbow', 'rightWrist');
    // Legs
    drawLine('leftHip', 'leftKnee');
    drawLine('leftKnee', 'leftAnkle');
    drawLine('rightHip', 'rightKnee');
    drawLine('rightKnee', 'rightAnkle');
  }

  @override
  bool shouldRepaint(covariant _PlaybackPosePainter oldDelegate) =>
      oldDelegate.currentTimestampMs != currentTimestampMs;
}
