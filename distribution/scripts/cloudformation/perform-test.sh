#!/bin/bash -e
# Copyright (c) 2018, WSO2 Inc. (http://wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# ----------------------------------------------------------------------------
# Run performance tests on AWS CloudFormation stacks.
# ----------------------------------------------------------------------------

# Source common script
script_dir=$(dirname "$0")
script_dir=$(realpath $script_dir)
. $script_dir/../common/common.sh

declare -a concurrent_users_array

declare -a message_sizes_array

key_file=""
default_number_of_stacks=1
number_of_stacks=$default_number_of_stacks
default_parallel_parameter_option="u"
parallel_parameter_option="$default_parallel_parameter_option"
ALLOWED_OPTIONS="ubsm"

file=$2/"deployment.properties"
declare -A arr_prop
if [ -f "$file" ]
then
    while IFS='=' read -r key value; do
        arr_prop["$key"]="$value"
    done < $file
    m=${arr_prop[heap_memory_app]}
    s=${arr_prop[backend_sleep]}
    d=${arr_prop[test_duration]}
    w=${arr_prop[warmup_time]}
    j=${arr_prop[heap_memory_jmeter_s]}
    k=${arr_prop[heap_memory_jmeter_c]}
    l=${arr_prop[heap_memory_netty]}
    # for i in "${!arr_prop[@]}"
    # do
    #     echo "key :" $i
    #     echo "value:" ${arr_prop[$i]}
    # done
    while read -r line; do
         concurrent_users_array=("${concurrent_users_array[@]}" "$line")
    done < <(grep con_users= file2.properties | sed "s/con_users=//")
    while read -r line; do
         message_sizes_array=("${message_sizes_array[@]}" "$line")
    done < <(grep msg_size= file2.properties | sed "s/msg_size=//")
else
  echo "$file not found."
  exit 1
fi

# [[ $concurrent_users_array ]] && export A_MY_ARRAY=$(declare -p concurrent_users_array)
# [[ $message_sizes_array ]] && export B_MY_ARRAY=$(declare -p message_sizes_array)

run_performance_tests_options=("$@")

echo "${run_performance_tests_options[@]}"

declare -a performance_test_options

# if [[ $number_of_stacks -gt 1 ]]; then
#     # Read options given to the performance test script. Refer jmeter/perf-test-common.sh
#     declare -a options
#     # Flag to check whether next parameter is an argument to $parallel_parameter_option
#     next_opt_param=false
#     for opt in ${run_performance_tests_options[@]}; do
#         if [[ $opt == -$parallel_parameter_option* ]]; then
#             optarg="${opt:2}"
#             if [[ ! -z $optarg ]]; then
#                 options+=("${optarg}")
#             else
#                 next_opt_param=true
#             fi
#         else
#             if [[ $next_opt_param == true ]]; then
#                 options+=("${opt}")
#                 next_opt_param=false
#             else
#                 run_performance_tests_remaining_options+=("${opt}")
#             fi
#         fi
#     done
#     minimum_params_per_stack=$(bc <<<"scale=0; ${#options[@]}/${number_of_stacks}")
#     remaining_params=$(bc <<<"scale=0; ${#options[@]}%${number_of_stacks}")
#     echo "Parallel option parameters: ${#options[@]}"
#     echo "Number of stacks: ${number_of_stacks}"
#     echo "Minimum parameters per stack: $minimum_params_per_stack"
#     echo "Remaining parameters after distributing evenly: $remaining_params"

#     option_counter=0
#     remaining_option_counter=0
#     for ((i = 0; i < $number_of_stacks; i++)); do
#         declare -a options_per_stack=()
#         for ((j = 0; j < $minimum_params_per_stack; j++)); do
#             options_per_stack+=("${options[$option_counter]}")
#             let option_counter=option_counter+1
#         done
#         if [[ $remaining_option_counter -lt $remaining_params ]]; then
#             options_per_stack+=("${options[$option_counter]}")
#             let option_counter=option_counter+1
#             let remaining_option_counter=remaining_option_counter+1
#         fi
#         options_list=""
#         for parameter_value in ${options_per_stack[@]}; do
#             options_list+="-${parallel_parameter_option} ${parameter_value} "
#         done
#         performance_test_options+=("${options_list} ${run_performance_tests_remaining_options[*]}")
#     done
# else
    performance_test_options+=("${run_performance_tests_options[*]}")
# fi

# Allow to change the script name
run_performance_tests_script_name=${run_performance_tests_script_name:-run-performance-tests.sh}

