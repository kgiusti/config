#!/bin/bash -xe

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

ORG=$1
PROJECT=$2

source /usr/local/jenkins/slave_scripts/common_translation_update.sh

setup_git

setup_review "$ORG" "$PROJECT"
setup_translation
setup_project "$PROJECT"

setup_loglevel_vars
setup_loglevel_project "$PROJECT"

# Pull upstream translations of files that are at least 75 %
# translated
tx pull -a -f --minimum-perc=75

extract_messages_log "$PROJECT"

PO_FILES=`find ${PROJECT}/locale -name "${PROJECT}.po"`
if [ -n "$PO_FILES" ]
then
    # Use updated .pot file to update translations
    python setup.py update_catalog --no-fuzzy-matching  --ignore-obsolete=true
fi
# We cannot run update_catlog for the log files, since there is no
# option to specify the keyword and thus an update_catalog run would
# add the messages with the default keywords. Therefore use msgmerge
# directly.
for level in $LEVELS ; do
  PO_FILES=`find ${PROJECT}/locale -name "${PROJECT}-log-${level}.po"`
  if [ -n "$PO_FILES" ]
  then
    for f in $PO_FILES ; do
        echo "Updating $f"
        msgmerge --update --no-fuzzy-matching $f \
            --backup=none \
            ${PROJECT}/locale/${PROJECT}-log-${level}.pot
        # Remove obsolete entries
        msgattrib --no-obsolete --force-po \
            --output-file=${f}.tmp ${f}
        mv ${f}.tmp ${f}
    done
  fi
done

#
# Add all changed files to git
git add $PROJECT/locale/*

filter_commits

send_patch
