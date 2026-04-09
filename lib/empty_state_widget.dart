import 'package:flutter/material.dart';
import 'theme.dart';

enum EmptyStateType {
  noData,
  noReminders,
  noAlerts,
  noCaregivers,
  noPatients,
  noChat,
  noFaces,
  error,
}

class EmptyStateWidget extends StatelessWidget {
  final EmptyStateType type;
  final String? title;
  final String? message;
  final VoidCallback? onAction;
  final String? actionText;

  const EmptyStateWidget({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.onAction,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(),
            const SizedBox(height: 24),
            Text(
              title ?? _defaultTitle,
              style: AppTextStyles.headline3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message ?? _defaultMessage,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText ?? _defaultActionText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accentColor.withValues(alpha: 0.15),
      ),
      child: Icon(
        _icon,
        size: 56,
        color: AppTheme.primaryColor,
      ),
    );
  }

  IconData get _icon {
    switch (type) {
      case EmptyStateType.noData:
        return Icons.inbox_outlined;
      case EmptyStateType.noReminders:
        return Icons.notifications_off_outlined;
      case EmptyStateType.noAlerts:
        return Icons.notifications_outlined;
      case EmptyStateType.noCaregivers:
        return Icons.people_outline;
      case EmptyStateType.noPatients:
        return Icons.person_outline;
      case EmptyStateType.noChat:
        return Icons.chat_bubble_outline;
      case EmptyStateType.noFaces:
        return Icons.face_outlined;
      case EmptyStateType.error:
        return Icons.error_outline;
    }
  }

  String get _defaultTitle {
    switch (type) {
      case EmptyStateType.noData:
        return "Aucune donnée";
      case EmptyStateType.noReminders:
        return "Aucun rappel";
      case EmptyStateType.noAlerts:
        return "Aucune alerte";
      case EmptyStateType.noCaregivers:
        return "Aucun proche";
      case EmptyStateType.noPatients:
        return "Aucun patient";
      case EmptyStateType.noChat:
        return "Aucun message";
      case EmptyStateType.noFaces:
        return "Aucun proche enregistré";
      case EmptyStateType.error:
        return "Une erreur est survenue";
    }
  }

  String get _defaultMessage {
    switch (type) {
      case EmptyStateType.noData:
        return "Les données apparaîtront ici";
      case EmptyStateType.noReminders:
        return "Ajoutez des rappels pour ne rien oublier";
      case EmptyStateType.noAlerts:
        return "Tout va bien, aucune alerte";
      case EmptyStateType.noCaregivers:
        return "Liez-vous avec un proche pour commencer";
      case EmptyStateType.noPatients:
        return "Aucun patient lié à votre compte";
      case EmptyStateType.noChat:
        return "Commencez une conversation";
      case EmptyStateType.noFaces:
        return "Ajoutez des proches pour la reconnaissance faciale";
      case EmptyStateType.error:
        return "Veuillez réessayer plus tard";
    }
  }

  String get _defaultActionText {
    switch (type) {
      case EmptyStateType.noReminders:
        return "Ajouter un rappel";
      case EmptyStateType.noCaregivers:
        return "Lier un proche";
      case EmptyStateType.noPatients:
        return "Ajouter un patient";
      case EmptyStateType.noChat:
        return "Commencer";
      case EmptyStateType.noFaces:
        return "Ajouter un proche";
      default:
        return "Réessayer";
    }
  }
}

class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    super.key,
    this.message = "Une erreur est survenue",
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      type: EmptyStateType.error,
      title: "Oups!",
      message: message,
      onAction: onRetry,
      actionText: "Réessayer",
    );
  }
}
