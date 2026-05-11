// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }
  runApp(const PlantBuddyApp());
}

class PlantBuddyApp extends StatelessWidget {
  const PlantBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D58),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7FAF5),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 44),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ApiClient _api = ApiClient();
  var _isAuthenticated = false;
  var _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final authenticated = await _api.restoreSession();
    if (!mounted) return;
    setState(() {
      _isAuthenticated = authenticated;
      _checkingAuth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAuthenticated) {
      return LoginScreen(
        api: _api,
        onLoggedIn: () => setState(() => _isAuthenticated = true),
      );
    }
    return HomeScreen(
      api: _api,
      onLogout: () {
        _api.logout();
        setState(() => _isAuthenticated = false);
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.api, required this.onLoggedIn, super.key});

  final ApiClient api;
  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  var _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Username and password are required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      widget.api.baseUrl = defaultApiBaseUrl();
      await widget.api.login(username, password);
      widget.onLoggedIn();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.local_florist,
                            size: 38, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text('Plant Buddy',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('Household plant care',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.secondary)),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _usernameController,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline)),
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline)),
                        obscureText: true,
                        onSubmitted: (_) => _login(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(message: _error!),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _loading ? null : _login,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.login),
                        label: const Text('Log In'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.api, required this.onLogout, super.key});

  final ApiClient api;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _selectedIndex = 0;
  var _loading = true;
  String? _error;
  List<dynamic> _plants = [];
  List<dynamic> _tasks = [];
  List<dynamic> _jobs = [];
  List<dynamic> _taskEvents = [];
  List<dynamic> _calendarDays = [];
  Map<String, dynamic>? _selectedPlant;
  Map<String, dynamic>? _carePlan;
  Map<String, dynamic>? _latestAnalysis;
  Map<String, dynamic>? _deepAnalysis;
  List<dynamic> _analysisHistory = [];
  List<dynamic> _photos = [];
  List<dynamic> _chatSessions = [];
  List<dynamic> _chatMessages = [];
  Map<String, dynamic>? _selectedChatSession;
  Timer? _pollTimer;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedCalendarDay = _today();

  @override
  void initState() {
    super.initState();
    _loadAll();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _refreshQuietly());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plants = await widget.api.getList('/plants');
      final tasks = await widget.api.getList('/tasks');
      final jobs = await widget.api.getList('/jobs');
      final calendarDays = await _fetchCalendarDays(_calendarMonth);
      setState(() {
        _plants = plants;
        _tasks = tasks;
        _jobs = jobs;
        _calendarDays = calendarDays;
        if (_selectedPlant == null && plants.isNotEmpty) {
          _selectedPlant = plants.first as Map<String, dynamic>;
        } else if (_selectedPlant != null) {
          _selectedPlant =
              _firstPlantById(plants, _selectedPlant!['id'] as String);
        }
      });
      await _loadSelectedPlantDetails();
    } catch (error) {
      _handleError(error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshQuietly() async {
    if (!_loading) {
      try {
        final plants = await widget.api.getList('/plants');
        final tasks = await widget.api.getList('/tasks');
        final jobs = await widget.api.getList('/jobs');
        final calendarDays = await _fetchCalendarDays(_calendarMonth);
        if (!mounted) return;
        setState(() {
          _plants = plants;
          _tasks = tasks;
          _jobs = jobs;
          _calendarDays = calendarDays;
          if (_selectedPlant != null) {
            _selectedPlant =
                _firstPlantById(plants, _selectedPlant!['id'] as String);
          }
        });
        await _loadSelectedPlantDetails(silent: true);
      } catch (error) {
        if (error is AuthExpiredException) {
          widget.onLogout();
        }
      }
    }
  }

  Future<void> _loadSelectedPlantDetails({bool silent = false}) async {
    final plant = _selectedPlant;
    if (plant == null) {
      setState(() {
        _carePlan = null;
        _latestAnalysis = null;
        _deepAnalysis = null;
        _analysisHistory = [];
        _photos = [];
        _chatSessions = [];
        _chatMessages = [];
        _selectedChatSession = null;
      });
      return;
    }
    try {
      final photos = await widget.api.getList('/plants/${plant['id']}/photos');
      final taskEvents =
          await widget.api.getList('/plants/${plant['id']}/task-events');
      final chatSessions =
          await widget.api.getList('/plants/${plant['id']}/chat/sessions');
      Map<String, dynamic>? carePlan;
      Map<String, dynamic>? analysis;
      Map<String, dynamic>? deepAnalysis;
      List<dynamic> analysisHistory = [];
      Map<String, dynamic>? selectedChatSession;
      List<dynamic> chatMessages = [];
      try {
        carePlan = await widget.api.getMap('/plants/${plant['id']}/care-plan');
      } catch (error) {
        if (error is AuthExpiredException) rethrow;
      }
      try {
        analysis =
            await widget.api.getMap('/plants/${plant['id']}/analysis/latest');
      } catch (error) {
        if (error is AuthExpiredException) rethrow;
      }
      try {
        analysisHistory =
            await widget.api.getList('/plants/${plant['id']}/analysis');
      } catch (error) {
        if (error is AuthExpiredException) rethrow;
      }
      try {
        deepAnalysis = await widget.api
            .getMap('/plants/${plant['id']}/deep-analysis/latest');
      } catch (error) {
        if (error is AuthExpiredException) rethrow;
      }
      if (chatSessions.isNotEmpty) {
        selectedChatSession =
            _firstMapById(chatSessions, _selectedChatSession?['id']) ??
                chatSessions.first as Map<String, dynamic>;
        chatMessages = await widget.api
            .getList('/chat/sessions/${selectedChatSession['id']}/messages');
      }
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _taskEvents = taskEvents;
        _carePlan = carePlan;
        _latestAnalysis = analysis;
        _deepAnalysis = deepAnalysis;
        _analysisHistory = analysisHistory;
        _chatSessions = chatSessions;
        _selectedChatSession = selectedChatSession;
        _chatMessages = chatMessages;
      });
    } catch (error) {
      if (!silent) {
        _handleError(error);
      } else if (error is AuthExpiredException) {
        widget.onLogout();
      }
    }
  }

  void _handleError(Object error) {
    if (error is AuthExpiredException) {
      widget.onLogout();
      return;
    }
    if (mounted) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _createPlant() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const PlantFormDialog(),
    );
    if (result == null) return;
    try {
      final iconFile = result.remove('icon_file') as html.File?;
      final plant = await widget.api.postJson('/plants', result);
      if (iconFile != null) {
        await widget.api.uploadFile('/plants/${plant['id']}/icon', iconFile);
      }
      setState(() => _selectedPlant = plant);
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _uploadPlantIcon() async {
    final plant = _selectedPlant;
    if (plant == null) return;
    try {
      final file = await pickImageFile();
      if (file == null) return;
      final updated = await widget.api.uploadFile('/plants/${plant['id']}/icon', file);
      setState(() => _selectedPlant = updated);
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _uploadPhoto({bool registration = false}) async {
    final plant = _selectedPlant;
    if (plant == null) return;
    try {
      final file = await pickImageFile();
      if (file == null) return;
      await widget.api.uploadFile(
          '/plants/${plant['id']}/photos?is_registration_photo=$registration',
          file);
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _analyzePhoto(Map<String, dynamic> photo) async {
    try {
      await widget.api.postJson('/photos/${photo['id']}/analyze', {});
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    try {
      await widget.api.delete('/photos/${photo['id']}');
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _runDeepAnalysis() async {
    final plant = _selectedPlant;
    if (plant == null) return;
    try {
      final result =
          await widget.api.postJson('/plants/${plant['id']}/deep-analysis', {});
      setState(() => _deepAnalysis = result);
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _applyDeepAnalysis() async {
    final plant = _selectedPlant;
    final analysis = _deepAnalysis;
    if (plant == null || analysis == null) return;
    try {
      final result = await widget.api.postJson(
          '/plants/${plant['id']}/deep-analysis/${analysis['id']}/apply', {});
      setState(() => _deepAnalysis = result);
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _completeTask(Map<String, dynamic> task) async {
    try {
      await widget.api
          .postJson('/tasks/${task['id']}/complete', {'notes': null});
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _editTask(Map<String, dynamic> task) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TaskFormDialog(task: task),
    );
    if (result == null) return;
    try {
      await widget.api.patchJson('/tasks/${task['id']}', result);
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _createTask() async {
    final plant = _selectedPlant;
    if (plant == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TaskFormDialog(plantId: plant['id'] as String),
    );
    if (result == null) return;
    try {
      await widget.api.postJson('/tasks', result);
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _deleteSelectedPlant() async {
    final plant = _selectedPlant;
    if (plant == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete plant?'),
        content: Text('Delete ${plant['pet_name']} and its stored photos?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.delete('/plants/${plant['id']}');
      setState(() => _selectedPlant = null);
      await _loadAll();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _sendChatMessage(String content) async {
    final plant = _selectedPlant;
    if (plant == null) return;
    try {
      var session = _selectedChatSession;
      if (session == null) {
        session = await widget.api.postJson(
            '/plants/${plant['id']}/chat/sessions',
            {'title': 'Chat with ${plant['pet_name']}'});
        setState(() => _selectedChatSession = session);
      }
      final localMessages = List<dynamic>.from(_chatMessages)
        ..add({'role': 'user', 'content': content})
        ..add({'role': 'assistant', 'content': '_Thinking..._'});
      setState(() => _chatMessages = localMessages);
      var hasDelta = false;
      await widget.api.streamChatMessage(
        session['id'] as String,
        content,
        onDelta: (delta) {
          setState(() {
            final messages = List<dynamic>.from(_chatMessages);
            final last = Map<String, dynamic>.from(messages.last as Map);
            last['content'] = '${hasDelta ? last['content'] ?? '' : ''}$delta';
            hasDelta = true;
            messages[messages.length - 1] = last;
            _chatMessages = messages;
          });
        },
      );
      final messages =
          await widget.api.getList('/chat/sessions/${session['id']}/messages');
      final sessions =
          await widget.api.getList('/plants/${plant['id']}/chat/sessions');
      setState(() {
        _chatMessages = messages;
        _chatSessions = sessions;
      });
    } catch (error) {
      if (error is AuthExpiredException) {
        _handleError(error);
        return;
      }
      setState(() {
        _error = error.toString();
        if (_chatMessages.isNotEmpty) {
          final messages = List<dynamic>.from(_chatMessages);
          final last = Map<String, dynamic>.from(messages.last as Map);
          if (last['role'] == 'assistant' &&
              (last['content'] == null ||
                  last['content'] == '' ||
                  last['content'] == '_Thinking..._')) {
            last['content'] = '**Chat failed.** ${error.toString()}';
            messages[messages.length - 1] = last;
            _chatMessages = messages;
          }
        }
      });
    }
  }

  Future<void> _clearChat() async {
    final session = _selectedChatSession;
    if (session == null) return;
    try {
      await widget.api.delete('/chat/sessions/${session['id']}/messages');
      setState(() => _chatMessages = []);
    } catch (error) {
      _handleError(error);
    }
  }

  Future<List<dynamic>> _fetchCalendarDays(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    return widget.api.getList(
        '/calendar?start=${_dateString(start)}&end=${_dateString(end)}');
  }

  Future<void> _changeCalendarMonth(int delta) async {
    final nextMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month + delta);
    final days = await _fetchCalendarDays(nextMonth);
    setState(() {
      _calendarMonth = nextMonth;
      _selectedCalendarDay = DateTime(nextMonth.year, nextMonth.month, 1);
      _calendarDays = days;
    });
  }

  Future<void> _exportCalendar() async {
    try {
      final start = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
      final end = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
      await widget.api.downloadIcs(
          '/calendar.ics?start=${_dateString(start)}&end=${_dateString(end)}');
    } catch (error) {
      _handleError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _TasksPage(
        tasks: _tasks,
        plants: _plants,
        onCompleteTask: _completeTask,
        onEditTask: _editTask,
      ),
      _PlantsPage(
        api: widget.api,
        plants: _plants,
        selectedPlant: _selectedPlant,
        photos: _photos,
        carePlan: _carePlan,
        latestAnalysis: _latestAnalysis,
        deepAnalysis: _deepAnalysis,
        analysisHistory: _analysisHistory,
        chatSessions: _chatSessions,
        chatMessages: _chatMessages,
        selectedChatSession: _selectedChatSession,
        tasks: _tasks,
        taskEvents: _taskEvents,
        jobs: _jobs,
        onSelectPlant: (plant) async {
          setState(() => _selectedPlant = plant);
          await _loadSelectedPlantDetails();
        },
        onCreatePlant: _createPlant,
        onUploadPhoto: () => _uploadPhoto(registration: false),
        onUploadRegistrationPhoto: () => _uploadPhoto(registration: true),
        onUploadPlantIcon: _uploadPlantIcon,
        onAnalyzePhoto: _analyzePhoto,
        onDeletePhoto: _deletePhoto,
        onRunDeepAnalysis: _runDeepAnalysis,
        onApplyDeepAnalysis: _applyDeepAnalysis,
        onSendChatMessage: _sendChatMessage,
        onClearChat: _clearChat,
        onCompleteTask: _completeTask,
        onEditTask: _editTask,
        onCreateTask: _createTask,
        onDeletePlant: _deleteSelectedPlant,
      ),
      _CalendarPage(
        month: _calendarMonth,
        selectedDay: _selectedCalendarDay,
        calendarDays: _calendarDays,
        plants: _plants,
        onPreviousMonth: () => _changeCalendarMonth(-1),
        onNextMonth: () => _changeCalendarMonth(1),
        onSelectDay: (day) => setState(() => _selectedCalendarDay = day),
        onExport: _exportCalendar,
      ),
    ];

    final content = _loading
        ? const _LoadingState()
        : Column(
            children: [
              if (_error != null)
                _AppErrorBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null),
                ),
              Expanded(child: pages[_selectedIndex]),
            ],
          );
    const destinations = [
      NavigationDestination(
          icon: Icon(Icons.checklist_outlined), label: 'Tasks'),
      NavigationDestination(
          icon: Icon(Icons.local_florist_outlined), label: 'Plants'),
      NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 1040;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Plant Buddy'),
            centerTitle: false,
            actions: [
              IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh)),
              IconButton(
                  tooltip: 'Log out',
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout)),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: useRail
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (index) =>
                            setState(() => _selectedIndex = index),
                        labelType: NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: IconButton.filled(
                            tooltip: 'Add plant',
                            onPressed: _createPlant,
                            icon: const Icon(Icons.add),
                          ),
                        ),
                        destinations: const [
                          NavigationRailDestination(
                              icon: Icon(Icons.checklist_outlined),
                              label: Text('Tasks')),
                          NavigationRailDestination(
                              icon: Icon(Icons.local_florist_outlined),
                              label: Text('Plants')),
                          NavigationRailDestination(
                              icon: Icon(Icons.calendar_month_outlined),
                              label: Text('Calendar')),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
          floatingActionButton: !useRail && _selectedIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: _createPlant,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Plant'),
                )
              : null,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: destinations,
                ),
        );
      },
    );
  }
}

class _PlantsPage extends StatelessWidget {
  const _PlantsPage({
    required this.api,
    required this.plants,
    required this.selectedPlant,
    required this.photos,
    required this.carePlan,
    required this.latestAnalysis,
    required this.deepAnalysis,
    required this.analysisHistory,
    required this.chatSessions,
    required this.chatMessages,
    required this.selectedChatSession,
    required this.tasks,
    required this.taskEvents,
    required this.jobs,
    required this.onSelectPlant,
    required this.onCreatePlant,
    required this.onUploadPhoto,
    required this.onUploadRegistrationPhoto,
    required this.onUploadPlantIcon,
    required this.onAnalyzePhoto,
    required this.onDeletePhoto,
    required this.onRunDeepAnalysis,
    required this.onApplyDeepAnalysis,
    required this.onSendChatMessage,
    required this.onClearChat,
    required this.onCompleteTask,
    required this.onEditTask,
    required this.onCreateTask,
    required this.onDeletePlant,
  });

  final ApiClient api;
  final List<dynamic> plants;
  final Map<String, dynamic>? selectedPlant;
  final List<dynamic> photos;
  final Map<String, dynamic>? carePlan;
  final Map<String, dynamic>? latestAnalysis;
  final Map<String, dynamic>? deepAnalysis;
  final List<dynamic> analysisHistory;
  final List<dynamic> chatSessions;
  final List<dynamic> chatMessages;
  final Map<String, dynamic>? selectedChatSession;
  final List<dynamic> tasks;
  final List<dynamic> taskEvents;
  final List<dynamic> jobs;
  final ValueChanged<Map<String, dynamic>> onSelectPlant;
  final VoidCallback onCreatePlant;
  final VoidCallback onUploadPhoto;
  final VoidCallback onUploadRegistrationPhoto;
  final VoidCallback onUploadPlantIcon;
  final ValueChanged<Map<String, dynamic>> onAnalyzePhoto;
  final ValueChanged<Map<String, dynamic>> onDeletePhoto;
  final Future<void> Function() onRunDeepAnalysis;
  final Future<void> Function() onApplyDeepAnalysis;
  final Future<void> Function(String content) onSendChatMessage;
  final Future<void> Function() onClearChat;
  final ValueChanged<Map<String, dynamic>> onCompleteTask;
  final ValueChanged<Map<String, dynamic>> onEditTask;
  final VoidCallback onCreateTask;
  final VoidCallback onDeletePlant;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final listPanel = SizedBox(
          width: isDesktop ? 330 : null,
          child: _PlantList(
              api: api,
              plants: plants,
              selectedPlant: selectedPlant,
              onSelectPlant: onSelectPlant,
              onCreatePlant: onCreatePlant),
        );
        final detailPanel = selectedPlant == null
            ? const _EmptyState(
                icon: Icons.local_florist_outlined,
                title: 'No plant selected',
                body: 'Add or select a plant to continue.')
            : _PlantDetail(
                api: api,
                plant: selectedPlant!,
                photos: photos,
                carePlan: carePlan,
                latestAnalysis: latestAnalysis,
                deepAnalysis: deepAnalysis,
                analysisHistory: analysisHistory,
                chatSessions: chatSessions,
                chatMessages: chatMessages,
                selectedChatSession: selectedChatSession,
                tasks: tasks
                    .where((task) => task['plant_id'] == selectedPlant!['id'])
                    .toList(),
                taskEvents: taskEvents,
                jobs: jobs
                    .where((job) => job['plant_id'] == selectedPlant!['id'])
                    .toList(),
                onUploadPhoto: onUploadPhoto,
                onUploadRegistrationPhoto: onUploadRegistrationPhoto,
                onUploadPlantIcon: onUploadPlantIcon,
                onAnalyzePhoto: onAnalyzePhoto,
                onDeletePhoto: onDeletePhoto,
                onRunDeepAnalysis: onRunDeepAnalysis,
                onApplyDeepAnalysis: onApplyDeepAnalysis,
                onSendChatMessage: onSendChatMessage,
                onClearChat: onClearChat,
                onCompleteTask: onCompleteTask,
                onEditTask: onEditTask,
                onCreateTask: onCreateTask,
                onDeletePlant: onDeletePlant,
              );
        return Padding(
          padding: const EdgeInsets.all(16),
          child: isDesktop
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  listPanel,
                  const SizedBox(width: 16),
                  Expanded(child: detailPanel)
                ])
              : ListView(children: [
                  listPanel,
                  const SizedBox(height: 16),
                  SizedBox(height: 720, child: detailPanel)
                ]),
        );
      },
    );
  }
}

class _PlantList extends StatefulWidget {
  const _PlantList(
      {required this.api,
      required this.plants,
      required this.selectedPlant,
      required this.onSelectPlant,
      required this.onCreatePlant});

  final ApiClient api;
  final List<dynamic> plants;
  final Map<String, dynamic>? selectedPlant;
  final ValueChanged<Map<String, dynamic>> onSelectPlant;
  final VoidCallback onCreatePlant;

  @override
  State<_PlantList> createState() => _PlantListState();
}

class _PlantListState extends State<_PlantList> {
  var _locationType = 'all';
  var _healthBand = 'all';
  final _locationController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.plants
        .cast<Map<String, dynamic>>()
        .where(_matchesFilters)
        .toList()
      ..sort((left, right) {
        final locationCompare =
            _plantLocationLabel(left).compareTo(_plantLocationLabel(right));
        if (locationCompare != 0) return locationCompare;
        return (left['pet_name'] ?? '')
            .toString()
            .compareTo((right['pet_name'] ?? '').toString());
      });
    final grouped = _groupPlantsByLocation(filtered);
    return _Panel(
      title: 'Plants',
      trailing: IconButton(
          tooltip: 'Add plant',
          onPressed: widget.onCreatePlant,
          icon: const Icon(Icons.add)),
      child: widget.plants.isEmpty
          ? const _EmptyState(
              icon: Icons.local_florist_outlined,
              title: 'No plants',
              body: 'Create a plant, then upload a registration photo.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'indoor', label: Text('Indoor')),
                        ButtonSegment(value: 'outdoor', label: Text('Outdoor')),
                      ],
                      selected: {_locationType},
                      onSelectionChanged: (values) =>
                          setState(() => _locationType = values.first),
                    ),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        value: _healthBand,
                        decoration:
                            const InputDecoration(labelText: 'Health'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                              value: 'healthy', child: Text('Healthy 8-10')),
                          DropdownMenuItem(
                              value: 'watch', child: Text('Watch 5-7')),
                          DropdownMenuItem(
                              value: 'attention',
                              child: Text('Attention 1-4')),
                          DropdownMenuItem(
                              value: 'unknown', child: Text('Unknown')),
                        ],
                        onChanged: (value) =>
                            setState(() => _healthBand = value ?? 'all'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Filter location',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const _EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No matching plants',
                      body: 'Adjust filters to see more plants.')
                else
                  ...grouped.entries.map((entry) => _PlantLocationGroup(
                        title: entry.key,
                        plants: entry.value,
                        api: widget.api,
                        selectedPlant: widget.selectedPlant,
                        onSelectPlant: widget.onSelectPlant,
                      )),
              ],
            ),
    );
  }

  bool _matchesFilters(Map<String, dynamic> plant) {
    if (_locationType != 'all' && plant['location'] != _locationType) {
      return false;
    }
    final filterText = _locationController.text.trim().toLowerCase();
    if (filterText.isNotEmpty &&
        !_plantLocationLabel(plant).toLowerCase().contains(filterText)) {
      return false;
    }
    final score = plant['health_score'] as int?;
    return switch (_healthBand) {
      'healthy' => score != null && score >= 8,
      'watch' => score != null && score >= 5 && score <= 7,
      'attention' => score != null && score >= 1 && score <= 4,
      'unknown' => score == null,
      _ => true,
    };
  }
}

