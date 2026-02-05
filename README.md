<p align="center">
  <a href="#gh-dark-mode-only" target="_blank" rel="noopener noreferrer">
    <img src=".github/assets/night.svg" alt="gitprofiles.plugin.zsh">
  </a>

  <a href="#gh-light-mode-only" target="_blank" rel="noopener noreferrer">
    <img src=".github/assets/day.svg" alt="gitprofiles.plugin.zsh">
  </a>
</p>

Plugin for managing multiple `git` profiles.

![](.github/assets/preview.gif)

## Installation

#### [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh)

```shell
git clone https://github.com/baliestridev/gitprofiles.plugin.zsh.git $ZSH_CUSTOM/plugins/gitprofiles
```

```shell
~/.zshrc
plugins=(... gitprofiles)
```

#### [zinit](https://github.com/zdharma-continuum/zinit)

```shell
zinit light baliestridev/gitprofiles.plugin.zsh
```

#### [zi](https://github.com/z-shell/zi)

```shell
zi light baliestridev/gitprofiles.plugin.zsh
```

#### [zgenom](https://github.com/jandamm/zgenom)

```shell
zgenom load baliestridev/gitprofiles.plugin.zsh
```

#### [zplug](https://github.com/zplug/zplug)

```shell
zplug baliestridev/gitprofiles.plugin.zsh
```

#### [antidote](https://github.com/mattmc3/antidote.git)

Add the following to your .zsh_plugins.txt file for antidote:

```shell
baliestridev/gitprofiles.plugin.zsh
```

## Usage

#### Define where your profiles are stored

```sh
# ~/.zshrc

zstyle ":baliestridev:git:profile" path "$HOME/.config/git/profiles"
```

#### Add a new profile

```sh
# ~/.config/git/profiles

[profile "default"]
  name = Bruno Sales
  email = me@baliestri.dev
  # signingkey = 1234567890

[profile "work"]
  name = Bruno Sales
  email = work@baliestri.dev
  # signingkey = 1234567890
  paths = "/home/baliestri/work"

[profile "personal"]
  name = Bruno Sales
  email = personal@baliestri.dev
  # signingkey = 1234567890
  paths = "~/personal",
    "~/src/personal/*",
    "~/src/mytopsecretproject"
```

Multiple paths can be defined for a profile, separated by either newline or commas. The paths are processed in the order they are defined, with exact matches taking precedence over wild card matches. Tildes are expanded to `${HOME}`.

It is possible to get debug information by setting the `GP_DEBUG` environment variable to any value within your current session.
