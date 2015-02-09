# ENV (Tomcat) **/etc/default/tomcat7**

# Run Tomcat as this user ID. Not setting this or leaving it blank will use the
# default of tomcat7.
TOMCAT7_USER=tomcat7

# Run Tomcat as this group ID. Not setting this or leaving it blank will use
# the default of tomcat7.
TOMCAT7_GROUP=tomcat7

# The home directory of the Java development kit (JDK). You need at least
# JDK version 1.5. If JAVA_HOME is not set, some common directories for
# OpenJDK, the Sun JDK, and various J2SE 1.5 versions are tried.
#JAVA_HOME=/usr/lib/jvm/openjdk-6-jdk

### KB: custom options
# Use "-XX:+UseConcMarkSweepGC" to enable the CMS garbage collector (improved
# response time). If you use that option and you run Tomcat on a machine with
# exactly one CPU chip that contains one or two cores, you should also add
# the "-XX:+CMSIncrementalMode" option.
JAVA_OPTS="-Djava.awt.headless=true"
if [ "${1}" = "start" ]; then
  JAVA_OPTS="${JAVA_OPTS} -XX:+UseConcMarkSweepGC -XX:+UseCodeCacheFlushing"
  JAVA_OPTS="${JAVA_OPTS} -Xms128m -Xmx1536m -XX:PermSize=128m -XX:MaxPermSize=256m"
fi

###
#JAVA_OPTS="${JAVA_OPTS} -XX:CompileThreshold=8000 -Xss1280k"

### KB: remote monitoring
if [ "${1}" = "start" ]; then
  JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote"
  JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.port=9901"
  JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.authenticate=false"
  JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.ssl=false"
fi

### KB: JRuby
#JAVA_OPTS="${JAVA_OPTS} -Xss1024k"
#JAVA_OPTS="${JAVA_OPTS} -Djruby.compile.invokedynamic=false"
#JAVA_OPTS="${JAVA_OPTS} -Djruby.compile.mode=JIT"

JAVA_OPTS="${JAVA_OPTS} -Djruby.management.enabled=true"
#JAVA_OPTS="${JAVA_OPTS} -Djruby.reify.classes=true"
#JAVA_OPTS="${JAVA_OPTS} -Djruby.reify.logErrors=true"

### Helper
#PUBLIC_IP_FILE="$(dirname $0)/.public-ip"
#if [ ! -f $PUBLIC_IP_FILE ]; then
#  PUBLIC_IP="$(curl -s ipecho.net/plain)"
#  echo $PUBLIC_IP > $PUBLIC_IP_FILE
#else
#  PUBLIC_IP="$(cat $PUBLIC_IP_FILE)"
#fi

# make sure to uncomment the following line if you're use x.y.z.t:9901
#JAVA_OPTS="${JAVA_OPTS} -Djava.rmi.server.hostname=$PUBLIC_IP"
# or simply set your public hostname e.g. :
#JAVA_OPTS="${JAVA_OPTS} -Djava.rmi.server.hostname=ec2-54-148-66-206.us-west-2.compute.amazonaws.com"
# by default we assume ssh -N -v -L 9901:localhost:9901 ubuntu@ec2-remote-host
JAVA_OPTS="${JAVA_OPTS} -Djava.rmi.server.hostname=localhost"

# To enable remote debugging uncomment the following line.
# You will then be able to use a java debugger on port 8000.
#JAVA_OPTS="${JAVA_OPTS} -Xdebug -Xrunjdwp:transport=dt_socket,address=8000,server=y,suspend=n"

echo "using JAVA_OPTS=${JAVA_OPTS}"

### KB: !!! CHANGE ME !!! host where MySQL is running
KB_DB_HOST="killbill.cjafxh9qc2le.us-west-2.rds.amazonaws.com"

### KB: database setup
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.url=jdbc:mysql://${KB_DB_HOST}:3306/killbill"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.user=killbill"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.password=killbill"

JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.url=jdbc:mysql://${KB_DB_HOST}:3306/killbill"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.user=killbill"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.password=killbill"

### KB: MAGICK
JAVA_OPTS="${JAVA_OPTS} -DANTLR_USE_DIRECT_CLASS_LOADING=true"

### KB: optionals/tunning :
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.server.baseUrl=http://${PUBLIC_IP}:8080"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.server.updateCheck.skip=true"

### KB: will have all plugin configuration at /etc/killbill :
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.bundles.jruby.conf.dir=/etc/killbill"

### KB: concurrency connection pool size (default 30) :
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.dao.maxActive=100"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.billing.osgi.dao.maxActive=100"

JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.payment.plugin.threads.nb=100"

### KB: persistent bus :
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.external.claimed=100"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.external.inMemory=true"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.external.inflight.claimed=100"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.external.nbThreads=10"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.external.queue.capacity=30000"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.external.sleep=0"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.external.sticky=true"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.external.useInflightQ=true"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.main.claimed=100"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.main.nbThreads=10"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.main.queue.capacity=30000"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.main.sleep=0"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.main.sticky=true"
JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.persistent.bus.main.useInflightQ=true"

### KB: TODO
#JAVA_OPTS="${JAVA_OPTS} -Dorg.killbill.payment.plugin.timeout=5s"

# To enable remote debugging uncomment the following line.
# You will then be able to use a java debugger on port 8000.
#JAVA_OPTS="${JAVA_OPTS} -Xdebug -Xrunjdwp:transport=dt_socket,address=8000,server=y,suspend=n"

# Java compiler to use for translating JavaServer Pages (JSPs). You can use all
# compilers that are accepted by Ant's build.compiler property.
#JSP_COMPILER=javac

# Use the Java security manager? (yes/no, default: no)
#TOMCAT7_SECURITY=no

# Number of days to keep logfiles in /var/log/tomcat7. Default is 14 days.
#LOGFILE_DAYS=14
# Whether to compress logfiles older than today's
#LOGFILE_COMPRESS=1

# Location of the JVM temporary directory
# WARNING: This directory will be destroyed and recreated at every startup !
#JVM_TMP=/tmp/tomcat7-temp

# If you run Tomcat on port numbers that are all higher than 1023, then you
# do not need authbind.  It is used for binding Tomcat to lower port numbers.
# NOTE: authbind works only with IPv4.  Do not enable it when using IPv6.
# (yes/no, default: no)
#AUTHBIND=no
