import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:temple_app/constants.dart'; // Assuming you have AppColors defined here

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
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
                'Terms and Conditions',
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
                'Welcome to Temple App ("App"), a platform designed to facilitate spiritual services, bookings, donations, and community engagement for devotees. By accessing or using this App, you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree with these Terms, please do not use the App.',
                isDarkMode,
              ),
              _buildSectionTitle('1. Acceptance of Terms', isDarkMode),
              _buildSection(
                'By downloading, installing, or using the App, you acknowledge that you have read, understood, and agree to comply with these Terms. We reserve the right to modify these Terms at any time, and such changes will be effective upon posting within the App. Continued use of the App after changes constitutes acceptance of the updated Terms.',
                isDarkMode,
              ),
              _buildSectionTitle('2. Eligibility', isDarkMode),
              _buildSection(
                'To use the App, you must:\n- Be at least 18 years old or have parental consent if under 18.\n- Provide accurate and complete information during registration.\n- Not use the App for any illegal or unauthorized purpose.',
                isDarkMode,
              ),
              _buildSectionTitle('3. Services Offered', isDarkMode),
              _buildSection(
                'The App provides the following services:\n- Booking of poojas, room reservations, and other temple-related offerings.\n- Facilitating donations to the temple.\n- Access to event information and store purchases (where applicable).\n- Profile management and contact options for registered users.\n\nServices are subject to availability and may change without prior notice.',
                isDarkMode,
              ),
              _buildSectionTitle('4. User Accounts', isDarkMode),
              _buildSection(
                '- You may register as a guest or create an account using valid credentials.\n- You are responsible for maintaining the confidentiality of your account details and password.\n- Notify us immediately of any unauthorized use of your account.\n- We reserve the right to suspend or terminate accounts for violation of these Terms.',
                isDarkMode,
              ),
              _buildSectionTitle('5. Payments and Donations', isDarkMode),
              _buildSection(
                '- All payments for bookings, donations, or store purchases are processed through secure third-party payment gateways.\n- Prices are listed in Indian Rupees (₹) unless otherwise stated and are subject to change.\n- Refunds, if applicable, will be processed as per our Refund Policy (available separately in the App).',
                isDarkMode,
              ),
              _buildSectionTitle('6. User Conduct', isDarkMode),
              _buildSection(
                'You agree not to:\n- Use the App to harass, abuse, or harm others.\n- Upload or share content that is offensive, illegal, or violates the rights of others.\n- Attempt to hack, disrupt, or misuse the App’s functionality.\n- Misrepresent your identity or provide false information.',
                isDarkMode,
              ),
              _buildSectionTitle('7. Intellectual Property', isDarkMode),
              _buildSection(
                '- All content, including text, images, logos, and designs within the App, is owned by Temple App or its licensors and protected by copyright and trademark laws.\n- You may not reproduce, distribute, or modify any content without prior written permission.',
                isDarkMode,
              ),
              _buildSectionTitle('8. Limitation of Liability', isDarkMode),
              _buildSection(
                '- The App is provided "as is" without warranties of any kind, express or implied.\n- We are not liable for any indirect, incidental, or consequential damages arising from your use of the App, including loss of data or interruptions in service.\n- We do not guarantee the accuracy or availability of services listed in the App.',
                isDarkMode,
              ),
              _buildSectionTitle('9. Termination', isDarkMode),
              _buildSection(
                'We may terminate or suspend your access to the App at our discretion, without notice, if you violate these Terms or engage in activities deemed harmful to the App or its users.',
                isDarkMode,
              ),
              _buildSectionTitle('10. Governing Law', isDarkMode),
              _buildSection(
                'These Terms are governed by the laws of India. Any disputes arising from your use of the App shall be subject to the exclusive jurisdiction of courts in [City/State, India].',
                isDarkMode,
              ),
              _buildSectionTitle('11. Contact Us', isDarkMode),
              _buildSection(
                'For questions or concerns about these Terms, please contact us at:\n- Email: support@templeapp.com\n- Phone: +91-123-456-7890',
                isDarkMode,
              ),
              const SizedBox(height: 16),
              Text(
                'By using the App, you agree to abide by these Terms and Conditions.',
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
