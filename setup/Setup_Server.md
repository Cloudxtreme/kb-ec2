# Setup (Kill Bill Server)

**NOTE:** Actual virtual (RDS/EC2) machine [setup][1] is out of scope here.

We're assuming a 2+ machine setup:
1. the database machine (RDS) using MySQL
2. KillBill server on an EC2 that can connect to DB
3. (optional) testing server close to the KB server

## Install

**NOTE:** Most of these require administrative rights (`sudo`).

- `apt-get install -y mysql-client`

- `apt-get install -y openjdk-7-jre-headless`

   alternatively: setup Oracle JDK e.g.
   - `cd /opt`
   - `wget --no-cookies --no-check-certificate --header 'Cookie:gpw_e24=http://www.oracle.com; oraclelicense=accept-securebackup-cookie' http://download.oracle.com/otn-pub/java/jdk/7u71-b14/jdk-7u71-linux-x64.tar.gz`
   - untar the package `tar -zxvf jdk-7u71-linux-x64.tar.gz`
   - `update-alternatives --install "/usr/bin/java" "java" "/opt/jdk-7u71/bin/java" 1`
   - make it the default Java: `update-alternatives --config java`


- `apt-get install -y tomcat7` we'll be assuming a TC service (`sudo service tomcat7 restart`)

- for KPM we simply use MRI (KillBill will install it's own JRuby) :
  - `apt-get install -y ruby1.9.3 make`
  - `sudo ruby -S gem install kpm`

- sample KPM configuration (assuming system tomcat installation) :

```yaml
killbill:
  version: 0.12.1
  # KPM version used did not handle extracting .war into the ROOT
  # but otherwise we'd like to end-up with KB installed as :
  # webapp_path: /var/lib/tomcat7/webapps/ROOT.war
  # or the .war contents simply extracted under root path :
  # webapp_path: /var/lib/tomcat7/webapps/ROOT
  webapp_path: /var/lib/tomcat7/webapps
  plugins_dir: /var/tmp/bundles
  plugins:
    #java:
    #  - name: analytics-plugin
    #    version: 0.7.2
    ruby:
      # plugins will end up at /var/tmp/bundles/plugins/ruby
      - name: stripe-plugin
        version: 0.2.1
      #- name: stripe-plugin
      #  version: 0.0.4
```

- run KPM to install KB including the plugins `sudo ruby -S kpm install kpm.yml`

- if the *killbill-0.2.1.war* did end up under Tomcat's *webapps* move it under root :
  - `rm -r /var/lib/tomcat7/webapps/ROOT/`
  - `mv /var/lib/tomcat7/webapps/killbill*.war /var/lib/tomcat7/webapps/ROOT.war`

## Configure

With all the packages installed, let's configure/tune KB based on our (testing) scenarios and system resources.

### ENV (Tomcat)

Assuming the tomcat7 package, all modifications under **/etc/default/tomcat7**

[1]: http://killbill.io/aws-deployment/
