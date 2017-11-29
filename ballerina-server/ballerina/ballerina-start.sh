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
# Start WSO2 API Manager
# ----------------------------------------------------------------------------



#1st variable threadpoolsize
#needs to be edited

#service_name
service_name=java
pool_size=$1
log_files=($BALLERINA_HOME/logs/*)
if [ ${#log_files[@]} -gt 1 ]; then
    echo "Log files exists. Moving to /tmp"
    mv $BALLERINA_HOME/logs/tmp/;
fi


if pgrep -f "$service_name" > /dev/null; then
    echo "Shutting down Bal service"
    pkill -f $service_name
fi

echo "waiting for ballerina service to stop"

while true
do
    if ! pgrep -f "$service_name" > /dev/null; then
        echo "Bal service is stopped"
        break
    else
        sleep 10
    fi
done

netstat -ltnp;


echo "Enabling GC Logs"
export JAVA_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -DexecutorPoolSize=${pool_size} -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:$BALLERINA_HOME/logs/gc.log"

echo "Starting Ballerina"
nohup ballerina run jsonToXmlConversion.bal > bal.out 2>&1 &

echo "Waiting for Ballerina to start"
sleep 10

#while true 
#do
    # Check Version service
#    response_code="$(curl -sk -w "%{http_code}" -o /dev/null https://localhost:8243/services/Version)"
#    if [ $response_code -eq 200 ]; then
 #       echo "API Manager started"
  #      break
   # else
    #    sleep 10
   # fi
#done

# Wait for another 10 seconds to make sure that the server is ready to accept API requests.
sleep 10
netstat -ltnp
