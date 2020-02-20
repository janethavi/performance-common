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
# Report Generation from JMeter Client
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
script_dir=$(realpath $script_dir)

while getopts "n:p:j:c:" opts; do
    case $opts in
    n)
        application_name=("${OPTARG}")
        ;;
    p)
        metrics_file_prefix=("${OPTARG}")
        ;;
    j)
        max_jmeter_servers=("${OPTARG}")
        ;;
    c)
        create_csv_opts=("${OPTARG}")
        ;;        
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
shift "$((OPTIND - 1))"

gcviewer_jar_path="/home/ubuntu/Resources/gcviewer-1.35.jar"
results_dir="/home/ubuntu/results"

function exit_handler() {
    if [[ "$estimate" == false ]] && [[ -d results ]]; then
        echo "Zipping results directory..."
        # Create zip file without JTLs first (in case of limited disc space)
        zip -9qr results-without-jtls.zip results/ -x '*jtls.zip'
        zip -9qr results.zip results/
    fi
}

trap exit_handler EXIT

for n in {1..2}
do
    metrics_file_prefix="$metrics_file_prefix${n}"
    # Create warmup summary CSV
    $HOME/Perf_dist/jmeter/create-summary-csv.sh ${create_csv_opts} -d $results_dir -n "${application_name}" -p "${metrics_file_prefix}" -j $max_jmeter_servers -g "${gcviewer_jar_path}" -i -w -o summary-warmup-apim-${n}.csv
    mv $HOME/summary-warmup-apim-${n}.csv $results_dir
    # # Create measurement summary CSV
    $HOME/Perf_dist/jmeter/create-summary-csv.sh ${create_csv_opts} -d $results_dir -n "${application_name}" -p "${metrics_file_prefix}" -j $max_jmeter_servers -g "${gcviewer_jar_path}" -i -o summary-apim-${n}.csv
    mv $HOME/summary-apim-${n}.csv $results_dir
done
