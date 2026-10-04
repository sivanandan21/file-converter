/// Configuration for the multi-database failover system.
///
/// ─────────────────────────────────────────────────────────────────────────────
///  HOW TO SET UP EACH BACKEND
/// ─────────────────────────────────────────────────────────────────────────────
///
/// ① AWS DYNAMODB (primary — configured via pure-Dart SigV4)
///    Uses AWS DynamoDB table 'file_converter_devices' in Sydney (ap-southeast-2).
///
/// ② CLOUDFLARE D1 (secondary)
///    1. Create a Cloudflare account → Workers & Pages → D1 → Create database
///       Name it: file_converter_db
///    2. Run the SQL in cloudflare/d1_schema.sql in the Cloudflare D1 console
///    3. Deploy the Worker in cloudflare/d1_worker.js:
///         wrangler deploy --name d1-worker
///    4. Fill in the two constants below.
///
/// ③ APPWRITE (tertiary)
///    1. Create a free Appwrite Cloud account at https://cloud.appwrite.io
///    2. Create a project → note the Project ID
///    3. Databases → Create Database → ID: file_converter_db
///    4. Create Collection → ID: user_devices
///    5. Add all attributes matching d1_schema.sql column names
///    6. API Keys → Create Key with databases.read + databases.write scopes
///    7. Fill in the three constants below.
///
/// ─────────────────────────────────────────────────────────────────────────────
class MultiDbConfig {
  // ── Cloudflare D1 ────────────────────────────────────────────────────────────

  /// Full URL of your deployed Cloudflare Worker.
  /// Example: 'https://d1-worker.yourname.workers.dev'
  static const String cloudflareWorkerUrl = '';

  /// Secret key set in your Worker's environment variable API_KEY.
  static const String cloudflareApiKey = '';

  // ── Appwrite ─────────────────────────────────────────────────────────────────

  /// Appwrite endpoint — use 'https://cloud.appwrite.io/v1' for Appwrite Cloud.
  static const String appwriteEndpoint = 'https://cloud.appwrite.io/v1';

  /// Your Appwrite Project ID (found in Settings → Project ID).
  static const String appwriteProjectId = '';

  /// Appwrite API Key with databases.read + databases.write scope.
  static const String appwriteApiKey = '';

  // ── Feature flags ────────────────────────────────────────────────────────────

  /// Set to false to disable Cloudflare D1 tier entirely (e.g. while setting up).
  static bool get enableCloudflareD1 =>
      cloudflareWorkerUrl.isNotEmpty && cloudflareApiKey.isNotEmpty;

  /// Set to false to disable Appwrite tier entirely (e.g. while setting up).
  static bool get enableAppwrite =>
      appwriteProjectId.isNotEmpty && appwriteApiKey.isNotEmpty;
}
