// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settingsGeneralTitle => 'Paramètres généraux';

  @override
  String get settingsGeneralDescription =>
      'Préférences et configuration de l\'application.';

  @override
  String get settingsAppearanceTitle => 'Paramètres d\'apparence';

  @override
  String get settingsAppearanceSubtitle => 'Personnaliser l\'apparence';

  @override
  String get appearanceScreenTitle => 'Apparence';

  @override
  String get appearanceDescription =>
      'Personnalisez l\'apparence de l\'application.';

  @override
  String get appearanceThemeMode => 'Thème';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeSystem => 'Système';

  @override
  String get appearanceAccentColor => 'Couleur d\'accent';

  @override
  String get commonBackToSettings => 'Retour aux paramètres';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get desktopSettingsTitle => 'Paramètres du bureau';

  @override
  String get desktopHeading => 'Bureau';

  @override
  String get desktopDescription =>
      'Paramètres propres à l\'ordinateur et opérations sur les fichiers.';

  @override
  String get desktopFileOperations => 'Opérations sur les fichiers';

  @override
  String get desktopFileOperationsSubtitle =>
      'Gérer les opérations sur les fichiers et les autorisations';

  @override
  String get desktopGuiAutomation => 'Automatisation de l\'interface';

  @override
  String get desktopGuiAutomationSubtitle =>
      'Configurer l\'automatisation du bureau';

  @override
  String get llmProviderSettingsTitle => 'Fournisseurs de modèles';

  @override
  String get llmProviderHermesDescription =>
      'Cette application utilise Hermes Agent comme environnement d\'exécution principal. La discussion et les fonctions associées passent par votre installation locale de Hermes.';

  @override
  String get llmProviderOpenConfig => 'Ouvrir la configuration';

  @override
  String get llmProviderSystemStatus => 'État du système';

  @override
  String get llmProviderPrimaryRuntime => 'Environnement d\'agent principal';

  @override
  String get llmProviderSupportProviders =>
      'Fournisseurs de modèles d\'appoint';

  @override
  String get llmProviderSupportProvidersSubtitle =>
      'Outils facultatifs comme Ollama ou LM Studio';

  @override
  String get visionSettingsTitle => 'Paramètres de vision';

  @override
  String get visionServiceStatus => 'État des services';

  @override
  String get visionMainService => 'Service de vision principal';

  @override
  String get visionRegionCaptureService => 'Service de capture de zone';

  @override
  String get visionCameraCaptureService => 'Service de capture caméra';

  @override
  String get visionOcrService => 'Service de reconnaissance de texte (OCR)';

  @override
  String get visionInitialized => 'Initialisé';

  @override
  String get visionNotInitialized => 'Non initialisé';

  @override
  String get visionCameraPreview => 'Aperçu de la caméra';

  @override
  String get visionCameraPreviewNote =>
      'Aperçu local seulement (v4l2/ffmpeg). Les images ne sont ni enregistrées ni envoyées.';

  @override
  String get visionTestResults => 'Résultats des tests';

  @override
  String get visionInitializeAll => 'Initialiser tous les services';

  @override
  String get visionInitializing => 'Initialisation des services…';

  @override
  String get visionInitComplete => 'Initialisation terminée';

  @override
  String visionInitFailed(String error) {
    return 'Échec de l\'initialisation : $error';
  }

  @override
  String visionResultInitialized(String service) {
    return '✅ $service : initialisé';
  }

  @override
  String visionResultError(String service, String error) {
    return '❌ $service : $error';
  }

  @override
  String visionLinuxCameraStarted(String device) {
    return '✅ Capture de la caméra Linux démarrée ($device)';
  }

  @override
  String visionLinuxCameraError(String error) {
    return '❌ Caméra Linux : $error';
  }

  @override
  String visionFatalError(String error) {
    return '❌ Erreur fatale : $error';
  }

  @override
  String get meshTitle => 'Maillage d\'appareils';

  @override
  String get meshRevokeTitle => 'Révoquer l\'appareil?';

  @override
  String meshRevokeBody(String device) {
    return 'Révoquer $device? L\'appareil devra s\'inscrire de nouveau pour se reconnecter.';
  }

  @override
  String get meshRevoke => 'Révoquer';

  @override
  String get meshRevoked => 'Appareil révoqué';

  @override
  String get meshRevokeFailed => 'Impossible de révoquer l\'appareil';

  @override
  String get meshThisDevice => 'Cet appareil';

  @override
  String get meshRegisteredDevices => 'Appareils inscrits';

  @override
  String get meshLoadFailed => 'Impossible de charger les appareils';

  @override
  String get meshNoDevices => 'Aucun autre appareil inscrit.';

  @override
  String get meshStatusConnected => 'Connecté au connecteur infonuagique';

  @override
  String get meshStatusConnecting => 'Connexion…';

  @override
  String get meshStatusError => 'Erreur de connexion';

  @override
  String get meshStatusDisconnected => 'Déconnecté';

  @override
  String get meshUnknownPlatform => 'plateforme inconnue';

  @override
  String get meshNever => 'jamais';

  @override
  String get meshOnline => 'en ligne';

  @override
  String meshLastSeen(String time) {
    return 'dernière connexion : $time';
  }

  @override
  String get meshRuntimeAvailable => 'environnement d\'exécution disponible';

  @override
  String get commonConnected => 'Connecté';

  @override
  String get commonDisconnected => 'Déconnecté';

  @override
  String get connectionSettingsTitle => 'Paramètres de connexion';

  @override
  String get connectionHeading => 'Connexion';

  @override
  String get connectionDescription =>
      'Gérer les connexions du tunnel et du service d\'arrière-plan.';

  @override
  String get connectionDaemonSettings => 'Service d\'arrière-plan';

  @override
  String get connectionDaemonSubtitle =>
      'Configurer le service de la zone de notification';

  @override
  String get connectionDeviceMeshSubtitle =>
      'Appareils inscrits et présence infonuagique';

  @override
  String get connectionStatusTitle => 'État de la connexion';

  @override
  String get connectionStatusSubtitle => 'Voir l\'état actuel de la connexion';

  @override
  String get connectionRerunWizard => 'Relancer l\'assistant de configuration';

  @override
  String get connectionRerunWizardSubtitle =>
      'Reconfigurer la connexion à la passerelle';

  @override
  String get connectionRerunWizardBody =>
      'Cela effacera votre configuration enregistrée et relancera l\'assistant de configuration. Vous devrez reconfigurer la connexion à votre passerelle.\n\nContinuer?';

  @override
  String get connectionClearAndRerun => 'Effacer et relancer';

  @override
  String connectionClearFailed(String error) {
    return 'Impossible d\'effacer les données de configuration : $error';
  }

  @override
  String get daemonSettingsTitle => 'Service de la zone de notification';

  @override
  String get daemonHeading => 'Configuration de la zone de notification';

  @override
  String get daemonDescription =>
      'Configurer le comportement et l\'apparence du service de la zone de notification';

  @override
  String get daemonSaved => 'Paramètres du service enregistrés avec succès';

  @override
  String daemonSaveFailed(String error) {
    return 'Impossible d\'enregistrer les paramètres : $error';
  }

  @override
  String get daemonRestarting =>
      'Redémarrage du service de la zone de notification…';

  @override
  String get daemonRestarted =>
      'Service de la zone de notification redémarré avec succès';

  @override
  String daemonRestartFailed(String error) {
    return 'Impossible de redémarrer le service : $error';
  }

  @override
  String get daemonRealtimeStatus => 'État de la connexion en temps réel';

  @override
  String get daemonConnectionType => 'Type de connexion';

  @override
  String get daemonVersion => 'Version';

  @override
  String get daemonAvailableModels => 'Modèles disponibles';

  @override
  String daemonModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles',
      one: '$count modèle',
    );
    return '$_temp0';
  }

  @override
  String get daemonError => 'Erreur';

  @override
  String daemonLastUpdated(String time) {
    return 'Dernière mise à jour : $time';
  }

  @override
  String get daemonLoadingStatus => 'Chargement de l\'état de la connexion…';

  @override
  String get daemonEnableTray => 'Activer la zone de notification';

  @override
  String get daemonStartMinimized => 'Démarrer réduit';

  @override
  String get daemonStartMinimizedSubtitle =>
      'Démarrer l\'application réduite dans la zone de notification';

  @override
  String get daemonEnableNotifications => 'Activer les notifications';

  @override
  String get daemonEnableNotificationsSubtitle =>
      'Afficher des notifications système pour les événements importants';

  @override
  String get daemonAutoStart => 'Démarrage automatique du service';

  @override
  String get daemonAutoStartSubtitle =>
      'Démarrer automatiquement le service avec l\'ordinateur';

  @override
  String get daemonTrayIconTheme => 'Style de l\'icône';

  @override
  String get daemonTrayIconThemeSubtitle =>
      'Choisir le style de l\'icône dans la zone de notification';

  @override
  String get themeMonochrome => 'Monochrome';

  @override
  String get daemonConnectionTimeout => 'Délai de connexion';

  @override
  String get daemonConnectionTimeoutSubtitle =>
      'Délai d\'attente des connexions au service (secondes)';

  @override
  String get daemonHealthCheckInterval => 'Intervalle de vérification';

  @override
  String get daemonHealthCheckIntervalSubtitle =>
      'Intervalle entre les vérifications de l\'état du service (secondes)';

  @override
  String get daemonActions => 'Actions';

  @override
  String get daemonSaveSettings => 'Enregistrer les paramètres';

  @override
  String get daemonRestart => 'Redémarrer le service';
}
