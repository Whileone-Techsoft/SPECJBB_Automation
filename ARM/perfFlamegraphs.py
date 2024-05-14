import subprocess,datetime
import time,threading


#commands = "cd /opt/SPECJBB/jdk-17.0.10/; export JAVA_HOME=`pwd`; export PATH=`pwd`/bin:$PATH"
#subprocess.run(commands,shell=True)
def run_background_process():
    
    background_command = ["./run.sh"]
    subprocess.Popen(background_command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(20)
    commands = "cd /opt/SPECJBB/java-versions/jdk-17.0.10; export JAVA_HOME=`pwd`; export PATH=`pwd`/bin:$PATH; echo $JAVA_HOME; touch /opt/SPECJBB/specjbb2015-1.03-lib/processes.pid;  ps ax | grep java > /opt/SPECJBB/specjbb2015-1.03-lib/processes.pid"
    pids=[]
    count=0
    result = subprocess.run(commands,shell=True, capture_output=True, text=True)
    with open('/opt/SPECJBB/specjbb2015-1.03-lib/processes.pid',"r") as file:
        l_strip = [s.rstrip() for s in file.readlines()]
        for line in l_strip:
            p = line.split(' ')
            count+=1
            pids.append(p[0])
            if count == 3:
                break
    print(pids)
#def run_parallel_process_2():
    print("=====./create-java-perf-map.sh {pid} command started=====")
    for pid in pids:
        commands = f"cd /opt/SPECJBB/java-versions/jdk-17.0.10; export JAVA_HOME=`pwd`; export PATH=`pwd`/bin:$PATH; echo $JAVA_HOME; cd /opt/SPECJBB/perf-map-agent-0.9/bin; ./create-java-perf-map.sh {pid}"
        subprocess.run(commands,shell=True)

    print("===== ./jmaps command started=====")
    commands = "cd /opt/SPECJBB/java-versions/jdk-17.0.10; export JAVA_HOME=`pwd`; export PATH=`pwd`/bin:$PATH; echo $JAVA_HOME; cd /opt/SPECJBB/FlameGraph; sudo ./jmaps"
    subprocess.run(commands,shell=True)
    commands = "cd /opt/SPECJBB/java-versions/jdk-17.0.10; export JAVA_HOME=`pwd`; export PATH=`pwd`/bin:$PATH; echo $JAVA_HOME; cd /opt/SPECJBB/perf-map-agent-0.9; sudo chown root /tmp/perf*.map;"
    subprocess.run(commands,shell=True)

#Date Time Capture
    '''
    commands = "cdatetime = datetime.datetime.now(); fdatetime = cdatetime.strftime('%Y%m%d_%H%M%S')"
    rdate = subprocess.run(commands,capture_output=True, text=True)
    fdatetime = rdate.stdout
    '''
#def  run_parallel_process_3():
#Fetch Architecture name for maping to files name
    result = subprocess.run(['lscpu'], capture_output=True, text=True)
    output = result.stdout
    lines = output.split('\n')

    for line in lines:
        if 'Architecture:' in line:
            arch = line.split(':')[1].strip()
            break

#Create .data files

    commands = f"sudo perf record -F 99 -p {pids[0]} -g -o {arch}_perf_1.data & sudo perf record -F 99 -p {pids[1]} -g -o {arch}_perf_2.data & sudo perf record -F 99 -p {pids[2]} -g -o {arch}_perf_3.data"
    subprocess.run(commands,shell=True)


#Create .perf files
    commands = f"sudo perf script -i {arch}_perf_1.data > out_1.perf; sudo perf script -i {arch}_perf_2.data > out_2.perf; sudo perf script -i {arch}_perf_3.data > out_3.perf"
    subprocess.run(commands,shell=True)

#Create SVG's
    commands = f"cd /opt/SPECJBB/FlameGraph; sudo perf script -i ../specjbb2015-1.03-lib/{arch}_perf_1.data | ./stackcollapse-perf.pl  | ./flamegraph.pl --color=java --hash > flamegraph_1.svg; sudo perf script -i ../specjbb2015-1.03-lib/{arch}_perf_2.data | ./stackcollapse-perf.pl  | ./flamegraph.pl --color=java --hash > flamegraph_2.svg; sudo perf script -i ../specjbb2015-1.03-lib/{arch}_perf_3.data | ./stackcollapse-perf.pl  | ./flamegraph.pl --color=java --hash > flamegraph_3.svg"
    subprocess.run(commands,shell=True)


run_background_process()
#run_background_process_1()
#run_parallel_process_2()
#run_parallel_process_3()