class _PlantLocationGroup extends StatelessWidget {
  const _PlantLocationGroup({
    required this.title,
    required this.plants,
    required this.api,
    required this.selectedPlant,
    required this.onSelectPlant,
  });

  final String title;
  final List<Map<String, dynamic>> plants;
  final ApiClient api;
  final Map<String, dynamic>? selectedPlant;
  final ValueChanged<Map<String, dynamic>> onSelectPlant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          ...plants.map((plant) {
            final selected = selectedPlant?['id'] == plant['id'];
            return ListTile(
              selected: selected,
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: PlantIconAvatar(api: api, plant: plant),
              ),
              title: Text(plant['pet_name'] ?? ''),
              subtitle: Text([plant['common_name'], plant['location']]
                  .whereType<String>()
                  .where((text) => text.isNotEmpty)
                  .join(' / ')),
              trailing: plant['health_score'] == null
                  ? null
                  : _ScoreBadge(score: plant['health_score'] as int),
              onTap: () => onSelectPlant(plant),
            );
          }),
        ],
      ),
    );
  }
}

class _PlantDetail extends StatelessWidget {
  const _PlantDetail({
    required this.api,
    required this.plant,
    required this.photos,
    required this.carePlan,
    required this.latestAnalysis,
    required this.deepAnalysis,
    required this.analysisHistory,
    required this.chatSessions,
    required this.chatMessages,
    required this.selectedChatSession,
    required this.tasks,
    required this.taskEvents,
    required this.jobs,
    required this.onUploadPhoto,
    required this.onUploadRegistrationPhoto,
    required this.onUploadPlantIcon,
    required this.onAnalyzePhoto,
    required this.onDeletePhoto,
    required this.onRunDeepAnalysis,
    required this.onApplyDeepAnalysis,
    required this.onSendChatMessage,
    required this.onClearChat,
    required this.onCompleteTask,
    required this.onEditTask,
    required this.onCreateTask,
    required this.onDeletePlant,
  });

