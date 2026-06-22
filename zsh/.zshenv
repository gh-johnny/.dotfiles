# ai-profiles: API key path for tools that explicitly source it (e.g. graphify via governance skill).
# NOT sourced here — keeps ANTHROPIC_API_KEY out of the global env so Claude Code
# never detects it and never prompts to use it for the session itself.
export AI_PROFILES_APIKEY_ENV="$HOME/projects/ai-profiles/.secrets/anthropic-apikey/.env"
unset ANTHROPIC_API_KEY  # enforce — key must never leak into global env
