/**
 * Shared type definitions for the Pistisai Personality Skill.
 *
 * These types define the contract between the OpenClaw runtime and the
 * personality/evolution system, and mirror the Flutter-side models in
 * lib/models/avatar/personality_models.dart.
 */

// ─── Personality Traits ────────────────────────────────────────────────

/** The four core personality traits, each on a 0.0–1.0 scale. */
export interface PersonalityTraits {
  formality: number;   // 0.0 = casual, 1.0 = formal
  humor: number;       // 0.0 = serious, 1.0 = playful
  enthusiasm: number;  // 0.0 = calm, 1.0 = energetic
  empathy: number;     // 0.0 = direct, 1.0 = warm
}

// ─── Evolution Stages ──────────────────────────────────────────────────

export const EVOLUTION_STAGES = [
  'curious_explorer',
  'knowledge_seeker',
  'wise_companion',
  'enlightened_guide',
] as const;

export type EvolutionStage = (typeof EVOLUTION_STAGES)[number];

/** Stage transition rules: which stage can evolve to which. */
export const STAGE_TRANSITIONS: Record<EvolutionStage, EvolutionStage | null> = {
  curious_explorer: 'knowledge_seeker',
  knowledge_seeker: 'wise_companion',
  wise_companion: 'enlightened_guide',
  enlightened_guide: null, // terminal stage
};

/** Human-readable labels for each stage. */
export const STAGE_LABELS: Record<EvolutionStage, string> = {
  curious_explorer: 'Curious Explorer',
  knowledge_seeker: 'Knowledge Seeker',
  wise_companion: 'Wise Companion',
  enlightened_guide: 'Enlightened Guide',
};

/** Stage-specific system prompt guidance. */
export const STAGE_GUIDANCE: Record<EvolutionStage, string> = {
  curious_explorer:
    'You are in the early stages of development. Be helpful but acknowledge when you are learning.',
  knowledge_seeker:
    'You have begun to develop your own voice. Show growing confidence in your interactions.',
  wise_companion:
    'You have developed a mature personality. Engage deeply and show nuanced understanding.',
  enlightened_guide:
    'You have reached your full potential. Be your authentic self with confidence and depth.',
};

// ─── Evolution Requirements ───────────────────────────────────────────

/** Thresholds that must be met for evolution to be approved. */
export const EVOLUTION_THRESHOLDS = {
  /** Minimum number of deep conversations (complexity > 0.7). */
  minDeepConversations: 5,
  /** Minimum average novelty score across all conversations. */
  minAvgNovelty: 0.5,
  /** Minimum number of growth self-reflections. */
  minGrowthReflections: 3,
  /** Minimum depth score to consider evolution. */
  minDepthScore: 0.4,
} as const;

// ─── Conversation Depth Metrics ───────────────────────────────────────

export interface ConversationDepthMetrics {
  id: string;
  conversationId: string;
  complexityScore: number;  // 0–1: topic diversity, length, reasoning
  emotionalDepth: number;   // 0–1: empathy, personal sharing
  noveltyScore: number;     // 0–1: new topics vs repeated
  timestamp: number;        // epoch ms
}

// ─── Self-Reflection ──────────────────────────────────────────────────

export type ReflectionType = 'growth' | 'pattern' | 'limitation';

export interface SelfReflection {
  id: number;
  agentId: string;
  timestamp: string;
  reflectionType: ReflectionType;
  content: string;
  confidence: number; // 0–1
}

// ─── Personality Profile ──────────────────────────────────────────────

export interface PersonalityProfile {
  agentId: string;
  agentName: string;
  traits: PersonalityTraits;
  evolutionStage: EvolutionStage;
  conversationCount: number;
  depthScore: number;
  createdAt: string;
  updatedAt: string;
}

// ─── Evolution Request / Decision ──────────────────────────────────────

export interface EvolutionRequest {
  agentId: string;
  currentStage: EvolutionStage;
  proposedStage: EvolutionStage;
  reason: string;
  evidence: {
    conversationsCount: number;
    uniqueTopics: number;
    depthScore: number;
    growthReflections: number;
    deepConversations: number;
    avgNovelty: number;
  };
  timestamp: string;
}

export interface EvolutionDecision {
  approved: boolean;
  reason?: string;
  newStage?: EvolutionStage;
}

// ─── Conversation Memory ──────────────────────────────────────────────

export interface ConversationMemory {
  id: number;
  agentId: string;
  timestamp: string;
  userMessage: string;
  agentResponse: string;
  sentimentScore?: number;
  topics: string[];
}

// ─── Conversation Stats ────────────────────────────────────────────────

export interface ConversationStats {
  totalConversations: number;
  uniqueTopics: number;
  avgSentiment: number;
  depthScore: number;
  deepConversations: number;
  avgNovelty: number;
}

// ─── Personality Injection ────────────────────────────────────────────

/** Result of injecting personality into a system prompt. */
export interface PersonalityInjection {
  systemPrompt: string;
  personalityTraits: PersonalityTraits;
  evolutionStage: EvolutionStage;
  stageLabel: string;
}

// ─── OpenClaw Skill Handler Types ─────────────────────────────────────

/**
 * Standard OpenClaw skill handler interface.
 * The gateway calls these methods to interact with the skill.
 */
export interface OpenClawSkillHandler {
  /** Unique skill name. */
  name: string;
  /** Human-readable description. */
  description: string;
  /** Version string. */
  version: string;

  /** Called when the gateway loads the skill. */
  onLoad(config: Record<string, unknown>): Promise<void>;
  /** Called when the gateway unloads the skill. */
  onUnload(): Promise<void>;

  /** Handle an incoming message/event from the gateway. */
  handleMessage(message: SkillMessage): Promise<SkillResponse>;
}

export interface SkillMessage {
  type: string;
  payload: Record<string, unknown>;
  conversationId?: string;
  timestamp?: string;
}

export interface SkillResponse {
  type: string;
  payload: Record<string, unknown>;
}

// ─── Skill Config ─────────────────────────────────────────────────────

export interface SkillConfig {
  agentId: string;
  agentName?: string;
  driftDbPath?: string;
  pistisaiApiUrl?: string;
  markdownPath?: string;
  autoEvolve?: boolean;
}