  final ApiClient api;
  final Map<String, dynamic> plant;
  final List<dynamic> photos;
  final Map<String, dynamic>? carePlan;
  final Map<String, dynamic>? latestAnalysis;
  final Map<String, dynamic>? deepAnalysis;
  final List<dynamic> analysisHistory;
  final List<dynamic> chatSessions;
  final List<dynamic> chatMessages;
  final Map<String, dynamic>? selectedChatSession;
  final List<dynamic> tasks;
  final List<dynamic> taskEvents;
  final List<dynamic> jobs;
  final VoidCallback onUploadPhoto;
  final VoidCallback onUploadRegistrationPhoto;
  final VoidCallback onUploadPlantIcon;
  final ValueChanged<Map<String, dynamic>> onAnalyzePhoto;
  final ValueChanged<Map<String, dynamic>> onDeletePhoto;
  final Future<void> Function() onRunDeepAnalysis;
  final Future<void> Function() onApplyDeepAnalysis;
  final Future<void> Function(String content) onSendChatMessage;
  final Future<void> Function() onClearChat;
  final ValueChanged<Map<String, dynamic>> onCompleteTask;
  final ValueChanged<Map<String, dynamic>> onEditTask;
  final VoidCallback onCreateTask;
  final VoidCallback onDeletePlant;

  @override
  Widget build(BuildContext context) {
    final latestPhoto =
        photos.isEmpty ? null : photos.first as Map<String, dynamic>;
    return ListView(
      children: [
        _Panel(
          title: plant['pet_name'] ?? 'Plant',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  tooltip: 'Delete plant',
                  onPressed: onDeletePlant,
                  icon: const Icon(Icons.delete_outline)),
              IconButton(
                  tooltip: 'Upload photo',
                  onPressed: onUploadPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined)),
              IconButton(
                  tooltip: 'Add icon',
                  onPressed: onUploadPlantIcon,
                  icon: const Icon(Icons.account_circle_outlined)),
              FilledButton.icon(
                  onPressed: onUploadRegistrationPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Register Photo')),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (latestPhoto != null)
                AuthImage(api: api, photoId: latestPhoto['id'] as String)
              else
                const _ImageFallback(),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InfoChip(
                      icon: Icons.home_outlined,
                      label: plant['location'] ?? 'unknown'),
                  if (plant['room_location'] != null)
                    _InfoChip(
                        icon: Icons.room_outlined,
                        label: plant['room_location']),
                  if (plant['health_score'] != null)
                    _InfoChip(
                        icon: Icons.favorite_outline,
                        label: 'Health ${plant['health_score']}/10'),
                  if (plant['common_name'] != null)
                    _InfoChip(
                        icon: Icons.eco_outlined, label: plant['common_name']),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Photo Timeline',
          child: _PhotoTimeline(
              api: api,
              photos: photos,
              onAnalyzePhoto: onAnalyzePhoto,
              onDeletePhoto: onDeletePhoto),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Health History',
          child: _HealthHistoryChart(analyses: analysisHistory),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Analysis',
          child: latestAnalysis == null
              ? _AnalysisPendingState(jobs: jobs)
              : _AnalysisDetails(analysis: latestAnalysis!, jobs: jobs),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Deep Analysis',
          child: _DeepAnalysisPanel(
            deepAnalysis: deepAnalysis,
            onRun: onRunDeepAnalysis,
            onApply: onApplyDeepAnalysis,
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Care Plan',
          child: carePlan == null
              ? const _EmptyState(
                  icon: Icons.spa_outlined,
                  title: 'No care plan yet',
                  body:
                      'Upload a registration photo and Plant Buddy will analyze it automatically.')
              : _CarePlanDetails(carePlan: carePlan!),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Tasks',
          trailing: IconButton(
              tooltip: 'Add task',
              onPressed: onCreateTask,
              icon: const Icon(Icons.add_task_outlined)),
          child: _TaskList(
              tasks: tasks,
              selectedPlant: plant,
              onComplete: onCompleteTask,
              onEdit: onEditTask),
        ),
        const SizedBox(height: 16),
        _Panel(title: 'Task History', child: _TaskHistory(events: taskEvents)),
        const SizedBox(height: 16),
        _Panel(
          title: 'Plant Chat',
          child: _PlantChatPanel(
            sessions: chatSessions,
            selectedSession: selectedChatSession,
            messages: chatMessages,
            onSend: onSendChatMessage,
            onClear: onClearChat,
          ),
        ),
      ],
    );
  }
}

class _TasksPage extends StatelessWidget {
  const _TasksPage({
    required this.tasks,
    required this.plants,
    required this.onCompleteTask,
    required this.onEditTask,
  });

  final List<dynamic> tasks;
  final List<dynamic> plants;
  final ValueChanged<Map<String, dynamic>> onCompleteTask;
  final ValueChanged<Map<String, dynamic>> onEditTask;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _Panel(
              title: 'Tasks By Need',
              child: _GroupedTaskList(
                  tasks: tasks,
                  plants: plants,
                  onComplete: onCompleteTask,
                  onEdit: onEditTask)),
        ],
      ),
    );
  }
}

class _PhotoTimeline extends StatefulWidget {
  const _PhotoTimeline(
      {required this.api,
      required this.photos,
      required this.onAnalyzePhoto,
      required this.onDeletePhoto});

