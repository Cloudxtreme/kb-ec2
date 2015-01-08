# Setup (Test Runner)

Machine (close to the KB server) where the (load) tests will run.

## Install

- Setup Java (for JMeter) `apt-get install -y openjdk-7-jre-headless`

- Apache JMeter `apt-get install -y jmeter`

  unfortunately no GUI-less version package alternatively (less junk installed) :
  - `wget http://www.eu.apache.org/dist//jmeter/binaries/apache-jmeter-2.12.tgz`
  - and unpack


- Ruby JMeter `apt-get install -y ruby1.9.3 make`
  - and `sudo ruby -S gem install ruby-jmeter --no-ri --no-rdoc`

- HTTP testing utility `apt-get install -y siege`
  - `sudo touch /var/log/siege.log` `sudo chmod a+rw /var/log/siege.log`

## Clock Test

To make sure we're [not the bottleneck][1]

`siege -b -t30S -c100 http://[KB.SERVER.HOST]:8080/1.0/kb/test/clock`

```
** SIEGE 3.0.5
** Preparing 100 concurrent users for battle.
The server is now under siege...
Lifting the server siege...      done.

Transactions:		      191420 hits
Availability:		      100.00 %
Elapsed time:		       30.00 secs
Data transferred:	        0.00 MB
Response time:		        0.02 secs
Transaction rate:	     6380.67 trans/sec
Throughput:		        0.00 MB/sec
Concurrency:		       99.83
Successful transactions:      191612
Failed transactions:	           0
Longest transaction:	        1.15
Shortest transaction:	        0.00
```

[1]: https://github.com/killbill/killbill/wiki/Kill-Bill-Profiling
