import 'package:flutter/material.dart';

import '../Services/api_service.dart';

class UsersLocationsScreen extends StatefulWidget {
  const UsersLocationsScreen({super.key});

  @override
  State<UsersLocationsScreen> createState() => _UsersLocationsScreenState();
}

class _UsersLocationsScreenState extends State<UsersLocationsScreen> {
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    getUsersWithLocations();
  }

  Future<void> getUsersWithLocations() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final response = await ApiService.get('/users/locations');
      if (response.statusCode != 200) {
        throw _RequestFailure(
          ApiService.messageForStatus(
            response.statusCode,
            serverMessage: ApiService.responseMessage(response),
          ),
        );
      }

      final result = ApiService.decode(response);
      if (result is! List) {
        throw const FormatException('Expected a list of users.');
      }

      final loadedUsers = result
          .whereType<Map>()
          .map((user) => Map<String, dynamic>.from(user))
          .toList(growable: false);

      if (!mounted) return;
      setState(() => users = loadedUsers);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error is _RequestFailure
            ? error.message
            : ApiService.messageForError(error);
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users & Locations'),
        actions: [
          IconButton(
            tooltip: 'Refresh users',
            onPressed: isLoading ? null : getUsersWithLocations,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: isLoading && users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? _EmptyUsersState(
              message: errorMessage ?? 'No registered users were found.',
              onRetry: getUsersWithLocations,
            )
          : RefreshIndicator(
              onRefresh: getUsersWithLocations,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: users.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${users.length} ${users.length == 1 ? 'user' : 'users'}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 10),
                            _InlineError(message: errorMessage!),
                          ],
                        ],
                      ),
                    );
                  }

                  return _UserLocationCard(user: users[index - 1]);
                },
              ),
            ),
    );
  }
}

class _UserLocationCard extends StatelessWidget {
  const _UserLocationCard({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final location = user['location'] is Map
        ? Map<String, dynamic>.from(user['location'] as Map)
        : null;
    final hasLocation = location != null;
    final statusColor = hasLocation ? const Color(0xFF237A57) : AppColors.muted;
    final name = user['name']?.toString().trim();
    final email = user['email']?.toString().trim();
    final address = location?['address']?.toString().trim();
    final updatedAt = location?['last_updated']?.toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  foregroundColor: AppColors.primary,
                  child: Text(
                    name == null || name.isEmpty ? 'U' : name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name?.isNotEmpty == true ? name! : 'Unnamed user',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _LocationBadge(active: hasLocation, color: statusColor),
              ],
            ),
            if (email?.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              _InfoLine(icon: Icons.mail_outline_rounded, text: email!),
            ],
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.location_on_outlined,
              text: hasLocation && address?.isNotEmpty == true
                  ? address!
                  : hasLocation
                  ? 'Address not available'
                  : 'No location has been shared',
              color: hasLocation ? AppColors.ink : AppColors.muted,
            ),
            if (updatedAt?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _InfoLine(
                icon: Icons.schedule_rounded,
                text: 'Updated $updatedAt',
                color: AppColors.muted,
                small: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationBadge extends StatelessWidget {
  const _LocationBadge({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.location_on_rounded : Icons.location_off_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            active ? 'Shared' : 'Not shared',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.color = AppColors.ink,
    this.small = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: small ? 12 : 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF9D3E32), fontSize: 13),
      ),
    );
  }
}

class _EmptyUsersState extends StatelessWidget {
  const _EmptyUsersState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppColors {
  AppColors._();

  static const primary = Color(0xFFC56A2C);
  static const ink = Color(0xFF20252B);
  static const muted = Color(0xFF6C737C);
}

class _RequestFailure implements Exception {
  const _RequestFailure(this.message);

  final String message;
}