  final ApiClient api;
  final List<dynamic> photos;
  final ValueChanged<Map<String, dynamic>> onAnalyzePhoto;
  final ValueChanged<Map<String, dynamic>> onDeletePhoto;

  @override
  State<_PhotoTimeline> createState() => _PhotoTimelineState();
}

class _PhotoTimelineState extends State<_PhotoTimeline> {
  final _pageController = PageController(viewportFraction: 0.92);
  var _index = 0;

  @override
  void didUpdateWidget(covariant _PhotoTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.photos.length) {
      _index = widget.photos.isEmpty ? 0 : widget.photos.length - 1;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const _EmptyState(
          icon: Icons.photo_library_outlined,
          title: 'No photos yet',
          body: 'Upload photos to track this plant over time.');
    }
    final current = widget.photos[_index] as Map<String, dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 330,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final photo = widget.photos[index] as Map<String, dynamic>;
              return GestureDetector(
                onLongPressStart: (details) =>
                    _showPhotoMenu(photo, details.globalPosition),
                onSecondaryTapDown: (details) =>
                    _showPhotoMenu(photo, details.globalPosition),
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AuthImage(
                      api: widget.api,
                      photoId: photo['id'] as String,
                      height: 330,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous photo',
              onPressed: _index == 0 ? null : () => _goTo(_index - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_index + 1} of ${widget.photos.length} / ${_shortDate(current['captured_at'] ?? current['created_at'])}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            IconButton(
              tooltip: 'Next photo',
              onPressed: _index >= widget.photos.length - 1
                  ? null
                  : () => _goTo(_index + 1),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'Delete photo',
              onPressed: () => _confirmDelete(current),
              icon: const Icon(Icons.delete_outline),
            ),
            TextButton.icon(
              onPressed: () => widget.onAnalyzePhoto(current),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Analyze'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final photo = widget.photos[index] as Map<String, dynamic>;
              final selected = index == _index;
              return GestureDetector(
                onLongPressStart: (details) =>
                    _showPhotoMenu(photo, details.globalPosition),
                onSecondaryTapDown: (details) =>
                    _showPhotoMenu(photo, details.globalPosition),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _goTo(index),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        width: selected ? 2 : 1,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: SizedBox(
                      width: 74,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AuthImage(
                              api: widget.api,
                              photoId: photo['id'] as String,
                              height: 74),
                          if (photo['is_registration_photo'] == true)
                            const Positioned(
                              right: 4,
                              top: 4,
                              child: Icon(Icons.verified,
                                  size: 16, color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _goTo(int index) {
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    setState(() => _index = index);
  }

  Future<void> _showPhotoMenu(
      Map<String, dynamic> photo, Offset position) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: const [
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete photo'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (action == 'delete') {
      _confirmDelete(photo);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text(
            'This removes the photo and any health history generated from it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onDeletePhoto(photo);
    }
  }
}

class _PlantChatPanel extends StatefulWidget {
  const _PlantChatPanel({
    required this.sessions,
    required this.selectedSession,
    required this.messages,
    required this.onSend,
    required this.onClear,
  });

  final List<dynamic> sessions;
  final Map<String, dynamic>? selectedSession;
  final List<dynamic> messages;
  final Future<void> Function(String content) onSend;
  final Future<void> Function() onClear;

  @override
  State<_PlantChatPanel> createState() => _PlantChatPanelState();
}

class _PlantChatPanelState extends State<_PlantChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  var _sending = false;

  @override
  void didUpdateWidget(covariant _PlantChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages.length != widget.messages.length ||
        (oldWidget.messages.isNotEmpty &&
            widget.messages.isNotEmpty &&
            oldWidget.messages.last['content'] !=
                widget.messages.last['content'])) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      _controller.clear();
      await widget.onSend(text);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _clear() async {
    if (_sending || widget.messages.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('This removes the saved messages for this chat.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onClear();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.selectedSession?['title'] ?? 'New chat',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Clear chat',
              onPressed: widget.messages.isEmpty || _sending ? null : _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 380,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.35),
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.messages.isEmpty
              ? const _EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No messages yet',
                  body: 'Ask about watering, light, pests, or care changes.')
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        widget.messages[index] as Map<String, dynamic>;
                    final isUser = message['role'] == 'user';
                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 620),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: MarkdownBody(
                          data: message['content'] ?? '',
                          selectable: true,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context))
                                  .copyWith(
                            p: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ask Plant Buddy',
                  prefixIcon: Icon(Icons.chat_outlined),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HealthHistoryChart extends StatelessWidget {
  const _HealthHistoryChart({required this.analyses});

  final List<dynamic> analyses;

  @override
  Widget build(BuildContext context) {
    final points = analyses
        .cast<Map<String, dynamic>>()
        .where((analysis) => analysis['health_score'] != null)
        .map((analysis) => HealthPoint(
            score: analysis['health_score'] as int,
            label: _shortDate(analysis['created_at'])))
        .toList();
    if (points.isEmpty) {
      return const _EmptyState(
          icon: Icons.show_chart_outlined,
          title: 'No health scores yet',
          body: 'Run analysis on one or more photos to build a trend.');
    }
    return SizedBox(
        height: 220,
        child: CustomPaint(
            painter: HealthChartPainter(
                points: points, color: Theme.of(context).colorScheme.primary),
            child: Container()));
  }
}

class _AnalysisHistory extends StatelessWidget {
  const _AnalysisHistory({required this.analyses});

  final List<dynamic> analyses;

  @override
  Widget build(BuildContext context) {
    if (analyses.isEmpty) {
      return const _EmptyState(
          icon: Icons.analytics_outlined,
          title: 'No analysis history',
          body: 'Analysis results will appear here over time.');
    }
    return Column(
      children: analyses.reversed.map((item) {
        final analysis = item as Map<String, dynamic>;
        return ListTile(
          leading: _ScoreBadge(score: analysis['health_score'] ?? 0),
          title: Text(
              '${analysis['common_name'] ?? 'Unknown'} (${analysis['scientific_name'] ?? 'unknown'})'),
          subtitle: Text(
              '${_shortDate(analysis['created_at'])} / Confidence ${analysis['confidence'] ?? 'n/a'}'),
        );
      }).toList(),
    );
  }
}

class _DeepAnalysisPanel extends StatefulWidget {
  const _DeepAnalysisPanel({
    required this.deepAnalysis,
    required this.onRun,
    required this.onApply,
  });

  final Map<String, dynamic>? deepAnalysis;
  final Future<void> Function() onRun;
  final Future<void> Function() onApply;

  @override
  State<_DeepAnalysisPanel> createState() => _DeepAnalysisPanelState();
}

class _DeepAnalysisPanelState extends State<_DeepAnalysisPanel> {
  var _running = false;
  var _applying = false;

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await widget.onRun();
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await widget.onApply();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.deepAnalysis;
    if (analysis == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _EmptyState(
            icon: Icons.biotech_outlined,
            title: 'No deep analysis yet',
            body:
                'Run a botanist-style review across representative dated photos.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.biotech_outlined),
            label: const Text('Run Deep Analysis'),
          ),
        ],
      );
    }

    final selectedPhotos =
        ((analysis['selected_photos'] as Map<String, dynamic>?)?['photos']
                as List<dynamic>? ??
            []);
    final specialTasks =
        ((analysis['special_tasks'] as Map<String, dynamic>?)?['tasks']
                as List<dynamic>? ??
            []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _running ? null : _run,
              icon: const Icon(Icons.refresh),
              label: const Text('Run Again'),
            ),
            FilledButton.icon(
              onPressed:
                  analysis['applied'] == true || _applying ? null : _apply,
              icon: _applying
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.task_alt_outlined),
              label: Text(analysis['applied'] == true
                  ? 'Suggestions Applied'
                  : 'Adjust Plan'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DeepAnalysisTextBlock(
            title: 'Review', value: analysis['review']?.toString()),
        _DeepAnalysisTextBlock(
            title: 'Trajectory', value: analysis['trajectory']?.toString()),
        _DeepAnalysisTextBlock(
            title: 'Recommendations',
            value: analysis['recommendations']?.toString()),
        if (selectedPhotos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Photos reviewed',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedPhotos
                .map((photo) => Chip(
                      avatar: const Icon(Icons.photo_outlined, size: 16),
                      label: Text(_shortDate(
                          (photo as Map<String, dynamic>)['created_at'])),
                    ))
                .toList(),
          ),
        ],
        if (specialTasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Special tasks',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          ...specialTasks.map((task) {
            final mapped = task as Map<String, dynamic>;
            return ListTile(
              dense: true,
              leading: Icon(_taskIcon(mapped['task_type'] as String?)),
              title: Text(mapped['title'] ?? ''),
              subtitle: Text(mapped['notes'] ?? ''),
            );
          }),
        ],
      ],
    );
  }
}

