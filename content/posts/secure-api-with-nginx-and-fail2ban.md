---
title: "Secure your Django API from DDoS attacks with NGINX and fail2ban"
date: 2020-04-26T11:36:39-03:00
lastmod: 2020-04-26T11:36:39-03:00
tags : [ "devops", "nginx", "django" ]
---

Hello everyone!

Last week our Django API, hosted on an Amazon EC2 server was attacked by a
botnet farm, which took our services down for almost the entire weekend. I’m not
going to lie, it was a very stressful situation, but at the same time we learned
a lot about how to secure our server from future
[DDoS](https://en.wikipedia.org/wiki/Denial-of-service_attack) attacks.

For our solution we are using the
[rate-limiting](https://www.nginx.com/blog/rate-limiting-nginx/) functionality from NGINX and
[fail2ban](https://www.fail2ban.org/), a program that bans external APIs when they break a certain set of
rules. Let’s start!

# NGINX configuration

In NGINX is simple, we just need to configure the rate-limiting on our website
level.

We are using Django with the Django REST framework, so we went with a
configuration of 5 requests per second (5r/s) with extra bursts of 5 requests.
This works fine with Django, but you might need to tweak it for your
configuration.

This allows a total of 10 requests (5 processing and 5 in queue) before our API
returns a 503 server error

```nginx
limit_req_zone $binary_remote_addr zone=one:20m rate=5r/s;

server {
    limit_req   zone=one  burst=5 nodelay;
    # ...
}
```

Let me explain what is going on here:

1) First, we are setting up the `limit_req_zone`. 
    - The `$binary_remote_addr` specifies that we are registering the requests by IP
    - `zone` is the name of the `limit_req_zone`, and `20m` is its total size 
    - `rate` is the permitted rate per IP address. Here we are allowing `5r/s`,
    which translates to 1 request every 200ms.
2) Then, inside the `server` directive we use the `limit_req_zone` referencing
    it by name.
    - `zone` specifies the `limit_req_zone` to be used, in this case, we named it `one`
    - `burst` is the number of requests that can be queued by the same IP per second,
      giving us a grand total of 10 requests per IP (5 in process and 5 in queue)
    - We want our queued requests to be processed as soon as possible, by
      giving it the `nodelay` directive when a slot is freed, an item in the
      queue is going to be processed
    
If a client goes over the 10 requests limit, NGINX is going to return a 503
(Service Unavailable) error and will record the attempt in the error log. And
here is where it becomes interesting :)

If you want to read more about NGINX rate limiting, you can check this link https://www.nginx.com/blog/rate-limiting-nginx/

# fail2ban

According to their documentation, [fail2ban](https://www.fail2ban.org/) is:
> Fail2ban scans log files (e.g. /var/log/apache/error_log) and bans IPs that show the malicious signs -- too many password failures, seeking for exploits, etc. Generally Fail2Ban is then used to update firewall rules to reject the IP addresses for a specified amount of time, although any arbitrary other action (e.g. sending an email) could also be configured. Out of the box Fail2Ban comes with filters for various services (apache, courier, ssh, etc).

We are going to use fail2ban to scan our NGINX error logs, and if it finds too
many occurrences of the same IP, it will ban it for an x amount of time.

First, we need to install fail2ban:

In Debian based distros:

```bash
$ sudo apt install fail2ban
```

After installing fail2ban, we need to configure our local configuration file. In
fail2ban they are called "jails". We can make a local copy with the following
command:

```bash
$ sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

Once we have our local configuration file, we can create our own directive. At
the bottom of the `/etc/fail2ban/jail.local` file, add this configuration:

```bash
[nginx-req-limit]

enabled = true
filter = nginx-limit-req
action = iptables-multiport[name=ReqLimit, port="http,https", protocol=tcp]
logpath = /var/log/nginx/error.log
findtime = 5
maxretry = 2
bantime = 300
```

Here is what's happening:

1) First, we name our filter. In this case, our filter is called
`[nginx-req-limit]`
2) Then we enable our filter with `enabled = true`
3) We set our filter to be `nginx-limit-req`. This is a default filter from fail2ban
4) We define the action that fail2ban is going to do when it finds a suspicious
IP. In this case, it will process it with `iptables-multiport` and block the
http and https ports for that IP address
5) We tell fail2ban which logfile it is going to scan. In our case, since we are
using NGINX our log file is `/var/log/nginx/error.log`
6) `findtime` is the time in which fail2ban is going to limit the searches, and
maxretry is the max amount of times an IP can appear on the log before it is
banned. In our case, if an IP address appears 2 times in less than 5 seconds on
our error log, fail2ban is going to ban it.
7) And finally, we set our `bantime` to 300 seconds (5 minutes). 

And that's it! We need to restart fail2ban to see if everything is working
correctly:

```bash
$ sudo systemctl restart fail2ban.service
```

To check if the service is running, you can run:

```bash
$ sudo fail2ban-client status
```

It should return something like:

```bash
Status
|- Number of jail:	2
`- Jail list:	nginx-req-limit, sshd
```

To know more, you can run:

```bash
$ sudo fail2ban-client status nginx-req-limit
```

And it will return something like:

```bash
|- Filter
|  |- Currently failed:	0
|  |- Total failed:	0
|  `- File list:	/var/log/nginx/error.log
`- Actions
   |- Currently banned:	1
   |- Total banned:	2
   `- Banned IP list:	1.2.3.4
```

And that's it! It is fully working, you are now protected from DDoS attacks
dynamically.

# Bonus

## What if I want to ban an IP address forever?

We can create another jail in `fail2ban` to achieve this. On our
`/etc/fail2ban/jail.local` file, add this: 

```bash
[man-ban]

enabled = true
filter = nginx-limit-req
action = iptables-multiport[name=ReqLimit, port="http,https", protocol=tcp]
logpath = /var/log/nginx/error.log
findtime = 1
bantime = 2678400
maxretry = 99999
```

This jail wont pick up anything because we are expecting 99999 errors in less
than a second, but it will ban anyone for 1 month. Once we restart fail2ban
again, you can manually ban IP addresses with that jail:

```bash
$ sudo fail2ban-client set man-ban banip 1.2.3.4
```

If you check the status, you will see something like:

```bash
|- Filter
|  |- Currently failed:	0
|  |- Total failed:	0
|  `- File list:	/var/log/nginx/error.log
`- Actions
   |- Currently banned:	1
   |- Total banned:	1
   `- Banned IP list:	1.2.3.4
```

The IP `1.2.3.4` will be banned for 1 month. You can unban it with

```bash
$ sudo fail2ban-client set man-ban unbanip 1.2.3.4
```

# Conclusion

In this days, DDoS attacks are very common on the internet, so it is common sense to
be prepared to defend against them. 

In the next delivery we will create a status page for our API, that will let us
know if one of the services is down.


Stay tuned!
