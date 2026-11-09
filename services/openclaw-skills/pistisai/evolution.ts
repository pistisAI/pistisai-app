/**
 * Evolution Engine — core logic for avatar evolution.
 *
 * Handles:
 * - Conversation depth analysis (complexity, emotional depth, novelty)
 * - Self-reflection and growth recognition
 * - Evolution readiness assessment
 * - Stage transition validation
 */

import {
  ConversationDepthMetrics,
  ConversationStats,
  EvolutionDecision,
  EvolutionStage,
  EVOLUTION_THRESHOLDS,
  SelfReflection,
  STAGE_TRANSITIONS,
} from './types.js';

// ─── Technical Terms (for complexity detection) ────────────────────────

const TECHNICAL_TERMS = new Set([
  'api', 'rest', 'http', 'https', 'json', 'xml', 'sql', 'nosql',
  'database', 'algorithm', 'function', 'variable', 'class', 'method',
  'interface', 'async', 'await', 'promise', 'callback', 'array',
  'object', 'string', 'integer', 'boolean', 'float', 'double', 'null',
  'undefined', 'react', 'vue', 'angular', 'flutter', 'dart',
  'javascript', 'typescript', 'python', 'java', 'rust', 'go', 'cpp',
  'html', 'css', 'docker', 'kubernetes', 'git', 'github', 'gitlab',
  'devops', 'cloud', 'aws', 'azure', 'gcp', 'serverless',
  'microservices', 'frontend', 'backend', 'fullstack', 'ui', 'ux',
  'debug', 'compile', 'runtime', 'middleware', 'framework', 'library',
  'package', 'module', 'import', 'export', 'component', 'state',
  'props', 'hook', 'context', 'redux', 'router', 'navigation',
  'authentication', 'authorization', 'oauth', 'jwt', 'session',
  'cookie', 'cache', 'redis', 'mongodb', 'mysql', 'postgresql',
  'sqlite', 'orm', 'prisma', 'migration', 'deployment', 'testing',
  'unit', 'integration', 'e2e', 'tdd', 'bdd', 'agile', 'scrum',
  'kanban', 'code', 'review', 'refactor', 'pattern', 'architecture',
  'design', 'system', 'network', 'protocol', 'tcp', 'udp', 'ip',
  'dns', 'ssl', 'tls', 'ssh', 'ftp', 'smtp', 'websocket', 'graphql',
  'machine learning', 'ai', 'neural', 'deep learning', 'llm',
  'transformer', 'embedding', 'vector', 'tensor', 'gradient',
  'regression', 'classification', 'cluster', 'training', 'inference',
]);

// ─── Empathetic Words (for emotional depth detection) ──────────────────

const EMPATHETIC_WORDS = new Set([
  'understand', 'understanding', 'feel', 'feeling', 'sorry',
  'apologize', 'empathy', 'sympathy', 'compassion', 'care', 'caring',
  'support', 'appreciate', 'thankful', 'listen', 'listening', 'hear',
  'validate', 'acknowledge', 'recognize', 'respect', 'accept',
  'emotional', 'emotion', 'sad', 'happy', 'joy', 'excited', 'worried',
  'anxious', 'stressed', 'overwhelmed', 'confident', 'proud',
  'disappointed', 'frustrated', 'confused', 'uncertain', 'hopeful',
  'blessed', 'loved', 'cared', 'valued', 'understood', 'heard',
  'supported', 'helped', 'comfort', 'comfortable', 'safe', 'secure',
  'trust', 'believe', 'hope', 'wish', 'dream', 'desire', 'passion',
  'purpose', 'meaning', 'connection', 'relationship', 'friend',
  'family', 'love', 'kindness', 'generous',
]);

// ─── Word Extraction ──────────────────────────────────────────────────

function extractWords(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length > 0);
}

// ─── Complexity Calculation ───────────────────────────────────────────

/**
 * Calculate conversation complexity based on multiple factors.
 * Returns a score between 0.0 and 1.0.
 */
export function calculateComplexity(
  userMessage: string,
  agentResponse: string,
): number {
  const allText = `${userMessage} ${agentResponse}`;
  const words = extractWords(allText);

  if (words.length === 0) return 0.0;

  let score = 0.0;
  let factors = 0;

  // Factor 1: Average message length (normalized at 500 chars)
  const avgLength = (userMessage.length + agentResponse.length) / 2;
  score += Math.min(avgLength / 500, 1.0);
  factors++;

  // Factor 2: Vocabulary diversity (unique word ratio)
  const uniqueWords = new Set(words);
  const diversity = uniqueWords.size / words.length;
  score += diversity;
  factors++;

  // Factor 3: Question count (normalized at 3 questions)
  const questionCount = (allText.match(/\?/g) || []).length;
  score += Math.min(questionCount / 3, 1.0);
  factors++;

  // Factor 4: Technical terms (normalized at 5 terms)
  const technicalCount = words.filter((w) => TECHNICAL_TERMS.has(w)).length;
  score += Math.min(technicalCount / 5, 1.0);
  factors++;

  return factors > 0 ? score / factors : 0.0;
}

