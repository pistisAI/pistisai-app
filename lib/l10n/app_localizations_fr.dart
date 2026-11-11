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

  @override
  String get commonRemove => 'Retirer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonUnknownError => 'Erreur inconnue';

  @override
  String commonFieldLabel(String label) {
    return '$label :';
  }

  @override
  String get commonStatus => 'État';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonName => 'Nom';

  @override
  String get commonType => 'Type';

  @override
  String get commonMessages => 'Messages';

  @override
  String get commonNever => 'Jamais';

  @override
  String get timeJustNow => 'À l\'instant';

  @override
  String timeSecondsAgo(int seconds) {
    return 'il y a $seconds s';
  }

  @override
  String timeMinutesAgo(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String timeHoursAgo(int hours) {
    return 'il y a $hours h';
  }

  @override
  String timeDaysAgo(int days) {
    return 'il y a $days j';
  }

  @override
  String get agentsTitle => 'Agents';

  @override
  String get agentsAdd => 'Ajouter un agent';

  @override
  String get agentsTabRegistry => 'Registre';

  @override
  String get agentsTabMonitor => 'Suivi';

  @override
  String get agentsTabConfig => 'Configuration';

  @override
  String get agentsEmptyTitle => 'Aucun agent enregistré';

  @override
  String get agentsEmptyMessage =>
      'Les agents apparaîtront ici une fois enregistrés';

  @override
  String get agentsNoTask => 'Aucune tâche assignée';

  @override
  String agentsActivityCompleted(String task) {
    return 'Terminé : $task';
  }

  @override
  String agentsActivityFailed(String error) {
    return 'Échec : $error';
  }

  @override
  String agentsActivityStarted(String task) {
    return 'Démarré : $task';
  }

  @override
  String get agentsActivityTaskFallback => 'tâche';

  @override
  String get agentsActivityErrorFallback => 'erreur inconnue';

  @override
  String get agentsRegistryUnavailable =>
      'Le registre des agents n\'est pas disponible tant que le serveur API n\'est pas connecté';

  @override
  String get agentsRegisterFailed => 'Impossible d\'enregistrer l\'agent';

  @override
  String agentsRegistered(String name) {
    return '$name enregistré';
  }

  @override
  String agentsEditTitle(String name) {
    return 'Modifier $name';
  }

  @override
  String agentsUpdateFailed(String name) {
    return 'Impossible de mettre à jour $name';
  }

  @override
  String agentsUpdated(String name) {
    return '$name mis à jour';
  }

  @override
  String agentsRemoveFailed(String name) {
    return 'Impossible de retirer $name';
  }

  @override
  String agentsRemoved(String name) {
    return '$name retiré';
  }

  @override
  String get agentsStatTasks => 'Tâches';

  @override
  String get agentsStatAvgLatency => 'Latence moyenne';

  @override
  String get agentsStatLastActive => 'Dernière activité';

  @override
  String get agentsStatusOnline => 'EN LIGNE';

  @override
  String get agentsStatusBusy => 'OCCUPÉ';

  @override
  String get agentsStatusOffline => 'HORS LIGNE';

  @override
  String get agentsStatusError => 'ERREUR';

  @override
  String get agentsTotal => 'Agents au total';

  @override
  String get agentsTasksToday => 'Tâches aujourd\'hui';

  @override
  String get agentsErrors => 'Erreurs';

  @override
  String get agentsNoActivityTitle => 'Aucune activité récente';

  @override
  String get agentsNoActivityMessage => 'L\'activité des agents apparaîtra ici';

  @override
  String get agentsPoolSettings => 'Réglages du groupe d\'agents';

  @override
  String get agentsAutoScale => 'Ajuster automatiquement le nombre d\'agents';

  @override
  String get agentsAutoScaleSubtitle =>
      'Ajouter des agents automatiquement selon la charge';

  @override
  String get agentsMin => 'Agents minimum';

  @override
  String get agentsMinSubtitle => 'Nombre minimal d\'agents actifs';

  @override
  String get agentsMax => 'Agents maximum';

  @override
  String get agentsMaxSubtitle => 'Nombre maximal d\'agents simultanés';

  @override
  String get agentsTimeoutSettings => 'Délais d\'attente';

  @override
  String get agentsRequestTimeout => 'Délai de requête';

  @override
  String get agentsRequestTimeoutSubtitle =>
      'Temps maximal d\'attente d\'une réponse de l\'agent';

  @override
  String get agentsQueueTimeout => 'Délai en file d\'attente';

  @override
  String get agentsQueueTimeoutSubtitle =>
      'Temps maximal en file d\'attente avant le refus';

  @override
  String get agentsPause => 'Mettre l\'agent en pause';

  @override
  String get agentsResume => 'Reprendre l\'agent';

  @override
  String get agentsRestart => 'Redémarrer l\'agent';

  @override
  String get agentsEditConfig => 'Modifier la configuration';

  @override
  String get agentsRemove => 'Retirer l\'agent';

  @override
  String agentsRemoveConfirm(String name) {
    return 'Voulez-vous vraiment retirer $name ?';
  }

  @override
  String get agentsRegisterTitle => 'Enregistrer un agent';

  @override
  String get agentsRegister => 'Enregistrer';

  @override
  String get agentsIdsRequired =>
      'L\'identifiant du sous-agent et celui de l\'agent parent sont obligatoires';

  @override
  String get agentsSubagentId => 'Identifiant du sous-agent';

  @override
  String get agentsParentId => 'Identifiant de l\'agent parent';

  @override
  String get agentsDisplayLabel => 'Nom affiché';

  @override
  String get agentsTaskDescription => 'Description de la tâche';

  @override
  String get agentDetailTitle => 'Détails de l\'agent';

  @override
  String get agentDetailNotFound => 'Agent introuvable';

  @override
  String agentDetailIdValue(String id) {
    return 'Identifiant : $id';
  }

  @override
  String get agentDetailActivity => 'Activité';

  @override
  String get agentDetailLastUpdate => 'Dernière mise à jour';

  @override
  String get agentDetailStart => 'Démarrer';

  @override
  String get agentDetailStop => 'Arrêter';

  @override
  String get agentDetailRestart => 'Redémarrer';

  @override
  String get agentDetailInformation => 'Informations';

  @override
  String get agentDetailId => 'Identifiant';

  @override
  String get agentStateIdle => 'Inactif';

  @override
  String get agentStateStarting => 'Démarrage…';

  @override
  String get agentStateRunning => 'En cours';

  @override
  String get agentStateStopping => 'Arrêt…';

  @override
  String get agentStateError => 'Erreur';

  @override
  String get agentStateOffline => 'Hors ligne';

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionsTabWebSocket => 'WebSocket';

  @override
  String get sessionsTabConversations => 'Conversations';

  @override
  String get sessionsTabUsers => 'Utilisateurs';

  @override
  String get sessionsRefresh => 'Actualiser les sessions';

  @override
  String get sessionsEmptyTitle => 'Aucune session';

  @override
  String get sessionsEmptyMessage =>
      'Aucune session active dans cette catégorie.';

  @override
  String get sessionsDetailsTitle => 'Détails de la session';

  @override
  String get sessionsId => 'Identifiant de session';

  @override
  String get sessionsUserOrAgent => 'Utilisateur ou agent';

  @override
  String get sessionsStarted => 'Début';

  @override
  String get sessionsDuration => 'Durée';

  @override
  String get sessionsTokens => 'Jetons';

  @override
  String sessionsDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String sessionsDurationMinutesSeconds(int minutes, int seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String sessionsDurationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get sessionsTerminateTitle => 'Mettre fin à la session';

  @override
  String sessionsTerminateConfirm(String id, String who) {
    return 'Voulez-vous vraiment mettre fin à la session $id ?\n\n$who sera déconnecté. Cette action est irréversible.';
  }

  @override
  String get sessionsServiceUnavailable => 'Service des sessions indisponible';

  @override
  String sessionsTerminated(String id) {
    return 'Session $id terminée';
  }

  @override
  String sessionsTerminateFailed(String id) {
    return 'Impossible de mettre fin à la session $id';
  }

  @override
  String get sessionsTerminate => 'Mettre fin';

  @override
  String get sessionsViewDetails => 'Voir les détails';

  @override
  String get sessionsTerminateTooltip => 'Mettre fin à la session';

  @override
  String get channelsTitle => 'Canaux';

  @override
  String get channelsRefresh => 'Actualiser les canaux';

  @override
  String channelsLoadError(String error) {
    return 'Impossible de charger les canaux : $error';
  }

  @override
  String get channelsEmptyTitle => 'Aucun canal';

  @override
  String get channelsEmptyMessage =>
      'Aucun canal de communication n\'est disponible pour le moment.';

  @override
  String channelsMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '$count message',
    );
    return '$_temp0';
  }

  @override
  String get homeSettings => 'Paramètres';

  @override
  String get homeNoAgentTitle => 'Aucun agent connecté';

  @override
  String get homeNoAgentBanner =>
      'Configurez un environnement d\'agent dans les Paramètres pour activer les réponses de l\'IA et le contrôle de l\'ordinateur.';

  @override
  String get homeStatusConfigured => 'Configuré';

  @override
  String get homeStatusOffline => 'Hors ligne';

  @override
  String get homeNoAgentStandalone =>
      'Configurez un environnement d\'agent dans les Paramètres pour commencer, ou utilisez l\'avatar et les fonctions locales hors ligne.';

  @override
  String get homeOpenSettings => 'Ouvrir les paramètres';

  @override
  String get homeConfigureManually => 'Configurer la connexion manuellement';

  @override
  String homeMessagePlaceholder(String name) {
    return 'Écrire à $name…';
  }

  @override
  String get homePillarAvatar => 'Avatar';

  @override
  String get homePillarTools => 'Outils';

  @override
  String get homePillarMood => 'Humeur';

  @override
  String homeMoodTitle(String possessive, String name) {
    return 'Humeur de l\'agent $name';
  }

  @override
  String get homeMoodNotReady =>
      'Le moteur de personnalité n\'est pas encore prêt.';

  @override
  String homeMoodAgent(String name) {
    return 'Agent : $name';
  }

  @override
  String get homeTraitFormality => 'Formalité';

  @override
  String get homeTraitHumor => 'Humour';

  @override
  String get homeTraitEnthusiasm => 'Enthousiasme';

  @override
  String get homeTraitEmpathy => 'Empathie';

  @override
  String homeMoodEvolution(String stage) {
    return 'Évolution : $stage';
  }

  @override
  String homeToolsTitle(String name) {
    return 'Ce que l\'agent $name peut faire';
  }

  @override
  String get homeToolsSubtitle =>
      'Disponible hors ligne • Connectez-vous pour en débloquer davantage';

  @override
  String get homeToolDesktop => 'Contrôle de l\'ordinateur';

  @override
  String get homeToolDesktopDescription =>
      'Cliquer, taper, faire défiler et glisser sur votre ordinateur';

  @override
  String get homeToolVision => 'Vision';

  @override
  String get homeToolVisionDescription => 'Voir et analyser votre écran';

  @override
  String get homeToolVoice => 'Voix';

  @override
  String get homeToolVoiceDescription => 'Parler et écouter';

  @override
  String get homeToolWebSearch => 'Recherche web';

  @override
  String get homeToolWebSearchDescription =>
      'Chercher et extraire du contenu web';

  @override
  String get homeToolRequiresAgent => 'Nécessite la connexion d\'un agent';

  @override
  String get homeToolCode => 'Exécution de code';

  @override
  String get homeToolCodeDescription =>
      'Exécuter des scripts Python, shell et Dart';

  @override
  String get homeToolLocal => 'local';

  @override
  String get homeToolCloud => 'nuage';

  @override
  String get welcomeSubtitle =>
      'Votre compagnon d\'agent.\nEntièrement hors ligne jusqu\'à ce que vous décidiez de vous connecter.';

  @override
  String get welcomeHint =>
      'Écrivez un message ci-dessous ou tapez /new pour repartir de zéro. Connectez un environnement d\'agent dans les Paramètres pour obtenir les réponses de l\'IA et les fonctions d\'agent.';

  @override
  String get messageInputPlaceholder => 'Écrivez votre message…';

  @override
  String get messageInputNewChat => 'Nouvelle conversation';

  @override
  String get messageInputNoModels => 'Aucun modèle disponible';

  @override
  String get messageInputSelectModel => 'Choisir un modèle';

  @override
  String get messageCopied => 'Copié dans le presse-papiers';

  @override
  String get commonStart => 'Démarrer';

  @override
  String get commonStop => 'Arrêter';

  @override
  String get commonRestart => 'Redémarrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonCreate => 'Créer';

  @override
  String get commonEnable => 'Activer';

  @override
  String get commonDisable => 'Désactiver';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonCategory => 'Catégorie';

  @override
  String get commonApply => 'Appliquer';

  @override
  String get cronTitle => 'Tâches planifiées';

  @override
  String get cronAddJob => 'Ajouter une tâche';

  @override
  String get cronEmptyTitle => 'Aucune tâche planifiée';

  @override
  String get cronEmptyMessage =>
      'Créez des tâches planifiées pour automatiser l\'entretien';

  @override
  String cronTriggered(String name) {
    return 'Lancée : $name';
  }

  @override
  String get cronDeleteTitle => 'Supprimer la tâche planifiée';

  @override
  String cronDeleteConfirm(String name) {
    return 'Voulez-vous vraiment supprimer « $name » ? Cette action est irréversible.';
  }

  @override
  String get cronDeleted => 'Tâche supprimée';

  @override
  String get cronDeleteFailed => 'Impossible de supprimer la tâche';

  @override
  String get cronEditTitle => 'Modifier la tâche planifiée';

  @override
  String get cronCreateTitle => 'Créer une tâche planifiée';

  @override
  String get cronJobName => 'Nom de la tâche';

  @override
  String get cronJobNameHint => 'ex. : Résumé quotidien';

  @override
  String get cronJobNameRequired => 'Entrez un nom de tâche';

  @override
  String get cronSchedule => 'Expression de planification ou intervalle';

  @override
  String get cronScheduleHint => 'ex. : 30m, every 2h ou 0 9 * * *';

  @override
  String get cronScheduleRequired => 'Entrez une planification';

  @override
  String get cronExecutionMode => 'Mode d\'exécution';

  @override
  String get cronModeAgent => 'Agent IA';

  @override
  String get cronModeScript => 'Script seulement (surveillance)';

  @override
  String get cronPrompt => 'Consigne pour l\'agent';

  @override
  String get cronPromptHint =>
      'Décrivez la tâche que l\'agent doit effectuer régulièrement…';

  @override
  String get cronPromptRequired => 'Entrez une consigne ou joignez un script';

  @override
  String get cronScriptRequiredLabel => 'Fichier de script (obligatoire)';

  @override
  String get cronScriptOptionalLabel => 'Fichier de script (facultatif)';

  @override
  String get cronScriptHint => 'ex. : backup-vault.sh';

  @override
  String get cronScriptHelper =>
      'Les scripts doivent se trouver dans ~/.hermes/scripts/';

  @override
  String get cronScriptRequired =>
      'Un fichier de script est obligatoire en mode surveillance';

  @override
  String get cronWorkdir => 'Dossier de travail (facultatif)';

  @override
  String get cronWorkdirHint => 'Chemin absolu du dossier du projet';

  @override
  String get cronWorkdirHelper =>
      'Ajoute le contexte AGENTS.md/CLAUDE.md du projet';

  @override
  String get cronUpdated => 'Tâche mise à jour';

  @override
  String get cronCreated => 'Tâche créée';

  @override
  String get cronSaveFailed => 'Impossible d\'enregistrer la tâche planifiée';

  @override
  String get cronScheduleLabel => 'Planification';

  @override
  String get cronNextRun => 'Prochaine exécution';

  @override
  String get cronLastRun => 'Dernière exécution';

  @override
  String get cronMode => 'Mode';

  @override
  String get cronModeWatchdog => 'Surveillance (sans agent)';

  @override
  String get cronWorkdirLabel => 'Dossier de travail';

  @override
  String get cronRunNow => 'Exécuter maintenant';

  @override
  String get skillsTitle => 'Compétences';

  @override
  String get skillsRegisterTitle => 'Enregistrer une compétence';

  @override
  String get skillsTabRegistry => 'Registre';

  @override
  String get skillsTabUsage => 'Utilisation';

  @override
  String get skillsTabManagement => 'Gestion';

  @override
  String get skillsEmptyTitle => 'Aucune compétence enregistrée';

  @override
  String get skillsEmptyMessage =>
      'Les compétences apparaîtront ici une fois enregistrées';

  @override
  String get skillsServiceUnavailable =>
      'Le service des compétences n\'est pas disponible sur cette plateforme';

  @override
  String skillsRegistered(String name) {
    return 'Compétence $name enregistrée';
  }

  @override
  String skillsRegisterFailed(String error) {
    return 'Impossible d\'enregistrer la compétence : $error';
  }

  @override
  String skillsEnabled(String name) {
    return '$name activée';
  }

  @override
  String skillsDisabled(String name) {
    return '$name désactivée';
  }

  @override
  String get skillsStatUses => 'Utilisations';

  @override
  String get skillsStatAvgTime => 'Temps moyen';

  @override
  String get skillsStatLastUsed => 'Dernière utilisation';

  @override
  String get skillsUsageByCategory =>
      'Utilisation des compétences par catégorie';

  @override
  String skillsUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utilisations',
      one: '$count utilisation',
    );
    return '$_temp0';
  }

  @override
  String skillsAvgSeconds(String seconds) {
    return '$seconds s en moyenne';
  }

  @override
  String get skillsTopPerforming => 'Compétences les plus performantes';

  @override
  String get skillsGlobalSettings => 'Réglages généraux';

  @override
  String get skillsAutoDisable =>
      'Désactiver automatiquement les compétences lentes';

  @override
  String get skillsAutoDisableSubtitle =>
      'Désactiver les compétences qui prennent plus de 5 secondes';

  @override
  String get skillsCache => 'Mettre en cache les résultats';

  @override
  String get skillsCacheSubtitle =>
      'Conserver les réponses aux requêtes identiques';

  @override
  String get skillsDefaultTimeout => 'Délai par défaut';

  @override
  String get skillsDefaultTimeoutValue => '30 secondes';

  @override
  String get skillsResourceLimits => 'Limites de ressources';

  @override
  String get skillsMaxConcurrent => 'Compétences simultanées maximum';

  @override
  String get skillsMaxConcurrentSubtitle =>
      'Nombre maximal de compétences exécutées en même temps';

  @override
  String get skillsMemory => 'Mémoire par compétence';

  @override
  String get skillsMemorySubtitle => 'Mémoire vive maximale par compétence';

  @override
  String get skillsNameDescriptionRequired =>
      'Le nom et la description sont obligatoires';

  @override
  String skillsCreatesUnder(String directory) {
    return 'Crée SKILL.md dans $directory';
  }

  @override
  String get instancesTitle => 'Instances';

  @override
  String get instancesRefresh => 'Actualiser les instances';

  @override
  String get instancesNotStarted => 'Non démarré';

  @override
  String instancesUptimeDaysHours(int days, int hours) {
    return '$days j $hours h';
  }

  @override
  String get instancesStartFailed => 'Impossible de démarrer la passerelle';

  @override
  String get instancesStopFailed => 'Impossible d\'arrêter la passerelle';

  @override
  String get instancesRestartFailed => 'Impossible de redémarrer la passerelle';

  @override
  String get instancesNoGatewayState => 'Aucun état de passerelle disponible';

  @override
  String get instancesGatewayProcess => 'Processus de la passerelle';

  @override
  String get instancesModelInstances => 'Instances de modèles';

  @override
  String instancesPort(String port) {
    return 'Port $port';
  }

  @override
  String instancesUptime(String uptime) {
    return 'Temps de fonctionnement : $uptime';
  }

  @override
  String get instancesRequests => 'Requêtes';

  @override
  String instancesUtilized(int percent) {
    return '$percent % utilisé';
  }

  @override
  String get instancesHermesEnabledSnack =>
      'Agent Hermes activé — la discussion passera par Hermes';

  @override
  String get instancesHermesDisabledSnack =>
      'Retour à la passerelle par défaut';

  @override
  String get instancesHermesTitle => '🦞 Agent Hermes';

  @override
  String get instancesHermesActive =>
      'Actif — la discussion passe par le serveur API Hermes';

  @override
  String get instancesHermesInactive =>
      'Désactivé — utilisation de la passerelle Hermes par défaut';

  @override
  String get instancesHermesEnable => 'Activer l\'agent Hermes';

  @override
  String get instancesHermesEnableSubtitle =>
      'Faire passer la discussion par Hermes pour les outils, les fichiers, la recherche web et l\'exécution de code';

  @override
  String get instancesHermesUrl => 'URL de l\'API Hermes';

  @override
  String get instancesApiKeyOptional => 'Clé API (facultative)';

  @override
  String get instancesApiKeyHint =>
      'Laisser vide pour un usage local seulement';

  @override
  String get instancesTestConnection => 'Tester la connexion';
}
