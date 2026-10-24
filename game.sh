#!/usr/bin/env bash

# REMENOS SOURCE CODE
# THIS IS WHAT MAKES THE ENTIRE GAME EVEN POSSIBLE

BEST_SCORE_FILE="$HOME/remenos/best-score"

# Load best score
if [[ -f "$BEST_SCORE_FILE" ]]; then
    BEST_SCORE=$(cat "$BEST_SCORE_FILE")
else
    BEST_SCORE=0
fi

speak() {
    if command -v say &>/dev/null; then
        say "$1"
    elif command -v espeak &>/dev/null; then
        espeak "$1"
    else
        echo "$1"
    fi
}

clear_screen() {
    printf "\033c"
}

show_intro() {
    clear_screen
    echo "======================"
    figlet "Remenos"
    echo "By Gretagen ZETA"
    echo "======================"
    echo
    echo "Memory game inspired by the 90's minigame "Simon"."
    echo
    echo "A sequence of numbers, letters and symbols will play out, remember it."
    echo "Type the sequence with your keyboard."
    echo "It gets faster every round."
    echo
    echo "Best score: $BEST_SCORE"
    echo
    
    echo
    read -p "Press Enter to start..."
}

choose_gamemode() {
    clear_screen
    echo "======================"
    figlet "Choose gamemode"
    echo "======================"
    echo
    echo "1) Classic: numbers, letters, symbols"
    echo "2) Numbers only"
    echo "3) Letters only"
    echo "4) Symbols only"
    echo "5) Hardcore: ruthless , shuts down computer on failure"
    echo
    read -p "Enter choice [1-5]: " mode_choice

    case "$mode_choice" in    
        1) MODE="classic"; CHARSET='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#=$/;?.*%[{~&]}-|@'; ;;
        2) MODE="numbers"; CHARSET='0123456789'; ;;
        3) MODE="letters"; CHARSET='ABCDEFGHIJKLMNOPQRSTUVWXYZ'; ;;
        4) MODE="symbols"; CHARSET='+!#=$/;?.*%[{~&]}-|@'; ;;
        5) MODE="hardcore"; CHARSET='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#=$/;?.*%[{~&]}-|@'; ;;
        *) echo "Invalid choice, defaulting to Classic."; MODE="classic"; CHARSET='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+!#'; ;;
    esac

    echo "You selected: $MODE"
    sleep 1
}

random_char() {
    echo "${CHARSET:RANDOM%${#CHARSET}:1}"
}

play_sound() {
    local char="$1"
    local path="$HOME/remenos/sfx"

    if [[ "$char" =~ [0-9] ]]; then
        paplay "$path/number.wav" &
    elif [[ "$char" =~ [A-Z] ]]; then
        paplay "$path/letter.wav" &
    else
        paplay "$path/symbol.wav" &
    fi
}

# Show sequence stuff
disable_input() {
    stty -echo -icanon
}

enable_input() {
    stty echo icanon
}

show_sequence() {
    disable_input
    for char in "${sequence[@]}"; do
        clear_screen
        if command -v figlet &>/dev/null; then
            center_figlet "$char"
        else
            echo "$char"
        fi
        speak_char "$char" &
        play_sound "$char"
        sleep "$delay"
        clear_screen
        sleep 0.15
    done
    enable_input
}

speak_char() {
    local c="$1"
    case "$c" in
        '+') c="plus" ;;
        '!') c="exclamation" ;;
        '#') c="hash" ;;
        '=') c="equals" ;;
        '$') c="dollar" ;;
        '/') c="slash" ;;
        '?') c="question" ;;
        '*') c="asterisk" ;;
        '%') c="percent" ;;
        '[') c="left bracket" ;;
        ']') c="right bracket" ;;
        '{') c="left brace" ;;
        '}') c="right brace" ;;
        '|') c="pipe" ;;
        '~') c="tilde" ;;
        ';') c="semicolon" ;;
        '@') c="at" ;;
        '-') c="dash" ;;
        '.') c="dot" ;;
        ',') c="comma" ;;
    esac

    # speak using system TTS (espeak)
    if command -v say &>/dev/null; then
        say "$c"
    elif command -v espeak &>/dev/null; then
        espeak "$c"
    else
        echo "$c"
    fi
}

center_figlet() {
    local text="$1"
    local figlet_output
    local term_width term_height
    local line_count padding_top

    # Get figlet output
    figlet_output=$(figlet -f big "$text")

    # Get terminal size
    read term_height term_width < <(stty size)

    # Count number of lines in figlet output
    line_count=$(echo "$figlet_output" | wc -l)

    # Calculate top padding for vertical centering
    padding_top=$(( (term_height - line_count) / 2 ))

    # Print blank lines for vertical centering
    for ((i=0;i<padding_top;i++)); do
        echo
    done

    # Print each line centered horizontally
    while IFS= read -r line; do
        # Calculate horizontal padding
        line_len=${#line}
        padding_left=$(( (term_width - line_len) / 2 ))
        printf "%*s%s\n" $padding_left "" "$line"
    done <<< "$figlet_output"
}

play_game() {
    sequence=()
    round=1
    delay=1.0
    speak "commencing sequence"

    while true; do
        # Add new character for each round
        sequence+=("$(random_char)")

        # Show sequence 
        show_sequence

        # Get user input
        read -p "Enter sequence: " input
        input=$(echo "$input" | tr 'a-z' 'A-Z')
        expected=$(printf "%s" "${sequence[@]}")

        if [[ "$input" != "$expected" ]]; then
        speak "game over" &
        center_figlet "Game Over!"
        echo "Score: $((round - 1))"

    # Update best score if necessary
    if (( round - 1 > BEST_SCORE )); then
        BEST_SCORE=$((round - 1))
        echo "$BEST_SCORE" > "$BEST_SCORE_FILE"
        echo "New best score!"
    fi

    # Hardcore mode: shuts down computer on game over
    if [[ "$MODE" == "hardcore" ]]; then
        sleep 1
        systemctl poweroff
    fi

    sleep 1
    return
fi

        # Round complete → increase round speed and decrease delay
        ((round++))
        if [[ "$MODE" == "hardcore" ]]; then
            # Aggressive speed: multiply by 0.5 each round, minimum 0.05s per character
            delay=$(awk "BEGIN {print ($delay * 0.5 > 0.05) ? $delay * 0.5 : 0.05}")
        else
            # Normal mode: multiply by 0.9, minimum 0.3s per character
            delay=$(awk "BEGIN {print ($delay * 0.90 > 0.3) ? $delay * 0.90 : 0.3}")
        fi
    done
}

clear

# Main loop
while true; do
    show_intro
    choose_gamemode
    play_game
done
