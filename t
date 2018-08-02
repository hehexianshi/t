#!/usr/bin/env bash

UP=$'\033[A'
DOWN=$'\033[B'
BASE_DIR='/usr/local/phpt'
BASE_VERSIONS_DIR='/usr/local/phpt/version'
BASE_VERSIONS_DOWN='/usr/local/phpt/phpdown'
BASE_VERSION_PECL='/usr/local/phpt/pecl'
VERSION='0.0.1'

log() {
    printf "  \033[36m%10s\033[0m : \033[90m%s\033[0m\n" $1 $2
}

init() {
    if [ `whoami` != "root" ]; then
        echo "must use root(Permission denied)"
        exit 1
    fi


    if [ ! -d "$BASE_DIR" ]; then
        mkdir $BASE_DIR
        mkdir $BASE_VERSIONS_DIR
        mkdir $BASE_VERSIONS_DOWN
        mkdir $BASE_VERSION_PECL

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
        #ln -f -s "$BASE_VERSIONS_DIR/$version" /usr/local/phpc
        if [ -f "$BASE_VERSIONS_DIR/$version/bin/php" ]; then
            rm /usr/bin/php
            rm /usr/local/sbin/php-fpm
            ln -f -s "$BASE_VERSIONS_DIR/$version/bin/php" /usr/bin/php
            ln -f -s "$BASE_VERSIONS_DIR/$version/sbin/php-fpm" /usr/local/sbin/php-fpm
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
        rm -rf $BASE_DIR/php
        ln -s $BASE_VERSIONS_DIR/$version $BASE_DIR/php
        ln -s $BASE_VERSIONS_DIR/$version/bin/php /usr/bin/php
    fi

    if test "$has" == 0; then
        local name="php-"$version".tar.bz2"
        cd $BASE_VERSIONS_DOWN
        wget "http://php.net/get/php-"$version".tar.bz2/from/this/mirror" -O "$name"
        tar -jxvf $name
        mv "php-$version" $version
        cd $BASE_VERSIONS_DOWN/$version
        ./configure --prefix="$BASE_VERSIONS_DIR/$version" --with-config-file-path="$BASE_VERSIONS_DIR/$version/"etc --enable-fpm --enable-bcmath --with-curl --with-mysql --with-mysqli --with-openssl --with-gd --enable-pcntl --enable-debug --with-pdo-mysql --enable-soap --enable-pcntl --with-freetype-dir --with-jpeg-dir --with-png-dir --enable-gd-native-ttf --with-zip --with-mbstring 
        make
        make install

        cp $BASE_VERSIONS_DOWN/$version/php.ini-development $BASE_VERSIONS_DIR/$version/etc/php.ini
        cp $BASE_VERSIONS_DIR/$version/etc/php-fpm.conf.default $BASE_VERSIONS_DIR/$version/etc/php-fpm.conf

        rm -rf $BASE_DIR/php
        ln -f -s $BASE_VERSIONS_DIR/$version $BASE_DIR/php
        ln -f -s $BASE_VERSIONS_DIR/$version/bin/php /usr/bin/php
        ln -f -s $BASE_VERSIONS_DIR/$version/sbin/php-fpm /usr/local/sbin/php-fpm 
    fi
    exit 1
}

install_extension() {
    local name=$1
    local version=$2
    if test "$name" == ""; then
        echo "./t -e ***"
        exit 1
    fi

    local proto="http"
    if test "$version" == ""; then
        local url="pecl.php.net/get/$1"
    else
        local url="pecl.php.net/get/$1"-"$2".tgz
    fi

    local http_code=`curl -I -m 10 -o /dev/null -s -w %{http_code} $url`
    case $http_code in
        200)
            cd $BASE_VERSION_PECL
            wget "$proto"://"$url" -O "$name".tgz
            mkdir $name
            rm -rf $name/*

            local tar_info=`tar -zxvf "$name".tgz -C $name`

            cd $name
            cd $name-*

            check_current_version

            local phpize_info=`$BASE_DIR/php/bin/phpize`
            local configure_info=`./configure --with-php-config="$BASE_DIR/php/bin/php-config"`
            local make_info=`make`
            local info=`make install`

            for i in $info; do
                local path=$i
            done

            #add extension
            case $name in
                xdebug)
                    echo "zend_extension=$i$name.so" >> "$BASE_DIR/php/etc/php.ini"
                    ;;
                *)
                    echo "extension=$i$name.so" >> "$BASE_DIR/php/etc/php.ini"
                    ;;
            esac

            ;;
        *)
            echo "$name is not found"
            exit 1
        ;;

    esac


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
        ./t -e yaml 1.2.0
        ./t -e yaml  //new
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
        -e) install_extension $2 $3;exit;;
        *) install $1; exit;;

    esac
fi