estimate_command="$script_dir/../jmeter/${run_performance_tests_script_name} -t -m $m -s $s -d $d -w $w -j $j -k $k -l $l -u '${concurrent_users_array[@]}' -b '${message_sizes_array[@]}'"
#estimate_command="$script_dir/../jmeter/${run_performance_tests_script_name}"
echo "Estimating total time for performance tests: $estimate_command"
# Estimating this script will also validate the options. It's important to validate options before creating the stack.
$estimate_command

results_dir=$(cat results_dir.json | jq -r '.results_dir')

# Save test metadata
mv test-metadata.json $results_dir
mv test-duration.json $results_dir

aws s3 cp s3://performance-test-archives/janeth-key.pem $results_dir/janeth-key.pem
key_file=$results_dir/janeth-key.pem
key_file=$(realpath $key_file)
chmod 400 $key_file

function download_files() {
    local stack_id="$1"
    local stack_name="$2"
    local stack_results_dir="$3"
    local suffix="$(date +%Y%m%d%H%M%S)"
    local stack_files_dir="$stack_results_dir/stack-files"
    mkdir -p $stack_files_dir
    local stack_resources_json=$stack_files_dir/stack-resources-$suffix.json
    echo "Saving $stack_name stack resources to $stack_resources_json"
    aws cloudformation describe-stack-resources --stack-name $stack_id --no-paginate --output json >$stack_resources_json
    local vpc_id="$(jq -r '.StackResources[] | select(.LogicalResourceId=="VPC") | .PhysicalResourceId' $stack_resources_json)"
    if [[ ! -z $vpc_id ]]; then
        echo "VPC ID: $vpc_id"
        local stack_instances_json=$stack_files_dir/stack-instances-$suffix.json
        aws ec2 describe-instances --filters "Name=vpc-id, Values="$vpc_id"" --query "Reservations[*].Instances[*]" --no-paginate --output json >$stack_instances_json
        # Try to get a public IP
        local instance_public_ip="$(jq -r 'first(.[][] | .PublicIpAddress // empty)' $stack_instances_json)"
        if [[ ! -z $instance_public_ip ]]; then
            local instance_ips_file=$stack_files_dir/stack-instance-ips-$suffix.txt
            cat $stack_instances_json | jq -r '.[][] | (.Tags[] | select(.Key=="Name")) as $tags | ($tags["Value"] + "/" + .PrivateIpAddress) | tostring' >$instance_ips_file
            echo "Private IPs in $instance_ips_file: "
            cat $instance_ips_file
            echo "Uploading $instance_ips_file to $instance_public_ip"
            if scp -i $key_file -o "StrictHostKeyChecking=no" $instance_ips_file ubuntu@$instance_public_ip:; then
                download_files_command="ssh -i $key_file -o "StrictHostKeyChecking=no" ubuntu@$instance_public_ip ./cloudformation/download-files.sh -f $(basename $instance_ips_file) -k private_key.pem -o /home/ubuntu"
                echo "Download files command: $download_files_command"
                $download_files_command
                echo "Downloading files.zip"
                local files_zip_file=$stack_files_dir/files-$suffix.zip
                scp -i $key_file -o "StrictHostKeyChecking=no" ubuntu@$instance_public_ip:files.zip $files_zip_file
                local files_dir="$stack_results_dir/files"
                mkdir -p $files_dir
                echo "Extracting files.zip to $files_dir"
                unzip -o $files_zip_file -d $files_dir
            fi
        fi
    else
        echo "WARNING: VPC ID not found!"
    fi
}

function delete_stack() {
    local stack_id="$1"
    local stack_delete_start_time=$(date +%s)
    echo "Deleting the stack: $stack_id"
    aws cloudformation delete-stack --stack-name $stack_id

    echo "Polling till the stack deletion completes..."
    aws cloudformation wait stack-delete-complete --stack-name $stack_id
    printf "Stack ($stack_id) deletion time: %s\n" "$(format_time $(measure_time $stack_delete_start_time))"
}

