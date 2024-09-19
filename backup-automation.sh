#!/bin/bash

usageFunction()
{
   echo "Error - Invalid parameters passed to the script" >> ${log_file_name}
   echo "Usage: $0 -n <namespace> -p <policy_name>" >> ${log_file_name}
   echo "-n (required) specifies the namespace to be backed up" >> ${log_file_name}
   echo "-p (required) specifies the policy name to be used for backup" >> ${log_file_name}
   echo "-r (required) specifies the roun count" >> ${log_file_name}
   echo "-d (required) specifies the expiry date of the kasten backup. Date should be in the format YYYY-MM-DD." >> ${log_file_name}
   exit 1
}

createRunAction()
{
cat<<EOF | kubectl create -f -
apiVersion: actions.kio.kasten.io/v1alpha1
kind: RunAction
metadata:
  generateName: run-backup-${namespace}-
  namespace: kasten-io
spec:
  expiresAt: "${expiry_date}T23:59:59Z"
  subject:
    kind: Policy
    name: ${policy_name} 
    namespace: kasten-io
EOF

#get runaction name
sleep 15
runaction_name=`kubectl get runaction -n kasten-io | grep run-backup-${namespace}- | awk 'NR==1{print $1}'`
echo "Runaction Name : ${runaction_name}"  >> ${log_file_name}

}

checkStatus()
{
global_timeout=7200
timeout=0

while [[ ${timeout} -le ${global_timeout} ]]
do
  runaction_status=`kubectl get runactions.actions.kio.kasten.io ${runaction_name} -n kasten-io -ojsonpath="{.status.state}{'\n'}"`
  if [[ -z ${runaction_status} ]]; then
    echo "Unable to get the status of RunAction ${runaction_name}. Check the logs"  >> ${log_file_name}
    exit 1
  elif [[ ${runaction_status} == "Skipped" ]]; then
    echo "RunAction ${runaction_name} was Skipped. This is not an expected behavior. Check logs"  >> ${log_file_name}
    exit 1
  elif [[ ${runaction_status} == "Deleting" ]]; then
    echo "RunAction ${runaction_name} is in Deleting state. This is not an expected behavior. Check logs"  >> ${log_file_name}
    exit 1
  elif [[ ${runaction_status} == "Complete" ]]; then
    echo "RunAction ${runaction_name} Completed Successfully"   >> ${log_file_name}
    collectRunActionMetrics
    break
  elif [[ ${runaction_status} == "Failed" ]]; then
    echo "RunAction ${runaction_name} Failed. Check Kasten dashboard for more details"  >> ${log_file_name}
    exit 1
  elif [[ ${runaction_status} == "Cancelled" ]]; then
    echo "RunAction ${runaction_name} Cancelled. Check Kasten dashboard for more details"  >> ${log_file_name}
    exit 1  
  #elif [[ ${runaction_status} == "Running" ]]; then
    #echo "RunAction ${runaction_name} is still in Running state...."  >> ${log_file_name}
  fi

  sleep 30
  timeout=$((timeout + 30))
done
}

collectRunActionMetrics()
{

kubectl get runaction ${runaction_name} -n kasten-io -o jsonpath='Name: {.metadata.name}{"\n"}' >> ${log_file_name}
kubectl get runaction ${runaction_name} -n kasten-io -o jsonpath='Status: {.status.state}{"\n"}' >> ${log_file_name}
start_time=`kubectl get runaction ${runaction_name} -n kasten-io -o jsonpath='{.status.startTime}'`
end_time=`kubectl get runaction ${runaction_name} -n kasten-io -o jsonpath='{.status.endTime}'`
difference=$(($(date -u -d "$end_time" +"%s") - $(date -u -d "$start_time" +"%s")))

# Convert the difference to hours, minutes, and seconds
hours=$((difference / 3600))
minutes=$(((difference % 3600) / 60))
seconds=$((difference % 60))

echo "Run-Time: $hours hours, $minutes minutes, $seconds seconds"  >> ${log_file_name}


}

applyChangeRate()
{

pod_name=`kubectl get pods -n $namespace --no-headers | awk '{print $1}'`

echo "Updating the PVC data - `date` " >> ${log_file_name}

cmd="kubectl exec ${pod_name} -n ${namespace}  -- /bin/sh /data/apply-change.sh -f 7 -d 7 -s 1872 -i 20 -o /data"
eval $cmd

if [ $? -eq 0 ]; then
  echo "Successfully updated the PVC data - `date`" >> ${log_file_name}
else
  echo "Unable to update the PVC data. Command failed with return code $?." >> ${log_file_name}
  exit 1
fi

}

#main

no_args="true"
cnt=1

#Parse the input parameters 
while getopts n:p:r:d: flag 
do
    case "${flag}"
        in
        n) namespace=${OPTARG}
           ;;
        p) policy_name=${OPTARG}
           ;;
        r) run_count=${OPTARG}
           ;;
        d) expiry_date=${OPTARG}
	   ;;
        *) usageFunction
           ;;
    esac
    no_args="false"
done

if [[ $no_args == "true" || -z $namespace || -z $policy_name || -z $run_count || -z ${expiry_date} ]] 
then 
   usageFunction
fi

ts=`date +%Y-%m-%d-%H.%M.%S`
log_file_name=/opt/logs/${namespace}-automation-$ts.log
echo "Starting the script - `date`" >> ${log_file_name}

while [[ ${cnt} -le ${run_count} ]]    
do
  echo "--------------------------------------------------------" >> ${log_file_name}
  echo "Start Run $cnt - `date`" >> ${log_file_name}
  createRunAction
  checkStatus
  applyChangeRate
  echo "End Run $cnt - `date` " >> ${log_file_name}

  cnt=$((cnt+1))
done

echo "--------------------------------------------------------" >> ${log_file_name}
echo "Ending the script - `date` " >> ${log_file_name}
