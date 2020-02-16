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
# Run performance tests on AWS CloudFormation stack.
# ----------------------------------------------------------------------------

# Source common script
script_dir=$(dirname "$0")
script_dir=$(realpath $script_dir)
. $script_dir/../common/common.sh

key_file=""
number_of_product_nodes=2

input_dir=$1
output_dir=$2
deployment_prop_file=$input_dir/"deployment.properties"
testplan_prop_file=$input_dir/../"testplan-props.properties"
echo "Test output directory is $output_dir"
declare -A propArray
if [ -f "$deployment_prop_file" ]
then
    while IFS='=' read -r key value; do
        propArray["$key"]="$value"
    done < $deployment_prop_file
    application_heap=${propArray[heap_memory_app]}
    backend_sleep_time=${propArray[backend_sleep]}
    test_duration=${propArray[test_duration]}
    warm_up_time=${propArray[warmup_time]}
    jmeter_server_heap=${propArray[heap_memory_jmeter_s]}
    jmeter_client_heap=${propArray[heap_memory_jmeter_c]}
    netty_heap=${propArray[heap_memory_netty]}
    message_size=${propArray[msg_size]}
    concurrent_users=${propArray[con_users]}
    mysql_host=${propArray[RDSHost]}
    apim_endpoint=${propArray[GatewayHttpsUrl]}
    jmeter_client_ip=${propArray[JMeterClient]}
    netty_backend_ip=${propArray[NettyBackend]}
    IFS=','
    read -ra message_sizes_array <<< "$message_size"
    read -ra concurrent_users_array <<< "$concurrent_users"
else
  echo "Error: deployment.properties file not found."
  exit 1
fi
if [ -f "$testplan_prop_file" ]
then
    while IFS='=' read -r key value; do
        propArray["$key"]="$value"
    done < $testplan_prop_file
    mysql_username=${propArray[DBUsername]}
    mysql_password=${propArray[DBPassword]}
    region=${propArray[region]}
    num_jmeter_servers=${propArray[NumberOfJmeterServers]}
    IFS=' '
else
  echo "Error: testplan_prop.properties file not found."
  exit 1
fi
virtualenv .venv
source .venv/bin/activate
pip3 install -r $script_dir/python-requirements.txt

results_dir="Results-$(date +%Y%m%d%H%M%S)"
mkdir $results_dir
aws s3 cp s3://performance-test-archives/janeth-key.pem $script_dir/janeth-key.pem
key_file=$script_dir/janeth-key.pem
key_file=$(realpath $key_file)
sudo chmod 400 $key_file
scp_command_prefix="scp -i $key_file -o "StrictHostKeyChecking=no""
ssh_command_prefix="ssh -i $key_file -o "StrictHostKeyChecking=no""

# scp key_file to jmeter-client
$scp_command_prefix $key_file ubuntu@$jmeter_client_ip:/home/ubuntu

# Starting Backend
$ssh_command_prefix ubuntu@$netty_backend_ip sudo bash /home/ubuntu/Perf_dist/netty-service/netty-start.sh -m $netty_heap -w

# Create APIS
echo "SSH to JMeter Client"
echo "Starting to create APIS needed for performance testing"
$ssh_command_prefix ubuntu@$jmeter_client_ip sudo bash /home/ubuntu/Perf_dist/setup/setup-apis.sh -n $netty_backend_ip \
-a $apim_endpoint -m $mysql_host -u $mysql_username -p $mysql_password -o "root"

echo "Getting the IP addresses of the Product nodes"
declare -a apim_ips
for ((i = 0; i < $number_of_product_nodes; i++)); do
    apim_ips+=($(python $script_dir/../apim/private_ip_extractor.py $region $AWS_ACCESS_KEY_ID $AWS_SECRET_ACCESS_KEY WSO2APIMInstance$((i+1)) | tr -d '[],'))
done

# ssh to jmeter-client and scp Perf_dist to product nodes
echo "Copying Performance-distribution to product nodes"
$ssh_command_prefix ubuntu@$jmeter_client_ip bash /home/ubuntu/Perf_dist/setup/setup_perf_dist.sh "${apim_ips[@]}"

# Allow to change the script name
run_performance_tests_script_name=${run_performance_tests_script_name:-run-performance-tests.sh}

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

