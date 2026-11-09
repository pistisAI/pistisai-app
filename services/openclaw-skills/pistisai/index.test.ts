/**
 * Tests for the Pistisai Personality Skill.
 *
 * Covers:
 * - Evolution engine (complexity, emotional depth, novelty, topic extraction)
 * - Self-reflection and growth analysis
 * - Evolution readiness and decision making
 * - Personality prompt building
 * - State management (markdown persistence)
 * - Full skill handler integration
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { unlinkSync, existsSync, mkdirSync, rmSync } from 'fs';
import { writeFileSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

import {
  calculateComplexity,
  calculateEmotionalDepth,
  calculateNovelty,
  extractTopics,
  analyzeGrowth,
  checkEvolutionReadiness,
  getNextStage,
  validateStageTransition,
  makeEvolutionDecision,
  generateEvolutionReason,
  computeDepthMetrics,
} from './evolution.js';

import {
  buildPersonalityPrompt,
  injectPersonality,
} from './prompt.js';

import {
  createDefaultProfile,
  PersonalityStateManager,
} from './state.js';

import PersonalitySkill from './index.js';

import type {
  ConversationStats,
  EvolutionStage,
  PersonalityTraits,
} from './types.js';

// ─── Test Helpers ────────────────────────────────────────────────────

const defaultStats: ConversationStats = {
  totalConversations: 150,
  uniqueTopics: 30,
  avgSentiment: 0.7,
  depthScore: 0.65,
  deepConversations: 8,
  avgNovelty: 0.6,
};

function makeTempDir(): string {
  const dir = join(tmpdir(), `pistisai-test-${Date.now()}-${Math.random().toString(36).slice(2)}`);
  mkdirSync(dir, { recursive: true });
  return dir;
}

// ─── Evolution Engine Tests ────────────────────────────────────────

describe('Evolution Engine', () => {
  describe('calculateComplexity', () => {
    it('returns 0 for empty messages', () => {
      expect(calculateComplexity('', '')).toBe(0);
    });

    it('returns higher score for technical content', () => {
      const simple = calculateComplexity('Hello', 'Hi there!');
      const technical = calculateComplexity(
        'How does the transformer architecture work in machine learning?',
        'The transformer uses self-attention mechanisms to process sequential data. It has encoder and decoder layers with multi-head attention.',
      );
      expect(technical).toBeGreaterThan(simple);
    });

    it('returns higher score for longer messages', () => {
      const short = calculateComplexity('Hi', 'Hello');
      const long = calculateComplexity(
        'Can you explain the differences between REST and GraphQL APIs in detail?',
        'REST uses multiple endpoints with HTTP methods while GraphQL uses a single endpoint with queries. REST returns fixed data structures whereas GraphQL lets clients specify exactly what they need.',
      );
      expect(long).toBeGreaterThan(short);
    });

    it('returns score between 0 and 1', () => {
      const score = calculateComplexity(
        'What is the capital of France?',
        'The capital of France is Paris.',
      );
      expect(score).toBeGreaterThanOrEqual(0);
      expect(score).toBeLessThanOrEqual(1);
    });
  });

  describe('calculateEmotionalDepth', () => {
    it('returns 0 for empty messages', () => {
      expect(calculateEmotionalDepth('', '')).toBe(0);
    });

    it('returns higher score for empathetic content', () => {
      const factual = calculateEmotionalDepth(
        'What time is it?',
        'It is 3 PM.',
      );
      const empathetic = calculateEmotionalDepth(
        'I feel really anxious about my presentation tomorrow.',
        'I understand you feel anxious. It is completely normal to feel that way. You have prepared well and I believe in you.',
      );
      expect(empathetic).toBeGreaterThan(factual);
    });

    it('returns score between 0 and 1', () => {
      const score = calculateEmotionalDepth(
        'I appreciate your help with this.',
        'You are welcome! I am happy to help.',
      );
      expect(score).toBeGreaterThanOrEqual(0);
      expect(score).toBeLessThanOrEqual(1);
    });
  });

  describe('calculateNovelty', () => {
    it('returns 0 for empty messages', () => {
      expect(calculateNovelty('', '')).toBe(0);
    });

    it('returns higher score for diverse vocabulary', () => {
      const repetitive = calculateNovelty(
        'Hello hello hello',
        'Hi hi hi hi',
      );
      const diverse = calculateNovelty(
        'Quantum entanglement enables instantaneous correlation between particles',
        'The phenomenon challenges our classical understanding of locality and causality in physics.',
      );
      expect(diverse).toBeGreaterThan(repetitive);
    });

    it('returns score between 0 and 1', () => {
      const score = calculateNovelty(
        'Tell me about machine learning algorithms',
        'There are supervised, unsupervised, and reinforcement learning approaches.',
      );
      expect(score).toBeGreaterThanOrEqual(0);
      expect(score).toBeLessThanOrEqual(1);
    });
  });

  describe('extractTopics', () => {
    it('extracts technical terms from conversation', () => {
      const topics = extractTopics(
        'How do I set up a Docker container?',
        'You need to create a Dockerfile and use docker build command.',
      );
      expect(topics).toContain('docker');
    });

    it('extracts significant words (length > 5)', () => {
      const topics = extractTopics(
        'What is the architecture of Kubernetes?',
        'Kubernetes uses a master-worker architecture with pods and services.',
      );
      expect(topics.length).toBeGreaterThan(0);
    });

    it('returns empty array for trivial content', () => {
      const topics = extractTopics('Hi', 'Hello');
      expect(topics).toEqual([]);
    });

    it('limits to 10 topics', () => {
      const longText = Array(20)
        .fill('architecture deployment authentication authorization')
        .join(' ');
      const topics = extractTopics(longText, longText);
      expect(topics.length).toBeLessThanOrEqual(10);
    });
  });

  describe('computeDepthMetrics', () => {
    it('returns all three metrics', () => {
      const metrics = computeDepthMetrics(
        'conv-1',
        'What is machine learning?',
        'Machine learning is a subset of artificial intelligence.',
      );
      expect(metrics.id).toContain('depth_');
      expect(metrics.conversationId).toBe('conv-1');
      expect(metrics.complexityScore).toBeGreaterThanOrEqual(0);
      expect(metrics.emotionalDepth).toBeGreaterThanOrEqual(0);
      expect(metrics.noveltyScore).toBeGreaterThanOrEqual(0);
      expect(metrics.timestamp).toBeGreaterThan(0);
    });
  });

  describe('analyzeGrowth', () => {
    it('returns null when no growth indicators', () => {
      const stats: ConversationStats = {
        totalConversations: 5,
        uniqueTopics: 2,
        avgSentiment: 0.5,
        depthScore: 0.1,
        deepConversations: 0,
        avgNovelty: 0.2,
      };
      const result = analyzeGrowth(stats, {
        recentConversations: 1,
        recentTopics: [],
        currentChallenges: [],
      });
      expect(result).toBeNull();
    });

    it('returns reflection when growth detected', () => {
      const result = analyzeGrowth(defaultStats, {
        recentConversations: 10,
        recentTopics: ['docker', 'kubernetes', 'react', 'api', 'database', 'auth'],
        currentChallenges: ['scaling', 'performance'],
      });
      expect(result).not.toBeNull();
      expect(result!.reflectionType).toBe('growth');
      expect(result!.confidence).toBeGreaterThan(0.5);
    });

    it('increases confidence with more indicators', () => {
      const low = analyzeGrowth(
        { ...defaultStats, deepConversations: 5 },
        { recentConversations: 5, recentTopics: ['a', 'b', 'c'], currentChallenges: [] },
      );
      const high = analyzeGrowth(
        { ...defaultStats, deepConversations: 10 },
        { recentConversations: 20, recentTopics: ['a', 'b', 'c', 'd', 'e', 'f'], currentChallenges: ['x'] },
      );
      expect(high!.confidence).toBeGreaterThanOrEqual(low!.confidence);
    });
  });

  describe('checkEvolutionReadiness', () => {
    it('returns ready when all thresholds met', () => {
      const result = checkEvolutionReadiness(defaultStats, 5);
      expect(result.ready).toBe(true);
      expect(result.reasons).toEqual([]);
    });

    it('returns not ready when deep conversations insufficient', () => {
      const stats = { ...defaultStats, deepConversations: 2 };
      const result = checkEvolutionReadiness(stats, 5);
      expect(result.ready).toBe(false);
      expect(result.reasons.some((r) => r.includes('deep conversations'))).toBe(true);
    });

    it('returns not ready when novelty too low', () => {
      const stats = { ...defaultStats, avgNovelty: 0.3 };
      const result = checkEvolutionReadiness(stats, 5);
      expect(result.ready).toBe(false);
      expect(result.reasons.some((r) => r.includes('novelty'))).toBe(true);
    });

    it('returns not ready when growth reflections insufficient', () => {
      const result = checkEvolutionReadiness(defaultStats, 0);
      expect(result.ready).toBe(false);
      expect(result.reasons.some((r) => r.includes('reflections'))).toBe(true);
    });

    it('returns not ready when depth score too low', () => {
      const stats = { ...defaultStats, depthScore: 0.1 };
      const result = checkEvolutionReadiness(stats, 5);
      expect(result.ready).toBe(false);
      expect(result.reasons.some((r) => r.includes('depth'))).toBe(true);
    });
  });

  describe('getNextStage', () => {
    it('returns next stage in sequence', () => {
      expect(getNextStage('curious_explorer')).toBe('knowledge_seeker');
      expect(getNextStage('knowledge_seeker')).toBe('wise_companion');
      expect(getNextStage('wise_companion')).toBe('enlightened_guide');
    });

    it('returns null for terminal stage', () => {
      expect(getNextStage('enlightened_guide')).toBeNull();
    });
  });

  describe('validateStageTransition', () => {
    it('accepts valid transitions', () => {
      const result = validateStageTransition('curious_explorer', 'knowledge_seeker');
      expect(result.valid).toBe(true);
    });

    it('rejects invalid transitions', () => {
      const result = validateStageTransition('curious_explorer', 'enlightened_guide');
      expect(result.valid).toBe(false);
      expect(result.reason).toContain('Cannot transition');
    });

    it('rejects transitions from terminal stage', () => {
      const result = validateStageTransition('enlightened_guide', 'curious_explorer');
      expect(result.valid).toBe(false);
      expect(result.reason).toContain('terminal stage');
    });
  });

  describe('makeEvolutionDecision', () => {
    it('approves when all criteria met', () => {
      const decision = makeEvolutionDecision(
        'curious_explorer',
        'knowledge_seeker',
        defaultStats,
        5,
      );
      expect(decision.approved).toBe(true);
      expect(decision.newStage).toBe('knowledge_seeker');
    });

    it('denies when stage transition invalid', () => {
      const decision = makeEvolutionDecision(
        'curious_explorer',
        'enlightened_guide',
        defaultStats,
        5,
      );
      expect(decision.approved).toBe(false);
    });

    it('denies when readiness criteria not met', () => {
      const stats = { ...defaultStats, deepConversations: 0, avgNovelty: 0.1 };
      const decision = makeEvolutionDecision(
        'curious_explorer',
        'knowledge_seeker',
        stats,
        0,
      );
      expect(decision.approved).toBe(false);
      expect(decision.reason).toContain('Not ready');
    });
  });

  describe('generateEvolutionReason', () => {
    it('generates reason with stats', () => {
      const reason = generateEvolutionReason(defaultStats, 6);
      expect(reason).toContain('150 meaningful conversations');
      expect(reason).toContain('30 unique topics');
      expect(reason).toContain('8 deep conversations');
      expect(reason).toContain('6 growth reflections');
    });

    it('generates fallback reason with minimal stats', () => {
      const stats: ConversationStats = {
        totalConversations: 5,
        uniqueTopics: 2,
        avgSentiment: 0.5,
        depthScore: 0.1,
        deepConversations: 0,
        avgNovelty: 0.2,
      };
      const reason = generateEvolutionReason(stats, 0);
      expect(reason).toBe('I feel I have grown and am ready for the next stage.');
    });
  });
});

// ─── Prompt Builder Tests ────────────────────────────────────────────

describe('Prompt Builder', () => {
  const defaultTraits: PersonalityTraits = {
    formality: 0.5,
    humor: 0.3,
    enthusiasm: 0.6,
    empathy: 0.7,
  };

  describe('buildPersonalityPrompt', () => {
    it('includes stage guidance', () => {
      const prompt = buildPersonalityPrompt(defaultTraits, 'curious_explorer');
      expect(prompt).toContain('Curious Explorer');
      expect(prompt).toContain('early stages of development');
    });

    it('includes tone description', () => {
      const prompt = buildPersonalityPrompt(defaultTraits, 'knowledge_seeker');
      expect(prompt).toContain('Your Tone');
    });

    it('adapts to high formality', () => {
      const formal: PersonalityTraits = {
        ...defaultTraits,
        formality: 0.9,
      };
      const prompt = buildPersonalityPrompt(formal, 'wise_companion');
      expect(prompt).toContain('professional and formal');
    });

    it('adapts to high humor', () => {
      const playful: PersonalityTraits = {
        ...defaultTraits,
        humor: 0.8,
      };
      const prompt = buildPersonalityPrompt(playful, 'enlightened_guide');
      expect(prompt).toContain('playful with occasional wit');
    });

    it('adapts to high enthusiasm', () => {
      const energetic: PersonalityTraits = {
        ...defaultTraits,
        enthusiasm: 0.9,
      };
      const prompt = buildPersonalityPrompt(energetic, 'curious_explorer');
      expect(prompt).toContain('energetic and expressive');
    });

    it('adapts to high empathy', () => {
      const warm: PersonalityTraits = {
        ...defaultTraits,
        empathy: 0.9,
      };
      const prompt = buildPersonalityPrompt(warm, 'knowledge_seeker');
      expect(prompt).toContain('warm and emotionally attuned');
    });
  });

  describe('injectPersonality', () => {
    it('appends personality to base prompt', () => {
      const result = injectPersonality(
        'You are a helpful assistant.',
        defaultTraits,
        'curious_explorer',
      );
      expect(result.systemPrompt).toContain('You are a helpful assistant.');
      expect(result.systemPrompt).toContain('Your Tone');
      expect(result.evolutionStage).toBe('curious_explorer');
      expect(result.stageLabel).toBe('Curious Explorer');
    });

    it('preserves trait values', () => {
      const result = injectPersonality('', defaultTraits, 'knowledge_seeker');
      expect(result.personalityTraits.formality).toBe(0.5);
      expect(result.personalityTraits.humor).toBe(0.3);
      expect(result.personalityTraits.enthusiasm).toBe(0.6);
      expect(result.personalityTraits.empathy).toBe(0.7);
    });
  });
});

// ─── State Manager Tests ─────────────────────────────────────────────

describe('PersonalityStateManager', () => {
  let tempDir: string;
  let manager: PersonalityStateManager;

  beforeEach(() => {
    tempDir = makeTempDir();
    manager = new PersonalityStateManager(
      join(tempDir, 'personality.db'),
      tempDir,
    );
  });

  afterEach(() => {
    manager.disconnect();
    rmSync(tempDir, { recursive: true, force: true });
  });

  describe('createDefaultProfile', () => {
    it('creates profile with default values', () => {
      const profile = createDefaultProfile('test-agent');
      expect(profile.agentId).toBe('test-agent');
      expect(profile.agentName).toBe('Pistisai');
      expect(profile.evolutionStage).toBe('curious_explorer');
      expect(profile.traits.formality).toBe(0.5);
      expect(profile.traits.humor).toBe(0.3);
      expect(profile.traits.enthusiasm).toBe(0.6);
      expect(profile.traits.empathy).toBe(0.7);
      expect(profile.conversationCount).toBe(0);
      expect(profile.depthScore).toBe(0);
    });
  });

  describe('markdown persistence', () => {
    it('saves and loads personality from markdown', async () => {
      const profile = createDefaultProfile('test-agent');
      await manager.savePersonality(profile);

      const loaded = await manager.loadPersonality('test-agent');
      expect(loaded).not.toBeNull();
      expect(loaded!.agentId).toBe('test-agent');
      expect(loaded!.traits.formality).toBe(0.5);
    });

    it('creates personality.md file', async () => {
      const profile = createDefaultProfile('test-agent');
      await manager.savePersonality(profile);

      const filePath = join(tempDir, 'personality.md');
      expect(existsSync(filePath)).toBe(true);
    });

    it('returns null for non-existent profile', async () => {
      const loaded = await manager.loadPersonality('non-existent');
      expect(loaded).toBeNull();
    });
  });
});

// ─── Integration Tests ──────────────────────────────────────────────

describe('PersonalitySkill Integration', () => {
  let tempDir: string;
  let skill: PersonalitySkill;

  beforeEach(async () => {
    tempDir = makeTempDir();
    skill = new PersonalitySkill();
    await skill.onLoad({
      agentId: 'test-agent',
      agentName: 'TestBot',
      markdownPath: tempDir,
      autoEvolve: true,
    });
  });

  afterEach(async () => {
    await skill.onUnload();
    rmSync(tempDir, { recursive: true, force: true });
  });

  describe('initialization', () => {
    it('creates default profile on first load', async () => {
      const result = await skill.handleMessage({
        type: 'get_personality',
        payload: {},
      });
      expect(result.type).toBe('personality');
      expect((result.payload as any).agentName).toBe('TestBot');
      expect((result.payload as any).evolutionStage).toBe('curious_explorer');
    });
  });

  describe('get_personality', () => {
    it('returns current personality', async () => {
      const result = await skill.handleMessage({
        type: 'get_personality',
        payload: {},
      });
      expect(result.type).toBe('personality');
      expect((result.payload as any).traits).toBeDefined();
      expect((result.payload as any).traits.formality).toBe(0.5);
    });
  });

  describe('inject_personality', () => {
    it('injects personality into base prompt', async () => {
      const result = await skill.handleMessage({
        type: 'inject_personality',
        payload: { basePrompt: 'You are a helpful assistant.' },
      });
      expect(result.type).toBe('personality_injected');
      expect((result.payload as any).systemPrompt).toContain('You are a helpful assistant.');
      expect((result.payload as any).systemPrompt).toContain('Your Tone');
    });
  });

  describe('track_conversation', () => {
    it('tracks conversation and returns metrics', async () => {
      const result = await skill.handleMessage({
        type: 'track_conversation',
        payload: {
          userMessage: 'What is machine learning?',
          agentResponse: 'Machine learning is a subset of AI that enables systems to learn from data.',
          conversationId: 'conv-1',
        },
      });
      expect(result.type).toBe('conversation_tracked');
      expect((result.payload as any).metrics).toBeDefined();
      expect((result.payload as any).metrics.complexityScore).toBeGreaterThan(0);
      expect((result.payload as any).conversationCount).toBe(1);
    });
  });

  describe('update_traits', () => {
    it('updates specified traits', async () => {
      const result = await skill.handleMessage({
        type: 'update_traits',
        payload: { traits: { formality: 0.9, humor: 0.1 } },
      });
      expect(result.type).toBe('traits_updated');
      expect((result.payload as any).traits.formality).toBe(0.9);
      expect((result.payload as any).traits.humor).toBe(0.1);
      // Unchanged traits preserved
      expect((result.payload as any).traits.enthusiasm).toBe(0.6);
    });

    it('clamps values to 0-1 range', async () => {
      const result = await skill.handleMessage({
        type: 'update_traits',
        payload: { traits: { formality: 5.0, humor: -1.0 } },
      });
      expect((result.payload as any).traits.formality).toBe(1.0);
      expect((result.payload as any).traits.humor).toBe(0.0);
    });
  });

  describe('update_agent_name', () => {
    it('updates agent name', async () => {
      const result = await skill.handleMessage({
        type: 'update_agent_name',
        payload: { name: 'NewName' },
      });
      expect(result.type).toBe('agent_name_updated');
      expect((result.payload as any).agentName).toBe('NewName');
    });
  });

  describe('self_reflect', () => {
    it('returns null reflection with no conversations', async () => {
      const result = await skill.handleMessage({
        type: 'self_reflect',
        payload: {
          recentConversations: 0,
          recentTopics: [],
          currentChallenges: [],
        },
      });
      expect(result.type).toBe('self_reflection');
      expect((result.payload as any).reflection).toBeNull();
    });
  });

  describe('check_readiness', () => {
    it('returns not ready with no conversations', async () => {
      const result = await skill.handleMessage({
        type: 'check_readiness',
        payload: {},
      });
      expect(result.type).toBe('readiness');
      expect((result.payload as any).ready).toBe(false);
      expect((result.payload as any).nextStage).toBe('knowledge_seeker');
    });
  });

  describe('request_evolution', () => {
    it('denies evolution with no conversations', async () => {
      const result = await skill.handleMessage({
        type: 'request_evolution',
        payload: { proposedStage: 'knowledge_seeker' },
      });
      expect(result.type).toBe('evolution_result');
      expect((result.payload as any).approved).toBe(false);
    });
  });

  describe('get_stats', () => {
    it('returns stats with profile and metrics', async () => {
      const result = await skill.handleMessage({
        type: 'get_stats',
        payload: {},
      });
      expect(result.type).toBe('stats');
      expect((result.payload as any).profile).toBeDefined();
      expect((result.payload as any).stats).toBeDefined();
      expect((result.payload as any).reflectionCount).toBe(0);
    });
  });

  describe('unknown message type', () => {
    it('returns error for unknown type', async () => {
      const result = await skill.handleMessage({
        type: 'unknown_type',
        payload: {},
      });
      expect(result.type).toBe('error');
    });
  });
});
