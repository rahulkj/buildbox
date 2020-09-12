#!/bin/bash -e

export DEBIAN_FRONTEND=noninteractive

declare -a DEPENDENCIES=(tar wget gzip ruby gem jq curl)

LOGFILE=/dev/null
OUTPUT=/usr/local/bin

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

install_yq() {
    log 'Installing yq'

    get_latest_release "$REPO_YQ" "linux_amd64"

    wget -qO "$OUTPUT"/yq "$DOWNLOAD_URL"
    chmod +x "$OUTPUT"/yq
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

  while read -r line; do
    if [[ "$line" == *om-*linux-*.tar.gz ]]; then
      wget -qO om.tgz "$line"
      tar -xvf om.tgz
      chmod +x om
      mv om "$OUTPUT"/om

      rm om.tgz
    fi
  done <<< "$DOWNLOAD_URL"
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

install_mc() {
    log 'Installing minio cli'
    wget https://dl.min.io/client/mc/release/linux-amd64/mc
    chmod +x mc
    mv ./mc /usr/local/bin/mc
    mc --version
}

install_kubectl() {
    log 'Installing kubectl cli'
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.19.0/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/kubectl
    kubectl version --client
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
    install_yq
    install_bosh
    install_cf
    install_credhub
    install_om
    install_pivnet_cli
    install_fly
    install_govc
    install_mc
    install_kubectl
fi