class _DeepAnalysisTextBlock extends StatelessWidget {
  const _DeepAnalysisTextBlock({required this.title, required this.value});

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          MarkdownBody(data: value!, selectable: true),
        ],
      ),
    );
  }
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage({
    required this.month,
    required this.selectedDay,
    required this.calendarDays,
    required this.plants,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDay,
    required this.onExport,
  });

  final DateTime month;
  final DateTime selectedDay;
  final List<dynamic> calendarDays;
  final List<dynamic> plants;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final byDay = _calendarTasksByDay(calendarDays);
    final selectedTasks = byDay[_dateString(selectedDay)] ?? [];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          final calendar = _Panel(
            title: _monthTitle(month),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                    tooltip: 'Previous month',
                    onPressed: onPreviousMonth,
                    icon: const Icon(Icons.chevron_left)),
                IconButton(
                    tooltip: 'Next month',
                    onPressed: onNextMonth,
                    icon: const Icon(Icons.chevron_right)),
                IconButton(
                    tooltip: 'Export calendar',
                    onPressed: onExport,
                    icon: const Icon(Icons.download_outlined)),
              ],
            ),
            child: _MonthGrid(
                month: month,
                selectedDay: selectedDay,
                tasksByDay: byDay,
                onSelectDay: onSelectDay),
          );
          final detail = _Panel(
            title: _dateString(selectedDay),
            child: selectedTasks.isEmpty
                ? const _EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'No tasks',
                    body: 'No plant care tasks are due on this day.')
                : _CalendarTaskList(tasks: selectedTasks, plants: plants),
          );
          if (isDesktop) {
            return ListView(
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 2, child: calendar),
                  const SizedBox(width: 16),
                  Expanded(child: detail)
                ]),
              ],
            );
          }
          return ListView(
              children: [calendar, const SizedBox(height: 16), detail]);
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid(
      {required this.month,
      required this.selectedDay,
      required this.tasksByDay,
      required this.onSelectDay});

  final DateTime month;
  final DateTime selectedDay;
  final Map<String, List<Map<String, dynamic>>> tasksByDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = first.weekday % 7;
    final totalCells = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          childAspectRatio: 1.1,
          children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((day) => Center(
                  child: Text(day,
                      style: const TextStyle(fontWeight: FontWeight.w800))))
              .toList(),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, childAspectRatio: 1.05),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            final dayNumber = index - leadingBlanks + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }
            final day = DateTime(month.year, month.month, dayNumber);
            final key = _dateString(day);
            final taskCount = tasksByDay[key]?.length ?? 0;
            final selected = _sameDate(day, selectedDay);
            final isToday = _sameDate(day, _today());
            return Padding(
              padding: const EdgeInsets.all(3),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelectDay(day),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$dayNumber',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (taskCount > 0)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle),
                            child: Text('$taskCount',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CalendarTaskList extends StatelessWidget {
  const _CalendarTaskList({required this.tasks, required this.plants});

  final List<Map<String, dynamic>> tasks;
  final List<dynamic> plants;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: tasks.map((task) {
        return ListTile(
          leading: Icon(_taskIcon(task['task_type'] as String?)),
          title: Text(task['title'] ?? ''),
          subtitle: Text([_plantName(plants, task['plant_id']), task['notes']]
              .whereType<String>()
              .where((text) => text.isNotEmpty)
              .join(' / ')),
        );
      }).toList(),
    );
  }
}

class PlantFormDialog extends StatefulWidget {
  const PlantFormDialog({super.key});

  @override
  State<PlantFormDialog> createState() => _PlantFormDialogState();
}

class _PlantFormDialogState extends State<PlantFormDialog> {
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();
  final _notesController = TextEditingController();
  var _location = 'indoor';
  html.File? _iconFile;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Plant'),
      content: SingleChildScrollView(
        child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Pet name')),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'indoor',
                    label: Text('Indoor'),
                    icon: Icon(Icons.home_outlined)),
                ButtonSegment(
                    value: 'outdoor',
                    label: Text('Outdoor'),
                    icon: Icon(Icons.yard_outlined)),
              ],
              selected: {_location},
              onSelectionChanged: (values) =>
                  setState(() => _location = values.first),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _roomController,
                decoration: const InputDecoration(labelText: 'Room location')),
            const SizedBox(height: 12),
            TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final file = await pickImageFile();
                if (file != null) {
                  setState(() => _iconFile = file);
                }
              },
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(_iconFile == null ? 'Add Icon' : 'Change Icon'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: _error!),
            ],
          ],
        ),
      ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) {
              setState(() => _error = 'Give the plant a pet name.');
              return;
            }
            Navigator.pop(context, {
              'pet_name': _nameController.text.trim(),
              'location': _location,
              'room_location': _roomController.text.trim(),
              'notes': _notesController.text.trim(),
              'icon_file': _iconFile,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({this.task, this.plantId, super.key});

  final Map<String, dynamic>? task;
  final String? plantId;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _frequencyController;
  late final TextEditingController _dueController;
  late String _taskType;
  late bool _enabled;
  String? _error;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?['title'] ?? '');
    _notesController = TextEditingController(text: task?['notes'] ?? '');
    _frequencyController =
        TextEditingController(text: task?['frequency_days']?.toString() ?? '');
    _dueController =
        TextEditingController(text: task?['next_due_date'] ?? _todayString());
    _taskType = task?['task_type'] ?? 'custom';
    _enabled = task?['enabled'] ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _frequencyController.dispose();
    _dueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Task' : 'Add Task'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            DropdownButtonFormField<String>(
              value: _taskType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'watering', child: Text('Watering')),
                DropdownMenuItem(
                    value: 'fertilizing', child: Text('Fertilizing')),
                DropdownMenuItem(value: 'repotting', child: Text('Repotting')),
                DropdownMenuItem(
                    value: 'inspection', child: Text('Inspection')),
                DropdownMenuItem(value: 'custom', child: Text('Custom')),
              ],
              onChanged: isEdit
                  ? null
                  : (value) => setState(() => _taskType = value ?? 'custom'),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3),
            const SizedBox(height: 12),
            TextField(
              controller: _frequencyController,
              decoration: const InputDecoration(
                  labelText: 'Frequency days', prefixIcon: Icon(Icons.repeat)),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dueController,
              decoration: const InputDecoration(
                  labelText: 'Next due date',
                  helperText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.event_outlined)),
            ),
            if (isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: _error!),
            ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) {
              setState(() => _error = 'Task title is required.');
              return;
            }
            final frequencyText = _frequencyController.text.trim();
            final frequency =
                frequencyText.isEmpty ? null : int.tryParse(frequencyText);
            if (frequencyText.isNotEmpty &&
                (frequency == null || frequency < 1)) {
              setState(() => _error = 'Frequency must be a positive number.');
              return;
            }
            final dueText = _dueController.text.trim();
            if (dueText.isNotEmpty && DateTime.tryParse(dueText) == null) {
              setState(() => _error = 'Use YYYY-MM-DD for the due date.');
              return;
            }
            final payload = <String, dynamic>{
              'task_type': _taskType,
              'title': _titleController.text.trim(),
              'notes': _notesController.text.trim(),
              'frequency_days': frequency,
              'next_due_date': dueText.isEmpty ? null : dueText,
            };
            if (isEdit) {
              payload['enabled'] = _enabled;
              payload.remove('task_type');
            } else {
              payload['plant_id'] = widget.plantId;
            }
            Navigator.pop(context, payload);
          },
          child: Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _GroupedTaskList extends StatelessWidget {
  const _GroupedTaskList(
      {required this.tasks,
      required this.plants,
      required this.onComplete,
      required this.onEdit});

  final List<dynamic> tasks;
  final List<dynamic> plants;
  final ValueChanged<Map<String, dynamic>> onComplete;
  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _EmptyState(
          icon: Icons.task_alt_outlined,
          title: 'No tasks yet',
          body: 'Analyze a plant or add a custom task.');
    }
    final today = _today();
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));
    final overdue = <Map<String, dynamic>>[];
    final todayTasks = <Map<String, dynamic>>[];
    final tomorrowTasks = <Map<String, dynamic>>[];
    final thisWeek = <Map<String, dynamic>>[];
    final upcoming = <Map<String, dynamic>>[];
    for (final item in tasks) {
      final task = item as Map<String, dynamic>;
      final due = _parseDate(task['next_due_date']);
      if (due != null && due.isBefore(today)) {
        overdue.add(task);
      } else if (due != null && _sameDate(due, today)) {
        todayTasks.add(task);
      } else if (due != null && _sameDate(due, tomorrow)) {
        tomorrowTasks.add(task);
      } else if (due != null && due.isBefore(weekEnd.add(const Duration(days: 1)))) {
        thisWeek.add(task);
      } else {
        upcoming.add(task);
      }
    }
    for (final list in [overdue, todayTasks, tomorrowTasks, thisWeek, upcoming]) {
      _sortTasksByDueAndLocation(list, plants);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TaskSection(
            title: 'Overdue',
            tasks: overdue,
            plants: plants,
            onComplete: onComplete,
            onEdit: onEdit,
            highlightOverdue: true),
        _TaskSection(
            title: 'Today',
            tasks: todayTasks,
            plants: plants,
            onComplete: onComplete,
            onEdit: onEdit,
            groupByLocation: true),
        _TaskSection(
            title: 'Tomorrow',
            tasks: tomorrowTasks,
            plants: plants,
            onComplete: onComplete,
            onEdit: onEdit,
            groupByLocation: true),
        _TaskSection(
            title: 'This Week',
            tasks: thisWeek,
            plants: plants,
            onComplete: onComplete,
            onEdit: onEdit),
        _TaskSection(
            title: 'Upcoming',
            tasks: upcoming,
            plants: plants,
            onComplete: onComplete,
            onEdit: onEdit),
      ],
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.tasks,
    required this.plants,
    required this.onComplete,
    required this.onEdit,
    this.highlightOverdue = false,
    this.groupByLocation = false,
  });

  final String title;
  final List<Map<String, dynamic>> tasks;
  final List<dynamic> plants;
  final ValueChanged<Map<String, dynamic>> onComplete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final bool highlightOverdue;
  final bool groupByLocation;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (groupByLocation)
            ..._groupTasksByLocation(tasks, plants).entries.map((entry) =>
                _TaskLocationGroup(
                    title: entry.key,
                    tasks: entry.value,
                    plants: plants,
                    onComplete: onComplete,
                    onEdit: onEdit,
                    forceOverdue: highlightOverdue))
          else
            ...tasks.map((task) => _TaskTile(
                task: task,
                plant: _plantById(plants, task['plant_id']),
                plantName: _plantName(plants, task['plant_id']),
                onComplete: onComplete,
                onEdit: onEdit,
                forceOverdue: highlightOverdue)),
        ],
      ),
    );
  }
}

class _TaskLocationGroup extends StatelessWidget {
  const _TaskLocationGroup({
    required this.title,
    required this.tasks,
    required this.plants,
    required this.onComplete,
    required this.onEdit,
    required this.forceOverdue,
  });

