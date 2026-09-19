# dotfiles

navairgap's Linux dotfiles with a one-command installer

> 🚧 **Status: planning** — architecture and README first, code next.

## Why

A developer's dotfiles are their second memory. This repo versions my shell, editor, terminal, and system config with an idempotent install script — reproducible machine setup in minutes.

## Planned features

- zsh + starship, neovim config, tmux, git config
- Idempotent install script (symlink or copy mode)
- Per-machine overrides via a local .zshrc.local pattern
- Documented keyboard shortcuts and plugin list

## Stack

`bash` `zsh` `neovim`

## Notes

Bootstrap order matters: shell → editor → tools.

## License

MIT, see [LICENSE](LICENSE).
