import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

// Kagisho Connect · Parent Experience — Premium Edition
// Presentation-only redesign. The original Supabase tables and queries are retained.
class Brand {
  static const forest = Color(0xFF103F65);
  static const green = Color(0xFF0786C7);
  static const sea = Color(0xFF36B5EC);
  static const mint = Color(0xFFE5F5FE);
  static const lime = Color(0xFFBEEAFF);
  static const ink = Color(0xFF173C59);
  static const muted = Color(0xFF67849B);
  static const background = Color(0xFFF5FAFF);
  static const border = Color(0xFFDDEEF7);
  static const amber = Color(0xFFDD864A);
  static const softAmber = Color(0xFFFFF2E8);
  static const white = Colors.white;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || key.isEmpty) {
    runApp(const MaterialApp(home: Scaffold(body: Center(
      child: Padding(padding: EdgeInsets.all(24), child: Text(
        'Kagisho Connect needs SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY. See README.md.',
        textAlign: TextAlign.center))))));
    return;
  }
  await Supabase.initialize(url: url, anonKey: key);
  runApp(const KagishoApp());
}

final _db = Supabase.instance.client;
String textValue(dynamic value) => value?.toString() ?? '';
String greetingName(String? name) {
  final value = (name ?? '').trim();
  return value.isEmpty ? 'there' : value.split(' ').first;
}
String dateTimeLabel(dynamic value) {
  final date = DateTime.tryParse(textValue(value));
  if (date == null) return textValue(value);
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
String friendlyDate(dynamic value) {
  final date = DateTime.tryParse(textValue(value));
  if (date == null) return textValue(value);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
String clockLabel(dynamic value) {
  final date = DateTime.tryParse(textValue(value));
  if (date == null) return '';
  final local = date.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class KagishoApp extends StatelessWidget {
  const KagishoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kagisho Connect',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Brand.background,
      colorScheme: ColorScheme.fromSeed(seedColor: Brand.green, primary: Brand.green,
        surface: Brand.white, brightness: Brightness.light),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Brand.ink, fontWeight: FontWeight.w900, letterSpacing: -1.0),
        headlineMedium: TextStyle(color: Brand.ink, fontWeight: FontWeight.w900, letterSpacing: -0.7),
        titleLarge: TextStyle(color: Brand.ink, fontWeight: FontWeight.w800, letterSpacing: -0.4),
        titleMedium: TextStyle(color: Brand.ink, fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(color: Brand.ink),
        bodyMedium: TextStyle(color: Brand.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Brand.white,
        hintStyle: const TextStyle(color: Brand.muted),
        labelStyle: const TextStyle(color: Brand.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Brand.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Brand.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Brand.green, width: 1.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(54), backgroundColor: Brand.green,
        foregroundColor: Brand.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      )),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Brand.forest, contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    home: const AppGate(),
  );
}

class KagishoLogo extends StatelessWidget {
  final bool inverse;
  final double size;
  const KagishoLogo({super.key, this.inverse = false, this.size = 40});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: inverse ? [Brand.lime, const Color(0xFF9CDFFF)] : [Brand.green, Brand.forest]),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(Icons.auto_stories_rounded, size: size * .55,
        color: inverse ? Brand.forest : Brand.white),
    ),
    const SizedBox(width: 11),
    Text('kagisho', style: TextStyle(fontSize: size * .51, color: inverse ? Colors.white : Brand.ink,
      fontWeight: FontWeight.w900, letterSpacing: -.8)),
    Text(' connect', style: TextStyle(fontSize: size * .51,
      color: inverse ? Brand.lime : Brand.green, fontWeight: FontWeight.w600, letterSpacing: -.8)),
  ]);
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  const SoftCard({super.key, required this.child, this.onTap,
    this.padding = const EdgeInsets.all(20), this.color = Brand.white});
  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity, padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Brand.border),
        boxShadow: const [BoxShadow(color: Color(0x070D4233), blurRadius: 24, offset: Offset(0, 10))]),
      child: child,
    );
    return onTap == null ? content : InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(24), child: content);
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onTap;
  const SectionTitle(this.title, {super.key, this.subtitle, this.action, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900,
          color: Brand.ink, letterSpacing: -.5)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(fontSize: 13, color: Brand.muted)),
        ],
      ])),
      if (action != null) TextButton(onPressed: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(action!, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 2), const Icon(Icons.arrow_forward_rounded, size: 17),
        ])),
    ]),
  );
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  const IconBadge(this.icon, {super.key, this.background = Brand.mint,
    this.foreground = Brand.green, this.size = 46});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(size * .34)),
    child: Icon(icon, color: foreground, size: size * .49));
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  const StatusChip(this.label, {super.key, this.color = Brand.green, this.background = Brand.mint});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
  );
}

class EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String heading;
  final String detail;
  const EmptyPanel({super.key, required this.icon, required this.heading, required this.detail});
  @override
  Widget build(BuildContext context) => SoftCard(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 23, horizontal: 12),
    child: Column(children: [
      IconBadge(icon, size: 58), const SizedBox(height: 16),
      Text(heading, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: Brand.ink, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted, height: 1.5)),
    ]),
  ));
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});
  @override
  State<AppGate> createState() => _AppGateState();
}
class _AppGateState extends State<AppGate> {
  StreamSubscription<AuthState>? sub;
  @override
  void initState() {
    super.initState();
    sub = _db.auth.onAuthStateChange.listen((_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { sub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _db.auth.currentSession == null
    ? const AuthScreen() : const ParentShell();
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(), pass = TextEditingController(), name = TextEditingController();
  bool create = false, busy = false, showPassword = false;
  @override
  void dispose() { email.dispose(); pass.dispose(); name.dispose(); super.dispose(); }
  void notice(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  Future<void> submit() async {
    if (email.text.trim().isEmpty || pass.text.isEmpty || (create && name.text.trim().length < 2)) {
      notice('Please complete all required fields.'); return;
    }
    if (create && pass.text.length < 12) { notice('Use a password of at least 12 characters.'); return; }
    setState(() => busy = true);
    try {
      if (create) {
        await _db.auth.signUp(email: email.text.trim(), password: pass.text,
          data: {'full_name': name.text.trim()});
        if (mounted) {
          await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Check your email'),
            content: const Text('We sent you a confirmation link. After confirming, sign in. Your school will verify the learners connected to your account.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))],
          ));
          if (mounted) setState(() => create = false);
        }
      } else {
        await _db.auth.signInWithPassword(email: email.text.trim(), password: pass.text);
      }
    } on AuthException catch (e) { notice(e.message); }
    catch (_) { notice('Could not connect. Check your internet connection and try again.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> resetPassword() async {
    if (email.text.trim().isEmpty) { notice('Enter your email address first.'); return; }
    try {
      await _db.auth.resetPasswordForEmail(email.text.trim());
      notice('If an account exists, recovery instructions will be sent.');
    } catch (_) { notice('Could not send recovery email.'); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: LayoutBuilder(builder: (context, bounds) {
    final wide = bounds.maxWidth >= 900;
    final form = Center(child: SingleChildScrollView(padding: EdgeInsets.symmetric(
      horizontal: wide ? 44 : 24, vertical: 36), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!wide) ...[
          const Center(child: KagishoLogo(size: 42)), const SizedBox(height: 34),
        ],
        const StatusChip('THE FAMILY EXPERIENCE'),
        const SizedBox(height: 18),
        Text(create ? 'Welcome to the family.' : 'Good to have you back.',
          style: const TextStyle(fontSize: 35, fontWeight: FontWeight.w900,
            color: Brand.ink, height: 1.14, letterSpacing: -1.1)),
        const SizedBox(height: 12),
        Text(create ? 'Create a secure space to stay close to your child’s school day.'
          : 'Sign in to see what matters in your child’s school day.',
          style: const TextStyle(color: Brand.muted, fontSize: 15, height: 1.6)),
        const SizedBox(height: 32),
        if (create) ...[
          const Text('Your name', style: TextStyle(fontWeight: FontWeight.w800, color: Brand.ink)),
          const SizedBox(height: 9),
          TextField(controller: name, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Your full name', prefixIcon: Icon(Icons.person_outline_rounded))),
          const SizedBox(height: 20),
        ],
        const Text('Email address', style: TextStyle(fontWeight: FontWeight.w800, color: Brand.ink)),
        const SizedBox(height: 9),
        TextField(controller: email, keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(hintText: 'name@example.com',
            prefixIcon: Icon(Icons.mail_outline_rounded))),
        const SizedBox(height: 20),
        const Text('Password', style: TextStyle(fontWeight: FontWeight.w800, color: Brand.ink)),
        const SizedBox(height: 9),
        TextField(controller: pass, obscureText: !showPassword,
          autofillHints: [create ? AutofillHints.newPassword : AutofillHints.password],
          onSubmitted: (_) { if (!busy) submit(); },
          decoration: InputDecoration(hintText: create ? 'At least 12 characters' : 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(tooltip: showPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => showPassword = !showPassword),
              icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
        if (!create) Align(alignment: Alignment.centerRight,
          child: TextButton(onPressed: busy ? null : resetPassword, child: const Text('Forgot password?'))),
        SizedBox(height: create ? 28 : 14),
        ElevatedButton(onPressed: busy ? null : submit,
          child: busy ? const SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(create ? 'Create parent account' : 'Sign in'),
              const SizedBox(width: 9), const Icon(Icons.arrow_forward_rounded, size: 18),
            ])),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(create ? 'Already registered?' : 'New to Kagisho?',
            style: const TextStyle(color: Brand.muted)),
          TextButton(onPressed: busy ? null : () => setState(() => create = !create),
            child: Text(create ? 'Sign in' : 'Create account',
              style: const TextStyle(fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 25),
        const Text('For parents and guardians. Staff use the school portal.',
          textAlign: TextAlign.center, style: TextStyle(color: Brand.muted, fontSize: 12)),
      ]),
    )));
    if (!wide) return form;
    return Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.all(64),
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Brand.forest, Color(0xFF127FB6), Color(0xFF2DA8DB)])),
        child: Stack(children: [
          Positioned(right: -110, bottom: -120, child: Container(width: 440, height: 440,
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(.13), width: 65)))),
          Positioned(left: -150, top: -120, child: Container(width: 350, height: 350,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(.04)))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const KagishoLogo(inverse: true, size: 44),
            const Spacer(),
            const Icon(Icons.favorite_rounded, color: Brand.lime, size: 45),
            const SizedBox(height: 24),
            const Text('Closer to their world.\nEvery single day.',
              style: TextStyle(color: Brand.white, fontSize: 52,
                fontWeight: FontWeight.w900, height: 1.12, letterSpacing: -1.5)),
            const SizedBox(height: 21),
            const Text('Attendance, achievements, school news and real conversations—all in one beautiful space for families.',
              style: TextStyle(color: Color(0xFFE0F2FD), fontSize: 17, height: 1.7)),
            const SizedBox(height: 35),
            Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.12),
                borderRadius: BorderRadius.circular(14)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shield_outlined, color: Brand.lime, size: 20), SizedBox(width: 10),
                Text('A safer connection between home and school',
                  style: TextStyle(color: Brand.white, fontWeight: FontWeight.w600)),
              ])),
            const Spacer(),
          ]),
        ]),
      )),
      Expanded(child: form),
    ]);
  }));
}

class ParentShell extends StatefulWidget {
  const ParentShell({super.key});
  @override
  State<ParentShell> createState() => _ParentShellState();
}
class _ParentShellState extends State<ParentShell> {
  int tab = 0;
  bool loading = true;
  String? error;
  Timer? refreshTimer;
  final composer = TextEditingController();
  List<Map<String, dynamic>> children = [], classes = [], marks = [], attendance = [],
    alerts = [], news = [], messages = [], events = [];
  List<Map<String, dynamic>> linkRequests = [], reports = [], reportMarks = [], reportTerms = [], documents = [];
  Map<String, dynamic>? myProfile;
  bool sendingRequest = false;

  String? selectedChild;

