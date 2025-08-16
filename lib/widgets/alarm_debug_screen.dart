import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/alarm_diagnostic_service.dart';
import '../services/alarm_trigger_validator.dart';
import '../services/alarm_test_service.dart';
import '../services/alarm_system_monitor.dart';
import '../services/reliable_alarm_service.dart';
import '../services/basic_alarm_service.dart';
import '../services/shift_notification_service.dart';
import '../services/alarm_service_bridge.dart';
import '../models/basic_alarm.dart';
import '../models/shift_alarm.dart';
import '../models/shift_pattern.dart';
import '../models/shift_type.dart';

class AlarmDebugScreen extends StatefulWidget {
  final AlarmDiagnosticService diagnosticService;
  final AlarmTriggerValidator? triggerValidator;
  
  const AlarmDebugScreen({
    super.key,
    required this.diagnosticService,
    this.triggerValidator,
  });
  
  @override
  State<AlarmDebugScreen> createState() => _AlarmDebugScreenState();
}

class _AlarmDebugScreenState extends State<AlarmDebugScreen> {
  Map<String, dynamic>? _systemState;
  bool _isLoading = false;
  late final AlarmTestService _testService;
  late final AlarmSystemMonitor _systemMonitor;
  
  @override
  void initState() {
    super.initState();
    _testService = AlarmTestService(widget.diagnosticService.notifications);
    _systemMonitor = AlarmSystemMonitor(widget.diagnosticService.notifications);
    _loadSystemState();
  }
  
