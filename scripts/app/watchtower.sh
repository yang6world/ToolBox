#!/bin/bash
# Watchtower
#
function watchtower_install() {
    docker run --detach \
        --name watchtower \
        --volume /var/run/docker.sock:/var/run/docker.sock \
        containrrr/watchtower 
}
function watchtower_uninstall() {
    docker stop watchtower
    docker rm watchtower
}
#$1为install则执行安装uninstall则执行卸载
case $1 in
    install)
        watchtower_install
        ;;
    uninstall)
        watchtower_uninstall
        ;;
esac