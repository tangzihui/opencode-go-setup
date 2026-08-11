# opencode-go-setup

One-shot PowerShell config manager that points OpenCode at DeepSeek V4
through the `opencode-go` provider.

## What it does

- Menu option `1`: switch OpenCode to `opencode-go/deepseek-v4-flash`
- Menu option `2`: switch OpenCode to `opencode-go/deepseek-v4-pro`
- Menu option `3`: restore the config that existed before first install
- Reads `OPENCODE_API_KEY` first, otherwise prompts for the API key
- Backs up `opencode.json` and `auth.json` before first install
- Rewrites only the `model` field on later runs

## Requirements

- Windows PowerShell 5.1 or later
- OpenCode installed and on `PATH`
- A DeepSeek API key

## Run from GitHub

```powershell
irm https://raw.githubusercontent.com/tangzihui/opencode-go-setup/main/opencode-go-setup.ps1 | iex
```

Or set the API key first so the script does not prompt:

```powershell
$env:OPENCODE_API_KEY = 'sk-your-deepseek-api-key'
irm https://raw.githubusercontent.com/tangzihui/opencode-go-setup/main/opencode-go-setup.ps1 | iex
```

## Run from a local file

```powershell
powershell -ExecutionPolicy Bypass -File .\opencode-go-setup.ps1
```

## Notes

- The script writes to `%APPDATA%\opencode\opencode.json` and
  `%LOCALAPPDATA%\opencode\auth.json` unless `OPENCODE_CONFIG_DIR` is set.
- If `opencode.jsonc` already exists, it may override the model set here.
- Config and auth files are backed up under a timestamped directory and can be
  restored with menu option `3`.
