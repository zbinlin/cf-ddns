#!/bin/bash

set -e

set -o allexport
[[ -f .env ]] && . .env
set +o allexport

ENDPOINT=https://api.cloudflare.com/client/v4/
ZONE_ID=${ZONE_ID:-95774d875c16e0760e081e4a42e53795}
DOMAIN=${1:-$DOMAIN}
#API_TOKEN=${API_TOKEN:-}

IP=$(\
	ip -6 address show scope global \
	| awk '{ print $2 }' \
  	| grep \
		-e '^200[1,3]' \
		-e '^2[4,6,8,c]' \
		-e '^26[1-3]' \
		-e '^2a[0-1]' \
	| head -n1 \
)
IP=${IP%/*}

function log() {
	if [[ -n "${DEBUG++}" ]];
	then
		echo "$@" >&2
	fi
}

function fetch() {
	if [[ "$1" == "" ]];
	then
		echo "Missing argument 1" >&2
		return 1
	fi
	if [[ "$2" == "" ]];
	then
		method="GET"
	else
		method="POST"
		payload=$2
	fi
	if [[ "$3" != "" ]];
	then
		method=$payload
		payload=$3
	fi

	log $method $1 "$payload"

	res=$( \
		curl -sSL -X "$method" "${ENDPOINT}$1" \
			-H "Authorization: Bearer ${API_TOKEN}" \
			-H "Content-Type:application/json" \
			--data-raw "$payload" \
	)

	if [[ "true" == "$(jq -r '.success' <<<$res)" ]];
	then
		echo "$res" | jq -r '.result'
	else
		echo "$res" >&2
		exit 1
	fi
}

function list() {
	name=${1:+&name=$1}
	fetch "zones/${ZONE_ID}/dns_records?type=AAAA${name}"
}

function create() {
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

function update() {
	: ${1:?Argument 1 must be a dns_records id}
	: ${2:?Argument 2 must be a IPv6 address}
	log "Update DNS Record(id: $1) to $2"
	result=$(fetch "zones/${ZONE_ID}/dns_records/$1" "PATCH" '
{
	"content": "'$2'"
}
	')
	log "$result"
}

function upsert() {
	: ${1:?Argument 1 must be a domain name}
	: ${2:?Argument 2 must be a IPv6 address}
	rid=$(list $1 | jq -r '.[0].id')
	if [[ "null" == "$rid" ]];
	then
		create $1 $2
	else
		update $rid $2
	fi
}

upsert $DOMAIN $IP
