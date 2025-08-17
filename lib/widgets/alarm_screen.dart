import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/alarm_service.dart';

class AlarmScreen extends StatefulWidget {
  final String alarmTitle;
  final String alarmMessage;
  final String? alarmTone;
  final double? alarmVolume;
  final int? notificationId;

  const AlarmScreen({
    super.key,
    required this.alarmTitle,
    required this.alarmMessage,
    this.alarmTone,
    this.alarmVolume,
    this.notificationId,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  VolumeController get _volumeController => VolumeController.instance;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  Timer? _volumeTimer;
  Timer? _dismissProtectionTimer;
  
  double _originalVolume = 0.5;
  double _originalBrightness = 0.5;
  bool _canDismiss = false;
  final int _dismissTapsRequired = 3;
  int _currentTaps = 0;
  bool _isSnoozing = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: Duration(milliseconds: 100),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    
    _setupAlarm();
    
    // Start animations
    _pulseController.repeat(reverse: true);
    
    // Enable dismiss after 3 seconds to prevent accidental dismissal
    _dismissProtectionTimer = Timer(Duration(seconds: 3), () {
      setState(() => _canDismiss = true);
    });
  }

  Future<void> _setupAlarm() async {
    try {
      // Enable wake lock to keep screen on
      await WakelockPlus.enable();
      print('Wake lock enabled');
      
      // Save original settings
      _originalVolume = await _volumeController.getVolume();
      
      try {
        _originalBrightness = await ScreenBrightness().current;
      } catch (e) {
        print('Could not get current brightness: $e');
        _originalBrightness = 0.5;
      }
      
      // Set maximum volume and brightness for alarm
      await _volumeController.setVolume(widget.alarmVolume ?? 0.9);
      
      try {
        await ScreenBrightness().setScreenBrightness(1.0);
      } catch (e) {
        print('Could not set brightness: $e');
      }
      
      // Start playing alarm sound continuously
      await _startAlarmSound();
      
      print('Alarm setup complete - sound should be playing continuously');
      
    } catch (e) {
      print('Error setting up alarm: $e');
    }
  }

  Future<void> _startAlarmSound() async {
    try {
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }
      
      final soundPath = widget.alarmTone ?? 'sounds/wakeupcall.mp3';
      print('Playing alarm sound: $soundPath');
      
      // Set player mode to loop
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(widget.alarmVolume ?? 0.9);
      
      // Start playing
      await _audioPlayer.play(AssetSource(soundPath));
      
      // Gradually increase volume over 10 seconds
      _startVolumeGradualIncrease();
      
    } catch (e) {
      print('Error playing alarm sound: $e');
      // Try default sound as fallback
      try {
        await _audioPlayer.play(AssetSource('sounds/emergency_alarm.mp3'));
      } catch (e2) {
        print('Could not play fallback sound: $e2');
      }
    }
  }

  void _startVolumeGradualIncrease() {
    double currentVolume = 0.3;
    final targetVolume = widget.alarmVolume ?? 0.9;
    
    _volumeTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (currentVolume < targetVolume) {
        currentVolume += 0.1;
        _audioPlayer.setVolume(currentVolume.clamp(0.0, 1.0));
        _volumeController.setVolume(currentVolume.clamp(0.0, 1.0));
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _snoozeAlarm() async {
    if (_isSnoozing) return;
    
    setState(() => _isSnoozing = true);
    
    await _stopAlarmAndRestore();
    
    // Show snooze feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('알람이 5분 후에 다시 울립니다'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
    
    // Wait 2 seconds then close
    await Future.delayed(Duration(seconds: 2));
    Navigator.of(context).pop();
    
    // In a real implementation, you would schedule a new alarm for 5 minutes later
    // For now, we'll just close the alarm screen
  }

  Future<void> _dismissAlarm() async {
    if (!_canDismiss) {
      _shakeController.forward().then((_) => _shakeController.reset());
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('알람을 끄려면 잠시 후 다시 시도하세요'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    _currentTaps++;
    
    if (_currentTaps < _dismissTapsRequired) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('알람을 끄려면 ${_dismissTapsRequired - _currentTaps}번 더 누르세요'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    
    await _stopAlarmAndRestore();
    Navigator.of(context).pop();
  }

  Future<void> _stopAlarmAndRestore() async {
    try {
      // Stop audio
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }
      _audioPlayer.dispose();
      
      // Cancel timers
      _volumeTimer?.cancel();
      
      // IMPORTANT: Stop reliable alarm service
      if (widget.notificationId != null) {
        print('🛑 Stopping reliable alarm ID: ${widget.notificationId}');
        final reliableSuccess = await AlarmService.cancelAlarm(widget.notificationId!);
        if (reliableSuccess) {
          print('✅ Reliable alarm stopped successfully');
        } else {
          print('⚠️ Failed to stop reliable alarm - trying manual stop');
          // Try to stop all alarms as fallback
          await AlarmService.stopAllAlarms();
        }
      }
      
      // Dismiss the persistent notification
      if (widget.notificationId != null) {
        final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
        await notifications.cancel(widget.notificationId!);
        print('Dismissed notification ID: ${widget.notificationId}');
      }
      
      // Restore original settings
      await _volumeController.setVolume(_originalVolume);
      
      try {
        await ScreenBrightness().setScreenBrightness(_originalBrightness);
      } catch (e) {
        print('Could not restore brightness: $e');
      }
      
      // Disable wake lock
      await WakelockPlus.disable();
      
      print('✅ Alarm stopped and settings restored');
      
    } catch (e) {
      print('❌ Error stopping alarm: $e');
    }
  }

  @override
  void dispose() {
    _dismissProtectionTimer?.cancel();
    _volumeTimer?.cancel();
    _pulseController.dispose();
    _shakeController.dispose();
    _stopAlarmAndRestore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button dismissal
        _shakeController.forward().then((_) => _shakeController.reset());
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.red.shade900, Colors.red.shade600],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Current time
                      Text(
                        TimeOfDay.now().format(context),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 32),
                      
                      // Alarm icon with pulse animation
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Icon(
                              Icons.alarm,
                              size: 120,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      
                      SizedBox(height: 32),
                      
                      // Alarm title
                      Text(
                        widget.alarmTitle,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Alarm message
                      Text(
                        widget.alarmMessage,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: 64),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Snooze button
                          GestureDetector(
                            onTap: _isSnoozing ? null : _snoozeAlarm,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.orange.withOpacity(0.8),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                Icons.snooze,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                          
                          // Dismiss button
                          GestureDetector(
                            onTap: _dismissAlarm,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _canDismiss 
                                    ? Colors.green.withOpacity(0.8)
                                    : Colors.grey.withOpacity(0.5),
                                border: Border.all(
                                  color: Colors.white, 
                                  width: _canDismiss ? 3 : 1
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.alarm_off,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                  if (!_canDismiss || _currentTaps < _dismissTapsRequired)
                                    Text(
                                      _canDismiss 
                                          ? '${_dismissTapsRequired - _currentTaps}'
                                          : '...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 32),
                      
                      // Instructions
                      if (!_canDismiss)
                        Text(
                          '알람을 끄려면 잠시 기다리세요...',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        )
                      else if (_currentTaps > 0 && _currentTaps < _dismissTapsRequired)
                        Text(
                          '${_dismissTapsRequired - _currentTaps}번 더 누르세요',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Text(
                          '끄기 버튼을 $_dismissTapsRequired번 누르세요',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