  @override
  void initState() {
    super.initState();
    load();
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) load(silent: true);
    });
  }
  @override
  void dispose() { refreshTimer?.cancel(); composer.dispose(); super.dispose(); }

  // Deliberately unchanged Supabase read/write schema and access pattern.
  Future<void> load({bool silent = false}) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    if (!silent) setState(() => loading = true);
    try {
      final profile = await _db.from('kc_parent_profiles').select().eq('user_id', user.id).maybeSingle();
      final fullName = textValue(user.userMetadata?['full_name']).trim();
      if (profile == null) {
        await _db.from('kc_parent_profiles').insert({'user_id': user.id, 'email': user.email ?? '',
          'full_name': fullName.length >= 2 ? fullName : 'Parent Account'});
      }
      final requests = List<Map<String, dynamic>>.from(await _db.from('kc_guardian_requests')
        .select('id,child_name,status,created_at,review_note,learner_id').eq('parent_id',user.id)
        .order('created_at',ascending:false).limit(25));
      final links = List<Map<String, dynamic>>.from(await _db.from('kc_guardian_links')
        .select('learner_id').eq('user_id', user.id));
      final ids = links.map((x) => textValue(x['learner_id'])).where((x) => x.isNotEmpty).toList();
      List<Map<String, dynamic>> newKids = [], newMarks = [], newAtt = [], newClasses = [];
      if (ids.isNotEmpty) {
        newKids = List<Map<String, dynamic>>.from(await _db.from('kc_learners')
          .select('id,full_name,class_id').inFilter('id', ids));
        newMarks = List<Map<String, dynamic>>.from(await _db.from('kc_marks')
          .select('learner_id,subject,score,updated_at').inFilter('learner_id', ids));
        newAtt = List<Map<String, dynamic>>.from(await _db.from('kc_attendance')
          .select('learner_id,school_date,status').inFilter('learner_id', ids)
          .order('school_date', ascending: false));
        final classIds = newKids.map((x) => textValue(x['class_id'])).toSet().toList();
        if (classIds.isNotEmpty) {
          newClasses = List<Map<String, dynamic>>.from(await _db.from('kc_classes')
            .select('id,name,grade').inFilter('id', classIds));
        }
      }
      List<Map<String, dynamic>> newReports = [], newReportMarks = [], newTerms = [];
      if (ids.isNotEmpty) {
        newReports = List<Map<String, dynamic>>.from(await _db.from('kc_report_cards')
          .select('id,learner_id,term_id,status,teacher_comment,published_at')
          .inFilter('learner_id', ids).eq('status', 'published')
          .order('published_at', ascending:false));
        if (newReports.isNotEmpty) {
          final reportIds = newReports.map((r)=>textValue(r['id'])).toList();
          final termIds = newReports.map((r)=>textValue(r['term_id'])).toSet().toList();
          newReportMarks = List<Map<String,dynamic>>.from(await _db.from('kc_report_marks')
            .select('id,report_id,subject,percentage').inFilter('report_id',reportIds).order('subject'));
          newTerms = List<Map<String,dynamic>>.from(await _db.from('kc_terms')
            .select('id,academic_year,term_no,starts_on,ends_on').inFilter('id',termIds));
        }
      }
      final newDocuments = List<Map<String,dynamic>>.from(await _db.from('kc_documents')
        .select('id,title,description,category,grade,mime_type,original_name,storage_path,created_at')
        .eq('published',true).order('created_at',ascending:false).limit(100));
      final newAlerts = List<Map<String, dynamic>>.from(await _db.from('kc_notifications')
        .select().eq('user_id', user.id).order('created_at', ascending: false).limit(100));
      final newNews = List<Map<String, dynamic>>.from(await _db.from('kc_announcements')
        .select().order('created_at', ascending: false).limit(100));
      final newEvents = List<Map<String, dynamic>>.from(await _db.from('kc_events')
        .select().order('school_date', ascending: true).limit(200));
      final newMessages = List<Map<String, dynamic>>.from(await _db.from('kc_messages')
        .select().eq('guardian_id', user.id).order('created_at', ascending: true).limit(200));
      if (!mounted) return;
      setState(() {
        myProfile = profile ?? {'full_name': fullName};
        children = newKids; marks = newMarks; attendance = newAtt;
        alerts = newAlerts; news = newNews; messages = newMessages;
        linkRequests = requests; reports = newReports; reportMarks = newReportMarks;
        reportTerms = newTerms; documents = newDocuments;
        classes = newClasses; events = newEvents;
        if (!children.any((x) => x['id'] == selectedChild)) {
          selectedChild = children.isEmpty ? null : textValue(children.first['id']);
        }
        error = null; loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        error = 'Unable to refresh school information. ${e is PostgrestException ? e.message : 'Check your connection and try again.'}';
        loading = false;
      });
    }
  }

  Map<String, dynamic>? get child {
    for (final item in children) { if (item['id'] == selectedChild) return item; }
    return children.isEmpty ? null : children.first;
  }
  String get childName => textValue(child?['full_name']);
  List<Map<String, dynamic>> get childMarks =>
    marks.where((x) => x['learner_id'] == selectedChild).toList();
  List<Map<String, dynamic>> get childAttendance =>
    attendance.where((x) => x['learner_id'] == selectedChild).toList();
  String? classLabel(String? id) {
    for (final c in classes) { if (c['id'] == id) return textValue(c['name']); }
    return null;
  }
  int? get average {
    if (childMarks.isEmpty) return null;
    return (childMarks.fold<double>(0, (sum, x) => sum +
      ((x['score'] as num?)?.toDouble() ?? 0)) / childMarks.length).round();
  }
  int get presentDays => childAttendance.where((x) => x['status'] == 'Present').length;
  int get absentDays => childAttendance.where((x) => x['status'] == 'Absent').length;
  int get unread => alerts.where((x) => x['is_read'] != true).length;
  List<Map<String,dynamic>> get childReports => reports.where((r) => r['learner_id']==selectedChild).toList();
  String reportLabel(Map<String,dynamic> r) {
    final term = reportTerms.where((x) => x['id']==r['term_id']).toList();
    if(term.isEmpty) return 'Published report';
    return '${term.first['academic_year']} · Term ${term.first['term_no']}';
  }

  String get selectedClass => classLabel(textValue(child?['class_id'])) ?? 'Class pending';

  void selectTab(int index) => setState(() => tab = index);
  Widget contentWrap(Widget content) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 1120), child: content));
  Widget familyPicker() {
    if (children.length < 2) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 20), child:
      DropdownButtonFormField<String>(
        value: selectedChild, decoration: const InputDecoration(labelText: 'Viewing learner',
          prefixIcon: Icon(Icons.people_outline_rounded)),
        items: children.map((x) => DropdownMenuItem(value: textValue(x['id']),
          child: Text(textValue(x['full_name'])))).toList(),
        onChanged: (value) => setState(() => selectedChild = value),
      ));
  }
  Widget navigationTile(IconData icon, String label, int index, {bool compact = false}) {
    final active = tab == index;
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Material(
      color: active ? Brand.mint : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(onTap: () => selectTab(index), borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(children: [
            Icon(icon, color: active ? Brand.green : Brand.muted, size: 23),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              color: active ? Brand.forest : Brand.muted, fontSize: 14))),
            if (index == 4 && unread > 0) StatusChip('$unread',
              color: Colors.white, background: Brand.amber),
          ])),
      ),
    ));
  }

  Widget headline(String title, String subtitle, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 31, color: Brand.ink,
          fontWeight: FontWeight.w900, letterSpacing: -.9)),
        const SizedBox(height: 7),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: Brand.muted)),
      ])),
      if (trailing != null) trailing,
    ]),
  );

  Widget heroPanel() {
    final name = greetingName(textValue(myProfile?['full_name']));
    return Container(
      width: double.infinity, constraints: const BoxConstraints(minHeight: 225),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(29),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Brand.forest, Color(0xFF176B99), Color(0xFF2C9BCB)]),
        boxShadow: const [BoxShadow(color: Color(0x1F10483B), blurRadius: 26, offset: Offset(0, 13))]),
      child: Stack(children: [
        Positioned(right: -58, bottom: -111, child: Container(width: 300, height: 300,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(.12), width: 52)))),
        Positioned(right: 63, top: -115, child: Container(width: 220, height: 220,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: Colors.white.withOpacity(.045)))),
        Padding(padding: const EdgeInsets.all(29), child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const StatusChip('YOUR FAMILY SPACE', color: Brand.forest, background: Brand.lime),
              const Icon(Icons.auto_awesome_rounded, color: Brand.lime, size: 25),
            ]),
            const SizedBox(height: 23),
            Text('Hello, $name 👋', style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w900, fontSize: 31, letterSpacing: -.75)),
            const SizedBox(height: 10),
            Text(child == null
              ? 'Your account is ready. Your school will verify your learner link.'
              : 'A little closer to everything that matters in your child’s day.',
              style: const TextStyle(fontSize: 15, color: Color(0xFFE7F6FE), height: 1.5)),
            const SizedBox(height: 26),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_user_outlined, color: Brand.lime, size: 18),
              const SizedBox(width: 8),
              Text(child == null ? 'Awaiting school verification' : 'Securely connected to your school',
                style: const TextStyle(color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget statCard(String label, String value, IconData icon, {Color? tint, Color? inkColor}) =>
    SoftCard(padding: const EdgeInsets.all(17), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon, background: tint ?? Brand.mint,
          foreground: inkColor ?? Brand.green, size: 43),
        const SizedBox(height: 15),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(
          color: Brand.ink, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12,
          fontWeight: FontWeight.w700)),
      ],
    ));

  Widget quickAction(String title, String subtitle, IconData icon,
      int target, {Color color = Brand.mint, Color iconColor = Brand.green}) =>
    SoftCard(onTap: () => selectTab(target), padding: const EdgeInsets.all(16),
      child: Row(children: [
        IconBadge(icon, size: 45, background: color, foreground: iconColor),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Brand.ink)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Brand.muted),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        const Icon(Icons.arrow_outward_rounded, color: Brand.muted, size: 18),
      ]),
    );

  Widget announcementCard(Map<String, dynamic> item) {
    final priority = textValue(item['priority']).toLowerCase();
    final important = priority.contains('urgent') || priority.contains('important') || priority.contains('high');
    return SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(Icons.campaign_outlined,
          background: important ? Brand.softAmber : Brand.mint,
          foreground: important ? Brand.amber : Brand.green),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(textValue(item['title']), style: const TextStyle(fontWeight: FontWeight.w900,
            color: Brand.ink, fontSize: 16)),
          const SizedBox(height: 5),
          Text(friendlyDate(item['created_at']), style: const TextStyle(
            color: Brand.muted, fontSize: 12)),
        ])),
        if (important) const StatusChip('IMPORTANT',
          color: Brand.amber, background: Brand.softAmber),
      ]),
      const SizedBox(height: 15),
      Text(textValue(item['body']), style: const TextStyle(
        color: Brand.ink, height: 1.55, fontSize: 14)),
    ]));
  }

  void snack(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> requestLearnerLink() async {
    final name = TextEditingController();
    final birth = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final send = await showDialog<bool>(context:context, builder:(dialogContext) => AlertDialog(
        title:const Text('Connect your child'),
        content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:
          SingleChildScrollView(child:Form(key:formKey,child:Column(
            mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Enter your child’s name and date of birth as recorded by the school. A school administrator will verify your relationship before any records are shared.',
              style:TextStyle(color:Brand.muted,height:1.5)),
            const SizedBox(height:18),
            TextFormField(controller:name,textCapitalization:TextCapitalization.words,
              decoration:const InputDecoration(labelText:'Child’s full name'),
              validator:(v)=>v==null || v.trim().length<3 ? 'Enter the full name' : null),
            const SizedBox(height:13),
            TextFormField(controller:birth,keyboardType:TextInputType.datetime,
              decoration:InputDecoration(labelText:'Date of birth (YYYY-MM-DD)',
                suffixIcon:IconButton(tooltip:'Choose birth date',onPressed:() async {
                  final picked=await showDatePicker(context:dialogContext,
                    initialDate:DateTime(2013),firstDate:DateTime(1990),lastDate:DateTime.now());
                  if(picked!=null) birth.text='${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                },icon:const Icon(Icons.calendar_month_outlined))),
              validator:(v){
                final t=(v??'').trim();final date=DateTime.tryParse(t);
                if(!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)||date==null||
                  date.toIso8601String().substring(0,10)!=t||date.isAfter(DateTime.now())||date.year<1990)
                  return 'Enter a valid date (YYYY-MM-DD)';
                return null;
              }),
          ])))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),
          FilledButton(onPressed:(){if(formKey.currentState!.validate()) Navigator.pop(dialogContext,true);},
            child:const Text('Send request')),
        ]));
      if(send!=true || !mounted)return;
      setState(()=>sendingRequest=true);
      final user=_db.auth.currentUser;
      if(user==null){snack('Please sign in first.');return;}
      await _db.from('kc_guardian_requests').insert({
        'parent_id':user.id,'child_name':name.text.trim(),
        'child_birth_date':birth.text.trim(),
      });
      snack('Request sent. The school will review your guardian relationship.');
      await load(silent:true);
    } on PostgrestException catch(e) {
      snack(e.code=='23505'?'A pending request already exists for that child.':e.message);
    } catch (_) {snack('Unable to send request. Please try again.');}
    finally {name.dispose();birth.dispose();if(mounted)setState(()=>sendingRequest=false);}
  }

  Widget claimPanel()=>SoftCard(padding:const EdgeInsets.all(24),child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const IconBadge(Icons.family_restroom_rounded,size:52),const SizedBox(width:14),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(children.isEmpty ? 'Request access to your child' : 'Connect another child',style:TextStyle(color:Brand.ink,fontSize:17,fontWeight:FontWeight.w900)),
          SizedBox(height:4),Text('Parent-initiated · school-approved',style:TextStyle(color:Brand.muted,fontSize:12))]))]),
      const SizedBox(height:14),
      const Text('Enter your child’s name and date of birth. The school checks the details and independently verifies guardianship before approving access.',
        style:TextStyle(color:Brand.muted,height:1.5)),
      const SizedBox(height:14),
      for(final r in linkRequests.where((r) => r['status'] != 'approved' ||
          !children.any((child) => child['id'] == r['learner_id'])).take(5))
        Padding(padding:const EdgeInsets.only(bottom:9),
        child:Row(children:[
          Expanded(child:Text(textValue(r['child_name']),maxLines:1,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontWeight:FontWeight.w700,color:Brand.ink))),
          StatusChip(textValue(r['status']).toUpperCase(),color:r['status']=='approved' ? Brand.green : Brand.amber,
            background:r['status']=='approved' ? Brand.mint : Brand.softAmber),
        ])),
      const SizedBox(height:7),
      ElevatedButton.icon(onPressed:sendingRequest?null:requestLearnerLink,
        icon:const Icon(Icons.add_circle_outline_rounded),label:const Text('Request learner access')),
  ]));

  Future<void> downloadReport(Map<String,dynamic> preview) async {
    try {
      final id=textValue(preview['id']);
      final current=await _db.from('kc_report_cards')
        .select('id,learner_id,term_id,status,teacher_comment,published_at')
        .eq('id',id).eq('status','published').maybeSingle();
      if(current==null || current['learner_id']!=selectedChild){
        snack('This report is no longer available. Refresh the app.');return;
      }
      final rows=List<Map<String,dynamic>>.from(await _db.from('kc_report_marks')
        .select('subject,percentage').eq('report_id',id).order('subject'));
      final term=reportTerms.where((r)=>r['id']==current['term_id']).toList();
      final termLabel=term.isEmpty?'Published report':'${term.first['academic_year']} · Term ${term.first['term_no']}';
      final averageMark=rows.isEmpty?null:rows.fold<double>(0,(sum,r)=>sum+(num.tryParse(textValue(r['percentage']))?.toDouble()??0))/rows.length;
      final document=pw.Document(title:'Kagisho Connect — $childName — $termLabel',author:'Kagisho Connect');
      final dark=PdfColor.fromInt(0xFF144B72);
      document.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,
        margin:const pw.EdgeInsets.all(38),
        build:(ctx)=>[
          pw.Container(padding:const pw.EdgeInsets.all(20),color:dark,child:pw.Column(
            crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
            pw.Text('KAGISHO CONNECT',style:pw.TextStyle(color:PdfColors.white,fontSize:13,fontWeight:pw.FontWeight.bold)),
            pw.SizedBox(height:10),
            pw.Text('Learner academic report',style:pw.TextStyle(color:PdfColors.white,fontSize:22,fontWeight:pw.FontWeight.bold)),
          ])),
          pw.SizedBox(height:23),
          pw.Text(childName,style:pw.TextStyle(fontSize:19,fontWeight:pw.FontWeight.bold,color:dark)),
          pw.SizedBox(height:6),pw.Text('$selectedClass   ·   $termLabel'),
          pw.SizedBox(height:24),
          pw.Table.fromTextArray(headers:['SUBJECT','PERCENTAGE'],
            data:rows.map((r)=>[textValue(r['subject']), '${r['percentage']}%']).toList(),
            headerStyle:pw.TextStyle(color:PdfColors.white,fontWeight:pw.FontWeight.bold),
            headerDecoration:pw.BoxDecoration(color:dark),
            cellPadding:const pw.EdgeInsets.all(11)),
          pw.SizedBox(height:16),
          pw.Text('Overall average: ${averageMark==null ? 'Not available' : '${averageMark.toStringAsFixed(1)}%'}',
            style:pw.TextStyle(fontSize:16,fontWeight:pw.FontWeight.bold,color:dark)),
          pw.SizedBox(height:20),
          pw.Text('Teacher comments',style:pw.TextStyle(fontSize:13,fontWeight:pw.FontWeight.bold,color:dark)),
          pw.SizedBox(height:5),pw.Text(textValue(current['teacher_comment']).trim().isEmpty
            ? 'No comments supplied.' : textValue(current['teacher_comment'])),
          pw.SizedBox(height:22),
          pw.Divider(color:PdfColors.grey400),
          pw.Text('Published by the school · ${friendlyDate(current['published_at'])}',
            style:pw.TextStyle(fontSize:10,color:PdfColors.grey700)),
        ]));
      await Printing.layoutPdf(name:'Kagisho_Report_${childName.replaceAll(' ','_')}.pdf',
        onLayout:(_)=>document.save());
    } on PostgrestException catch(e){snack('Could not load report: ${e.message}');}
    catch(_){snack('Unable to prepare PDF. Please try again.');}
  }

  Widget reportCardsPanel()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    SectionTitle('Official report cards',subtitle:'School-published reports · private to verified guardians'),
    if(childReports.isEmpty) const EmptyPanel(icon:Icons.description_outlined,
      heading:'No published reports yet',detail:'Your child’s official term reports will appear after the school publishes them.')
    else ...childReports.map((r)=>Padding(padding:const EdgeInsets.only(bottom:12),
      child:SoftCard(child:Row(children:[
        const IconBadge(Icons.workspace_premium_rounded,size:49),const SizedBox(width:13),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(reportLabel(r),style:const TextStyle(color:Brand.ink,fontWeight:FontWeight.w900,fontSize:16)),
          const SizedBox(height:5),Text('Published ${friendlyDate(r['published_at'])}',
            style:const TextStyle(fontSize:12,color:Brand.muted)),
        ])),
        FilledButton.tonalIcon(onPressed:()=>downloadReport(r),
          icon:const Icon(Icons.picture_as_pdf_outlined,size:18),label:const Text('PDF')),
      ])))),
  ]);

  Future<void> openSchoolDocument(Map<String,dynamic> document) async {
    try {
      final path=textValue(document['storage_path']);
      if(path.isEmpty){snack('Document not available.');return;}
      final url=await _db.storage.from('kagisho-documents').createSignedUrl(path,120);
      if(!await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication)){
        snack('Could not open document on this device.');
      }
    } on StorageException catch(e) {snack('Could not open document: ${e.message}');}
    catch(_){snack('Unable to download document.');}
  }

  Widget documentsPanel()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    SectionTitle('School documents',subtitle:'Published documents relevant to your child’s grade'),
    if(documents.isEmpty) const EmptyPanel(icon:Icons.folder_outlined,
      heading:'No documents available yet',detail:'School forms, policies and letters will appear here after publication.')
    else ...documents.map((d)=>Padding(padding:const EdgeInsets.only(bottom:11),
      child:SoftCard(onTap:()=>openSchoolDocument(d),child:Row(children:[
        IconBadge(textValue(d['mime_type'])=='application/pdf'?Icons.picture_as_pdf_rounded:Icons.insert_drive_file_outlined,
          size:49,background:Brand.mint),
        const SizedBox(width:13),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(textValue(d['title']),style:const TextStyle(color:Brand.ink,fontSize:15,fontWeight:FontWeight.w900)),
          const SizedBox(height:6),Text('${textValue(d['category'])} · ${d['grade']==null?'All grades':'Grade ${d['grade']}'}',
            style:const TextStyle(color:Brand.muted,fontSize:12)),
          if(textValue(d['description']).trim().isNotEmpty)...[
            const SizedBox(height:5),Text(textValue(d['description']),maxLines:2,overflow:TextOverflow.ellipsis,
              style:const TextStyle(color:Brand.muted,fontSize:12))],
        ])),
        const Icon(Icons.download_rounded,color:Brand.green),
      ])))),
  ]);

  Widget homePage() => ListView(padding: const EdgeInsets.fromLTRB(19, 22, 19, 36), children: [
    heroPanel(),
    const SizedBox(height: 29),
    if (child != null) ...[
      familyPicker(),
      SectionTitle('Your child', subtitle: 'A quick look at the school day',
        action: 'View profile', onTap: () => selectTab(1)),
      SoftCard(onTap: () => selectTab(1), child: Row(children: [
        Container(width: 59, height: 59,
          decoration: BoxDecoration(color: Brand.mint, borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.face_rounded, color: Brand.green, size: 31)),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(childName, style: const TextStyle(fontSize: 18,
            fontWeight: FontWeight.w900, color: Brand.ink)),
          const SizedBox(height: 5),
          Text(selectedClass, style: const TextStyle(color: Brand.muted, fontSize: 13)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: Brand.green),
      ])),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final gap = c.maxWidth < 370 ? 8.0 : 12.0;
        return Row(children: [
          Expanded(child: statCard(presentDays==1?'Day present':'Days present', '$presentDays', Icons.how_to_reg_rounded)),
          SizedBox(width: gap),
          Expanded(child: statCard('Academic avg.', average == null ? '—' : '$average%',
            Icons.trending_up_rounded, tint: const Color(0xFFEBF1FF),
            inkColor: const Color(0xFF627ED2))),
          SizedBox(width: gap),
          Expanded(child: statCard('New alerts', '$unread', Icons.notifications_active_outlined,
            tint: Brand.softAmber, inkColor: Brand.amber)),
        ]);
      }),
    ] else ...[
      const EmptyPanel(icon: Icons.verified_user_outlined, heading: 'School verification pending',
        detail: 'Request a learner link below. The school must verify your guardianship before access is granted.'),
      const SizedBox(height: 14), claimPanel(),
    ],
    const SizedBox(height: 30),
    const SectionTitle('Quick access', subtitle: 'Everything you need, one tap away'),
    LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 700;
      final first = quickAction('Messages', 'Talk to the school', Icons.chat_bubble_outline_rounded, 3);
      final second = quickAction('Announcements', 'Latest school updates', Icons.campaign_outlined, 2,
        color: const Color(0xFFF2EFFF), iconColor: const Color(0xFF816AC8));
      final third = quickAction('Attendance', 'View learner history', Icons.calendar_month_outlined, 1);
      final fourth = quickAction('Alerts', 'Important updates', Icons.notifications_none_rounded, 4,
        color: Brand.softAmber, iconColor: Brand.amber);
      if (!wide) return Column(children: [
        first, const SizedBox(height: 10), second, const SizedBox(height: 10),
        third, const SizedBox(height: 10), fourth, const SizedBox(height: 10),
        quickAction('Report cards', 'View and save official PDF reports', Icons.picture_as_pdf_outlined, 1),
        const SizedBox(height:10), quickAction('Documents', 'Download school letters and forms', Icons.folder_open_outlined, 2),
      ]);
      return Column(children: [
        Row(children: [Expanded(child: first), const SizedBox(width: 12), Expanded(child: second)]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: third), const SizedBox(width: 12), Expanded(child: fourth)]),
        const SizedBox(height: 12), Row(children: [
          Expanded(child: quickAction('Report cards', 'Official PDF reports', Icons.picture_as_pdf_outlined, 1)),
          const SizedBox(width:12),
          Expanded(child: quickAction('Documents', 'School letters and forms', Icons.folder_open_outlined, 2)),
        ]),
      ]);
    }),
    const SizedBox(height: 31),
    SectionTitle('From your school', subtitle: 'The latest news and notices',
      action: 'All updates', onTap: () => selectTab(2)),
    if (news.isEmpty) const EmptyPanel(icon: Icons.markunread_mailbox_outlined,
      heading: 'All caught up', detail: 'New school announcements will appear here.')
    else ...news.take(2).map((item) => Padding(padding: const EdgeInsets.only(bottom: 12),
      child: announcementCard(item))),
  ]);

  // Premium learner overview: layout-only enhancements to existing school data.
  // All scores, attendance records, and child identity still come from Supabase.
  Widget learnerHeader() => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 202),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF0E3655), Color(0xFF165E8A), Color(0xFF24A6E2)]),
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [BoxShadow(color: Color(0x1A105244), blurRadius: 30, offset: Offset(0, 15))],
    ),
    child: Stack(children: [
      Positioned(right: -90, bottom: -145, child: Container(
        width: 340, height: 340, decoration: BoxDecoration(
          shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.1), width: 48)))),
      Positioned(right: 65, top: -118, child: Container(
        width: 210, height: 210, decoration: BoxDecoration(
          shape: BoxShape.circle, color: Colors.white.withOpacity(.05)))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.stars_rounded, size: 17, color: Brand.lime),
            const SizedBox(width: 7),
            const Text('LEARNER SPOTLIGHT', style: TextStyle(color: Brand.lime,
              fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.6)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.14),
                borderRadius: BorderRadius.circular(99)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_rounded, color: Brand.lime, size: 15),
                SizedBox(width: 6),
                Text('VERIFIED', style: TextStyle(color: Colors.white,
                  fontSize: 10, letterSpacing: .8, fontWeight: FontWeight.w900)),
              ])),
          ]),
          const SizedBox(height: 26),
          Row(children: [
            Container(width: 68, height: 68,
              decoration: BoxDecoration(color: Colors.white.withOpacity(.15),
                border: Border.all(color: Colors.white.withOpacity(.2)),
                borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.school_rounded, size: 37, color: Colors.white)),
            const SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(childName, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w900, letterSpacing: -.6)),
              const SizedBox(height: 7),
              Text('$selectedClass  •  Your learner', style: const TextStyle(
                color: Color(0xFFE3F5FF), fontWeight: FontWeight.w600, fontSize: 13)),
            ])),
          ]),
          const SizedBox(height: 19),
          Text('Growing, learning and showing up — one day at a time.',
            style: TextStyle(color: Colors.white.withOpacity(.86),
              fontSize: 13, height: 1.4)),
        ])),
    ]),
  );

  Widget learningRing(int? percent, Color accent) {
    final value = (percent ?? 0).clamp(0, 100).toDouble() / 100;
    return SizedBox(width: 116, height: 116, child: Stack(
      fit: StackFit.expand, children: [
        CircularProgressIndicator(value: value, strokeWidth: 11,
          strokeCap: StrokeCap.round, backgroundColor: Brand.border, color: accent),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(percent == null ? '—' : '$percent%', style: const TextStyle(
            color: Brand.ink, fontSize: 27, fontWeight: FontWeight.w900,
            letterSpacing: -1.1)),
          Text(percent == null ? 'NO DATA' : 'ON RECORD', style: const TextStyle(
            color: Brand.muted, fontSize: 9, letterSpacing: .8,
            fontWeight: FontWeight.w800)),
        ])),
      ],
    ));
  }

  Widget learnerInsightCard({required String label, required int? value,
    required String description, required String footnote,
    required IconData icon, required Color accent, required Color iconBackground}) =>
    SoftCard(padding: const EdgeInsets.all(23), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(icon, size: 42, background: iconBackground, foreground: accent),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Brand.ink,
            fontSize: 16, fontWeight: FontWeight.w900))),
          const Icon(Icons.more_horiz_rounded, color: Brand.muted),
        ]),
        const SizedBox(height: 23),
        Row(children: [
          learningRing(value, accent),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(description, style: const TextStyle(color: Brand.ink,
              fontSize: 15, fontWeight: FontWeight.w800, height: 1.4)),
            const SizedBox(height: 8),
            const Text('A snapshot of information shared by the school.',
              style: TextStyle(color: Brand.muted, fontSize: 12, height: 1.5)),
          ])),
        ]),
        const SizedBox(height: 22),
        const Divider(height: 1, color: Brand.border),
        const SizedBox(height: 15),
        Row(children: [
          const Icon(Icons.info_outline_rounded, color: Brand.muted, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(footnote, style: const TextStyle(
            color: Brand.muted, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      ],
    ));

  Widget learningResultsCard(List<Map<String, dynamic>> results) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Subject performance', subtitle: 'Progress in every subject'),
      if (results.isEmpty)
        const EmptyPanel(icon: Icons.menu_book_outlined,
          heading: 'Results on the way',
          detail: 'Scores will appear after the school publishes them.')
      else SoftCard(padding: const EdgeInsets.all(22), child: Column(children: [
        for (var i = 0; i < results.length; i++) ...[
          if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1, color: Brand.border)),
          Builder(builder: (context) {
            final item = results[i];
            final score = (item['score'] as num?)?.toDouble() ?? 0;
            final displayScore = score.round();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 35, height: 35,
                  decoration: BoxDecoration(color: Brand.mint,
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.menu_book_rounded, size: 18, color: Brand.green)),
                const SizedBox(width: 10),
                Expanded(child: Text(textValue(item['subject']),
                  style: const TextStyle(color: Brand.ink, fontWeight: FontWeight.w900,
                    fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
                Text('$displayScore%', style: const TextStyle(color: Brand.green,
                  fontWeight: FontWeight.w900, fontSize: 19)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: score.clamp(0, 100) / 100, minHeight: 10,
                  backgroundColor: Brand.mint, color: Brand.green)),
            ]);
          }),
        ],
        const SizedBox(height: 18),
        const Divider(height: 1, color: Brand.border),
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.insights_outlined, size: 17, color: Brand.green),
          const SizedBox(width: 7),
          Expanded(child: Text('${results.length} subject result${results.length == 1 ? '' : 's'} published',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: Brand.muted))),
        ]),
      ])),
    ],
  );

  Widget learnerAttendanceCard(List<Map<String, dynamic>> records) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Attendance timeline', subtitle: 'Only submitted school registers appear'),
      if (records.isEmpty)
        const EmptyPanel(icon: Icons.event_available_outlined,
          heading: 'No attendance records yet',
          detail: 'Daily registers will appear here after the school submits them.')
      else SoftCard(padding: const EdgeInsets.all(22), child: Column(children: [
        for (var i = 0; i < records.length; i++) ...[
          if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: Brand.border)),
          Builder(builder: (context) {
            final item = records[i];
            final present = item['status'] == 'Present';
            return Row(children: [
              IconBadge(present ? Icons.check_circle_outline_rounded : Icons.event_busy_outlined,
                background: present ? Brand.mint : Brand.softAmber,
                foreground: present ? Brand.green : Brand.amber, size: 43),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(friendlyDate(item['school_date']), style: const TextStyle(
                  color: Brand.ink, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Submitted register', style: TextStyle(
                  color: Brand.muted, fontSize: 11)),
              ])),
              StatusChip(textValue(item['status']),
                color: present ? Brand.green : Brand.amber,
                background: present ? Brand.mint : Brand.softAmber),
            ]);
          }),
        ],
        const SizedBox(height: 15),
        const Divider(height: 1, color: Brand.border),
        const SizedBox(height: 14),
        Text('${records.length} recorded school day${records.length == 1 ? '' : 's'}',
          style: const TextStyle(color: Brand.muted, fontSize: 12)),
      ])),
    ],
  );

  Widget learnerPage() {
    if (child == null) return ListView(children: [const Padding(
      padding: EdgeInsets.all(20), child: EmptyPanel(icon: Icons.family_restroom_rounded,
        heading: 'Your family space is almost ready',
        detail: 'Request access with your child’s name and date of birth. The school must independently verify guardianship.')),
      Padding(padding:const EdgeInsets.fromLTRB(20,0,20,20),child:claimPanel())]);
    final results = childMarks;
    final records = childAttendance;
    final consideredDays = presentDays + absentDays;
    final attendancePercent = consideredDays == 0 ? null : (100 * presentDays / consideredDays).round();

    final academic = learnerInsightCard(label: 'Academic average', value: average,
      description: average == null ? 'No published scores yet'
        : 'Your child’s latest recorded subject scores',
      footnote: '${results.length} subject result${results.length == 1 ? '' : 's'} included in this average',
      icon: Icons.auto_graph_rounded, accent: Brand.green, iconBackground: Brand.mint);
    final attendanceInsight = learnerInsightCard(label: 'Recorded attendance',
      value: attendancePercent,
      description: attendancePercent == null ? 'Attendance records are on the way'
        : '$presentDays present · $absentDays absent',
      footnote: 'Based on $consideredDays recorded day${consideredDays == 1 ? '' : 's'} (not the full term)',
      icon: Icons.event_available_rounded, accent: const Color(0xFF6177D4),
      iconBackground: const Color(0xFFEEF0FF));

    return ListView(padding: const EdgeInsets.fromLTRB(20, 25, 20, 45), children: [
      headline('My children', 'Their learning journey, all in one beautiful place'),
      familyPicker(),
      learnerHeader(),
      const SizedBox(height: 27),
      reportCardsPanel(),
      const SizedBox(height: 25),
      const SectionTitle('At a glance', subtitle: 'A clearer picture of today’s school records'),
      LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 800) return Row(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: academic), const SizedBox(width: 17),
            Expanded(child: attendanceInsight),
          ]);
        return Column(children: [academic, const SizedBox(height: 14), attendanceInsight]);
      }),
      const SizedBox(height: 31),
      LayoutBuilder(builder: (context, c) {
        final resultsCard = learningResultsCard(results);
        final attendanceCard = learnerAttendanceCard(records);
        if (c.maxWidth >= 800) return Row(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: resultsCard), const SizedBox(width: 17),
            Expanded(child: attendanceCard),
          ]);
        return Column(children: [resultsCard, const SizedBox(height: 25), attendanceCard]);
      }),
      const SizedBox(height: 26),
      claimPanel(),
      const SizedBox(height: 20),
      SoftCard(color: Brand.mint, padding: const EdgeInsets.all(20),
        child: Wrap(spacing: 15, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const IconBadge(Icons.support_agent_rounded, size: 49,
              background: Brand.white, foreground: Brand.green),
            const Text('Questions about your child’s progress?',
              style: TextStyle(fontSize: 15, color: Brand.ink, fontWeight: FontWeight.w900)),
            TextButton.icon(onPressed: () => selectTab(3),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Message the school')),
          ])),
    ]);
  }

  Widget schoolPage() => ListView(padding: const EdgeInsets.fromLTRB(19, 22, 19, 36), children: [
    headline('School updates', 'Everything happening at school'),
    documentsPanel(),
    const SizedBox(height:30),
    const SectionTitle('School calendar', subtitle: 'Dates worth remembering'),
    if (events.isEmpty) const EmptyPanel(icon: Icons.calendar_today_outlined,
      heading: 'No school events yet', detail: 'Upcoming meetings and important dates will appear here.')
    else ...events.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(child: Row(children: [
        IconBadge(Icons.event_rounded, background: const Color(0xFFEAEFFF),
          foreground: const Color(0xFF657DC4)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(textValue(item['title']), style: const TextStyle(
            fontWeight: FontWeight.w900, color: Brand.ink)),
          const SizedBox(height: 5),
          Text(textValue(item['description']), style: const TextStyle(
            color: Brand.muted, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 9),
        Text(friendlyDate(item['school_date']),
          style: const TextStyle(color: Brand.green, fontSize: 11, fontWeight: FontWeight.w800)),
      ])))),
    const SizedBox(height: 30),
    SectionTitle('Announcements', subtitle: '${news.length} update(s) from your school'),
    if (news.isEmpty) const EmptyPanel(icon: Icons.campaign_outlined,
      heading: 'You’re all caught up', detail: 'Your school’s updates will show here as they are published.')
    else ...news.map((item) => Padding(padding: const EdgeInsets.only(bottom: 12),
      child: announcementCard(item))),
  ]);

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty || message.length > 1000) return;
    final user = _db.auth.currentUser;
    if (user == null) return;
    try {
      await _db.from('kc_messages').insert({
        'guardian_id': user.id, 'sender_id': user.id, 'body': message.trim(),
      });
      await load(silent: true);
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send your message. Try again.')));
    }
  }

  Widget messagesPage() => Column(children: [
    Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: Brand.white,
      child: Row(children: [
        const IconBadge(Icons.support_agent_rounded, size: 48),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('School messages', style: TextStyle(fontWeight: FontWeight.w900,
            color: Brand.ink, fontSize: 17)),
          SizedBox(height: 3),
          Text('Your private conversation with the school',
            style: TextStyle(color: Brand.muted, fontSize: 12)),
        ])),
        IconButton(tooltip: 'Refresh conversation', onPressed: load,
          icon: const Icon(Icons.refresh_rounded, color: Brand.green)),
      ])),
    Expanded(child: messages.isEmpty
      ? Center(child: Padding(padding: const EdgeInsets.all(22),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 410),
            child: const EmptyPanel(icon: Icons.forum_outlined,
              heading: 'Your conversation starts here',
              detail: 'Messages from your school will appear here. Once your learner is verified, you can write to the school.'))))
      : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 25),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final item = messages[index];
            final mine = item['sender_id'] == _db.auth.currentUser?.id;
            return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width > 650 ? 440 :
                  MediaQuery.sizeOf(context).width * .81),
                child: Container(margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: mine ? Brand.green : Brand.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(mine ? 20 : 5),
                      bottomRight: Radius.circular(mine ? 5 : 20)),
                    border: mine ? null : Border.all(color: Brand.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(mine ? 'You' : 'School staff', style: TextStyle(
                      color: mine ? Brand.lime : Brand.green,
                      fontSize: 11, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    Text(textValue(item['body']), style: TextStyle(
                      color: mine ? Colors.white : Brand.ink, height: 1.5)),
                    const SizedBox(height: 7),
                    Text('${friendlyDate(item['created_at'])}  ${clockLabel(item['created_at'])}',
                      style: TextStyle(color: mine ? Colors.white70 : Brand.muted,
                        fontSize: 11)),
                  ])),
              ));
          })),
    SafeArea(top: false, child: Container(
      decoration: const BoxDecoration(color: Brand.white,
        border: Border(top: BorderSide(color: Brand.border))),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
      child: Row(children: [
        Expanded(child: TextField(controller: composer, maxLength: 1000,
          minLines: 1, maxLines: 4, enabled: children.isNotEmpty,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: children.isEmpty
            ? 'Waiting for learner verification...' : 'Write a message...',
            counterText: '', fillColor: Brand.background,
            prefixIcon: const Icon(Icons.edit_note_rounded, color: Brand.muted)))),
        const SizedBox(width: 10),
        Container(width: 52, height: 52,
          decoration: BoxDecoration(color: children.isNotEmpty ? Brand.green : Brand.border,
            borderRadius: BorderRadius.circular(17)),
          child: IconButton(tooltip: 'Send message',
            onPressed: children.isEmpty ? null : () {
              final value = composer.text;
              if (value.trim().isEmpty) return;
              composer.clear(); sendMessage(value);
            }, icon: const Icon(Icons.arrow_upward_rounded, color: Brand.white)),
        ),
      ]),
    )),
  ]);

  Future<void> readAlert(String id) async {
    try {
      await _db.from('kc_notifications').update({'is_read': true})
        .eq('id', id).eq('user_id', _db.auth.currentUser!.id);
      await load(silent: true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the alert.')));
    }
  }

  Widget alertsPage() => ListView(padding: const EdgeInsets.fromLTRB(19, 22, 19, 36), children: [
    headline('Notifications', 'Stay in the know about your child',
      trailing: unread > 0 ? StatusChip('$unread NEW', color: Brand.amber,
        background: Brand.softAmber) : null),
    if (alerts.isEmpty) const EmptyPanel(icon: Icons.notifications_none_rounded,
      heading: 'All clear!', detail: 'Attendance alerts and corrections will appear here.')
    else ...alerts.map((item) {
      final correction = item['kind'] == 'correction';
      final read = item['is_read'] == true;
      return Padding(padding: const EdgeInsets.only(bottom: 12),
        child: SoftCard(color: read ? Brand.white : const Color(0xFFF1FAF5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(correction ? Icons.fact_check_outlined : Icons.notifications_active_outlined,
                background: correction ? Brand.mint : Brand.softAmber,
                foreground: correction ? Brand.green : Brand.amber),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(correction ? 'Attendance updated' : 'Attendance alert',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Brand.ink)),
                const SizedBox(height: 5),
                Text(friendlyDate(item['created_at']),
                  style: const TextStyle(fontSize: 12, color: Brand.muted)),
              ])),
              if (!read) const StatusChip('NEW', background: Brand.lime, color: Brand.forest),
            ]),
            const SizedBox(height: 15),
            Text(textValue(item['body']), style: const TextStyle(color: Brand.ink, height: 1.5)),
            if (!read) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight,
                child: TextButton.icon(onPressed: () => readAlert(textValue(item['id'])),
                  icon: const Icon(Icons.done_all_rounded, size: 17),
                  label: const Text('Mark as read'))),
            ],
          ])),
      );
    }),
  ]);

  Widget activePage() {
    switch (tab) {
      case 1: return learnerPage();
      case 2: return schoolPage();
      case 3: return messagesPage();
      case 4: return alertsPage();
      default: return homePage();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, bounds) {
    final desktop = bounds.maxWidth >= 960;
    final tabs = [
      (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Home'),
      (Icons.family_restroom_outlined, Icons.family_restroom_rounded, 'Children'),
      (Icons.campaign_outlined, Icons.campaign_rounded, 'News'),
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Messages'),
      (Icons.notifications_none_rounded, Icons.notifications_rounded, 'Alerts'),
    ];
    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator(color: Brand.green));
    } else if (error != null) {
      body = Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(padding: const EdgeInsets.all(22), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const IconBadge(Icons.wifi_off_rounded, size: 62,
              background: Brand.softAmber, foreground: Brand.amber),
            const SizedBox(height: 16),
            const Text('We couldn’t load your updates', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900, color: Brand.ink)),
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.muted, height: 1.5)),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: load, child: const Text('Try again')),
          ]))));
    } else if (tab == 3) {
      body = contentWrap(activePage());
    } else {
      body = RefreshIndicator(onRefresh: load, child: contentWrap(activePage()));
    }
    return Scaffold(
      appBar: AppBar(toolbarHeight: 73, backgroundColor: Brand.white,
        surfaceTintColor: Brand.white, scrolledUnderElevation: 0,
        titleSpacing: desktop ? 28 : 17,
        title: KagishoLogo(size: desktop ? 41 : 34),
        actions: [
          if (desktop) const Padding(padding: EdgeInsets.only(right: 14),
            child: Center(child: Text('PARENT PORTAL', style: TextStyle(
              fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w900,
              color: Brand.muted)))),
          IconButton(tooltip: 'Refresh information', onPressed: load,
            icon: const Icon(Icons.refresh_rounded, color: Brand.green)),
          PopupMenuButton<String>(tooltip: 'Account', icon: const CircleAvatar(
            radius: 18, backgroundColor: Brand.mint,
            child: Icon(Icons.person_outline_rounded, color: Brand.green, size: 20)),
            onSelected: (action) async {
              if (action == 'logout') await _db.auth.signOut();
            }, itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Row(children: [
                Icon(Icons.logout_rounded, color: Brand.green, size: 18),
                SizedBox(width: 10), Text('Sign out'),
              ])),
            ]),
          const SizedBox(width: 12),
        ],
      ),
      body: desktop ? Row(children: [
        Container(width: 236, color: Brand.white,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 27),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.fromLTRB(14, 0, 0, 23),
              child: Text('MY FAMILY', style: TextStyle(color: Brand.muted,
                fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4))),
            for (var i = 0; i < tabs.length; i++)
              navigationTile(tabs[i].$1, tabs[i].$3, i),
            const Spacer(),
            Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Brand.mint,
                borderRadius: BorderRadius.circular(18)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.favorite_outline_rounded, color: Brand.green, size: 23),
                SizedBox(height: 11),
                Text('A stronger school connection.', style: TextStyle(
                  color: Brand.forest, fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('Made for families.', style: TextStyle(color: Brand.green, fontSize: 12)),
              ])),
          ]),
        ),
        Expanded(child: body),
      ]) : body,
      bottomNavigationBar: desktop ? null : NavigationBar(
        height: 74, backgroundColor: Brand.white,
        indicatorColor: Brand.mint, elevation: 0,
        selectedIndex: tab, labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: selectTab,
        destinations: [
          for (var i = 0; i < tabs.length; i++) NavigationDestination(
            icon: i == 4 && unread > 0 ? Badge(label: Text('$unread'),
              child: Icon(tabs[i].$1)) : Icon(tabs[i].$1),
            selectedIcon: Icon(tabs[i].$2, color: Brand.green), label: tabs[i].$3),
        ],
      ),
    );
  });
}