  final String title;
  final List<Map<String, dynamic>> tasks;
  final List<dynamic> plants;
  final ValueChanged<Map<String, dynamic>> onComplete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final bool forceOverdue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          ...tasks.map((task) => _TaskTile(
                task: task,
                plant: _plantById(plants, task['plant_id']),
                plantName: _plantName(plants, task['plant_id']),
                onComplete: onComplete,
                onEdit: onEdit,
                forceOverdue: forceOverdue,
              )),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList(
      {required this.tasks,
      this.plants = const [],
      this.selectedPlant,
      required this.onComplete,
      required this.onEdit});

  final List<dynamic> tasks;
  final List<dynamic> plants;
  final Map<String, dynamic>? selectedPlant;
  final ValueChanged<Map<String, dynamic>> onComplete;
  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _EmptyState(
          icon: Icons.task_alt_outlined,
          title: 'No tasks yet',
          body: 'Analysis will generate starter care tasks.');
    }
    return Column(
        children: tasks
            .map((task) {
              final mapped = task as Map<String, dynamic>;
              final plant = selectedPlant ??
                  _plantById(plants, mapped['plant_id']);
              return _TaskTile(
                  task: mapped,
                  plant: plant,
                  plantName: selectedPlant == null
                      ? _plantName(plants, mapped['plant_id'])
                      : selectedPlant?['pet_name']?.toString(),
                  onComplete: onComplete,
                  onEdit: onEdit);
            })
            .toList());
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile(
      {required this.task,
      required this.onComplete,
      required this.onEdit,
      this.plant,
      this.plantName,
      this.forceOverdue = false});

  final Map<String, dynamic> task;
  final Map<String, dynamic>? plant;
  final String? plantName;
  final ValueChanged<Map<String, dynamic>> onComplete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final bool forceOverdue;

  @override
  Widget build(BuildContext context) {
    final due = _parseDate(task['next_due_date']);
    final overdue = forceOverdue || (due != null && due.isBefore(_today()));
    final subtitleParts = [
      if (plantName != null) plantName!,
      if ((task['next_due_date'] ?? '').toString().isNotEmpty)
        'Due ${task['next_due_date']}',
      if ((task['notes'] ?? '').toString().isNotEmpty) task['notes'].toString(),
      if (task['frequency_days'] != null)
        'Every ${task['frequency_days']} days',
    ];
    return ListTile(
      minLeadingWidth: 72,
      leading: _TaskPlantMarker(
          plant: plant,
          taskType: task['task_type'] as String?,
          overdue: overdue),
      title: Text(task['title'] ?? '',
          style: TextStyle(
              color: overdue ? Theme.of(context).colorScheme.error : null,
              fontWeight: overdue ? FontWeight.w700 : null)),
      subtitle: Text(subtitleParts.join(' / ')),
      trailing: Wrap(
        spacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
              tooltip: 'Edit task',
              onPressed: () => onEdit(task),
              icon: const Icon(Icons.edit_outlined)),
          IconButton(
              tooltip: 'Complete task',
              onPressed: () => onComplete(task),
              icon: const Icon(Icons.check_circle_outline)),
        ],
      ),
    );
  }
}

class _TaskPlantMarker extends StatelessWidget {
  const _TaskPlantMarker(
      {required this.plant, required this.taskType, required this.overdue});

  final Map<String, dynamic>? plant;
  final String? taskType;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return SizedBox(
      width: 72,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_taskIcon(taskType), color: overdue ? errorColor : null),
          const SizedBox(width: 10),
          _TaskPlantThumb(plant: plant),
        ],
      ),
    );
  }
}

class _TaskPlantThumb extends StatefulWidget {
  const _TaskPlantThumb({required this.plant});

  final Map<String, dynamic>? plant;

  @override
  State<_TaskPlantThumb> createState() => _TaskPlantThumbState();
}

class _TaskPlantThumbState extends State<_TaskPlantThumb> {
  String? _objectUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _TaskPlantThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plant?['id'] != widget.plant?['id'] ||
        oldWidget.plant?['latest_photo_id'] != widget.plant?['latest_photo_id']) {
      _revoke();
      _load();
    }
  }

  @override
  void dispose() {
    _revoke();
    super.dispose();
  }

  Future<void> _load() async {
    final plant = widget.plant;
    final photoId = plant?['latest_photo_id'];
    if (photoId == null || photoId.toString().isEmpty) return;
    try {
      final blob = await ApiClient().fetchPhotoBlob(photoId.toString(), 'thumb_256');
      if (!mounted) return;
      setState(() => _objectUrl = html.Url.createObjectUrlFromBlob(blob));
    } catch (_) {}
  }

  void _revoke() {
    final url = _objectUrl;
    if (url != null) {
      html.Url.revokeObjectUrl(url);
    }
    _objectUrl = null;
  }

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;
    final url = _objectUrl;
    if (url != null) {
      return ClipOval(
        child: Image.network(url, width: 28, height: 28, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Icon(
        (plant?['location'] == 'outdoor') ? Icons.yard_outlined : Icons.home_outlined,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _TaskHistory extends StatelessWidget {
  const _TaskHistory({required this.events});

  final List<dynamic> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _EmptyState(
          icon: Icons.history_outlined,
          title: 'No completed tasks',
          body: 'Task completions will show here.');
    }
    return Column(
      children: events.take(12).map((event) {
        event as Map<String, dynamic>;
        final wasLate = event['was_late'] == true;
        return ListTile(
          leading: Icon(
              wasLate
                  ? Icons.warning_amber_outlined
                  : Icons.check_circle_outline,
              color: wasLate ? Theme.of(context).colorScheme.error : null),
          title: Text(wasLate ? 'Completed late' : 'Completed on time'),
          subtitle: Text(
              'Due ${event['due_date'] ?? 'n/a'} / Completed ${event['completed_at'] ?? ''}'),
        );
      }).toList(),
    );
  }
}

class _AnalysisPendingState extends StatelessWidget {
  const _AnalysisPendingState({required this.jobs});

  final List<dynamic> jobs;

  @override
  Widget build(BuildContext context) {
    final activeJobs = _activeJobs(jobs);
    if (activeJobs.isEmpty) {
      return const _EmptyState(
          icon: Icons.auto_awesome_outlined,
          title: 'Analysis pending',
          body:
              'Upload a registration photo and Plant Buddy will analyze it automatically.');
    }
    return Column(
      children: activeJobs.take(3).map((job) {
        job as Map<String, dynamic>;
        return ListTile(
          dense: true,
          leading: Icon(_jobIcon(job['status'] as String?)),
          title: Text('Analysis ${job['status'] ?? ''}'),
          subtitle: job['last_error'] == null
              ? const Text('Plant Buddy is processing this photo.')
              : Text(job['last_error']),
        );
      }).toList(),
    );
  }
}

class _AnalysisDetails extends StatelessWidget {
  const _AnalysisDetails({required this.analysis, required this.jobs});

  final Map<String, dynamic> analysis;
  final List<dynamic> jobs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commonName = _displayText(analysis['common_name'], 'Plant')!;
    final scientificName = _displayText(analysis['scientific_name'], null);
    final healthScore = analysis['health_score'] is num
        ? (analysis['health_score'] as num).round()
        : int.tryParse(analysis['health_score']?.toString() ?? '');
    final confidence = _formatConfidence(analysis['confidence']);
    final analyzedAt = _shortDateTime(analysis['created_at']);
    final photoDate = _shortDateTime(
        analysis['photo_captured_at'] ?? analysis['photo_created_at']);
    final isRegistration = analysis['photo_is_registration_photo'] == true;
    final activeJobs = _activeJobs(jobs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(commonName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (scientificName != null) ...[
                    const SizedBox(height: 2),
                    Text(scientificName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            if (healthScore != null)
              _ScoreBadge(score: healthScore),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (confidence.isNotEmpty)
              _InfoChip(
                  icon: Icons.verified_outlined,
                  label: 'Confidence $confidence'),
            if (analyzedAt.isNotEmpty)
              _InfoChip(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Analyzed $analyzedAt'),
            if (photoDate.isNotEmpty)
              _InfoChip(
                  icon: Icons.photo_camera_outlined,
                  label: 'Photo $photoDate'),
            if (isRegistration)
              const _InfoChip(
                  icon: Icons.flag_outlined, label: 'Registration photo'),
          ],
        ),
        if (_displayText(analysis['health_notes'], null) != null) ...[
          const SizedBox(height: 14),
          Text('Recommendation',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(_displayText(analysis['health_notes'], '')!),
        ],
        if (activeJobs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AnalysisPendingState(jobs: jobs),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                    child: Text(title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800))),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                        alignment: Alignment.centerRight, child: trailing!),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _CareLine extends StatelessWidget {
  const _CareLine({required this.title, required this.value});

  final String title;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 96,
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(value?.toString() ?? '')),
        ],
      ),
    );
  }
}

class _CarePlanDetails extends StatelessWidget {
  const _CarePlanDetails({required this.carePlan});

  final Map<String, dynamic> carePlan;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CareSection(
          icon: Icons.water_drop_outlined,
          title: 'Watering',
          children: [
            _CareLine(title: 'Frequency', value: carePlan['watering']),
            _CareLine(title: 'Amount', value: carePlan['watering_amount']),
            _CareLine(title: 'How to tell', value: carePlan['watering_check']),
          ],
        ),
        _CareSection(
          icon: Icons.science_outlined,
          title: 'Fertilizing',
          children: [
            _CareLine(title: 'Schedule', value: carePlan['fertilizing']),
            _CareLine(title: 'Type', value: carePlan['fertilizer_type']),
            _CareLine(title: 'Amount', value: carePlan['fertilizer_amount']),
          ],
        ),
        _CareSection(
          icon: Icons.wb_sunny_outlined,
          title: 'Light',
          children: [_CareLine(title: 'Needs', value: carePlan['sunlight'])],
        ),
        _CareSection(
          icon: Icons.inventory_2_outlined,
          title: 'Repotting',
          children: [
            _CareLine(title: 'Plan', value: carePlan['repotting']),
            _CareLine(
                title: 'Current pot', value: carePlan['repotting_assessment']),
            _CareLine(title: 'Soil', value: carePlan['soil']),
          ],
        ),
        _CareSection(
          icon: Icons.content_cut_outlined,
          title: 'Grooming',
          children: [_CareLine(title: 'Pruning', value: carePlan['pruning'])],
        ),
        _CareSection(
          icon: Icons.warning_amber_outlined,
          title: 'Watch-outs',
          children: [
            _CareLine(title: 'Monitor', value: carePlan['watch_outs'])
          ],
        ),
      ],
    );
  }
}

