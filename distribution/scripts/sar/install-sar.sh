#!/bin/bash
# Copyright 2017 WSO2 Inc. (http://wso2.org)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ----------------------------------------------------------------------------
# Installation script for setting up System Activity Report
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")

# Make sure the script is running as root.
if [ "$UID" -ne "0" ]; then
    echo "You must be root to run $0. Try following"
    echo "sudo $0"
    exit 9
fi

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 [-h]"
    echo ""
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "h" opts; do
    case $opts in
    h)
        usage
        exit 0
        ;;
    \?)
        usage
        exit 1
        ;;
    esac
done

#Install sysstat
apt-get -y install sysstat
sysstat_file=/etc/default/sysstat
sed -i '/ENABLED/ s/false/true/' /etc/default/sysstat

#Change interval to 1 minute
sed -i 's/5-55/*/g' /etc/cron.d/sysstat
sed -i 's/10/1/g' /etc/cron.d/sysstat
#Restart the service
service sysstat restart

echo "Systat service started.. SAR version: "
sar -V