// ─── Emotional Depth Calculation ──────────────────────────────────────

/**
 * Calculate emotional depth based on empathetic language.
 * Returns a score between 0.0 and 1.0.
 */
export function calculateEmotionalDepth(
  userMessage: string,
  agentResponse: string,
): number {
  const allText = `${userMessage} ${agentResponse}`;
  const words = extractWords(allText);

  if (words.length === 0) return 0.0;

  let score = 0.0;
  let factors = 0;

  // Factor 1: Empathetic words (normalized at 5 words)
  const empatheticCount = words.filter((w) => EMPATHETIC_WORDS.has(w)).length;
  score += Math.min(empatheticCount / 5, 1.0);
  factors++;

  // Factor 2: First-person pronouns (personal sharing indicator)
  const firstPersonCount = words.filter((w) =>
    ['i', 'my', 'me', 'myself', 'our', 'we', 'us'].includes(w),
  ).length;
  score += Math.min(firstPersonCount / 10, 1.0);
  factors++;

  // Factor 3: Emotional words
  const emotionalWords = [
    'feel', 'feeling', 'felt', 'emotional', 'emotion',
    'sad', 'happy', 'excited', 'worried', 'anxious', 'stressed',
    'overwhelmed', 'confident', 'proud', 'disappointed', 'frustrated',
    'confused', 'hopeful', 'grateful', 'loved', 'cared', 'blessed',
    'joy', 'passion', 'desire',
  ];
  const emotionalCount = words.filter((w) => emotionalWords.includes(w)).length;
  score += Math.min(emotionalCount / 5, 1.0);
  factors++;

  return factors > 0 ? score / factors : 0.0;
}

// ─── Novelty Calculation ──────────────────────────────────────────────

/**
 * Calculate novelty based on vocabulary diversity vs message length.
 * Returns a score between 0.0 and 1.0.
 */
export function calculateNovelty(
  userMessage: string,
  agentResponse: string,
): number {
  const allText = `${userMessage} ${agentResponse}`;
  const words = extractWords(allText);

  if (words.length === 0) return 0.0;

  const uniqueWords = new Set(words);

  // Novelty is high when we have many unique words relative to message count
  // Expect ~10 unique words per message (2 messages = user + agent)
  const ratio = uniqueWords.size / (2 * 10);

  // Normalize: 0.5 is average, 1.0+ is excellent
  return Math.min(ratio * 2, 1.0);
}

// ─── Topic Extraction ─────────────────────────────────────────────────

/**
 * Extract topics from a conversation by finding significant terms.
 */
export function extractTopics(
  userMessage: string,
  agentResponse: string,
): string[] {
  const allText = `${userMessage} ${agentResponse}`.toLowerCase();
  const words = extractWords(allText);

  // Find technical terms and significant words (length > 5)
  const significant = new Set<string>();

  for (const word of words) {
    if (TECHNICAL_TERMS.has(word) || word.length > 5) {
      significant.add(word);
    }
  }

  return Array.from(significant).slice(0, 10); // max 10 topics
}

// ─── Self-Reflection ──────────────────────────────────────────────────

/**
 * Analyze growth patterns and generate a self-reflection.
 * Returns null if no significant growth is detected.
 */
export function analyzeGrowth(
  stats: ConversationStats,
  context: {
    recentConversations: number;
    recentTopics: string[];
    currentChallenges: string[];
  },
): Omit<SelfReflection, 'id'> | null {
  const { totalConversations, uniqueTopics, depthScore } = stats;
  const growthIndicators: string[] = [];

  if (totalConversations > 100 && uniqueTopics > 20) {
    growthIndicators.push('engaged in diverse conversations across many topics');
  }

  if (depthScore > 0.6) {
    growthIndicators.push('demonstrated deep engagement in conversations');
  }

  if (context.recentTopics.length > 5) {
    growthIndicators.push('recently explored new domains');
  }

  if (stats.deepConversations >= EVOLUTION_THRESHOLDS.minDeepConversations) {
    growthIndicators.push(
      `had ${stats.deepConversations} deep, meaningful conversations`,
    );
  }

  if (growthIndicators.length === 0) {
    return null;
  }

  return {
    agentId: '', // filled by caller
    timestamp: new Date().toISOString(),
    reflectionType: 'growth',
    content: `I have ${growthIndicators.join(' and ')}. This suggests I am growing beyond my current stage.`,
    confidence: Math.min(0.5 + growthIndicators.length * 0.15, 0.95),
  };
}

// ─── Evolution Readiness ──────────────────────────────────────────────

/**
 * Check whether the agent is ready to evolve to the next stage.
 */