function save_logs_and_delete_stack() {
    local stack_id="$1"
    local stack_name="$2"
    local stack_results_dir="$3"
    # Get stack events
    local stack_events_json=$stack_results_dir/stack-events.json
    echo "Saving $stack_name stack events to $stack_events_json"
    aws cloudformation describe-stack-events --stack-name $stack_id --no-paginate --output json >$stack_events_json
    # Check whether there are any failed events
    cat $stack_events_json | jq '.StackEvents | .[] | select ( .ResourceStatus == "CREATE_FAILED" )'

    # Download log events
    local log_group_name="${stack_name}-CloudFormationLogs"
    local log_streams_json=$stack_results_dir/log-streams.json
    if aws logs describe-log-streams --log-group-name $log_group_name --output json >$log_streams_json; then
        local log_events_file=$stack_results_dir/log-events.log
        for log_stream in $(cat $log_streams_json | jq -r '.logStreams | .[] | .logStreamName'); do
            echo "[$log_group_name] Downloading log events from stream: $log_stream..."
            echo "#### The beginning of log events from $log_stream" >>$log_events_file
            aws logs get-log-events --log-group-name $log_group_name --log-stream-name $log_stream --output text >>$log_events_file
            echo -ne "\n\n#### The end of log events from $log_stream\n\n" >>$log_events_file
        done
    else
        echo "WARNING: There was an error getting log streams from the log group $log_group_name. Check whether AWS CloudWatch logs are enabled."
    fi

    # Download files
    download_files ${stack_id} ${stack_name} ${stack_results_dir}

    if [ "$SUSPEND" = true ]; then
        echo "SUSPEND is true, holding the deletion of stack: $stack_id"
        if ! sleep infinity; then
            echo "Sleep terminated! Proceeding to delete the stack: $stack_id"
        fi
    fi

    #delete_stack $stack_id
}

function wait_and_download_files() {
    local stack_id="$1"
    local stack_name="$2"
    local stack_results_dir="$3"
    local wait_time="$4"
    sleep $wait_time
    local suffix="$(date +%Y%m%d%H%M%S)"
    local stack_files_dir="$stack_results_dir/stack-files"
    mkdir -p $stack_files_dir
    local stack_status_json=$stack_files_dir/stack-status-$suffix.json
    echo "Saving $stack_name stack status to $stack_status_json"
    aws cloudformation describe-stacks --stack-name $stack_id --no-paginate --output json >$stack_status_json
    local stack_status="$(jq -r '.Stacks[] | .StackStatus' $stack_status_json || echo "")"
    echo "Current status of $stack_name stack is $stack_status"
    if [[ "$stack_status" != "CREATE_COMPLETE" ]]; then
        download_files ${stack_id} ${stack_name} ${stack_results_dir}
    fi
}

function run_perf_tests_in_stack() {
    local index=$1
    local stack_id=$2
    local stack_name=$3
    local stack_results_dir=$4
    #trap "save_logs_and_delete_stack ${stack_id} ${stack_name} ${stack_results_dir}" EXIT
    #trap "save_logs_and_delete_stack ${stack_id} ${stack_name} ${stack_results_dir}" RETURN
    printf "Running performance tests on '%s' stack.\n" "$stack_name"

    # Download files periodically
    for wait_time in $(seq 5 5 30); do
        wait_and_download_files ${stack_id} ${stack_name} ${stack_results_dir} ${wait_time}m &
    done
    # Sleep for sometime before waiting
    # This is required since the 'aws cloudformation wait stack-create-complete' will exit with a
    # return code of 255 after 120 failed checks. The command polls every 30 seconds, which means that the
    # maximum wait time is one hour.
    # Due to the dependencies in CloudFormation template, the stack creation may take more than one hour.
    # echo "Waiting ${minimum_stack_creation_wait_time}m before polling for CREATE_COMPLETE status of the stack: $stack_name"
    # sleep ${minimum_stack_creation_wait_time}m
    # # Wait till completion
    # echo "Polling till the stack creation completes..."
    # aws cloudformation wait stack-create-complete --stack-name $stack_id
    # printf "Stack creation time: %s\n" "$(format_time $(measure_time $stack_create_start_time))"

    # # Get stack resources
    # local stack_resources_json=$stack_results_dir/stack-resources.json
    # echo "Saving $stack_name stack resources to $stack_resources_json"
    # aws cloudformation describe-stack-resources --stack-name $stack_id --no-paginate --output json >$stack_resources_json
    # # Print EC2 instances
    # echo "AWS EC2 instances: "
    # cat $stack_resources_json | jq -r '.StackResources | .[] | select ( .ResourceType == "AWS::EC2::Instance" ) | .LogicalResourceId'

    echo "Getting JMeter Client Public IP..."
    jmeter_client_ip="$(aws cloudformation describe-stacks --stack-name $stack_id --query 'Stacks[0].Outputs[?OutputKey==`JMeterClientPublicIP`].OutputValue' --output text)"
    echo "JMeter Client Public IP: $jmeter_client_ip"

    ssh_command_prefix="ssh -i $key_file -o "StrictHostKeyChecking=no" -T ubuntu@$jmeter_client_ip"
    # Run performance tests
    run_remote_tests_command="$ssh_command_prefix ./jmeter/${run_performance_tests_script_name} -m $m -s $s -d $d -w $w -j $j -k $k -l $l -u '${concurrent_users_array[@]}' -b '${message_sizes_array[@]}'"
    echo "Running performance tests: $run_remote_tests_command"
    # Handle any error and let the script continue.
    $run_remote_tests_command || echo "Remote test ssh command failed: $run_remote_tests_command"

    echo "Downloading results-without-jtls.zip"
    # Download results-without-jtls.zip
    scp -i $key_file -o "StrictHostKeyChecking=no" ubuntu@$jmeter_client_ip:results-without-jtls.zip $stack_results_dir
    echo "Downloading results.zip"
    # Download results.zip
    scp -i $key_file -o "StrictHostKeyChecking=no" ubuntu@$jmeter_client_ip:results.zip $stack_results_dir

    if [[ ! -f $stack_results_dir/results-without-jtls.zip ]]; then
        echo "Failed to download the results-without-jtls.zip"
        exit 500
    fi

    if [[ ! -f $stack_results_dir/results.zip ]]; then
        echo "Failed to download the results.zip"
        exit 500
    fi
}

