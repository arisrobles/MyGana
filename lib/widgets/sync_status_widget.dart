import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';

class SyncStatusWidget extends StatefulWidget {
  final bool showDetails;
  final VoidCallback? onRetry;

  const SyncStatusWidget({
    super.key,
    this.showDetails = false,
    this.onRetry,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final FirebaseUserSyncService _syncService = FirebaseUserSyncService();
  late Stream<bool> _syncStatusStream;
  late Stream<int> _queueStream;

  @override
  void initState() {
    super.initState();
    _syncStatusStream = Stream.periodic(
      const Duration(seconds: 2),
      (_) => _syncService.isOnline,
    );
    _queueStream = Stream.periodic(
      const Duration(seconds: 2),
      (_) => _syncService.queuedOperations,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _syncStatusStream,
      builder: (context, onlineSnapshot) {
        return StreamBuilder<int>(
          stream: _queueStream,
          builder: (context, queueSnapshot) {
            final isOnline = onlineSnapshot.data ?? true;
            final queuedOps = queueSnapshot.data ?? 0;

            if (isOnline && queuedOps == 0) {
              return _buildOnlineStatus();
            } else if (!isOnline) {
              return _buildOfflineStatus(queuedOps);
            } else {
              return _buildSyncingStatus(queuedOps);
            }
          },
        );
      },
    );
  }

  Widget _buildOnlineStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done,
            size: 16,
            color: Colors.green[600],
          ),
          if (widget.showDetails) ...[
            const SizedBox(width: 4),
            Text(
              'Synced',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfflineStatus(int queuedOps) {
    return GestureDetector(
      onTap: widget.onRetry ?? _retrySync,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 16,
              color: Colors.orange[600],
            ),
            if (widget.showDetails) ...[
              const SizedBox(width: 4),
              Text(
                queuedOps > 0 ? '$queuedOps pending' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncingStatus(int queuedOps) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            ),
          ),
          if (widget.showDetails) ...[
            const SizedBox(width: 4),
            Text(
              'Syncing...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _retrySync() {
    _syncService.forceSync();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Retrying sync...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: Stream.periodic(
        const Duration(seconds: 3),
        (_) => FirebaseUserSyncService().isOnline,
      ),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        final queuedOps = FirebaseUserSyncService().queuedOperations;

        if (isOnline && queuedOps == 0) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isOnline ? Colors.blue[50] : Colors.orange[50],
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.sync : Icons.cloud_off,
                size: 20,
                color: isOnline ? Colors.blue[600] : Colors.orange[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Syncing your progress...'
                      : 'You\'re offline. Changes will sync when connected.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isOnline ? Colors.blue[600] : Colors.orange[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!isOnline)
                TextButton(
                  onPressed: () => FirebaseUserSyncService().forceSync(),
                  child: const Text('Retry'),
                ),
            ],
          ),
        );
      },
    );
  }
}