  Future<void> _loadSystemState() async {
    setState(() => _isLoading = true);
    try {
      final state = await widget.diagnosticService.getSystemState();
      setState(() => _systemState = state);
    } catch (e) {
      print('Error loading system state: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _runDiagnostics() async {
    setState(() => _isLoading = true);
    await widget.diagnosticService.forceDiagnosticCheck();
    await _loadSystemState();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Debug Console'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
            tooltip: 'Run Full Diagnostics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _systemState == null
              ? const Center(child: Text('No system data available'))
              : _buildDebugContent(),
    );
  }
  
  Widget _buildDebugContent() {
    final state = _systemState!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSystemInfoCard(state),
          const SizedBox(height: 16),
          _buildPermissionsCard(state),
          const SizedBox(height: 16),
          if (widget.triggerValidator != null) ...[
            _buildTriggerValidatorCard(),
            const SizedBox(height: 16),
          ],
          _buildAlarmsCard(state),
          const SizedBox(height: 16),
          _buildActionsCard(),
        ],
      ),
    );
  }
  
  Widget _buildSystemInfoCard(Map<String, dynamic> state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'System Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Current Time', state['currentTime']),
            _buildInfoRow('Current TZ Time', state['currentTZTime']),
            _buildInfoRow('Time Zone', state['timeZone']),
            _buildInfoRow('Time Zone Offset', '${state['timeZoneOffset']} minutes'),
            _buildInfoRow('TZ Local Location', state['tzLocalLocation']),
            _buildInfoRow('Diagnostic Running', state['diagnosticRunning'].toString()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPermissionsCard(Map<String, dynamic> state) {
    final exactAlarmPermission = state['exactAlarmPermission'];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  exactAlarmPermission == true ? Icons.check_circle : Icons.warning,
                  color: exactAlarmPermission == true ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Permissions Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPermissionRow(
              'Exact Alarm Permission',
              exactAlarmPermission,
              'Required for precise alarm scheduling',
            ),
            if (exactAlarmPermission != true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🚨 CRITICAL ISSUE DETECTED',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const SizedBox(height: 8),
                    const Text('Exact alarm permission is required for alarms to work properly.'),
                    const SizedBox(height: 8),
                    const Text('📋 Solution:'),
                    const Text('1. Go to device Settings > Apps > ShiftCalendar > Special app access'),
                    const Text('2. Find "Schedule exact alarms" or "Alarms & reminders"'),
                    const Text('3. Enable the permission for this app'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAlarmsCard(Map<String, dynamic> state) {
    final pendingAlarms = state['pendingAlarms'] as List<dynamic>;
    final alarmCount = state['pendingNotificationsCount'] as int;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  alarmCount > 0 ? Icons.alarm : Icons.alarm_off,
                  color: alarmCount > 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Alarms ($alarmCount)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alarmCount == 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ NO ALARMS SCHEDULED',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    Text('This is likely why your alarms are not triggering.'),
                    Text('Check if your shift patterns and alarms are properly configured.'),
                  ],
                ),
              ),
            ] else ...[
              const Text('Next few scheduled alarms:'),
              const SizedBox(height: 8),
              ...pendingAlarms.take(5).map((alarm) => _buildAlarmRow(alarm)),
              if (pendingAlarms.length > 5) ...[
                const SizedBox(height: 8),
                Text('... and ${pendingAlarms.length - 5} more alarms'),
              ],
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildTriggerValidatorCard() {
    final validator = widget.triggerValidator!;
    final missedAlarms = validator.missedAlarms;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_late, 
                     color: missedAlarms.isNotEmpty ? Colors.red : Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Trigger Validator',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: validator.isRunning ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    validator.isRunning ? 'ACTIVE' : 'STOPPED',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Status summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: missedAlarms.isEmpty ? Colors.green.shade50 : Colors.red.shade50,
                border: Border.all(
                  color: missedAlarms.isEmpty ? Colors.green : Colors.red,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    missedAlarms.isEmpty ? Icons.check_circle : Icons.error,
                    color: missedAlarms.isEmpty ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      missedAlarms.isEmpty 
                          ? 'No missed alarms detected' 
                          : '${missedAlarms.length} missed alarms detected',
                      style: TextStyle(
                        color: missedAlarms.isEmpty ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Missed alarms list
            if (missedAlarms.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Missed Alarms:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ...missedAlarms.map((alarm) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alarm.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('Scheduled: ${DateFormat('HH:mm').format(alarm.scheduledTime)}'),
                    Text('Overdue by: ${alarm.overdueBy.inMinutes} minutes'),
                  ],
                ),
              )),
              
              // Clear missed alarms button
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    validator.clearMissedAlarms();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Missed Alarms'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Diagnostic Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _runDiagnostics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Data'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (widget.diagnosticService.isRunning) {
                        widget.diagnosticService.stopDiagnosticMonitoring();
                      } else {
                        widget.diagnosticService.startDiagnosticMonitoring();
                      }
                      _loadSystemState();
                    },
                    icon: Icon(
                      widget.diagnosticService.isRunning 
                          ? Icons.stop 
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      widget.diagnosticService.isRunning 
                          ? 'Stop Monitor' 
                          : 'Start Monitor',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // System monitoring section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                border: Border.all(color: Colors.purple.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.monitor_heart, color: Colors.purple.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'System Monitoring',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Real-time system monitoring with automatic recovery for missed alarms.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _systemMonitor.startMonitoring();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🔍 System monitoring started - check console for detailed logs'),
                                backgroundColor: Colors.purple,
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Monitor'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _systemMonitor.stopMonitoring();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⏹️ System monitoring stopped'),
                                backgroundColor: Colors.grey,
                              ),
                            );
                          },
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Monitor'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purple.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test alarm section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Alarm Testing',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Test if alarms can trigger properly on your device.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _testService.testImmediateAlarm();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Test alarm scheduled for 5 seconds from now'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          },
                          icon: const Icon(Icons.alarm_add, size: 16),
                          label: const Text('Test 5s', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _testService.testDelayedAlarm();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Test alarm scheduled for 30 seconds from now'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          },
                          icon: const Icon(Icons.timer, size: 16),
                          label: const Text('Test 30s', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _testService.cancelTestAlarms();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Test alarms cancelled'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Cancel', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Direct alarm screen testing
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.screen_share, color: Colors.orange.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Alarm Screen Testing',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Test alarm screen navigation directly without notifications.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          print('🧪 Testing direct alarm screen navigation...');
                          
                          // Navigate directly to alarm screen with test data
                          Navigator.of(context).pushNamed('/alarm', arguments: {
                            'title': 'TEST ALARM',
                            'message': 'This is a direct navigation test',
                            'alarmTone': 'sounds/wakeupcall.mp3',
                            'alarmVolume': 0.9,
                            'notificationId': 88888,
                          });
                          
                          print('✅ Direct navigation initiated');
                        } catch (e) {
                          print('❌ Direct navigation failed: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Navigation failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.launch),
                      label: const Text('Open Alarm Screen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Reliable alarm testing (NEW)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Reliable Alarm System (NEW)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Test the new reliable alarm system with foreground service.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final success = await ReliableAlarmService.testImmediateAlarm();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success 
                                    ? '✅ Reliable alarm scheduled for 5 seconds!'
                                    : '❌ Failed to schedule reliable alarm'),
                                  backgroundColor: success ? Colors.green : Colors.red,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.alarm_add),
                          label: const Text('Test Reliable'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await ReliableAlarmService.stopAllAlarms();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🛑 All reliable alarms stopped'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop All'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Active alarms: ${ReliableAlarmService.getAllAlarms().length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Comprehensive alarm type testing (INTEGRATION TEST)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                border: Border.all(color: Colors.deepPurple.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.integration_instructions, color: Colors.deepPurple.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Integrated Alarm System Tests',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Test all alarm types with ReliableAlarmService integration. Each test schedules for 10 seconds.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  
                  // Basic Alarm Test
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _testBasicAlarmIntegration(),
                            icon: const Icon(Icons.access_time, size: 16),
                            label: const Text('Basic Alarm', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _testShiftAlarmIntegration('day_shift'),
                            icon: const Icon(Icons.wb_sunny, size: 16),
                            label: const Text('Day', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade600,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _testShiftAlarmIntegration('night_shift'),
                          icon: const Icon(Icons.brightness_2, size: 16),
                          label: const Text('Night', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.indigo.shade600,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _testShiftAlarmIntegration('day_off'),
                          icon: const Icon(Icons.free_breakfast, size: 16),
                          label: const Text('Day Off', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelAllTestAlarms(),
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Cancel', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📋 Test Checklist:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.deepPurple.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '✓ Alarm screen appears automatically\n'
                          '✓ Correct alarm tone plays\n'
                          '✓ User can dismiss the alarm\n'
                          '✓ Both notification and reliable service work',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPermissionRow(String label, bool? granted, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            granted == true ? Icons.check_circle : Icons.error,
            color: granted == true ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            granted == true ? 'Granted' : 'Denied',
            style: TextStyle(
              color: granted == true ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAlarmRow(Map<String, dynamic> alarm) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.alarm, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${alarm['title']} - ID: ${alarm['id']}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Test basic alarm integration with ReliableAlarmService
  Future<void> _testBasicAlarmIntegration() async {
    try {
      print('🧪 Testing BasicAlarm integration with ReliableAlarmService...');
      
      // Create a test basic alarm scheduled for 10 seconds from now
      final testTime = DateTime.now().add(const Duration(seconds: 10));
      final basicAlarm = BasicAlarm(
        id: 'test_basic_alarm_${DateTime.now().millisecondsSinceEpoch}',
        label: 'TEST Basic Alarm',
        time: TimeOfDay(hour: testTime.hour, minute: testTime.minute),
        repeatDays: {}, // One-time alarm
        isActive: true,
        tone: AlarmTone.emergencyAlarm, // Test with different tone
        volume: 0.8,
        createdAt: DateTime.now(),
      );
      
      print('Created test BasicAlarm: ${basicAlarm.label}');
      print('Scheduled for: ${testTime.hour.toString().padLeft(2, '0')}:${testTime.minute.toString().padLeft(2, '0')}');
      print('Tone: ${basicAlarm.tone.name} (${basicAlarm.tone.soundPath})');
      print('Volume: ${basicAlarm.volume}');
      
      // Create BasicAlarmService instance
      final basicAlarmService = BasicAlarmService(widget.diagnosticService.notifications);
      await basicAlarmService.initialize();
      
      // Schedule the alarm (this will use both notification and ReliableAlarmService)
      await basicAlarmService.scheduleBasicAlarm(basicAlarm);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Test BasicAlarm scheduled for 10 seconds with ${basicAlarm.tone.displayName} tone'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      print('✅ BasicAlarm integration test initiated successfully');
      
    } catch (e) {
      print('❌ BasicAlarm integration test failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ BasicAlarm test failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  /// Test shift alarm integration with ReliableAlarmService
  Future<void> _testShiftAlarmIntegration(String shiftTypeString) async {
    try {
      print('🧪 Testing ShiftAlarm ($shiftTypeString) integration with ReliableAlarmService...');
      
      // Map string to actual ShiftType enum
      ShiftType targetShiftType;
      switch (shiftTypeString) {
        case 'day_shift':
          targetShiftType = ShiftType.day;
          break;
        case 'night_shift':
          targetShiftType = ShiftType.night;
          break;
        case 'day_off':
          targetShiftType = ShiftType.off;
          break;
        default:
          targetShiftType = ShiftType.day;
      }
      
      // Create test shift pattern - simplified for testing
      final testPattern = ShiftPattern(
        id: 'test_pattern_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Pattern',
        cycle: [targetShiftType], // Simple single-shift cycle for testing
        startDate: DateTime.now(),
        isActive: true,
        createdAt: DateTime.now(),
      );
      
      // Create test alarm settings with different tones for each shift type
      AlarmTone testTone;
      switch (shiftTypeString) {
        case 'day_shift':
          testTone = AlarmTone.wakeupcall;
          break;
        case 'night_shift':
          testTone = AlarmTone.emergencyAlarm;
          break;
        case 'day_off':
          testTone = AlarmTone.gentleAcoustic;
          break;
        default:
          testTone = AlarmTone.wakeupcall;
      }
      
      final alarmSettings = AlarmSettings(
        vibration: true,
        sound: true,
        tone: testTone,
        volume: 0.9,
        snooze: true,
        snoozeDuration: 10,
        maxSnoozeCount: 3,
      );
      
      // Map shift type string to AlarmType
      AlarmType alarmType;
      switch (shiftTypeString) {
        case 'day_shift':
          alarmType = AlarmType.day;
          break;
        case 'night_shift':
          alarmType = AlarmType.night;
          break;
        case 'day_off':
          alarmType = AlarmType.off;
          break;
        default:
          alarmType = AlarmType.day;
      }
      
      // Create test shift alarm scheduled for 10 seconds from now
      final testTime = DateTime.now().add(const Duration(seconds: 10));
      final shiftAlarm = ShiftAlarm(
        id: 'test_shift_alarm_${shiftTypeString}_${DateTime.now().millisecondsSinceEpoch}',
        patternId: testPattern.id,
        alarmType: alarmType,
        targetShiftTypes: {targetShiftType},
        time: TimeOfDay(hour: testTime.hour, minute: testTime.minute),
        title: 'TEST ${shiftTypeString.toUpperCase()} Alarm',
        message: 'This is a test alarm for $shiftTypeString',
        isActive: true,
        settings: alarmSettings,
        createdAt: DateTime.now(),
      );
      
      print('Created test ShiftAlarm: ${shiftAlarm.title}');
      print('Pattern: ${testPattern.name} (cycle: ${testPattern.cycle.map((s) => s.name).join(', ')})');
      print('Tone: ${testTone.name} (${testTone.soundPath})');
      print('Volume: ${alarmSettings.volume}');
      
      // Create a simplified scheduled notification for testing
      final notificationId = DateTime.now().millisecondsSinceEpoch;
      
      // Use AlarmServiceBridge directly for testing
      final success = await AlarmServiceBridge.scheduleWithReliableService(
        id: notificationId,
        scheduledTime: testTime,
        title: shiftAlarm.title,
        message: shiftAlarm.message,
        settings: alarmSettings,
      );
      
      String displayName;
      switch (shiftTypeString) {
        case 'day_shift':
          displayName = 'Day Shift';
          break;
        case 'night_shift':
          displayName = 'Night Shift';
          break;
        case 'day_off':
          displayName = 'Day Off';
          break;
        default:
          displayName = shiftTypeString;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? '✅ Test $displayName alarm scheduled for 10 seconds with ${testTone.displayName} tone'
              : '⚠️ Test $displayName alarm creation attempted but may have failed'),
            backgroundColor: success ? _getShiftColor(shiftTypeString) : Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      print('✅ ShiftAlarm ($shiftTypeString) integration test initiated successfully');
      
    } catch (e) {
      print('❌ ShiftAlarm ($shiftTypeString) integration test failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $shiftTypeString test failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  /// Cancel all test alarms
  Future<void> _cancelAllTestAlarms() async {
    try {
      print('🧹 Cancelling all test alarms...');
      
      // Cancel all pending notifications with "TEST" in the title
      final pending = await widget.diagnosticService.notifications.pendingNotificationRequests();
      int cancelledCount = 0;
      
      for (final request in pending) {
        if (request.title?.contains('TEST') == true) {
          await widget.diagnosticService.notifications.cancel(request.id);
          
          // Also try to cancel from ReliableAlarmService
          try {
            await AlarmServiceBridge.cancelWithReliableService(request.id);
          } catch (e) {
            print('⚠️ Could not cancel reliable alarm ${request.id}: $e');
          }
          
          cancelledCount++;
          print('Cancelled test alarm: ${request.title} (ID: ${request.id})');
        }
      }
      
      // Also stop all reliable alarms (test alarms use high IDs)
      await ReliableAlarmService.stopAllAlarms();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🧹 Cancelled $cancelledCount test alarms and stopped all reliable alarms'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      print('✅ All test alarms cancelled successfully');
      
    } catch (e) {
      print('❌ Error cancelling test alarms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error cancelling test alarms: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  /// Get color for shift type
  Color _getShiftColor(String shiftType) {
    switch (shiftType) {
      case 'day_shift':
        return Colors.orange;
      case 'night_shift':
        return Colors.indigo;
      case 'day_off':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }
}