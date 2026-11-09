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

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonClear => 'Effacer';

  @override
  String commonErrorDetails(String error) {
    return 'Erreur : $error';
  }

  @override
  String get nodesTitle => 'Nœuds';

  @override
  String get nodesAgentRuntimes => 'Environnements d\'agents';

  @override
  String get nodesNoAgentRuntimes => 'Aucun environnement d\'agent détecté';

  @override
  String get nodesSupportProviders => 'Fournisseurs de modèles d\'appoint';

  @override
  String get nodesNoSupportProviders =>
      'Aucun fournisseur de modèles d\'appoint détecté';

  @override
  String get nodesTailscaleDevices => 'Appareils Tailscale';

  @override
  String get nodesNoTailscaleDevices => 'Aucun appareil Tailscale détecté';

  @override
  String nodesLoadError(String error) {
    return 'Impossible de charger les données de découverte : $error';
  }

  @override
  String nodesSelectedRuntime(String name, String version) {
    return 'Environnement d\'agent : $name ($version)';
  }

  @override
  String get nodesVersionUnknown => 'version inconnue';

  @override
  String get nodesNoRuntimeSelected =>
      'Aucun environnement d\'agent sélectionné';

  @override
  String get channelDetailsTitle => 'Détails du canal';

  @override
  String get channelNotFound => 'Canal introuvable';

  @override
  String get channelBadgeNew => 'Nouveau';

  @override
  String get channelBadgeRead => 'Lu';

  @override
  String get channelStatistics => 'Statistiques';

  @override
  String get channelMessages => 'Messages';

  @override
  String get channelPlatform => 'Plateforme';

  @override
  String get channelPlatformUnknown => 'Inconnue';

  @override
  String get channelLastActivity => 'Dernière activité';

  @override
  String get channelNever => 'Jamais';

  @override
  String get channelControls => 'Commandes';

  @override
  String get channelStart => 'Démarrer le canal';

  @override
  String get channelStop => 'Arrêter le canal';

  @override
  String get channelReconnect => 'Reconnecter';

  @override
  String get channelViewLogs => 'Voir les journaux';

  @override
  String channelActionPerformed(String action, String channelId) {
    return 'Action $action effectuée pour le canal $channelId';
  }

  @override
  String get channelJustNow => 'À l\'instant';

  @override
  String channelMinutesAgo(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String channelHoursAgo(int hours) {
    return 'il y a $hours h';
  }

  @override
  String channelDaysAgo(int days) {
    return 'il y a $days j';
  }

  @override
  String get usageTitle => 'Utilisation';

  @override
  String get usageToday => 'Aujourd\'hui';

  @override
  String get usageWeek => 'Semaine';

  @override
  String get usageMonth => 'Mois';

  @override
  String get usageActiveConcurrency => 'Requêtes simultanées actives';

  @override
  String usageOfLimit(int limit) {
    return 'sur $limit';
  }

  @override
  String get usageConcurrencySubtitle => 'Requêtes en cours de traitement';

  @override
  String get usageConcurrencyUtilization => 'Utilisation de la simultanéité';

  @override
  String get usageRequestRate => 'Débit de requêtes';

  @override
  String get usageRequestsPerMinuteUnit => 'req./min';

  @override
  String get usageRequestRateSubtitle =>
      'Requêtes par minute, tous modèles confondus';

  @override
  String get usageRpmUtilization => 'Utilisation des requêtes par minute';

  @override
  String get usageTokenRate => 'Débit de jetons';

  @override
  String get usageTokensPerMinuteUnit => 'jetons/min';

  @override
  String get usageTokenRateSubtitle =>
      'Jetons par minute, tous modèles confondus';

  @override
  String get usageTpmUtilization => 'Utilisation des jetons par minute';

  @override
  String get usageChartTokenUsage => 'Utilisation des jetons dans le temps';

  @override
  String get usageChartRequestVolume => 'Volume de requêtes';

  @override
  String get usageChartResourceTrends => 'Tendances des ressources';

  @override
  String get usageChartPlaceholder => 'Graphique à venir';

  @override
  String get usageNoActiveModels => 'Aucun modèle actif';

  @override
  String get usagePerModelConcurrency => 'Simultanéité par modèle';

  @override
  String get usageNoRateData => 'Aucune donnée de débit';

  @override
  String get usageTopModelsByRpm =>
      'Modèles les plus sollicités (requêtes/min)';

  @override
  String get usageNoTokenData => 'Aucune donnée de jetons';

  @override
  String get usageTopModelsByTpm => 'Modèles les plus sollicités (jetons/min)';

  @override
  String get logsTitle => 'Journaux';

  @override
  String get logsExport => 'Exporter les journaux';

  @override
  String get logsServiceUnavailable => 'Service de journalisation indisponible';

  @override
  String logsExportedTo(String path) {
    return 'Journaux exportés vers $path';
  }

  @override
  String get logsCopied => 'Journaux copiés dans le presse-papiers';

  @override
  String get logsNoneFound => 'Aucune entrée de journal trouvée';

  @override
  String get logsAdjustFilters => 'Essayez de modifier vos filtres';

  @override
  String get logsNoneAvailable => 'Aucune entrée de journal disponible';

  @override
  String get logsSearchHint => 'Rechercher dans les journaux…';

  @override
  String get logsSeverity => 'Gravité';

  @override
  String get logsSource => 'Source';

  @override
  String get logsClearAll => 'Tout effacer';

  @override
  String get logsViewDetails => 'Voir les détails';

  @override
  String get logsDetailsTitle => 'Détails de l\'entrée';

  @override
  String get logsTimestamp => 'Horodatage';

  @override
  String get logsMessage => 'Message';

  @override
  String get logsError => 'Erreur';

  @override
  String get logsStackTrace => 'Pile d\'appels';

  @override
  String get logsFilterBySource => 'Filtrer par source';

  @override
  String logsDetailLabel(String label) {
    return '$label :';
  }
}