function run_perf_tests_in_stack() {
    jmeter_client_ssh_command="ssh -i $key_file -o "StrictHostKeyChecking=no" -T ubuntu@$jmeter_client_ip"
    # Run performance tests
    if [[ $num_jmeter_servers -gt 0 ]]; then
        echo "Running the performace test with distributed jmeter deployment"
        $jmeter_ssh_command "$HOME/Perf_dist/jmeter/${run_performance_tests_script_name} -m $application_heap -s $backend_sleep_time \
        -d $test_duration -w $warm_up_time -j $jmeter_server_heap -n $num_jmeter_servers -k $jmeter_client_heap -l $netty_heap -a $netty_backend_ip \
        -b '${message_sizes_array[*]}'  -u '${concurrent_users_array[*]}' " || echo "Remote test ssh command failed:"
    else
        echo "Running the performace test without distributed jmeter deployment"
        $jmeter_client_ssh_command "$HOME/Perf_dist/jmeter/${run_performance_tests_script_name} -m $application_heap -s $backend_sleep_time \
        -d $test_duration -w $warm_up_time -j $jmeter_server_heap -k $jmeter_client_heap -l $netty_heap -a $netty_backend_ip \
        -c '${apim_ips[*]}' -b '${message_sizes_array[*]}'  -u '${concurrent_users_array[*]}' " || echo "Remote test ssh command failed:"
    else
        echo "Running the performace test with distributed jmeter deployment"
        echo "Getting the IP Addresses of JMeter Servers"
        declare -a jmeter_client_ips
        jmeter_client_ips=($(python $script_dir/../apim/private_ip_extractor.py $region $AWS_ACCESS_KEY_ID $AWS_SECRET_ACCESS_KEY Jmeter-Server | tr -d '[],'))
        $jmeter_client_ssh_command "$HOME/Perf_dist/jmeter/${run_performance_tests_script_name} -m $application_heap -s $backend_sleep_time \
        -d $test_duration -w $warm_up_time -j $jmeter_server_heap -n $num_jmeter_servers -k $jmeter_client_heap -l $netty_heap -a $netty_backend_ip \
        -c '${apim_ips[*]}' -f '${jmeter_client_ips[@]}' -b '${message_sizes_array[*]}'  -u '${concurrent_users_array[*]}' " || echo "Remote test ssh command failed:"   
    fi
}

run_perf_tests_in_stack
# Creating summaries after running the test
gcviewer_jar_path=$results_dir/gcviewer-1.35.jar
aws s3 cp s3://performance-test-archives/gcviewer-1.35.jar $gcviewer_jar_path
echo "Coppying results directory to TESTGRID SLAVE"
$scp_command_prefix ubuntu@jmeter_client_ip/home/ubuntu/results.zip $results_dir
unzip $results_dir/results.zip -d $results_dir

if [ $num_jmeter_servers -ge 0 ]; then
    max_jmeter_servers=2
else
    max_jmeter_servers=1
fi
application_name="WSO2 API Manager"
metrics_file_prefix="apim"
echo "Creating summary.csv..."
for apim_node in ${#apim_ips[@]}; do
    metrics_file_prefix="apim${apim_node}"
    # Create warmup summary CSV
    $script_dir/../jmeter/create-summary-csv.sh ${create_csv_opts} -d $results_dir/results -n "${application_name}" -p "${metrics_file_prefix}" -j $max_jmeter_servers -g "${gcviewer_jar_path}" -i -w -o summary-warmup-apim-${apim_node}.csv
    # # Create measurement summary CSV
    $script_dir/../jmeter/create-summary-csv.sh ${create_csv_opts} -d $results_dir/results -n "${application_name}" -p "${metrics_file_prefix}" -j $max_jmeter_servers -g "${gcviewer_jar_path}" -i -o summary-apim-${apim_node}.csv
    # # Zip results
    # zip -9qmr results-all.zip results/
done

paste -d, summary-warmup-apim-1.csv summary-warmup-apim-2.csv > summary-warmup.csv
paste -d, summary-apim-1.csv summary-apim-2.csv > summary.csv

for apim_node in ${#apim_ips[@]}; do
    sudo rm -f summary-warmup-apim-${apim_node}.csv
    summary-apim-${apim_node}.csv
done

sudo rm -r $results_dir/gcviewer-1.35.jar

# Use following to get all column names:
echo "Available column names:"
while read -r line; do echo "\"$line\""; done < <($script_dir/../jmeter/create-summary-csv.sh ${create_csv_opts} -n "${application_name}" -j $max_jmeter_servers -i -x)
echo -ne "\n\n"

declare -a column_names

while read column_name; do
    column_names+=("$column_name")
done < <(get_columns)

function print_summary() {
    cat $1 | cut -d, -f 1-13 | column -t -s,
}

echo -ne "\n\n"
echo "Warmup Results:"
print_summary summary-warmup.csv

echo -ne "\n\n"
echo "Measurement Results:"
print_summary summary.csv

awk -F, '{ if ($8 > 0)  print }' summary.csv >summary-errors.csv

if [[ $(wc -l <summary-errors.csv) -gt 1 ]]; then
    echo -ne "\n\n"
    echo "WARNING: There are errors in measurement results! Please check."
    print_summary summary-errors.csv
fi

cd $results_dir
mkdir -p $output_dir/scenarios
output_scenarios_dir=$output_dir/scenarios
cp $stack_results_dir/results.zip $output_scenarios_dir
unzip $stack_results_dir/results.zip -d $output_scenarios_dir
unzip_dir="$output_scenarios_dir/results"

# Find the jtl zips and unzip them. Test grid finds for jtls inorder to complete the test
find $unzip_dir -name '*.zip' -exec sh -c 'unzip -d `dirname {}` {}' ';'
chmod -R 777 $unzip_dir
# Create a dummy jtl file
touch $unzip_dir/dummy.jtl
