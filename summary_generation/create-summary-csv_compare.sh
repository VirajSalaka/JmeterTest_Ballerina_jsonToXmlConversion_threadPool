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
# Create a summary report from JMeter results
# ----------------------------------------------------------------------------

gcviewer_path=$PWD/gcviewer-1.36-SNAPSHOT.jar
#true or false argument
include_all=$1


#if [[ ! -f $gcviewer_path ]]; then
 #   echo $gcviewer_path
  #  echo "Please specify the path to GCViewer JAR file. Example: $0 gcviewer_jar_file include_all->(true/false)"
   # exit 1
#fi

get_gc_headers() {
    echo -ne ",$1 GC Throughput (%),$1 Footprint (M),$1 Average of Footprint After Full GC (M)"
    echo -ne ",$1 Standard Deviation of Footprint After Full GC (M)"
}

get_loadavg_headers() {
    echo -ne ",$1 Load Average - Last 1 minute,$1 Load Average - Last 5 minutes,$1 Load Average - Last 15 minutes"
}

filename="compare_summary.csv"
if [[ ! -f $filename ]]; then
    # Create File and save headers
    echo -n "Type", "ThreadPool Size","Concurrent Users", > $filename
    echo -n "sampler_label,aggregate_report_count,average,aggregate_report_median,aggregate_report_90%_line,aggregate_report_95%_line,aggregate_report_99%_line,aggregate_report_min,aggregate_report_max,aggregate_report_error%,aggregate_report_rate,aggregate_report_bandwidth,aggregate_report_stddev" >> $filename
    echo -n $(get_gc_headers "Ballerina") >> $filename
    if [ "$include_all" = true ] ; then
        echo -n $(get_gc_headers "JMeter Client") >> $filename
    fi
    echo -n $(get_loadavg_headers "Ballerina") >> $filename
    if [ "$include_all" = true ] ; then
        echo -n $(get_loadavg_headers "JMeter Client") >> $filename
    fi
    echo -ne "\r\n" >> $filename
else
    echo "$filename already exists"
    exit 1
fi

write_column() {
    if [ "$1" = "none" ]
    then
        echo -n ",-" >> $filename
    else
        statisticsTableData=$1
        index=$2
        echo -n "," >> $filename
        echo -n "$(echo $statisticsTableData | jq -r ".overall | .data[$index]")" >> $filename
    fi			  

}

get_value_from_gc_summary() {
    echo $(grep -m 1 $2\; $1 | sed -r 's/.*\;(.*)\;.*/\1/' | sed 's/,//g')
}

write_gc_summary_details() {
    gc_log_file=$user_dir/$1_gc.log
    gc_summary_file=/tmp/gc.txt
    echo "Reading $gc_log_file"
    java -Xms128m -Xmx128m -jar $gcviewer_path $gc_log_file $gc_summary_file -t SUMMARY &> /dev/null
    echo -n ",$(get_value_from_gc_summary $gc_summary_file throughput)" >> $filename
    echo -n ",$(get_value_from_gc_summary $gc_summary_file footprint)" >> $filename
    echo -n ",$(get_value_from_gc_summary $gc_summary_file avgfootprintAfterFullGC)" >> $filename
    echo -n ",$(get_value_from_gc_summary $gc_summary_file avgfootprintAfterFullGCσ)" >> $filename
}

write_loadavg_details() {
    loadavg_file=$user_dir/$1_loadavg.txt
    if [[ -f $loadavg_file ]]; then
        echo "Reading $loadavg_file"
        loadavg_values=$(tail -2 $loadavg_file | head -1)
        loadavg_array=($loadavg_values)
        echo -n ",${loadavg_array[3]}" >> $filename
        echo -n ",${loadavg_array[4]}" >> $filename
        echo -n ",${loadavg_array[5]}" >> $filename
    else
        echo -n ",N/A,N/A,N/A" >> $filename
    fi
}

write_report_column() {
    line2=$(head -2 $1 | tail -1)
    echo -n ",$line2" >> $filename
}

for threadpool_size_dir in $(find . -maxdepth 1 -name '*Threads' | sort -V)
do
        for user_dir in $(find $threadpool_size_dir -maxdepth 1 -name '*_users' | sort -V)
        do
            dashboard_data_file=$user_dir/dashboard-measurement/content/js/dashboard.js
            if [[ ! -f $dashboard_data_file ]]; then
                echo "WARN: Dashboard data file not found: $dashboard_data_file"
                continue
            fi
            statisticsTableData=$(grep '#statisticsTable' $dashboard_data_file | sed  's/^.*"#statisticsTable"), \({.*}\).*$/\1/')
            echo "Getting data from $dashboard_data_file"
            threadpool_size=$(echo $message_size_dir | sed -r 's/.\/([0-9]+)Threads.*/\1/')
            concurrent_users=$(echo $user_dir | sed -r 's/.*\/([0-9]+)_users.*/\1/')
            echo -n "Dashboard," >> $filename
            echo -n "$threadpool_size,$concurrent_users" >> $filename
            write_column "none"
            write_column "$statisticsTableData" 1
            write_column "$statisticsTableData" 4
            write_column "none"
            write_column "$statisticsTableData" 7
            write_column "$statisticsTableData" 8
            write_column "$statisticsTableData" 9
            write_column "$statisticsTableData" 5
            write_column "$statisticsTableData" 6
            write_column "$statisticsTableData" 3
            write_column "$statisticsTableData" 10
            write_column "none"
            write_column "none"

            write_gc_summary_details ballerina_host
            if [ "$include_all" = true ] ; then
                write_gc_summary_details jmeter
            fi

            write_loadavg_details ballerina_host
            if [ "$include_all" = true ] ; then
                write_loadavg_details jmeter
            fi

            echo -ne "\r\n" >> $filename
            
            echo -n "Aggregate," >> $filename
            echo -n "$threadpool_size,$concurrent_users" >> $filename
            unzip $user_dir/jtls.zip
            java -jar /home/viraj/apache-jmeter-3.3/lib/cmdrunner-2.0.jar --tool Reporter --plugin-type AggregateReport --input-jtl results-measurement.jtl --generate-csv current_result.csv
            write_report_column "current_result.csv"
            rm results-measurement.jtl
            rm results-warmup.jtl
            rm current_result.csv
            echo -ne "\r\n" >> $filename
            echo -n "-" >> $filename
            echo -ne "\r\n" >> $filename
        done
done

echo "Completed. Open $filename."
