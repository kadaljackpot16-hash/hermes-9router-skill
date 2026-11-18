# Install Hermes Agent with 9Router

## Order and ground rules

- Read `~/workspace/hermuse/AGENTS.md` before running anything in the hermuse kit. The kit at `~/workspace/hermuse` holds the installer, the restart scripts and the doctor script used by every step below.

- Work in this order and verify each step before moving on: 9Router first, Hermes install second, Telegram bot wiring third, gateway test fourth, public tunnel last. The tunnel never blocks the bot and can wait indefinitely.

- Ask the user for the values only they can produce: the Telegram bot token from @BotFather, their numeric Telegram ID from @userinfobot, and any API key or OAuth approval a provider needs. Never invent or reuse these from another context.

- Keep every secret in a chmod 600 file and never print its value in chat or logs. The dashboard password lives in `~/workspace/hermuse/.dashboard-pw`, the 9Router API key for Hermes in `~/workspace/hermuse/.9router-api-key`, the Telegram token and allowlist in `~/.hermes/.env`, and OAuth state in `~/.9r-state/` (chmod 700).

- Expect VM replacements to kill every process without warning. The home directory persists, processes and /tmp do not, so recheck 9Router and the gateway after any gap and restart whatever is dead.

## Install and verify 9Router

- Install 9Router globally with `npm install -g --prefix ~/.npm-global 9router`. Version 0.5.116 is the verified build on this VM and the binary lands at `~/.npm-global/bin/9router`.

- Run 9Router only through the supervisor `bash ~/workspace/hermuse/start-9router.sh`, which binds 127.0.0.1 port 20128, reads the dashboard password from `.dashboard-pw` as INITIAL_PASSWORD and restarts the process when it crashes. Restart a running instance with `bash ~/workspace/hermuse/restart-9router.sh` and allow about 15 seconds before it listens.

- Verify with `curl -s -o /dev/null -w '%{http_code}' --noproxy '*' http://127.0.0.1:20128/` and accept 307 or 200 as healthy. Localhost calls must bypass the proxy or they fail.

- Never type the literal process pattern the restart script kills by into your own `muse.exec` command line, because the kill matches your shell too. Kill stray processes by PID from `ss -ltnp` instead.

- Know that an empty 9Router is the default state: a fresh or replaced install has no connections, keys or combos in `~/.9router/db/data.sqlite` until you create them.

## Connect model providers in 9Router

- Create one API key in the 9Router dashboard for Hermes and save it to `~/workspace/hermuse/.9router-api-key` (chmod 600). Hermes uses this single key for the primary model and every fallback.

- Add API key providers through the dashboard API with a POST to /api/providers carrying provider, name and apiKey, using the dashboard session cookie. Working examples on this VM are provider gemini named AI Studio and provider openrouter named OpenRouter.

- Add OAuth providers through the paste-back flow: request /api/oauth/<provider>/authorize with redirect_uri http://localhost:20128/callback, save the returned authUrl, state and codeVerifier to `~/.9r-state/auth-<provider>.json`, send the user the authUrl, then POST the returned code to /api/oauth/<provider>/exchange with state and codeVerifier. Use a client timeout of at least 280 seconds on the exchange, because a 60 second timeout can burn a code even when the exchange later completes server side.

- Connect GitHub by its device code flow instead of paste-back. It works on this VM and serves github/gpt-4o through Copilot, but the free tier rate limits hard under load (429 user_global_rate_limited), so never leave it as the only provider.

- Skip the Gemini OAuth route (provider gemini-cli). Google rejects both saved connections with 403 VALIDATION_REQUIRED and no valid license, and retrying without a change in the Google account verification state only wastes codes.

- Use the Gemini API key route for Gemini instead, and pick gemini/gemini-3-flash-preview. The 2.5 generation returns 404 for new users, and the free tier for this model is only 20 requests per day, so treat it as a fallback rather than a primary.

- Prefer openrouter/nvidia/nemotron-3-ultra-550b-a55b:free as the primary model when an OpenRouter key is connected. The free tier allows 50 requests per day, 9Router forwards model IDs that are missing from its static catalog, and this model answered correctly through 9Router in live tests.

- Test every new connection with one real chat call through the 9Router endpoint before wiring it into Hermes. A connection that lists as active can still fail at call time, as the Gemini OAuth connections did.

- Regenerate an OAuth link when its saved state is more than a few minutes old. Antigravity and Claude paste-back links from an earlier session are stale and will fail the exchange.

## Install Hermes Agent

- Install Hermes with the official pm flow from the hermuse kit and do not substitute a manual clone or a pip install. The CLI lands at `~/.local/bin/hermes` and `hermes doctor` must finish clean before you continue.

- Diagnose a pm install that keeps failing on downloads as a cache problem, not a network problem. pm uses its own uv cache at `~/.hermes/cache/uv` and ignores UV_CACHE_DIR, so wheels you download into the normal cache stay invisible to it.