class _CareSection extends StatelessWidget {
  const _CareSection(
      {required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visibleChildren = children.where((child) {
      if (child is _CareLine) {
        return _hasCareValue(child.value);
      }
      return true;
    }).toList();
    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ...visibleChildren,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8)),
      child:
          Text('$score', style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.image_outlined,
          size: 48, color: Theme.of(context).colorScheme.primary),
    );
  }
}

class AuthImage extends StatefulWidget {
  const AuthImage(
      {required this.api, required this.photoId, this.height = 240, super.key});

  final ApiClient api;
  final String photoId;
  final double height;

  @override
  State<AuthImage> createState() => _AuthImageState();
}

class PlantIconAvatar extends StatefulWidget {
  const PlantIconAvatar({required this.api, required this.plant, super.key});

  final ApiClient api;
  final Map<String, dynamic> plant;

  @override
  State<PlantIconAvatar> createState() => _PlantIconAvatarState();
}

class _PlantIconAvatarState extends State<PlantIconAvatar> {
  String? _objectUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlantIconAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plant['id'] != widget.plant['id'] ||
        oldWidget.plant['icon_path'] != widget.plant['icon_path']) {
      _revoke();
      _load();
    }
  }

  @override
  void dispose() {
    _revoke();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.plant['icon_path'] == null) return;
    try {
      final blob = await widget.api.fetchBlob('/plants/${widget.plant['id']}/icon');
      if (!mounted) return;
      setState(() => _objectUrl = html.Url.createObjectUrlFromBlob(blob));
    } catch (_) {}
  }

  void _revoke() {
    final url = _objectUrl;
    if (url != null) {
      html.Url.revokeObjectUrl(url);
    }
    _objectUrl = null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _objectUrl;
    if (url == null) {
      return Icon(widget.plant['location'] == 'outdoor'
          ? Icons.yard_outlined
          : Icons.home_outlined);
    }
    return ClipOval(
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _AuthImageState extends State<AuthImage> {
  String? _objectUrl;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) {
      _revoke();
      _load();
    }
  }

  @override
  void dispose() {
    _revoke();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final blob = await widget.api.fetchPhotoBlob(widget.photoId, 'thumb_768');
      if (!mounted) return;
      setState(() {
        _objectUrl = html.Url.createObjectUrlFromBlob(blob);
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  void _revoke() {
    final url = _objectUrl;
    if (url != null) {
      html.Url.revokeObjectUrl(url);
    }
    _objectUrl = null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _objectUrl;
    if (_failed || url == null) {
      return const _ImageFallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        height: widget.height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _ImageFallback(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Loading Plant Buddy',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style:
                      TextStyle(color: theme.colorScheme.onErrorContainer))),
        ],
      ),
    );
  }
}

class _AppErrorBanner extends StatelessWidget {
  const _AppErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      content: Text(message),
      leading: const Icon(Icons.error_outline),
      actions: [
        TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
      ],
    );
  }
}

IconData _taskIcon(String? type) {
  return switch (type) {
    'watering' => Icons.water_drop_outlined,
    'fertilizing' => Icons.science_outlined,
    'repotting' => Icons.inventory_2_outlined,
    'inspection' => Icons.search_outlined,
    _ => Icons.task_alt_outlined,
  };
}

IconData _jobIcon(String? status) {
  return switch (status) {
    'queued' => Icons.schedule,
    'running' => Icons.sync,
    'succeeded' => Icons.check_circle_outline,
    'failed' => Icons.error_outline,
    _ => Icons.sync_outlined,
  };
}

Future<html.File?> pickImageFile() async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.setAttribute('capture', 'environment');
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  return files.first;
}

Map<String, dynamic>? _firstPlantById(List<dynamic> plants, String id) {
  for (final plant in plants) {
    final mapped = plant as Map<String, dynamic>;
    if (mapped['id'] == id) {
      return mapped;
    }
  }
  return null;
}

Map<String, dynamic>? _firstMapById(List<dynamic> items, dynamic id) {
  if (id == null) return null;
  for (final item in items) {
    final mapped = item as Map<String, dynamic>;
    if (mapped['id'] == id) {
      return mapped;
    }
  }
  return null;
}

class ApiClient {
  ApiClient() {
    html.window.localStorage.remove('apiBaseUrl');
    baseUrl = defaultApiBaseUrl();
    _token = html.window.localStorage['accessToken'];
    _refreshToken = html.window.localStorage['refreshToken'];
  }

  late String baseUrl;
  String? _token;
  String? _refreshToken;
  Future<bool>? _refreshInFlight;

  bool get hasToken =>
      (_token != null && _token!.isNotEmpty) ||
      (_refreshToken != null && _refreshToken!.isNotEmpty);

  Map<String, String> get authHeaders => {'Authorization': 'Bearer $_token'};

  Future<bool> restoreSession() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      logout();
      return false;
    }
    baseUrl = defaultApiBaseUrl();
    return _refreshAccessToken();
  }

  void logout() {
    _token = null;
    _refreshToken = null;
    html.window.localStorage.remove('accessToken');
    html.window.localStorage.remove('refreshToken');
  }

  String photoUrl(String photoId, String variant) =>
      '${baseUrl.trimRight()}/photos/$photoId/image?variant=$variant';

  Future<void> login(String username, String password) async {
    final response = await _request(
      'POST',
      '/auth/login',
      body: {'username': username, 'password': password},
      authenticated: false,
    );
    _token = response['access_token'] as String;
    _refreshToken = response['refresh_token'] as String;
    html.window.localStorage['accessToken'] = _token!;
    html.window.localStorage['refreshToken'] = _refreshToken!;
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _request('GET', path);
    return response as List<dynamic>;
  }

  Future<Map<String, dynamic>> getMap(String path) async {
    final response = await _request('GET', path);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postJson(
      String path, Map<String, dynamic> body) async {
    final response = await _request('POST', path, body: body);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchJson(
      String path, Map<String, dynamic> body) async {
    final response = await _request('PATCH', path, body: body);
    return response as Map<String, dynamic>;
  }

  Future<void> delete(String path) async {
    await _request('DELETE', path, allowEmpty: true);
  }

  Future<Map<String, dynamic>> uploadFile(String path, html.File file,
      {bool retryOnUnauthorized = true}) async {
    await _ensureAuthenticated();
    final formData = html.FormData()..appendBlob('file', file, file.name);
    final response = await html.HttpRequest.request(
      _url(path),
      method: 'POST',
      requestHeaders: authHeaders,
      sendData: formData,
    );
    if (_isUnauthorized(response) && retryOnUnauthorized) {
      if (await _refreshAccessToken()) {
        return uploadFile(path, file, retryOnUnauthorized: false);
      }
      throw AuthExpiredException();
    }
    if (_isUnauthorized(response)) {
      logout();
      throw AuthExpiredException();
    }
    if (response.status == null ||
        response.status! < 200 ||
        response.status! >= 300) {
      throw ApiException(_errorMessage(response));
    }
    return jsonDecode(response.responseText ?? '{}') as Map<String, dynamic>;
  }

  Future<void> streamChatMessage(
    String sessionId,
    String content, {
    required ValueChanged<String> onDelta,
    bool retryOnUnauthorized = true,
  }) async {
    await _ensureAuthenticated();
    final request = html.HttpRequest();
    var seen = 0;
    final completer = Completer<void>();
    request
      ..open('POST', _url('/chat/sessions/$sessionId/messages/stream'))
      ..setRequestHeader('Content-Type', 'application/json')
      ..setRequestHeader('Authorization', 'Bearer $_token')
      ..onProgress.listen((_) {
        final text = request.responseText ?? '';
        if (text.length > seen) {
          onDelta(text.substring(seen));
          seen = text.length;
        }
      })
      ..onLoadEnd.listen((_) {
        final text = request.responseText ?? '';
        if (text.length > seen) {
          onDelta(text.substring(seen));
          seen = text.length;
        }
        if (completer.isCompleted) return;
        if (request.status == null ||
            request.status! < 200 ||
            request.status! >= 300) {
          if (_isUnauthorized(request) && retryOnUnauthorized) {
            _refreshAccessToken().then((refreshed) {
              if (!refreshed) {
                completer.completeError(AuthExpiredException());
                return;
              }
              streamChatMessage(sessionId, content,
                      onDelta: onDelta, retryOnUnauthorized: false)
                  .then((_) => completer.complete())
                  .catchError(completer.completeError);
            });
            return;
          }
          completer.completeError(ApiException(_errorMessage(request)));
        } else {
          completer.complete();
        }
      })
      ..onError.listen((_) {
        if (completer.isCompleted) return;
        completer.completeError(ApiException('Chat stream failed'));
      })
      ..send(jsonEncode({'content': content}));
    return completer.future;
  }

  Future<html.Blob> fetchPhotoBlob(String photoId, String variant) async {
    return fetchBlob('/photos/$photoId/image?variant=$variant');
  }

  Future<html.Blob> fetchBlob(String path,
      {bool retryOnUnauthorized = true}) async {
    await _ensureAuthenticated();
    final response = await html.HttpRequest.request(
      _url(path),
      method: 'GET',
      requestHeaders: authHeaders,
      responseType: 'blob',
    );
    if (_isUnauthorized(response) && retryOnUnauthorized) {
      if (await _refreshAccessToken()) {
        return fetchBlob(path, retryOnUnauthorized: false);
      }
      throw AuthExpiredException();
    }
    if (_isUnauthorized(response)) {
      logout();
      throw AuthExpiredException();
    }
    if (response.status == null ||
        response.status! < 200 ||
        response.status! >= 300) {
      throw ApiException(_errorMessage(response));
    }
    return response.response as html.Blob;
  }

  Future<void> downloadIcs(String path, {bool retryOnUnauthorized = true}) async {
    await _ensureAuthenticated();
    final response = await html.HttpRequest.request(
      _url(path),
      method: 'GET',
      requestHeaders: authHeaders,
      responseType: 'blob',
    );
    if (_isUnauthorized(response) && retryOnUnauthorized) {
      if (await _refreshAccessToken()) {
        return downloadIcs(path, retryOnUnauthorized: false);
      }
      throw AuthExpiredException();
    }
    if (_isUnauthorized(response)) {
      logout();
      throw AuthExpiredException();
    }
    if (response.status == null ||
        response.status! < 200 ||
        response.status! >= 300) {
      throw ApiException(_errorMessage(response));
    }
    final blob = response.response as html.Blob;
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = 'plant-buddy-calendar.ics'
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body,
      bool authenticated = true,
      bool allowEmpty = false,
      bool retryOnUnauthorized = true}) async {
    if (authenticated) {
      await _ensureAuthenticated();
    }
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      headers.addAll(authHeaders);
    }
    final response = await html.HttpRequest.request(
      _url(path),
      method: method,
      requestHeaders: headers,
      sendData: body == null ? null : jsonEncode(body),
    );
    if (authenticated && _isUnauthorized(response) && retryOnUnauthorized) {
      if (await _refreshAccessToken()) {
        return _request(method, path,
            body: body,
            authenticated: authenticated,
            allowEmpty: allowEmpty,
            retryOnUnauthorized: false);
      }
      throw AuthExpiredException();
    }
    if (authenticated && _isUnauthorized(response)) {
      logout();
      throw AuthExpiredException();
    }
    if (response.status == null ||
        response.status! < 200 ||
        response.status! >= 300) {
      throw ApiException(_errorMessage(response));
    }
    if (allowEmpty ||
        response.responseText == null ||
        response.responseText!.isEmpty) {
      return null;
    }
    return jsonDecode(response.responseText!);
  }

  Future<bool> _refreshAccessToken() async {
    final existingRefresh = _refreshInFlight;
    if (existingRefresh != null) {
      return existingRefresh;
    }
    final refreshFuture = _performRefresh();
    _refreshInFlight = refreshFuture;
    try {
      return await refreshFuture;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> _ensureAuthenticated() async {
    if (_token != null && _token!.isNotEmpty && !_accessTokenExpiresSoon()) {
      return;
    }
    if (await _refreshAccessToken()) {
      return;
    }
    throw AuthExpiredException();
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      logout();
      return false;
    }
    try {
      final response = await html.HttpRequest.request(
        _url('/auth/refresh'),
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: jsonEncode({'refresh_token': refreshToken}),
      );
      if (response.status == null ||
          response.status! < 200 ||
          response.status! >= 300 ||
          response.responseText == null ||
          response.responseText!.isEmpty) {
        logout();
        return false;
      }
      final body = jsonDecode(response.responseText!) as Map<String, dynamic>;
      _token = body['access_token'] as String;
      _refreshToken = body['refresh_token'] as String;
      html.window.localStorage['accessToken'] = _token!;
      html.window.localStorage['refreshToken'] = _refreshToken!;
      return true;
    } catch (_) {
      logout();
      return false;
    }
  }

  bool _isUnauthorized(html.HttpRequest response) => response.status == 401;

  bool _accessTokenExpiresSoon() {
    final token = _token;
    if (token == null || token.isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return true;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
      return DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 90))
          .isAfter(expiresAt);
    } catch (_) {
      return true;
    }
  }

  String _url(String path) {
    final root = baseUrl.trimRight();
    return path.startsWith('/') ? '$root$path' : '$root/$path';
  }

  String _errorMessage(html.HttpRequest response) {
    try {
      final body =
          jsonDecode(response.responseText ?? '{}') as Map<String, dynamic>;
      return body['detail']?.toString() ??
          'Request failed with HTTP ${response.status}';
    } catch (_) {
      return 'Request failed with HTTP ${response.status}';
    }
  }
}

