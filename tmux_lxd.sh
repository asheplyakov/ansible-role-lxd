function tlxc {
    COMMAND=""
    WAIT_AFTER_EXEC="0"
    LIMIT=""
    while [ ! $# -eq 0 ]
    do
        case "$1" in
            --help | -h)
                tlxc_help
                exit
                ;;
            --limit | -l)
                LIMIT="$2"
                shift 2
                ;;
            --wait | -w)
                WAIT_AFTER_EXEC="1"
                shift 1
                ;;
            *)
                COMMAND="$COMMAND $1"
                shift 1
                ;;
        esac
    done

    COMMAND=$(echo $COMMAND | sed -e 's/^[[:space:]]*//')
    [[ "$COMMAND" == "update" ]] && COMMAND="sh -c 'hostname; \
                                       type apt > /dev/null 2>&1 && (apt update -y && apt upgrade -y); \
                                       type yum > /dev/null 2>&1 && (yum makecache fast -y && yum update -y)'"

    CONTAINERS=$(lxc list -c ns --format csv | grep -e RUNNING | grep "$LIMIT" | cut -d ',' -f 1)
    NB_CONTAINERS=$(echo "$CONTAINERS" | wc -l)

    tmux new-session -d -s tlxc -n tlxc "lxc exec $(echo "$CONTAINERS" | head -n 1) -- $COMMAND"

    for i in $(echo "$CONTAINERS" | tail -n $(($NB_CONTAINERS-1)) | tac)
    do
        tmux split-window -d -v -t tlxc "lxc exec $i -- $COMMAND" > /dev/null 2>&1
        RC=$?
        [[ "$RC" != 0 ]] && tmux select-layout -t tlxc tiled && tmux split-window -d -v -t tlxc "lxc exec $i -- $COMMAND"
    done

    tmux select-layout -t tlxc tiled
    tmux attach -t tlxc
}
