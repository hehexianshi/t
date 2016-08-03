#!/usr/bin/env bash

UP=$'\033[A'
DOWN=$'\033[B'
BASE_DIR='/usr/local/phpt'
BASE_VERSIONS_DIR='/usr/local/phpt/version'
BASE_VERSIONS_DOWN='/usr/local/phpt/phpdown'
VERSION='0.0.1'

log() {
    printf "  \033[36m%10s\033[0m : \033[90m%s\033[0m\n" $1 $2
}

init() {
    if [ ! -w "$BASE_DIR" ]; then
        echo "must use root(Permission denied)"
        exit 1
    fi
    if [ ! -d "$BASE_DIR" ]; then
        mkdir $BASE_DIR
        mkdir $BASE_VERSIONS_DIR
        mkdir $BASE_VERSIONS_DOWN
        cd $BASE_VERSIONS_DIR
    fi
}

display_t_version() {
    echo "$VERSION"
    exit 1
}

enter_fullscreen() {
    tput smcup
    #stty -echo 关闭回显。比如在脚本中用于输入密码时
    stty -echo
}

leave_fullscreen() {
    #tput 命令将通过 terminfo 数据库对您的终端会话进行初始化和操作。通过使用 tput，您可以更改几项终端功能，如移动或更改光标、更改文本属性，以及清除终端屏幕的特定区域
    tput rmcup
    #stty echo 打开回显.
    stty echo
}

handle_sigint() {                                                                                                                                                                   
    leave_fullscreen
    clear
    exit $?
}
     
handle_sigtstp() {
    leave_fullscreen
    kill -s SIGSTOP $$
}

version_path() {
    find "$BASE_VERSIONS_DIR" -maxdepth 1 -type d \
    | sed 's|'$BASE_VERSIONS_DIR'/||g' \
    | egrep "[0-9]+\.[0-9]+\.[0-9]+" \
    | sort -k 1
}

display_version_with_select() {
    selected=$1
    echo 
    for version in $(version_path); do
        if test "$version" = "$selected"; then
            printf "  \033[36mο\033[0m $version\033[0m\n"
        else 
            printf "    \033[90m$version\033[0m\n"
        fi
    done
    echo
}

prev_version_installed() {
    list_versions_installed | grep $selected -B 1 | head -n 1
}

next_version_installed() {
    list_versions_installed | grep $selected -A 1 | tail -n 1
}

list_versions_installed() { 
    for version in $(version_path); do
        echo $version
    done
}

check_current_version() {
    current=$(php -v |egrep "PHP [0-9]+\.[0-9]+\.[0-9]+"|cut -c5-11)
}

# do something
active() {
    local version=$1
    check_current_version 
    if test "$version" != "$current"; then 
        ln -f -s "$BASE_VERSIONS_DIR/$version" /usr/local/phpc
        if [ -f "$BASE_VERSIONS_DIR/$version/bin/php" ]; then
            ln -f -s "$BASE_VERSIONS_DIR/$version/bin/php" /usr/bin/php
        fi
    fi
    #touch "$BASE_VERSIONS_DIR/$version" 
}

display_version() {
    enter_fullscreen
    check_current_version
    clear

    display_version_with_select $current 

    trap handle_sigint INT
    trap handle_sigtstp SIGTSTP

    while true; do
        read -n 3 c
        case "$c" in
        $UP)
            clear
            #printf $(prev_version_installed)
            display_version_with_select $(prev_version_installed)
            ;;
        $DOWN)
            clear
            display_version_with_select $(next_version_installed)
            ;;
        *)
            active $selected
            leave_fullscreen
            exit
            ;;
        esac
    done
}

install() {
    local version=$1
    local has=0
    for v in $(version_path); do
        if test "$version" == "$v"; then
            has=1
        fi
    done

    if test "$has" == 1; then
        ln -f -s $BASE_VERSIONS_DIR/$version $BASE_DIR/php
        ln -s $BASE_VERSIONS_DIR/$version/bin/php /usr/bin/php
    fi

    if test "$has" == 0; then
        local name="php-"$version".tar.bz2"
        cd $BASE_VERSIONS_DOWN
        wget "http://tw1.php.net/get/php-"$version".tar.bz2/from/this/mirror" -O "$name"
        tar -jxvf $name
        mv "php-$version" $version
        cd $BASE_VERSIONS_DOWN/$version
        ./configure --prefix="$BASE_VERSIONS_DIR/$version" --enable-fpm --enable-bcmath --with-curl --with-mysql --with-mysqli --with-openssl --with-gd --enable-pcntl
        make
        make install
        ln -f -s $BASE_VERSIONS_DIR/$version $BASE_DIR/php
        ln -f -s $BASE_VERSIONS_DIR/$version/bin/php /usr/bin/php
    fi
    exit 1
}

usage() {
    cat <<-EOF
    Usage: n [option]

    Option:
        -v  output current version
        -h  display help information

    example:
        ./t 5.4.28
        ./t -v
        ./t -h
        ./t
EOF
}

init

if test $# -eq 0; then
    test -z "$(version_path)"
    display_version
else
    case $1 in
        -v) display_t_version;exit;;
        -h) usage;exit;;
        *) install $1; exit;;

    esac
fi
