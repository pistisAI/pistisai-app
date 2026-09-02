/**
 * Personality State Manager.
 *
 * Manages persistence of personality state across sessions.
 * Supports two backends:
 * 1. Drift/SQLite database (primary) — accessed via sql.js
 * 2. Markdown files (fallback) — for offline/portable mode
 *
 * Mirrors the Flutter-side MarkdownSyncService and PersonalityEngine.
 */

import { readFile, writeFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import initSqlJs, { Database } from 'sql.js';

import {
  ConversationMemory,
  ConversationStats,
  EvolutionStage,
  PersonalityProfile,
  PersonalityTraits,
  SelfReflection,
} from './types.js';

// ─── Default Profile ─────────────────────────────────────────────────

export function createDefaultProfile(agentId: string): PersonalityProfile {
  const now = new Date().toISOString();
  return {
    agentId,
    agentName: 'Pistisai',
    traits: {
      formality: 0.5,
      humor: 0.3,
      enthusiasm: 0.6,
      empathy: 0.7,
    },
    evolutionStage: 'curious_explorer',
    conversationCount: 0,
    depthScore: 0.0,
    createdAt: now,
    updatedAt: now,
  };
}

// ─── State Manager ────────────────────────────────────────────────────

export class PersonalityStateManager {
  private db: Database | null = null;
  private dbPath: string;
  private markdownPath: string;
  private sqlJsReady = false;
  private SqlJsDatabase: any = null;
  private useMarkdownFallback = false;

  constructor(
    dbPath: string = '/tmp/drift/personality.db',
    markdownPath: string = '.',
  ) {
    this.dbPath = dbPath;
    this.markdownPath = markdownPath;
  }

  // ─── Connection ──────────────────────────────────────────────────

  /**
   * Connect to the database. Falls back to markdown if unavailable.
   */
  async connect(): Promise<boolean> {
    try {
      if (!this.sqlJsReady) {
        const initSqlJsResult = await initSqlJs();
        this.SqlJsDatabase = initSqlJsResult.Database;
        this.sqlJsReady = true;
      }

      const fs = await import('fs/promises');
      try {
        const buffer = await fs.readFile(this.dbPath);
        this.db = new this.SqlJsDatabase(buffer);
      } catch {
        this.db = new this.SqlJsDatabase();
      }

      // Ensure tables exist
      this.ensureTables();
      this.useMarkdownFallback = false;
      return true;
    } catch (error) {
      console.error('[PersonalityStateManager] DB connect failed, using markdown fallback:', error);
      this.useMarkdownFallback = true;
      return false;
    }
  }

  private ensureTables(): void {
    if (!this.db) return;

    this.db.run(`
      CREATE TABLE IF NOT EXISTS personality_profiles (
        agent_id TEXT PRIMARY KEY,
        agent_name TEXT NOT NULL DEFAULT 'Pistisai',
        formality REAL NOT NULL DEFAULT 0.5,
        humor REAL NOT NULL DEFAULT 0.3,
        enthusiasm REAL NOT NULL DEFAULT 0.6,
        empathy REAL NOT NULL DEFAULT 0.7,
        evolution_stage TEXT NOT NULL DEFAULT 'curious_explorer',
        conversation_count INTEGER NOT NULL DEFAULT 0,
        depth_score REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS conversation_memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        agent_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        user_message TEXT NOT NULL,
        agent_response TEXT NOT NULL,
        sentiment_score REAL,
        topics TEXT DEFAULT '[]'
      )
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS self_reflections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        agent_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        reflection_type TEXT NOT NULL,
        content TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0.5
      )
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS conversation_depth_metrics (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        complexity_score REAL NOT NULL DEFAULT 0.0,
        emotional_depth REAL NOT NULL DEFAULT 0.0,
        novelty_score REAL NOT NULL DEFAULT 0.0,
        timestamp INTEGER NOT NULL
      )
    `);
  }

  disconnect(): void {
    if (this.db) {
      this.db.close();
      this.db = null;
    }
  }

  isConnected(): boolean {
    return this.db !== null && !this.useMarkdownFallback;
  }

  // ─── Personality Profile ──────────────────────────────────────────

  async loadPersonality(agentId: string): Promise<PersonalityProfile | null> {
    // Try DB first
    if (!this.useMarkdownFallback) {
      const fromDb = this.loadFromDb(agentId);
      if (fromDb) return fromDb;
    }
    // Fall back to markdown
    return this.loadFromMarkdown(agentId);
  }

  async savePersonality(profile: PersonalityProfile): Promise<void> {
    if (!this.useMarkdownFallback) {
      this.saveToDb(profile);
    }
    await this.saveToMarkdown(profile);
  }

  private loadFromDb(agentId: string): PersonalityProfile | null {
    if (!this.db) return null;

    try {
      const stmt = this.db.prepare(
        'SELECT * FROM personality_profiles WHERE agent_id = ?',
      );
      stmt.bind([agentId]);

      if (!stmt.step()) {
        stmt.free();
        return null;
      }

      const result = stmt.getAsObject() as any;
      stmt.free();

      if (!result || Object.keys(result).length === 0) {
        return null;
      }

      return {
        agentId: result.agent_id,
        agentName: result.agent_name,
        traits: {
          formality: result.formality ?? 0.5,
          humor: result.humor ?? 0.3,
          enthusiasm: result.enthusiasm ?? 0.6,
          empathy: result.empathy ?? 0.7,
        },
        evolutionStage: (result.evolution_stage as EvolutionStage) || 'curious_explorer',
        conversationCount: result.conversation_count ?? 0,
        depthScore: result.depth_score ?? 0.0,
        createdAt: result.created_at || new Date().toISOString(),
        updatedAt: result.updated_at || new Date().toISOString(),
      };
    } catch (error) {
      console.error('[PersonalityStateManager] Failed to load from DB:', error);
      return null;
    }
  }

  private saveToDb(profile: PersonalityProfile): void {
    if (!this.db) return;

    try {
      const existing = this.loadFromDb(profile.agentId);
      const now = new Date().toISOString();

      if (existing) {
        this.db.run(
          `UPDATE personality_profiles
           SET agent_name = ?, formality = ?, humor = ?,
               enthusiasm = ?, empathy = ?,
               evolution_stage = ?, conversation_count = ?,
               depth_score = ?, updated_at = ?
           WHERE agent_id = ?`,
          [
            profile.agentName,
            profile.traits.formality,
            profile.traits.humor,
            profile.traits.enthusiasm,
            profile.traits.empathy,
            profile.evolutionStage,
            profile.conversationCount,
            profile.depthScore,
            now,
            profile.agentId,
          ],
        );
      } else {
        this.db.run(
          `INSERT INTO personality_profiles
           (agent_id, agent_name, formality, humor, enthusiasm, empathy,
            evolution_stage, conversation_count, depth_score, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            profile.agentId,
            profile.agentName,
            profile.traits.formality,
            profile.traits.humor,
            profile.traits.enthusiasm,
            profile.traits.empathy,
            profile.evolutionStage,
            profile.conversationCount,
            profile.depthScore,
            now,
            now,
          ],
        );
      }
    } catch (error) {
      console.error('[PersonalityStateManager] Failed to save to DB:', error);
    }
  }

  // ─── Markdown Persistence ─────────────────────────────────────────

  private async loadFromMarkdown(agentId: string): Promise<PersonalityProfile | null> {
    const path = `${this.markdownPath}/personality.md`;

    if (!existsSync(path)) {
      return null;
    }

    try {
      const content = await readFile(path, 'utf-8');
      return this.parseMarkdownProfile(content, agentId);
    } catch {
      return null;
    }
  }

  private parseMarkdownProfile(content: string, agentId: string): PersonalityProfile {
    const extract = (key: string, defaultVal: any = null): any => {
      const match = content.match(new RegExp(`- \\*\\*${key}\\*\\*:\\s*(.+)`));
      if (!match) return defaultVal;
      const value = match[1].trim();
      const num = parseFloat(value);
      return isNaN(num) ? value : num;
    };

    const stage = extract('stage', 'curious_explorer') as EvolutionStage;

    return {
      agentId,
      agentName: extract('agentName', 'Pistisai'),
      traits: {
        formality: extract('formality', 0.5),
        humor: extract('humor', 0.3),
        enthusiasm: extract('enthusiasm', 0.6),
        empathy: extract('empathy', 0.7),
      },
      evolutionStage: stage,
      conversationCount: extract('conversationCount', 0),
      depthScore: extract('depthScore', 0.0),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
  }

  private async saveToMarkdown(profile: PersonalityProfile): Promise<void> {
    const path = `${this.markdownPath}/personality.md`;

    const content = `# Personality Profile

**Agent ID**: ${profile.agentId}
**Agent Name**: ${profile.agentName}
**Stage**: ${profile.evolutionStage}
**Conversation Count**: ${profile.conversationCount}
**Depth Score**: ${profile.depthScore.toFixed(2)}
**Updated**: ${profile.updatedAt}

## Traits

- **formality**: ${profile.traits.formality.toFixed(2)}
- **humor**: ${profile.traits.humor.toFixed(2)}
- **enthusiasm**: ${profile.traits.enthusiasm.toFixed(2)}
- **empathy**: ${profile.traits.empathy.toFixed(2)}
`;

    await mkdir(this.markdownPath, { recursive: true });
    await writeFile(path, content, 'utf-8');
  }

  // ─── Conversation Memory ──────────────────────────────────────────

  async storeMemory(memory: Omit<ConversationMemory, 'id'>): Promise<void> {
    if (!this.useMarkdownFallback) {
      this.storeMemoryDb(memory);
    }
    await this.appendMarkdownMemory(memory);
  }

  private storeMemoryDb(memory: Omit<ConversationMemory, 'id'>): void {
    if (!this.db) return;

    try {
      this.db.run(
        `INSERT INTO conversation_memories
         (agent_id, timestamp, user_message, agent_response, sentiment_score, topics)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          memory.agentId,
          memory.timestamp,
          memory.userMessage,
          memory.agentResponse,
          memory.sentimentScore ?? null,
          JSON.stringify(memory.topics),
        ],
      );
    } catch (error) {
      console.error('[PersonalityStateManager] Failed to store memory:', error);
    }
  }

  private async appendMarkdownMemory(memory: Omit<ConversationMemory, 'id'>): Promise<void> {
    const path = `${this.markdownPath}/memory.md`;

    const entry = `
## ${memory.timestamp}

**User**: ${memory.userMessage}
**Agent**: ${memory.agentResponse}
**Topics**: ${memory.topics.join(', ')}
**Sentiment**: ${memory.sentimentScore?.toFixed(2) ?? 'N/A'}
`;

    await mkdir(this.markdownPath, { recursive: true });
    await writeFile(path, entry, { flag: 'a' });
  }

  // ─── Self-Reflection ─────────────────────────────────────────────

  async storeReflection(reflection: Omit<SelfReflection, 'id'>): Promise<void> {
    if (!this.useMarkdownFallback) {
      this.storeReflectionDb(reflection);
    }
    await this.appendMarkdownReflection(reflection);
  }

  private storeReflectionDb(reflection: Omit<SelfReflection, 'id'>): void {
    if (!this.db) return;

    try {
      this.db.run(
        `INSERT INTO self_reflections
         (agent_id, timestamp, reflection_type, content, confidence)
         VALUES (?, ?, ?, ?, ?)`,
        [
          reflection.agentId,
          reflection.timestamp,
          reflection.reflectionType,
          reflection.content,
          reflection.confidence,
        ],
      );
    } catch (error) {
      console.error('[PersonalityStateManager] Failed to store reflection:', error);
    }
  }

  private async appendMarkdownReflection(
    reflection: Omit<SelfReflection, 'id'>,
  ): Promise<void> {
    const path = `${this.markdownPath}/context.md`;

    const entry = `
## ${reflection.timestamp}

**Type**: ${reflection.reflectionType}
**Confidence**: ${reflection.confidence.toFixed(2)}

${reflection.content}
`;

    await mkdir(this.markdownPath, { recursive: true });
    await writeFile(path, entry, { flag: 'a' });
  }

  // ─── Conversation Stats ──────────────────────────────────────────

  getConversationStats(agentId: string): ConversationStats {
    if (this.useMarkdownFallback) {
      return {
        totalConversations: 0,
        uniqueTopics: 0,
        avgSentiment: 0.5,
        depthScore: 0,
        deepConversations: 0,
        avgNovelty: 0,
      };
    }

    return this.getStatsFromDb(agentId);
  }

  private getStatsFromDb(agentId: string): ConversationStats {
    if (!this.db) {
      return {
        totalConversations: 0,
        uniqueTopics: 0,
        avgSentiment: 0.5,
        depthScore: 0,
        deepConversations: 0,
        avgNovelty: 0,
      };
    }

    try {
      // Total conversations
      const totalStmt = this.db.prepare(
        'SELECT COUNT(*) as count FROM conversation_memories WHERE agent_id = ?',
      );
      totalStmt.bind([agentId]);
      const totalResult = totalStmt.step() ? (totalStmt.getAsObject() as any) : { count: 0 };
      totalStmt.free();
      const total = totalResult.count ?? 0;

      // Average sentiment
      const sentimentStmt = this.db.prepare(
        `SELECT AVG(sentiment_score) as avg
         FROM conversation_memories
         WHERE agent_id = ? AND sentiment_score IS NOT NULL`,
      );
      sentimentStmt.bind([agentId]);
      const sentimentResult = sentimentStmt.step() ? (sentimentStmt.getAsObject() as any) : { avg: 0.5 };
      sentimentStmt.free();
      const avgSentiment = sentimentResult.avg ?? 0.5;

      // Depth metrics
      const depthStmt = this.db.prepare(
        `SELECT complexity_score, novelty_score
         FROM conversation_depth_metrics
         ORDER BY timestamp DESC
         LIMIT 100`,
      );
      const depthRows: any[] = [];
      depthStmt.bind([]);
      while (depthStmt.step()) {
        depthRows.push(depthStmt.getAsObject());
      }
      depthStmt.free();

      const deepConversations = depthRows.filter(
        (r) => r.complexity_score > 0.7,
      ).length;

      const avgNovelty =
        depthRows.length > 0
          ? depthRows.reduce((sum, r) => sum + r.novelty_score, 0) /
            depthRows.length
          : 0;

      const depthScore =
        depthRows.length > 0
          ? Math.min(
              depthRows.reduce((sum, r) => sum + r.complexity_score, 0) /
                depthRows.length,
              1,
            )
          : 0;

      return {
        totalConversations: total,
        uniqueTopics: 0, // Simplified — full topic extraction is complex in sql.js
        avgSentiment,
        depthScore,
        deepConversations,
        avgNovelty,
      };
    } catch (error) {
      console.error('[PersonalityStateManager] Failed to get stats:', error);
      return {
        totalConversations: 0,
        uniqueTopics: 0,
        avgSentiment: 0.5,
        depthScore: 0,
        deepConversations: 0,
        avgNovelty: 0,
      };
    }
  }

  getRecentReflections(agentId: string, limit: number = 20): SelfReflection[] {
    if (this.useMarkdownFallback || !this.db) return [];

    try {
      const stmt = this.db.prepare(
        `SELECT * FROM self_reflections
         WHERE agent_id = ?
         ORDER BY timestamp DESC
         LIMIT ?`,
      );

      stmt.bind([agentId, limit]);
      const results: any[] = [];
      while (stmt.step()) {
        results.push(stmt.getAsObject());
      }
      stmt.free();

      return results.map((row) => ({
        id: row.id,
        agentId: row.agent_id,
        timestamp: row.timestamp,
        reflectionType: row.reflection_type,
        content: row.content,
        confidence: row.confidence,
      }));
    } catch (error) {
      console.error('[PersonalityStateManager] Failed to get reflections:', error);
      return [];
    }
  }

  // ─── Depth Metrics ───────────────────────────────────────────────

  storeDepthMetrics(metrics: {
    id: string;
    conversationId: string;
    complexityScore: number;
    emotionalDepth: number;
    noveltyScore: number;
    timestamp: number;
  }): void {
    if (this.useMarkdownFallback || !this.db) return;

    try {
      this.db.run(
        `INSERT INTO conversation_depth_metrics
         (id, conversation_id, complexity_score, emotional_depth, novelty_score, timestamp)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          metrics.id,
          metrics.conversationId,
          metrics.complexityScore,
          metrics.emotionalDepth,
          metrics.noveltyScore,
          metrics.timestamp,
        ],
      );
    } catch (error) {
      console.error('[PersonalityStateManager] Failed to store depth metrics:', error);
    }
  }
}
