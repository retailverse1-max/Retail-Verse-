import '../branding/app_branding.dart';

class LegalConstants {
  static String get privacyPolicy => AppBranding.format(_privacyPolicy);
  static String get termsAndConditions => AppBranding.format(_termsAndConditions);

  static const String _privacyPolicy = '''
Privacy Policy

Last updated: May 29, 2026

1. Information We Collect
We collect information you provide directly to us, such as when you create or modify your account, request on-demand services, contact customer support, or otherwise communicate with us. This information may include: name, email, phone number, postal address, profile picture, payment method, items requested (for delivery services), delivery notes, and other information you choose to provide.

2. How We Use Information
We may use the information we collect to:
- Provide, maintain, and improve our Services.
- Process and facilitate transactions and send related information.
- Send support and administrative messages.
- Respond to your comments, questions, and customer service requests.
- Communicate with you about products, services, offers, and events.

3. Sharing of Information
We may share the information we collect about you as described in this privacy policy or as described at the time of collection or sharing, including as follows:
- With third-party vendors, consultants and other service providers who need access to such information to carry out work on our behalf.
- In response to a request for information by a competent authority if we believe disclosure is in accordance with, or is otherwise required by, any applicable law, regulation, or legal process.

4. Security
We take reasonable measures to help protect information about you from loss, theft, misuse and unauthorized access, disclosure, alteration and destruction.

5. Device Permissions & Hardware Access
- Camera: Used exclusively for barcode and QR code scanning.
- Bluetooth: Used only to connect compatible thermal printers and other POS hardware.
These permissions are processed locally and are never used for advertising or tracking purposes.

6. User-Selected Photos
We use the secure system photo picker to allow you to upload specific product or profile images. Our app only accesses the specific images that you manually select. These images are uploaded securely to our servers and are never shared publicly or used for advertising.

7. Third-Party Services
Our application uses third-party services that may collect information used to identify you, authenticate your account, or provide analytics and notifications. These services include:
- Google Play Services
- Google Analytics for Firebase
- Firebase Cloud Messaging
- Facebook (Meta) SDK

8. Account & Data Deletion
Users may permanently delete their Retail Verse account and associated business data by navigating to Settings → Delete Account, or by contacting our support team. Once deletion is completed, data will be removed in accordance with our data retention policies.

9. Contact Us
If you have any questions about this Privacy Policy, please contact us via the Customer Support section.
''';

  static const String _termsAndConditions = '''
Terms and Conditions

Last updated: May 29, 2026

1. Acceptance of Terms
By accessing and using Retail Verse (the "App"), you accept and agree to be bound by the terms and provision of this agreement. In addition, when using these App's particular services, you shall be subject to any posted guidelines or rules applicable to such services.

2. Provision of Services
Retail Verse provides professional retail billing, inventory management, and business analytics. We reserve the right to modify the services to improve functionality, and will provide reasonable notice before discontinuing any major features.

3. User Responsibilities
You are responsible for maintaining the confidentiality of your account and password and for restricting access to your device. You agree to accept responsibility for all activities that occur under your account or password.

4. Payment and Billing
For our premium services, you agree to provide current, complete, and accurate purchase and account information. You agree to promptly update your account and other information, including your email address and payment method details, so that we can complete your transactions.

5. Data Sync and Offline Mode
Retail Verse provides offline capabilities. Data created offline is synced when a connection is restored. We are not liable for data loss due to device failure before synchronization is complete.

6. Limitation of Liability
In no event shall Retail Verse or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use the materials on the App.

7. Third-Party Integrations
The Service may offer integrations with third-party platforms (e.g., e-commerce marketplaces). We are not responsible for the availability, accuracy, or policies of these third-party services.

8. Governing Law
Any claim relating to Retail Verse's App shall be governed by the laws of the operating jurisdiction without regard to its conflict of law provisions.
''';
}
