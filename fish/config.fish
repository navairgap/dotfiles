# rice and the rest of what install.sh drops into ~/.local/bin — arch doesn't put that on the path itself
fish_add_path -g ~/.local/bin

if status is-interactive
    # starship prompt
    command -v starship &> /dev/null && starship init fish | source

    # direnv + zoxide
    command -v direnv &> /dev/null && direnv hook fish | source
    command -v zoxide &> /dev/null && zoxide init fish --cmd cd | source

    # ls, but the way i like it
    command -v eza &> /dev/null && alias ls='eza --icons --group-directories-first -1'

    # cava as dots, the pulse matrix (~/.config/cava/dots); plain bars are `command cava`
    command -v cava &> /dev/null && alias cava ~/.config/cava/dots

    # abbrs
    abbr lg 'lazygit'
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'


    # foot: a mark where every prompt starts, so it can jump between them
    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end
end
