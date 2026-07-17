import 'package:flutter/material.dart';

/// -----------------------------------------------------------------------
/// In-app Privacy Policy screen.
///
/// Shows the same content as the hosted privacy.html page, but rendered
/// natively inside the app — no browser tab, no url_launcher needed for
/// this screen. Reachable by pushing a normal route, e.g.:
///
///   Navigator.of(context).push(
///     MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
///   );
///
/// NOTE: Google Play Console still requires a separately hosted URL
/// (privacy.html at https://notescaseapp.web.app/privacy) in its own
/// "Privacy Policy" field — that check happens before someone even
/// installs the app, so it has to live on the open web regardless of
/// what the in-app experience looks like. This screen is what a user
/// sees *after* they've opened the app; the hosted page is what Play's
/// review process (and anyone browsing your listing) sees. Keep both
/// in sync when you edit the wording.
/// -----------------------------------------------------------------------

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text('NotesCase', style: theme.textTheme.labelLarge?.copyWith(
            color: cs.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2,
          )),
          const SizedBox(height: 4),
          Text('Privacy Policy', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Effective 17 July 2026 · Last updated 17 July 2026',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 20),

          _TldrBox(cs: cs),

          _Heading('1. Who runs NotesCase'),
          _Body(
            'NotesCase ("the app") is developed and operated by Vrutsa '
            'Solutions ("we", "us"), based in Chennai, Tamil Nadu, India. '
            'For any privacy question, write to privacy@vrutsa.com.',
          ),

          _Heading('2. What we collect'),
          _SubHeading('2.1 Account information'),
          _Body('When you sign in with Google, we receive your basic Google account profile:'),
          const _BulletList([
            'Name',
            'Email address',
            'Profile photo URL (if set)',
            'A unique Google user ID',
          ]),
          _Body('We use this only to identify you and to keep your notes attached to your account.'),

          _SubHeading('2.2 Content you create'),
          _Body(
            'Everything you type into the app — notes, titles, tags, passwords, '
            'usernames, Wi-Fi details, license keys, custom fields, checklist '
            'items — is stored in the app\'s Cloud Firestore database under a '
            'path scoped to your Google account ID '
            '(users/{your id}/notes/{note id}).',
          ),

          _SubHeading('2.3 What we do NOT collect'),
          const _BulletList([
            'No location data.',
            'No contacts, SMS, call logs, calendar, or media library access.',
            'No advertising identifiers.',
            'No third-party analytics or trackers.',
            'No crash-reporting SDKs are enabled at this time.',
          ]),

          _Heading('3. How your data is used'),
          _Body('Your data is used only to:'),
          const _BulletList([
            'authenticate you through Google sign-in;',
            'display your notes to you across your signed-in devices;',
            'save changes you make.',
          ]),
          _Body(
            'We do not sell your data, do not use it to serve advertising, '
            'and do not share it with third parties for marketing.',
          ),

          _Heading('4. Where your data lives'),
          _Body(
            'NotesCase uses Google Firebase services — Firebase Authentication '
            '(for Google sign-in) and Cloud Firestore (to store your notes) — '
            'provided by Google LLC. Data is stored on Google infrastructure and '
            'is subject to Firebase\'s privacy and security terms. Data in transit '
            'is encrypted with TLS; data at rest is encrypted by Google.',
          ),
          _Body(
            'Access is enforced by Firestore security rules that only allow reads '
            'and writes from your own signed-in account. The Vrutsa Solutions team '
            'does not access individual user notes in the normal course of running '
            'the service.',
          ),

          _Heading('5. How long we keep your data'),
          const _BulletList([
            'Notes you keep in the app: as long as your account exists.',
            'Notes you move to Trash: automatically deleted after 30 days.',
            'If you delete your account: everything above is deleted (see section 6).',
          ]),

          _Heading('6. Your rights & controls'),
          _Body('Inside the app you can:'),
          const _BulletList([
            'view, edit and delete individual notes;',
            'empty the Trash to permanently delete removed notes;',
            'sign out at any time;',
            'delete your account entirely, via Settings → "Delete my account & '
                'data". This deletes every note under your account from Firestore, '
                'then deletes your Firebase Authentication record. It is irreversible.',
          ]),
          _Body(
            'If you cannot access the app for any reason and need your account '
            'deleted, email privacy@vrutsa.com from the same Google address you '
            'signed in with, and we will complete the deletion within 30 days.',
          ),
          _Body(
            'Under India\'s Digital Personal Data Protection Act, 2023 (DPDP Act) '
            'you also have the right to access, correct, and withdraw consent. To '
            'exercise any of these rights, use the app controls above or email the '
            'address in section 1.',
          ),

          _Heading('7. Children'),
          _Body(
            'NotesCase is not directed to children under 18. We do not knowingly '
            'collect data from anyone under 18. If a parent or guardian believes we '
            'have such data, please contact us and we will delete it.',
          ),

          _Heading('8. Security & honest limits'),
          _Body(
            'Access is protected by Google sign-in and by Firestore security rules '
            'that make each user\'s notes readable only by that user. Data is '
            'encrypted in transit and at rest by Google infrastructure. At this '
            'time, note contents are stored as regular data in Firestore rather '
            'than being end-to-end encrypted — meaning the values are protected by '
            'access rules, not by a key only you hold. Please treat NotesCase as a '
            'convenient private notebook rather than a hardened password vault.',
          ),

          _Heading('9. Changes to this policy'),
          _Body(
            'If we materially change how the app handles data, we will update this '
            'screen (and the hosted page) and the "Last updated" date at the top, '
            'and — where meaningful — notify you inside the app on your next sign-in.',
          ),

          _Heading('10. Contact'),
          _Body('Vrutsa Solutions\nChennai, Tamil Nadu, India\nprivacy@vrutsa.com'),

          const SizedBox(height: 24),
          Divider(color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text(
            '© 2026 Vrutsa Solutions. This policy is provided for the NotesCase app only.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
        ],
      ),
    );
  }
}

class _TldrBox extends StatelessWidget {
  final ColorScheme cs;
  const _TldrBox({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14.5, height: 1.4),
          children: const [
            TextSpan(text: 'The short version. ', style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(
              text: 'NotesCase is a private notebook for your notes, passwords, '
                  'Wi-Fi details and similar personal information. Your notes are '
                  'saved to your own Google account through Firebase Firestore. '
                  'Nobody else can read them — not the developer, not other users. '
                  'You can delete your account and all your data from inside the '
                  'app at any time.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _SubHeading extends StatelessWidget {
  final String text;
  const _SubHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.55)),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  const _BulletList(this.items);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(fontSize: 14.5)),
                Expanded(child: Text(item, style: const TextStyle(fontSize: 14.5, height: 1.5))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
