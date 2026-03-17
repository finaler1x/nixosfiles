{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    shell = "${pkgs.zsh}/bin/zsh";
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      continuum
    ];

    extraConfig = ''
      # Split mit | und -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Pane wechseln mit Alt+Pfeiltasten
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Pane resize mit Ctrl+Pfeiltasten
      bind -n C-Left resize-pane -L 2
      bind -n C-Right resize-pane -R 2
      bind -n C-Up resize-pane -U 2
      bind -n C-Down resize-pane -D 2

      # Reload config
      bind r source-file ~/.tmux.conf \; display "Reloaded!"

      # Statusbar
      set -g status-position top
      set -g status-style 'bg=default,fg=white'
      set -g status-left '#[fg=blue,bold] #S '
      set -g status-right '#[fg=white]%H:%M '
    '';
  };
}
