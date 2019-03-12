# Back-end Server Performance Test Results

These are the performance test results of a [Netty](https://netty.io/) based Back-end service which echoes back any request
posted to it after a specified period of time. This is the Back-end that is used in the performance tests of WSO2 products.

| Test Scenarios | Description |
| --- | --- |
| Echo service - HTTP/1.1 over TLS | An HTTP/1.1 over TLS echo service implemented in Netty. |
| Echo service - HTTP/2 over TLS | An HTTP/2 over TLS echo service implemented in Netty. |

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
| Concurrent Users | The number of users accessing the application at the same time. | 100, 500 |
| Message Size (Bytes) | The request payload size in Bytes. | 50, 1024 |
| Back-end Delay (ms) | The delay added by the Back-end service. | 0, 30 |

The duration of each test is **240 seconds**. The warm-up period is **60 seconds**.
The measurement results are collected after the warm-up period.

A [**c5.xlarge** Amazon EC2 instance](https://aws.amazon.com/ec2/instance-types/) was used to install Back-end Server.

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
|  Echo service - HTTP/1.1 over TLS | 4G | 100 | 50 | 0 | 0 | 33369.21 | 2.85 | 3.38 | 6 | 99.97 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 100 | 50 | 30 | 0 | 3197.34 | 30.34 | 1.48 | 31 | 99.98 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 100 | 1024 | 0 | 0 | 22080.68 | 4.35 | 3.45 | 7 | 99.97 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 100 | 1024 | 30 | 0 | 3290.29 | 30.35 | 1.63 | 31 | 99.98 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 500 | 50 | 0 | 0 | 28321.07 | 15.02 | 15.08 | 60 | 99.97 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 500 | 50 | 30 | 0 | 16193.92 | 30.77 | 4.38 | 53 | 99.97 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 500 | 1024 | 0 | 0 | 19799.92 | 22.11 | 22.41 | 87 | 99.97 |  |
|  Echo service - HTTP/1.1 over TLS | 4G | 500 | 1024 | 30 | 0 | 16117.07 | 30.95 | 4.92 | 58 | 99.97 |  |
|  Echo service - HTTP/2 over TLS | 4G | 100 | 50 | 0 | 0 | 23544.15 | 0.21 | 1.42 | 1 | 99.97 | 12.78 |
|  Echo service - HTTP/2 over TLS | 4G | 100 | 50 | 30 | 0 | 23888.8 | 0.56 | 1.89 | 4 | 99.96 | 12.802 |
|  Echo service - HTTP/2 over TLS | 4G | 100 | 1024 | 0 | 0 | 16584.45 | 0.3 | 2.09 | 1 | 99.97 | 12.772 |
|  Echo service - HTTP/2 over TLS | 4G | 100 | 1024 | 30 | 0 | 16903.07 | 0.52 | 2 | 3 | 99.96 | 12.783 |
