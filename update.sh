#!/bin/sh

set -e

set -o allexport
[ -f .env ] && . ./.env
set +o allexport

ENDPOINT=https://api.cloudflare.com/client/v4/
ZONE_ID=${ZONE_ID:-95774d875c16e0760e081e4a42e53795}
DOMAIN=${1:-$DOMAIN}
#API_TOKEN=${API_TOKEN:-}

IP=$(ip -6 -j route get 2000:: | jq -r '.[0].prefsrc')

if [ -z "$IP" ];
then
	echo "IPv6 address not found" >&2
	exit 1
fi


log() {
	if [ -n "${DEBUG++}" ];
	then
		echo "$@" >&2
	fi
}

fetch() {
	method="GET"
	path=${1:?Missing argument 1}
	if [ -n "$2" ];
	then
		method="POST"
		payload=$2
	fi
	if [ -n "$3" ];
	then
		method=$1
		path=$2
		payload=$3
	fi

	log "method=$method" "path=$path" "payload=$payload"

	res=$( \
		curl -sSL -X "$method" "${ENDPOINT}$path" \
			-H "Authorization: Bearer ${API_TOKEN}" \
			-H "Content-Type:application/json" \
			--data-raw "$payload" \
	)

	if [ "true" = "$(echo -n $res | jq -r '.success')" ];
	then
		echo "$res" | jq -r '.result'
	else
		echo "$res" >&2
		return 1
	fi
}

list() {
	name=${1:+&name=$1}
	fetch "zones/${ZONE_ID}/dns_records?type=AAAA${name}"
}

find_id_by_name() {
	: ${1:?Argument 1 must be a domain name}
	lst=$(list "$1")
	rid=$(echo -n "$lst" | jq -r '.[0].id')
	if [ "null" = "$rid" ];
	then
		echo ""
	else
		echo "$rid"
	fi
}

create() {
	: ${1:?Argument 1 must be a domain name}
	: ${2:?Argument 2 must be a IPv6 address}
	log "Create DNS Record(name: $1) to $2"
	result=$(fetch "zones/${ZONE_ID}/dns_records" '
{
	"type": "AAAA",
	"name": "'$1'",
	"content": "'$2'",
	"ttl": 120,
	"proxied": false
}
	')
	log "$result"
}

update() {
	: ${1:?Argument 1 must be a dns_records id}
	: ${2:?Argument 2 must be a IPv6 address}
	log "Update DNS Record(id: $1) to $2"
	result=$(fetch "PATCH" "zones/${ZONE_ID}/dns_records/$1" '
{
	"content": "'$2'"
}
	')
	log "$result"
}

upsert() {
	: ${1:?Argument 1 must be a domain name}
	: ${2:?Argument 2 must be a IPv6 address}

	id=$(find_id_by_name "$1")
	if [ -z "$id" ];
	then
		create "$1" "$2"
	else
		update "$id" "$2"
	fi
}

upsert "$DOMAIN" "$IP"
