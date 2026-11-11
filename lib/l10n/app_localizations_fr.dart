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

  @override
  String get commonBack => 'Retour';

  @override
  String get commonReset => 'Réinitialiser';

  @override
  String get commonSelect => 'Choisir';

  @override
  String get avatarStateIdle => 'Au repos';

  @override
  String get avatarStateThinking => 'Réflexion';

  @override
  String get avatarStateWorking => 'Au travail';

  @override
  String get avatarStateHappy => 'Content';

  @override
  String get avatarSizeSmall => 'Petit';

  @override
  String get avatarSizeMedium => 'Moyen';

  @override
  String get avatarSizeLarge => 'Grand';

  @override
  String get avatarGlowEffect => 'Effet lumineux';

  @override
  String get avatarGlowSubtitle =>
      'Activer un halo lumineux pulsé autour de l\'avatar';

  @override
  String get avatarStageCuriousExplorer => 'Explorateur curieux';

  @override
  String get avatarStageCuriousExplorerInitial =>
      'Explorateur curieux (initial)';

  @override
  String get avatarStageKnowledgeSeeker => 'Chercheur de savoir';

  @override
  String get avatarStageWiseCompanion => 'Compagnon sage';

  @override
  String get avatarStageEnlightenedGuide => 'Guide éclairé';

  @override
  String get avatarSettingsTitle => 'Réglages de l\'avatar';

  @override
  String avatarInitFailed(String error) {
    return 'Impossible d\'initialiser le service d\'avatar : $error';
  }

  @override
  String get avatarSaved => 'Réglages de l\'avatar enregistrés';

  @override
  String avatarSaveFailed(String error) {
    return 'Impossible d\'enregistrer les réglages : $error';
  }

  @override
  String get avatarEvolutionReasonMissing =>
      'Indiquez la raison de l\'évolution';

  @override
  String avatarEvolutionApproved(String stage) {
    return 'Évolution vers le stade $stage approuvée ! Votre avatar a évolué.';
  }

  @override
  String avatarEvolutionDenied(String reason) {
    return 'Demande d\'évolution refusée : $reason';
  }

  @override
  String avatarEvolutionFailed(String error) {
    return 'Impossible de demander l\'évolution : $error';
  }

  @override
  String get avatarSaveSettings => 'Enregistrer les réglages';

  @override
  String get avatarLivePreview => 'Aperçu en direct';

  @override
  String avatarStageValue(String stage) {
    return 'Stade : $stage';
  }

  @override
  String get avatarConversations => 'Conversations';

  @override
  String get avatarDepthScore => 'Score de profondeur';

  @override
  String get avatarAgentName => 'Nom de l\'agent';

  @override
  String get avatarAgentNameHint => 'Entrez le nom de l\'agent';

  @override
  String get avatarAgentNameRequired => 'Entrez un nom d\'agent';

  @override
  String get avatarAgentNameTooShort =>
      'Le nom doit comporter au moins 2 caractères';

  @override
  String get avatarAgentNameTooLong =>
      'Le nom doit comporter moins de 50 caractères';

  @override
  String get avatarAgentNameHelp =>
      'Ce nom servira à vous adresser à votre avatar dans les conversations.';

  @override
  String get avatarPersonalityTraits => 'Traits de personnalité';

  @override
  String get avatarPersonalityHelp =>
      'Ajustez ces curseurs pour personnaliser la personnalité de votre avatar. Les changements apparaissent dans l\'aperçu ci-dessus.';

  @override
  String get avatarFormalityDescription => 'Le degré de formalité de l\'avatar';

  @override
  String get avatarHumorDescription => 'Fréquence et intensité de l\'humour';

  @override
  String get avatarEnthusiasmDescription =>
      'Niveau d\'énergie et d\'enthousiasme';

  @override
  String get avatarEmpathyDescription => 'Compréhension et soutien émotionnels';

  @override
  String get avatarAppearance => 'Apparence';

  @override
  String get avatarAppearanceHelp =>
      'Personnalisez le style visuel et l\'animation de votre avatar.';

  @override
  String get avatarColorTheme => 'Thème de couleur';

  @override
  String get avatarColorPersonality => 'Selon la personnalité';

  @override
  String get avatarColorOceanBlue => 'Bleu océan';

  @override
  String get avatarColorForestGreen => 'Vert forêt';

  @override
  String get avatarColorSunsetOrange => 'Orange coucher de soleil';

  @override
  String get avatarColorRoyalPurple => 'Violet royal';

  @override
  String get avatarColorMonochrome => 'Monochrome';

  @override
  String get avatarAnimationStyle => 'Style d\'animation';

  @override
  String get avatarAnimationBounce => 'Rebond';

  @override
  String get avatarAnimationPulse => 'Pulsation';

  @override
  String get avatarAnimationFloat => 'Flottement';

  @override
  String get avatarAnimationShake => 'Secousse';

  @override
  String get avatarAnimationNone => 'Aucune (statique)';

  @override
  String get avatarSize => 'Taille de l\'avatar';

  @override
  String get avatarAdvancedTitle => 'Personnalisation visuelle avancée';

  @override
  String get avatarAdvancedHelp =>
      'Ajustez la couleur, le type et les effets de votre avatar dans l\'écran de personnalisation.';

  @override
  String get avatarOpenAdvanced => 'Ouvrir la personnalisation avancée';

  @override
  String get avatarAchievements => 'Succès';

  @override
  String get avatarAchievementsHelp =>
      'Consultez vos succès débloqués et suivez votre progression.';

  @override
  String get avatarViewAchievements => 'Voir les succès';

  @override
  String get avatarEvolution => 'Évolution';

  @override
  String get avatarEvolutionHelp =>
      'Faites évoluer votre avatar pour débloquer de nouvelles capacités de personnalité.';

  @override
  String get avatarCurrentStage => 'Stade actuel :';

  @override
  String get avatarEvolveTo => 'Évoluer vers le stade';

  @override
  String get avatarEvolutionReason => 'Raison de l\'évolution';

  @override
  String get avatarEvolutionReasonHint =>
      'Expliquez pourquoi vous voulez faire évoluer votre avatar…';

  @override
  String get avatarEvolutionReasonRequired => 'Indiquez une raison';

  @override
  String get avatarRequesting => 'Demande en cours…';

  @override
  String get avatarRequestEvolution => 'Demander l\'évolution';

  @override
  String get avatarReadyToEvolve => 'Prêt à évoluer !';

  @override
  String get avatarEvolutionRequirements => 'Conditions d\'évolution';

  @override
  String get avatarDeepConversations => 'Conversations approfondies';

  @override
  String get avatarAverageNovelty => 'Nouveauté moyenne';

  @override
  String avatarRequirementPercent(int current, int required) {
    return '$current % / $required %';
  }

  @override
  String get avatarCustomizationTitle => 'Personnalisation de l\'avatar';

  @override
  String get avatarCustomizationSaved =>
      'Personnalisation de l\'avatar enregistrée';

  @override
  String get avatarResetTitle => 'Rétablir les valeurs par défaut';

  @override
  String get avatarResetConfirm =>
      'Voulez-vous vraiment rétablir tous les réglages de l\'avatar par défaut ?';

  @override
  String get avatarResetDone => 'Réglages de l\'avatar rétablis par défaut';

  @override
  String get avatarResetTooltip => 'Rétablir les valeurs par défaut';

  @override
  String get avatarSaveCustomization => 'Enregistrer la personnalisation';

  @override
  String get avatarPreview => 'Aperçu de l\'avatar';

  @override
  String get avatarType => 'Type d\'avatar';

  @override
  String get avatarTypeEmoji => 'Émoji';

  @override
  String get avatarColor => 'Couleur de l\'avatar';

  @override
  String get avatarCustomColorSelected => 'Couleur personnalisée choisie';

  @override
  String get avatarUsingPersonalityColors => 'Couleurs selon la personnalité';

  @override
  String get avatarPickColor => 'Choisir une couleur';

  @override
  String get avatarUsePersonalityColors =>
      'Utiliser les couleurs de la personnalité';

  @override
  String get avatarPickColorTitle => 'Choisir la couleur de l\'avatar';

  @override
  String get achievementsTitle => 'Succès';

  @override
  String achievementsLoadFailed(String error) {
    return 'Impossible de charger les succès : $error';
  }

  @override
  String get achievementsUnlockedSection => 'Débloqués';

  @override
  String get achievementsLockedSection => 'Verrouillés';

  @override
  String get achievementsNoneUnlocked =>
      'Aucun succès débloqué pour l\'instant. Commencez à discuter !';

  @override
  String get achievementsProgress => 'Progression des succès';

  @override
  String achievementsUnlockedCount(int unlocked, int total) {
    return '$unlocked sur $total débloqués';
  }

  @override
  String achievementsPercent(int percent) {
    return '$percent %';
  }

  @override
  String achievementsUnlockedWhen(String when) {
    return 'Débloqué $when';
  }

  @override
  String get achievementsToday => 'aujourd\'hui';

  @override
  String get achievementsYesterday => 'hier';

  @override
  String get achievementFirstChat => 'Première conversation';

  @override
  String get achievementFirstChatDescription =>
      'Terminez votre première conversation avec l\'avatar';

  @override
  String get achievementGettingToKnow => 'Faire connaissance';

  @override
  String get achievementDeepThinker => 'Penseur profond';

  @override
  String get achievementConversationalMaster => 'Maître de la conversation';

  @override
  String achievementDeepConversationsDescription(int count) {
    return 'Avoir $count conversations approfondies';
  }

  @override
  String get achievementNoveltySeeker => 'Chercheur de nouveauté';

  @override
  String get achievementNoveltySeekerDescription =>
      'Maintenir une grande nouveauté dans les conversations (60 % ou plus)';

  @override
  String achievementEvolveDescription(String stage) {
    return 'Faire évoluer votre avatar jusqu\'au stade $stage';
  }

  @override
  String get configPageGeneral => 'Général';

  @override
  String get configPageGeneralSubtitle => 'Préférences de l\'application';

  @override
  String get configPageAppearance => 'Apparence';

  @override
  String get configPageAppearanceSubtitle => 'Thème et apparence';

  @override
  String get configPageConnection => 'Connexion';

  @override
  String get configPageConnectionSubtitle => 'Service, maillage et compte';

  @override
  String get configPageLlm => 'Fournisseurs de modèles';

  @override
  String get configPageLlmSubtitle => 'Réglages des fournisseurs de modèles';

  @override
  String get configPageVision => 'Vision';

  @override
  String get configPageVisionSubtitle => 'Outils d\'écran et de vision';

  @override
  String get configPageAvatar => 'Avatar';

  @override
  String get configPageAvatarSubtitle => 'Apparence du compagnon';

  @override
  String get configPageAchievements => 'Succès';

  @override
  String get configPageAchievementsSubtitle => 'Étapes franchies par l\'avatar';

  @override
  String get configPageDesktop => 'Bureau';

  @override
  String get configPageDesktopSubtitle => 'Outils locaux de l\'ordinateur';

  @override
  String get configPageAbout => 'À propos';

  @override
  String get configPagePlans => 'Forfaits';

  @override
  String get configPagePlansSubtitle => 'Options d\'abonnement';

  @override
  String get configPageBrain => 'Analyse du cerveau local';

  @override
  String get configPageBrainSubtitle => 'Activité du cerveau local';

  @override
  String get configPageRoadmap => 'Feuille de route';

  @override
  String get configPageRoadmapSubtitle => 'Ce qui est en cours';

  @override
  String get configTitle => 'Réglages de l\'environnement';

  @override
  String get configBackToChannel => 'Retour au canal de l\'environnement';

  @override
  String get configTabRuntime => 'Environnement';

  @override
  String get configTabMesh => 'Maillage';

  @override
  String get configTabApp => 'Application';

  @override
  String get configTabStorage => 'Stockage';

  @override
  String get configTabSystem => 'Système';

  @override
  String configLoadFailed(String error) {
    return 'Impossible de charger la configuration : $error';
  }

  @override
  String get configSaved => 'Configuration enregistrée';

  @override
  String configSaveFailed(String error) {
    return 'Impossible d\'enregistrer la configuration : $error';
  }

  @override
  String get configResetTitle => 'Rétablir les valeurs par défaut';

  @override
  String get configResetBody =>
      'Les préférences de l\'environnement (thème, langue, délais, proxy, options de développement) reprennent leurs valeurs par défaut.\n\nLes URL de passerelle, les clés API et les réglages de l\'avatar ne sont pas touchés.';

  @override
  String get configResetDone => 'Configuration rétablie par défaut';

  @override
  String configResetFailed(String error) {
    return 'Impossible de rétablir la configuration : $error';
  }

  @override
  String configExported(String filename) {
    return 'Réglages exportés vers $filename';
  }

  @override
  String configExportFailed(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String get configImported => 'Réglages importés';

  @override
  String configImportFailed(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get configRuntimeNone => 'Aucun';

  @override
  String get configActiveRuntime => 'Environnement d\'agent actif';

  @override
  String configSecureChannelRuntime(String runtime) {
    return 'Environnement du canal sécurisé : $runtime';
  }

  @override
  String get configNoRuntime =>
      'Aucun environnement sélectionné — choisissez-en un ci-dessous';

  @override
  String get configAgentRuntime => 'Environnement d\'agent';

  @override
  String get configAgentRuntimeHelper =>
      'Choisissez l\'environnement utilisé par le canal sécurisé';

  @override
  String configRuntimeSet(String runtime) {
    return 'Environnement actif : $runtime';
  }

  @override
  String get configRuntimeCleared => 'Environnement retiré';

  @override
  String get configSupportProviders => 'Fournisseurs de modèles d\'appoint';

  @override
  String get configSupportProvidersSubtitle =>
      'Aides facultatives pour la mémoire, les résumés, le nettoyage OCR et les tâches de fond';

  @override
  String get configPreferredSupportProvider => 'Fournisseur d\'appoint préféré';

  @override
  String get configSupportProviderAuto => 'Automatique';

  @override
  String get configSupportProvidersNote =>
      'Les fournisseurs d\'appoint ne peuvent ni terminer la configuration ni recevoir le contrôle de l\'ordinateur, sauf s\'ils passent par un environnement d\'agent.';

  @override
  String get configRequestPolicy => 'Règles des requêtes';

  @override
  String get configConcurrentRequests => 'Requêtes simultanées';

  @override
  String get configConcurrentRequestsHint =>
      'Nombre maximal de requêtes simultanées';

  @override
  String get configRuntimeTimeout => 'Délai de l\'environnement (s)';

  @override
  String get configAutoRestart =>
      'Redémarrer automatiquement l\'environnement en cas d\'échec';

  @override
  String get configProxySettings => 'Réglages du proxy';

  @override
  String get configUseProxy => 'Utiliser un serveur proxy';

  @override
  String get configProxyHost => 'Hôte du proxy';

  @override
  String get configProxyHostHint => 'ex. : proxy.example.com';

  @override
  String get configProxyPort => 'Port du proxy';

  @override
  String get configConnectionSettings => 'Réglages de connexion';

  @override
  String get configRequestTimeout => 'Délai de requête (s)';

  @override
  String get configMaxRetries => 'Nombre maximal de tentatives';

  @override
  String get configAppearance => 'Apparence';

  @override
  String get configTheme => 'Thème';

  @override
  String get configLanguage => 'Langue';

  @override
  String get configNotifications => 'Notifications';

  @override
  String get configEnableNotifications => 'Activer les notifications';

  @override
  String get configShowTrayIcon =>
      'Afficher l\'icône dans la zone de notification';

  @override
  String get configSecurity => 'Sécurité';

  @override
  String get configEncryptLocalData => 'Chiffrer les données locales';

  @override
  String get configEncryptLocalDataSubtitle =>
      'Chiffrer l\'historique des conversations et les réglages';

  @override
  String get configBiometric => 'Exiger l\'authentification biométrique';

  @override
  String get configBiometricSubtitle =>
      'Exiger l\'empreinte digitale ou une authentification pour ouvrir l\'application';

  @override
  String get configSessionTimeout => 'Délai d\'expiration de session (min)';

  @override
  String get configSessionTimeoutHint =>
      'Verrouillage automatique après inactivité';

  @override
  String get configRememberTokens => 'Mémoriser les jetons d\'authentification';

  @override
  String get configDeveloperOptions => 'Options de développement';

  @override
  String get configDebugMode => 'Mode débogage';

  @override
  String get configDebugModeSubtitle =>
      'Afficher des informations de débogage supplémentaires';

  @override
  String get configVerboseLogging => 'Journalisation détaillée';

  @override
  String get configVerboseLoggingSubtitle =>
      'Consigner des informations de diagnostic détaillées';

  @override
  String get configShowDevTools => 'Afficher les outils de développement';

  @override
  String get configShowDevToolsSubtitle =>
      'Activer les outils et inspecteurs de développement';

  @override
  String get configDataRetention => 'Conservation des données';

  @override
  String get configMaxHistory => 'Historique maximal des conversations';

  @override
  String get configMaxHistoryHint =>
      'Nombre maximal de conversations conservées localement';

  @override
  String get configAutoCleanup =>
      'Nettoyer automatiquement les anciennes données';

  @override
  String get configCacheManagement => 'Gestion du cache';

  @override
  String get configEnableCache => 'Activer le cache des réponses';

  @override
  String get configCacheSize => 'Taille maximale du cache (Mo)';

  @override
  String get configClearCacheNow => 'Vider le cache maintenant';

  @override
  String get configApplication => 'Application';

  @override
  String get configVersion => 'Version';

  @override
  String configVersionValue(String version, String build) {
    return '$version (build $build)';
  }

  @override
  String get configPlatform => 'Plateforme';

  @override
  String get configDartVersion => 'Version de Dart';

  @override
  String get configSettingsPages => 'Pages de réglages';

  @override
  String get configPaths => 'Chemins';

  @override
  String get configAppPath => 'Chemin de l\'application';

  @override
  String get configConfigPath => 'Chemin de la configuration';

  @override
  String get configDataPath => 'Chemin des données';

  @override
  String get configWorkingDirectory => 'Dossier de travail';

  @override
  String get configSoftwareUpdates => 'Mises à jour';

  @override
  String get configCheckingUpdates => 'Recherche de mises à jour…';

  @override
  String get configDownloadingUpdate => 'Téléchargement de la mise à jour…';

  @override
  String get configInstallingUpdate => 'Installation de la mise à jour…';

  @override
  String configUpdateAvailable(String version) {
    return 'Mise à jour disponible : $version';
  }

  @override
  String configCurrentVersion(String version) {
    return 'Version actuelle : $version';
  }

  @override
  String get configDownloadUpdate => 'Télécharger la mise à jour';

  @override
  String get configViewChangelog => 'Voir les nouveautés';

  @override
  String get configUpdateReady => 'Mise à jour prête à installer';

  @override
  String get configInstallRestart => 'Installer et redémarrer';

  @override
  String get configUpToDate => 'À jour';

  @override
  String get configCheckNow => 'Vérifier maintenant';

  @override
  String get configExport => 'Exporter';

  @override
  String get configImport => 'Importer';

  @override
  String get configClearCacheTitle => 'Vider le cache';

  @override
  String configClearCacheConfirm(int size) {
    return 'Vider toutes les données en cache ? ($size Mo seront libérés)';
  }

  @override
  String get configCacheCleared => 'Cache vidé';

  @override
  String get configUpdateMajor =>
      'Version majeure — peut comporter des changements incompatibles';

  @override
  String get configUpdateMinor =>
      'Version mineure — nouvelles fonctions et améliorations';

  @override
  String get configUpdatePatch =>
      'Version corrective — corrections de bogues et de sécurité';

  @override
  String configWhatsNew(String version) {
    return 'Nouveautés de la version $version';
  }

  @override
  String get configNoChangelog => 'Aucune liste des nouveautés disponible';

  @override
  String get filesTitle => 'Opérations sur les fichiers';

  @override
  String filesLoadFailed(String error) {
    return 'Impossible de charger le dossier : $error';
  }

  @override
  String get filesNewDirectory => 'Nouveau dossier';

  @override
  String get filesDirectoryName => 'Nom du dossier';

  @override
  String get filesDirectoryNameRequired => 'Entrez un nom de dossier';

  @override
  String filesCreateDirectoryFailed(String error) {
    return 'Impossible de créer le dossier : $error';
  }

  @override
  String get filesNewFile => 'Nouveau fichier';

  @override
  String get filesFileName => 'Nom du fichier';

  @override
  String get filesFileNameRequired => 'Entrez un nom de fichier';

  @override
  String filesCreateFileFailed(String error) {
    return 'Impossible de créer le fichier : $error';
  }

  @override
  String get filesConfirmDelete => 'Confirmer la suppression';

  @override
  String filesDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Voulez-vous vraiment supprimer $count éléments ?',
      one: 'Voulez-vous vraiment supprimer $count élément ?',
    );
    return '$_temp0';
  }

  @override
  String filesDeleteFailed(String error) {
    return 'Impossible de supprimer les éléments : $error';
  }

  @override
  String filesCopied(String name) {
    return 'Copié : $name';
  }

  @override
  String filesCut(String name) {
    return 'Coupé : $name';
  }

  @override
  String get filesPasted => 'Collé';

  @override
  String get filesMoved => 'Déplacé';

  @override
  String filesPasteFailed(String error) {
    return 'Impossible de coller : $error';
  }

  @override
  String get filesRename => 'Renommer';

  @override
  String get filesNewName => 'Nouveau nom';

  @override
  String get filesNameRequired => 'Entrez un nom';

  @override
  String filesRenameFailed(String error) {
    return 'Impossible de renommer : $error';
  }

  @override
  String get filesOk => 'OK';

  @override
  String filesSizeBytes(String size) {
    return '$size o';
  }

  @override
  String filesSizeKb(String size) {
    return '$size Ko';
  }

  @override
  String filesSizeMb(String size) {
    return '$size Mo';
  }

  @override
  String get filesDirectory => 'Dossier';

  @override
  String get filesFile => 'Fichier';

  @override
  String get filesSize => 'Taille';

  @override
  String get filesModified => 'Modifié le';

  @override
  String get filesPath => 'Chemin';

  @override
  String get filesPaste => 'Coller';

  @override
  String get filesGoHome => 'Dossier de départ';

  @override
  String filesSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '$count sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get filesCopy => 'Copier';

  @override
  String get filesMove => 'Déplacer';

  @override
  String get filesEmpty => 'Ce dossier est vide';

  @override
  String get filesDetails => 'Détails';

  @override
  String get debugTitle => 'Débogage';

  @override
  String debugLoadFailed(String error) {
    return 'Impossible de charger les données de débogage : $error';
  }

  @override
  String get debugConnectedToGateway => 'Connecté à la passerelle';

  @override
  String get debugNoModel => 'aucun modèle';

  @override
  String get debugUnknown => 'inconnu';

  @override
  String get debugConnectionDebugger => 'Diagnostic de connexion';

  @override
  String get debugConnectionDebuggerSubtitle =>
      'Tester la connexion à la passerelle Hermes';

  @override
  String get debugTesting => 'Test en cours…';

  @override
  String get debugRunConnectionTest => 'Lancer le test de connexion';

  @override
  String get debugNoTestsYet =>
      'Aucun test lancé. Cliquez sur « Lancer le test de connexion » pour vérifier l\'état de la passerelle Hermes.';

  @override
  String get debugApiInspector => 'Inspecteur d\'API';

  @override
  String get debugApiInspectorSubtitle =>
      'Envoyer des requêtes à n\'importe quel point d\'accès';

  @override
  String get debugMethod => 'Méthode';

  @override
  String get debugUrl => 'URL';

  @override
  String get debugBodyJson => 'Corps (JSON)';

  @override
  String get debugSending => 'Envoi en cours…';

  @override
  String get debugSendRequest => 'Envoyer la requête';

  @override
  String get debugNoRequestsYet => 'Aucune requête envoyée.';

  @override
  String get debugUrlRequired => 'Erreur : l\'URL est obligatoire';

  @override
  String debugSendingMethod(String method) {
    return 'Envoi de la requête $method…';
  }

  @override
  String get debugServiceStatus => 'État des services';

  @override
  String get debugServiceStatusSubtitle => 'Vérifications et diagnostics';

  @override
  String get debugConnectionManager => 'Gestionnaire de connexion';

  @override
  String get debugHermesGateway => 'Passerelle Hermes';

  @override
  String get debugActive => 'Active';

  @override
  String get debugUnreachable => 'Injoignable';

  @override
  String get debugActiveModel => 'Modèle actif';

  @override
  String get debugNoneSelected => 'Aucun';

  @override
  String debugModelsAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles disponibles',
      one: '$count modèle disponible',
    );
    return '$_temp0';
  }

  @override
  String debugLastError(String error) {
    return 'Dernière erreur : $error';
  }

  @override
  String get debugAuto => 'automatique';

  @override
  String wizardStepOf(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get wizardSetUpLater => 'Configurer plus tard';

  @override
  String get wizardComplete => 'Terminer';

  @override
  String get wizardLoading => 'Chargement…';

  @override
  String get wizardNext => 'Suivant';

  @override
  String get wizardCompletionFailed =>
      'La configuration n\'a pas pu être terminée. Réessayez.';

  @override
  String get welcomeStepSubtitle =>
      'Votre compagnon IA local, qui respecte votre vie privée';

  @override
  String get welcomeFeatureChat => 'Discussion';

  @override
  String get welcomeFeatureChatDescription => 'Réponses de l\'IA en direct';

  @override
  String get welcomeFeatureRuntimes => 'Environnements d\'agents';

  @override
  String get welcomeFeatureRuntimesDescription =>
      'Hermes Agent sur cet appareil ou par Tailscale';

  @override
  String get welcomeFeatureAvatar => 'Avatar évolutif';

  @override
  String get welcomeFeatureAvatarDescription => 'Compagnon IA personnalisé';

  @override
  String get welcomeFeatureDesktopDescription =>
      'Automatisation de l\'interface';

  @override
  String get welcomeFeatureVisionDescription => 'Compréhension de l\'écran';

  @override
  String get welcomeStepInfo =>
      'Nous allons configurer votre IA locale en 2 minutes environ. Tout le traitement se fait en privé sur votre ordinateur.';

  @override
  String get locationTitle => 'Où Hermes fonctionne-t-il ?';

  @override
  String get locationSubtitle =>
      'Hermes peut fonctionner sur cet ordinateur ou sur une autre machine que vous joignez par Tailscale, y compris un serveur privé virtuel (VPS).';

  @override
  String get locationThisDevice => 'Cet appareil';

  @override
  String get locationThisDeviceDescription =>
      'Hermes est installé et fonctionne localement';

  @override
  String get locationTailscale => 'Appareil Tailscale ou VPS';

  @override
  String get locationTailscaleDescription =>
      'Hermes sur un serveur à la maison, un VPS ou une autre machine de votre réseau Tailscale';

  @override
  String get tailscaleDiscovering => 'Recherche des appareils Tailscale…';

  @override
  String get tailscaleScanning => 'Analyse de votre réseau Tailscale';

  @override
  String get tailscaleNoDevices => 'Aucun appareil Tailscale trouvé';

  @override
  String get tailscaleNoDevicesHelp =>
      'Vérifiez que Tailscale est installé et connecté.';

  @override
  String get tailscaleChooseOtherMethod =>
      'Choisir une autre méthode de connexion';

  @override
  String get tailscaleSelectServer => 'Choisissez votre serveur Hermes';

  @override
  String tailscaleSelectServerHelp(String port) {
    return 'Choisissez le VPS ou la machine qui exécute Hermes sur votre réseau Tailscale (port $port)';
  }

  @override
  String get tailscaleNoIp => 'Aucune IP';

  @override
  String get tailscaleOnline => 'En ligne';

  @override
  String get urlRemoteSubtitle =>
      'Confirmez l\'URL Tailscale, puis collez la clé API de votre serveur.';

  @override
  String get urlLooking => 'Recherche de Hermes sur cet appareil…';

  @override
  String get urlDetected =>
      'Hermes fonctionne sur cet appareil. Les informations de connexion ci-dessous ont été détectées automatiquement.';

  @override
  String urlEnterLocal(String port) {
    return 'Entrez l\'URL de Hermes Agent pour cet appareil. Le port par défaut est $port.';
  }

  @override
  String get urlConnectRemote => 'Se connecter à un Hermes distant';

  @override
  String get urlConnectLocal => 'Se connecter à Hermes Agent';

  @override
  String get urlLabel => 'URL de Hermes Agent';

  @override
  String get urlAutoDetectingKey => 'Détection automatique de la clé API…';

  @override
  String get urlApiKeyRequired => 'Clé API Hermes (obligatoire)';

  @override
  String get urlApiKey => 'Clé API Hermes';

  @override
  String get urlApiKeyRemoteHint =>
      'Valeur de API_SERVER_KEY sur le serveur distant';

  @override
  String get urlApiKeyLocalHint =>
      'Détectée automatiquement dans la configuration de Hermes';

  @override
  String get urlAutoDiscovered =>
      'Détectée automatiquement dans la configuration de Hermes';

  @override
  String get urlSaveContinue => 'Enregistrer et continuer';

  @override
  String get urlCommandCopied => 'Commande copiée — exécutez-la sur votre VPS';

  @override
  String get urlRemoteHelp =>
      'Sur votre VPS, exécutez cette commande et collez le résultat dans le champ de la clé API ci-dessus.';

  @override
  String get urlCopyCommand => 'Copier la commande';

  @override
  String get connTesting => 'Test de la connexion…';

  @override
  String get connDns => 'Résolution DNS';

  @override
  String get connTcp => 'Connexion TCP';

  @override
  String get connRuntimeApi => 'API de l\'environnement';

  @override
  String get connUnknown => 'Inconnue';

  @override
  String get connFailed => 'Échec de la connexion';

  @override
  String get connRetry => 'Relancer le test';

  @override
  String get connCheckSettings => 'Vérifier les réglages de connexion';

  @override
  String connConnectingTo(String url) {
    return 'Connexion à : $url';
  }

  @override
  String get connSuccess => 'Connexion réussie !';

  @override
  String get connConnectedTo => 'Connecté à :';

  @override
  String get completionAllSet => 'Tout est prêt !';

  @override
  String get completionConfigured =>
      'Votre environnement d\'agent est configuré et prêt à l\'emploi.';

  @override
  String get completionSaving => 'Enregistrement de la configuration…';

  @override
  String get completionConfiguration => 'Configuration :';

  @override
  String get completionRuntime => 'Environnement';

  @override
  String get completionLocation => 'Emplacement';

  @override
  String get completionLocal => 'Local';

  @override
  String get completionRemote => 'Distant';

  @override
  String get completionReady => 'Prêt à discuter !';

  @override
  String get completionDone =>
      'La configuration est terminée. Vous pouvez commencer à discuter !';

  @override
  String get installStatusInstalled => 'Installé';

  @override
  String get installStatusSkipped => 'Ignoré';

  @override
  String get installStatusFailed => 'Échec';

  @override
  String get providerCustom => 'Personnalisé';

  @override
  String get botInstallComplete =>
      'Installation terminée. Toutes les étapes ont réussi ou ont été ignorées.';

  @override
  String botInstallFailed(String steps) {
    return 'Échec de l\'installation : $steps';
  }

  @override
  String get eventsTitle => 'Flux d\'événements';

  @override
  String get eventsRunFinished => 'Exécution terminée';

  @override
  String get eventsNoRuntime => 'Aucun environnement d\'agent connecté';

  @override
  String get eventsConnectHelp =>
      'Connectez un environnement Hermes pour voir les événements en direct.';

  @override
  String get eventsResume => 'Reprendre';

  @override
  String get eventsPause => 'Pause';

  @override
  String get eventsWaiting => 'En attente d\'événements de l\'agent…';

  @override
  String get guiTitle => 'Automatisation de l\'interface';

  @override
  String get guiScreenshot => 'Capture d\'écran';

  @override
  String get guiAnalyze => 'Analyser';

  @override
  String get guiPrompt => 'Que voulez-vous faire ?';

  @override
  String get guiHint =>
      'ex. : cliquer sur le bouton de recherche, écrire dans la zone';

  @override
  String get guiExecute => 'Exécuter';

  @override
  String get guiResult => 'Résultat';

  @override
  String get guiLocalRuntime =>
      'L\'automatisation de l\'interface utilise l\'environnement d\'agent local.';

  @override
  String guiScreenshotSaved(String path) {
    return 'Capture enregistrée : $path';
  }

  @override
  String get adminUsersTitle => 'Gestion des utilisateurs';

  @override
  String get adminUsersSubtitle =>
      'Consulter et gérer les comptes, les abonnements et les autorisations des utilisateurs';

  @override
  String get adminUsersSearchHint =>
      'Rechercher par courriel, nom d\'utilisateur ou identifiant…';

  @override
  String get adminUsersTierFilter => 'Forfait';

  @override
  String get adminUsersAllTiers => 'Tous les forfaits';

  @override
  String get adminUsersStatusFilter => 'État du compte';

  @override
  String get adminUsersAllStatuses => 'Tous les états';

  @override
  String get adminStatusActive => 'Actif';

  @override
  String get adminStatusSuspended => 'Suspendu';

  @override
  String get adminStatusDeleted => 'Supprimé';

  @override
  String get adminUsersSortBy => 'Trier par';

  @override
  String get adminUsersSortRegistration => 'Date d\'inscription';

  @override
  String get adminUsersLastLogin => 'Dernière connexion';

  @override
  String get adminEmail => 'Courriel';

  @override
  String get adminUsersAscending => 'Croissant';

  @override
  String get adminUsersDescending => 'Décroissant';

  @override
  String get adminUsersNoPermissionView =>
      'Vous n\'avez pas l\'autorisation de consulter les utilisateurs';

  @override
  String adminUsersLoadFailed(String error) {
    return 'Impossible de charger les utilisateurs : $error';
  }

  @override
  String get adminUsersNone => 'Aucun utilisateur trouvé';

  @override
  String get adminUsername => 'Nom d\'utilisateur';

  @override
  String get adminSubscription => 'Abonnement';

  @override
  String get adminRegistered => 'Inscrit le';

  @override
  String get adminNotAvailable => 'S. O.';

  @override
  String get adminViewDetails => 'Voir les détails';

  @override
  String get adminSuspend => 'Suspendre';

  @override
  String get adminReactivate => 'Réactiver';

  @override
  String adminUsersShowing(int from, int to, int total) {
    return 'Utilisateurs $from à $to sur $total';
  }

  @override
  String adminPageOf(int page, int total) {
    return 'Page $page sur $total';
  }

  @override
  String adminUserDetailsLoadFailed(String error) {
    return 'Impossible de charger les détails de l\'utilisateur : $error';
  }

  @override
  String get adminUserDetails => 'Détails de l\'utilisateur';

  @override
  String get adminNoUserDetails => 'Aucun détail disponible';

  @override
  String get adminProfileInfo => 'Profil';

  @override
  String get adminUserId => 'Identifiant de l\'utilisateur';

  @override
  String get adminSubscriptionInfo => 'Abonnement';

  @override
  String get adminTier => 'Forfait';

  @override
  String get adminPeriodStart => 'Début de la période en cours';

  @override
  String get adminPeriodEnd => 'Fin de la période en cours';

  @override
  String get adminCancellation => 'Annulation';

  @override
  String get adminCancelAtPeriodEnd => 'Prévue à la fin de la période';

  @override
  String get adminRecentPayments => 'Paiements récents';

  @override
  String get adminActiveSessions => 'Sessions actives';

  @override
  String get adminRecentActivity => 'Activité récente';

  @override
  String get adminDate => 'Date';

  @override
  String get adminAmount => 'Montant';

  @override
  String get adminMethod => 'Méthode';

  @override
  String get adminIpAddress => 'Adresse IP';

  @override
  String get adminUserAgent => 'Navigateur (User-Agent)';

  @override
  String get adminLastActive => 'Dernière activité';

  @override
  String get adminUnknownAction => 'Action inconnue';

  @override
  String get adminInvalidDate => 'Date invalide';

  @override
  String get adminNoPermissionEdit =>
      'Vous n\'avez pas l\'autorisation de modifier les utilisateurs';

  @override
  String get adminSubscriptionUpdated =>
      'Abonnement de l\'utilisateur mis à jour';

  @override
  String adminUpdateFailed(String error) {
    return 'Impossible de mettre à jour l\'utilisateur : $error';
  }

  @override
  String get adminEditSubscriptionTitle =>
      'Modifier l\'abonnement de l\'utilisateur';

  @override
  String adminUserLabel(String email) {
    return 'Utilisateur : $email';
  }

  @override
  String get adminSuspendReasonMissing => 'Indiquez la raison de la suspension';

  @override
  String get adminNoPermissionSuspend =>
      'Vous n\'avez pas l\'autorisation de suspendre des utilisateurs';

  @override
  String get adminSuspended => 'Utilisateur suspendu';

  @override
  String adminSuspendFailed(String error) {
    return 'Impossible de suspendre l\'utilisateur : $error';
  }

  @override
  String get adminSuspendTitle => 'Suspendre le compte';

  @override
  String get adminSuspendWarning =>
      'Le compte sera suspendu et l\'utilisateur ne pourra plus accéder à l\'application.';

  @override
  String get adminSuspendReason => 'Raison de la suspension *';

  @override
  String get adminSuspendReasonHint =>
      'Indiquez pourquoi ce compte est suspendu';

  @override
  String get adminNoPermissionReactivate =>
      'Vous n\'avez pas l\'autorisation de réactiver des utilisateurs';

  @override
  String get adminReactivated => 'Utilisateur réactivé';

  @override
  String adminReactivateFailed(String error) {
    return 'Impossible de réactiver l\'utilisateur : $error';
  }

  @override
  String get adminReactivateTitle => 'Réactiver le compte';

  @override
  String get adminReactivateInfo =>
      'Le compte sera réactivé et l\'utilisateur retrouvera l\'accès à l\'application.';

  @override
  String get adminDashboardTitle => 'Tableau de bord';

  @override
  String get adminRefreshMetrics => 'Actualiser les indicateurs';

  @override
  String get adminTotalUsers => 'Utilisateurs au total';

  @override
  String adminNewThisMonth(String count) {
    return '$count nouveaux ce mois-ci';
  }

  @override
  String get adminActiveUsers => 'Utilisateurs actifs';

  @override
  String adminPercentOfTotal(String percent) {
    return '$percent % du total';
  }

  @override
  String get adminMrr => 'Revenu mensuel récurrent';

  @override
  String adminFromSubscribers(String count) {
    return 'Provenant de $count abonnés';
  }

  @override
  String get adminCurrentMonthRevenue => 'Revenu du mois en cours';

  @override
  String adminTransactionsCount(String count) {
    return '$count transactions';
  }

  @override
  String get adminSubscriptionDistribution => 'Répartition des abonnements';

  @override
  String adminConversionRate(String rate) {
    return 'Taux de conversion : $rate %';
  }

  @override
  String get adminTierFree => 'Gratuit';

  @override
  String get adminTierPremium => 'Premium';

  @override
  String get adminTierEnterprise => 'Entreprise';

  @override
  String adminCountPercent(int count, String percent) {
    return '$count ($percent %)';
  }

  @override
  String get adminNoRecentTransactions => 'Aucune transaction récente';

  @override
  String get adminRecentTransactions => 'Transactions récentes';

  @override
  String adminToday(String time) {
    return 'Aujourd\'hui $time';
  }

  @override
  String get adminYesterday => 'Hier';

  @override
  String adminDaysAgo(int days) {
    return 'il y a $days jours';
  }

  @override
  String auditLoadDetailsFailed(String error) {
    return 'Impossible de charger les détails de l\'entrée : $error';
  }

  @override
  String get auditExported => 'Journal d\'audit exporté';

  @override
  String auditExportFailed(String error) {
    return 'Impossible d\'exporter le journal : $error';
  }

  @override
  String get auditTitle => 'Journal d\'audit';

  @override
  String get auditFilters => 'Filtres';

  @override
  String get auditExportCsv => 'Exporter en CSV';

  @override
  String auditFilterAdmin(String value) {
    return 'Administrateur : $value';
  }

  @override
  String auditFilterAction(String value) {
    return 'Action : $value';
  }

  @override
  String auditFilterResource(String value) {
    return 'Ressource : $value';
  }

  @override
  String auditFilterAffectedUser(String value) {
    return 'Utilisateur visé : $value';
  }

  @override
  String auditFilterFrom(String date) {
    return 'Du : $date';
  }

  @override
  String auditFilterTo(String date) {
    return 'Au : $date';
  }

  @override
  String auditFilterSeverity(String value) {
    return 'Gravité : $value';
  }

  @override
  String get auditTimestamp => 'Horodatage';

  @override
  String get auditAction => 'Action';

  @override
  String get auditResource => 'Ressource';

  @override
  String get auditAdmin => 'Administrateur';

  @override
  String get auditAffectedUser => 'Utilisateur visé';

  @override
  String get auditSeverity => 'Gravité';

  @override
  String auditShowing(int from, int to, int total) {
    return 'Entrées $from à $to sur $total';
  }

  @override
  String auditError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get auditNone => 'Aucune entrée trouvée dans le journal';

  @override
  String get auditClearFilters => 'Effacer les filtres';

  @override
  String get auditFilterTitle => 'Filtrer le journal d\'audit';

  @override
  String get auditAdminUserId => 'Identifiant de l\'administrateur';

  @override
  String get auditAdminUserIdHint =>
      'Filtrer par identifiant d\'administrateur';

  @override
  String get auditActionHint => 'ex. : user_suspended, refund_processed';

  @override
  String get auditResourceType => 'Type de ressource';

  @override
  String get auditResourceTypeHint => 'ex. : user, subscription, transaction';

  @override
  String get auditAffectedUserId => 'Identifiant de l\'utilisateur visé';

  @override
  String get auditAffectedUserIdHint =>
      'Filtrer par identifiant de l\'utilisateur visé';

  @override
  String get auditDateRange => 'Période';

  @override
  String get auditStartDate => 'Date de début';

  @override
  String get auditEndDate => 'Date de fin';

  @override
  String get auditAllSeverities => 'Toutes les gravités';

  @override
  String get auditClearAll => 'Tout effacer';

  @override
  String get auditDetailsTitle => 'Détails de l\'entrée';

  @override
  String get auditLogId => 'Identifiant de l\'entrée';

  @override
  String get auditResourceId => 'Identifiant de la ressource';

  @override
  String get auditAdminUser => 'Administrateur';

  @override
  String get auditRole => 'Rôle';

  @override
  String get auditActionDetails => 'Détails de l\'action';

  @override
  String adminsLoadFailed(String error) {
    return 'Impossible de charger les administrateurs : $error';
  }

  @override
  String get adminsRevokeTitle => 'Retirer le rôle d\'administrateur';

  @override
  String adminsRevokeConfirm(String role, String email) {
    return 'Voulez-vous vraiment retirer le rôle $role à $email ?';
  }

  @override
  String get adminsRevoke => 'Retirer';

  @override
  String get adminsRevoked => 'Rôle d\'administrateur retiré';

  @override
  String adminsRevokeFailed(String error) {
    return 'Impossible de retirer le rôle : $error';
  }

  @override
  String get adminsRoleSuper => 'Super administrateur';

  @override
  String get adminsRoleSupport => 'Administrateur du soutien';

  @override
  String get adminsRoleFinance => 'Administrateur des finances';

  @override
  String get adminsSuperRequired => 'Accès super administrateur requis';

  @override
  String get adminsSuperRequiredBody =>
      'Seuls les super administrateurs peuvent gérer les comptes d\'administrateur.';

  @override
  String get adminsTitle => 'Gestion des administrateurs';

  @override
  String get adminsSubtitle =>
      'Gérer les comptes et les rôles d\'administrateur';

  @override
  String get adminsAdd => 'Ajouter un administrateur';

  @override
  String get adminsNone => 'Aucun administrateur trouvé';

  @override
  String get adminsTotalActions => 'Actions au total';

  @override
  String get adminsRecent30d => 'Récentes (30 j)';

  @override
  String get adminsLastAction => 'Dernière action';

  @override
  String get adminsToday => 'Aujourd\'hui';

  @override
  String adminsWeeksAgo(int weeks) {
    return 'il y a $weeks sem.';
  }

  @override
  String adminsMonthsAgo(int months) {
    return 'il y a $months mois';
  }

  @override
  String get adminsUnknown => 'Inconnue';

  @override
  String get adminsAssigned => 'Rôle d\'administrateur attribué';

  @override
  String get adminsAddTitle => 'Ajouter un administrateur';

  @override
  String get adminsEmailAddress => 'Adresse courriel';

  @override
  String get adminsEmailRequired => 'Le courriel est obligatoire';

  @override
  String get adminsEmailInvalid => 'Adresse courriel invalide';

  @override
  String get adminsSelectRole => 'Choisir un rôle';

  @override
  String get adminsSupportDescription => 'Gestion des utilisateurs et soutien';

  @override
  String get adminsFinanceDescription =>
      'Paiements, remboursements et rapports';
}
