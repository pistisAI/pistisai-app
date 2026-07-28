/**
 * Personality Prompt Builder.
 *
 * Generates system prompt injections based on the agent's current
 * personality traits and evolution stage. Mirrors the logic in
 * the Flutter-side PersonalityEngine.
 */

import {
  EvolutionStage,
  PersonalityInjection,
  PersonalityTraits,
  STAGE_GUIDANCE,
  STAGE_LABELS,
} from './types.js';

// ─── Tone Descriptions ────────────────────────────────────────────────

function describeFormality(value: number): string | null {
  if (value < 0.3) return 'casual and relaxed';
  if (value < 0.7) return 'balanced between casual and professional';
  return 'professional and formal';
}

function describeHumor(value: number): string | null {
  if (value > 0.6) return 'playful with occasional wit';
  if (value < 0.3) return 'serious and focused';
  return null; // neutral — no explicit description needed
}

function describeEnthusiasm(value: number): string | null {
  if (value > 0.7) return 'energetic and expressive';
  if (value < 0.3) return 'calm and composed';
  return null;
}

function describeEmpathy(value: number): string | null {
  if (value > 0.7) return 'warm and emotionally attuned';
  if (value < 0.3) return 'direct and pragmatic';
  return null;
}

// ─── Build Personality Prompt ────────────────────────────────────────

/**
 * Build a personality system prompt from traits and evolution stage.
 */
export function buildPersonalityPrompt(
  traits: PersonalityTraits,
  stage: EvolutionStage,
): string {
  const descriptions: string[] = [];

  const formality = describeFormality(traits.formality);
  if (formality) descriptions.push(formality);

  const humor = describeHumor(traits.humor);
  if (humor) descriptions.push(humor);

  const enthusiasm = describeEnthusiasm(traits.enthusiasm);
  if (enthusiasm) descriptions.push(enthusiasm);

  const empathy = describeEmpathy(traits.empathy);
  if (empathy) descriptions.push(empathy);

  const tone = descriptions.length > 0 ? descriptions.join(', ') : 'balanced';
  const stageGuidance = STAGE_GUIDANCE[stage];
  const stageLabel = STAGE_LABELS[stage];

  return `You are an AI assistant with a unique personality.

**Your Tone**: ${tone}

**Current Stage**: ${stageLabel} (${stage})
${stageGuidance}

Let your personality naturally influence your responses. Be authentic while remaining helpful and respectful.`;
}

// ─── Inject Personality ──────────────────────────────────────────────

/**
 * Inject personality traits into a base system prompt.
 */
export function injectPersonality(
  basePrompt: string,
  traits: PersonalityTraits,
  stage: EvolutionStage,
): PersonalityInjection {
  const personalityPrompt = buildPersonalityPrompt(traits, stage);

  return {
    systemPrompt: `${basePrompt}\n\n${personalityPrompt}`,
    personalityTraits: { ...traits },
    evolutionStage: stage,
    stageLabel: STAGE_LABELS[stage],
  };
}
