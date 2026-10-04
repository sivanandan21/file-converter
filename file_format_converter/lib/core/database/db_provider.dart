/// Identifies which backend is currently serving database requests.
enum DbProvider { awsDynamoDb, cloudflareD1, appwrite }

extension DbProviderLabel on DbProvider {
  String get label {
    switch (this) {
      case DbProvider.awsDynamoDb:
        return 'AWS DynamoDB';
      case DbProvider.cloudflareD1:
        return 'Cloudflare D1';
      case DbProvider.appwrite:
        return 'Appwrite';
    }
  }
}
