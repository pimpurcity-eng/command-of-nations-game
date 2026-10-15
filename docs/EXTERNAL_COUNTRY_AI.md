# Optional free-plan external country AI

Prepared in source; not activated or deployed. No provider API call has been made during this change because no Groq account key is configured.

## Provider and activation

Groq's official documentation was checked on 15 October 2026:
- https://console.groq.com/docs/rate-limits — free `openai/gpt-oss-20b` allowance is currently 1,000 requests/day, 200,000 tokens/day, 30 requests/minute and 8,000 tokens/minute. Account-specific limits can differ.
- https://console.groq.com/docs/models — GPT-OSS 20B is a production model; Llama 3.1/3.3 now show enterprise access, so those are not the free default.
- https://console.groq.com/docs/text-chat — chat completions API.

Use a **Free** Groq organization. This integration does not upgrade a plan or switch to a paid provider. Local limits are an additional guard, not a guarantee of free billing for an account the owner has separately upgraded.

Create the key in Groq Console and put it directly into the dedicated server's private environment, never into chat, source, the browser export or Android APK:

```
WM_EXTERNAL_AI=1
GROQ_API_KEY=<private key entered on server>
WM_AI_MODEL=openai/gpt-oss-20b
```

The existing Compose configuration passes these server-only variables through. The running host's deployment/environment location must be checked before applying it; no guessed remote paths or deployment changes were made. The private key is the remaining activation prerequisite.

## Below-medium rules and backup

- Default difficulty is `casual`, a little below medium. The built-in `CountryAI` is always available as the backup and tactical controller.
- Optional API plans run no more than once per country every 15 real minutes; requests are serialized with a further global delay. A reply can choose **one** action from a locally generated legal menu.
- Economy, balanced and defensive national policies are available. No aggressive-policy option is offered to this preset. Normal movement/combat remains in the game engine.
- The fallback targets at most ten armies (eight for an economy policy), reacts no faster than every 30 real seconds and issues at most two army orders per decision. It preserves the last capital garrison.
- No extra money, resources, technology or combat bonuses. Owned resources and legal prerequisites are validated by the existing server commands.
- No hidden enemy armies or orders, player messages, names, email addresses or account identifiers are sent. The request contains country, own stockpile, public war status and legal action labels.
- Human-controlled seats and Guard-protected seats cannot receive external orders. A human reconnect or Guard activation invalidates any pending response. Guard remains defence-only.
- The model cannot submit arbitrary server commands, code, shell commands or URLs: it returns indices into the prebuilt action list. Unknown IDs, malformed JSON and extra choices are ignored.
- Timeouts, quota limits, invalid output and API outages leave the built-in AI running. The local budget defaults to 96 requests and 100,000 tokens per UTC day per match and persists through server restarts. The provider's free organization quota is shared across matches; a 100-country deployment is not promised to fit that allowance.

## Validation

Focused local tests cover output validation, AI-seat ownership, reconnects, Guard, local quotas, the fixed HTTPS destination and the below-medium preset. They do not constitute live provider or gameplay-balance testing. Normal Godot 4.6 release validation, real two-player testing and deployment remain outstanding.

## Inactivity takeover

A human seat transfers to AI only after **48 real hours** since sign-in or a valid player order. WebSocket keepalive pings and game-speed changes do not reset this timer. Signing in or issuing a valid order returns control to the human. Last-activity timestamps persist as Unix time, including server downtime; legacy saves without timestamps receive a fresh 48-hour grace period. Guard mode can still be enabled before automatic takeover.
