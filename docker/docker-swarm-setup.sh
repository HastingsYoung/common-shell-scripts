#!/bin/bash

function usage() {
	echo "This script helps to bootstrap docker-swarm cluster in minutes."
	echo "It is created by and maintained by <${author}>."
	echo "Usage: [-option arg] keypath server [...server] "
	echo "Master server default to the first server specified."
	echo "Argument List:"
	echo -e "\t-v current version of the script"
	echo -e "\t-h hostname of server to deploy (default: ${host_name})"
	echo -e "\t-c swarm cluster (default: ${cluster})"
	echo -e "\t-n swarm overlay network (default: ${overlay_network})"
	echo "Note: Please make sure the following ports are open on your machine:"
	echo -e "\tType\tPort\tDescription"
	echo -e "\tTCP\t2377\tcluster management communications"
	echo -e "\tTCP\t7946\tcommunications among nodes"
	echo -e "\tUDP\t7946\tcommunications among nodes"
	echo -e "\tUDP\t4789\toverlay network traffic"
}

function checkDockerSetup() {
	key=${args_arr[0]}
	if [ $# -gt 1 ]; then
		echo "Found key <${key}>";
		for ((i=1;i<$#;i++));
			do echo "Connecting to <${args_arr[i]}>...";
			vcheck=$(ssh -i "${key}" "${host_name}@${args_arr[i]}" "docker -v; docker-compose -v;");
			dk_version=$(echo $vcheck | grep -o 'Docker version \d\d.\d\d.\d\(-\w\w\)\?'| grep -o '\d\d.\d\d.\d\(-\w\w\)\?');
			dkc_version=$(echo $vcheck | grep -o 'docker-compose version \d.\d\d.\d'| grep -o '\d.\d\d.\d');
			if [ -z "${dk_version}" ]; then 
				echo "Error: docker daemon not found"; exit 0;
			fi
			if [ -z "${dkc_version}" ]; then 
				echo "Error: docker compose not found"; exit 0;
			fi
			echo "Docker version: <${dk_version}>";
			echo "Docker Compose version: <${dkc_version}>";
			echo "Pass setup verification at <${args_arr[i]}>";
		done;
	else
		echo "Error: missing arguments";
		usage;
		exit 0;
	fi;
}

function lsNodes() {
	key=$1
	server=$2
	ssh -i "${key}" "${host_name}@${server}" "sudo docker node ls";
}

function setupSwarm() {
	triage=$1
	key=$2
	server=$3
	case $triage in
		master)
				echo "Start setting up master node..."
				init_resp=$(ssh -i "${key}" "${host_name}@${server}" "sudo docker swarm init --advertise-addr \$(hostname -I | awk '{print \$1}'):2377");
				join_cmd=$(echo $init_resp | grep -o 'docker swarm join \-\-token [A-Za-z0-9\-]\+ \d\+\.\d\+\.\d\+\.\d\+');
				token=$(echo $join_cmd | grep -o '[A-Za-z0-9\-]\{20,\}');
				echo "Acquired token: <${token}>"
				;;
		worker)
				echo "Start setting up worker node..."
				join_resp=$(ssh -i "${key}" "${host_name}@${server}" "sudo ${join_cmd}");
				echo $join_resp;
				;;
	esac
}

# accept arguments
host_name='ubuntu'
cluster='default_cluster'
overlay_network='default_network'
script_version='1.0.0'
author='Hastings Yeung'

while getopts "h:c:v" opt; do
		case $opt in
			h) 
				host_name=$OPTARG
				;;
			c)
				cluster=$OPTARG
				;;
			n)
				overlay_network=$OPTARG
				;;
			v) 
				echo "Script version ${script_version} (Copyright by ${author})";
				exit 0 ;;
			\?) usage ;;
		esac
	done

shift "$((OPTIND-1))"
args_arr=("$@")
token=''
join_cmd=''
keypath=${args_arr[0]}

# check docker installation && version of each node
checkDockerSetup ${args_arr[@]}

setupSwarm master ${keypath} ${args_arr[1]}

for ((i=2;i<$#;i++));
	do setupSwarm worker ${keypath} ${args_arr[i]}
	done;

echo "Setup complete:";
lsNodes ${keypath} ${args_arr[1]}

# todo: check swarm connectivity