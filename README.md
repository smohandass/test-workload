# Introduction

This repo discuss about deploying a workload in kuberenetes cluster and creating dummy data that can be used for testing purposes.

## Step 1 : Create the test workload 

Clone the git repo and use the `test-workload.yaml` to create a kubernetes namespace, persistentvolumeclaim and a deployment. Make sure you are connected to the right kuberenetes cluster and have permissions to create kuberenetes artifacts.

```
git clone https://github.com/smohandass/test-workload.git
cd test-workload
kubectl create -f test-workload.yaml
```

Note: The `test-workload.yaml` file uses the image `bullseie/test-workload:latest` from docker hub. This image already includes the scripts `workload-create.sh` and `apply-change.sh` under `/opt` directory. The dockerfile and the scripts are included in the GitHub Repo if you wish to make implement any additional changes. 

Verify that the pod is successfully running 
```
kubectl get pods -n test-workload
NAME                                    READY   STATUS    RESTARTS   AGE
test-workload-deploy-7f996d5dbb-f6shs   1/1     Running   0          27m
```

## Step 2 - Create the dummy data

The pod contains two scripts under `/opt` directory.  

The `workload-create.sh` script is used for the initial creation of files. This script takes several input parameters that control the size of each file, number of nested directories to create and number of files to create in each directory. Below is the usage of the script and what each parameter represents

```
Usage:
./workload-create.sh -f <# of files to create> -d <directory depth> -s <file size> -i <# of iterations> -o <Output Directory>
-f (required) specifies the number of files and sub-directories to create in each folder until the specified depth is reached
-d (required) specifies the depth of the sub-directories to create
-s (required) specifies the size of files to create in bytes
-i (required) specifies the number of iterations to run
-o (required) specifies the Output directory where the files are created. The script assumes the output directory exists and has permissions to write
Note: The directory path specified with -o parameter need to be a valid path inside the pod and has enough space. 
```

Note: The output directory specified using -o parameter should match the volumemount path specified in `test-workload.yaml`. This path is attached to a persistentvolumeclaim that persists the data even if the pod is restarted.

### Example 1: 

```
/opt/workload-create.sh -f 6 -d 6 -s 1872 -i 2 -o /data
```

When running the script with the above specified values, it creates two iteration directories (specified by -i parameter) under /data directory (specified by -o parameter). In each Iteration directory it creates 6 files and 6 sub-directories (specified by -f parameter) until to a depth of 6 (specified by -d parameter) under the output directory is reached. Each file will be of size 1872 bytes (specified by -s parameter).  

These inputs create 1555 directories and 9330 files under each iteration directory.

```
kubectl exec -it test-workload-deploy-7f996d5dbb-f6shs -n test-workload -- sh
cd /data
# ls
iteration1  iteration2
#cd /data/iteration1
# ls -lR |grep ^d |wc -l 
1555
# ls -lR |grep ^- |wc -l
9330
```

### Example 2: 

Now let's look at another example where i increase the files and sub-directories, and the depth to 7. You can now see that the total files and directories created in each iteration directory has increased.

```
kubectl exec -it test-workload-deploy-7f996d5dbb-f6shs -n test-workload -- sh
/opt/workload-create.sh -f 7 -d 7 -s 1872 -i 1 -o /data
cd /data/iteration1
# ls -lR |grep ^d |wc -l
19607
#ls -lR |grep ^- |wc -l
137256
```

Depending on your test criteria on how many files you need, these parameters can be adjusted. For example, if I want around 1 million files in the PVC as the test data, I can adjust the iteration value to 8 , resuling in 1098048 total files created.

Note: The size of the PVC need to be adjusted in `test-workload.yaml` file depending on how many files are being created and how much overall space it consumes.

## Step 3 - Applying change rate to the dummy data

In previoud step, I talked about how to create the initial data needed for the testing. The script `apply-change.sh` is used to update the data in the PVC and it does by deleting and adding new data. This script is similar to the workload-create script and takes the same set of input parameters. The -i parameter in `apply-change.sh` script is used to control the percentage of change rate to be applied. 

```
Usage:
./apply-change.sh -f <# of files to create> -d <directory depth> -s <file size> -i <# of iterations> -o <Output Directory>
-f (required) specifies the number of files and sub-directories to create in each folder until the specified depth is reached
-d (required) specifies the depth of the sub-directories to create
-s (required) specifies the size of files to create in bytes
-i (required) specifies the number of iterations to run
-o (required) specifies the Output directory where the files are created. The script assumes the output directory exists and has permissions to write
```

Let’s assume when creating the initial files the `-i` value passed is 10. The script would have created 10 iteration directories. In order to apply a change rate of 20% only 2 iteration directories need to be removed and two new ones need to be created. By running the script `apply-change.sh` with -i value as 2, the script will remove the oldest 2 iteration directories and create two new ones resulting in a net 20% change of data in the PVC. 

```
kubectl exec -it test-workload-deploy-7f996d5dbb-f6shs -- sh
/opt/workload-create.sh -f 6 -d 6 -s 1872 -i 4 -o /data

ls /data
iteration1  iteration2  iteration3  iteration4  logs

/opt/apply-change.sh -f 6 -d 6 -s 1872 -i 2 -o /data
ls /data
iteration3  iteration4  iteration5  iteration6  logs
```

In the output above, you can see that the two oldest directories iteration1 and iteration2 is deleted and directories iteration5 and iteration6 are created with new data. 

## Step 4 - Automating the process of running backup

Now that we have a process to create test data and apply a specific change rate as needed, we can use this to run automated backup tests using Kasten. The script expects that a kasten policy is already defined with the required settings. When run the script will create a runaction for the specified policy to create a backup. When the backup is complete, the script applies the required change rate and creates another backup. It repeats the process until the number of runs specified is reached. The parameters for applying the change rate has been hard coded and can be changed according to individual needs. 

```
Usage:
cd test-workload
./backup-automation.sh -n <namespace> -p <policy-name> -r <number-of-runs> -d <policy-expiry-date>
-n (required) specifies the namespace to be backed up
-p (required) specifies the policy name to be used for backup
-r (required) specifies the number of runs 
-d (required) specifies the expiry date of the kasten backup. Date should be in the format YYYY-MM-DD
```

Example

```
./backup-automation.sh -n test-workload -p test-workload-backup-policy -r 10 -d 2024-10-10
```






 

