#!/bin/bash

for benchmark in ./to_execute/*.gz; do
        tar -zxvf $benchmark
        base=${benchmark##*/}
        target=${base%-executables.tar.gz}

        out_dir="./$target-results"
        in_dir="./$target-executables"

        echo $base $target $out_dir $in_dir

        mkdir -p $out_dir
        for f in $in_dir/*.exe; do
                $f & PROCESS_ID=$!
                echo $PROCESS_ID
                ps -aux | grep "$PROCESS_ID"
                bname=$(basename $f)
                fname=${bname%.*}
                # warm up cache
                sleep 2
                time=10
                # create output csv
                echo "counter value,counter unit,event name,run time,% measurement time,metric value,metric unit" > "$out_dir/$fname-$time.csv"
                # measure perf stat
                perf stat -x , -e task-clock,context-switches,cpu-migrations,page-faults,cycles,instructions,branches,branch-misses,stalled-cycles-frontend,stalled-cycles-backend,eu_stall,if_stall,id_stall,ib_stall -p $PROCESS_ID sleep $time 2>> "$out_dir/$fname-$time.csv"
                kill $PROCESS_ID
        done
        tar -czvf $target-results.tar.gz $target-results/
done
