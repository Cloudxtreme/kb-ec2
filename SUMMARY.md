# Summary

## t2.medium

### improvements

- patched KB gem + Stripe plugin (branch load_testing3 with pool: false)
  * 50 concurrency avg response 8767 -> 6788 (82.000 -> 106.000 handled requests)
  * lower memory use under the same setup (max 720M-830M allocated -> 680M)
  * see [run-07_1](run-07_1.md)

- when unexpected (using `Java::JavaLang::Enum.value_of` patches) errors are 
  avoided avg response falls back to 8139 (with 88440 handled requests)
  
  **TODO** need to look into AR-Bogacs timeouts - they seem to never happen ?!
  

### notes
    
- same setup with 50 than 100 concurrent users performs worse in the later case 
  * see [run-07_1](run-07_1.md) and [run-07_2](run-07_2.md)
  
  **TODO** Tomcat/KB configuration needs to get aggressive to cut off requests ?!

- including (a few) `Java::JavaLang::Enum.value_of` makes sense 
  * they account for errors under loads the server is able to handle 
    (with the patch we're able to get to a **0.00000%** error rate)
  * unless there's a JRuby fix in the horizon this should be accounted forou
  
  **WiP** on the JRuby side

- 
  
### slowness

- decreasing `-XX:CompileThreshold` (under 7500) as well as JRuby's JIT treshold
  makes overall performance numbers worse ...

- using native thread priorities degrade performance significantly
  * TOTAL |  33279 |   43269 |  54858 (100 users -XX:+UseThreadPriorities)
  * TOTAL |  99043 |   14529 |  13647 (100 users)
  
  **TODO** should be double checked / confirmed ...

- potentially high rate of exceptions generated on each request from JRuby
  * NoMethodError : undefined method `fractional' for 1000:Fixnum from 
    `gems/money-6.1.1/lib/money/money.rb:241 in initialize` 
    
    rescue behavior is changed to a respond_to? check in money gem >= 6.2.1
    
  * with money/monetize gems updated exception generated down by **80+ %**
    
    TODO updated gem stack slow-ness

- generated KB API (Ruby) code might be a good candidate for a native JRuby ext
  * mostly scripted Java code which JRuby ends up decorating for Ruby features 
  * (otherwise) direct Java method dispatches end up being reflected
  * slow to startup + hard to catch (compilation) errors early on
  
#### libraries

- gem json 1.8.2 (was 1.8.1) seems to be causing a major slow-down
  ... it includes a JRuby specific fix that should have improved performance

- updating money 6.2.1 (was 6.1.1) + monetize 0.4.1 (was 0.3.0)
  de-creases exception/backtrace count but degrades performance as well ~ 30%

  **NOTE:** should be re-visited ... as updated json 1.8.2 was used
  
- updating money 6.5.0 (was 6.1.1) + monetize 1.1.0 (was 0.3.0)
  de-creases exception/backtrace count but degrades performance as well ~ 50%
  
  **NOTE:** should be re-visited ... as updated json 1.8.2 was used
  
- atomic 1.1.99 (was 1.1.16) seems to degrade results ... for no obvious reason

  **TODO:** probably EC2 "reliability" otherwise WTF http://git.io/FxYK ?!
  
  **NOTE:** re-look into this one ... maybe updated json 1.8.2 slipped in !?
  
- Java::JavaLang::Enum.value_of patches avoid (1 for 2 argument) Ruby exceptions 
  (coming from JRuby's Java support under concurrent invocations)
