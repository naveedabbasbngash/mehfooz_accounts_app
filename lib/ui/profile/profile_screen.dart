// lib/ui/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/profile/profile_view_model.dart';
import '../../model/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool expandCompanies = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildUI(context, vm);
      },
    );
  }

  Widget _buildUI(BuildContext context, ProfileViewModel vm) {
    final UserModel user = vm.loggedInUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // USER HEADER
          CircleAvatar(
            radius: 55,
            backgroundImage: user.imageUrl.isNotEmpty
                ? NetworkImage(user.imageUrl)
                : null,
            child: user.imageUrl.isEmpty
                ? const Icon(Icons.person, size: 55)
                : null,
          ),

          const SizedBox(height: 12),
          Text(
            user.fullName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            user.email,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),

          const SizedBox(height: 25),

          _companySelectorAnimated(context, vm),

          const SizedBox(height: 25),

          if (user.planStatus != null)
            _infoCard(
              icon: Icons.workspace_premium,
              title: "Plan Status",
              value: user.planStatus!.statusText,
              color: Colors.blue,
            ),

          if (user.expiry != null)
            _infoCard(
              icon: Icons.timer,
              title: "Remaining Days",
              value: "${user.expiry!.remainingDays} days",
              color: Colors.orange,
            ),

          if (user.subscription != null)
            _subscriptionCard(user.subscription!),

          const SizedBox(height: 25),

          _emailMatchCard(vm, user),
        ],
      ),
    );
  }

  // ============================================================
  // COMPANY SELECTOR (Animated)
  // ============================================================
  Widget _companySelectorAnimated(
      BuildContext context, ProfileViewModel vm) {
    final selected = vm.selectedCompany;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Company",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            InkWell(
              onTap: () {
                setState(() => expandCompanies = !expandCompanies);
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.deepPurple, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.deepPurple.shade600),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        selected?.companyName ?? "Select Company",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),

                    AnimatedRotation(
                      turns: expandCompanies ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                    ),
                  ],
                ),
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: expandCompanies
                  ? Column(
                children: [
                  const SizedBox(height: 10),
                  ...vm.companies.map((company) {
                    return ListTile(
                      leading: const Icon(Icons.circle, size: 10),
                      title: Text(company.companyName ?? "Unnamed"),
                      onTap: () {
                        vm.selectCompany(company.companyId,
                            context: context);
                        setState(() => expandCompanies = false);
                      },
                    );
                  }).toList(),
                ],
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // Generic info card
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 35, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value),
      ),
    );
  }

  // Subscription card
  Widget _subscriptionCard(SubscriptionInfo sub) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Subscription Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _subscriptionRow("Plan", sub.planTitle),
            _subscriptionRow("Description", sub.planDescription),
            _subscriptionRow("Price", "${sub.planPrice} PKR"),
            _subscriptionRow("Duration", "${sub.durationMonths} months"),
            _subscriptionRow("Start Date", sub.startDate),
            _subscriptionRow("End Date", sub.endDate),
          ],
        ),
      ),
    );
  }

  Widget _subscriptionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 5, child: Text(value)),
        ],
      ),
    );
  }

  // Email match card
  Widget _emailMatchCard(ProfileViewModel vm, UserModel user) {
    final bool isMatch = vm.dbEmail != null &&
        vm.dbEmail!.trim().toLowerCase() == user.email.trim().toLowerCase();

    return Card(
      color: isMatch ? Colors.green.shade50 : Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          isMatch ? Icons.verified : Icons.error_outline,
          size: 35,
          color: isMatch ? Colors.green : Colors.red,
        ),
        title: const Text(
          "Database Email Check",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isMatch
              ? "✔ Email matches with Db_Info"
              : "❌ Email does NOT match database",
        ),
      ),
    );
  }
}