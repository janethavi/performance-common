# Back-end Server Performance Test Results

These are the performance test results of a [Netty](https://netty.io/) based Back-end service which echoes back any request
posted to it after a specified period of time. This is the Back-end that is used in the performance tests of WSO2 products.

| Test Scenarios | Description |
| --- | --- |
| Echo service - HTTP/1.1 over cleartext | An HTTP/1.1 over cleartext echo service implemented in Netty. |
| Echo service - HTTP/1.1 over TLS | An HTTP/1.1 over TLS echo service implemented in Netty. |

Our test client is [Apache JMeter](https://jmeter.apache.org/index.html). We test each scenario for a fixed duration of
time. We split the test results into warmup and measurement parts and use the measurement part to compute the
performance metrics.

We run the Back-end performance tests under different numbers of concurrent users, message sizes (payloads) and Back-end service
delays.

The main performance metrics:

1. **Throughput**: The number of requests that the Back-end Server processes during a specific time interval (e.g. per second).
2. **Response Time**: The end-to-end latency for an operation of invoking an API. The complete distribution of response times was recorded.

In addition to the above metrics, we measure the load average and several memory-related metrics.

The following are the test parameters.

| Test Parameter | Description | Values |
| --- | --- | --- |
| Scenario Name | The name of the test scenario. | Refer to the above table. |
| Heap Size | The amount of memory allocated to the application | 4G |
| Concurrent Users | The number of users accessing the application at the same time. | 100, 200, 500 |
| Message Size (Bytes) | The request payload size in Bytes. | 1024, 10240 |
| Back-end Delay (ms) | The delay added by the Back-end service. | 0, 1000 |

The duration of each test is **300 seconds**. The warm-up period is **120 seconds**.
The measurement results are collected after the warm-up period.

The performance tests were executed on 1 AWS CloudFormation stack.

System information for Back-end Server in 1st AWS CloudFormation stack.

| Class | Subclass | Description | Value |
| --- | --- | --- | --- |
| AWS | EC2 | AMI-ID | ami-024a64a6685d05041 |
| AWS | EC2 | Instance Type | c5.xlarge |
| System | Processor | CPU(s) | 4 |
| System | Processor | Thread(s) per core | 2 |
| System | Processor | Core(s) per socket | 2 |
| System | Processor | Socket(s) | 1 |
| System | Processor | Model name | Intel(R) Xeon(R) Platinum 8124M CPU @ 3.00GHz |
| System | Memory | BIOS | 64 KiB |
| System | Memory | System memory | 7807988 KiB |
| System | Storage | Block Device: nvme0n1 | 8G |
| Operating System | Distribution | Release | Ubuntu 18.04.2 LTS |
| Operating System | Distribution | Kernel | Linux ip-10-0-1-232 4.15.0-1039-aws #41-Ubuntu SMP Wed May 8 10:43:54 UTC 2019 x86_64 x86_64 x86_64 GNU/Linux |

The following are the measurements collected from each performance test conducted for a given combination of
test parameters.

| Measurement | Description |
| --- | --- |
| Error % | Percentage of requests with errors |
| Average Response Time (ms) | The average response time of a set of results |
| Standard Deviation of Response Time (ms) | The “Standard Deviation” of the response time. |
| 99th Percentile of Response Time (ms) | 99% of the requests took no more than this time. The remaining samples took at least as long as this |
| Throughput (Requests/sec) | The throughput measured in requests per second. |
| Average Memory Footprint After Full GC (M) | The average memory consumed by the application after a full garbage collection event. |

The following is the summary of performance test results collected for the measurement period.

|  Scenario Name | Heap Size | Concurrent Users | Message Size (Bytes) | Back-end Service Delay (ms) | Error % | Throughput (Requests/sec) | Average Response Time (ms) | Standard Deviation of Response Time (ms) | 99th Percentile of Response Time (ms) | Back-end Server GC Throughput (%) | Average Back-end Server Memory Footprint After Full GC (M) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|  Echo service - HTTP/1.1 over cleartext | 4G | 100 | 1024 | 0 | 0 | 37744.39 | 2.51 | 3.28 | 6 | 99.98 |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 100 | 1024 | 1000 | 0 | 99.49 | 1002 | 0.09 | 1003 |  |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 100 | 10240 | 0 | 0 | 23376.15 | 4.12 | 3.12 | 9 | 99.98 |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 100 | 10240 | 1000 | 0 | 99.48 | 1002 | 0.25 | 1003 |  |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 200 | 1024 | 0 | 0 | 36299.95 | 4.91 | 7.63 | 30 | 99.98 |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 200 | 1024 | 1000 | 0 | 198.8 | 1002.01 | 0.5 | 1003 |  |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 200 | 10240 | 0 | 0 | 22047.87 | 8.46 | 8.93 | 36 | 99.98 |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 200 | 10240 | 1000 | 0 | 198.84 | 1002 | 0.25 | 1003 |  |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 500 | 1024 | 0 | 0 | 31714.33 | 13.23 | 13.4 | 59 | 99.98 |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 500 | 1024 | 1000 | 0 | 496.83 | 1002.01 | 0.37 | 1003 |  |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 500 | 10240 | 0 | 0 | 21259.24 | 18.38 | 17.39 | 67 | 99.98 |  |
|  Echo service - HTTP/1.1 over cleartext | 4G | 500 | 10240 | 1000 | 0 | 496.31 | 1002.01 | 0.43 | 1003 |  |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 100 | 1024 | 0 | 0 | 21585.88 | 4.5 | 3.81 | 8 | 99.98 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 100 | 1024 | 1000 | 0 | 108.46 | 919.05 | 274.18 | 1003 |  |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 100 | 10240 | 0 | 0 | 5178.85 | 19.05 | 7.57 | 41 | 99.98 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 100 | 10240 | 1000 | 0 | 104.46 | 953.12 | 213.68 | 1003 |  |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 200 | 1024 | 0 | 0 | 20689.71 | 9.08 | 9.75 | 36 | 99.98 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 200 | 1024 | 1000 | 0 | 237.97 | 836.77 | 367.92 | 1003 |  |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 200 | 10240 | 0 | 0 | 5151.43 | 37.67 | 21.86 | 126 | 99.98 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 200 | 10240 | 1000 | 0 | 226.68 | 877.83 | 327.04 | 1003 |  |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 500 | 1024 | 0 | 0 | 19312.84 | 22.21 | 20.64 | 88 | 99.98 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 500 | 1024 | 1000 | 0 | 943.32 | 527.02 | 497.19 | 1003 |  |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 500 | 10240 | 0 | 0 | 5118.01 | 87.44 | 93.4 | 531 | 99.98 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 500 | 10240 | 1000 | 0 | 669.9 | 742.26 | 432.67 | 1003 |  |  |
