---
name: ai-engineering
description: Patterns for Edge Functions, Gemini integration, and robust async processing.
---

# AI Engineering Skill

This skill governs the architecture of `supabase/functions/` and interactions with LLMs (Gemini).

## 1. Edge Function Patterns
- **The Dispatcher**: Use a single Entrypoint (`index.ts`) that switches on an `action` param.
  ```typescript
  switch (action) {
    case 'generate': return handleGenerate();
    case 'verify': return handleVerify();
  }
  ```
- **Time Limits**: Edge Functions have hard timeouts (Wall time). For long ops, return 200 OK immediately and proceed asynchronously if possible (or use "Fire-and-Forget").

## 2. Async Reliability
- **EdgeRuntime.waitUntil**: Use this to keep the background process alive after sending the HTTP response.
- **Fire-and-Forget**: For heavy verification loops, dispatch a secondary async request to yourself so the user doesn't wait.

## 3. Prompt Engineering
- **Separation**: Store prompts in `prompts/` directory (e.g., `DuoPrompts.ts`). Never hardcode prompt strings in business logic.
- **Structured JSON**: Always request JSON output from Gemini and use `zod` to validate the response.
- **Retries**: Implement at least 1 retry for malformed JSON responses.

## 4. Logging & Tracing
- **GlassBox**: Use `GlassBoxLogger` for all AI operations.
- **Trace ID**: Generate a `traceId` at request start and pass it to all sub-services.
