-- AI providers and models. Nothing is read from the environment except the
-- key variable each provider names here: no OPENAI_BASE_URL, no guessing.
--
-- A model is written provider/model-id. The model id is whatever the
-- provider calls it and may contain slashes itself:
--   openrouter/deepseek/deepseek-v4.1-flash
--   openrouter/openrouter/free
--
-- Every provider here speaks the OpenAI chat completions API
-- (<base_url>/chat/completions, and <base_url>/models for the model list).
-- A provider may add `system`, text put in front of every system prompt
-- sent to it.

return {
	providers = {
		openrouter = {
			base_url = 'https://openrouter.ai/api/v1',
			key_env = 'OPENROUTER_API_KEY',
		},
		gemini = {
			base_url = 'https://generativelanguage.googleapis.com/v1beta/openai',
			key_env = 'GEMINI_API_KEY',
		},
		-- deeprelay = {
		-- 	base_url = 'https://…/v1',
		-- 	key_env = 'DEEPRELAY_API_KEY',
		-- },
	},

	-- The model each mode uses until :AIModel changes it for the session.
	models = {
		oneshot = 'openrouter/openrouter/free',
	},

	-- At most this much of the file is sent as context (about 4 characters
	-- per token), and never more than half the model's context window.
	context_chars = 24000,
}
