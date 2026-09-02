# Pistisai Avatar Personality Skill

Provides personality-driven responses and organic evolution capabilities for OpenClaw agents.

## Architecture

```
services/openclaw-skills/pistisai/
├── SKILL.md          # This file — skill descriptor
├── package.json      # NPM package manifest
├── tsconfig.json     # TypeScript configuration
├── types.ts          # Shared type definitions & OpenClaw handler interface
├── evolution.ts      # Evolution engine — depth analysis, self-reflection, readiness
├── prompt.ts         # Personality prompt builder — trait → system prompt injection
├── state.ts          # State manager — Drift/SQLite + markdown persistence
├── index.ts          # Main handler — PersonalitySkill class (OpenClawSkillHandler)
├── index.test.ts     # Unit tests
├── drift-adapter.ts  # Legacy adapter (kept for backward compatibility)
└── node_modules/     # Dependencies
```

## Personality Traits

The agent has four personality traits (0–1 scale):

| Trait | Low (0.0–0.3) | Medium (0.4–0.6) | High (0.7–1.0) |
|-------|---------------|-----------------|----------------|
| **Formality** | Casual, relaxed, slang | Balanced mix | Professional, polished, structured |
| **Humor** | Serious, minimal jokes | Occasional wit | Playful, puns, lighthearted |
| **Enthusiasm** | Calm, measured responses | Engaged interest | High energy, expressive, excited |
| **Empathy** | Direct, factual | Understanding | Warm, supportive, emotionally aware |

## Evolution System

The agent evolves organically through meaningful conversations:

- **No XP grinding** — evolution based on conversation depth and patterns
- **Self-reflection** — agent recognizes when it has grown
- **Collaborative** — Pistisai validates evolution requests (or auto-approves)
- **Stages**: curious_explorer → knowledge_seeker → wise_companion → enlightened_guide

### Evolution Thresholds

| Criteria | Threshold |
|----------|-----------|
| Deep conversations (complexity > 0.7) | 5+ |
| Average novelty score | > 0.5 |
| Growth self-reflections | 3+ |
| Depth score | > 0.4 |

## Data Storage

- **Primary**: Drift/SQLite database (sql.js)
- **Backup**: Markdown files (personality.md, memory.md, context.md)
- **Fallback**: Markdown files used when database unavailable

## OpenClaw Skill Handler Interface

The skill implements `OpenClawSkillHandler`:

```typescript
interface OpenClawSkillHandler {
  name: string;
  description: string;
  version: string;
  onLoad(config: Record<string, unknown>): Promise<void>;
  onUnload(): Promise<void>;
  handleMessage(message: SkillMessage): Promise<SkillResponse>;
}
```

### Message Types

| Type | Payload | Response |
|------|---------|----------|
| `get_personality` | — | Current profile with traits and stage |
| `inject_personality` | `{ basePrompt }` | System prompt with personality injection |
| `track_conversation` | `{ userMessage, agentResponse, conversationId? }` | Depth metrics and topics |
| `self_reflect` | `{ recentConversations, recentTopics, currentChallenges }` | Self-reflection or null |
| `request_evolution` | `{ proposedStage }` | Evolution decision (approved/denied) |
| `update_traits` | `{ traits: { formality?, humor?, enthusiasm?, empathy? } }` | Updated traits |
| `update_agent_name` | `{ name }` | Updated agent name |
| `check_readiness` | — | Readiness status with reasons |
| `get_stats` | — | Full stats including profile and metrics |

## Usage

```typescript
import PersonalitySkill from './index.js';

const skill = new PersonalitySkill();
await skill.onLoad({
  agentId: 'my-agent',
  agentName: 'Pistisai',
  autoEvolve: true,
});

// Inject personality into a prompt
const result = await skill.handleMessage({
  type: 'inject_personality',
  payload: { basePrompt: 'You are a helpful assistant.' },
});

// Track a conversation turn
await skill.handleMessage({
  type: 'track_conversation',
  payload: {
    userMessage: 'What is machine learning?',
    agentResponse: 'Machine learning is a subset of AI...',
  },
});

// Check if ready to evolve
const readiness = await skill.handleMessage({
  type: 'check_readiness',
  payload: {},
});

// Request evolution
const evolution = await skill.handleMessage({
  type: 'request_evolution',
  payload: { proposedStage: 'knowledge_seeker' },
});
```

## Development

```bash
# Build
npm run build

# Test
npm test

# Watch mode
npm run test:watch
```
