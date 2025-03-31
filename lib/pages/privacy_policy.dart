import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temple_app/constants.dart'; // Assuming you have AppColors defined here

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color:
            isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last Updated: March 16, 2025',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              _buildSection(
                'At Temple App ("App"), we value your privacy and are committed to protecting your personal information. This Privacy Policy outlines how we collect, use, disclose, and safeguard your data when you use our App. By using the App, you consent to the practices described herein.',
                isDarkMode,
              ),
              _buildSectionTitle('1. Information We Collect', isDarkMode),
              _buildSection(
                'We may collect the following types of information:\n- **Personal Information**: Name, email address, phone number, and address provided during registration or booking.\n- **Payment Information**: Details processed through third-party payment gateways for donations, bookings, or purchases (we do not store full payment details).\n- **Usage Data**: Information about how you interact with the App, such as pages visited, bookings made, and IP address.\n- **Device Information**: Device type, operating system, and unique identifiers.',
                isDarkMode,
              ),
              _buildSectionTitle('2. How We Collect Information', isDarkMode),
              _buildSection(
                '- **Directly from You**: When you register, book services, or contact us.\n- **Automatically**: Through cookies, analytics tools, and log files as you use the App.\n- **Third Parties**: From payment processors or authentication services (e.g., Firebase Auth).',
                isDarkMode,
              ),
              _buildSectionTitle('3. How We Use Your Information', isDarkMode),
              _buildSection(
                'We use your information to:\n- Provide and improve App services (e.g., processing bookings and donations).\n- Communicate with you about bookings, events, or updates.\n- Personalize your experience and display relevant content.\n- Ensure security and prevent fraud.\n- Comply with legal obligations.',
                isDarkMode,
              ),
              _buildSectionTitle('4. Sharing Your Information', isDarkMode),
              _buildSection(
                'We may share your information with:\n- **Service Providers**: Third-party vendors (e.g., payment gateways, cloud storage) who assist in operating the App.\n- **Temple Administration**: To fulfill your bookings or donations.\n- **Legal Authorities**: If required by law or to protect our rights.\n\nWe do not sell or rent your personal information to third parties for marketing purposes.',
                isDarkMode,
              ),
              _buildSectionTitle('5. Data Security', isDarkMode),
              _buildSection(
                '- We use industry-standard encryption and security measures to protect your data.\n- However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.',
                isDarkMode,
              ),
              _buildSectionTitle('6. Your Choices', isDarkMode),
              _buildSection(
                '- **Account Management**: Update or delete your account information via the App’s profile settings.\n- **Notifications**: Opt out of promotional communications within the App or by contacting us.\n- **Cookies**: Adjust your device settings to manage cookie preferences.',
                isDarkMode,
              ),
              _buildSectionTitle('7. Data Retention', isDarkMode),
              _buildSection(
                '- We retain your personal information only as long as necessary to fulfill the purposes outlined in this Policy or as required by law.\n- Inactive accounts may be deleted after 12 months of inactivity.',
                isDarkMode,
              ),
              _buildSectionTitle('8. Children’s Privacy', isDarkMode),
              _buildSection(
                'The App is not intended for children under 13. We do not knowingly collect personal information from children under 13 without parental consent. If you believe we have such data, please contact us.',
                isDarkMode,
              ),
              _buildSectionTitle('9. Third-Party Links', isDarkMode),
              _buildSection(
                'The App may contain links to external sites (e.g., payment gateways). We are not responsible for the privacy practices of these third parties. Please review their policies separately.',
                isDarkMode,
              ),
              _buildSectionTitle('10. Changes to This Policy', isDarkMode),
              _buildSection(
                'We may update this Privacy Policy periodically. Changes will be posted within the App, and significant updates may be communicated via email or in-App notifications. Your continued use of the App after changes indicates acceptance of the revised Policy.',
                isDarkMode,
              ),
              _buildSectionTitle('11. Contact Us', isDarkMode),
              _buildSection(
                'For questions, requests, or concerns about your privacy, please reach out to:\n- Email: privacy@templeapp.com\n- Phone: +91-123-456-7890\n- Address: Temple App, 123 Spiritual Lane, [City, State, PIN], India',
                isDarkMode,
              ),
              _buildSectionTitle('12. Your Rights', isDarkMode),
              _buildSection(
                'Subject to applicable laws, you may have the right to:\n- Access, correct, or delete your personal data.\n- Object to or restrict certain processing of your data.\n- Lodge a complaint with a data protection authority.',
                isDarkMode,
              ),
              const SizedBox(height: 16),
              Text(
                'Thank you for trusting Temple App with your spiritual journey.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }

  Widget _buildSection(String content, bool isDarkMode) {
    return Text(
      content,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: isDarkMode ? AppColors.darkText : AppColors.lightText,
      ),
    );
  }
}
