/**
 * Pistisai Personality Skill — Main Handler
 *
 * OpenClaw skill that provides:
 * - Personality-driven responses via system prompt injection
 * - Self-reflection for growth recognition
 * - Evolution requests to Pistisai (or auto-approval)
 * - Markdown fallback for offline mode
 *
 * Implements the OpenClawSkillHandler interface for gateway integration.
 */

import {
  ConversationMemory,
  EvolutionDecision,
  EvolutionRequest,
  EvolutionStage,
  OpenClawSkillHandler,
  PersonalityInjection,
  PersonalityProfile,
  PersonalityTraits,
  SelfReflection,
  SkillConfig,
  SkillMessage,
  SkillResponse,
  STAGE_LABELS,
} from './types.js';

import {
  analyzeGrowth,
  checkEvolutionReadiness,
  computeDepthMetrics,
  extractTopics,
  generateEvolutionReason,
  getNextStage,
  makeEvolutionDecision,
} from './evolution.js';

import { injectPersonality } from './prompt.js';

import {
  createDefaultProfile,
  PersonalityStateManager,
} from './state.js';

export class PersonalitySkill implements OpenClawSkillHandler {
  // ─── OpenClawSkillHandler Interface ──────────────────────────────

  readonly name = 'pistisai-personality';
  readonly description =
    'Avatar personality and evolution system — defines personality traits, manages evolution stages, and injects personality into agent responses';
  readonly version = '1.1.0';

  // ─── Internal State ──────────────────────────────────────────────

  private stateManager: PersonalityStateManager;
  private config!: SkillConfig;
  private currentProfile: PersonalityProfile | null = null;
  private initialized = false;

  constructor() {
    this.stateManager = new PersonalityStateManager();
  }

  // ─── Lifecycle ────────────────────────────────────────────────────

  async onLoad(config: Record<string, unknown>): Promise<void> {
    this.config = {
      agentId: (config.agentId as string) || 'default-agent',
      agentName: (config.agentName as string) || 'Pistisai',
      driftDbPath: (config.driftDbPath as string) || '/tmp/drift/personality.db',
      pistisaiApiUrl: config.pistisaiApiUrl as string | undefined,
      markdownPath: (config.markdownPath as string) || '.',
      autoEvolve: (config.autoEvolve as boolean) ?? false,
    };

    this.stateManager = new PersonalityStateManager(
      this.config.driftDbPath,
      this.config.markdownPath,
    );

    await this.initialize();
  }

  async onUnload(): Promise<void> {
    this.stateManager.disconnect();
    this.initialized = false;
  }

  // ─── Message Handling ────────────────────────────────────────────

  async handleMessage(message: SkillMessage): Promise<SkillResponse> {
    if (!this.initialized) {
      return {
        type: 'error',
        payload: { error: 'Skill not initialized. Call onLoad first.' },
      };
    }

    switch (message.type) {
      case 'get_personality':
        return this.handleGetPersonality();

      case 'inject_personality':
        return this.handleInjectPersonality(
          message.payload.basePrompt as string,
        );

      case 'track_conversation':
        return this.handleTrackConversation(message.payload);

      case 'self_reflect':
        return this.handleSelfReflect(message.payload);

      case 'request_evolution':
        return this.handleRequestEvolution(
          message.payload.proposedStage as EvolutionStage,
        );

      case 'update_traits':
        return this.handleUpdateTraits(
          message.payload.traits as Partial<PersonalityTraits>,
        );

      case 'update_agent_name':
        return this.handleUpdateAgentName(
          message.payload.name as string,
        );

      case 'check_readiness':
        return this.handleCheckReadiness();

      case 'get_stats':
        return this.handleGetStats();

      default:
        return {
          type: 'error',
          payload: { error: `Unknown message type: ${message.type}` },
        };
    }
  }

  // ─── Initialization ──────────────────────────────────────────────

  private async initialize(): Promise<void> {
    const connected = await this.stateManager.connect();

    if (connected) {
      console.log('[PersonalitySkill] Connected to database');
    } else {
      console.warn('[PersonalitySkill] Database unavailable, using markdown fallback');
    }

    this.currentProfile = await this.stateManager.loadPersonality(
      this.config.agentId,
    );

    if (!this.currentProfile) {
      this.currentProfile = createDefaultProfile(this.config.agentId);
      this.currentProfile.agentName = this.config.agentName || 'Pistisai';
      await this.stateManager.savePersonality(this.currentProfile);
      console.log('[PersonalitySkill] Created default profile');
    }

    this.initialized = true;
    console.log(
      '[PersonalitySkill] Initialized:',
      this.currentProfile.agentName,
      `(${STAGE_LABELS[this.currentProfile.evolutionStage]})`,
    );
  }

  // ─── Handlers ────────────────────────────────────────────────────