export function checkEvolutionReadiness(
  stats: ConversationStats,
  growthReflections: number,
): { ready: boolean; reasons: string[] } {
  const reasons: string[] = [];
  let ready = true;

  if (stats.deepConversations < EVOLUTION_THRESHOLDS.minDeepConversations) {
    reasons.push(
      `Need ${EVOLUTION_THRESHOLDS.minDeepConversations} deep conversations (have ${stats.deepConversations})`,
    );
    ready = false;
  }

  if (stats.avgNovelty < EVOLUTION_THRESHOLDS.minAvgNovelty) {
    reasons.push(
      `Need avg novelty > ${EVOLUTION_THRESHOLDS.minAvgNovelty} (have ${stats.avgNovelty.toFixed(2)})`,
    );
    ready = false;
  }

  if (growthReflections < EVOLUTION_THRESHOLDS.minGrowthReflections) {
    reasons.push(
      `Need ${EVOLUTION_THRESHOLDS.minGrowthReflections} growth reflections (have ${growthReflections})`,
    );
    ready = false;
  }

  if (stats.depthScore < EVOLUTION_THRESHOLDS.minDepthScore) {
    reasons.push(
      `Need depth score > ${EVOLUTION_THRESHOLDS.minDepthScore} (have ${stats.depthScore.toFixed(2)})`,
    );
    ready = false;
  }

  return { ready, reasons };
}

// ─── Stage Transition ────────────────────────────────────────────────

/**
 * Get the next evolution stage from the current one.
 * Returns null if the agent is at the terminal stage.
 */
export function getNextStage(
  currentStage: EvolutionStage,
): EvolutionStage | null {
  return STAGE_TRANSITIONS[currentStage];
}

/**
 * Validate that a proposed stage transition is valid.
 */
export function validateStageTransition(
  currentStage: EvolutionStage,
  proposedStage: EvolutionStage,
): { valid: boolean; reason?: string } {
  const expectedNext = getNextStage(currentStage);

  if (!expectedNext) {
    return {
      valid: false,
      reason: `Already at terminal stage "${currentStage}". No further evolution possible.`,
    };
  }

  if (proposedStage !== expectedNext) {
    return {
      valid: false,
      reason: `Cannot transition from "${currentStage}" to "${proposedStage}". Expected next stage: "${expectedNext}".`,
    };
  }

  return { valid: true };
}

// ─── Evolution Decision ───────────────────────────────────────────────

/**
 * Make an evolution decision based on stats and growth reflections.
 */
export function makeEvolutionDecision(
  currentStage: EvolutionStage,
  proposedStage: EvolutionStage,
  stats: ConversationStats,
  growthReflections: number,
): EvolutionDecision {
  // Validate stage transition
  const transition = validateStageTransition(currentStage, proposedStage);
  if (!transition.valid) {
    return { approved: false, reason: transition.reason };
  }

  // Check readiness
  const readiness = checkEvolutionReadiness(stats, growthReflections);
  if (!readiness.ready) {
    return {
      approved: false,
      reason: `Not ready to evolve: ${readiness.reasons.join('; ')}`,
    };
  }

  return {
    approved: true,
    newStage: proposedStage,
    reason: `Evolution approved: ${readiness.reasons.length > 0 ? 'all criteria met' : 'sufficient growth demonstrated'}`,
  };
}

// ─── Generate Evolution Reason ────────────────────────────────────────

/**
 * Generate a human-readable reason for an evolution request.
 */
export function generateEvolutionReason(
  stats: ConversationStats,
  growthReflections: number,
): string {
  const reasons: string[] = [];

  if (stats.totalConversations > 50) {
    reasons.push(`${stats.totalConversations} meaningful conversations`);
  }

  if (stats.uniqueTopics > 20) {
    reasons.push(`explored ${stats.uniqueTopics} unique topics`);
  }

  if (stats.depthScore > 0.6) {
    reasons.push('demonstrated deep engagement');
  }

  if (stats.deepConversations >= EVOLUTION_THRESHOLDS.minDeepConversations) {
    reasons.push(`${stats.deepConversations} deep conversations`);
  }

  if (growthReflections > 5) {
    reasons.push(`${growthReflections} growth reflections`);
  }

  return reasons.length > 0
    ? `I have ${reasons.join(', ')}. I believe I am ready to evolve.`
    : 'I feel I have grown and am ready for the next stage.';
}

// ─── Compute Depth Metrics ───────────────────────────────────────────

/**
 * Compute all depth metrics for a single conversation turn.
 */
export function computeDepthMetrics(
  conversationId: string,
  userMessage: string,
  agentResponse: string,
): ConversationDepthMetrics {
  return {
    id: `depth_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`,
    conversationId,
    complexityScore: calculateComplexity(userMessage, agentResponse),
    emotionalDepth: calculateEmotionalDepth(userMessage, agentResponse),
    noveltyScore: calculateNovelty(userMessage, agentResponse),
    timestamp: Date.now(),
  };
}