- Fix the cache problem by running a manual uv sync with UV_HTTP_TIMEOUT=600, UV_CONCURRENT_DOWNLOADS=1 and UV_RETRY=5, then merging the filled cache into `~/.hermes/cache/uv` and rerunning `python3 -m pm.cli install`. This exact path completed the install on 2026-11-10 after days of failed attempts.

- Run long installs from your own shell, never through the Hermes terminal tool. That tool times out at about 180 seconds and kills downloads mid flight.

- Accept that the lockfile targets Python 3.14 and pm provisions its own runtime. Do not fight it by forcing the system Python 3.12.

## Wire Hermes to 9Router and Telegram

- Point Hermes at 9Router as a custom provider in `~/.hermes/config.yaml` (chmod 600): provider custom, base_url http://127.0.0.1:20128/v1, api_key set to the contents of `.9router-api-key`, and default set to the chosen primary model.

- Add fallback_providers entries on the same custom provider and endpoint, ordered github/gpt-4o then gemini/gemini-3-flash-preview. Quota failures cascade fast on free tiers, so the bot needs somewhere to fall back to.

- Set `hermes config set platforms.telegram.extra.drop_pending_on_cold_boot false` so messages sent while the gateway is down get processed when it revives. Only a turn being processed at the exact second of death is lost and must be resent.

- Confirm python-telegram-bot is installed in the Hermes venv before starting the gateway. Version 22.8 is verified.

- Write the bot token and the user numeric ID into `~/.hermes/.env` (chmod 600) as TELEGRAM_BOT_TOKEN and TELEGRAM_ALLOWED_USERS. The gateway is default deny, so a silent bot almost always means the ID is missing from the allowlist.

## Run the gateway and keep it alive

- Start the gateway detached with the no_proxy exports first, because the proxy environment breaks localhost calls: `export no_proxy="localhost,127.0.0.1" NO_PROXY="localhost,127.0.0.1"`, then run `~/.local/bin/hermes gateway run` under setsid nohup appending to `~/.hermes/logs/gateway-manual.log`. Keep the no_proxy value to that minimal pair, because bracketed IPv6 entries crash httpx with an invalid port error.

- Verify startup by finding a fresh Connected to Telegram line in `~/.hermes/logs/agent.log` or the gateway log, and by `~/.local/bin/hermes gateway status` reporting a running PID.

- Keep exactly one gateway process alive. Two pollers on one bot token produce Telegram 409 conflicts, so confirm the old PID is gone before starting a replacement, and allow a slow graceful drain of more than 12 seconds.

- Test the bot with a real text message from the user. Hermes ignores /start as a platform ping by design, so silence after /start proves nothing.

- Tell the user to send one message and wait. A resend while a turn runs redirects and restarts that run, and /sethome is rejected mid turn, so the home channel can only be set while the bot is idle.

- Send the user /new when answers come back empty on a very long session. Nemotron returned empty content on a session of about 58k input tokens, old sessions stay stored in `~/.hermes/state.db`, and a fresh session fixed it without losing history.

- Guard the stack with a watchdog cron every 2 minutes that checks the 9Router HTTP code and the gateway status, restarts whatever is dead using the steps above, and reports only when something was dead and revived or failed to revive. Silence means healthy.

## Respect the hard walls of this VM

- Do not let Hermes install Playwright or Chromium for browsing. Egress from this VM goes through a proxy that rejects Chromium CONNECT tunnels (ERR_TUNNEL_CONNECTION_FAILED), so browser automation from local Chromium can never work here, and Hermes does not know this unless told.

- Do not retry ngrok or cloudflared for the public tunnel. ngrok dies with ERR_NGROK_9009 and cloudflared dies at the edge because all direct UDP is blocked at syscall level on this VM.

- Use the Cloudflare Pages plus D1 polling tunnel as the only public route: `bash ~/workspace/hermuse/scripts/setup-tunnel.sh hermuse-tunnel hermuse-db` with CLOUDFLARE_API_TOKEN passed as a transient environment variable only, then `bash ~/workspace/hermuse/restart-tunnel.sh`. The tunnel exposes the 9Router dashboard only and the bot does not need it.

- Run `bash ~/workspace/hermuse/scripts/doctor.sh` at the end of any install or repair and fix every FAIL line before calling the stack done.

## Available connectors

- Use `muse.connector_search` to find other connectors and `muse.skill_search` to find related skills.

- If nothing here fits, look on the web for a maintained API or MCP server and set it up with [Custom Connectors and MCPs](/opt/muse/skills/custom-connector-setup/SKILL.md), or build a custom connector.

## Alternatives for better results

- Add providers in order of free quota value when the user offers new keys: OpenRouter free first for volume, GitHub Copilot for quality, Gemini API key as the last fallback. Ask before adding any paid provider.

- Write the Chromium wall into Hermes own memory when the user agrees, so the bot stops burning its terminal timeouts on Playwright installs it attempts on its own.