  private async handleGetPersonality(): Promise<SkillResponse> {
    if (!this.currentProfile) {
      return { type: 'error', payload: { error: 'No profile loaded' } };
    }

    return {
      type: 'personality',
      payload: {
        agentName: this.currentProfile.agentName,
        traits: this.currentProfile.traits,
        evolutionStage: this.currentProfile.evolutionStage,
        stageLabel: STAGE_LABELS[this.currentProfile.evolutionStage],
        conversationCount: this.currentProfile.conversationCount,
        depthScore: this.currentProfile.depthScore,
      },
    };
  }

  private async handleInjectPersonality(
    basePrompt: string,
  ): Promise<SkillResponse> {
    if (!this.currentProfile) {
      return { type: 'error', payload: { error: 'No profile loaded' } };
    }

    const injection = injectPersonality(
      basePrompt,
      this.currentProfile.traits,
      this.currentProfile.evolutionStage,
    );

    return {
      type: 'personality_injected',
      payload: {
        systemPrompt: injection.systemPrompt,
        traits: injection.personalityTraits,
        evolutionStage: injection.evolutionStage,
        stageLabel: injection.stageLabel,
      },
    };
  }

  private async handleTrackConversation(
    payload: Record<string, unknown>,
  ): Promise<SkillResponse> {
    if (!this.currentProfile) {
      return { type: 'error', payload: { error: 'No profile loaded' } };
    }

    const userMessage = payload.userMessage as string;
    const agentResponse = payload.agentResponse as string;
    const conversationId =
      (payload.conversationId as string) || `conv_${Date.now()}`;

    // Extract topics
    const topics = extractTopics(userMessage, agentResponse);

    // Compute depth metrics
    const metrics = computeDepthMetrics(
      conversationId,
      userMessage,
      agentResponse,
    );

    // Store depth metrics
    this.stateManager.storeDepthMetrics(metrics);

    // Store conversation memory
    const memory: Omit<ConversationMemory, 'id'> = {
      agentId: this.config.agentId,
      timestamp: new Date().toISOString(),
      userMessage,
      agentResponse,
      sentimentScore: (payload.sentimentScore as number) ?? undefined,
      topics,
    };

    await this.stateManager.storeMemory(memory);

    // Update profile stats
    this.currentProfile.conversationCount++;
    this.currentProfile.depthScore = Math.max(
      this.currentProfile.depthScore,
      metrics.complexityScore,
    );
    this.currentProfile.updatedAt = new Date().toISOString();
    await this.stateManager.savePersonality(this.currentProfile);

    return {
      type: 'conversation_tracked',
      payload: {
        metrics,
        topics,
        conversationCount: this.currentProfile.conversationCount,
      },
    };
  }

  private async handleSelfReflect(
    context: Record<string, unknown>,
  ): Promise<SkillResponse> {
    if (!this.currentProfile) {
      return { type: 'error', payload: { error: 'No profile loaded' } };
    }

    const stats = this.stateManager.getConversationStats(
      this.config.agentId,
    );

    const reflection = analyzeGrowth(stats, {
      recentConversations: (context.recentConversations as number) || 0,
      recentTopics: (context.recentTopics as string[]) || [],
      currentChallenges: (context.currentChallenges as string[]) || [],
    });

    if (reflection) {
      const fullReflection: Omit<SelfReflection, 'id'> = {
        ...reflection,
        agentId: this.config.agentId,
      };
      await this.stateManager.storeReflection(fullReflection);

      return {
        type: 'self_reflection',
        payload: {
          reflection: fullReflection,
          stats,
        },
      };
    }

    return {
      type: 'self_reflection',
      payload: {
        reflection: null,
        stats,
        message: 'No significant growth detected yet. Continue having meaningful conversations.',
      },
    };
  }

  private async handleRequestEvolution(
    proposedStage: EvolutionStage,
  ): Promise<SkillResponse> {
    if (!this.currentProfile) {
      return { type: 'error', payload: { error: 'No profile loaded' } };
    }

    const stats = this.stateManager.getConversationStats(
      this.config.agentId,
    );

    const reflections = this.stateManager.getRecentReflections(
      this.config.agentId,
      20,
    );

    const growthReflections = reflections.filter(
      (r) => r.reflectionType === 'growth',
    ).length;

    // Make local decision
    const decision = makeEvolutionDecision(
      this.currentProfile.evolutionStage,
      proposedStage,
      stats,
      growthReflections,
    );

    // If auto-evolve is enabled and decision is approved, apply it
    if (decision.approved && this.config.autoEvolve) {
      await this.applyEvolution(proposedStage, stats, growthReflections);
    }

    // If Pistisai API is configured, send request for collaborative approval
    if (this.config.pistisaiApiUrl && decision.approved) {
      const request: EvolutionRequest = {
        agentId: this.config.agentId,
        currentStage: this.currentProfile.evolutionStage,
        proposedStage,
        reason: generateEvolutionReason(stats, growthReflections),
        evidence: {
          conversationsCount: stats.totalConversations,
          uniqueTopics: stats.uniqueTopics,
          depthScore: stats.depthScore,
          growthReflections,
          deepConversations: stats.deepConversations,
          avgNovelty: stats.avgNovelty,
        },
        timestamp: new Date().toISOString(),
      };

      try {
        const response = await fetch(
          `${this.config.pistisaiApiUrl}/api/evolution`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(request),
          },
        );

        const result = (await response.json()) as EvolutionDecision;

        if (result.approved) {
          await this.applyEvolution(proposedStage, stats, growthReflections);
          return {
            type: 'evolution_result',
            payload: { ...result, source: 'pistisai' },
          };
        }

        return {
          type: 'evolution_result',
          payload: { ...result, source: 'pistisai' },
        };
      } catch (error) {
        console.error('[PersonalitySkill] Pistisai API call failed:', error);
        // Fall through to return local decision
      }
    }

