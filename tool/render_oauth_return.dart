import 'dart:io';
import 'package:gen_office_mobile/features/ai/data/oauth_return_page.dart';

/// Generates the real callback page for browser QA without a login or token.
void main(List<String> args) => stdout.write(
  oauthReturnPage(success: !args.contains('--error'), nonce: 'qa-page-nonce'),
);
