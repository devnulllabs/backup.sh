#!/usr/bin/env bash

# devnulllabs/backup.sh Copyright 🄯 2020 Kenny Ballou /dev/null labs
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.

# devnulllabs/backup.sh is a simple script that uses various existing utilities
# in combination to create a series of backups.  The goal of the script is to
# be configurable, however, the needs of this program likely mirror that of the
# authors.

VERBOSE="false"
FULL="false"
DESTINATION_DIRECTORY=""
TARGET_DIRECTORY=""
REMOTE_HOST=""
GPG_KEY_ID="${GPG_KEY_ID:-}"
EXCLUDES_FILE="${HOME}/.config/backup.sh/exclude-patterns"
SNAPSHOT_DIRECTORY="${HOME}/.config/backup.sh/snapshots/"

function usage() {
    echo "backup.sh [-v] [-f] [-h <remote host>] -t <target folder> -d <destination>"
}

function error() {
    printf "%s\n" "${1}" 1>&2
}

function parse_arguments() {
    while getopts 'vfh:d:t:' flag; do
        case "${flag}" in
            v) VERBOSE='true' ;;
            f) FULL='true' ;;
            t) TARGET_DIRECTORY="${OPTARG}" ;;
            d) DESTINATION_DIRECTORY="${OPTARG}" ;;
            h) REMOTE_HOST="${OPTARG}" ;;
            *)
                error "Invalid argument/option passed"
                usage
                exit 1
                ;;
        esac
    done
    readonly VERBOSE
    readonly FULL
    readonly DESTINATION_DIRECTORY
    readonly TARGET_DIRECTORY
    readonly REMOTE_HOST
}

function touch_excludes_file() {
    # if the excludes file does not exist, we will create it with nothing
    mkdir -p "$(dirname "${EXCLUDES_FILE}")"
    touch "${EXCLUDES_FILE}"
}

function backup_to_local_directory() {
    local snapshot_dir
    local snapshot_file
    local snapshot_basename
    local status
    snapshot_basename="${TARGET_DIRECTORY/${HOME}\//}"
    snapshot_dir="${SNAPSHOT_DIRECTORY}${snapshot_basename}"
    snapshot_file="${snapshot_dir}.snapshot"
    if [[ "${VERBOSE}" == "true" ]]; then
        status="progress"
    else
        status="none"
    fi
    mkdir -p "${snapshot_dir}"
    if [[ "${FULL}" == "true" && -f "${snapshot_file}" ]]; then
        rm "${snapshot_file}"
        touch "${snapshot_file}"
    fi
    mkdir -p "$(dirname "${DESTINATION_DIRECTORY}/${snapshot_basename}")"
    tar -zcg "${snapshot_file}" --exclude-from="${EXCLUDES_FILE}" "${TARGET_DIRECTORY}" | \
         gpg --encrypt --recipient="${GPG_KEY_ID}" | \
         dd of="${DESTINATION_DIRECTORY}/${snapshot_basename}-$(date --iso-8601=minutes).tar.gz.gpg" status="${status}"
}

function backup_to_remote_host() {
    local snapshot_dir
    local snapshot_file
    local snapshot_basename
    local status
    snapshot_basename="${TARGET_DIRECTORY/${HOME}\//}"
    snapshot_dir="${SNAPSHOT_DIRECTORY}${snapshot_basename}"
    snapshot_file="${snapshot_dir}.snapshot"
    if [[ "${VERBOSE}" == "true" ]]; then
        status="progress"
    else
        status="none"
    fi
    mkdir -p "${snapshot_dir}"
    if [[ "${FULL}" == "true" && -f "${snapshot_file}" ]]; then
        rm "${snapshot_file}"
        touch "${snapshot_file}"
    fi
    ssh "${REMOTE_HOST}" mkdir -p "${DESTINATION_DIRECTORY}/${snapshot_basename}"
    tar -zcg "${snapshot_file}" --exclude-from="${EXCLUDES_FILE}" "${TARGET_DIRECTORY}" | \
         gpg --encrypt --recipient="${GPG_KEY_ID}" | \
         ssh "${REMOTE_HOST}" dd of="${DESTINATION_DIRECTORY}/${snapshot_basename}-$(date --iso-8601=minutes).tar.gz.gpg" status="${status}"
}

function main() {
    parse_arguments "$@"
    if [[ -z "${GPG_KEY_ID}" ]]; then
        error "No GPG key ID set"
        exit 2
    fi
    if [[ -z "${TARGET_DIRECTORY}" || -z "${DESTINATION_DIRECTORY}" ]]; then
        error "Missing required arguments"
        usage
        exit 1
    fi
    if [[ ! -f "${EXCLUDES_FILE}" ]]; then
        echo "touch touch touch"
        touch_excludes_file
    fi
    if [[ -n "${REMOTE_HOST}" ]]; then
        backup_to_remote_host
    else
        backup_to_local_directory
    fi
}

main "$@"
