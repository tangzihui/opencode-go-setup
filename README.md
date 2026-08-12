# opencode-go-setup

One-shot PowerShell config managers for connecting DeepSeek V4 models through
the `opencode-go` provider.

Two scripts are included:

- `OpenCodeCLI-opencodego-setup.ps1` configures the **OpenCode CLI**
- `Codex-opencodego-setup.ps1` configures the **Codex** `config.toml`

## What they do

- Menu option `1`: switch to DeepSeek V4 Flash
- Menu option `2`: switch to DeepSeek V4 Pro
- Menu option `3`: restore the config that existed before first install
- Reads `OPENCODE_API_KEY` first, otherwise prompts for the API key
- Backs up the target config before first install
- Rewrites only the model setting on later runs

## Requirements

- Windows PowerShell 5.1 or later
- A subscription/API key for OpenCode Go
- For the OpenCode CLI script: OpenCode installed and on `PATH`
- For the Codex script: Codex installed, with `%USERPROFILE%\.codex` created

## Run the Codex script from GitHub

```powershell
irm https://github.com/tangzihui/opencode-go-setup/raw/main/Codex-opencodego-setup.ps1 | iex
```

## Run the OpenCode CLI script from GitHub

```powershell
irm https://github.com/tangzihui/opencode-go-setup/raw/main/OpenCodeCLI-opencodego-setup.ps1 | iex
```

Or set the API key first so the script does not prompt:

```powershell
$env:OPENCODE_API_KEY = 'sk-your-opencode-go-api-key'
irm https://github.com/tangzihui/opencode-go-setup/raw/main/Codex-opencodego-setup.ps1 | iex
```

## Notes

- The Codex script edits `%USERPROFILE%\.codex\config.toml` and writes
  `models.json` into the same directory.
- The OpenCode CLI script edits `%APPDATA%\opencode\opencode.json` and
  `%LOCALAPPDATA%\opencode\auth.json` unless `OPENCODE_CONFIG_DIR` is set.
- Config files are backed up and can be restored with menu option `3`.