String defaultApiBaseUrl() {
  const buildTimeApiBaseUrl = String.fromEnvironment('PLANTBUDDY_API_BASE_URL');
  if (buildTimeApiBaseUrl.trim().isNotEmpty) {
    return buildTimeApiBaseUrl.trim();
  }
  final runtimeApiBaseUrl = _runtimeConfigValue('apiBaseUrl');
  if (runtimeApiBaseUrl != null && runtimeApiBaseUrl.trim().isNotEmpty) {
    return runtimeApiBaseUrl.trim();
  }
  return 'http://127.0.0.1:8000/api';
}

String? _runtimeConfigValue(String key) {
  try {
    final config =
        js_util.getProperty<Object?>(html.window, 'PLANTBUDDY_CONFIG');
    if (config == null) return null;
    final value = js_util.getProperty<Object?>(config, key);
    return value?.toString();
  } catch (_) {
    return null;
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthExpiredException implements Exception {
  @override
  String toString() => 'Session expired';
}

class HealthPoint {
  HealthPoint({required this.score, required this.label});

  final int score;
  final String label;
}

class HealthChartPainter extends CustomPainter {
  HealthChartPainter({required this.points, required this.color});

  final List<HealthPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = const Color(0xFFCBD5C6)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = color;
    const left = 34.0;
    const right = 12.0;
    const top = 12.0;
    const bottom = 34.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    for (var score = 1; score <= 10; score += 3) {
      final y = top + chartHeight - ((score - 1) / 9) * chartHeight;
      canvas.drawLine(
          Offset(left, y), Offset(size.width - right, y), axisPaint);
      _drawText(canvas, '$score', Offset(6, y - 8),
          const TextStyle(fontSize: 11, color: Color(0xFF60705C)));
    }

    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + (index / (points.length - 1)) * chartWidth;
      final y = top +
          chartHeight -
          ((points[index].score.clamp(1, 10) - 1) / 9) * chartHeight;
      offsets.add(Offset(x, y));
    }
    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, linePaint);
    }
    for (var index = 0; index < offsets.length; index++) {
      canvas.drawCircle(offsets[index], 5, dotPaint);
      if (index == 0 || index == offsets.length - 1) {
        _drawText(
            canvas,
            points[index].label,
            Offset(offsets[index].dx - 30, size.height - 24),
            const TextStyle(fontSize: 11, color: Color(0xFF40513C)));
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant HealthChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _todayString() {
  final today = _today();
  return '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

bool _sameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String? _plantName(List<dynamic> plants, dynamic plantId) {
  for (final plant in plants) {
    final mapped = plant as Map<String, dynamic>;
    if (mapped['id'] == plantId) {
      return mapped['pet_name'] as String?;
    }
  }
  return null;
}

Map<String, dynamic>? _plantById(List<dynamic> plants, dynamic plantId) {
  for (final plant in plants) {
    final mapped = plant as Map<String, dynamic>;
    if (mapped['id'] == plantId) {
      return mapped;
    }
  }
  return null;
}

String _plantLocationLabel(Map<String, dynamic> plant) {
  final room = (plant['room_location'] ?? '').toString().trim();
  if (room.isNotEmpty) return room;
  final location = (plant['location'] ?? '').toString().trim();
  if (location.isNotEmpty) return location;
  return 'Unassigned';
}

String _taskLocationLabel(Map<String, dynamic> task, List<dynamic> plants) {
  final plant = _plantById(plants, task['plant_id']);
  if (plant == null) return 'Unassigned';
  return _plantLocationLabel(plant);
}

Map<String, List<Map<String, dynamic>>> _groupPlantsByLocation(
    List<Map<String, dynamic>> plants) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final plant in plants) {
    final label = _plantLocationLabel(plant);
    grouped.putIfAbsent(label, () => []).add(plant);
  }
  return grouped;
}

Map<String, List<Map<String, dynamic>>> _groupTasksByLocation(
    List<Map<String, dynamic>> tasks, List<dynamic> plants) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final task in tasks) {
    final label = _taskLocationLabel(task, plants);
    grouped.putIfAbsent(label, () => []).add(task);
  }
  return grouped;
}

void _sortTasksByDueAndLocation(
    List<Map<String, dynamic>> tasks, List<dynamic> plants) {
  tasks.sort((left, right) {
    final leftDue = _parseDate(left['next_due_date']);
    final rightDue = _parseDate(right['next_due_date']);
    if (leftDue != null && rightDue != null) {
      final dueCompare = leftDue.compareTo(rightDue);
      if (dueCompare != 0) return dueCompare;
    } else if (leftDue != null) {
      return -1;
    } else if (rightDue != null) {
      return 1;
    }
    final locationCompare = _taskLocationLabel(left, plants)
        .compareTo(_taskLocationLabel(right, plants));
    if (locationCompare != 0) return locationCompare;
    return (left['title'] ?? '')
        .toString()
        .compareTo((right['title'] ?? '').toString());
  });
}

List<Map<String, dynamic>> _activeJobs(List<dynamic> jobs) {
  return jobs
      .cast<Map<String, dynamic>>()
      .where((job) => job['status'] == 'queued' || job['status'] == 'running')
      .toList();
}

String _dateString(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _shortDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '';
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}

String _shortDateTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '';
  final local = parsed.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $suffix';
}

String? _displayText(dynamic value, String? fallback) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return fallback;
  return text;
}

String _formatConfidence(dynamic value) {
  if (value == null) return '';
  final number = value is num ? value : num.tryParse(value.toString());
  if (number == null) return value.toString();
  final percent = number <= 1 ? number * 100 : number;
  return '${percent.round()}%';
}

bool _hasCareValue(dynamic value) {
  return value != null && value.toString().trim().isNotEmpty;
}

String _monthTitle(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.year}';
}

Map<String, List<Map<String, dynamic>>> _calendarTasksByDay(
    List<dynamic> calendarDays) {
  final mapped = <String, List<Map<String, dynamic>>>{};
  for (final day in calendarDays) {
    final dayMap = day as Map<String, dynamic>;
    mapped[dayMap['day'] as String] =
        (dayMap['tasks'] as List<dynamic>).cast<Map<String, dynamic>>();
  }
  return mapped;
}
