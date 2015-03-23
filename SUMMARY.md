# Summary

## t2.medium

### improvements

- patched KB gem + Stripe plugin (branch load_testing3 with pool: false)
  * 50 concurrency avg response 8767 -> 6788 (82.000 -> 106.000 handled requests)
  * lower memory use under the same setup (max 720M-830M allocated -> 680M)
  * see [run-07_1](run-07_1.md)

- when unexpected (using `Java::JavaLang::Enum.value_of` patches) errors are
  avoided avg response falls back to 8139 (with 88440 handled requests)

* see e.g. [run-09_4](run-09_4.md) with :
  `JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.connectionTimeout=5s"`

  * NOTE: Bogacs seems to be delegating timeout fine http://git.io/NE70

### notes

- same setup with 50 than 100 concurrent users performs worse in the later case
  * see [run-07_1](run-07_1.md) and [run-07_2](run-07_2.md)

  **TODO** Tomcat/KB configuration needs to get aggressive to cut off requests ?!

  **TODO** ~~revisit with another plugin + analyze plugin API call response times~~

- including (a few) `Java::JavaLang::Enum.value_of` makes sense
  * they account for errors under loads the server is able to handle
    (with the patch we're able to get to a **0.00000%** error rate)
  * unless there's a JRuby fix in the horizon this should be accounted forou

  **WiP** on the JRuby side

#### plugin-thread

- (osgi) plugin settings: dao.maxActive=50 threads.nb=50
  * [run-07_5](run-07_5.md) 97097 |    7414 |   6757 |   50254 | 0.00000%

- higher (unused) plugin thread count - decreases performance (response time)
  * base (osgi) plugin settings: dao.maxActive=100 threads.nb=100
  * [run-07_91](run-07_91.md)  106724 |    6741 |   6720 |   14439 | 0.00013% (connectionTimeout=5s)
  * [run-07_92](run-07_92.md)  106719 |    6742 |   6720 |   17888 | 0.00008%
  * [run-07_93](run-07_93.md)  106413 |    6761 |   6738 |   35088 | 0.00059% (threads.nb=75)
  * [run-07_94](run-07_94.md)  100932 |    7128 |   7115 |   12372 | 0.00000% (dao.maxActive=50)
  * [run-07_95](run-07_95.md)  106633 |    6747 |   6729 |   12342 | 0.00023% (dao.maxActive=80)
  * [run-07_96](run-07_96.md)  107073 |    6719 |   6696 |   14805 | 0.00003% (dao.maxActive=50 threads.nb=80)


### slowness

- decreasing `-XX:CompileThreshold` (under 7500) as well as JRuby's JIT treshold
  ~~makes overall performance numbers worse~~
  * e.g. ~~[run-07_7](run-07_7.md) versus [run-07_8](run-07_8.md)~~

- using native thread priorities degrade performance significantly
  * TOTAL |  33279 |   43269 |  54858 (100 users -XX:+UseThreadPriorities)
  * TOTAL |  99043 |   14529 |  13647 (100 users)
  * see [run-07_3](run-07_3.md) versus [run-07_4](run-07_4.md)
  * see [run-09_2](run-09_2.md) versus [run-09_3](run-09_3.md)

- potentially high rate of exceptions generated on each request from JRuby
  * NoMethodError : undefined method `fractional' for 1000:Fixnum from
    `gems/money-6.1.1/lib/money/money.rb:241 in initialize`

    rescue behavior is changed to a respond_to? check in money gem >= 6.2.1

  * with money/monetize gems updated exception generated down by **80+ %**

    **TODO** updated gem stack slow-ness

- generated KB API (Ruby) code might be a good candidate for a native JRuby ext
  * mostly scripted Java code which JRuby ends up decorating for Ruby features
  * (otherwise) direct Java method dispatches end up being reflected
  * slow to startup + hard to catch (compilation) errors early on

#### logging

- logback (JRuby) stack-trace logging **major** slow-ness and "non-reliability" source !
- attempted a log4j2 upgrade ~ behaves the same, but there's a possiblity to fix it
  * using a log4j plugin that replaces the stack-trace converted with out own

#### libraries

- **TODO** gem json 1.8.2 (was 1.8.1) seems to be causing a major slow-down ?!?
  ... it includes a JRuby specific fix that should have improved performance

- updating money 6.2.1 (was 6.1.1) + monetize 0.4.1 (was 0.3.0)
  de-creases exception/backtrace count but degrades performance as well ~ 30%

  **TODO:** should be re-visited ... as updated json 1.8.2 was used

- updating money 6.5.0 (was 6.1.1) + monetize 1.1.0 (was 0.3.0)
  degrades performance compared to money 6.2.1 + monetize 0.4.1 !
  * see [run-08_7](run-08_7.md) versus [run-08_8](run-08_8.md)
  * **NOTE:** should probably be revisited later with another pair of run

- atomic 1.1.99 (was 1.1.16) seems to degrade results ... for no obvious reason

  **TODO:** probably EC2 "reliability" otherwise WTF http://git.io/FxYK ?!

  **NOTE:** re-look into this one ... maybe updated json 1.8.2 slipped in !?

- Java::JavaLang::Enum.value_of patches avoid (1 for 2 argument) Ruby exceptions
  (coming from JRuby's Java support under concurrent invocations)


### jj-opts

- `-XX:+UseConcMarkSweepGC` makes sense compared to default GC on Java 7(u72)
- `-Djruby.compile.fastest=true` **needs to be avoided** as there's a serious issue
  with the stack `(ArgumentError) wrong number of arguments (1 for 0)`
```
2015-02-23 22:02:12,788 [Plugin-th-159] WARN  org.killbill.billing.osgi.bundles.jruby.JRubyPlugin - RuntimeException in jruby plugin
org.jruby.exceptions.RaiseException: (ArgumentError) wrong number of arguments (1 for 0)
        at MonitorMixin::ConditionVariable.signal(classpath:/META-INF/jruby.home/lib/ruby/1.9/monitor.rb:139) ~[?:?]
        at ActiveRecord::ConnectionAdapters::ConnectionPool::Queue.add(/var/tmp/bundles/plugins/ruby/killbill-stripe/0.2.1.12/gems/gems/activerecord-4.1.8/lib/active_record/connection_adapters/abstract/connection_pool.rb:101) ~[?:?]
        at MonitorMixin.mon_synchronize(classpath:/META-INF/jruby.home/lib/ruby/1.9/monitor.rb:211) ~[?:?]
        at MonitorMixin.mon_synchronize(classpath:/META-INF/jruby.home/lib/ruby/1.9/monitor.rb:210) ~[?:?]
        at ActiveRecord::ConnectionAdapters::ConnectionPool::Queue.synchronize(/var/tmp/bundles/plugins/ruby/killbill-stripe/0.2.1.12/gems/gems/activerecord-4.1.8/lib/active_record/connection_adapters/abstract/connection_pool.rb:146) ~[?:?]
        at ActiveRecord::ConnectionAdapters::ConnectionPool::Queue.add(/var/tmp/bundles/plugins/ruby/killbill-stripe/0.2.1.12/gems/gems/activerecord-4.1.8/lib/active_record/connection_adapters/abstract/connection_pool.rb:99) ~[?:?]
        at ActiveRecord::ConnectionAdapters::ConnectionPool.checkin(/var/tmp/bundles/plugins/ruby/killbill-stripe/0.2.1.12/gems/gems/activerecord-4.1.8/lib/active_record/connection_adapters/abstract/connection_pool.rb:370) ~[?:?]
        at MonitorMixin.mon_synchronize(classpath:/META-INF/jruby.home/lib/ruby/1.9/monitor.rb:211) ~[?:?]
        at MonitorMixin.mon_synchronize(classpath:/META-INF/jruby.home/lib/ruby/1.9/monitor.rb:210) ~[?:?]
        at ActiveRecord::ConnectionAdapters::ConnectionPool.checkin(/var/tmp/bundles/plugins/ruby/killbill-stripe/0.2.1.12/gems/gems/activerecord-4.1.8/lib/active_record/connection_adapters/abstract/connection_pool.rb:363) ~[?:?]
        at ActiveRecord::ConnectionAdapters::AbstractAdapter.close(/var/tmp/bundles/plugins/ruby/killbill-stripe/0.2.1.12/gems/gems/activerecord-4.1.8/lib/active_record/connection_adapters/abstract_adapter.rb:353) ~[?:?]
        at Killbill::Plugin::ActiveMerchant::PaymentPlugin.after_request(/var/tmp/bundles/plugins/ruby/killbill-stripe/0.2.1.12/gems/gems/killbill-3.2.1.8/lib/killbill/helpers/active_merchant/payment_plugin.rb:40) ~[?:?]
        at RUBY.authorizePayment(/var/tmp/bundles/plugins/ruby/killbill-stripe/0.2.1.12/gems/gems/killbill-3.2.1.8/lib/killbill/gen/plugin-api/payment_plugin_api.rb:89) ~[?:?]
        at Killbill$$Plugin$$Api$$PaymentPluginApi_798999245.authorizePayment(Killbill$$Plugin$$Api$$PaymentPluginApi_798999245.gen:13) ~[?:?]
```
- no gain really going with `-XX:CompileThreshold` < 7000
- no gain really going with `-Djruby.jit.treshold` <= 30
- (minor) difference but no errors `-Djruby.compile.fastest=true`
- do not use ~~`-XX:+UseThreadPriorities`~~
- perm-gen never really grows after start from ~ 110M (allocated size 180M)

#### t2.medium (2 CPU cores, 4GB)

- KillBill 0.12.1 + Stripe/Litle (payment gateway) plugin
- Oracle JDK 7u71

```
JAVA_OPTS="-Djava.awt.headless=true"
if [ "${1}" = "start" ]; then
  JAVA_OPTS="${JAVA_OPTS} -XX:+UseConcMarkSweepGC -XX:+UseCodeCacheFlushing"
  JAVA_OPTS="${JAVA_OPTS} -Xms1024m -Xmx1792m -XX:PermSize=128m -XX:MaxPermSize=256m"
fi

JAVA_OPTS="${JAVA_OPTS} -XX:CompileThreshold=7000"
# NOTE: DO NOT USE :
#JAVA_OPTS="${JAVA_OPTS} -Djruby.compile.fastest=true"

### KB: database setup
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.url=jdbc:mysql://${KB_DB_HOST}:3306/killbill"
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.user=killbill"
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.password=killbill"

#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.url=jdbc:mysql://${KB_DB_HOST}:3306/killbill"
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.user=killbill"
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.password=killbill"

### KB: MAGICK
JAVA_OPTS="${JAVA_OPTS} -DANTLR_USE_DIRECT_CLASS_LOADING=true"

### KB: concurrency connection pool size (default 30) :
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.maxActive=80"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.maxActive=50"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.connectionTimeout=5s"

JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.payment.plugin.threads.nb=60"
```

```xml
    <Connector port="8080" protocol="HTTP/1.1"
               URIEncoding="UTF-8"
               redirectPort="8443"
               maxThreads="100"
               acceptCount="50"
               acceptorThreadCount="2"
               connectionTimeout="10000"
               keepAliveTimeout="5000"
               maxKeepAliveRequests="100" />
```

- KB configuration is capable of handling 50 concurrent gate-way requests
- at a rate around 25k-30k transactions per hour with a response < 10s response
  NOTE: real-world numbers are expected to be better
- dedicated MySQL RDS (db.m3.medium) instance was used during tests
  * expect a "medium" MySQL CPU utilization at peaks ~ 50-60%

**[run-08_1][run-08_1.md]** results :

|                                 | #count | average | median | 90% |  min |   max |   errors | bandwidth |
| ------------------------------- | ------ | ------- | ------ | --- | ---- | ----- | -------- | --------- |
|                           TOTAL | 107255 |    6708 |   6689 |   0 |   18 | 13315 | 0.00000% |    6.33/s |

**[run-09_6][run-09_6.md]** results :

|                                 | #count | average | median | 90% |  min |   max |   errors | bandwidth |
| ------------------------------- | ------ | ------- | ------ | --- | ---- | ----- | -------- | --------- |
|                           TOTAL | 108407 |    6637 |   6620 |   0 |   11 | 12237 | 0.00000% |     6.4/s |


#### t2.small (1 CPU cores, 2GB)

- KillBill 0.12.1 + Stripe (payment gateway) plugin
- openjdk-7-jre-headless amd64 7u75-2.5.4-1~trusty1

```
JAVA_OPTS="-Djava.awt.headless=true"
JAVA_OPTS="${JAVA_OPTS} -XX:+UseConcMarkSweepGC"
JAVA_OPTS="${JAVA_OPTS} -Xms1024m -Xmx1536m -XX:PermSize=96m -XX:MaxPermSize=160m"

JAVA_OPTS="${JAVA_OPTS} -XX:CompileThreshold=7000"

### KB: database setup
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.url=jdbc:mysql://${KB_DB_HOST}:3306/killbill"
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.user=killbill"
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.password=killbill"

#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.url=jdbc:mysql://${KB_DB_HOST}:3306/killbill"
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.user=killbill"
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.password=killbill"

### KB: MAGICK
JAVA_OPTS="${JAVA_OPTS} -DANTLR_USE_DIRECT_CLASS_LOADING=true"

### KB: concurrency connection pool size (default 30) :
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.maxActive=50"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.maxActive=30"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.connectionTimeout=5s"

JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.payment.plugin.threads.nb=30"
```

- KB configuration is capable of handling 30 concurrent gate-way requests
- at a rate around 10.000 transactions per hour with a response < 10s response
  NOTE: real-world numbers are expected to be better
- dedicated MySQL RDS (db.m3.medium) instance was used during tests
  * expect a "low" MySQL CPU utilization ~ 15-30%
  * 82-85 database connections where used at peak

- NOTE: memory limit is at the machine's edge be sure not to run anything else on
  this instance, in case of swapping issues JVM memory should be decreased further




- what is LRU cache used for ... test without ?!
- /var/tmp/bundles/plugins/ruby/killbill-stripe/0.2.1.10/gems/gems/active_utils-2.2.3/lib/active_utils/common/country.rb:65 warning: already initialized constant COUNTRIES


- TODO why does log2j2-ext report thread incorrectly with those - did we mess up or ?!

```
2015-03-04 13:07:13,892 [Thread-5] INFO  org.kill-bill.billing.killbill-platform-osgi-bundles-jruby-1.0.1.3.SNAPSHOT - [stripe-plugin] after_request [Plugin-th-82 #<Thread:0xb71d851 run>] closing connection ...
2015-03-04 13:07:13,892 [Thread-5] INFO  org.kill-bill.billing.killbill-platform-osgi-bundles-jruby-1.0.1.3.SNAPSHOT - [stripe-plugin] after_request [Plugin-th-86 #<Thread:0x5f30b3b5 run>] closing connection ...
2015-03-04 13:07:13,892 [Thread-5] INFO  org.kill-bill.billing.killbill-platform-osgi-bundles-jruby-1.0.1.3.SNAPSHOT - [stripe-plugin] after_request [Plugin-th-76 #<Thread:0x766660e5 run>] closing connection ...
2015-03-04 13:07:13,892 [Thread-5] INFO  org.kill-bill.billing.killbill-platform-osgi-bundles-jruby-1.0.1.3.SNAPSHOT - [stripe-plugin] after_request [Plugin-th-80 #<Thread:0x3b63971d run>] closing connection ...
2015-03-04 13:07:13,892 [Thread-5] INFO  org.kill-bill.billing.killbill-platform-osgi-bundles-jruby-1.0.1.3.SNAPSHOT - [stripe-plugin] after_request [Plugin-th-75 #<Thread:0x5d3e1d58 run>] closing connection ...
2015-03-04 13:07:14,056 [Thread-5] INFO  org.kill-bill.billing.killbill-platform-osgi-bundles-jruby-1.0.1.3.SNAPSHOT - [stripe-plugin] after_request [Plugin-th-90 #<Thread:0x2ae56f0c run>] closing connection ...
```