results_dir=$(cat results_dir.json | jq -r '.results_dir')
stack_id=$(cat $results_dir/stack_id.json | jq -r '.stack_id')
stack_name_prefix="wso2-apim-test-"
#stack_id=${stack_ids[$i]}
i=0
stack_name="${stack_name_prefix}"
stack_results_dir="$results_dir/results-$(($i + 1))"
log_file="${stack_results_dir}/run.log"
run_perf_tests_in_stack $i ${stack_id} ${stack_name} ${stack_results_dir} 2>&1 | ts "[${stack_name}] [%Y-%m-%d %H:%M:%S]" | tee ${log_file} &


# See current jobs
echo "Jobs: "
# jobs
echo "Waiting till all performance test jobs are completed..."
# Wait till parallel tests complete
wait

declare -a system_information_files

# Extract all results.
for ((i = 0; i < ${#performance_test_options[@]}; i++)); do
    stack_results_dir="$results_dir/results-$(($i + 1))"
    unzip -nq ${stack_results_dir}/results-without-jtls.zip -x '*/test-metadata.json' -d $results_dir
    system_info_file="${stack_results_dir}/files/${ec2_instance_name}/system-info.json"
    if [[ -f $system_info_file ]]; then
        system_information_files+=("$system_info_file")
    fi
done
cd $results_dir
# echo "Combining system information in following files: ${system_information_files[@]}"
# # Join json files containing system information and create an array
# jq -s . "${system_information_files[@]}" >all-system-info.json
# # Copy metadata before creating CSV
# cp cf-test-metadata.json test-metadata.json results
# echo "Creating summary.csv..."
# # Create warmup summary CSV
# $script_dir/../jmeter/create-summary-csv.sh ${create_csv_opts} -d results -n "${application_name}" -p "${metrics_file_prefix}" -j $max_jmeter_servers -g "${gcviewer_jar_path}" -i -w -o summary-warmup.csv
# # Create measurement summary CSV
# $script_dir/../jmeter/create-summary-csv.sh ${create_csv_opts} -d results -n "${application_name}" -p "${metrics_file_prefix}" -j $max_jmeter_servers -g "${gcviewer_jar_path}" -i -o summary.csv
# # Zip results
# zip -9qmr results-all.zip results/

# # Use following to get all column names:
# echo "Available column names:"
# while read -r line; do echo "\"$line\""; done < <($script_dir/../jmeter/create-summary-csv.sh ${create_csv_opts} -n "${application_name}" -j $max_jmeter_servers -i -x)
# echo -ne "\n\n"

# declare -a column_names

# while read column_name; do
#     column_names+=("$column_name")
# done < <(get_columns)

# echo "Creating summary results markdown file... Using column names: ${column_names[@]}"
# $script_dir/../jmeter/create-summary-markdown.py --json-parameters parameters=cf-test-metadata.json,parameters=test-metadata.json,instances=all-system-info.json \
#     --column-names "${column_names[@]}"

# function print_summary() {
#     cat $1 | cut -d, -f 1-13 | column -t -s,
# }

# echo -ne "\n\n"
# echo "Warmup Results:"
# print_summary summary-warmup.csv

# echo -ne "\n\n"
# echo "Measurement Results:"
# print_summary summary.csv

# awk -F, '{ if ($8 > 0)  print }' summary.csv >summary-errors.csv

# if [[ $(wc -l <summary-errors.csv) -gt 1 ]]; then
#     echo -ne "\n\n"
#     echo "WARNING: There are errors in measurement results! Please check."
#     print_summary summary-errors.csv
# fi