    return {
      type: 'evolution_result',
      payload: { ...decision, source: 'local' },
    };
  }

  private async applyEvolution(
    newStage: EvolutionStage,
    stats: { totalConversations: number; uniqueTopics: number; depthScore: number },
    growthReflections: number,
  ): Promise<void> {
    if (!this.currentProfile) return;

    const oldStage = this.currentProfile.evolutionStage;
    this.currentProfile.evolutionStage = newStage;
    this.currentProfile.updatedAt = new Date().toISOString();
    await this.stateManager.savePersonality(this.currentProfile);

    console.log(
      `[PersonalitySkill] Evolution: ${oldStage} → ${newStage}`,
    );
  }

  private async handleUpdateTraits(
    partial: Partial<PersonalityTraits>,
  ): Promise<SkillResponse> {
    if (!this.currentProfile) {
      return { type: 'error', payload: { error: 'No profile loaded' } };
    }

    const clamp = (v: number | undefined, def: number): number =>
      v !== undefined ? Math.max(0, Math.min(1, v)) : def;

    this.currentProfile.traits = {
      formality: clamp(partial.formality, this.currentProfile.traits.formality),
      humor: clamp(partial.humor, this.currentProfile.traits.humor),
      enthusiasm: clamp(partial.enthusiasm, this.currentProfile.traits.enthusiasm),
      empathy: clamp(partial.empathy, this.currentProfile.traits.empathy),
    };

    this.currentProfile.updatedAt = new Date().toISOString();
    await this.stateManager.savePersonality(this.currentProfile);

    return {
      type: 'traits_updated',
      payload: { traits: this.currentProfile.traits },
    };
  }

  private async handleUpdateAgentName(name: string): Promise<SkillResponse> {
    if (!this.currentProfile) {
      return { type: 'error', payload: { error: 'No profile loaded' } };
    }

    this.currentProfile.agentName = name;
    this.currentProfile.updatedAt = new Date().toISOString();
    await this.stateManager.savePersonality(this.currentProfile);

    return {
      type: 'agent_name_updated',
      payload: { agentName: name },
    };
  }

  private async handleCheckReadiness(): Promise<SkillResponse> {
    if (!this.currentProfile) {
      return { type: 'error', payload: { error: 'No profile loaded' } };
    }

    const stats = this.stateManager.getConversationStats(
      this.config.agentId,
    );

    const reflections = this.stateManager.getRecentReflections(
      this.config.agentId,
      20,
    );

    const growthReflections = reflections.filter(
      (r) => r.reflectionType === 'growth',
    ).length;

    const readiness = checkEvolutionReadiness(stats, growthReflections);
    const nextStage = getNextStage(this.currentProfile.evolutionStage);

    return {
      type: 'readiness',
      payload: {
        ready: readiness.ready,
        reasons: readiness.reasons,
        stats,
        growthReflections,
        currentStage: this.currentProfile.evolutionStage,
        nextStage,
        stageLabel: nextStage ? STAGE_LABELS[nextStage] : null,
      },
    };
  }

  private async handleGetStats(): Promise<SkillResponse> {
    if (!this.currentProfile) {
      return { type: 'error', payload: { error: 'No profile loaded' } };
    }

    const stats = this.stateManager.getConversationStats(
      this.config.agentId,
    );

    const reflections = this.stateManager.getRecentReflections(
      this.config.agentId,
      20,
    );

    return {
      type: 'stats',
      payload: {
        profile: {
          agentName: this.currentProfile.agentName,
          traits: this.currentProfile.traits,
          evolutionStage: this.currentProfile.evolutionStage,
          stageLabel: STAGE_LABELS[this.currentProfile.evolutionStage],
          conversationCount: this.currentProfile.conversationCount,
          depthScore: this.currentProfile.depthScore,
        },
        stats,
        reflectionCount: reflections.length,
        growthReflections: reflections.filter((r) => r.reflectionType === 'growth').length,
      },
    };
  }
}

// ─── Default Export ──────────────────────────────────────────────────

export default PersonalitySkill;
