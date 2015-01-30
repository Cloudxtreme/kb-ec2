# Summary

## t2.medium

### improvements

- patched KB gem + Stripe plugin (branch load_testing3 with pool: false)
  * 50 concurrency avg response 8767 -> 6788 (82.000 -> 106.000 handled requests)
  * lower memory use under the same setup (max 720M-830M allocated -> 680M)

### slowness

- using native thread priorities degrade performance significantly - TODO confirm
  * TOTAL |  33279 |   43269 |  54858 (100 users -XX:+UseThreadPriorities)
  * TOTAL |  99043 |   14529 |  13647 (100 users)

- potentially high rate of exceptions generated on each request from JRuby
  * NoMethodError : undefined method `fractional' for 1000:Fixnum from 
    `gems/money-6.1.1/lib/money/money.rb:241 in initialize` 
    
    rescue behavior is changed to a respond_to? check in money gem >= 6.2.1
    
  * with money/monetize gems updated exception generated down by **80+ %**
    
    TODO updated gem stack slow-ness

- generated KB API (Ruby) code might be a good candidate for a native JRuby ext
  * mostly scripted Java code which JRuby ends up decorating for Ruby features 
  * direct Java method invocations end up being reflected
  * slow to startup + hard to catch (compilation) errors early on
    
### notes
    
- including (a few) `Java::JavaLang::Enum.value_of` in a hope for a clean 
  (exception less log) patches has little impact on performance but affects 
  correctness and predictability since they seems to happen more as the server
  gets stressed
  * they account for errors under loads the server is able to handle 
    (with the patch we're able to get to a **0.00000%** error rate)
  
  **WiP** on the JRuby side
  
## minor

