#!/bin/bash -e

export DEBIAN_FRONTEND=noninteractive

declare -a DEPENDENCIES=(tar wget gzip ruby gem jq curl)

LOGFILE=/dev/null
OUTPUT=/usr/local/bin

DEFAULT_RUBY_VERSION=2.6.2
URLS_CF='https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github'
REPO_CREDHUB=cloudfoundry-incubator/credhub-cli
REPO_OM=pivotal-cf/om
REPO_PIVNET_CLI=pivotal-cf/pivnet-cli
REPO_FLY=concourse/concourse
REPO_YQ=mikefarah/yq
REPO_GOVC=vmware/govmomi

###
## Helpers
###

log() {
    echo $@ >> $LOGFILE
}

function_exists() {
    declare -f -F $1 > /dev/null
    return $?
}

validate() {
    if [ "$USER" != "root" ]; then
        echo "Please run as root or with sudo" 1>&2
        exit 2
    fi
}

validate_dependencies() {
    missing=
    for dep in "${DEPENDENCIES[@]}"; do
        hash "$dep" || missing="$missing "
    done

    if [ ! -z "$missing" ]; then
        echo "Missing required dependencies: $missing" 1>&2
        exit 2
    else
        log "All dependency requirements met"
    fi
}

get_latest_release() {
    DOWNLOAD_URL=$(curl --silent "https://api.github.com/repos/$1/releases/latest" | \
      jq -r \
      --arg flavor $2 '.assets[] | select(.name | contains($flavor)) | .browser_download_url')
    echo $DOWNLOAD_URL
}


###
## Installations
###

install_curl() {
  log 'Installing curl'
  apt-get update
  apt-get install curl -y --no-install-recommends
}

install_wget() {
  log 'Installing wget'
  apt-get update
  apt-get install wget -y --no-install-recommends
}

install_ruby() {
  command curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
  command curl -sSL https://rvm.io/mpapis.asc | gpg --import -
  \curl -sSL https://get.rvm.io | bash -s stable
  source /usr/local/rvm/scripts/rvm
  rvm install $DEFAULT_RUBY_VERSION
  rvm use --default $DEFAULT_RUBY_VERSION
  rvm cleanup all
}

install_jq() {
    log 'Installing jq'
    apt-get update
    apt-get install jq -y --no-install-recommends
}


install_yq() {
    log 'Installing yq'

    get_latest_release "$REPO_YQ" "linux_amd64"

    wget -qO "$OUTPUT"/yq "$DOWNLOAD_URL"
    chmod +x "$OUTPUT"/yq
}

install_git() {
  log 'Installing git'
  apt-get update
  apt-get install git -y --no-install-recommends
}

install_bosh() {
    log 'Installing bosh'

    BOSH_CLI_VERSION=$(curl --silent "https://api.github.com/repos/cloudfoundry/bosh-cli/releases/latest" | jq -r '.name' | cut -d'v' -f2)
    URLS_BOSH=https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-$BOSH_CLI_VERSION-linux-amd64

    wget -qO "$OUTPUT"/bosh "$URLS_BOSH"
    chmod +x "$OUTPUT"/bosh
}

install_cf() {
  log 'Installing cf'

  wget -qO "$OUTPUT"/cf.tgz "$URLS_CF"
  tar -xzvf "$OUTPUT"/cf.tgz -O cf > "$OUTPUT"/cf

  chmod +x "$OUTPUT"/cf

  rm "$OUTPUT"/cf.tgz
}

install_credhub() {
    log 'Installing credhub'

    get_latest_release "$REPO_CREDHUB" "linux"

    wget -qO "$OUTPUT"/credhub.tgz "$DOWNLOAD_URL"
    tar -xvf "$OUTPUT"/credhub.tgz
    chmod +x credhub
    mv credhub "$OUTPUT"/credhub

    rm "$OUTPUT"/credhub.tgz
}

install_om() {
  log 'Installing om'

  get_latest_release "$REPO_OM" "linux"

  wget -qO "$OUTPUT"/om "$DOWNLOAD_URL"
  chmod +x "$OUTPUT"/om
}

install_pivnet_cli() {
    log 'Installing pivnet cli'

    get_latest_release "$REPO_PIVNET_CLI" "linux"

    wget -qO "$OUTPUT"/pivnet "$DOWNLOAD_URL"
    chmod +x "$OUTPUT"/pivnet
}

install_fly() {
    log 'Installing fly'

    get_latest_release "$REPO_FLY" "linux-amd64"

    while read -r line; do
      if [[ "$line" == *fly-*linux-amd64.tgz ]]; then
        wget -qO fly.tgz "$line"
        tar -xvf fly.tgz
        chmod +x fly
        mv fly "$OUTPUT"/fly

        rm fly.tgz
      fi
    done <<< "$DOWNLOAD_URL"
}

install_govc() {
    log 'Installing govc'

    get_latest_release "$REPO_GOVC" "linux_amd64"

    wget -qO govc_linux_amd64.gz "$DOWNLOAD_URL"
    gzip -d govc_linux_amd64.gz

    chmod +x govc_linux_amd64
    mv govc_linux_amd64 "$OUTPUT"/govc

    rm -rf govc_linux_amd64.gz
}

install_uaac() {
    log 'Installing uaac cli'
    apt-get update
    gem install cf-uaac >> $LOGFILE
}

###
# Main
##

while getopts 'vo:' param; do
    case $param in
        o ) log "Setting output to $OPTARG"
            OUTPUT="$OPTARG"
            ;;
        v ) LOGFILE=/dev/stdout
            ;;
        ? ) echo "Unkown option $OPTARG" 1>&2
            exit 3
            ;;
    esac
done

shift $(($OPTIND - 1))

# validate

if [ ! -d "$OUTPUT" ]; then
  mkdir -p $OUTPUT
fi

if [ ! -z "$1" ]; then
    function_exists install_$1 && eval install_$1 || echo "Unknown installation $1" 1>&2 && exit 4
else
    # install_curl
    # install_wget
    # install_ruby
    install_jq
    install_yq
    install_git
    install_bosh
    install_cf
    install_credhub
    install_om
    install_pivnet_cli
    install_fly
    install_govc
    # install_uaac
fi
